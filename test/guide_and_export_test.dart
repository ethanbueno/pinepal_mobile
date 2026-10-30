import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pinepal_mobile/models/scan_record.dart';
import 'package:pinepal_mobile/services/export_service.dart';
import 'package:pinepal_mobile/services/label_service.dart';
import 'package:pinepal_mobile/services/protocol_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every class the model can output has a real guide entry', () async {
    // Reads the same labels.txt the classifier uses
    final labels = await LabelService.load();
    expect(labels, isNotEmpty);

    for (final label in labels) {
      final protocol = await ProtocolService.getProtocolForDisease(label);
      // The fallback has no scientific name; a real entry always does
      expect(
        protocol.scientificName,
        isNot('N/A'),
        reason: '$label has no entry in remediation_protocols.json',
      );
      expect(protocol.remediationSteps, isNotEmpty, reason: label);
    }
  });

  test('label matching ignores case, underscores and dashes', () async {
    final a = await ProtocolService.getProtocolForDisease('Mealybug_Wilt');
    final b = await ProtocolService.getProtocolForDisease('mealybug-wilt');
    expect(a.name, b.name);
  });

  test(
    'CSV export quotes cells and leaves is_correct blank without feedback',
    () {
      final scan = ScanRecord(
        scanUuid: 'u1',
        predictedLabel: 'Crown_Rot',
        confidence: 0.91234567,
        imageSource: 'Camera',
        imagePath: r'C:\photos\scan_1.jpg',
        latitude: 0,
        longitude: 0,
        scannedAt: DateTime(2026, 10, 8, 9, 30),
        notes: 'Block 3, "wet" day',
      );

      final lines = ExportService.buildCsv([scan]).trim().split('\n');
      expect(lines.first, ExportService.headers.join(','));

      final row = lines[1];
      expect(row, contains('2026-10-08'));
      expect(row, contains('0.9123'));
      expect(row, contains('"Block 3, ""wet"" day"'));
      expect(row, endsWith('scan_1.jpg'));
      // feedback blank, is_verified = 0, is_correct blank, has_gps = 0, no GPS,
      // no municipality or farm name
      expect(row, contains(',,0,,0,,,,,Camera,'));
    },
  );

  test('CSV export writes the farmer feedback', () {
    ScanRecord scan(ScanFeedback? feedback, String? actual) => ScanRecord(
      scanUuid: 'u',
      predictedLabel: 'Crown_Rot',
      confidence: 0.9,
      imageSource: 'Camera',
      imagePath: '/p/scan.jpg',
      latitude: 0,
      longitude: 0,
      scannedAt: DateTime(2026, 10, 8),
      feedback: feedback,
      verifiedLabel: actual,
    );

    List<String> cells(ScanRecord r) =>
        ExportService.buildCsv([r]).trim().split('\n')[1].split(',');
    final feedbackAt = ExportService.headers.indexOf('feedback');
    final correctAt = ExportService.headers.indexOf('is_correct');

    final right = cells(scan(ScanFeedback.correct, 'Crown_Rot'));
    expect([right[feedbackAt], right[correctAt]], ['correct', '1']);

    // Reported wrong and the farmer was not sure what it is
    final unsure = cells(scan(ScanFeedback.incorrect, null));
    expect([unsure[feedbackAt], unsure[correctAt]], ['incorrect', '0']);
  });

  test('asset bundle exposes the protocols file', () async {
    final raw = await rootBundle.loadString(
      'assets/data/remediation_protocols.json',
    );
    expect(raw, contains('Crown Rot'));
  });
}
