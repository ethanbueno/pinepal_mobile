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

// What the disease is and how to recognise it. The symptoms read as one short
// paragraph, so the card is not a list of bullets.
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
            'What to look for',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            protocol.symptoms.join(' '),
            style: TextStyle(
              color: context.colors.textMuted,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

// Treatment steps in order, then prevention as a short paragraph. Only the
// steps are numbered, because their order matters.
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
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '${i + 1}.',
                    style: TextStyle(
                      color: context.colors.accentText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
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
            'Prevention',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            protocol.preventiveMeasures.join(' '),
            style: TextStyle(
              color: context.colors.textMuted,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}
