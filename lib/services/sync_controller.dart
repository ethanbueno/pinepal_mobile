import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'app_settings.dart';
import 'auth_controller.dart';
import 'database_helper.dart';
import 'sync_service.dart';

// Decides when scans are sent and tells the screens what is going on.
// Signed in, scans go to the account's farmer ID. Signed out, automatic mode
// sends them under this phone's own farmer ID (made on the first such sync);
// signing in or up later connects that farmer ID to the account.
// Manual mode: only when the farmer taps "Sync Now".
// Automatic mode: by itself when the app starts, when a connection comes back,
// and after a scan is saved or edited (on Wi-Fi only, unless turned off).
class SyncController extends ChangeNotifier {
  SyncController({
    ApiClient? api,
    AuthController? auth,
    AppSettings? settings,
    DatabaseHelper? db,
    Connectivity? connectivity,
  }) : _api = api ?? ApiClient(),
       _auth = auth ?? AuthController.instance,
       _settings = settings ?? AppSettings.instance,
       _db = db ?? DatabaseHelper.instance,
       _injectedConnectivity = connectivity;

  static final instance = SyncController();

  static const _lastSyncKey = 'last_sync_at';

  final ApiClient _api;
  final AuthController _auth;
  final AppSettings _settings;
  final DatabaseHelper _db;
  final Connectivity? _injectedConnectivity;
  Connectivity? _connectivityInstance;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _syncing = false;
  int _pending = 0;
  DateTime? _lastSyncedAt;
  String? _message;
  bool _messageIsError = false;

  bool get syncing => _syncing;
  int get pending => _pending; // scans waiting to be uploaded
  DateTime? get lastSyncedAt => _lastSyncedAt;
  String? get message => _message; // result of the last run, for Settings
  bool get messageIsError => _messageIsError;

  Connectivity get _connectivity =>
      _injectedConnectivity ?? (_connectivityInstance ??= Connectivity());

  // Called once when the app starts
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastSyncedAt = DateTime.tryParse(prefs.getString(_lastSyncKey) ?? '');
    } catch (_) {
      // not remembered, only the "last synced" line is missing
    }
    await refreshPending();
    _subscription ??= _connectivity.onConnectivityChanged.listen(
      (_) => maybeAutoSync(),
    );
    await maybeAutoSync();
  }

  Future<int> refreshPending() async {
    _pending = await _db.countUnsynced();
    notifyListeners();
    return _pending;
  }

  // Call after a scan is saved, edited or deleted
  Future<void> onLocalChange() async {
    await refreshPending();
    await maybeAutoSync();
  }

  // The "Sync Now" button
  Future<void> syncNow() => _run();

  // Does nothing unless automatic mode is on, the connection is allowed and
  // something is waiting. Works signed out too, under the phone's farmer ID.
  Future<void> maybeAutoSync() async {
    if (_syncing || _settings.syncMode != SyncMode.automatic) return;
    if (!await _connectionAllowed()) return;
    if (await refreshPending() == 0) return;
    await _run();
  }

  Future<bool> _connectionAllowed() async {
    try {
      final now = await _connectivity.checkConnectivity();
      final wifi =
          now.contains(ConnectivityResult.wifi) ||
          now.contains(ConnectivityResult.ethernet);
      if (_settings.wifiOnly) return wifi;
      return wifi ||
          now.contains(ConnectivityResult.mobile) ||
          now.contains(ConnectivityResult.vpn) ||
          now.contains(ConnectivityResult.other);
    } catch (_) {
      return false;
    }
  }

  Future<void> _run() async {
    if (_syncing) return;
    _syncing = true;
    _message = null;
    notifyListeners();

    try {
      final signedIn = _auth.isSignedIn;
      final token = signedIn ? _auth.token! : (await _phoneFarmer()).token;
      final result = await SyncService(
        api: _api,
        db: _db,
        settings: _settings,
      ).syncPending(token: token);

      if (result.sessionExpired) {
        // Signed out: the phone's farmer ID was connected to an account, so a
        // new one is made next time (or the farmer signs in)
        signedIn ? await _auth.signOut() : await _auth.setPhoneFarmer(null);
      }
      if (result.uploaded > 0) await _rememberLastSync();
      _message = result.summary;
      _messageIsError = !result.ok;
    } catch (e) {
      _message = 'Sync failed: $e';
      _messageIsError = true;
    } finally {
      _syncing = false;
      await refreshPending();
    }
  }

  // This phone's own farmer ID, asked from the server the first time
  Future<PhoneFarmer> _phoneFarmer() async {
    final existing = _auth.phoneFarmer;
    if (existing != null) return existing;
    final phone = await _api.registerPhone();
    await _auth.setPhoneFarmer(phone);
    return phone;
  }

  Future<void> _rememberLastSync() async {
    _lastSyncedAt = DateTime.now();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, _lastSyncedAt!.toIso8601String());
    } catch (_) {
      // shown for this launch only
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
