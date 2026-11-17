import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// Map tiles saved on the phone, so the map still shows offline.
//
// flutter_map 8 caches tiles by itself (BuiltInMapCachingProvider, used by the
// default NetworkTileProvider of every TileLayer). Here it is only configured,
// once at start-up, before any map is built:
//  * kept in the app's support folder instead of the OS cache folder, which
//    Android may empty whenever it likes
//  * a tile counts as fresh for 30 days, so a farmer who opened the map once
//    keeps seeing it without internet (OpenStreetMap itself says ~a week)
//  * at most 100 MB; the map is locked to Echague, so it stays far below that
class MapTileCache {
  static const freshFor = Duration(days: 30);
  static const maxBytes = 100 * 1024 * 1024;

  static Future<void> init() async {
    if (kIsWeb) return; // the built-in cache is native only
    String? folder;
    try {
      folder = p.join(
        (await getApplicationSupportDirectory()).path,
        'map_tiles',
      );
    } catch (_) {
      // no support folder (tests): fall back to the default cache folder
    }
    BuiltInMapCachingProvider.getOrCreateInstance(
      cacheDirectory: folder,
      maxCacheSize: maxBytes,
      overrideFreshAge: freshFor,
    );
  }
}
