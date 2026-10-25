import 'package:flutter/services.dart' show rootBundle;

/// Reads the same labels.txt the model uses, so the verification dropdown can
/// never drift out of sync with the model's classes.
class LabelService {
  static const String assetPath = 'assets/models/labels.txt';

  static List<String>? _cache;

  static Future<List<String>> load() async {
    if (_cache != null) return _cache!;

    final raw = await rootBundle.loadString(assetPath);
    _cache = raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    return _cache!;
  }

  /// "Crown_Rot_Disease" -> "Crown Rot Disease", for display only.
  static String pretty(String label) => label.replaceAll('_', ' ');
}