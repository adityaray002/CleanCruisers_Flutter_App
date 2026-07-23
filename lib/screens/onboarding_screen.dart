import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _controller = PageController();
  int _page = 0;

  static const _slides = [
    _Slide(
      emoji: '🚗',
      title: 'Doorstep Car Wash\nin Delhi NCR',
      description:
          'Trained professionals come to your home, office, or society and clean your car with professional-grade equipment.\n\nNo driving to a wash centre. No waiting in queues.',
      badge: 'DOORSTEP SERVICE',
      gradient: [Color(0xFF052E16), Color(0xFF0D1F0E)],
    ),
    _Slide(
      emoji: '📱',
      title: 'Book in Under\n2 Minutes',
      description:
          'Choose your service, car type, and preferred time. Confirm on WhatsApp — and our team shows up at your door.\n\nNo app account needed. No complicated forms.',
      badge: 'EASY BOOKING',
      gradient: [Color(0xFF1E1B4B), Color(0xFF0F0B2B)],
    ),
    _Slide(
      emoji: '✅',
      title: 'No Advance Payment.\nEver.',
      description:
          'Pay only after the service is done and you are 100% satisfied. Available 7 days a week from 7 AM to 8 PM.\n\n4.9★ rated by 1000+ happy customers in Delhi.',
      badge: 'TRUSTED SERVICE',
      gradient: [Color(0xFF1A0533), Color(0xFF100220)],
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) context.go('/home');
  }

  void _next() {
    if (_page < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgBlack,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  ClipOval(
                    child: Image.asset('assets/images/logo.png',
                        width: 36, height: 36, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 10),
                  const Text('CleanCruisers',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  if (_page < _slides.length - 1)
                    TextButton(
                      onPressed: _finish,
                      child: const Text('Skip',
                          style: TextStyle(color: kGray400, fontSize: 14)),
                    ),
                ],
              ),
            ),

            // Slides
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _slides.length,
                itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
              ),
            ),

            // Dots + Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _page ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page ? kGreen400 : kGray700,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: Text(
                        _page == _slides.length - 1
                            ? 'Get Started — It\'s Free'
                            : 'Next',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
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

class _Slide {
  final String emoji;
  final String title;
  final String description;
  final String badge;
  final List<Color> gradient;
  const _Slide({
    required this.emoji,
    required this.title,
    required this.description,
    required this.badge,
    required this.gradient,
  });
}

class _SlideView extends StatefulWidget {
  final _Slide slide;
  const _SlideView({required this.slide});

  @override
  State<_SlideView> createState() => _SlideViewState();
}

class _SlideViewState extends State<_SlideView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _slide = Tween(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));
    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Emoji with gradient circle
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.slide.gradient,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: kGreen400.withAlpha(77), width: 2),
                ),
                child: Center(
                  child: Text(widget.slide.emoji,
                      style: const TextStyle(fontSize: 64)),
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: kGreen400.withAlpha(26),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kGreen400.withAlpha(77)),
                ),
                child: Text(widget.slide.badge,
                    style: const TextStyle(
                        color: kGreen400,
                        fontSize: 10, fontWeight: FontWeight.w800,
                        letterSpacing: 1.5)),
              ),
              const SizedBox(height: 16),
              Text(
                widget.slide.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28, fontWeight: FontWeight.w800,
                    height: 1.2, letterSpacing: -0.5),
              ),
              const SizedBox(height: 16),
              Text(
                widget.slide.description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: kGray400, fontSize: 14, height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
