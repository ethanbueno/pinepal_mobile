import 'package:flutter_test/flutter_test.dart';

import 'package:pinepal_mobile/main.dart';

void main() {
  testWidgets('App starts on the PinePal home screen', (tester) async {
    await tester.pumpWidget(const PinePalApp());

    expect(find.text('PINEPAL'), findsWidgets);
  });
}
