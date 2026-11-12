import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pinepal_mobile/services/api_client.dart';
import 'package:pinepal_mobile/services/app_settings.dart';
import 'package:pinepal_mobile/services/auth_controller.dart';
import 'package:pinepal_mobile/theme/app_theme.dart';
import 'package:pinepal_mobile/widgets/my_profile_view.dart';

Map<String, dynamic> profileJson({String username = 'juan'}) => {
  'account': {
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
    // the password has moved into Edit profile
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

  testWidgets('Edit profile changes the username with the current password', (
    tester,
  ) async {
    await showMyProfile(tester);

    await tester.tap(find.text('Edit profile'));
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
}
