import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pinepal_mobile/services/app_settings.dart';
import 'package:pinepal_mobile/services/auth_controller.dart';

const juan = AuthUser(
  id: 7,
  fullName: 'Juan Dela Cruz',
  username: 'juan',
  role: 'farmer',
);

void main() {
  group('AuthController', () {
    test('signing in is remembered and signing out forgets it', () async {
      final store = MemorySessionStore();
      final auth = AuthController(store: store);
      expect(auth.isSignedIn, false);

      await auth.signIn(const AuthSession(token: 'tok', user: juan));
      expect(auth.isSignedIn, true);
      expect(auth.token, 'tok');
      expect(store.value, isNotNull);

      // A new launch finds the same account
      final next = AuthController(store: store);
      await next.load();
      expect(next.isSignedIn, true);
      expect(next.user!.username, 'juan');
      expect(next.token, 'tok');

      await next.signOut();
      expect(next.isSignedIn, false);
      expect(store.value, isNull);
    });

    test('a damaged saved session is ignored instead of crashing', () async {
      final auth = AuthController(store: MemorySessionStore()..value = '{oops');
      await auth.load();
      expect(auth.isSignedIn, false);
    });

    test('roles use the same names as the web dashboard', () {
      AuthUser withRole(String role) =>
          AuthUser(id: 1, fullName: 'A B', username: 'ab', role: role);

      expect(withRole('farmer').roleLabel, 'Farmer');
      expect(withRole('officer').roleLabel, 'Agricultural Officer');
      expect(withRole('admin').roleLabel, 'Admin');
    });

    test('initials come from the first two names', () {
      expect(juan.initials, 'JD');
      const single = AuthUser(
        id: 2,
        fullName: 'maria',
        username: 'm',
        role: 'farmer',
      );
      expect(single.initials, 'M');
      const empty = AuthUser(
        id: 3,
        fullName: '',
        username: 'x',
        role: 'farmer',
      );
      expect(empty.initials, '?');
    });
  });

  group('AppSettings', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('server addresses are tidied up', () {
      expect(
        AppSettings.cleanServerUrl('192.168.1.5:5000/'),
        'http://192.168.1.5:5000',
      );
      expect(
        AppSettings.cleanServerUrl(' https://pinepal.app// '),
        'https://pinepal.app',
      );
      expect(
        AppSettings.cleanServerUrl('http://10.0.2.2:5000'),
        'http://10.0.2.2:5000',
      );
      expect(AppSettings.cleanServerUrl('   '), AppSettings.defaultServerUrl);
    });

    test('starts with safe defaults', () {
      final settings = AppSettings();
      expect(settings.syncMode, SyncMode.manual);
      expect(settings.wifiOnly, true);
      expect(settings.municipality, 'Echague');
      expect(settings.farmName, '');
    });

    test('changes are remembered between launches', () async {
      final settings = AppSettings();
      await settings.setServerUrl('192.168.1.5:5000');
      await settings.setSyncMode(SyncMode.automatic);
      await settings.setWifiOnly(false);
      await settings.setFarmName('  Bueno Farm ');
      await settings.setMunicipality('Alicia');

      final later = AppSettings();
      await later.load();
      expect(later.serverUrl, 'http://192.168.1.5:5000');
      expect(later.syncMode, SyncMode.automatic);
      expect(later.wifiOnly, false);
      expect(later.farmName, 'Bueno Farm');
      expect(later.municipality, 'Alicia');
    });

    test(
      'the server is the built-in one unless a developer changes it',
      () async {
        final settings = AppSettings();
        expect(settings.serverUrl, AppSettings.defaultServerUrl);
        expect(settings.usesCustomServer, false);
        expect(settings.developerOptions, false);

        await settings.setServerUrl('192.168.1.5:5000');
        expect(settings.usesCustomServer, true);

        // Remembered, and removed again by resetting
        final later = AppSettings();
        await later.load();
        expect(later.serverUrl, 'http://192.168.1.5:5000');
        await later.resetServerUrl();
        expect(later.serverUrl, AppSettings.defaultServerUrl);

        final reloaded = AppSettings();
        await reloaded.load();
        expect(reloaded.usesCustomServer, false);
      },
    );

    test('typing the built-in address again goes back to using it', () async {
      final settings = AppSettings();
      await settings.setServerUrl('192.168.1.5:5000');
      await settings.setServerUrl(AppSettings.defaultServerUrl);
      expect(settings.usesCustomServer, false);
    });

    test('developer options are remembered', () async {
      final settings = AppSettings();
      await settings.setDeveloperOptions(true);

      final later = AppSettings();
      await later.load();
      expect(later.developerOptions, true);
    });

    test('a municipality that is not in the list is ignored', () async {
      final settings = AppSettings();
      await settings.setMunicipality('Atlantis');
      expect(settings.municipality, 'Echague');

      SharedPreferences.setMockInitialValues({'municipality': 'Atlantis'});
      final loaded = AppSettings();
      await loaded.load();
      expect(loaded.municipality, 'Echague');
    });
  });
}
