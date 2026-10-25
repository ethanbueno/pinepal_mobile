import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'theme/app_scroll_behavior.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.load();
  runApp(const PinePalApp());
}

class PinePalApp extends StatelessWidget {
  const PinePalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'PinePal',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: mode,
          scrollBehavior: const AppScrollBehavior(),
          // Status bar icons follow the theme on every screen, including the
          // ones without an app bar
          builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: overlayStyleFor(Theme.of(context).brightness),
            child: child!,
          ),
          home: const HomeScreen(),
        );
      },
    );
  }
}
