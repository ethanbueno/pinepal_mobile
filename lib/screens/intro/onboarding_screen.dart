import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'intro_content.dart';
import 'intro_loading_screen.dart';
import 'intro_widgets.dart';

// Three slides that advance on their own every 2.5 s and loop; the farmer can
// also swipe. Each slide has a main illustration with small images floating
// around it, which slide in and out faster than the page and bob while idle.
// The title and subtitle crossfade and rise a little on each change.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  static const _interval = Duration(milliseconds: 2500);
  static const _turn = Duration(milliseconds: 600);

  // The PageView starts far from page 0 and maps every page onto the slides,
  // so it loops in both directions.
  static final int _firstPage = onboardingSlides.length * 1000;

  late final PageController _pages = PageController(initialPage: _firstPage);
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  int _page = _firstPage;
  Timer? _timer;
  bool _dragging = false;

  OnboardingSlide get _slide =>
      onboardingSlides[_page % onboardingSlides.length];

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  // Restarted after every swipe, so a slide the farmer chose stays 2.5 s
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) {
      if (_dragging || !_pages.hasClients) return;
      _pages.nextPage(duration: _turn, curve: Curves.easeInOutCubic);
    });
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _dragging = true;
    } else if (notification is ScrollEndNotification && _dragging) {
      _dragging = false;
      _startTimer();
    }
    return false;
  }

  void _getStarted() {
    _timer?.cancel();
    Navigator.pushReplacement(
      context,
      introFadeRoute(const IntroLoadingScreen()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pages.dispose();
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IntroPage(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              SizedBox(
                height: constraints.maxHeight * 0.55,
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onScroll,
                  child: PageView.builder(
                    controller: _pages,
                    onPageChanged: (page) => setState(() => _page = page),
                    itemBuilder: (context, page) => _Illustration(
                      slide: onboardingSlides[page % onboardingSlides.length],
                      page: page,
                      pages: _pages,
                      bob: _bob,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: SizedBox(
                  height: 120,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 450),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.topCenter,
                      children: [...previous, ?current],
                    ),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0, 0.15),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: _SlideText(key: ValueKey(_page), slide: _slide),
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: IntroButton(
                  label: 'Get Started',
                  onPressed: _getStarted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideText extends StatelessWidget {
  final OnboardingSlide slide;

  const _SlideText({super.key, required this.slide});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          slide.title,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: context.colors.text,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          slide.subtitle,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: context.colors.textMuted,
          ),
        ),
      ],
    );
  }
}

// One slide's illustration: the main image in the middle and the floating
// images around it.
class _Illustration extends StatelessWidget {
  final OnboardingSlide slide;
  final int page;
  final PageController pages;
  final Animation<double> bob;

  const _Illustration({
    required this.slide,
    required this.page,
    required this.pages,
    required this.bob,
  });

  // How far this page is from the middle of the screen: 0 when it is
  // showing, -1 or 1 when it is one full page away.
  double _distance() {
    if (!pages.hasClients || !pages.position.haveDimensions) return 0;
    return (pages.page ?? page.toDouble()) - page;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Center(
                child: IntroImage(
                  slide.image,
                  width: width * 0.6,
                  height: height * 0.62,
                  radius: 28,
                ),
              ),
              for (final (i, floating) in slide.floatingImages.indexed)
                Align(
                  alignment: floating.alignment,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([pages, bob]),
                    builder: (context, child) {
                      final distance = _distance();
                      // The page already moves by its own width; the floating
                      // images move further, so they slide in and out.
                      final speed = 0.5 + 0.15 * i;
                      final dx = -distance * width * speed;
                      // Each one bobs at its own point in the cycle
                      final phase = (bob.value + i / 4) * 2 * math.pi;
                      final dy = math.sin(phase) * 7;
                      return Opacity(
                        opacity: (1 - distance.abs()).clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(dx, dy),
                          child: child,
                        ),
                      );
                    },
                    child: IntroImage(
                      floating.image,
                      width: floating.size,
                      height: floating.size,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
