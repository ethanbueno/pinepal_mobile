import 'package:flutter/material.dart';

import '../models/remediation_protocol.dart';
import '../theme/app_colors.dart';

// Shared by the diagnostic report and the Guide tab, so a disease looks the
// same wherever it is shown.

Color severityColor(BuildContext context, String severity) {
  switch (severity.toLowerCase()) {
    case 'none':
      return context.colors.success;
    case 'low':
      return const Color(0xFF7CB342);
    case 'medium':
      return context.colors.warning;
    case 'high':
      return context.colors.danger;
    case 'critical':
      return const Color(0xFFB62324);
    default:
      return context.colors.textMuted;
  }
}

// Small rounded label such as "Severity: HIGH"
class SeverityChip extends StatelessWidget {
  final String severity;

  const SeverityChip({super.key, required this.severity});

  @override
  Widget build(BuildContext context) {
    final color = severityColor(context, severity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color),
      ),
      child: Text(
        'Severity: ${severity.toUpperCase()}',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _Section({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: context.colors.accent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

Widget _bullet(BuildContext context, String text, IconData icon, Color color) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: context.colors.textMuted, fontSize: 14),
          ),
        ),
      ],
    ),
  );
}

// What the disease is and how to recognise it
class PathogenCard extends StatelessWidget {
  final RemediationProtocol protocol;

  const PathogenCard({super.key, required this.protocol});

  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: Icons.biotech_outlined,
      title: 'About (${protocol.pathogenType})',
      children: [
        Text(
          protocol.description,
          style: TextStyle(
            color: context.colors.textMuted,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        if (protocol.symptoms.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Key visual symptoms',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (final symptom in protocol.symptoms)
            _bullet(context, symptom, Icons.center_focus_weak, context.colors.accent),
        ],
      ],
    );
  }
}

// Numbered treatment steps, then preventive practices
class RemediationCard extends StatelessWidget {
  final RemediationProtocol protocol;

  const RemediationCard({super.key, required this.protocol});

  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: Icons.healing,
      title: 'Step-by-step remediation',
      children: [
        for (var i = 0; i < protocol.remediationSteps.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.canvas,
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(color: context.colors.line),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: context.colors.accent,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: context.colors.onAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    protocol.remediationSteps[i],
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        if (protocol.preventiveMeasures.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'Preventive and cultural practices',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (final measure in protocol.preventiveMeasures)
            _bullet(context, measure, Icons.shield_outlined, context.colors.success),
        ],
      ],
    );
  }
}
