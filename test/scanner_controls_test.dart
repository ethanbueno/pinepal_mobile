import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pinepal_mobile/widgets/scanner_controls.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('shutter button reacts to taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(ShutterButton(onPressed: () => taps++)));

    await tester.tap(find.byType(ShutterButton));
    expect(taps, 1);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shutter button shows a spinner while busy', (tester) async {
    await tester.pumpWidget(_host(ShutterButton(onPressed: () {}, busy: true)));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('glass button does nothing when it is disabled', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlassButton(
              icon: Icons.history,
              tooltip: 'On',
              onPressed: () => taps++,
            ),
            const GlassButton(
              icon: Icons.close,
              tooltip: 'Off',
              onPressed: null,
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.history));
    await tester.tap(find.byIcon(Icons.close), warnIfMissed: false);
    expect(taps, 1);
  });

  testWidgets('viewfinder frame draws and ignores touches', (tester) async {
    await tester.pumpWidget(
      _host(const SizedBox(width: 300, height: 500, child: ViewfinderFrame())),
    );

    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byType(IgnorePointer), findsWidgets);
  });
}
