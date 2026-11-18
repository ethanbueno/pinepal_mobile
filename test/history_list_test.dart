import 'package:flutter_test/flutter_test.dart';
import 'package:pinepal_mobile/models/history_list.dart';
import 'package:pinepal_mobile/models/scan_record.dart';
import 'package:pinepal_mobile/models/server_scan.dart';

ScanRecord phoneScan(
  String uuid,
  DateTime at, {
  String label = 'Crown_Rot',
  bool synced = true,
}) {
  return ScanRecord(
    scanUuid: uuid,
    predictedLabel: label,
    confidence: 0.9,
    imageSource: 'Camera',
    imagePath: '/photos/$uuid.jpg',
    latitude: 16.7,
    longitude: 121.6,
    scannedAt: at,
    synced: synced,
  );
}

ServerScan serverScan(
  String uuid,
  DateTime at, {
  String predicted = 'Crown_Rot',
  String? officer,
  String source = 'Web',
  bool details = true,
}) {
  return ServerScan.fromJson({
    'scan_uuid': uuid,
    'label': officer ?? predicted,
    'scanned_at': at.toIso8601String(),
    'latitude': 16.7,
    'longitude': 121.6,
    if (details) ...{
      'predicted_label': predicted,
      'confidence': 0.8,
      'image_source': source,
      'image_url': 'https://example.com/$uuid.jpg',
      'verified_label': officer,
      'verified_by': officer == null ? null : 'Officer Cruz',
      'verified_at': officer == null ? null : '2026-11-10T09:30:00',
    },
  });
}

void main() {
  final nov1 = DateTime(2026, 11, 1, 8);
  final nov5 = DateTime(2026, 11, 5, 8);
  final nov9 = DateTime(2026, 11, 9, 8);

  group('ServerScan', () {
    test('reads the short shape an older server sends', () {
      final scan = ServerScan.fromJson({
        'scan_uuid': 'a',
        'label': 'Fruit_Rot',
        'scanned_at': '2026-11-01T08:00:00',
        'latitude': 16.7,
        'longitude': 121.6,
      });
      expect(scan.hasDetails, isFalse);
      expect(scan.officerLabel, isNull);
    });

    test('a saved copy round-trips', () {
      final scan = serverScan('a', nov1, officer: 'Fruit_Rot');
      final again = ServerScan.fromJson(scan.toJson());
      expect(again.officerLabel, 'Fruit_Rot');
      expect(again.officerBy, 'Officer Cruz');
      expect(again.officerAt, DateTime(2026, 11, 10, 9, 30));
      expect(again.imageUrl, 'https://example.com/a.jpg');
    });
  });

  group('mergeHistory', () {
    test('adds the officer check to phone scans', () {
      final list = mergeHistory(
        [phoneScan('a', nov1)],
        [serverScan('a', nov1, officer: 'Fruit_Rot')],
      );
      expect(list, hasLength(1));
      expect(list.single.onPhone, isTrue);
      expect(list.single.isOfficerCorrected, isTrue);
      expect(list.single.shownLabel, 'Fruit_Rot');
      expect(list.single.imagePath, '/photos/a.jpg');
    });

    test('lists scans only on the server, newest first', () {
      final list = mergeHistory(
        [phoneScan('a', nov1)],
        [serverScan('a', nov1), serverScan('b', nov9, source: 'Gallery')],
      );
      expect(list.map((s) => s.scanUuid), ['b', 'a']);
      expect(list.first.onPhone, isFalse);
      expect(list.first.imageSource, 'Gallery');
      expect(list.first.imageUrl, 'https://example.com/b.jpg');
    });

    test('skips server-only scans an older server sent too little for', () {
      final list = mergeHistory([], [serverScan('b', nov9, details: false)]);
      expect(list, isEmpty);
    });

    test('a checked scan that the officer agreed with is not corrected', () {
      final list = mergeHistory(
        [phoneScan('a', nov1)],
        [serverScan('a', nov1, officer: 'Crown_Rot')],
      );
      expect(list.single.isOfficerVerified, isTrue);
      expect(list.single.isOfficerCorrected, isFalse);
    });
  });

  group('HistoryFilter', () {
    final scans = [
      phoneScan('a', nov1),
      phoneScan('b', nov5, label: 'No_Disease'),
      phoneScan('c', nov9),
    ];

    test('empty matches everything', () {
      expect(const HistoryFilter().apply(scans), hasLength(3));
    });

    test('by condition', () {
      final list = const HistoryFilter(label: 'No_Disease').apply(scans);
      expect(list.map((s) => s.scanUuid), ['b']);
    });

    test('by date range, both days included', () {
      final list = HistoryFilter(
        from: DateTime(2026, 11, 5),
        to: DateTime(2026, 11, 9),
      ).apply(scans);
      expect(list.map((s) => s.scanUuid), ['b', 'c']);
    });

    test('by the officer answer, not the model', () {
      final merged = mergeHistory(
        [phoneScan('a', nov1)],
        [serverScan('a', nov1, officer: 'Fruit_Rot')],
      );
      expect(
        const HistoryFilter(label: 'Fruit_Rot').apply(merged),
        hasLength(1),
      );
      expect(const HistoryFilter(label: 'Crown_Rot').apply(merged), isEmpty);
    });
  });

  group('HistoryFilter source and order', () {
    // a: synced phone scan, b: phone scan not synced yet, c: only on the server
    List<ScanRecord> scans() => mergeHistory(
      [
        phoneScan('a', DateTime(2026, 11, 3)),
        phoneScan('b', DateTime(2026, 11, 2), synced: false),
      ],
      [
        serverScan('a', DateTime(2026, 11, 3)),
        serverScan('c', DateTime(2026, 11, 1)),
      ],
    );

    test('on this phone: synced or not', () {
      final list = const HistoryFilter(
        source: HistorySource.phone,
      ).apply(scans());
      expect(list.map((s) => s.scanUuid), ['a', 'b']);
    });

    test('online: synced and server-only, not pending', () {
      final list = const HistoryFilter(
        source: HistorySource.online,
      ).apply(scans());
      expect(list.map((s) => s.scanUuid), ['a', 'c']);
    });

    test('oldest first reverses the list, clearing keeps the order', () {
      const filter = HistoryFilter(
        oldestFirst: true,
        source: HistorySource.phone,
      );
      expect(filter.apply(scans()).map((s) => s.scanUuid), ['b', 'a']);
      expect(filter.cleared().apply(scans()).map((s) => s.scanUuid), [
        'c',
        'b',
        'a',
      ]);
    });
  });

  test('editing feedback keeps the officer check', () {
    final merged = mergeHistory(
      [phoneScan('a', nov1)],
      [serverScan('a', nov1, officer: 'Fruit_Rot')],
    ).single;
    final edited = merged.copyWith(feedback: ScanFeedback.correct);
    expect(edited.officerLabel, 'Fruit_Rot');
    expect(edited.feedback, ScanFeedback.correct);
    expect(edited.copyWith(clearFeedback: true).feedback, isNull);
  });
}
