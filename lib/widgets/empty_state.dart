import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

// An icon, a short title and a hint, for a list with nothing in it.
// Same as EmptyState on the website.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? text;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.text,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.section,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.colors.line),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: context.colors.textMuted),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          if (text != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              text!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: context.colors.textMuted),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: AppSpacing.lg),
            action!,
          ],
        ],
      ),
    );
  }
}
