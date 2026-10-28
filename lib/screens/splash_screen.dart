import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../data/business_info.dart';

/// Brand moment shown while the app starts: rising foam bubbles, the logo
/// popping in inside a spinning ring with a shine sweep, the wordmark, and a
/// progress bar that fills until we move on to the home screen.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  static const _total = Duration(milliseconds: 2200);

  // One-shot intro; each element animates in its own slice of it.
  late final AnimationController _intro = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500));

  // Looping motion: ring spin and bubbles.
  late final AnimationController _loop = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 6000));

  // Fills the progress bar over the whole splash, then navigates.
  late final AnimationController _progress =
      AnimationController(vsync: this, duration: _total);

  Animation<double> _slice(double from, double to,
          [Curve curve = Curves.easeOutCubic]) =>
      CurvedAnimation(parent: _intro, curve: Interval(from, to, curve: curve));

  late final _logoIn = _slice(0.0, 0.45, Curves.easeOutBack);
  late final _logoFade = _slice(0.0, 0.25);
  late final _ringIn = _slice(0.15, 0.5);
  late final _shine = _slice(0.4, 0.8, Curves.easeInOut);
  late final _wordIn = _slice(0.35, 0.7);
  late final _tagIn = _slice(0.55, 0.85);
  late final _footIn = _slice(0.7, 1.0);

  @override
  void initState() {
    super.initState();
    _intro.forward();
    _loop.repeat();
    _progress.forward().whenComplete(() {
      if (mounted) context.go('/home');
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect "remove animations": skip the looping motion.
    if (MediaQuery.of(context).disableAnimations) _loop.stop();
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(fit: StackFit.expand, children: [
          // Soft mint glow behind the logo, another lower down.
          const _Glow(alignment: Alignment(0, -0.15), size: 440, alpha: 46),
          const _Glow(alignment: Alignment(0.9, 1.1), size: 380, alpha: 30),

          // Rising foam bubbles.
          RepaintBoundary(
            child: CustomPaint(painter: _BubblePainter(_loop)),
          ),

          // ── Centre: logo + wordmark ──────────────────────────────────────
          Align(
            alignment: const Alignment(0, -0.12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _Logo(
                scale: _logoIn,
                fade: _logoFade,
                ringIn: _ringIn,
                spin: _loop,
                shine: _shine,
              ),
              const SizedBox(height: 34),
              _Rise(
                anim: _wordIn,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text.rich(
                    const TextSpan(children: [
                      TextSpan(text: 'CLEAN'),
                      TextSpan(
                          text: 'CRUISERS',
                          style: TextStyle(color: AppColors.primary)),
                    ]),
                    style: AppText.display.copyWith(
                        color: AppColors.text, fontSize: 30, letterSpacing: 3),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _Rise(
                anim: _tagIn,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const _Rule(reversed: true),
                  const SizedBox(width: 10),
                  Text('Doorstep Car Wash & Detailing',
                      style: AppText.small.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6)),
                  const SizedBox(width: 10),
                  const _Rule(),
                ]),
              ),
            ]),
          ),

          // ── Bottom: progress + trust line ────────────────────────────────
          Positioned(
            left: 24,
            right: 24,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: FadeTransition(
                  opacity: _footIn,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    _ProgressBar(progress: _progress),
                    const SizedBox(height: 18),
                    Text(
                      '$kCityLabel  •  $kHoursLabel  •  Pay after service',
                      textAlign: TextAlign.center,
                      style: AppText.caption,
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Pieces ────────────────────────────────────────────────────────────────────

class _Glow extends StatelessWidget {
  final Alignment alignment;
  final double size;
  final int alpha;
  const _Glow(
      {required this.alignment, required this.size, required this.alpha});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              AppColors.brand.withAlpha(alpha),
              AppColors.brand.withAlpha(0),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Logo in a glowing disc, ringed by a spinning gradient arc, with a single
/// light sweep across it once it lands.
class _Logo extends StatelessWidget {
  final Animation<double> scale, fade, ringIn, spin, shine;
  const _Logo({
    required this.scale,
    required this.fade,
    required this.ringIn,
    required this.spin,
    required this.shine,
  });

  static const _logo = 112.0;
  static const _ring = 146.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _ring,
      height: _ring,
      child: Stack(alignment: Alignment.center, children: [
        // Spinning arc.
        FadeTransition(
          opacity: ringIn,
          child: RotationTransition(
            turns: spin,
            child: CustomPaint(
                size: const Size.square(_ring), painter: _RingPainter()),
          ),
        ),
        // Logo disc.
        FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: Tween(begin: 0.6, end: 1.0).animate(scale),
            child: Container(
              width: _logo,
              height: _logo,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                // The logo's own white rim would vanish on white, so lift it
                // with a soft green shadow.
                boxShadow: [
                  BoxShadow(
                      color: AppColors.primary.withAlpha(45),
                      blurRadius: 30,
                      offset: const Offset(0, 10)),
                  BoxShadow(
                      color: AppColors.brand.withAlpha(70),
                      blurRadius: 40,
                      spreadRadius: 2),
                ],
              ),
              child: ClipOval(
                child: Stack(fit: StackFit.expand, children: [
                  Image.asset('assets/images/logo.png', fit: BoxFit.cover),
                  // Light sweep, left to right.
                  AnimatedBuilder(
                    animation: shine,
                    builder: (_, __) {
                      final t = shine.value;
                      if (t == 0 || t == 1) return const SizedBox.shrink();
                      return FractionalTranslation(
                        translation: Offset(-1.2 + t * 2.4, 0),
                        child: Transform.rotate(
                          angle: 0.35,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                Colors.white.withAlpha(0),
                                Colors.white.withAlpha(90),
                                Colors.white.withAlpha(0),
                              ], stops: const [
                                0.3,
                                0.5,
                                0.7
                              ]),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(colors: [
        AppColors.brand.withAlpha(0),
        AppColors.brand.withAlpha(0),
        AppColors.brand,
        AppColors.primary,
      ], stops: const [
        0.0,
        0.35,
        0.8,
        1.0
      ]).createShader(rect);
    canvas.drawArc(rect.deflate(2), 0, math.pi * 2, false, stroke);

    // Head at the end of the arc.
    canvas.drawCircle(Offset(size.width - 2, size.height / 2), 3.4,
        Paint()..color = AppColors.primary);

    // Faint full track.
    canvas.drawCircle(
        rect.center,
        size.width / 2 - 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = AppColors.primary.withAlpha(22));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Foam bubbles drifting up the screen, each on its own speed and sway.
class _BubblePainter extends CustomPainter {
  final Animation<double> t;
  _BubblePainter(this.t) : super(repaint: t);

  static final _bubbles = () {
    final r = math.Random(7); // fixed seed: same layout every launch
    return [
      for (var i = 0; i < 18; i++)
        (
          x: r.nextDouble(),
          size: 3 + r.nextDouble() * 9,
          speed: 1 + r.nextInt(2).toDouble(), // whole loops → seamless
          phase: r.nextDouble(),
          sway: 6 + r.nextDouble() * 10,
        ),
    ];
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final fill = Paint();
    final glint = Paint();

    for (final b in _bubbles) {
      final p = (t.value * b.speed + b.phase) % 1.0; // 0 bottom → 1 top
      final y = size.height * (1.05 - p * 1.15);
      final x = size.width * b.x +
          math.sin((t.value * b.speed + b.phase) * math.pi * 4) * b.sway;
      // Fade in near the bottom, out near the top.
      final a = math.sin(p * math.pi);
      final c = Offset(x, y);

      fill.color = AppColors.brand.withAlpha((22 * a).round());
      ring.color = AppColors.primary.withAlpha((60 * a).round());
      canvas.drawCircle(c, b.size, fill);
      canvas.drawCircle(c, b.size, ring);
      glint.color = AppColors.primary.withAlpha((45 * a).round());
      canvas.drawCircle(
          c.translate(-b.size * 0.35, -b.size * 0.35), b.size * 0.22, glint);
    }
  }

  @override
  bool shouldRepaint(covariant _BubblePainter old) => false;
}

/// Fades a child in while sliding it up a little.
class _Rise extends StatelessWidget {
  final Animation<double> anim;
  final Widget child;
  const _Rise({required this.anim, required this.child});

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position:
            Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(anim),
        child: child,
      ),
    );
  }
}

/// Short green line that fades out towards its outer end.
class _Rule extends StatelessWidget {
  final bool reversed;
  const _Rule({this.reversed = false});

  @override
  Widget build(BuildContext context) {
    final colors = [AppColors.primary, AppColors.primary.withAlpha(0)];
    return Container(
      width: 28,
      height: 1.5,
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: reversed ? colors.reversed.toList() : colors),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final Animation<double> progress;
  const _ProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 140,
        height: 4,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: AnimatedBuilder(
          animation: progress,
          builder: (_, __) => Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: Curves.easeInOut.transform(progress.value),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.brand]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
