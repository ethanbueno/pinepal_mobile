import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// The area the maps are locked to, the same as on the website
// (LOCKED_MUNICIPALITY in src/utils/diseases.js and the town in src/data/isabela.js).
// Like the web, only this town is shown: everything outside its border is
// painted over, and the map can't be moved away from it.
const lockedAreaName = 'Echague, Isabela';

// Corners of Echague: south-west and north-east
final lockedAreaBounds = LatLngBounds(
  const LatLng(16.5259, 121.5973),
  const LatLng(16.7669, 122.1290),
);

const lockedAreaMaxZoom = 18.0;

bool isInLockedArea(double latitude, double longitude) {
  return lockedAreaBounds.contains(LatLng(latitude, longitude));
}

// Zoom level at which the whole of Echague just fits in a map of [size].
// The map can't zoom out further than this, like map.getBoundsZoom() on the web.
double zoomToFitLockedArea(Size size) {
  if (size.width <= 0 || size.height <= 0) return 10;
  // Web Mercator: the world is 256 px wide at zoom 0 and doubles every level
  double x(double lng) => (lng + 180) / 360;
  double y(double lat) {
    final rad = lat * math.pi / 180;
    return (1 - math.log(math.tan(rad) + 1 / math.cos(rad)) / math.pi) / 2;
  }

  final width = x(lockedAreaBounds.east) - x(lockedAreaBounds.west);
  final height = y(lockedAreaBounds.south) - y(lockedAreaBounds.north);
  final zoomForWidth = math.log(size.width / (256 * width)) / math.ln2;
  final zoomForHeight = math.log(size.height / (256 * height)) / math.ln2;
  // a little less, so the border doesn't touch the edges of the map
  return math.min(zoomForWidth, zoomForHeight) - 0.15;
}

// Keeps the map on Echague in every direction, the way Leaflet's maxBounds
// does on the web: when the screen is smaller than the town, the view stays
// inside it; when it is larger (zoomed out), the town stays centred.
// (flutter_map's own CameraConstraint.contain gives up when zoomed out, which
// let the map be dragged away in some directions.)
class LockToArea extends CameraConstraint {
  const LockToArea();

  @override
  MapCamera? constrain(MapCamera camera) {
    final zoom = camera.zoom;
    final ne = camera.projectAtZoom(lockedAreaBounds.northEast, zoom);
    final sw = camera.projectAtZoom(lockedAreaBounds.southWest, zoom);
    final half = camera.size / 2;
    final center = camera.projectAtZoom(camera.center, zoom);

    double keep(double value, double low, double high, double half) {
      // town smaller than the screen on this side: centre it
      if (high - low <= half * 2) return (low + high) / 2;
      return value.clamp(low + half, high - half);
    }

    final newCenter = Offset(
      keep(
        center.dx,
        math.min(sw.dx, ne.dx),
        math.max(sw.dx, ne.dx),
        half.width,
      ),
      keep(
        center.dy,
        math.min(sw.dy, ne.dy),
        math.max(sw.dy, ne.dy),
        half.height,
      ),
    );
    if (newCenter == center) return camera;
    return camera.withPosition(center: camera.unprojectAtZoom(newCenter, zoom));
  }
}

// Middle of the box around Echague, where the map opens
final lockedAreaCenter = lockedAreaBounds.center;

// A rectangle 3 degrees bigger than Echague on every side, used to paint over
// everything but the town. The map can never show more than this.
// (A rectangle over the whole world does not draw reliably in flutter_map.)
const maskOutline = [
  LatLng(16.5259 - 3, 121.5973 - 3),
  LatLng(16.7669 + 3, 121.5973 - 3),
  LatLng(16.7669 + 3, 122.1290 + 3),
  LatLng(16.5259 - 3, 122.1290 + 3),
];

// The border of Echague, from the same town data as the website
const lockedAreaOutline = [
  LatLng(16.5259, 121.9526),
  LatLng(16.6093, 121.9252),
  LatLng(16.6085, 121.7987),
  LatLng(16.6108, 121.7558),
  LatLng(16.6105, 121.6874),
  LatLng(16.6093, 121.6848),
  LatLng(16.6047, 121.6833),
  LatLng(16.5772, 121.637),
  LatLng(16.5791, 121.6114),
  LatLng(16.5902, 121.6149),
  LatLng(16.6004, 121.6142),
  LatLng(16.599, 121.6108),
  LatLng(16.608, 121.6067),
  LatLng(16.6121, 121.6086),
  LatLng(16.6173, 121.6067),
  LatLng(16.6187, 121.6034),
  LatLng(16.6231, 121.604),
  LatLng(16.6258, 121.6024),
  LatLng(16.6259, 121.5997),
  LatLng(16.6297, 121.5973),
  LatLng(16.687, 121.6197),
  LatLng(16.6993, 121.6414),
  LatLng(16.7047, 121.6406),
  LatLng(16.709, 121.6423),
  LatLng(16.7106, 121.6477),
  LatLng(16.7128, 121.6489),
  LatLng(16.7242, 121.6459),
  LatLng(16.7334, 121.653),
  LatLng(16.7352, 121.6644),
  LatLng(16.7433, 121.6748),
  LatLng(16.7516, 121.6786),
  LatLng(16.75, 121.6724),
  LatLng(16.7521, 121.6709),
  LatLng(16.7583, 121.6708),
  LatLng(16.7669, 121.6787),
  LatLng(16.7459, 121.6887),
  LatLng(16.7357, 121.6953),
  LatLng(16.7345, 121.7209),
  LatLng(16.7239, 121.7295),
  LatLng(16.7166, 121.732),
  LatLng(16.7104, 121.7307),
  LatLng(16.7062, 121.7602),
  LatLng(16.7066, 121.7865),
  LatLng(16.702, 121.7914),
  LatLng(16.6923, 121.8071),
  LatLng(16.6542, 121.8727),
  LatLng(16.6517, 121.8841),
  LatLng(16.6547, 121.9266),
  LatLng(16.6678, 121.9527),
  LatLng(16.6643, 121.9566),
  LatLng(16.6625, 121.9658),
  LatLng(16.6558, 121.9652),
  LatLng(16.6544, 121.9678),
  LatLng(16.6587, 121.9707),
  LatLng(16.6542, 121.9737),
  LatLng(16.6456, 121.976),
  LatLng(16.6412, 121.9726),
  LatLng(16.6385, 121.9777),
  LatLng(16.6394, 121.9783),
  LatLng(16.6378, 121.9791),
  LatLng(16.6343, 121.9782),
  LatLng(16.6317, 121.9804),
  LatLng(16.6267, 121.9798),
  LatLng(16.6254, 121.9817),
  LatLng(16.6264, 122.0199),
  LatLng(16.6, 122.046),
  LatLng(16.5506, 122.1096),
  LatLng(16.5323, 122.129),
  LatLng(16.5336, 122.0823),
  LatLng(16.5291, 122.0789),
  LatLng(16.5259, 121.9526),
];
