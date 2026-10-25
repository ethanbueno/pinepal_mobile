import 'package:flutter/material.dart';

import '../services/label_service.dart';
import '../theme/app_colors.dart';

// One place for disease colors so a class always looks the same, as on the web
// (src/utils/diseases.js).
const Map<String, Color> diseaseColors = {
  'Crown_Rot': Color(0xFFD97706),
  'Fruit_Rot': Color(0xFFB91C1C),
  'Mealybug_Wilt': Color(0xFF7C3AED),
  'Fruit_Fasciation': Color(0xFF2563EB),
  'Multiple_Crown': Color(0xFF0891B2),
  'No_Disease': Color(0xFF16A34A),
};

// Pill with the disease name in its color, like the web DiseaseBadge
class DiseaseBadge extends StatelessWidget {
  final String label;

  const DiseaseBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = diseaseColors[label] ?? context.colors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        LabelService.pretty(label),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
