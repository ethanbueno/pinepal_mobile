import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

// An intro image from assets/intro/. While the file is missing it shows a
// rounded gray box with the file name, so it is clear which image goes where.
class IntroImage extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double radius;

  const IntroImage(
    this.path, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Image.asset(
        path,
        fit: fit,
        errorBuilder: (context, error, stack) => Container(
          decoration: BoxDecoration(
            color: context.colors.surface2,
            borderRadius: BorderRadius.circular(radius),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(4),
          child: Text(
            path.split('/').last,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 9, color: context.colors.textMuted),
          ),
        ),
      ),
    );
  }
}

// The full-width pill button of the intro screens: the app's own primary
// button (amber), only taller and fully rounded
class IntroButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const IntroButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: 'Geist',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

// An intro page: the theme's page color, with status bar icons to match
class IntroPage extends StatelessWidget {
  final Widget body;

  const IntroPage({super.key, required this.body});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyleFor(Theme.of(context).brightness),
      child: Scaffold(backgroundColor: context.colors.canvas, body: body),
    );
  }
}

// A fade between intro screens
Route<T> introFadeRoute<T>(
  Widget page, {
  Duration duration = const Duration(milliseconds: 500),
}) {
  return PageRouteBuilder<T>(
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    pageBuilder: (context, animation, secondary) => page,
    transitionsBuilder: (context, animation, secondary, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}
