// One of the farmer's scans as the server has it (GET /api/mobile/scans).
// The dashboard only needs the label, date and place; History also uses the
// rest: the officer's verification, and the photo and result of scans taken
// on the web or another phone. A server from before those were added only
// sends the first five fields, so everything else may be null.
class ServerScan {
  final String scanUuid;

  // The condition to count: the officer's correction, then the farmer's,
  // then the model's (the server picks it)
  final String label;
  final DateTime scannedAt;

  // 0.0, 0.0 means no GPS fix, same as in ScanRecord
  final double latitude;
  final double longitude;

  final String? predictedLabel;
  final double? confidence;
  final String? secondLabel;
  final double? secondConfidence;
  final String? imageSource; // Camera, Gallery or Web
  final String? imageUrl; // empty or null when the server has no photo
  final String? municipality;
  final String? farmName;
  final String? notes;

  // Set when an agricultural officer checked the scan on the web dashboard
  final String? officerLabel;
  final String? officerBy;
  final DateTime? officerAt;

  // The farmer's own answer, from whichever phone or the web sent it
  final String? farmerFeedback;
  final String? farmerLabel;

  const ServerScan({
    required this.scanUuid,
    required this.label,
    required this.scannedAt,
    required this.latitude,
    required this.longitude,
    this.predictedLabel,
    this.confidence,
    this.secondLabel,
    this.secondConfidence,
    this.imageSource,
    this.imageUrl,
    this.municipality,
    this.farmName,
    this.notes,
    this.officerLabel,
    this.officerBy,
    this.officerAt,
    this.farmerFeedback,
    this.farmerLabel,
  });

  bool get hasGps => latitude != 0.0 || longitude != 0.0;

  // Enough to list it in History on its own (a newer server sent it)
  bool get hasDetails => predictedLabel != null && confidence != null;

  static DateTime? _date(Object? value) =>
      value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;

  static String? _text(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  factory ServerScan.fromJson(Map<String, dynamic> json) {
    return ServerScan(
      // a saved copy from before scan_uuid was kept has none
      scanUuid: json['scan_uuid'] as String? ?? '',
      label: json['label'] as String,
      scannedAt: DateTime.parse(json['scanned_at'] as String),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      predictedLabel: _text(json['predicted_label']),
      confidence: (json['confidence'] as num?)?.toDouble(),
      secondLabel: _text(json['second_label']),
      secondConfidence: (json['second_confidence'] as num?)?.toDouble(),
      imageSource: _text(json['image_source']),
      imageUrl: _text(json['image_url']),
      municipality: _text(json['municipality']),
      farmName: _text(json['farm_name']),
      notes: _text(json['notes']),
      officerLabel: _text(json['verified_label']),
      officerBy: _text(json['verified_by']),
      officerAt: _date(json['verified_at']),
      farmerFeedback: _text(json['farmer_feedback']),
      farmerLabel: _text(json['farmer_label']),
    );
  }

  // The same shape as fromJson reads, for the saved copy (ServerScanCache)
  Map<String, dynamic> toJson() => {
    'scan_uuid': scanUuid,
    'label': label,
    'scanned_at': scannedAt.toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'predicted_label': predictedLabel,
    'confidence': confidence,
    'second_label': secondLabel,
    'second_confidence': secondConfidence,
    'image_source': imageSource,
    'image_url': imageUrl,
    'municipality': municipality,
    'farm_name': farmName,
    'notes': notes,
    'verified_label': officerLabel,
    'verified_by': officerBy,
    'verified_at': officerAt?.toIso8601String(),
    'farmer_feedback': farmerFeedback,
    'farmer_label': farmerLabel,
  };
}
