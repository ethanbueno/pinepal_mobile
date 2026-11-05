class RemediationProtocol {
  // The entry's key in the JSON, like "Crown Rot". Matches the model label
  // once spaces become underscores ("Crown_Rot").
  final String key;
  final String name;
  final String scientificName;
  final String severity;
  final String pathogenType;
  // Bundled photo of the disease, null when there is none.
  final String? image;
  final String description;
  final List<String> symptoms;
  final List<String> remediationSteps;
  final List<String> preventiveMeasures;

  RemediationProtocol({
    required this.key,
    required this.name,
    required this.scientificName,
    required this.severity,
    required this.pathogenType,
    this.image,
    required this.description,
    required this.symptoms,
    required this.remediationSteps,
    required this.preventiveMeasures,
  });

  // The model label, used to look up the disease color
  String get label => key.trim().replaceAll(RegExp(r'[\s\-]+'), '_');

  // Same three types as the protocols on the website
  String get kind {
    final type = pathogenType.toLowerCase();
    if (type.contains('no pathogen') || label == 'No_Disease') return 'Healthy';
    if (type.contains('disorder')) return 'Disorder';
    return 'Disease';
  }

  factory RemediationProtocol.fromJson(String key, Map<String, dynamic> json) {
    return RemediationProtocol(
      key: key,
      name: json['name'] as String? ?? key,
      scientificName: json['scientific_name'] as String? ?? 'N/A',
      severity: json['severity'] as String? ?? 'Medium',
      pathogenType: json['pathogen_type'] as String? ?? 'Unknown',
      image: json['image'] as String?,
      description:
          json['description'] as String? ?? 'No description available.',
      symptoms:
          (json['symptoms'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      remediationSteps:
          (json['remediation_steps'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      preventiveMeasures:
          (json['preventive_measures'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  factory RemediationProtocol.fallback(String diseaseName) {
    return RemediationProtocol(
      key: diseaseName,
      name: diseaseName.replaceAll('_', ' '),
      scientificName: 'N/A',
      severity: 'Medium',
      pathogenType: 'General Disease',
      description:
          'Detailed pathogen data is currently unavailable offline for $diseaseName.',
      symptoms: ['Signs of fruit discoloration or localized soft rot.'],
      remediationSteps: [
        'Isolate infected plant/fruit to prevent cross-contamination.',
        'Sanitize farm tools with 10% sodium hypochlorite bleach solution.',
        'Consult local agricultural extension office for targeted fungicide/bactericide recommendations.',
      ],
      preventiveMeasures: [
        'Maintain proper crop spacing and soil aeration.',
        'Inspect plants regularly during warm/humid periods.',
      ],
    );
  }
}
