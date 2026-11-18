import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

// Building blocks of the camera screen. The scanner is always dark, so these
// use AppPalette.dark instead of the current theme.

const _glassFill = CameraColors.glassFill;
const _glassLine = CameraColors.glassLine;

// Camera picture that fills its whole box, edge to edge. CameraPreview alone
// keeps the camera's shape and leaves black bars on the sides; here the picture
// is scaled up instead, so a thin strip at the top and bottom is cut off.
class CoverCameraPreview extends StatelessWidget {
  final CameraController controller;

  const CoverCameraPreview({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        return ValueListenableBuilder<CameraValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            if (!value.isInitialized) return const SizedBox.shrink();

            // Same shape CameraPreview picks for itself
            final orientation =
                value.previewPauseOrientation ??
                value.lockedCaptureOrientation ??
                value.deviceOrientation;
            final landscape =
                orientation == DeviceOrientation.landscapeLeft ||
                orientation == DeviceOrientation.landscapeRight;
            final picture = landscape
                ? value.aspectRatio
                : 1 / value.aspectRatio;
            final area = box.maxWidth / box.maxHeight;

            return ClipRect(
              child: Transform.scale(
                scale: math.max(area / picture, picture / area),
                child: Center(child: CameraPreview(controller)),
              ),
            );
          },
        );
      },
    );
  }
}

// Round translucent button that sits on the camera picture
class GlassButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed; // null greys the button out
  final double size;
  final bool active; // lit up in the accent color, e.g. while the light is on

  const GlassButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 44,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.dark;
    return Opacity(
      opacity: onPressed == null ? 0.4 : 1,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: active ? p.accent : _glassFill,
          shape: CircleBorder(
            side: BorderSide(color: active ? p.accent : _glassLine),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                icon,
                size: size * 0.5,
                color: active ? p.onAccent : CameraColors.foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Glass button with its name underneath (Gallery, History)
class GlassAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const GlassAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassButton(icon: icon, tooltip: label, onPressed: onPressed, size: 56),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: CameraColors.foregroundSoft,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// The big capture button: white ring, accent center, shrinks a little when
// pressed and shows a spinner while the photo is being taken.
class ShutterButton extends StatefulWidget {
  final VoidCallback? onPressed; // null while the camera is not ready
  final bool busy;

  const ShutterButton({super.key, required this.onPressed, this.busy = false});

  @override
  State<ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<ShutterButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.dark;
    final ready = widget.onPressed != null;
    final pressable = ready && !widget.busy;

    return Semantics(
      button: true,
      enabled: pressable,
      label: 'Take Photo',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: pressable ? (_) => setState(() => _down = true) : null,
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _down ? 0.92 : 1,
          duration: const Duration(milliseconds: 100),
          child: Container(
            width: 84,
            height: 84,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: CameraColors.foreground.withValues(
                  alpha: ready ? 1 : 0.4,
                ),
                width: 4,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ready ? p.accent : p.surface2,
              ),
              child: widget.busy
                  ? Padding(
                      padding: const EdgeInsets.all(22),
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: p.onAccent,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

// Rounded corner marks that show where to put the fruit. The model looks at
// the whole photo, so nothing outside the frame is dimmed.
class ViewfinderFrame extends StatelessWidget {
  final bool tight; // pulled in a little while the photo is taken

  const ViewfinderFrame({super.key, this.tight = false});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) {
          // A little taller than wide, like a pineapple with its crown
          const ratio = 1.2;
          final width = math.min(
            box.maxWidth * 0.74,
            box.maxHeight * 0.78 / ratio,
          );
          return Center(
            child: AnimatedScale(
              scale: tight ? 0.96 : 1,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              child: CustomPaint(
                size: Size(width, width * ratio),
                painter: _FramePainter(AppPalette.dark.accent),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  final Color color;

  const _FramePainter(this.color);

  static const _arm = 34.0; // straight part of each corner mark
  static const _radius = 22.0; // rounded elbow

  @override
  void paint(Canvas canvas, Size size) {
    const r = _radius;
    const a = _arm;
    const quarter = math.pi / 2;
    final w = size.width;
    final h = size.height;

    // One path with four separate corner marks
    final path = Path()
      // top left
      ..moveTo(0, r + a)
      ..lineTo(0, r)
      ..arcTo(Rect.fromLTWH(0, 0, 2 * r, 2 * r), math.pi, quarter, false)
      ..lineTo(r + a, 0)
      // top right
      ..moveTo(w - r - a, 0)
      ..lineTo(w - r, 0)
      ..arcTo(
        Rect.fromLTWH(w - 2 * r, 0, 2 * r, 2 * r),
        -quarter,
        quarter,
        false,
      )
      ..lineTo(w, r + a)
      // bottom right
      ..moveTo(w, h - r - a)
      ..lineTo(w, h - r)
      ..arcTo(
        Rect.fromLTWH(w - 2 * r, h - 2 * r, 2 * r, 2 * r),
        0,
        quarter,
        false,
      )
      ..lineTo(w - r - a, h)
      // bottom left
      ..moveTo(r + a, h)
      ..lineTo(r, h)
      ..arcTo(
        Rect.fromLTWH(0, h - 2 * r, 2 * r, 2 * r),
        quarter,
        quarter,
        false,
      )
      ..lineTo(0, h - r - a);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // A soft dark outline first, so the marks stay visible on bright pictures
    canvas.drawPath(
      path,
      stroke
        ..color = CameraColors.shade
        ..strokeWidth = 7,
    );
    canvas.drawPath(
      path,
      stroke
        ..color = color
        ..strokeWidth = 4,
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.color != color;
}

// Short instruction on top of the picture
class ScannerHint extends StatelessWidget {
  final String text;

  const ScannerHint({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: CameraColors.scrim,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: _glassLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.center_focus_strong_outlined, size: 16, color: p.accent),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: CameraColors.foreground,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
