import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// The area the maps are locked to, the same as on the website
// (src/utils/diseases.js LOCKED_MUNICIPALITY and src/data/isabela.js).
const lockedAreaName = 'Echague, Isabela';

// Corners of Echague: south-west and north-east
final lockedAreaBounds = LatLngBounds(
  const LatLng(16.5259, 121.5973),
  const LatLng(16.7669, 122.1290),
);

// Echague town proper, where the map opens when there are no scans to show
const lockedAreaCenter = LatLng(16.7050, 121.6670);
const lockedAreaZoom = 13.0;

// Zoomed out further than this, the whole province would show
const lockedAreaMinZoom = 10.0;
const lockedAreaMaxZoom = 18.0;

bool isInLockedArea(double latitude, double longitude) {
  return lockedAreaBounds.contains(LatLng(latitude, longitude));
}
