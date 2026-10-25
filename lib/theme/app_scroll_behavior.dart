import 'package:flutter/material.dart';

// Scrolling for the whole app. Android 12+ stretches the list when you pull
// past the end; here the list just stops at the edge instead. Pull to refresh
// still works because it listens to the scroll itself, and iOS keeps its own
// native bounce.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
