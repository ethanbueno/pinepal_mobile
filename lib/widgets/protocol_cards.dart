import 'package:flutter/material.dart';

import '../models/remediation_protocol.dart';
import '../theme/app_colors.dart';
import 'disease_badge.dart';

// Shared by the diagnostic report and the Guide tab, so a disease looks the
// same wherever it is shown. The sections use the same titles as the
// remediation guide on the website: Symptoms, Immediate action, Prevention.

// Body text of the guide: a bit larger than normal and in the full text color,
// so it is easy to read outside in the sun.
const double guideTextSize = 16;
const double guideLineHeight = 1.5;

Color severityColor(BuildContext context, String severity) {
  switch (severity.toLowerCase()) {
    case 'none':
      return context.colors.success;
    case 'low':
    case 'medium':
      return context.colors.warning;
    case 'high':
    case 'critical':
      return context.colors.danger;
    default:
      return context.colors.textMuted;
  }
}

// The fixed disease color for a protocol, grey when there is none
Color protocolColor(BuildContext context, RemediationProtocol protocol) {
  return diseaseColors[protocol.label] ?? context.colors.textMuted;
}

// Small tinted pill, the same shape as the disease badge
class _Pill extends StatelessWidget {
  final String text;
  final Color color;

  const _Pill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// "High severity", colored by how serious it is
class SeverityChip extends StatelessWidget {
  final String severity;

  const SeverityChip({super.key, required this.severity});

  @override
  Widget build(BuildContext context) {
    return _Pill(
      text: '$severity severity',
      color: severityColor(context, severity),
    );
  }
}

// "Disease", "Disorder" or "Healthy"
class KindChip extends StatelessWidget {
  final String kind;

  const KindChip({super.key, required this.kind});

  @override
  Widget build(BuildContext context) {
    return _Pill(text: kind, color: context.colors.textMuted);
  }
}

// Name of the disease with its color, the scientific name and the two chips.
// Sits at the top of a guide page.
class DiseaseHeader extends StatelessWidget {
  final RemediationProtocol protocol;

  const DiseaseHeader({super.key, required this.protocol});

  @override
  Widget build(BuildContext context) {
    final color = protocolColor(context, protocol);
    final hasScientificName =
        protocol.scientificName.isNotEmpty && protocol.scientificName != 'N/A';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.colors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Color strip on the left, like the dot next to a disease name
            Container(width: 6, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      protocol.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    if (hasScientificName) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        protocol.scientificName,
                        style: TextStyle(
                          color: context.colors.textMuted,
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        KindChip(kind: protocol.kind),
                        SeverityChip(severity: protocol.severity),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Cause: ${protocol.pathogenType}',
                      style: TextStyle(
                        color: context.colors.textMuted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// A titled card with an icon in a soft amber square, like the scan hint on Home
class GuideSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const GuideSection({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
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
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.colors.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Icon(icon, size: 20, color: context.colors.accentText),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

// A plain paragraph of guide text
class GuideParagraph extends StatelessWidget {
  final String text;

  const GuideParagraph({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: guideTextSize, height: guideLineHeight),
    );
  }
}

// One numbered step. Only the steps are numbered, because their order matters;
// symptoms and prevention read as short paragraphs.
class GuideStep extends StatelessWidget {
  final String text;
  final int number;

  const GuideStep({super.key, required this.text, required this.number});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$number.',
              style: TextStyle(
                color: context.colors.accentText,
                fontSize: guideTextSize,
                fontWeight: FontWeight.w700,
                height: guideLineHeight,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: guideTextSize,
                height: guideLineHeight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// What the disease is, then the symptoms to look for
class PathogenCard extends StatelessWidget {
  final RemediationProtocol protocol;

  const PathogenCard({super.key, required this.protocol});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GuideSection(
          icon: Icons.info_outline,
          title: 'About',
          children: [GuideParagraph(text: protocol.description)],
        ),
        if (protocol.symptoms.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          GuideSection(
            icon: Icons.search,
            title: 'Symptoms',
            children: [GuideParagraph(text: protocol.symptoms.join(' '))],
          ),
        ],
      ],
    );
  }
}

// What to do now (numbered, the order matters), then how to prevent it
class RemediationCard extends StatelessWidget {
  final RemediationProtocol protocol;

  const RemediationCard({super.key, required this.protocol});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GuideSection(
          icon: Icons.healing_outlined,
          title: 'Immediate action',
          children: [
            for (var i = 0; i < protocol.remediationSteps.length; i++)
              GuideStep(text: protocol.remediationSteps[i], number: i + 1),
          ],
        ),
        if (protocol.preventiveMeasures.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          GuideSection(
            icon: Icons.eco_outlined,
            title: 'Prevention',
            children: [
              GuideParagraph(text: protocol.preventiveMeasures.join(' ')),
            ],
          ),
        ],
      ],
    );
  }
}
