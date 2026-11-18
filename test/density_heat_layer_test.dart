import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pinepal_mobile/widgets/density_heat_layer.dart';

Widget map(List<LatLng> points, double zoom) => MaterialApp(
  home: SizedBox(
    width: 400,
    height: 400,
    child: FlutterMap(
      options: MapOptions(
        initialCenter: const LatLng(16.70, 121.68),
        initialZoom: zoom,
      ),
      children: [DensityHeatLayer(points: points)],
    ),
  ),
);

void main() {
  const points = [
    LatLng(16.700, 121.680),
    LatLng(16.701, 121.681),
    LatLng(16.705, 121.690),
  ];

  testWidgets('draws the heat as a picture over the map', (tester) async {
    await tester.pumpWidget(map(points, 14));
    expect(find.byType(OverlayImageLayer), findsOneWidget);
  });

  testWidgets('works zoomed far in, drawing only around the screen', (
    tester,
  ) async {
    await tester.pumpWidget(map(points, 18));
    expect(find.byType(OverlayImageLayer), findsOneWidget);
  });

  testWidgets('no points, no heat', (tester) async {
    await tester.pumpWidget(map(const [], 14));
    expect(find.byType(OverlayImageLayer), findsNothing);
  });
}
