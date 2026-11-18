import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';

// A real heat map layer for flutter_map, made the same way as the website's
// (leaflet.heat): every point is a soft blurred spot, overlapping spots add up,
// and the total is colored from blue (few) through green, yellow and orange to
// red (many). Same settings as the web: radius 25 px, blur 18 px, max zoom 14,
// minimum opacity 0.35, the same color stops.
//
// The heat is drawn as a picture laid over the map at its place, for the
// screen and half a screen around it, so panning is free; it is drawn again
// when the zoom changes by a step or the map moves past that area.
// It needs no internet: it is drawn on the phone.

const _radius = 25.0;
const _blur = 18.0;
const _maxZoom = 14.0;
const _minOpacity = 0.35;
final _stops = <double, Color>{
  0.2: Color(0xFF2563EB),
  0.4: Color(0xFF16A34A),
  0.6: Color(0xFFEAB308),
  0.8: Color(0xFFF97316),
  1.0: Color(0xFFDC2626),
};

// 256 colors, one for each amount of heat (0 = none, 255 = most)
final List<Color> _palette = () {
  final keys = _stops.keys.toList();
  return List<Color>.generate(256, (i) {
    final t = i / 255;
    if (t <= keys.first) return _stops[keys.first]!;
    for (var k = 1; k < keys.length; k++) {
      if (t <= keys[k]) {
        final f = (t - keys[k - 1]) / (keys[k] - keys[k - 1]);
        return Color.lerp(_stops[keys[k - 1]], _stops[keys[k]], f)!;
      }
    }
    return _stops[keys.last]!;
  });
}();

// One spot's strength from its center outwards: full inside, then a smooth
// fall-off over the blur, like a canvas shadow blur
final int _reach = (_radius + _blur).ceil();
final List<double> _falloff = List<double>.generate(_reach + 1, (d) {
  final inner = _radius - _blur / 2;
  if (d <= inner) return 1;
  final t = ((d - inner) / (_reach - inner)).clamp(0.0, 1.0);
  // smoothstep down to 0
  return 1 - t * t * (3 - 2 * t);
});

class DensityHeatLayer extends StatefulWidget {
  final List<LatLng> points;

  const DensityHeatLayer({super.key, required this.points});

  @override
  State<DensityHeatLayer> createState() => _DensityHeatLayerState();
}

class _HeatPicture {
  final int zoom;
  final Rect area; // in map pixels at [zoom]
  final LatLngBounds? bounds; // null = no heat in this area
  final MemoryImage? image;
  const _HeatPicture(this.zoom, this.area, this.bounds, this.image);
}

class _DensityHeatLayerState extends State<DensityHeatLayer> {
  // the heat last drawn: for one zoom step and an area around what was on
  // screen, so panning within it costs nothing
  _HeatPicture? _picture;

  @override
  void didUpdateWidget(DensityHeatLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_samePoints(oldWidget.points, widget.points)) _picture = null;
  }

  static bool _samePoints(List<LatLng> a, List<LatLng> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // What is on screen, in map pixels at zoom z
  static Rect _visible(MapCamera camera, double z) {
    final b = camera.visibleBounds;
    final a = camera.projectAtZoom(b.northWest, z);
    final c = camera.projectAtZoom(b.southEast, z);
    return Rect.fromPoints(a, c);
  }

  // Draws the heat for zoom step [zoom] in the screen area and half a screen
  // around it (only where there are points)
  _HeatPicture _draw(MapCamera camera, int zoom, Rect visible) {
    final z = zoom.toDouble();
    final area = visible.inflate(math.max(visible.width, visible.height) / 2);
    final pixels = [
      for (final p in widget.points) camera.projectAtZoom(p, z),
    ].where((p) => area.inflate(_reach.toDouble()).contains(p)).toList();
    if (pixels.isEmpty) return _HeatPicture(zoom, area, null, null);

    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final p in pixels) {
      minX = math.min(minX, p.dx);
      minY = math.min(minY, p.dy);
      maxX = math.max(maxX, p.dx);
      maxY = math.max(maxY, p.dy);
    }
    // the points' area plus each spot's reach, but no bigger than the area
    minX = math.max(minX - _reach, area.left);
    minY = math.max(minY - _reach, area.top);
    maxX = math.min(maxX + _reach, area.right);
    maxY = math.min(maxY + _reach, area.bottom);
    final width = (maxX - minX).ceil() + 1;
    final height = (maxY - minY).ceil() + 1;

    // how strong one scan is at this zoom (leaflet.heat: weaker when zoomed out)
    final strength = math.max(
      1 / math.pow(2, math.max(0, math.min(_maxZoom - z, 12))),
      _minOpacity,
    );

    // add the spots up the way a canvas does: a = a + s * (1 - a)
    final alpha = Float32List(width * height);
    for (final p in pixels) {
      final cx = (p.dx - minX).round();
      final cy = (p.dy - minY).round();
      for (var dy = -_reach; dy <= _reach; dy++) {
        final y = cy + dy;
        if (y < 0 || y >= height) continue;
        for (var dx = -_reach; dx <= _reach; dx++) {
          final x = cx + dx;
          if (x < 0 || x >= width) continue;
          final d = math.sqrt(dx * dx + dy * dy).round();
          if (d > _reach) continue;
          final s = strength * _falloff[d];
          final i = y * width + x;
          alpha[i] = alpha[i] + s * (1 - alpha[i]);
        }
      }
    }

    final picture = img.Image(width: width, height: height, numChannels: 4);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final a = alpha[y * width + x];
        if (a <= 0.01) {
          picture.setPixelRgba(x, y, 0, 0, 0, 0);
          continue;
        }
        final c = _palette[(a * 255).round().clamp(0, 255)];
        picture.setPixelRgba(
          x,
          y,
          (c.r * 255).round(),
          (c.g * 255).round(),
          (c.b * 255).round(),
          (a * 255).round().clamp(0, 255),
        );
      }
    }

    final topLeft = camera.unprojectAtZoom(Offset(minX, minY), z);
    final bottomRight = camera.unprojectAtZoom(
      Offset(minX + width, minY + height),
      z,
    );
    return _HeatPicture(
      zoom,
      area,
      LatLngBounds(topLeft, bottomRight),
      MemoryImage(img.encodePng(picture)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    if (widget.points.isEmpty) return const SizedBox.shrink();
    final zoom = camera.zoom.round();
    final visible = _visible(camera, zoom.toDouble());
    var picture = _picture;
    if (picture == null ||
        picture.zoom != zoom ||
        !picture.area.contains(visible.topLeft) ||
        !picture.area.contains(visible.bottomRight)) {
      picture = _picture = _draw(camera, zoom, visible);
    }
    if (picture.image == null) return const SizedBox.shrink();
    return OverlayImageLayer(
      overlayImages: [
        OverlayImage(
          bounds: picture.bounds!,
          imageProvider: picture.image!,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
        ),
      ],
    );
  }
}
