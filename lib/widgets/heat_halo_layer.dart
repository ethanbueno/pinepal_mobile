import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/dashboard_stats.dart';
import '../services/label_service.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import 'disease_badge.dart';

// The heat map layer, the same as the website's Disease Map: every scan is its
// own dot (in its disease color) with a soft glow under it. A glow is colored by
// the share of diseased scans around it (scans whose dots are close on screen,
// so zoomed out it shows the area, zoomed in the spot), in fixed 10% bands from
// green to red. Overlapping glows add up, so busy diseased areas glow strongest.

const _rateStops = [
  Color(0xFF16A34A),
  Color(0xFF84CC16),
  Color(0xFFEAB308),
  Color(0xFFF97316),
  Color(0xFFDC2626),
];

Color _mix(double t) {
  final x = t.clamp(0.0, 1.0) * (_rateStops.length - 1);
  final i = math.min(x.floor(), _rateStops.length - 2);
  return Color.lerp(_rateStops[i], _rateStops[i + 1], x - i)!;
}

// band 0 = under 10% diseased ... band 9 = 90% and over (the legend uses these)
final List<Color> rateBands = [
  for (var i = 0; i < 10; i++) _mix((i + 0.5) / 10),
];

Color rateColor(double share) =>
    rateBands[math.min(9, (share.clamp(0.0, 1.0) * 10).floor())];

// how close on screen another scan must be to count towards a glow's color
const _nearbyPixels = 45.0;

class HeatHaloLayer extends StatelessWidget {
  final List<DashboardScan> scans;

  const HeatHaloLayer({super.key, required this.scans});

  @override
  Widget build(BuildContext context) {
    if (scans.isEmpty) return const SizedBox.shrink();
    final camera = MapCamera.of(context);
    final zoom = camera.zoom.roundToDouble();
    final pixels = [
      for (final s in scans)
        camera.projectAtZoom(LatLng(s.latitude, s.longitude), zoom),
    ];

    Color glowOf(int i) {
      var near = 0, diseased = 0;
      for (var j = 0; j < scans.length; j++) {
        if ((pixels[j] - pixels[i]).distance < _nearbyPixels) {
          near++;
          if (scans[j].label != 'No_Disease') diseased++;
        }
      }
      return rateColor(diseased / near);
    }

    return Stack(
      children: [
        // the glows, under every dot
        MarkerLayer(
          markers: [
            for (var i = 0; i < scans.length; i++)
              Marker(
                point: LatLng(scans[i].latitude, scans[i].longitude),
                width: 90,
                height: 90,
                child: IgnorePointer(child: _Glow(color: glowOf(i))),
              ),
          ],
        ),
        MarkerLayer(
          markers: [
            for (final scan in scans)
              Marker(
                point: LatLng(scan.latitude, scan.longitude),
                width: 30,
                height: 30,
                child: _ScanDot(scan: scan),
              ),
          ],
        ),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  const _Glow({required this.color});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.12),
            color.withValues(alpha: 0.045),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.25, 0.5, 0.7],
        ),
      ),
    );
  }
}

// One scan's dot, in its disease color; tap it for what it was and when
class _ScanDot extends StatelessWidget {
  final DashboardScan scan;

  const _ScanDot({required this.scan});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      triggerMode: TooltipTriggerMode.tap,
      message:
          '${LabelService.pretty(scan.label)}\n${formatDateTime(scan.scannedAt)}',
      child: Center(
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: diseaseColors[scan.label] ?? context.colors.textMuted,
            shape: BoxShape.circle,
            // a thin white ring so the dot stands out on its glow
            border: Border.all(color: Colors.white, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x59000000),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// The legend: the glow's 10% bands, then what the dots are
class HeatLegend extends StatelessWidget {
  const HeatLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(color: context.colors.textMuted, fontSize: 11);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Glow: Scans with a Disease Nearby',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Row(
            children: [
              for (final color in rateBands)
                Expanded(child: Container(height: 8, color: color)),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0%', style: muted),
            Text('50%', style: muted),
            Text('100%', style: muted),
          ],
        ),
        Text('Dots: each scan, in its disease color', style: muted),
      ],
    );
  }
}
