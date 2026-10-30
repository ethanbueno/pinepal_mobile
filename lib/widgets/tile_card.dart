import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

// A card around a ListTile (a scan in a list, a disease in the guide), with the
// space below it. The card is a Material, so the tile can draw its press ripple;
// a plain colored Container would hide it.
class TileCard extends StatelessWidget {
  final Widget child;

  const TileCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: context.colors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}
