import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/server_scan.dart';
import 'api_client.dart';
import 'auth_controller.dart';

// The last scans the server sent, kept per user, so the Online dashboard and
// History show the last-known copy straight away (and offline), then swap in
// fresh ones once the server answers. Cleared on sign out.
class ServerScanCache {
  // the old name, so copies saved before History used them still load
  static const _prefix = 'dashboard_cache_';

  final List<ServerScan> scans;
  final DateTime savedAt;

  const ServerScanCache(this.scans, this.savedAt);

  static Future<ServerScanCache?> load(String owner) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefix + owner);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return ServerScanCache(
        (json['scans'] as List<dynamic>)
            .map((row) => ServerScan.fromJson(row as Map<String, dynamic>))
            .toList(),
        DateTime.parse(json['saved_at'] as String),
      );
    } catch (_) {
      return null; // missing or unreadable: just wait for the server
    }
  }

  static Future<void> save(String owner, List<ServerScan> scans) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefix + owner,
        jsonEncode({
          'saved_at': DateTime.now().toIso8601String(),
          'scans': scans.map((s) => s.toJson()).toList(),
        }),
      );
    } catch (_) {
      // not saved this time; the next refresh tries again
    }
  }

  // On sign out: every user's copy, so the next person sees nothing old
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys().where((k) => k.startsWith(_prefix))) {
        await prefs.remove(key);
      }
    } catch (_) {
      // nothing more to do
    }
  }
}

// Gets the farmer's scans from the server and keeps the saved copy up to
// date. Signed in: the account's scans. Signed out: this phone's own farmer
// ID, which only exists after the first sync.
class ServerScans {
  ServerScans({ApiClient? api, AuthController? auth})
    : _api = api ?? ApiClient(),
      _auth = auth ?? AuthController.instance;

  final ApiClient _api;
  final AuthController _auth;

  // Who the saved copy belongs to: the account, or this phone's farmer ID.
  // Null when there is nobody to ask the server for.
  String? get owner {
    final user = _auth.user;
    if (user != null) return 'user_${user.id}';
    final phone = _auth.phoneFarmer;
    return phone == null ? null : 'phone_${phone.farmerId}';
  }

  Future<ServerScanCache?> saved() async {
    final who = owner;
    return who == null ? null : ServerScanCache.load(who);
  }

  // Asks the server and saves what it sends. Throws ApiException with a
  // message for the farmer when there is nobody to ask for or it fails.
  Future<List<ServerScan>> fetch() async {
    final token = _auth.token ?? _auth.phoneFarmer?.token;
    final who = owner;
    if (token == null || who == null) {
      throw const ApiException(
        'Nothing from this phone is on the server yet. Sync your scans or '
        'sign in to see them here.',
      );
    }
    final List<ServerScan> scans;
    try {
      scans = await _api.getMyScans(token: token);
    } on ApiException catch (e) {
      if (e.unauthorized) {
        throw const ApiException(
          'Sign in again to see your scans on the server.',
        );
      }
      rethrow;
    }
    await ServerScanCache.save(who, scans);
    return scans;
  }
}
