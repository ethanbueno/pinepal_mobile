import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/remediation_protocol.dart';

class ProtocolService {
  static const String assetPath = 'assets/data/remediation_protocols.json';

  static Map<String, RemediationProtocol>? _cache;

  static Future<Map<String, RemediationProtocol>> _load() async {
    if (_cache != null) return _cache!;

    try {
      final raw = await rootBundle.loadString(assetPath);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;

      final protocols = <String, RemediationProtocol>{};
      decoded.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          protocols[_normalize(key)] = RemediationProtocol.fromJson(key, value);
        }
      });

      _cache = protocols;
      return protocols;
    } catch (e) {
      debugPrint('ProtocolService failed to load $assetPath: $e');
      _cache = {};
      return _cache!;
    }
  }

  static Future<RemediationProtocol> getProtocolForDisease(String label) async {
    final protocols = await _load();
    return protocols[_normalize(label)] ?? RemediationProtocol.fallback(label);
  }

  /// Every protocol, for the Guide tab. The JSON order is kept.
  static Future<List<RemediationProtocol>> getAll() async {
    final protocols = await _load();
    return protocols.values.toList();
  }

  /// Matches "Black Rot", "black_rot" and "BLACK-ROT" to the same entry so a
  /// small mismatch between labels.txt and the JSON keys is not fatal.
  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
