import 'package:flutter/material.dart';

import '../services/classifier_service.dart';
import '../theme/app_colors.dart';

// How sure the model is, as a thin bar with the percent next to it.
// Amber normally, red under the low confidence line. Same as ConfidenceBar on
// the website.
class ConfidenceBar extends StatelessWidget {
  final double value;

  const ConfidenceBar({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    final low = value < ClassifierService.minConfidence;
    final color = low ? context.colors.danger : context.colors.accent;

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 8,
              color: color,
              backgroundColor: context.colors.surface2,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          '${(value * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: low ? context.colors.danger : context.colors.text,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
