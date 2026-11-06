import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'intro_widgets.dart';
import 'welcome_screen.dart';

// A blank screen with a small spinner for a moment after "Get Started", then
// the welcome screen.
class IntroLoadingScreen extends StatefulWidget {
  const IntroLoadingScreen({super.key});

  @override
  State<IntroLoadingScreen> createState() => _IntroLoadingScreenState();
}

class _IntroLoadingScreenState extends State<IntroLoadingScreen> {
  static const _wait = Duration(milliseconds: 1000);

  @override
  void initState() {
    super.initState();
    Future.delayed(_wait, () {
      if (!mounted) return;
      Navigator.pushReplacement(context, introFadeRoute(const WelcomeScreen()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return IntroPage(
      body: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: context.colors.accent,
          ),
        ),
      ),
    );
  }
}
