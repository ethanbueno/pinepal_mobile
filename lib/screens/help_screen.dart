import 'package:flutter/material.dart';

import '../services/classifier_service.dart';
import '../theme/app_colors.dart';
import '../widgets/section_card.dart';

// How PinePal works and what is good to know, for any time after the first
// launch (the onboarding only shows once). The same points as "Learn more" on
// the web's farmer Home (src/components/LearnMore.jsx). Opened from the help
// button on Home and from Settings.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  // Same as HIGH_CONFIDENCE on the web (src/utils/diseases.js)
  static const highConfidence = 0.90;

  static String _pct(double value) => '${(value * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    final low = ClassifierService.minConfidence;

    const steps = [
      _Point(
        Icons.camera_alt_outlined,
        'Take a photo',
        'Tap the camera button and point it at the fruit, or pick a photo '
            'from your gallery.',
      ),
      _Point(
        Icons.document_scanner_outlined,
        'Get a diagnosis',
        'The app checks the photo right on your phone, even without internet, '
            'and names the disease with a confidence score.',
      ),
      _Point(
        Icons.assignment_outlined,
        'Follow the treatment',
        'Every result comes with step-by-step treatment and prevention advice '
            'for that disease. All guides are in the Guide tab.',
      ),
      _Point(
        Icons.map_outlined,
        'Track your farm',
        'Your scans sync to your account once you are online. Agricultural '
            'officers use them to spot outbreaks early.',
      ),
    ];

    final goodToKnow = [
      const _Point(
        Icons.wb_sunny_outlined,
        'Getting a good photo',
        'Use daylight, keep the whole fruit in the frame, and hold the phone '
            'steady. One fruit per photo.',
      ),
      _Point(
        Icons.speed_outlined,
        'What the confidence score means',
        '${_pct(highConfidence)} or more: the app is sure. ${_pct(low)} to '
            '${_pct(highConfidence)}: likely right. Below ${_pct(low)}: '
            'unsure, so take another photo. An agricultural officer can '
            'review it.',
      ),
      const _Point(
        Icons.wifi_off_outlined,
        'No signal in the field?',
        'Scanning works offline. Results wait on your phone and upload by '
            'themselves the next time you are online (see Sync in Settings).',
      ),
      const _Point(
        Icons.verified_outlined,
        'Officer checks',
        'An agricultural officer may check a synced scan and confirm or '
            'correct it. History shows "Checked by officer" or "Corrected by '
            'officer", and the scan\'s report says who checked it and when.',
      ),
      const _Point(
        Icons.devices_outlined,
        'One account, phone and web',
        'Sign in with the same account on the PinePal website. Scans you '
            'save there, or on another phone, show up in History here too.',
      ),
      const _Point(
        Icons.shield_outlined,
        'Who sees your scans',
        "Only you and PinePal's agricultural officers and admins.",
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('How PinePal works')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          SectionCard(
            title: 'How it works',
            children: [
              for (var i = 0; i < steps.length; i++)
                _PointRow(point: steps[i], number: i + 1),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            title: 'Good to know',
            children: [for (final point in goodToKnow) _PointRow(point: point)],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _Point {
  final IconData icon;
  final String title;
  final String text;

  const _Point(this.icon, this.title, this.text);
}

// An icon in a soft square, a title and a short text. Steps show their
// number in the title.
class _PointRow extends StatelessWidget {
  final _Point point;
  final int? number;

  const _PointRow({required this.point, this.number});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.colors.accentSoft,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Icon(point.icon, size: 20, color: context.colors.accentText),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  number == null ? point.title : '$number. ${point.title}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  point.text,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: context.colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
