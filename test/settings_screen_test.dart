import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pinepal_mobile/screens/settings_screen.dart';
import 'package:pinepal_mobile/services/app_settings.dart';
import 'package:pinepal_mobile/services/auth_controller.dart';
import 'package:pinepal_mobile/services/sync_controller.dart';
import 'package:pinepal_mobile/theme/app_theme.dart';

Future<AppSettings> showSettings(
  WidgetTester tester, {
  AppSettings? settings,
}) async {
  settings ??= AppSettings();
  final sync = SyncController(
    auth: AuthController(store: MemorySessionStore()),
    settings: settings,
  );

  // A tall phone, so the whole list is built and nothing is scrolled out of view
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(Brightness.light),
      home: SettingsScreen(settings: settings, sync: sync),
    ),
  );
  return settings;
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('has the preferences, and no server address', (tester) async {
    await showSettings(tester);

    expect(find.text('Sync'), findsOneWidget);
    expect(find.text('Manual'), findsOneWidget);
    expect(find.text('Automatic'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Dark mode'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.text('Version $appVersion'), findsOneWidget);

    // Farmers never see the server
    expect(find.text('Developer'), findsNothing);
    expect(find.text('Server address'), findsNothing);
  });

  testWidgets('Wi-Fi only appears with automatic sync', (tester) async {
    final settings = await showSettings(tester);
    expect(find.text('Wi-Fi only'), findsNothing);

    await tester.tap(find.text('Automatic'));
    await tester.pump();

    expect(settings.syncMode, SyncMode.automatic);
    expect(find.text('Wi-Fi only'), findsOneWidget);

    await tester.tap(find.text('Manual'));
    await tester.pump();
    expect(settings.syncMode, SyncMode.manual);
    expect(find.text('Wi-Fi only'), findsNothing);
  });

  testWidgets('tapping the version seven times reveals the developer options', (
    tester,
  ) async {
    final settings = await showSettings(tester);

    for (var i = 0; i < 6; i++) {
      await tester.tap(find.text('Version $appVersion'));
    }
    await tester.pump();
    expect(find.text('Server address'), findsNothing); // not yet

    await tester.tap(find.text('Version $appVersion'));
    await tester.pump();

    expect(settings.developerOptions, true);
    expect(find.text('Developer'), findsOneWidget);
    expect(find.text('Server address'), findsOneWidget);
    expect(find.text('Test connection'), findsOneWidget);
    expect(find.text('Developer options are on.'), findsOneWidget);
  });

  testWidgets('developer options can be hidden again', (tester) async {
    final settings = AppSettings();
    await settings.setDeveloperOptions(true);
    await showSettings(tester, settings: settings);
    expect(find.text('Server address'), findsOneWidget);

    await tester.tap(find.text('Hide developer options'));
    await tester.pump();

    expect(settings.developerOptions, false);
    expect(find.text('Server address'), findsNothing);
  });

  testWidgets('a custom server can be set and reset to the built-in one', (
    tester,
  ) async {
    final settings = AppSettings();
    await settings.setDeveloperOptions(true);
    await showSettings(tester, settings: settings);

    // Saved when the field is submitted
    await tester.enterText(find.byType(TextField), '192.168.1.5:5000');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(settings.serverUrl, 'http://192.168.1.5:5000');
    expect(settings.usesCustomServer, true);

    await tester.tap(find.text('Use built-in address'));
    await tester.pump();

    expect(settings.usesCustomServer, false);
    expect(settings.serverUrl, AppSettings.defaultServerUrl);
  });
}
