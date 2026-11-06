import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/scan_record.dart';

// Handles the local sqflite database. All scans are saved here first,
// so the app works fully offline.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pinepal.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: upgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE scans (
        scan_uuid TEXT PRIMARY KEY,
        predicted_label TEXT NOT NULL,
        confidence REAL NOT NULL,
        second_label TEXT,
        second_confidence REAL,
        image_source TEXT NOT NULL,
        image_path TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        scanned_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        synced_at TEXT,
        notes TEXT,
        verified_label TEXT,
        feedback TEXT,
        municipality TEXT,
        farm_name TEXT
      )
    ''');
  }

  // Existing installs already have scans, so add the columns instead of
  // recreating the table.
  @visibleForTesting
  static Future<void> upgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE scans ADD COLUMN verified_label TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE scans ADD COLUMN feedback TEXT');
      // Scans checked before feedback existed: the label the farmer picked
      // tells whether the model was right
      await db.execute('''
        UPDATE scans
        SET feedback = CASE
          WHEN verified_label = predicted_label THEN 'correct'
          ELSE 'incorrect'
        END
        WHERE verified_label IS NOT NULL AND verified_label != ''
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE scans ADD COLUMN municipality TEXT');
      await db.execute('ALTER TABLE scans ADD COLUMN farm_name TEXT');
    }
  }

  // CREATE
  Future<void> insertScan(ScanRecord scan) async {
    final db = await database;
    await db.insert('scans', scan.toMap());
  }

  // READ (newest first)
  Future<List<ScanRecord>> getAllScans() async {
    final db = await database;
    final rows = await db.query('scans', orderBy: 'scanned_at DESC');
    return rows.map((row) => ScanRecord.fromMap(row)).toList();
  }

  Future<ScanRecord?> getScan(String scanUuid) async {
    final db = await database;
    final rows = await db.query(
      'scans',
      where: 'scan_uuid = ?',
      whereArgs: [scanUuid],
    );
    if (rows.isEmpty) return null;
    return ScanRecord.fromMap(rows.first);
  }

  // UPDATE: the farmer can add or edit a note (pass null to clear it).
  // The scan goes back to Pending, so the change is uploaded on the next sync.
  Future<void> updateNotes(String scanUuid, String? notes) async {
    final db = await database;
    await db.update(
      'scans',
      {'notes': notes, 'synced': 0},
      where: 'scan_uuid = ?',
      whereArgs: [scanUuid],
    );
  }

  // UPDATE: the municipality the farmer picked for this scan.
  // The scan goes back to Pending, so the change is uploaded on the next sync.
  Future<void> updateMunicipality(String scanUuid, String municipality) async {
    final db = await database;
    await db.update(
      'scans',
      {'municipality': municipality, 'synced': 0},
      where: 'scan_uuid = ?',
      whereArgs: [scanUuid],
    );
  }

  // UPDATE: the farmer's feedback and notes (pass null to clear any of them).
  // The scan goes back to Pending, so the change is uploaded on the next sync.
  Future<void> updateFeedback(
    String scanUuid, {
    ScanFeedback? feedback,
    String? verifiedLabel,
    String? notes,
  }) async {
    final db = await database;
    await db.update(
      'scans',
      {
        'feedback': feedback?.name,
        'verified_label': verifiedLabel,
        'notes': notes,
        'synced': 0,
      },
      where: 'scan_uuid = ?',
      whereArgs: [scanUuid],
    );
  }

  // Numbers shown above the history list: how many scans, how many the
  // farmer gave feedback on, and how many of those the model got right.
  Future<Map<String, int>> getSummary() async {
    final db = await database;

    Future<int> count(String where) async {
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM scans${where.isEmpty ? '' : ' WHERE $where'}',
      );
      return Sqflite.firstIntValue(rows) ?? 0;
    }

    return {
      'total': await count(''),
      'checked': await count('feedback IS NOT NULL'),
      'correct': await count("feedback = 'correct'"),
    };
  }

  // DELETE
  Future<void> deleteScan(String scanUuid) async {
    final db = await database;
    await db.delete('scans', where: 'scan_uuid = ?', whereArgs: [scanUuid]);
  }

  // DELETE ALL: clears the whole history
  Future<void> deleteAllScans() async {
    final db = await database;
    await db.delete('scans');
  }

  // SYNC: scans that still need to be uploaded
  Future<List<ScanRecord>> getUnsyncedScans() async {
    final db = await database;
    final rows = await db.query(
      'scans',
      where: 'synced = 0',
      orderBy: 'scanned_at ASC',
    );
    return rows.map((row) => ScanRecord.fromMap(row)).toList();
  }

  // How many scans are waiting to be uploaded
  Future<int> countUnsynced() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM scans WHERE synced = 0',
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<void> markSynced(String scanUuid) async {
    final db = await database;
    await db.update(
      'scans',
      {'synced': 1, 'synced_at': DateTime.now().toIso8601String()},
      where: 'scan_uuid = ?',
      whereArgs: [scanUuid],
    );
  }
}
