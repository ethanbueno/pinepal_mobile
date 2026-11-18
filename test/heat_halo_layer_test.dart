import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pinepal_mobile/models/dashboard_stats.dart';
import 'package:pinepal_mobile/widgets/heat_halo_layer.dart';

DashboardScan scan(double lat, double lng, String label) => DashboardScan(
  label: label,
  scannedAt: DateTime(2026, 11, 1),
  latitude: lat,
  longitude: lng,
);

Widget map(List<DashboardScan> scans, double zoom) => MaterialApp(
  home: SizedBox(
    width: 400,
    height: 400,
    child: FlutterMap(
      options: MapOptions(
        initialCenter: const LatLng(16.70, 121.68),
        initialZoom: zoom,
      ),
      children: [HeatHaloLayer(scans: scans)],
    ),
  ),
);

void main() {
  test('glow colors are fixed 10% bands from green to red', () {
    expect(rateBands, hasLength(10));
    expect(rateColor(0), rateBands.first);
    expect(rateColor(0.55), rateBands[5]);
    expect(rateColor(1), rateBands.last);
  });

  testWidgets('every scan gets its own dot and glow', (tester) async {
    await tester.pumpWidget(
      map([
        scan(16.7000, 121.6800, 'Fruit_Rot'),
        scan(16.7001, 121.6801, 'No_Disease'),
        scan(16.7002, 121.6799, 'Crown_Rot'),
      ], 14),
    );
    // a dot (with its tooltip) for each scan, none grouped
    expect(find.byType(Tooltip), findsNWidgets(3));
  });

  testWidgets('no scans, nothing drawn', (tester) async {
    await tester.pumpWidget(map(const [], 14));
    expect(find.byType(Tooltip), findsNothing);
  });
}
