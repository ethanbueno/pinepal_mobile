import 'package:flutter/material.dart';

// Same tokens as the PinePal web dashboard (src/index.css), light and dark,
// so the mobile app and the website look like one system.
// Read them with context.colors, they follow the current theme.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color canvas; // page background
  final Color surface; // cards, bottom bar
  final Color surface2; // muted fills: image placeholders, notices
  final Color line; // borders
  final Color text;
  final Color textMuted;
  final Color accent; // primary: buttons, icons, active tab
  final Color accentText; // accent when used as text, readable on surface
  final Color onAccent; // text/icons on top of accent
  final Color success;
  final Color danger;
  final Color warning;

  const AppPalette({
    required this.canvas,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.text,
    required this.textMuted,
    required this.accent,
    required this.accentText,
    required this.onAccent,
    required this.success,
    required this.danger,
    required this.warning,
  });

  // Accent at 15% opacity: active tab, chips, icon backgrounds
  Color get accentSoft => accent.withValues(alpha: 0.15);

  static const light = AppPalette(
    canvas: Color(0xFFFAF9F5), // --background
    surface: Color(0xFFFFFFFF), // --card
    surface2: Color(0xFFF0EEE6), // --muted
    line: Color(0xFFE3E0D5), // --border
    text: Color(0xFF141413), // --foreground
    textMuted: Color(0xFF6B6A64), // --muted-foreground
    accent: Color(0xFFF0B323), // --primary
    accentText: Color(0xFF8A5F00), // darker amber so text passes contrast
    onAccent: Color(0xFF14110A), // --primary-foreground
    success: Color(0xFF2F7D4F), // --chart-2
    danger: Color(0xFFB53333), // --destructive
    warning: Color(0xFF9A6700),
  );

  static const dark = AppPalette(
    canvas: Color(0xFF0D1117),
    surface: Color(0xFF161B22),
    surface2: Color(0xFF21262D),
    line: Color(0xFF30363D),
    text: Color(0xFFE6EDF3),
    textMuted: Color(0xFF8B949E),
    accent: Color(0xFFF2C14E),
    accentText: Color(0xFFF2C14E),
    onAccent: Color(0xFF14110A),
    success: Color(0xFF3FB950),
    danger: Color(0xFFF85149),
    warning: Color(0xFFD29922),
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      line: Color.lerp(line, other.line, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppPalette get colors => Theme.of(this).extension<AppPalette>()!;
}

// Corner radii from the web (--radius is 10px)
class AppRadius {
  static const control = 10.0; // buttons, inputs
  static const card = 14.0; // cards
  static const pill = 999.0; // badges
}

// Spacing steps, so every screen keeps the same rhythm
class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const page = 20.0; // padding around a screen
  static const section = 28.0; // space between sections
}
