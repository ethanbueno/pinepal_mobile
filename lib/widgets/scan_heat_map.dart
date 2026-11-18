import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/dashboard_stats.dart';
import '../theme/app_colors.dart';
import '../utils/map_area.dart';
import 'heat_halo_layer.dart';

// Heat map of the places where the farmer scanned, the same as the website's
// (heat_halo_layer.dart): every scan is a dot in its disease color with a soft
// glow under it, colored green to red (fixed 10% bands) by the share of scans
// nearby with a disease. Tap a dot to see what it was.
//
// The map is locked to Echague, like the maps on the website (see
// lib/utils/map_area.dart). Scans taken outside it are left off the map.
//
// The street map comes from OpenStreetMap, so it needs internet. flutter_map
// keeps the tiles it has already shown, so places seen before still load
// offline; anywhere else the circles and dots still show on a plain background.
class ScanHeatMap extends StatefulWidget {
  final List<DashboardScan> scans; // only scans with GPS
  final double? height; // null = fill the space it is given
  final bool interactive; // false for the small preview on the dashboard
  // Opens zoomed in on this place instead of the whole town (one scan's
  // report). Null = the whole town.
  final LatLng? focus;

  const ScanHeatMap({
    super.key,
    required this.scans,
    this.height,
    this.interactive = true,
    this.focus,
  });

  // How close a focused map opens: a few streets around the spot
  static const focusZoom = 15.0;

  @override
  State<ScanHeatMap> createState() => _ScanHeatMapState();
}

class _ScanHeatMapState extends State<ScanHeatMap> {
  // Set when a map tile could not be downloaded (no internet), so the map
  // can say why the background is empty
  bool _tilesFailed = false;

  void _onTileError(TileImage tile, Object error, StackTrace? stackTrace) {
    if (!_tilesFailed && mounted) setState(() => _tilesFailed = true);
  }

  @override
  Widget build(BuildContext context) {
    // only the scans inside the locked area, so far away ones can't pull the map off Echague
    final scans = widget.scans
        .where((scan) => isInLockedArea(scan.latitude, scan.longitude))
        .toList();
    final interactive = widget.interactive;
    final height = widget.height;

    // The size is needed to know how far out the map may zoom: no further
    // than the whole of Echague, like on the website
    final map = LayoutBuilder(
      builder: (context, constraints) => FlutterMap(
        options: MapOptions(
          // painted outside Echague too, so only the town is ever seen
          backgroundColor: context.colors.canvas,
          // opens on the whole town, like the Disease Map on the web
          initialCenter: widget.focus ?? lockedAreaCenter,
          initialZoom: widget.focus == null
              ? zoomToFitLockedArea(constraints.biggest)
              : ScanHeatMap.focusZoom,
          minZoom: zoomToFitLockedArea(constraints.biggest),
          maxZoom: lockedAreaMaxZoom,
          cameraConstraint: const LockToArea(),
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
            errorTileCallback: _onTileError,
          ),
          PolygonLayer(
            polygons: [
              // everything outside Echague is painted over with the page color
              Polygon(
                points: maskOutline,
                holePointsList: const [lockedAreaOutline],
                color: context.colors.canvas,
              ),
              // the town border, in the same amber as the web map
              Polygon(
                points: lockedAreaOutline,
                borderColor: context.colors.accent,
                borderStrokeWidth: 3,
              ),
            ],
          ),
          HeatHaloLayer(scans: scans),
          const SimpleAttributionWidget(
            source: Text('OpenStreetMap contributors'),
          ),
        ],
      ),
    );

    final mapWithNotice = Stack(
      children: [
        map,
        // the color bands, on the full-size map only (the preview is too small)
        if (interactive)
          Positioned(
            top: AppSpacing.sm,
            right: AppSpacing.sm,
            width: 190,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  border: Border.all(color: context.colors.line),
                ),
                child: const HeatLegend(),
              ),
            ),
          ),
        if (_tilesFailed)
          Positioned(
            left: AppSpacing.sm,
            right: AppSpacing.sm,
            bottom: AppSpacing.sm,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  border: Border.all(color: context.colors.line),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      size: 18,
                      color: context.colors.textMuted,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Expanded(
                      child: Text(
                        'The street map needs internet. Your scan spots are '
                        'still shown.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: height == null
          ? mapWithNotice
          : SizedBox(height: height, child: mapWithNotice),
    );
  }
}

// The full screen heat map, opened from the dashboard card
class ScanHeatMapScreen extends StatelessWidget {
  final List<DashboardScan> scans;
  final String title;
  final LatLng? focus; // see ScanHeatMap.focus

  const ScanHeatMapScreen({
    super.key,
    required this.scans,
    this.title = 'Scan Heat Map',
    this.focus,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: ScanHeatMap(scans: scans, focus: focus),
      ),
    );
  }
}

// All the scans taken at the same place (same spot to about one meter)
