import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants.dart';
import '../core/router.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // Logo: scale + fade
  late final AnimationController _logoCtrl;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;

  // Text: slide up + fade
  late final AnimationController _textCtrl;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _textFade;

  // Tagline: fade after text
  late final Animation<double> _tagFade;

  // Dots: looping pulse
  late final AnimationController _dotCtrl;
  late final Animation<double> _dotAnim;

  @override
  void initState() {
    super.initState();

    // ── Logo animation (elastic pop-in) ───────────────────────────────────────
    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoFade = CurvedAnimation(parent: _logoCtrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut));

    // ── Text animation (slide up + fade) ──────────────────────────────────────
    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _textSlide = Tween<Offset>(
            begin: const Offset(0, 0.35), end: Offset.zero)
        .animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));
    _textFade =
        CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut);
    _tagFade = CurvedAnimation(parent: _textCtrl,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOut));

    // ── Dots pulse (looping) ──────────────────────────────────────────────────
    _dotCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _dotAnim = CurvedAnimation(parent: _dotCtrl, curve: Curves.easeInOut);

    // ── Sequence: logo → text → navigate ──────────────────────────────────────
    _logoCtrl.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 150),
          () { if (mounted) _textCtrl.forward(); });
    });

    // Total visible time: ~2.8 seconds
    Timer(const Duration(milliseconds: 2800), () {
      if (!mounted) return;
      final done = ref.read(onboardingDoneProvider);
      context.go(done ? '/home' : '/onboarding');
    });
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _dotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgBlack,
      body: Stack(
        children: [
          // Background radial glow
          Center(
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    kGreen400.withAlpha(25),
                    Colors.transparent,
                  ],
                  radius: 0.8,
                ),
              ),
            ),
          ),

          // Main content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Logo ──────────────────────────────────────────────────────
                ScaleTransition(
                  scale: _logoScale,
                  child: FadeTransition(
                    opacity: _logoFade,
                    child: Container(
                      width: 110, height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: kGreen400.withAlpha(80), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: kGreen400.withAlpha(40),
                            blurRadius: 30, spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // ── Brand name ────────────────────────────────────────────────
                SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textFade,
                    child: Column(
                      children: [
                        // CLEANCRUISERS — letter-spaced bold
                        const Text(
                          'CLEANCRUISERS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Tagline
                        FadeTransition(
                          opacity: _tagFade,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                  width: 28, height: 1.5,
                                  color: kGreen400.withAlpha(150)),
                              const SizedBox(width: 10),
                              const Text(
                                'Doorstep Car Wash & Detailing',
                                style: TextStyle(
                                  color: kGreen400,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                  width: 28, height: 1.5,
                                  color: kGreen400.withAlpha(150)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 56),

                // ── Animated loading dots ─────────────────────────────────────
                FadeTransition(
                  opacity: _textFade,
                  child: _PulseDots(anim: _dotAnim),
                ),
              ],
            ),
          ),

          // Bottom label
          Positioned(
            bottom: 40, left: 0, right: 0,
            child: FadeTransition(
              opacity: _tagFade,
              child: const Text(
                'Delhi NCR • 8 AM – 6 PM • No Advance Payment',
                textAlign: TextAlign.center,
                style: TextStyle(color: kGray400, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Three pulsing green dots
class _PulseDots extends StatelessWidget {
  final Animation<double> anim;
  const _PulseDots({required this.anim});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        // Stagger each dot by 150ms via Interval
        final staggered = CurvedAnimation(
          parent: anim,
          curve: Interval(i * 0.2, 0.6 + i * 0.2,
              curve: Curves.easeInOut),
        );
        return AnimatedBuilder(
          animation: staggered,
          builder: (_, __) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 7 + staggered.value * 3,
            height: 7 + staggered.value * 3,
            decoration: BoxDecoration(
              color: kGreen400.withAlpha(
                  (100 + (staggered.value * 155)).round()),
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}
