import 'server_scan.dart';

// The farmer's answer to "was the result correct?". Officers verify scans on
// the web dashboard; this is only the farmer's side of it.
enum ScanFeedback {
  correct, // the model got it right
  incorrect, // the farmer reports the result as wrong
}

// One saved scan. The column names in toMap() match the scans table
// of the backend, so the same data can be uploaded when syncing.
class ScanRecord {
  // Generated on the phone (uuid package). The server uses it to ignore
  // scans it already has, so syncing twice never makes duplicates.
  final String scanUuid;

  final String predictedLabel;
  final double confidence;
  final String? secondLabel;
  final double? secondConfidence;

  final String imageSource; // 'Camera' or 'Gallery'
  final String imagePath;

  // 0.0 means no GPS fix was available
  final double latitude;
  final double longitude;
  final DateTime scannedAt;

  // Sync status: false = Pending, true = Synced
  final bool synced;
  final DateTime? syncedAt;

  final String? notes;

  // Where the scan was taken: the farm details in Settings, or the municipality the
  // farmer picked for this scan. They go to the web
  // dashboard when syncing, where its filters and map use them.
  final String? municipality;
  final String? farmName;

  // Null until the farmer gives feedback on the scan screen.
  final ScanFeedback? feedback;

  // What the farmer says the fruit actually is. Null when there is no feedback,
  // or when the result was reported wrong and the farmer is not sure what it is.
  final String? verifiedLabel;

  // Not saved in the phone's database: filled in from the server's copy of
  // the scan (ServerScan) each time History loads.
  // The agricultural officer's check on the web dashboard, when there is one.
  final String? officerLabel;
  final String? officerBy;
  final DateTime? officerAt;

  // False for a scan taken on the web or another phone: it is only on the
  // server, so there is no photo file here (imageUrl instead) and it can't be
  // edited or deleted from this phone.
  final bool onPhone;
  final String? imageUrl;

  ScanRecord({
    required this.scanUuid,
    required this.predictedLabel,
    required this.confidence,
    this.secondLabel,
    this.secondConfidence,
    required this.imageSource,
    required this.imagePath,
    required this.latitude,
    required this.longitude,
    required this.scannedAt,
    this.synced = false,
    this.syncedAt,
    this.notes,
    this.municipality,
    this.farmName,
    this.feedback,
    this.verifiedLabel,
    this.officerLabel,
    this.officerBy,
    this.officerAt,
    this.onPhone = true,
    this.imageUrl,
  });

  // A scan that is only on the server. Needs a server that sends the details
  // (ServerScan.hasDetails).
  factory ScanRecord.fromServer(ServerScan scan) {
    return ScanRecord(
      scanUuid: scan.scanUuid,
      predictedLabel: scan.predictedLabel ?? scan.label,
      confidence: scan.confidence ?? 0,
      secondLabel: scan.secondLabel,
      secondConfidence: scan.secondConfidence,
      imageSource: scan.imageSource ?? 'Web',
      imagePath: '',
      latitude: scan.latitude,
      longitude: scan.longitude,
      scannedAt: scan.scannedAt,
      synced: true,
      notes: scan.notes,
      municipality: scan.municipality,
      farmName: scan.farmName,
      feedback: ScanFeedback.values.asNameMap()[scan.farmerFeedback],
      verifiedLabel: scan.farmerLabel,
      officerLabel: scan.officerLabel,
      officerBy: scan.officerBy,
      officerAt: scan.officerAt,
      onPhone: false,
      imageUrl: scan.imageUrl,
    );
  }

  // This phone's scan with the officer's check from the server's copy
  ScanRecord withServer(ServerScan scan) => _copy(
    officerLabel: scan.officerLabel,
    officerBy: scan.officerBy,
    officerAt: scan.officerAt,
  );

  // This scan with another copy's officer check, after reading it again from
  // the database (which does not keep it)
  ScanRecord withOfficerOf(ScanRecord other) => _copy(
    officerLabel: other.officerLabel,
    officerBy: other.officerBy,
    officerAt: other.officerAt,
  );

  bool get isOfficerVerified => officerLabel != null;

  // The officer changed the model's answer
  bool get isOfficerCorrected =>
      officerLabel != null && officerLabel != predictedLabel;

  // What the scan is shown and filtered as: the officer's answer when there
  // is one, otherwise the model's (the same as the web)
  String get shownLabel => officerLabel ?? predictedLabel;

  bool get hasGps => latitude != 0.0 || longitude != 0.0;

  bool get hasFeedback => feedback != null;

  // Null without feedback, so unchecked scans are not counted as wrong
  bool? get isCorrect =>
      feedback == null ? null : feedback == ScanFeedback.correct;

  // sqflite has no bool or DateTime type, so we store 0/1 and ISO text.
  Map<String, dynamic> toMap() {
    return {
      'scan_uuid': scanUuid,
      'predicted_label': predictedLabel,
      'confidence': confidence,
      'second_label': secondLabel,
      'second_confidence': secondConfidence,
      'image_source': imageSource,
      'image_path': imagePath,
      'latitude': latitude,
      'longitude': longitude,
      'scanned_at': scannedAt.toIso8601String(),
      'synced': synced ? 1 : 0,
      'synced_at': syncedAt?.toIso8601String(),
      'notes': notes,
      'municipality': municipality,
      'farm_name': farmName,
      'feedback': feedback?.name,
      'verified_label': verifiedLabel,
    };
  }

  factory ScanRecord.fromMap(Map<String, dynamic> map) {
    return ScanRecord(
      scanUuid: map['scan_uuid'] as String,
      predictedLabel: map['predicted_label'] as String,
      confidence: (map['confidence'] as num).toDouble(),
      secondLabel: map['second_label'] as String?,
      secondConfidence: (map['second_confidence'] as num?)?.toDouble(),
      imageSource: map['image_source'] as String,
      imagePath: map['image_path'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      scannedAt: DateTime.parse(map['scanned_at'] as String),
      synced: map['synced'] == 1,
      syncedAt: map['synced_at'] == null
          ? null
          : DateTime.parse(map['synced_at'] as String),
      notes: map['notes'] as String?,
      municipality: map['municipality'] as String?,
      farmName: map['farm_name'] as String?,
      feedback: ScanFeedback.values.asNameMap()[map['feedback']],
      verifiedLabel: map['verified_label'] as String?,
    );
  }

  // The prediction, photo and GPS are what the model produced and never
  // change; only the farmer's feedback and notes can be edited.
  ScanRecord copyWith({
    ScanFeedback? feedback,
    bool clearFeedback = false,
    String? verifiedLabel,
    bool clearVerifiedLabel = false,
    String? notes,
    bool clearNotes = false,
    String? municipality,
  }) {
    return _copy(
      feedback: clearFeedback ? null : (feedback ?? this.feedback),
      verifiedLabel: clearVerifiedLabel
          ? null
          : (verifiedLabel ?? this.verifiedLabel),
      notes: clearNotes ? null : (notes ?? this.notes),
      municipality: municipality ?? this.municipality,
    );
  }

  static const _same = Object();

  // Every field kept unless passed; pass null to empty a field
  ScanRecord _copy({
    Object? feedback = _same,
    Object? verifiedLabel = _same,
    Object? notes = _same,
    Object? municipality = _same,
    Object? officerLabel = _same,
    Object? officerBy = _same,
    Object? officerAt = _same,
  }) {
    T pick<T>(Object? value, T current) =>
        identical(value, _same) ? current : value as T;
    return ScanRecord(
      scanUuid: scanUuid,
      predictedLabel: predictedLabel,
      confidence: confidence,
      secondLabel: secondLabel,
      secondConfidence: secondConfidence,
      imageSource: imageSource,
      imagePath: imagePath,
      latitude: latitude,
      longitude: longitude,
      scannedAt: scannedAt,
      synced: synced,
      syncedAt: syncedAt,
      notes: pick(notes, this.notes),
      municipality: pick(municipality, this.municipality),
      farmName: farmName,
      feedback: pick(feedback, this.feedback),
      verifiedLabel: pick(verifiedLabel, this.verifiedLabel),
      officerLabel: pick(officerLabel, this.officerLabel),
      officerBy: pick(officerBy, this.officerBy),
      officerAt: pick(officerAt, this.officerAt),
      onPhone: onPhone,
      imageUrl: imageUrl,
    );
  }
}
