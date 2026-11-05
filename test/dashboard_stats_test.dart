import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:pinepal_mobile/models/dashboard_stats.dart';
import 'package:pinepal_mobile/models/scan_record.dart';
import 'package:pinepal_mobile/services/api_client.dart';

DashboardScan scan(String label, DateTime at, {bool gps = true}) {
  return DashboardScan(
    label: label,
    scannedAt: at,
    latitude: gps ? 16.7 : 0.0,
    longitude: gps ? 121.6 : 0.0,
  );
}

void main() {
  // A Thursday
  final today = DateTime(2026, 11, 5, 15, 0);

  test('counts follow labels.txt order and include every class', () {
    final stats = DashboardStats([
      scan('Fruit_Rot', today),
      scan('Fruit_Rot', today),
      scan('No_Disease', today),
    ], now: today);

    final counts = stats.countsByLabel([
      'Crown_Rot',
      'Fruit_Rot',
      'No_Disease',
    ]);

    expect(counts.keys.toList(), ['Crown_Rot', 'Fruit_Rot', 'No_Disease']);
    expect(counts.values.toList(), [0, 2, 1]);
    expect(stats.total, 3);
    expect(stats.healthy, 1);
    expect(stats.diseased, 2);
  });

  test('the farmer\'s corrected label is the one counted', () {
    final record = ScanRecord(
      scanUuid: 'a',
      predictedLabel: 'Crown_Rot',
      confidence: 0.7,
      imageSource: 'Camera',
      imagePath: '',
      latitude: 0,
      longitude: 0,
      scannedAt: today,
      feedback: ScanFeedback.incorrect,
      verifiedLabel: 'Multiple_Crown',
    );

    final dashboardScan = DashboardScan.fromRecord(record);

    expect(dashboardScan.label, 'Multiple_Crown');
    expect(dashboardScan.hasGps, isFalse);
  });

  test('weekly makes 8 Monday weeks, oldest first, this week last', () {
    final stats = DashboardStats([
      scan('No_Disease', DateTime(2026, 11, 2, 8)), // Monday this week
      scan('Fruit_Rot', DateTime(2026, 11, 5, 9)), // today
      scan('Fruit_Rot', DateTime(2026, 11, 1, 23)), // Sunday last week
      scan('Crown_Rot', DateTime(2026, 8, 1)), // too old
    ], now: today);

    final weeks = stats.weekly();

    expect(weeks.length, 8);
    expect(weeks.last.start, DateTime(2026, 11, 2));
    expect(weeks.first.start, DateTime(2026, 9, 14));
    expect(weeks.last.healthy, 1);
    expect(weeks.last.diseased, 1);
    expect(weeks[6].diseased, 1);
    expect(weeks.fold(0, (sum, w) => sum + w.total), 3);
  });

  test('changes compare the last 30 days with the 30 before', () {
    final stats = DashboardStats([
      // last 30 days: 3 Fruit Rot, 1 Crown Rot
      scan('Fruit_Rot', DateTime(2026, 11, 4)),
      scan('Fruit_Rot', DateTime(2026, 10, 20)),
      scan('Fruit_Rot', DateTime(2026, 10, 7)),
      scan('Crown_Rot', DateTime(2026, 10, 10)),
      // the 30 days before: 1 Fruit Rot, 1 Crown Rot, 2 Mealybug Wilt
      scan('Fruit_Rot', DateTime(2026, 10, 1)),
      scan('Crown_Rot', DateTime(2026, 9, 20)),
      scan('Mealybug_Wilt', DateTime(2026, 9, 15)),
      scan('Mealybug_Wilt', DateTime(2026, 9, 10)),
      // healthy scans are never a "change"
      scan('No_Disease', DateTime(2026, 11, 1)),
    ], now: today);

    final changes = stats.changes();

    // Crown Rot stayed the same, so it is left out
    expect(changes.map((c) => c.label), ['Fruit_Rot', 'Mealybug_Wilt']);
    expect(changes[0].now, 3);
    expect(changes[0].before, 1);
    expect(changes[1].difference, -2);
  });

  test('scans without GPS stay off the map', () {
    final stats = DashboardStats([
      scan('Fruit_Rot', today),
      scan('Fruit_Rot', today, gps: false),
    ], now: today);

    expect(stats.withGps.length, 1);
  });

  test('getMyScans sends the token and reads the scans', () async {
    late http.Request seen;
    final api = ApiClient(
      baseUrl: () => 'http://server.test:5000',
      client: MockClient((request) async {
        seen = request;
        return http.Response(
          jsonEncode({
            'scans': [
              {
                'scan_uuid': '11111111-2222-4333-8444-555555555555',
                'label': 'Fruit_Rot',
                'scanned_at': '2026-10-18T12:58:00',
                'latitude': 16.7083,
                'longitude': 121.6833,
              },
            ],
          }),
          200,
        );
      }),
    );

    final scans = await api.getMyScans(token: 'abc');

    expect(seen.method, 'GET');
    expect(seen.url.toString(), 'http://server.test:5000/api/mobile/scans');
    expect(seen.headers['Authorization'], 'Bearer abc');
    expect(scans.single.label, 'Fruit_Rot');
    expect(scans.single.scannedAt, DateTime(2026, 10, 18, 12, 58));
    expect(scans.single.hasGps, isTrue);
  });
}
