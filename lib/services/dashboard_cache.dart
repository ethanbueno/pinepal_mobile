import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/dashboard_stats.dart';

// The last scans the server sent for the Online dashboard, kept per user, so
// the Online view shows the last-known numbers straight away (and offline),
// then swaps in fresh ones once the server answers. Cleared on sign out.
class DashboardCache {
  static const _prefix = 'dashboard_cache_';

  final List<DashboardScan> scans;
  final DateTime savedAt;

  const DashboardCache(this.scans, this.savedAt);

  static Future<DashboardCache?> load(String owner) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefix + owner);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return DashboardCache(
        (json['scans'] as List<dynamic>)
            .map((row) => DashboardScan.fromJson(row as Map<String, dynamic>))
            .toList(),
        DateTime.parse(json['saved_at'] as String),
      );
    } catch (_) {
      return null; // missing or unreadable: just wait for the server
    }
  }

  static Future<void> save(String owner, List<DashboardScan> scans) async {
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
