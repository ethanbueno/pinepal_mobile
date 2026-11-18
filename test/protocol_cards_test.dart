import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pinepal_mobile/models/remediation_protocol.dart';
import 'package:pinepal_mobile/theme/app_theme.dart';
import 'package:pinepal_mobile/widgets/protocol_cards.dart';

void main() {
  final protocol = RemediationProtocol(
    key: 'Crown Rot',
    name: 'Crown Rot',
    scientificName: 'Thielaviopsis paradoxa',
    severity: 'High',
    pathogenType: 'Fungus',
    description: 'A fungal rot that starts at the crown.',
    symptoms: ['Yellow crown leaves.', 'Soft tissue at the base.'],
    remediationSteps: ['Remove infected plants.', 'Treat the soil.'],
    preventiveMeasures: ['Avoid wounding the fruit.', 'Improve drainage.'],
  );

  testWidgets('symptoms and prevention show as bullet lists', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                PathogenCard(protocol: protocol),
                RemediationCard(protocol: protocol),
              ],
            ),
          ),
        ),
      ),
    );

    // Symptoms and prevention are bullet lists, one line per item
    expect(find.text('Yellow crown leaves.'), findsOneWidget);
    expect(find.text('Soft tissue at the base.'), findsOneWidget);
    expect(find.text('Avoid wounding the fruit.'), findsOneWidget);
    expect(find.text('Improve drainage.'), findsOneWidget);
    expect(find.byIcon(Icons.center_focus_weak), findsNothing);
    expect(find.byIcon(Icons.shield_outlined), findsNothing);

    // Same section titles as the remediation guide on the website
    expect(find.text('Symptoms'), findsOneWidget);
    expect(find.text('Immediate Action'), findsOneWidget);
    expect(find.text('Prevention'), findsOneWidget);

    // Steps keep their numbers because the order matters
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('2.'), findsOneWidget);
    expect(find.text('Remove infected plants.'), findsOneWidget);
  });

  test('images falls back to [image] when the JSON has no images list', () {
    final withImage = RemediationProtocol.fromJson('Crown Rot', {
      'image': 'assets/images/diseases/crown_rot.jpg',
    });
    expect(withImage.images, ['assets/images/diseases/crown_rot.jpg']);

    final withList = RemediationProtocol.fromJson('Crown Rot', {
      'image': 'a.jpg',
      'images': ['a.jpg', 'a_2.jpg'],
    });
    expect(withList.images, ['a.jpg', 'a_2.jpg']);

    final none = RemediationProtocol.fromJson('Crown Rot', {});
    expect(none.images, isEmpty);
  });
}
