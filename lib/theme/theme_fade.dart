import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

// Quick crossfade when switching light/dark.
//
// Animating the theme itself (MaterialApp's themeAnimationDuration) rebuilds the
// whole app on every frame, which was laggy on the Home dashboard. Instead this
// takes a picture of the screen just before the switch, switches the theme in
// one rebuild, then fades the picture out on top of the new theme. Only that
// one picture is animated, so it stays smooth.
class ThemeFade extends StatefulWidget {
  final Widget child;

  const ThemeFade({super.key, required this.child});

  static const duration = Duration(milliseconds: 280);

  static _ThemeFadeState? _state;

  // Call right before changing the theme. Returns once the old look is captured
  // (or straight away when the fade is skipped).
  static Future<void> captureBeforeSwitch() async {
    final state = _state;
    if (state == null) return;
    await state._capture();
  }

  @override
  State<ThemeFade> createState() => _ThemeFadeState();
}

class _ThemeFadeState extends State<ThemeFade>
    with SingleTickerProviderStateMixin {
  final _boundaryKey = GlobalKey();
  late final AnimationController _fade;
  late final Animation<double> _opacity;
  ui.Image? _snapshot;

  @override
  void initState() {
    super.initState();
    // Created here, not lazily: a lazy controller would first be built inside
    // dispose(), where creating a ticker throws.
    _fade = AnimationController(vsync: this, duration: ThemeFade.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _clear();
      });
    _opacity = Tween(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _fade, curve: Curves.easeOutCubic));
    ThemeFade._state = this;
  }

  @override
  void dispose() {
    if (ThemeFade._state == this) ThemeFade._state = null;
    _fade.dispose();
    _snapshot?.dispose();
    super.dispose();
  }

  bool get _skip =>
      // reduced motion turned on in the phone's accessibility settings
      ui.PlatformDispatcher.instance.accessibilityFeatures.disableAnimations ||
      // widget tests: no real frames to capture
      Platform.environment.containsKey('FLUTTER_TEST');

  Future<void> _capture() async {
    if (_skip) return;
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) return;
      // debugNeedsPaint only works in debug builds: in release and profile it
      // throws (its value is set inside an assert), which used to stop the
      // theme from switching at all
      if (kDebugMode && boundary.debugNeedsPaint) return;
      final pixelRatio = View.of(context).devicePixelRatio;
      final image = await boundary
          .toImage(pixelRatio: pixelRatio)
          .timeout(const Duration(milliseconds: 250));
      if (!mounted) {
        image.dispose();
        return;
      }
      _snapshot?.dispose();
      setState(() => _snapshot = image);
      _fade.forward(from: 0);
    } catch (_) {
      // capture failed or was slow; the theme just switches without the fade
    }
  }

  void _clear() {
    final old = _snapshot;
    if (old == null) return;
    setState(() => _snapshot = null);
    old.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Stack(
      textDirection: TextDirection.ltr,
      fit: StackFit.expand,
      children: [
        RepaintBoundary(key: _boundaryKey, child: widget.child),
        if (snapshot != null)
          IgnorePointer(
            child: FadeTransition(
              opacity: _opacity,
              child: RawImage(image: snapshot, fit: BoxFit.fill),
            ),
          ),
      ],
    );
  }
}
