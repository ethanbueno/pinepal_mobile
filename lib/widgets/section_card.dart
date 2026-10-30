import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

// A titled card, like a Card with a CardTitle on the web: ring border, rounded
// corners and a medium-weight title. An optional action sits at the right of the
// title.
class SectionCard extends StatelessWidget {
  final String title;
  final Widget? action;
  final List<Widget> children;

  const SectionCard({
    super.key,
    required this.title,
    this.action,
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
      // A Material of its own, so switches and list tiles inside the colored
      // card can draw their press effect
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ?action,
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
