import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/dashboard_stats.dart';
import '../services/label_service.dart';
import '../theme/app_colors.dart';
import 'disease_badge.dart';

// Heat map of the places where the farmer scanned. Every scan adds a soft
// circle in the color of its condition, so places with many scans glow
// stronger. A dot sits on each place, with a number when several scans were
// taken at the same spot.
//
// The street map comes from OpenStreetMap, so it needs internet. flutter_map
// keeps the tiles it has already shown, so places seen before still load
// offline; anywhere else the circles and dots still show on a plain background.
class ScanHeatMap extends StatelessWidget {
  final List<DashboardScan> scans; // only scans with GPS
  final double? height; // null = fill the space it is given
  final bool interactive; // false for the small preview on the dashboard

  const ScanHeatMap({
    super.key,
    required this.scans,
    this.height,
    this.interactive = true,
  });

  // Heat circle sizes in meters: a wide faint one and a smaller stronger one
  static const _outerRadius = 120.0;
  static const _innerRadius = 45.0;

  @override
  Widget build(BuildContext context) {
    final spots = _groupBySpot(scans);

    final map = FlutterMap(
      options: MapOptions(
        backgroundColor: context.colors.surface2,
        initialCenter: _center(scans),
        initialZoom: 16,
        initialCameraFit: _fitsOnePlace(scans)
            ? null
            : CameraFit.coordinates(
                coordinates: [
                  for (final scan in scans)
                    LatLng(scan.latitude, scan.longitude),
                ],
                padding: const EdgeInsets.all(40),
                maxZoom: 17,
              ),
        interactionOptions: InteractionOptions(
          // turning the map around only confuses, north stays up
          flags: interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          // OpenStreetMap asks every app to say who it is
          userAgentPackageName: 'com.example.pinepal_mobile',
        ),
        CircleLayer(
          circles: [
            for (final scan in scans) ...[
              _heatCircle(context, scan, _outerRadius, 0.12),
              _heatCircle(context, scan, _innerRadius, 0.22),
            ],
          ],
        ),
        MarkerLayer(
          markers: [
            for (final spot in spots)
              Marker(
                point: spot.point,
                width: 30,
                height: 30,
                child: _SpotDot(spot: spot),
              ),
          ],
        ),
        const SimpleAttributionWidget(
          source: Text('OpenStreetMap contributors'),
        ),
      ],
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: height == null ? map : SizedBox(height: height, child: map),
    );
  }

  CircleMarker _heatCircle(
    BuildContext context,
    DashboardScan scan,
    double radius,
    double strength,
  ) {
    final color = diseaseColors[scan.label] ?? context.colors.textMuted;
    return CircleMarker(
      point: LatLng(scan.latitude, scan.longitude),
      radius: radius,
      useRadiusInMeter: true,
      color: color.withValues(alpha: strength),
    );
  }
}

// The full screen heat map, opened from the dashboard card
class ScanHeatMapScreen extends StatelessWidget {
  final List<DashboardScan> scans;

  const ScanHeatMapScreen({super.key, required this.scans});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Heat Map')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: ScanHeatMap(scans: scans),
      ),
    );
  }
}

// All the scans taken at the same place (same spot to about one meter)
class _Spot {
  final LatLng point;
  final List<DashboardScan> scans = [];

  _Spot(this.point);
}

List<_Spot> _groupBySpot(List<DashboardScan> scans) {
  final spots = <String, _Spot>{};
  for (final scan in scans) {
    final key =
        '${scan.latitude.toStringAsFixed(5)},${scan.longitude.toStringAsFixed(5)}';
    spots
        .putIfAbsent(key, () => _Spot(LatLng(scan.latitude, scan.longitude)))
        .scans
        .add(scan);
  }
  return spots.values.toList();
}

// Middle of all the scans, used when they are all at about one place
LatLng _center(List<DashboardScan> scans) {
  if (scans.isEmpty) return const LatLng(0, 0);
  var lat = 0.0;
  var lng = 0.0;
  for (final scan in scans) {
    lat += scan.latitude;
    lng += scan.longitude;
  }
  return LatLng(lat / scans.length, lng / scans.length);
}

// True when every scan is within about 50 m of the others. Fitting the camera
// to such a tiny area does not work, so the map just centres on it instead.
bool _fitsOnePlace(List<DashboardScan> scans) {
  if (scans.length < 2) return true;
  var minLat = scans.first.latitude, maxLat = minLat;
  var minLng = scans.first.longitude, maxLng = minLng;
  for (final scan in scans) {
    if (scan.latitude < minLat) minLat = scan.latitude;
    if (scan.latitude > maxLat) maxLat = scan.latitude;
    if (scan.longitude < minLng) minLng = scan.longitude;
    if (scan.longitude > maxLng) maxLng = scan.longitude;
  }
  return maxLat - minLat < 0.0005 && maxLng - minLng < 0.0005;
}

// One place on the map: a dot in the color of the latest scan there, with the
// number of scans when there is more than one. Tap it to see what was found.
class _SpotDot extends StatelessWidget {
  final _Spot spot;

  const _SpotDot({required this.spot});

  @override
  Widget build(BuildContext context) {
    final latest = spot.scans.reduce(
      (a, b) => a.scannedAt.isAfter(b.scannedAt) ? a : b,
    );
    final color = diseaseColors[latest.label] ?? context.colors.textMuted;
    final count = spot.scans.length;

    // "3 scans here: 2 Crown Rot, 1 No Disease"
    final perLabel = <String, int>{};
    for (final scan in spot.scans) {
      perLabel[scan.label] = (perLabel[scan.label] ?? 0) + 1;
    }
    final details = perLabel.entries
        .map((e) => '${e.value} ${LabelService.pretty(e.key)}')
        .join('\n');
    final message = count == 1 ? details : '$count scans here:\n$details';

    return Tooltip(
      triggerMode: TooltipTriggerMode.tap,
      message: message,
      child: Center(
        child: Container(
          width: count == 1 ? 18 : 26,
          height: count == 1 ? 18 : 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            // ring in the card color so the dot stands out on any part of the map
            border: Border.all(color: context.colors.surface, width: 2),
          ),
          child: count == 1
              ? null
              : Text(
                  '$count',
                  // white reads well on every disease color
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}
