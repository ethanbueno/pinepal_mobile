import 'package:flutter/material.dart';

// Everything the intro shows: edit the text and image paths here.
// Images go in assets/intro/. Until a file exists, a gray box with its file
// name is shown in its place (see IntroImage), so the app still runs.
// Colors come from the app theme (context.colors), light or dark.

class IntroAssets {
  // The logo is drawn as a single-color silhouette (white on black, then the
  // theme's text color), so any logo PNG with a transparent background works.
  static const logo = 'assets/icons/logo.png';
}

// A small image floating around a slide's main illustration.
// alignment places it in the illustration area: (-1, -1) is the top left
// corner, (1, 1) the bottom right. size is its width and height.
class FloatingImage {
  final String image;
  final Alignment alignment;
  final double size;

  const FloatingImage(this.image, this.alignment, {this.size = 64});
}

class OnboardingSlide {
  final String image; // the main center illustration
  final List<FloatingImage> floatingImages; // 3 or 4 around it
  final String title; // 2 lines
  final String subtitle; // 1 or 2 lines

  const OnboardingSlide({
    required this.image,
    required this.floatingImages,
    required this.title,
    required this.subtitle,
  });
}

const List<OnboardingSlide> onboardingSlides = [
  OnboardingSlide(
    image: 'assets/intro/slide1_main.png',
    floatingImages: [
      FloatingImage('assets/intro/slide1_float1.png', Alignment(-0.9, -0.85)),
      FloatingImage('assets/intro/slide1_float2.png', Alignment(0.9, -0.6)),
      FloatingImage('assets/intro/slide1_float3.png', Alignment(-0.85, 0.75)),
      FloatingImage('assets/intro/slide1_float4.png', Alignment(0.85, 0.9)),
    ],
    title: 'Spot pineapple\ndiseases early',
    subtitle:
        'Take a photo of the fruit, crown or leaves and get a diagnosis in seconds.',
  ),
  OnboardingSlide(
    image: 'assets/intro/slide2_main.png',
    floatingImages: [
      FloatingImage('assets/intro/slide2_float1.png', Alignment(0.85, -0.9)),
      FloatingImage('assets/intro/slide2_float2.png', Alignment(-0.9, -0.3)),
      FloatingImage('assets/intro/slide2_float3.png', Alignment(0.9, 0.7)),
    ],
    title: 'Works in the field,\neven offline',
    subtitle:
        'Scans are checked on your phone, then synced when you are back online.',
  ),
  OnboardingSlide(
    image: 'assets/intro/slide3_main.png',
    floatingImages: [
      FloatingImage('assets/intro/slide3_float1.png', Alignment(-0.85, -0.8)),
      FloatingImage('assets/intro/slide3_float2.png', Alignment(0.9, -0.75)),
      FloatingImage('assets/intro/slide3_float3.png', Alignment(-0.9, 0.85)),
      FloatingImage('assets/intro/slide3_float4.png', Alignment(0.8, 0.8)),
    ],
    title: 'Know what to do\nnext',
    subtitle:
        'Every result comes with treatment steps from the PinePal disease guide.',
  ),
];

class WelcomeContent {
  static const title = 'Welcome to\nPinePal';
  static const subtitle =
      'Sign in to sync your scans with your agricultural officer.';

  // The row of images that slowly scrolls across the middle of the screen
  static const marqueeImages = [
    'assets/intro/welcome_item1.png',
    'assets/intro/welcome_item2.png',
    'assets/intro/welcome_item3.png',
    'assets/intro/welcome_item4.png',
    'assets/intro/welcome_item5.png',
    'assets/intro/welcome_item6.png',
  ];
}
