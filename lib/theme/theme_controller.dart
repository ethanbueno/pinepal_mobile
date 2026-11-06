import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Light, dark, or the same as the device (ThemeMode.system), remembered between
// launches. Light is the default, like the web.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController._(super.value);

  static const _key = 'theme';
  static final instance = ThemeController._(ThemeMode.light);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      instance.value = switch (prefs.getString(_key)) {
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light,
      };
    } catch (_) {
      // storage unavailable; keep the default for this launch
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name); // 'light', 'dark' or 'system'
    } catch (_) {
      // theme still applies for this launch
    }
  }

  // The quick switch on the home screen: the opposite of what is showing now,
  // which with "Device" is whatever the device is using
  Future<void> toggle(Brightness showing) =>
      setMode(showing == Brightness.dark ? ThemeMode.light : ThemeMode.dark);
}
