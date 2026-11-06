import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/app_settings.dart';
import '../../services/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../home_screen.dart';
import 'intro_content.dart';
import 'intro_widgets.dart';
import 'onboarding_screen.dart';

// Shown on every launch. Black screen with the white logo; after a moment the
// background fades to the theme's page color and the logo to its text color,
// then the onboarding fades in. After the first time (or once signed in) it
// goes straight to the home screen instead.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _hold = Duration(milliseconds: 1000); // black, before the fade
  static const _fade = Duration(milliseconds: 700);
  static const _afterFade = Duration(milliseconds: 400);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _fade,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await Future.delayed(_hold);
    if (!mounted) return;
    await _controller.forward();
    await Future.delayed(_afterFade);
    if (!mounted) return;

    // The onboarding shows only the first time, until the farmer signs in or skips
    final skipIntro =
        AuthController.instance.isSignedIn || AppSettings.instance.introSeen;
    final next = skipIntro ? const HomeScreen() : const OnboardingScreen();
    Navigator.pushReplacement(context, introFadeRoute(next));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, _) {
        // black with a white logo, then the theme's page and text colors
        final t = _curve.value;
        final background = Color.lerp(Colors.black, context.colors.canvas, t)!;
        final logo = Color.lerp(Colors.white, context.colors.text, t)!;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: t < 0.5
              ? overlayStyleFor(Brightness.dark, background: Colors.black)
              : overlayStyleFor(Theme.of(context).brightness),
          child: Scaffold(
            backgroundColor: background,
            body: Center(
              child: Image.asset(
                IntroAssets.logo,
                width: 120,
                height: 120,
                color: logo,
                colorBlendMode: BlendMode.srcIn,
                errorBuilder: (context, error, stack) =>
                    Icon(Icons.eco, size: 96, color: logo),
              ),
            ),
          ),
        );
      },
    );
  }
}
