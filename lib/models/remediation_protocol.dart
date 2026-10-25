class RemediationProtocol {
  final String name;
  final String scientificName;
  final String severity;
  final String pathogenType;
  final String description;
  final List<String> symptoms;
  final List<String> remediationSteps;
  final List<String> preventiveMeasures;

  RemediationProtocol({
    required this.name,
    required this.scientificName,
    required this.severity,
    required this.pathogenType,
    required this.description,
    required this.symptoms,
    required this.remediationSteps,
    required this.preventiveMeasures,
  });

  factory RemediationProtocol.fromJson(String key, Map<String, dynamic> json) {
    return RemediationProtocol(
      name: json['name'] as String? ?? key,
      scientificName: json['scientific_name'] as String? ?? 'N/A',
      severity: json['severity'] as String? ?? 'Medium',
      pathogenType: json['pathogen_type'] as String? ?? 'Unknown',
      description: json['description'] as String? ?? 'No description available.',
      symptoms: (json['symptoms'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      remediationSteps: (json['remediation_steps'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      preventiveMeasures: (json['preventive_measures'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  factory RemediationProtocol.fallback(String diseaseName) {
    return RemediationProtocol(
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
        'Consult local agricultural extension office for targeted fungicide/bactericide recommendations.'
      ],
      preventiveMeasures: [
        'Maintain proper crop spacing and soil aeration.',
        'Inspect plants regularly during warm/humid periods.'
      ],
    );
  }
}
