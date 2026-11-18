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

// Shown on every launch: the logo in its own colors on the page color of the
// saved theme (light on a fresh install, dark if the farmer chose dark). The
// logo fades and grows in, then the onboarding fades in. After the first time
// (or once signed in) it goes straight to the home screen instead.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _hold = Duration(milliseconds: 300); // before the logo comes in
  static const _fade = Duration(milliseconds: 700);
  static const _afterFade = Duration(
    milliseconds: 1100,
  ); // the logo stays a moment

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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyleFor(Theme.of(context).brightness),
      child: Scaffold(
        backgroundColor: context.colors.canvas,
        body: Center(
          child: AnimatedBuilder(
            animation: _curve,
            builder: (context, child) => Opacity(
              opacity: _curve.value,
              child: Transform.scale(
                scale: 0.9 + 0.1 * _curve.value,
                child: child,
              ),
            ),
            // the logo's own colors, not a silhouette
            child: Image.asset(
              IntroAssets.logo,
              width: 120,
              height: 120,
              errorBuilder: (context, error, stack) =>
                  Icon(Icons.eco, size: 96, color: context.colors.accent),
            ),
          ),
        ),
      ),
    );
  }
}
