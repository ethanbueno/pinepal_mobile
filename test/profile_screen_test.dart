import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pinepal_mobile/screens/profile_screen.dart';
import 'package:pinepal_mobile/services/app_settings.dart';
import 'package:pinepal_mobile/services/auth_controller.dart';
import 'package:pinepal_mobile/services/sync_controller.dart';
import 'package:pinepal_mobile/theme/app_theme.dart';

Future<void> showProfile(
  WidgetTester tester, {
  required AuthController auth,
  required AppSettings settings,
}) async {
  final sync = SyncController(auth: auth, settings: settings);

  // A tall phone, so the whole list is built and nothing is scrolled out of view
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  // The screen asks the real database how many scans are waiting, which needs
  // real (not fake) time to answer
  await tester.runAsync(() async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: ProfileScreen(auth: auth, settings: settings, sync: sync),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await tester.pump();
}

AuthController signedInAuth() {
  final auth = AuthController(store: MemorySessionStore());
  auth.signIn(
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
  return auth;
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('signed out: Sync now opens sign in', (tester) async {
    await showProfile(
      tester,
      auth: AuthController(store: MemorySessionStore()),
      settings: AppSettings(),
    );

    expect(find.text('Not signed in'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Sign in'), findsOneWidget);
    expect(find.text('Log out'), findsNothing);

    // Signing in (or creating an account) is how a signed-out phone syncs
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sync now'));
    await tester.pumpAndSettle();
    expect(find.text('Log into PinePal'), findsOneWidget);
    expect(find.text('New to PinePal? Create an account'), findsOneWidget);
  });

  testWidgets('signed out: shows the farmer ID this phone syncs as', (
    tester,
  ) async {
    final auth = AuthController(store: MemorySessionStore());
    await auth.setPhoneFarmer(
      const PhoneFarmer(farmerId: 'F070', token: 'device'),
    );
    final settings = AppSettings();
    await settings.setSyncMode(SyncMode.automatic);
    await showProfile(tester, auth: auth, settings: settings);

    expect(find.textContaining('syncs as farmer ID F070'), findsOneWidget);
    // "All scans are synced as..." or "2 scans are waiting to sync as..."
    expect(
      find.textContaining(RegExp(r'sync(ed)? as farmer ID F070\.$')),
      findsOneWidget,
    );
  });

  testWidgets('signing in forgets the phone farmer ID', (tester) async {
    final auth = AuthController(store: MemorySessionStore());
    await auth.setPhoneFarmer(
      const PhoneFarmer(farmerId: 'F070', token: 'device'),
    );
    await auth.signIn(
      const AuthSession(
        token: 't',
        user: AuthUser(
          id: 7,
          fullName: 'Juan Dela Cruz',
          username: 'juan',
          role: 'farmer',
          farmerId: 'F069',
        ),
      ),
    );
    expect(auth.phoneFarmer, isNull);

    await showProfile(tester, auth: auth, settings: AppSettings());
    expect(find.text('Farmer ID F069'), findsOneWidget);
  });

  testWidgets('the tab is about the farmer, preferences are in Settings', (
    tester,
  ) async {
    await showProfile(
      tester,
      auth: AuthController(store: MemorySessionStore()),
      settings: AppSettings(),
    );

    expect(find.text('Account'), findsOneWidget);
    expect(find.text('My farm'), findsOneWidget);
    expect(find.text('Sync'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);

    // None of the preferences, and never the server
    expect(find.text('Dark mode'), findsNothing);
    expect(find.byType(SegmentedButton<SyncMode>), findsNothing);
    expect(find.text('Wi-Fi only'), findsNothing);
    expect(find.text('Server address'), findsNothing);
  });

  testWidgets('signed in: shows the account and its web role', (tester) async {
    await showProfile(tester, auth: signedInAuth(), settings: AppSettings());

    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(find.text('@juan'), findsOneWidget);
    expect(find.text('Farmer'), findsOneWidget);
    expect(find.text('JD'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Not signed in'), findsNothing);
  });

  testWidgets('the sync line says how syncing is set up', (tester) async {
    final settings = AppSettings();
    await settings.setSyncMode(SyncMode.automatic);
    await showProfile(tester, auth: signedInAuth(), settings: settings);

    expect(find.textContaining('Automatic, on Wi-Fi only'), findsOneWidget);
  });

  testWidgets('the farm can be added from a sheet', (tester) async {
    final settings = AppSettings();
    await showProfile(
      tester,
      auth: AuthController(store: MemorySessionStore()),
      settings: settings,
    );

    // Nothing yet: it asks for the farm, and there is no municipality
    expect(find.textContaining('Add your farm name'), findsOneWidget);
    expect(find.text('No municipality yet'), findsOneWidget);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Farm details'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Bueno Farm');
    // Save waits for a municipality
    final save = find.widgetWithText(ElevatedButton, 'Save');
    expect(tester.widget<ElevatedButton>(save).onPressed, isNull);

    await tester.tap(find.text('Choose a municipality'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Echague').last);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(settings.farmName, 'Bueno Farm');
    expect(settings.municipality, 'Echague');
    expect(find.text('Echague'), findsOneWidget);
    expect(find.text('Bueno Farm'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.textContaining('Add your farm name'), findsNothing);
  });
}
