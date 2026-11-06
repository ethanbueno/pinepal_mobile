import 'package:flutter/material.dart';

import '../../services/app_settings.dart';
import '../../theme/app_colors.dart';
import '../home_screen.dart';
import '../login_screen.dart';
import '../register_screen.dart';
import 'intro_content.dart';
import 'intro_widgets.dart';

// The last intro screen: heading, a slowly scrolling row of images, sign in and
// register. Signing in or registering opens the app's own screens and then goes
// to the home screen. "Skip" goes there without an account: scanning works
// without one, and the farmer can sign in later from Profile. Either way the
// intro is done and does not show again.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _goHome(BuildContext context) {
    AppSettings.instance.setIntroSeen();
    Navigator.pushAndRemoveUntil(
      context,
      introFadeRoute(const HomeScreen()),
      (route) => false,
    );
  }

  // LoginScreen and RegisterScreen pop with true once signed in
  Future<void> _open(BuildContext context, Widget screen) async {
    final signedIn = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
    if (signedIn != true || !context.mounted) return;
    _goHome(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return IntroPage(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 4, 12, 0),
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: colors.textMuted,
                    textStyle: const TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed: () => _goHome(context),
                  child: const Text('Skip'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
              child: Column(
                children: [
                  Text(
                    WelcomeContent.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    WelcomeContent.subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(
              child: Center(
                child: _Marquee(images: WelcomeContent.marqueeImages),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Column(
                children: [
                  IntroButton(
                    label: 'Sign in',
                    onPressed: () => _open(context, const LoginScreen()),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(fontSize: 13, color: colors.textMuted),
                      ),
                      GestureDetector(
                        onTap: () => _open(context, const RegisterScreen()),
                        child: Text(
                          'Register',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.accentText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// A row of images that keeps sliding to the left and wraps around
class _Marquee extends StatefulWidget {
  final List<String> images;

  const _Marquee({required this.images});

  @override
  State<_Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<_Marquee>
    with SingleTickerProviderStateMixin {
  static const _itemWidth = 120.0;
  static const _itemHeight = 150.0;
  static const _gap = 14.0;
  static const _speed = 30.0; // pixels per second

  double get _rowWidth => widget.images.length * (_itemWidth + _gap);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (_rowWidth / _speed * 1000).round()),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _itemHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // enough copies of the row to always fill the screen width
          final copies = (constraints.maxWidth / _rowWidth).ceil() + 1;
          return ClipRect(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final shift = _controller.value * _rowWidth;
                return Stack(
                  children: [
                    for (var copy = 0; copy < copies; copy++)
                      for (final (i, image) in widget.images.indexed)
                        Positioned(
                          left:
                              copy * _rowWidth +
                              i * (_itemWidth + _gap) -
                              shift,
                          top: 0,
                          width: _itemWidth,
                          height: _itemHeight,
                          child: IntroImage(
                            image,
                            fit: BoxFit.cover,
                            radius: 20,
                          ),
                        ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
