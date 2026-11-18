import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/municipalities.dart';

// How scans are sent to the server
enum SyncMode {
  manual, // only when the farmer taps "Sync Now"
  automatic, // by itself when there is a connection
}

// The settings a farmer can change, remembered between launches.
class AppSettings extends ChangeNotifier {
  AppSettings();

  static final instance = AppSettings();

  // The server is part of the app, not a setting for farmers. It is chosen when
  // the app is built:
  //   flutter run --dart-define=PINEPAL_API_URL=https://your-server
  // Without it, release builds (the APK farmers install) use the live server
  // on Render, so a build made without the flag still works. Debug builds talk
  // to a server on the same computer: 10.0.2.2 is how the Android emulator
  // reaches the computer it runs on. A real phone needs the laptop's Wi-Fi
  // address instead, e.g. http://192.168.1.5:5000.
  // Developers can override it in Settings > Developer (see developerOptions).
  static const liveServerUrl = 'https://pinepal-api-rebe.onrender.com';
  static const defaultServerUrl = String.fromEnvironment(
    'PINEPAL_API_URL',
    defaultValue: kReleaseMode ? liveServerUrl : 'http://10.0.2.2:5000',
  );

  static const _serverKey = 'server_url';
  static const _developerKey = 'developer_options';
  static const _modeKey = 'sync_mode';
  static const _wifiKey = 'sync_wifi_only';
  static const _farmKey = 'farm_name';
  static const _municipalityKey = 'municipality';
  static const _introSeenKey = 'intro_seen';

  String? _serverOverride; // null = use the one the app was built with
  bool _developerOptions = false;
  SyncMode _syncMode = SyncMode.manual;
  bool _wifiOnly = true; // photos are big, so do not use mobile data by default
  String _farmName = '';
  // '' until the farmer picks one, in the farm details or on their first scan
  String _municipality = '';
  bool _introSeen = false; // the onboarding and welcome screens show only once

  String get serverUrl => _serverOverride ?? defaultServerUrl;
  bool get usesCustomServer => _serverOverride != null;

  // Hidden from farmers: switched on by tapping the version in Settings
  bool get developerOptions => _developerOptions;

  SyncMode get syncMode => _syncMode;
  bool get wifiOnly => _wifiOnly;
  String get farmName => _farmName;
  String get municipality => _municipality;
  bool get introSeen => _introSeen;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _serverOverride = prefs.getString(_serverKey);
      _developerOptions = prefs.getBool(_developerKey) ?? false;
      _syncMode = prefs.getString(_modeKey) == 'automatic'
          ? SyncMode.automatic
          : SyncMode.manual;
      _wifiOnly = prefs.getBool(_wifiKey) ?? true;
      _farmName = prefs.getString(_farmKey) ?? '';
      final saved = prefs.getString(_municipalityKey);
      // Every farm is in Echague: a town saved before the lock becomes Echague
      _municipality = municipalities.contains(saved) ? scanMunicipality : '';
      if (_municipality.isNotEmpty && saved != _municipality) {
        await prefs.setString(_municipalityKey, _municipality);
      }
      _introSeen = prefs.getBool(_introSeenKey) ?? false;
      notifyListeners();
    } catch (_) {
      // storage unavailable; the defaults still work for this launch
    }
  }

  // "192.168.1.5:5000/" becomes "http://192.168.1.5:5000"
  static String cleanServerUrl(String input) {
    var url = input.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.isEmpty) return defaultServerUrl;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    return url;
  }

  // Typing the built-in address again just goes back to using it
  Future<void> setServerUrl(String value) async {
    final url = cleanServerUrl(value);
    if (url == defaultServerUrl) return resetServerUrl();
    _serverOverride = url;
    notifyListeners();
    await _save((p) => p.setString(_serverKey, url));
  }

  Future<void> resetServerUrl() async {
    _serverOverride = null;
    notifyListeners();
    await _save((p) => p.remove(_serverKey));
  }

  Future<void> setDeveloperOptions(bool value) async {
    _developerOptions = value;
    notifyListeners();
    await _save((p) => p.setBool(_developerKey, value));
  }

  Future<void> setSyncMode(SyncMode value) async {
    _syncMode = value;
    notifyListeners();
    await _save((p) => p.setString(_modeKey, value.name));
  }

  Future<void> setWifiOnly(bool value) async {
    _wifiOnly = value;
    notifyListeners();
    await _save((p) => p.setBool(_wifiKey, value));
  }

  Future<void> setFarmName(String value) async {
    _farmName = value.trim();
    notifyListeners();
    await _save((p) => p.setString(_farmKey, _farmName));
  }

  Future<void> setMunicipality(String value) async {
    if (!municipalities.contains(value)) return;
    _municipality = scanMunicipality; // locked to Echague
    notifyListeners();
    await _save((p) => p.setString(_municipalityKey, scanMunicipality));
  }

  Future<void> setIntroSeen() async {
    _introSeen = true;
    notifyListeners();
    await _save((p) => p.setBool(_introSeenKey, true));
  }

  Future<void> _save(Future<dynamic> Function(SharedPreferences) write) async {
    try {
      await write(await SharedPreferences.getInstance());
    } catch (_) {
      // the setting still applies until the app is closed
    }
  }
}
