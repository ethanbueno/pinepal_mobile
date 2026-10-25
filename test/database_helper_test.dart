import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pinepal_mobile/models/scan_record.dart';
import 'package:pinepal_mobile/services/database_helper.dart';

ScanRecord makeScan(String uuid) {
  return ScanRecord(
    scanUuid: uuid,
    predictedLabel: 'Crown_Rot',
    confidence: 0.91,
    secondLabel: 'Mealybug_Wilt',
    secondConfidence: 0.05,
    imageSource: 'Camera',
    imagePath: '/photos/$uuid.jpg',
    latitude: 16.7,
    longitude: 121.6,
    scannedAt: DateTime(2026, 10, 8, 9, 30),
  );
}

void main() {
  // Runs sqflite on the desktop so the test needs no emulator
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final db = DatabaseHelper.instance;

  test('insert, read, update note, sync, delete', () async {
    await db.insertScan(makeScan('uuid-1'));

    // READ
    final saved = await db.getScan('uuid-1');
    expect(saved, isNotNull);
    expect(saved!.predictedLabel, 'Crown_Rot');
    expect(saved.secondLabel, 'Mealybug_Wilt');
    expect(saved.synced, false);
    expect(saved.notes, isNull);

    // UPDATE note, then clear it
    await db.updateNotes('uuid-1', 'Block 3, after rain');
    expect((await db.getScan('uuid-1'))!.notes, 'Block 3, after rain');
    await db.updateNotes('uuid-1', null);
    expect((await db.getScan('uuid-1'))!.notes, isNull);

    // SYNC: pending list, then mark as synced
    expect((await db.getUnsyncedScans()).map((s) => s.scanUuid), ['uuid-1']);
    await db.markSynced('uuid-1');
    expect(await db.getUnsyncedScans(), isEmpty);
    final synced = await db.getScan('uuid-1');
    expect(synced!.synced, true);
    expect(synced.syncedAt, isNotNull);

    // DELETE
    await db.deleteScan('uuid-1');
    expect(await db.getScan('uuid-1'), isNull);
  });

  test('getAllScans returns newest first', () async {
    final older = makeScan('old');
    final newer = ScanRecord(
      scanUuid: 'new',
      predictedLabel: 'No_Disease',
      confidence: 0.8,
      imageSource: 'Gallery',
      imagePath: '/photos/new.jpg',
      latitude: 0,
      longitude: 0,
      scannedAt: DateTime(2026, 10, 9),
    );
    await db.insertScan(older);
    await db.insertScan(newer);

    final all = await db.getAllScans();
    expect(all.map((s) => s.scanUuid).toList(), ['new', 'old']);
    expect(all.first.hasGps, false);

    await db.deleteScan('old');
    await db.deleteScan('new');
  });

  test('feedback, accuracy summary and delete all', () async {
    await db.insertScan(makeScan('a')); // predicted Crown_Rot
    await db.insertScan(makeScan('b'));
    await db.insertScan(makeScan('c'));
    await db.insertScan(makeScan('d'));

    // a: model was right, b: wrong and the farmer knows what it is,
    // c: wrong but the farmer is not sure what it is, d: no answer yet
    await db.updateFeedback(
      'a',
      feedback: ScanFeedback.correct,
      verifiedLabel: 'Crown_Rot',
      notes: 'ok',
    );
    await db.updateFeedback(
      'b',
      feedback: ScanFeedback.incorrect,
      verifiedLabel: 'Fruit_Rot',
    );
    await db.updateFeedback('c', feedback: ScanFeedback.incorrect);

    final a = (await db.getScan('a'))!;
    expect(a.hasFeedback, true);
    expect(a.isCorrect, true);
    expect(a.notes, 'ok');
    expect((await db.getScan('b'))!.isCorrect, false);
    expect((await db.getScan('b'))!.verifiedLabel, 'Fruit_Rot');
    final c = (await db.getScan('c'))!;
    expect(c.isCorrect, false);
    expect(c.verifiedLabel, isNull);
    expect((await db.getScan('d'))!.isCorrect, isNull);

    expect(await db.getSummary(), {'total': 4, 'checked': 3, 'correct': 1});

    // Clearing the answer puts the scan back to "no feedback"
    await db.updateFeedback('a');
    expect((await db.getScan('a'))!.hasFeedback, false);

    await db.deleteAllScans();
    expect(await db.getAllScans(), isEmpty);
  });

  test(
    'upgrading a v2 database turns old checked scans into feedback',
    () async {
      final path = '${await databaseFactory.getDatabasesPath()}/v2_test.db';
      await databaseFactory.deleteDatabase(path);

      // A database as release 2 created it: verified_label, no feedback column
      final v2 = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, version) => db.execute('''
          CREATE TABLE scans (
            scan_uuid TEXT PRIMARY KEY, predicted_label TEXT NOT NULL,
            confidence REAL NOT NULL, second_label TEXT,
            second_confidence REAL, image_source TEXT NOT NULL,
            image_path TEXT NOT NULL, latitude REAL NOT NULL,
            longitude REAL NOT NULL, scanned_at TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0, synced_at TEXT, notes TEXT,
            verified_label TEXT
          )
        '''),
        ),
      );
      Future<void> add(String uuid, String predicted, String? verified) =>
          v2.insert('scans', {
            'scan_uuid': uuid,
            'predicted_label': predicted,
            'confidence': 0.8,
            'image_source': 'Camera',
            'image_path': '/p.jpg',
            'latitude': 0.0,
            'longitude': 0.0,
            'scanned_at': '2026-10-01T08:00:00.000',
            'verified_label': verified,
          });
      await add('right', 'Crown_Rot', 'Crown_Rot');
      await add('wrong', 'Crown_Rot', 'Fruit_Rot');
      await add('unchecked', 'Crown_Rot', null);
      await v2.close();

      // Opens it again with the app's real upgrade code
      final v3 = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 3,
          onUpgrade: DatabaseHelper.upgrade,
        ),
      );
      final rows = await v3.query('scans');
      String? feedbackOf(String uuid) =>
          rows.firstWhere((r) => r['scan_uuid'] == uuid)['feedback'] as String?;
      expect(feedbackOf('right'), 'correct');
      expect(feedbackOf('wrong'), 'incorrect');
      expect(feedbackOf('unchecked'), isNull);
      await v3.close();
      await databaseFactory.deleteDatabase(path);
    },
  );

  test('upgrading a v1 database keeps scans and adds verified_label', () async {
    final path = '${await databaseFactory.getDatabasesPath()}/upgrade_test.db';
    await databaseFactory.deleteDatabase(path);

    // A database exactly as the first release created it
    final v1 = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) => db.execute('''
          CREATE TABLE scans (
            scan_uuid TEXT PRIMARY KEY, predicted_label TEXT NOT NULL,
            confidence REAL NOT NULL, second_label TEXT,
            second_confidence REAL, image_source TEXT NOT NULL,
            image_path TEXT NOT NULL, latitude REAL NOT NULL,
            longitude REAL NOT NULL, scanned_at TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0, synced_at TEXT, notes TEXT
          )
        '''),
      ),
    );
    await v1.insert('scans', {
      'scan_uuid': 'old',
      'predicted_label': 'Fruit_Rot',
      'confidence': 0.7,
      'image_source': 'Camera',
      'image_path': '/p.jpg',
      'latitude': 0.0,
      'longitude': 0.0,
      'scanned_at': '2026-10-01T08:00:00.000',
    });
    await v1.close();

    final v2 = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onUpgrade: (db, oldVersion, newVersion) =>
            db.execute('ALTER TABLE scans ADD COLUMN verified_label TEXT'),
      ),
    );
    final rows = await v2.query('scans');
    expect(rows.single['scan_uuid'], 'old');
    expect(rows.single['verified_label'], isNull);
    await v2.close();
    await databaseFactory.deleteDatabase(path);
  });
}
