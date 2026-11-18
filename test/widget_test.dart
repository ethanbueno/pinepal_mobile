import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pinepal_mobile/main.dart';
import 'package:pinepal_mobile/screens/home_screen.dart';
import 'package:pinepal_mobile/screens/intro/onboarding_screen.dart';
import 'package:pinepal_mobile/screens/intro/splash_screen.dart';
import 'package:pinepal_mobile/screens/intro/welcome_screen.dart';
import 'package:pinepal_mobile/services/app_settings.dart';
import 'package:pinepal_mobile/widgets/pinepal_loader.dart';

// Moves time forward frame by frame, so animations and timers run as in the app
Future<void> wait(WidgetTester tester, int milliseconds) async {
  for (var t = 0; t < milliseconds; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  // every test starts as a first launch
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.load();
  });

  testWidgets('App starts on the PinePal home screen', (tester) async {
    await tester.pumpWidget(const PinePalApp(showIntro: false));

    expect(find.text('PinePal'), findsWidgets);
  });

  testWidgets('intro: splash, onboarding, loading, then welcome', (
    tester,
  ) async {
    await tester.pumpWidget(const PinePalApp());

    // splash: hold, fade to the page color, then the onboarding fades in
    await wait(tester, 3200);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Spot pineapple\ndiseases early'), findsOneWidget);

    // it moves to the next slide on its own
    await wait(tester, 3200);
    expect(find.text('Works in the field,\neven offline'), findsOneWidget);

    await tester.tap(find.text('Get Started'));
    await wait(tester, 600);
    expect(find.byType(PinePalLoader), findsOneWidget);

    await wait(tester, 1800);
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
    expect(find.textContaining('or sign in using'), findsNothing);

    // Skip goes to the home screen without an account, and the intro is done
    await tester.tap(find.text('Skip'));
    await wait(tester, 800);
    expect(find.byType(WelcomeScreen), findsNothing);
    expect(find.text('PinePal'), findsWidgets);
    expect(AppSettings.instance.introSeen, true);
  });

  testWidgets('after the first time the splash goes straight home', (
    tester,
  ) async {
    await AppSettings.instance.setIntroSeen();
    await tester.pumpWidget(const PinePalApp());

    expect(find.byType(SplashScreen), findsOneWidget);
    await wait(tester, 3200);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
