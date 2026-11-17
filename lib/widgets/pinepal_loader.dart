import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// PinePal loading indicator: an amber ring spinning around the logo.
/// Same look as the website's PinePalLoader.
///
/// Use it centered where a screen or section is loading. Size 96 for a
/// full screen, 64-72 inside a card. Small spinners inside buttons stay as
/// they are, because the logo would be too small to read there.
class PinePalLoader extends StatefulWidget {
  const PinePalLoader({
    super.key,
    this.size = 96,
    this.label,
    this.trackColor,
    this.labelColor,
  });

  final double size;

  /// Optional text under the loader, e.g. 'Loading scans...'.
  final String? label;

  /// Ring track color. Defaults to the theme's border color.
  final Color? trackColor;
  final Color? labelColor;

  @override
  State<PinePalLoader> createState() => _PinePalLoaderState();
}

class _PinePalLoaderState extends State<PinePalLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final size = widget.size;

    final loader = Semantics(
      label: widget.label ?? 'Loading',
      child: SizedBox.square(
        dimension: size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            final t = _c.value;
            final bob = reduceMotion
                ? 0.0
                : math.sin(t * 2 * math.pi) * size * 0.025;
            return Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size.square(size),
                  painter: _RingPainter(
                    t: t,
                    track: widget.trackColor ?? colors.line,
                    arc: colors.accent,
                  ),
                ),
                Transform.translate(offset: Offset(0, -bob), child: child),
              ],
            );
          },
          child: Image.asset(
            'assets/icons/loader_logo.png',
            height: size * 0.58,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );

    if (widget.label == null) return loader;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        loader,
        const SizedBox(height: 12),
        Text(
          widget.label!,
          style: TextStyle(
            fontSize: 14,
            color: widget.labelColor ?? colors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.t, required this.track, required this.arc});

  final double t; // 0..1 through one loop
  final Color track;
  final Color arc;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.05;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.width - stroke) / 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = track);

    // the arc turns once per loop and stretches between ~75 and ~140 degrees
    final start = t * 2 * math.pi - math.pi / 2;
    final s = math.sin(t * math.pi);
    final sweep = (75 + 65 * s * s) * math.pi / 180;
    canvas.drawArc(rect, start, sweep, false, paint..color = arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.t != t || old.track != track || old.arc != arc;
}
