import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/business_info.dart';
import '../providers/app_providers.dart';
import '../widgets/contact_actions.dart';
import '../widgets/motion.dart';
import '../widgets/ui.dart';

class BookingSentScreen extends ConsumerStatefulWidget {
  final String bookingRef;
  const BookingSentScreen({super.key, required this.bookingRef});

  @override
  ConsumerState<BookingSentScreen> createState() => _BookingSentScreenState();
}

class _BookingSentScreenState extends ConsumerState<BookingSentScreen>
    with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700))
    ..forward();

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = ref.watch(bookingsProvider.notifier).byRef(widget.bookingRef);
    final scale = CurvedAnimation(
        parent: _anim,
        curve: const Interval(0, 0.7, curve: Curves.easeOutBack));
    final fade = CurvedAnimation(
        parent: _anim, curve: const Interval(0.3, 1, curve: Curves.easeOut));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/home');
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Stack(children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.page, 40, AppSpace.page, 24),
              children: [
                Center(
                  child: ScaleTransition(
                    scale: scale,
                    child: Container(
                      width: 92,
                      height: 92,
                      decoration: const BoxDecoration(
                          color: AppColors.primarySoft, shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded,
                          size: 54, color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                FadeTransition(
                  opacity: fade,
                  child: Column(children: [
                    Text('Booking request sent',
                        style: AppText.h1, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(
                      'We\'ll confirm your slot on WhatsApp, usually within $kConfirmWithin.',
                      style: AppText.body,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (b != null)
                      AppCard(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Text('BOOKING REF', style: AppText.overline),
                                const Spacer(),
                                Pill(b.ref, tone: PillTone.brand),
                              ]),
                              const SizedBox(height: 10),
                              const Divider(),
                              InfoRow(
                                  icon: Icons.local_car_wash_outlined,
                                  label: 'Service',
                                  value: b.serviceName),
                              InfoRow(
                                  icon: Icons.calendar_today_outlined,
                                  label: 'When',
                                  value:
                                      '${friendlyDate(b.date)}\n${b.slotLabel}'),
                              InfoRow(
                                  icon: Icons.payments_outlined,
                                  label: kPayAfterService
                                      ? 'Pay after service'
                                      : 'Estimated total',
                                  value: rupees(b.total)),
                            ]),
                      ),
                    const SizedBox(height: 16),
                    const NoticeBox(
                      icon: Icons.info_outline_rounded,
                      warning: true,
                      text:
                          'Didn\'t press Send in WhatsApp? Your booking only reaches us once the message is sent.',
                    ),
                    if (b != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => openWhatsApp(context,
                              message: b.whatsAppMessage()),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Open WhatsApp again'),
                        ),
                      ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: 'View my bookings',
                      onPressed: () => context.go('/bookings'),
                    ),
                    const SizedBox(height: 10),
                    SecondaryButton(
                        label: 'Back to home',
                        onPressed: () => context.go('/home')),
                  ]),
                ),
              ],
            ),
            // Brief celebration, centred on the check mark.
            const Positioned(
                top: 0, left: 0, right: 0, height: 172, child: ConfettiBurst()),
          ]),
        ),
      ),
    );
  }
}
