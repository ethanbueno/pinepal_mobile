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

  // Where the scan was taken, from the farm details in Settings. They go to the web
  // dashboard when syncing, where its filters and map use them.
  final String? municipality;
  final String? farmName;

  // Null until the farmer gives feedback on the scan screen.
  final ScanFeedback? feedback;

  // What the farmer says the fruit actually is. Null when there is no feedback,
  // or when the result was reported wrong and the farmer is not sure what it is.
  final String? verifiedLabel;

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
  });

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
  }) {
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
      notes: clearNotes ? null : (notes ?? this.notes),
      municipality: municipality,
      farmName: farmName,
      feedback: clearFeedback ? null : (feedback ?? this.feedback),
      verifiedLabel: clearVerifiedLabel
          ? null
          : (verifiedLabel ?? this.verifiedLabel),
    );
  }
}
