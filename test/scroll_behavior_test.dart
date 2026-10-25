import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pinepal_mobile/theme/app_scroll_behavior.dart';

Widget _list({ScrollBehavior? behavior}) {
  return MaterialApp(
    scrollBehavior: behavior,
    home: Scaffold(
      body: ListView(children: [for (var i = 0; i < 50; i++) Text('row $i')]),
    ),
  );
}

void main() {
  testWidgets('lists have no stretch or glow when pulled past the end', (
    tester,
  ) async {
    await tester.pumpWidget(_list(behavior: const AppScrollBehavior()));

    expect(find.byType(StretchingOverscrollIndicator), findsNothing);
    expect(find.byType(GlowingOverscrollIndicator), findsNothing);

    // Pulling down at the top must not move anything
    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('row 0')).dy, lessThan(100));
  });

  testWidgets('the default Android behavior does add an indicator', (
    tester,
  ) async {
    await tester.pumpWidget(_list());

    // Proves the test above would notice the old stretch coming back
    final hasIndicator =
        find.byType(StretchingOverscrollIndicator).evaluate().isNotEmpty ||
        find.byType(GlowingOverscrollIndicator).evaluate().isNotEmpty;
    expect(hasIndicator, true);
  });
}
