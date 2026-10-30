import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pinepal_mobile/models/scan_record.dart';
import 'package:pinepal_mobile/services/api_client.dart';
import 'package:pinepal_mobile/services/app_settings.dart';
import 'package:pinepal_mobile/services/database_helper.dart';
import 'package:pinepal_mobile/services/sync_service.dart';

ScanRecord makeScan(
  String uuid, {
  required DateTime at,
  String? municipality,
  String? farmName,
}) {
  return ScanRecord(
    scanUuid: uuid,
    predictedLabel: 'Crown_Rot',
    confidence: 0.9,
    secondLabel: 'Fruit_Rot',
    secondConfidence: 0.05,
    imageSource: 'Camera',
    imagePath: '/no/photo/$uuid.jpg',
    latitude: 16.7,
    longitude: 121.6,
    scannedAt: at,
    municipality: municipality,
    farmName: farmName,
  );
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final db = DatabaseHelper.instance;
  late AppSettings settings;
  late List<String> bodies; // one entry per request the server received

  setUp(() async {
    await db.deleteAllScans();
    settings = AppSettings();
    bodies = [];
  });
  tearDownAll(() => db.deleteAllScans());

  SyncService serviceWith(Future<http.Response> Function(http.Request) server) {
    final api = ApiClient(
      client: MockClient((request) {
        bodies.add(request.body);
        return server(request);
      }),
      baseUrl: () => 'http://server.test',
    );
    return SyncService(api: api, db: db, settings: settings);
  }

  Future<http.Response> accept(http.Request _) async =>
      http.Response('{}', 200);

  test(
    'uploads the pending scans oldest first and marks them synced',
    () async {
      await db.insertScan(makeScan('newer', at: DateTime(2026, 10, 18, 10)));
      await db.insertScan(makeScan('older', at: DateTime(2026, 10, 18, 8)));
      await db.insertScan(makeScan('done', at: DateTime(2026, 10, 18, 9)));
      await db.markSynced('done');

      final result = await serviceWith(accept).syncPending(token: 't');

      expect(result.ok, true);
      expect(result.uploaded, 2);
      expect(result.summary, 'Synced 2 scans.');
      expect(bodies, hasLength(2)); // the one already synced is not sent again
      expect(bodies.first, contains('older'));
      expect(bodies.last, contains('newer'));
      expect(await db.countUnsynced(), 0);
      expect((await db.getScan('older'))!.syncedAt, isNotNull);
    },
  );

  test('scans without farm details get the ones from Settings', () async {
    await settings.setFarmName('Bueno Farm');
    await settings.setMunicipality('Alicia');
    await db.insertScan(makeScan('old-scan', at: DateTime(2026, 10, 1)));
    await db.insertScan(
      makeScan(
        'own-details',
        at: DateTime(2026, 10, 2),
        municipality: 'Burgos',
        farmName: 'Other Farm',
      ),
    );

    await serviceWith(accept).syncPending(token: 't');

    expect(bodies[0], contains('name="municipality"\r\n\r\nAlicia'));
    expect(bodies[0], contains('name="farm_name"\r\n\r\nBueno Farm'));
    // a scan keeps its own details
    expect(bodies[1], contains('name="municipality"\r\n\r\nBurgos'));
    expect(bodies[1], contains('name="farm_name"\r\n\r\nOther Farm'));
  });

  test('nothing is sent when nothing is pending', () async {
    final result = await serviceWith(accept).syncPending(token: 't');

    expect(bodies, isEmpty);
    expect(result.uploaded, 0);
    expect(result.summary, 'Everything is already synced.');
  });

  test(
    'an expired session stops the sync and keeps the scans pending',
    () async {
      await db.insertScan(makeScan('a', at: DateTime(2026, 10, 1)));
      await db.insertScan(makeScan('b', at: DateTime(2026, 10, 2)));

      final result = await serviceWith(
        (_) async =>
            http.Response(jsonEncode({'error': 'Token has expired'}), 401),
      ).syncPending(token: 'old');

      expect(result.sessionExpired, true);
      expect(result.error, 'Your session expired. Sign in again.');
      expect(bodies, hasLength(1)); // it did not keep trying
      expect(await db.countUnsynced(), 2);
    },
  );

  test('no connection stops the sync and keeps the scans pending', () async {
    await db.insertScan(makeScan('a', at: DateTime(2026, 10, 1)));
    await db.insertScan(makeScan('b', at: DateTime(2026, 10, 2)));

    final result = await serviceWith(
      (_) async => throw const SocketException('down'),
    ).syncPending(token: 't');

    expect(result.ok, false);
    expect(result.sessionExpired, false);
    expect(result.uploaded, 0);
    expect(bodies, hasLength(1));
    expect(await db.countUnsynced(), 2);
  });

  test('one scan the server refuses does not block the others', () async {
    await db.insertScan(makeScan('good-1', at: DateTime(2026, 10, 1)));
    await db.insertScan(makeScan('bad-scan', at: DateTime(2026, 10, 2)));
    await db.insertScan(makeScan('good-2', at: DateTime(2026, 10, 3)));

    final result = await serviceWith((request) async {
      return request.body.contains('bad-scan')
          ? http.Response(jsonEncode({'error': 'Unknown disease label'}), 400)
          : http.Response('{}', 200);
    }).syncPending(token: 't');

    expect(result.uploaded, 2);
    expect(result.failed, 1);
    expect(result.error, contains('Unknown disease label'));
    expect((await db.getUnsyncedScans()).map((s) => s.scanUuid), ['bad-scan']);
  });

  test('a scan edited after syncing is sent again with the feedback', () async {
    await db.insertScan(makeScan('a', at: DateTime(2026, 10, 1)));
    final service = serviceWith(accept);
    await service.syncPending(token: 't');
    expect(await db.countUnsynced(), 0);

    await db.updateFeedback(
      'a',
      feedback: ScanFeedback.correct,
      verifiedLabel: 'Crown_Rot',
      notes: 'Looked fine',
    );
    expect(await db.countUnsynced(), 1); // back to Pending

    bodies.clear();
    await service.syncPending(token: 't');

    expect(bodies, hasLength(1));
    expect(bodies.single, contains('name="farmer_feedback"\r\n\r\ncorrect'));
    expect(bodies.single, contains('name="notes"\r\n\r\nLooked fine'));
    expect(await db.countUnsynced(), 0);
  });
}
