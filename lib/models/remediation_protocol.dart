// One source a guide is based on, shown under "Sources" in the guide.
class GuideSource {
  final String title;
  final String publisher;
  final String url;
  // "Philippines", "Southeast Asia" or "International". Philippine sources
  // come first in the guide.
  final String tier;

  const GuideSource({
    required this.title,
    required this.publisher,
    required this.url,
    required this.tier,
  });

  static const tierOrder = ['Philippines', 'Southeast Asia', 'International'];

  int get tierRank {
    final i = tierOrder.indexOf(tier);
    return i == -1 ? tierOrder.length : i;
  }

  factory GuideSource.fromJson(Map<String, dynamic> json) {
    return GuideSource(
      title: json['title'] as String? ?? '',
      publisher: json['publisher'] as String? ?? '',
      url: json['url'] as String? ?? '',
      tier: json['tier'] as String? ?? 'International',
    );
  }
}

// Who took one of the guide photos, shown under "Photo credits"
class PhotoCredit {
  // File name of the photo, like "crown_rot_2.jpg"
  final String file;
  final String title;
  final String author;
  // e.g. "CC BY 4.0"
  final String license;
  final String url;

  const PhotoCredit({
    required this.file,
    required this.title,
    required this.author,
    required this.license,
    required this.url,
  });

  factory PhotoCredit.fromJson(Map<String, dynamic> json) {
    return PhotoCredit(
      file: json['file'] as String? ?? '',
      title: json['title'] as String? ?? '',
      author: json['author'] as String? ?? '',
      license: json['license'] as String? ?? '',
      url: json['url'] as String? ?? '',
    );
  }
}

List<String> _strings(dynamic value) =>
    (value as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

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
  // All photos for the guide header, main photo first. Falls back to [image]
  // when the JSON has no "images" list.
  final List<String> images;
  final String description;
  final List<String> symptoms;
  // Problems that look similar, and how to tell them apart
  final List<String> lookAlikes;
  // Healthy result only: what to check by hand, and how to scan well
  final List<String> checks;
  final List<String> scanTips;
  final List<String> remediationSteps;
  final List<String> preventiveMeasures;
  // Who to contact, and when
  final List<String> getHelp;
  final List<GuideSource> sources;
  // Credits for the guide photos that are bundled with the app
  final List<PhotoCredit> photoCredits;
  // Date the content was last checked against the sources, like "2026-11-17"
  final String? reviewed;

  RemediationProtocol({
    required this.key,
    required this.name,
    required this.scientificName,
    required this.severity,
    required this.pathogenType,
    this.image,
    List<String>? images,
    required this.description,
    required this.symptoms,
    this.lookAlikes = const [],
    this.checks = const [],
    this.scanTips = const [],
    required this.remediationSteps,
    required this.preventiveMeasures,
    this.getHelp = const [],
    this.sources = const [],
    this.photoCredits = const [],
    this.reviewed,
  }) : images = (images != null && images.isNotEmpty)
           ? images
           : (image != null ? [image] : const []);

  // The model label, used to look up the disease color
  String get label => key.trim().replaceAll(RegExp(r'[\s\-]+'), '_');

  // Same three types as the protocols on the website
  String get kind {
    final type = pathogenType.toLowerCase();
    if (type.contains('no pathogen') || label == 'No_Disease') return 'Healthy';
    if (type.contains('disorder')) return 'Disorder';
    return 'Disease';
  }

  // Philippine sources first, then Southeast Asian, then international
  List<GuideSource> get sortedSources {
    final list = [...sources];
    list.sort((a, b) => a.tierRank.compareTo(b.tierRank));
    return list;
  }

  factory RemediationProtocol.fromJson(String key, Map<String, dynamic> json) {
    return RemediationProtocol(
      key: key,
      name: json['name'] as String? ?? key,
      scientificName: json['scientific_name'] as String? ?? 'N/A',
      severity: json['severity'] as String? ?? 'Medium',
      pathogenType: json['pathogen_type'] as String? ?? 'Unknown',
      image: json['image'] as String?,
      images: _strings(json['images']),
      description:
          json['description'] as String? ?? 'No description available.',
      symptoms: _strings(json['symptoms']),
      lookAlikes: _strings(json['look_alikes']),
      checks: _strings(json['checks']),
      scanTips: _strings(json['scan_tips']),
      remediationSteps: _strings(json['remediation_steps']),
      preventiveMeasures: _strings(json['preventive_measures']),
      getHelp: _strings(json['get_help']),
      sources:
          (json['sources'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(GuideSource.fromJson)
              .toList() ??
          [],
      photoCredits:
          (json['photo_credits'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(PhotoCredit.fromJson)
              .toList() ??
          [],
      reviewed: json['reviewed'] as String?,
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
        'Separate the affected plant or fruit from healthy ones.',
        'Clean knives, bolos and crates in 1 part household bleach (such as Zonrox) to 9 parts water, then rinse.',
        'Ask the Echague Municipal Agriculture Office which treatment to use.',
      ],
      preventiveMeasures: [
        'Keep drains clear and avoid wounding plants and fruit.',
        'Check plants often during warm, wet weather.',
      ],
    );
  }
}
