import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Light or dark, remembered between launches. Light is the default, like the web.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController._(super.value);

  static const _key = 'theme';
  static final instance = ThemeController._(ThemeMode.light);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      instance.value = prefs.getString(_key) == 'dark'
          ? ThemeMode.dark
          : ThemeMode.light;
    } catch (_) {
      // storage unavailable; keep the default for this launch
    }
  }

  Future<void> toggle() async {
    value = value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, value == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {
      // theme still applies for this launch
    }
  }
}
