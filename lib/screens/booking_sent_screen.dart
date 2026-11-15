import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/booking.dart';
import '../providers/app_providers.dart';
import '../widgets/booking_progress.dart';
import '../widgets/ui.dart';

/// Shown right after a booking request is sent. It is a *request*: the team
/// still confirms the slot, so this screen says exactly that and shows the
/// tracker, instead of claiming the slot is already locked.
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
    final b = ref
            .watch(myBookingsProvider)
            .where((x) => x.ref == widget.bookingRef)
            .firstOrNull ??
        ref.watch(bookingsProvider.notifier).byRef(widget.bookingRef);
    final confirmed = b != null &&
        (progressIndex(b.status) ?? 0) >= 1 &&
        b.status != BookingStatus.rescheduleNeeded;

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
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.page, 40, AppSpace.page, AppSpace.xxl),
            children: [
              Center(
                child: ScaleTransition(
                  scale: scale,
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                        color: AppColors.primarySoft, shape: BoxShape.circle),
                    child: Icon(
                        confirmed
                            ? Icons.check_circle_rounded
                            : Icons.schedule_send_rounded,
                        size: 46,
                        color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.xl),
              FadeTransition(
                opacity: fade,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(confirmed ? 'Slot confirmed!' : 'Request sent!',
                          textAlign: TextAlign.center, style: AppText.h1),
                      const SizedBox(height: AppSpace.sm),
                      Text(
                          confirmed
                              ? 'See you then.'
                              : 'We\'ll confirm your slot in the app.\n'
                                  'Watch it here or under Bookings.',
                          textAlign: TextAlign.center,
                          style: AppText.body),
                      if (b != null) ...[
                        const SizedBox(height: AppSpace.xxl),
                        AppCard(child: BookingProgress(status: b.status)),
                        const SizedBox(height: AppSpace.md),
                        _Summary(booking: b),
                      ],
                      const SizedBox(height: AppSpace.xxl),
                      PrimaryButton(
                        label: 'Track booking',
                        icon: Icons.event_note_rounded,
                        onPressed: () => context
                            .go(b == null ? '/bookings' : '/bookings/${b.ref}'),
                      ),
                      const SizedBox(height: AppSpace.sm),
                      TextButton(
                        onPressed: () => context.go('/home'),
                        child: const Text('Back to Home'),
                      ),
                    ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What was requested, one icon per line.
class _Summary extends StatelessWidget {
  final BookingRecord booking;
  const _Summary({required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final extras = [
      for (final (name, qty, _) in b.extras) qty > 1 ? '$name × $qty' : name,
    ];
    final rows = [
      (Icons.local_car_wash_rounded, [b.serviceName, ...extras].join(' + ')),
      (Icons.directions_car_rounded, b.carLabel),
      (
        Icons.schedule_rounded,
        '${friendlyDate(b.date)} · ${slotById(b.slotId)?.short ?? b.slotLabel}'
      ),
      (Icons.location_on_rounded, b.address),
      (
        Icons.payments_rounded,
        '${rupees(b.payable)} · pay after the wash'
            '${b.couponCode == null ? '' : ' (${b.couponCode} applied)'}'
      ),
    ];
    return AppCard(
      child: Column(children: [
        for (final (icon, text) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Text(text,
                    style: AppText.small.copyWith(color: AppColors.text)),
              ),
            ]),
          ),
        const Divider(height: AppSpace.lg),
        Row(children: [
          Text('Booking ID', style: AppText.caption),
          const Spacer(),
          SelectableText(b.ref, style: AppText.smallStrong),
        ]),
      ]),
    );
  }
}
