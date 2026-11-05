import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/dashboard_stats.dart';
import '../services/label_service.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import 'disease_badge.dart';

// Map of the places where the farmer scanned, one dot per scan in the color of
// its condition (same colors as the web Disease Map).
//
// The street map comes from OpenStreetMap, so it needs internet. flutter_map
// keeps the tiles it has already shown, so places seen before still load
// offline; anywhere else the dots still show, on a plain background.
class ScanSpotsMap extends StatelessWidget {
  final List<DashboardScan> scans; // only scans with GPS
  final double height;

  const ScanSpotsMap({super.key, required this.scans, this.height = 280});

  @override
  Widget build(BuildContext context) {
    final points = scans
        .map((scan) => LatLng(scan.latitude, scan.longitude))
        .toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(
            backgroundColor: context.colors.surface2,
            // Zoom so every dot fits; a single spot zooms in to the farm
            initialCameraFit: CameraFit.coordinates(
              coordinates: points,
              padding: const EdgeInsets.all(32),
              maxZoom: 17,
            ),
            interactionOptions: const InteractionOptions(
              // turning the map around only confuses, north stays up
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              // OpenStreetMap asks every app to say who it is
              userAgentPackageName: 'com.example.pinepal_mobile',
            ),
            MarkerLayer(
              markers: [
                for (final scan in scans)
                  Marker(
                    point: LatLng(scan.latitude, scan.longitude),
                    width: 22,
                    height: 22,
                    child: _Dot(scan: scan),
                  ),
              ],
            ),
            const SimpleAttributionWidget(
              source: Text('OpenStreetMap contributors'),
            ),
          ],
        ),
      ),
    );
  }
}

// One scan on the map. Tap it to see what it was and when.
class _Dot extends StatelessWidget {
  final DashboardScan scan;

  const _Dot({required this.scan});

  @override
  Widget build(BuildContext context) {
    final color = diseaseColors[scan.label] ?? context.colors.textMuted;
    return Tooltip(
      triggerMode: TooltipTriggerMode.tap,
      message:
          '${LabelService.pretty(scan.label)}\n${formatDateTime(scan.scannedAt)}',
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          // white ring so the dot stands out on any part of the map
          border: Border.all(color: context.colors.surface, width: 2),
        ),
      ),
    );
  }
}
