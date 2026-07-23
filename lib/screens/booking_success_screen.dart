import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import '../core/pricing.dart';
import '../providers/booking_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BookingSuccessScreen extends ConsumerStatefulWidget {
  const BookingSuccessScreen({super.key});

  @override
  ConsumerState<BookingSuccessScreen> createState() =>
      _BookingSuccessScreenState();
}

class _BookingSuccessScreenState extends ConsumerState<BookingSuccessScreen>
    with TickerProviderStateMixin {
  late final AnimationController _checkAnim;
  late final AnimationController _contentAnim;
  late final Animation<double> _checkScale;
  late final Animation<double> _checkOpacity;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();

    _checkAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _contentAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));

    _checkScale = CurvedAnimation(parent: _checkAnim, curve: Curves.elasticOut);
    _checkOpacity = CurvedAnimation(parent: _checkAnim, curve: Curves.easeIn);
    _contentFade = CurvedAnimation(parent: _contentAnim, curve: Curves.easeOut);
    _contentSlide =
        Tween(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _contentAnim, curve: Curves.easeOut),
    );

    // Stagger: checkmark first, then content
    _checkAnim.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 100),
          () => _contentAnim.forward());
    });
  }

  @override
  void dispose() {
    _checkAnim.dispose();
    _contentAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookingProvider);
    final total = state.computeTotal();

    return Scaffold(
      backgroundColor: kBgBlack,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),

              // ── Animated checkmark ────────────────────────────────────────
              FadeTransition(
                opacity: _checkOpacity,
                child: ScaleTransition(
                  scale: _checkScale,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: kGreen400.withAlpha(26),
                      border: Border.all(color: kGreen400, width: 3),
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: kGreen400, size: 64),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // ── Content ───────────────────────────────────────────────────
              FadeTransition(
                opacity: _contentFade,
                child: SlideTransition(
                  position: _contentSlide,
                  child: Column(
                    children: [
                      const Text('Booking Request Sent! 🎉',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 26, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      const Text(
                        'Our team will confirm your slot on WhatsApp\nwithin 30 minutes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: kGray400, fontSize: 14, height: 1.5),
                      ),
                      const SizedBox(height: 28),

                      // Booking summary card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: kBgCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: kGreen400.withAlpha(77)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Your Booking Summary',
                                style: TextStyle(
                                    color: kGray400,
                                    fontSize: 11, fontWeight: FontWeight.w600,
                                    letterSpacing: 0.8)),
                            const SizedBox(height: 12),
                            _SummaryRow(
                                icon: Icons.miscellaneous_services,
                                label: state.serviceTypeLabel),
                            if (state.carType != null)
                              _SummaryRow(
                                  icon: Icons.directions_car,
                                  label: carTypeNames[state.carType]!),
                            if (state.carModel.isNotEmpty)
                              _SummaryRow(
                                  icon: Icons.car_repair,
                                  label: state.carModel),
                            if (state.preferredDate != null)
                              _SummaryRow(
                                  icon: Icons.calendar_today,
                                  label: state.formattedDate),
                            if (state.preferredTimeSlot.isNotEmpty)
                              _SummaryRow(
                                  icon: Icons.schedule,
                                  label: state.preferredTimeSlot),
                            if (total > 0) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 10),
                                child: Divider(color: kGray700, height: 1),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Estimated Total',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600)),
                                  Text('₹$total',
                                      style: const TextStyle(
                                          color: kGreen400,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // What happens next
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: kGreen400.withAlpha(13),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: kGreen400.withAlpha(51)),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('What happens next?',
                                style: TextStyle(
                                    color: kGreen400,
                                    fontSize: 12, fontWeight: FontWeight.w700)),
                            SizedBox(height: 8),
                            _NextStep(n: '1', text: 'Our team calls to confirm your slot'),
                            _NextStep(n: '2', text: 'Professionals arrive at your location'),
                            _NextStep(n: '3', text: 'Car washed while you relax at home'),
                            _NextStep(n: '4', text: 'Pay only after you\'re satisfied'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // ── Action buttons ─────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(kWhatsAppUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.chat, size: 18),
                  label: const Text('Open WhatsApp Chat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ref.read(bookingProvider.notifier).reset();
                      context.go('/home');
                      context.push('/booking');
                    },
                    child: const Text('Book Again'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ref.read(bookingProvider.notifier).reset();
                      context.go('/home');
                    },
                    child: const Text('Go Home'),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SummaryRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, color: kGreen400, size: 14),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }
}

class _NextStep extends StatelessWidget {
  final String n;
  final String text;
  const _NextStep({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18, height: 18,
            decoration: const BoxDecoration(
                color: kGreen400, shape: BoxShape.circle),
            child: Center(
              child: Text(n,
                  style: const TextStyle(
                      color: Colors.black,
                      fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: kGray400, fontSize: 12, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
