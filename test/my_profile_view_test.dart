import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pinepal_mobile/services/api_client.dart';
import 'package:pinepal_mobile/services/app_settings.dart';
import 'package:pinepal_mobile/services/auth_controller.dart';
import 'package:pinepal_mobile/theme/app_theme.dart';
import 'package:pinepal_mobile/widgets/my_profile_view.dart';

Map<String, dynamic> profileJson({
  String username = 'juan',
  String? avatarUrl,
}) => {
  'account': {
    'avatar_url': avatarUrl,
    'full_name': 'Juan Dela Cruz',
    'username': username,
    'email': 'juan@example.com',
    'role': 'farmer',
    'municipality': 'Echague',
    'created_at': '2026-10-01T08:00:00',
  },
  'farm': {
    'farmer_id': 'F012',
    'farm_name': 'Bueno Farm',
    'municipality': 'Echague',
    'farm_size_ha': 2.5,
    'farm_latitude': 16.7,
    'farm_longitude': 121.68,
    'is_active': true,
    'registered_at': '2026-10-01T08:00:00',
    'total_scans': 14,
  },
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late List<http.Request> puts;
  late AuthController auth;

  Future<void> showMyProfile(WidgetTester tester) async {
    puts = [];
    final api = ApiClient(
      baseUrl: () => 'http://server.test:5000',
      client: MockClient((request) async {
        if (request.method == 'PUT') {
          puts.add(request);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['current_password'] != 'secret') {
            return http.Response(
              jsonEncode({'error': 'Your current password is wrong'}),
              403,
            );
          }
          return http.Response(
            jsonEncode(profileJson(username: body['username'] as String)),
            200,
          );
        }
        return http.Response(jsonEncode(profileJson()), 200);
      }),
    );
    auth = AuthController(store: MemorySessionStore());
    await auth.signIn(
      const AuthSession(
        token: 't',
        user: AuthUser(
          id: 7,
          fullName: 'Juan Dela Cruz',
          username: 'juan',
          role: 'farmer',
        ),
      ),
    );

    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: ListView(
            children: [
              MyProfileView(api: api, auth: auth, settings: AppSettings()),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the cover, Overview, Farm and Personal info', (
    tester,
  ) async {
    await showMyProfile(tester);

    expect(find.text('JD'), findsOneWidget); // the avatar
    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.text('Farm'), findsOneWidget);
    expect(find.text('Personal info'), findsOneWidget);
    expect(find.text('juan@example.com'), findsOneWidget);
    expect(find.text('Municipality · Echague only for now'), findsOneWidget);
    expect(find.text('Active account'), findsOneWidget);
    // the password has moved into Edit account
    expect(find.text('Change password'), findsNothing);
  });

  testWidgets('offline: shows the account the phone knows and Try again', (
    tester,
  ) async {
    final auth = AuthController(store: MemorySessionStore());
    await auth.signIn(
      const AuthSession(
        token: 't',
        user: AuthUser(
          id: 7,
          fullName: 'Juan Dela Cruz',
          username: 'juan',
          role: 'farmer',
        ),
      ),
    );
    final api = ApiClient(
      baseUrl: () => 'http://server.test:5000',
      client: MockClient(
        (request) async => throw http.ClientException('offline'),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: ListView(
            children: [
              MyProfileView(api: api, auth: auth, settings: AppSettings()),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('Edit account changes the username with the current password', (
    tester,
  ) async {
    await showMyProfile(tester);

    await tester.tap(find.text('Edit account'));
    await tester.pumpAndSettle();
    expect(find.text('Change'), findsNWidgets(6));

    // the second Change is the username's
    await tester.tap(find.text('Change').at(1));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'juan2');
    await tester.tap(find.text('Save username'));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter your current password to change your username.'),
      findsOneWidget,
    );
    expect(puts, isEmpty);

    await tester.enterText(find.byType(TextField).last, 'secret');
    await tester.tap(find.text('Save username'));
    await tester.pumpAndSettle();

    expect(puts, hasLength(1));
    expect(jsonDecode(puts.single.body), {
      'username': 'juan2',
      'current_password': 'secret',
    });
    expect(auth.user!.username, 'juan2');
    expect(find.text('@juan2'), findsWidgets);
  });

  group('photos', () {
    late List<http.BaseRequest> sent;

    Future<void> showWithPhotos(
      WidgetTester tester, {
      String? avatarUrl,
      Future<String?> Function(ImageSource)? pickPhoto,
    }) async {
      sent = [];
      final api = ApiClient(
        baseUrl: () => 'http://server.test:5000',
        client: MockClient((request) async {
          sent.add(request);
          if (request.method == 'POST') {
            return http.Response(
              jsonEncode(
                profileJson(avatarUrl: 'https://res.cloudinary.com/x/a.jpg'),
              ),
              200,
            );
          }
          if (request.method == 'DELETE') {
            return http.Response(jsonEncode(profileJson()), 200);
          }
          return http.Response(
            jsonEncode(profileJson(avatarUrl: avatarUrl)),
            200,
          );
        }),
      );
      final auth = AuthController(store: MemorySessionStore());
      await auth.signIn(
        const AuthSession(
          token: 't',
          user: AuthUser(
            id: 7,
            fullName: 'Juan Dela Cruz',
            username: 'juan',
            role: 'farmer',
          ),
        ),
      );
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(
            body: ListView(
              children: [
                MyProfileView(
                  api: api,
                  auth: auth,
                  settings: AppSettings(),
                  pickPhoto: pickPhoto,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a new profile photo from the gallery is uploaded', (
      tester,
    ) async {
      // sync: real file work never finishes inside a widget test's fake time
      final dir = Directory.systemTemp.createTempSync('pinepal_photo');
      addTearDown(() => dir.deleteSync(recursive: true));
      final photo = File('${dir.path}/me.jpg')
        ..writeAsBytesSync([0xff, 0xd8, 0xff, 0xe0, 0, 0, 0, 0]);
      ImageSource? source;

      await showWithPhotos(
        tester,
        pickPhoto: (s) async {
          source = s;
          return photo.path;
        },
      );
      await tester.tap(find.byTooltip('Change profile photo'));
      await tester.pumpAndSettle();
      // no photo yet, so nothing to remove
      expect(find.text('Remove photo'), findsNothing);
      await tester.tap(find.text('Choose from gallery'));
      // the upload reads the file for real, so let real time pass while the
      // spinner turns (pumpAndSettle would wait for the spinner forever)
      for (
        var i = 0;
        i < 50 && !find.text('Profile photo changed.').evaluate().isNotEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();

      expect(source, ImageSource.gallery);
      final upload = sent.last;
      expect(upload.method, 'POST');
      expect(upload.url.path, '/api/profile/photo/avatar');
      // MockClient hands over the multipart body as one plain request
      expect(upload.headers['content-type'], startsWith('multipart/form-data'));
      expect(
        latin1.decode((upload as http.Request).bodyBytes),
        contains('name="photo"'),
      );
      expect(find.text('Profile photo changed.'), findsOneWidget);
    });

    testWidgets('Remove photo goes back to the initials', (tester) async {
      await showWithPhotos(
        tester,
        avatarUrl: 'https://res.cloudinary.com/x/a.jpg',
      );
      await tester.tap(find.byTooltip('Change profile photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove photo'));
      await tester.pumpAndSettle();

      expect(sent.last.method, 'DELETE');
      expect(sent.last.url.path, '/api/profile/photo/avatar');
      expect(find.text('Profile photo removed.'), findsOneWidget);
    });
  });
}
