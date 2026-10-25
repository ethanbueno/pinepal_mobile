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

  test('verification, accuracy summary and delete all', () async {
    await db.insertScan(makeScan('a')); // predicted Crown_Rot
    await db.insertScan(makeScan('b'));
    await db.insertScan(makeScan('c'));

    // a: model was right, b: model was wrong, c: not checked yet
    await db.updateVerification('a', verifiedLabel: 'Crown_Rot', notes: 'ok');
    await db.updateVerification('b', verifiedLabel: 'Fruit_Rot');

    final a = (await db.getScan('a'))!;
    expect(a.isVerified, true);
    expect(a.isCorrect, true);
    expect(a.notes, 'ok');
    expect((await db.getScan('b'))!.isCorrect, false);
    expect((await db.getScan('c'))!.isCorrect, isNull);

    expect(await db.getSummary(), {'total': 3, 'verified': 2, 'correct': 1});

    // Clearing the verification puts the scan back to unchecked
    await db.updateVerification('a');
    expect((await db.getScan('a'))!.isVerified, false);

    await db.deleteAllScans();
    expect(await db.getAllScans(), isEmpty);
  });

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
