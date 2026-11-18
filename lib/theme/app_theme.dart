import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

// Status bar and navigation bar icons that stay readable on the page color.
// Screens with their own background (the camera) pass it as [background].
SystemUiOverlayStyle overlayStyleFor(
  Brightness brightness, {
  Color? background,
}) {
  final dark = brightness == Brightness.dark;
  final icons = dark ? Brightness.light : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: icons,
    statusBarBrightness: brightness, // iOS: brightness of the bar background
    systemNavigationBarColor:
        background ?? (dark ? AppPalette.dark.canvas : AppPalette.light.canvas),
    systemNavigationBarIconBrightness: icons,
  );
}

// Builds the light or dark ThemeData from the web tokens.
ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final p = dark ? AppPalette.dark : AppPalette.light;

  final controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.control),
  );
  const buttonText = TextStyle(
    fontFamily: 'Geist',
    fontWeight: FontWeight.w500,
    fontSize: 15,
  );

  OutlineInputBorder inputBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.control),
    borderSide: BorderSide(color: color),
  );

  final base = ThemeData(
    brightness: brightness,
    useMaterial3: true,
    fontFamily: 'Geist',
  );

  return base.copyWith(
    extensions: [p],
    scaffoldBackgroundColor: p.canvas,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: p.accent,
      onPrimary: p.onAccent,
      secondary: p.accent,
      onSecondary: p.onAccent,
      surface: p.surface,
      onSurface: p.text,
      error: p.danger,
      onError: Colors.white,
      outline: p.line,
      surfaceContainerHighest: p.surface2,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: 'Geist',
      bodyColor: p.text,
      displayColor: p.text,
    ),
    dividerColor: p.line,
    dividerTheme: DividerThemeData(color: p.line, thickness: 1),
    iconTheme: IconThemeData(color: p.text),

    // Top bar: card color with a thin line under it
    appBarTheme: AppBarTheme(
      backgroundColor: p.surface,
      foregroundColor: p.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: Border(bottom: BorderSide(color: p.line)),
      titleTextStyle: TextStyle(
        fontFamily: 'Geist',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: p.text,
      ),
      systemOverlayStyle: overlayStyleFor(brightness),
    ),

    // Manual / Automatic and similar choices
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: p.textMuted,
        selectedBackgroundColor: p.accent.withValues(alpha: 0.15),
        selectedForegroundColor: p.accentText,
        side: BorderSide(color: p.line),
        shape: controlShape,
        textStyle: buttonText,
      ),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? p.onAccent : p.textMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? p.accent : p.surface2,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? p.accent : p.line,
      ),
    ),

    // Main buttons: amber fill, dark text
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        disabledBackgroundColor: p.surface2,
        disabledForegroundColor: p.textMuted,
        elevation: 0,
        shape: controlShape,
        textStyle: buttonText,
      ),
    ),

    // Secondary buttons: page-colored fill with a border
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: dark ? p.surface2 : p.canvas,
        foregroundColor: p.text,
        side: BorderSide(color: p.line),
        shape: controlShape,
        textStyle: buttonText,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.accentText,
        shape: controlShape,
        textStyle: buttonText,
      ),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: p.text, shape: controlShape),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? p.surface2.withValues(alpha: 0.3) : Colors.transparent,
      hintStyle: TextStyle(color: p.textMuted),
      border: inputBorder(p.line),
      enabledBorder: inputBorder(p.line),
      focusedBorder: inputBorder(p.accent),
    ),

    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: p.line),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: p.line),
      ),
      titleTextStyle: TextStyle(
        fontFamily: 'Geist',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: p.text,
      ),
    ),

    // The calendar in PinePal's own style, like the web's DatePicker
    // (src/components/DatePicker.jsx): the page colors, rounded day cells,
    // the chosen days in amber with dark text, today ringed in amber, and
    // the days in between a soft amber.
    datePickerTheme: () {
      final day = WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) return p.onAccent;
        if (states.contains(WidgetState.disabled)) {
          return p.textMuted.withValues(alpha: 0.4);
        }
        return p.text;
      });
      final dayFill = WidgetStateProperty.resolveWith<Color?>(
        (states) => states.contains(WidgetState.selected) ? p.accent : null,
      );
      final cellShape = WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      );
      final heading = TextStyle(
        fontFamily: 'Geist',
        fontWeight: FontWeight.w600,
        color: p.text,
      );
      return DatePickerThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: p.line),
        ),
        headerBackgroundColor: p.surface,
        headerForegroundColor: p.text,
        headerHeadlineStyle: heading.copyWith(fontSize: 24),
        headerHelpStyle: TextStyle(color: p.textMuted, fontSize: 13),
        weekdayStyle: TextStyle(
          color: p.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        dayStyle: const TextStyle(fontSize: 14),
        dayForegroundColor: day,
        dayBackgroundColor: dayFill,
        dayShape: cellShape,
        todayForegroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? p.onAccent : p.accentText,
        ),
        todayBackgroundColor: dayFill,
        todayBorder: BorderSide(color: p.accent),
        yearForegroundColor: day,
        yearBackgroundColor: dayFill,
        yearShape: cellShape,
        dividerColor: p.line,
        rangePickerBackgroundColor: p.surface,
        rangePickerSurfaceTintColor: Colors.transparent,
        rangePickerHeaderBackgroundColor: p.surface,
        rangePickerHeaderForegroundColor: p.text,
        rangePickerHeaderHeadlineStyle: heading.copyWith(fontSize: 22),
        rangePickerHeaderHelpStyle: TextStyle(color: p.textMuted, fontSize: 13),
        rangeSelectionBackgroundColor: p.accentSoft,
        rangeSelectionOverlayColor: WidgetStatePropertyAll(p.accentSoft),
        cancelButtonStyle: TextButton.styleFrom(foregroundColor: p.textMuted),
        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: p.accentText,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    }(),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      modalBackgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: p.line,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: p.line),
      ),
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        side: BorderSide(color: p.line),
      ),
    ),

    listTileTheme: ListTileThemeData(iconColor: p.textMuted, textColor: p.text),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? p.surface2 : p.text,
      contentTextStyle: TextStyle(
        fontFamily: 'Geist',
        color: dark ? p.text : p.canvas,
      ),
      actionTextColor: p.accent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        side: BorderSide(color: dark ? p.line : p.text),
      ),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent),
  );
}
