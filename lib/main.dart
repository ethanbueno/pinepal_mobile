import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'screens/intro/splash_screen.dart';
import 'services/app_settings.dart';
import 'services/auth_controller.dart';
import 'services/map_tile_cache.dart';
import 'services/sync_controller.dart';
import 'theme/app_scroll_behavior.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'theme/theme_fade.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    ThemeController.load(),
    AppSettings.instance.load(),
    AuthController.instance.load(),
    MapTileCache.init(), // before any map is built
  ]);
  runApp(const PinePalApp());
  SyncController.instance.init();
}

class PinePalApp extends StatelessWidget {
  // false skips the splash and onboarding and opens the home screen (tests)
  final bool showIntro;

  const PinePalApp({super.key, this.showIntro = true});

  @override
  Widget build(BuildContext context) {
    // ThemeFade crossfades the old look into the new one when the theme changes
    return ThemeFade(
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeController.instance,
        builder: (context, mode, _) {
          return MaterialApp(
            title: 'PinePal',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(Brightness.light),
            darkTheme: buildTheme(Brightness.dark),
            themeMode: mode,
            // Switch the theme in one rebuild. The default 200 ms theme animation
            // rebuilds the whole app on every frame (the Home dashboard and its
            // map too), which felt laggy; ThemeFade does a cheap crossfade instead.
            themeAnimationDuration: Duration.zero,
            scrollBehavior: const AppScrollBehavior(),
            // Status bar icons follow the theme on every screen, including the
            // ones without an app bar
            builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
              value: overlayStyleFor(Theme.of(context).brightness),
              child: child!,
            ),
            home: showIntro ? const SplashScreen() : const HomeScreen(),
          );
        },
      ),
    );
  }
}
