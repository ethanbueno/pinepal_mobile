import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/scan_record.dart';

// Writes the scans to a CSV file for the data analytics work, then hands it
// to the system share sheet so the farmer can save it to Drive, send it by
// email or chat, and so on. No storage permission is needed for this.
//
// The columns are wider than the database table: scan_date, scan_hour and
// is_correct are worked out here, so the file loads straight into pandas
// without a cleaning step.
class ExportService {
  static const List<String> headers = [
    'scan_uuid',
    'scanned_at',
    'scan_date',
    'scan_hour',
    'predicted_label',
    'confidence',
    'second_label',
    'second_confidence',
    'verified_label',
    'is_verified',
    'is_correct',
    'has_gps',
    'latitude',
    'longitude',
    'image_source',
    'synced',
    'notes',
    'image_file',
  ];

  static String _two(int n) => n.toString().padLeft(2, '0');

  static List<Object?> _rowFor(ScanRecord r) {
    final t = r.scannedAt;
    return [
      r.scanUuid,
      t.toIso8601String(),
      '${t.year}-${_two(t.month)}-${_two(t.day)}',
      t.hour,
      r.predictedLabel,
      double.parse(r.confidence.toStringAsFixed(4)),
      r.secondLabel ?? '',
      r.secondConfidence == null
          ? ''
          : double.parse(r.secondConfidence!.toStringAsFixed(4)),
      r.verifiedLabel ?? '',
      r.isVerified ? 1 : 0,
      // Blank rather than 0 when unverified, so unchecked scans do not get
      // counted as incorrect during analysis.
      r.isCorrect == null ? '' : (r.isCorrect! ? 1 : 0),
      r.hasGps ? 1 : 0,
      r.hasGps ? r.latitude : '',
      r.hasGps ? r.longitude : '',
      r.imageSource,
      r.synced ? 1 : 0,
      r.notes ?? '',
      r.imagePath.split(RegExp(r'[/\\]')).last,
    ];
  }

  static String _csvCell(Object? value) {
    final text = value?.toString() ?? '';
    if (text.contains(',') || text.contains('"') || text.contains('\n')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }

  static String _fileStamp() {
    final now = DateTime.now();
    return '${now.year}${_two(now.month)}${_two(now.day)}'
        '_${_two(now.hour)}${_two(now.minute)}${_two(now.second)}';
  }

  static String buildCsv(List<ScanRecord> records) {
    final buffer = StringBuffer()..writeln(headers.join(','));
    for (final record in records) {
      buffer.writeln(_rowFor(record).map(_csvCell).join(','));
    }
    return buffer.toString();
  }

  static Future<File> exportCsv(List<ScanRecord> records) async {
    final documents = await getApplicationDocumentsDirectory();
    final dir = Directory('${documents.path}/exports');
    if (!await dir.exists()) await dir.create(recursive: true);

    final file = File('${dir.path}/pinepal_scans_${_fileStamp()}.csv');
    // The BOM makes Excel open UTF-8 correctly on Windows.
    await file.writeAsString('﻿${buildCsv(records)}');
    return file;
  }

  static Future<void> shareFile(File file) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: 'PinePal scans',
      ),
    );
  }
}
