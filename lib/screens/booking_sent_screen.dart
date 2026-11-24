import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/format.dart';
import '../core/pricing.dart';
import '../core/scheduling.dart' show clockLabel;
import '../core/theme.dart';
import '../data/api/models.dart';
import '../data/business_info.dart';
import '../providers/booking_providers.dart';
import '../widgets/booking_progress.dart';
import '../widgets/ui.dart';

/// Shown right after a booking request is sent (v3 design). It is a
/// *request*: the team still confirms the slot, so this screen says exactly
/// that, with when to expect it (from the server, which knows working hours)
/// and that the confirmation comes on WhatsApp.
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
    final b = ref.watch(apiBookingProvider(widget.bookingRef)).valueOrNull;
    final confirmed = b != null &&
        const [BookingState.confirmed, BookingState.onTheWay, BookingState.inService]
            .contains(b.status);

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
        backgroundColor: AppColors.bg,
        body: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.15,
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.page, 48, AppSpace.page, AppSpace.xxl),
              children: [
                Center(
                  child: ScaleTransition(
                    scale: scale,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: const BoxDecoration(
                          color: AppColors.primarySoft, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: const BoxDecoration(
                            color: AppColors.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.check_rounded,
                            size: 38, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.xl),
                FadeTransition(
                  opacity: fade,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                              confirmed ? 'Slot confirmed' : 'Slot requested',
                              textAlign: TextAlign.center,
                              style: AppText.h1),
                        ),
                        const SizedBox(height: AppSpace.sm),
                        Text(
                            confirmed
                                ? 'See you then.'
                                : b?.statusNote ??
                                    'We\'ll confirm it on WhatsApp,\n'
                                        'usually within $kConfirmUsually.',
                            textAlign: TextAlign.center,
                            style: AppText.body),
                        if (b != null) ...[
                          const SizedBox(height: AppSpace.xxl),
                          _StatusCard(booking: b, confirmed: confirmed),
                          const SizedBox(height: AppSpace.md),
                          Container(
                            padding: const EdgeInsets.all(AppSpace.lg),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Text.rich(
                              const TextSpan(children: [
                                TextSpan(
                                    text: 'What happens next: ',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w800)),
                                TextSpan(
                                    text: 'you get a WhatsApp message when the '
                                        'team confirms, and the status changes '
                                        'here and under My Bookings. Keep a '
                                        'water tap and plug point ready for '
                                        'the visit.'),
                              ]),
                              style: AppText.small.copyWith(
                                  color: AppColors.primaryDk, height: 1.45),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpace.xxl),
                        PrimaryButton(
                          label: 'View booking',
                          onPressed: () => context.go(
                              b == null ? '/bookings' : '/bookings/${b.ref}'),
                        ),
                        const SizedBox(height: AppSpace.sm),
                        TextButton(
                          onPressed: () => context.go('/home'),
                          style: TextButton.styleFrom(
                              minimumSize: const Size(0, 48)),
                          child: const Text('Back to home'),
                        ),
                      ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What was requested: status, when, what, and the booking reference
/// (tap to copy).
class _StatusCard extends StatelessWidget {
  final Booking booking;
  final bool confirmed;
  const _StatusCard({required this.booking, required this.confirmed});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final extras = b.extras.length;
    final what = [
      b.service.name,
      if (extras > 0) '$extras ${extras == 1 ? 'extra' : 'extras'}',
    ].join(' + ');
    final car = b.car.model.trim().isEmpty ? carTypeNames[b.car.type]! : b.car.model;
    return AppCard(
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Pill(confirmed ? 'Confirmed' : 'Waiting for confirmation',
                  tone: confirmed ? PillTone.brand : PillTone.warning),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Semantics(
            button: true,
            label: 'Booking ${b.ref}. Copy',
            child: ExcludeSemantics(
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: b.ref));
                  showMessage(context, 'Booking ID copied');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.xs, vertical: 12),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(b.ref, style: AppText.caption),
                    const SizedBox(width: 4),
                    const Icon(Icons.copy_rounded,
                        size: 14, color: AppColors.textSubtle),
                  ]),
                ),
              ),
            ),
          ),
        ]),
        const SizedBox(height: AppSpace.sm),
        Text(
            '${friendlyDate(b.slot.date)}, expert arrives '
            '${clockLabel(b.slot.start)}',
            style: AppText.h3),
        const SizedBox(height: 2),
        Text('$what · $car', style: AppText.small),
        const SizedBox(height: AppSpace.lg),
        BookingProgress(status: b.status),
        const Divider(height: AppSpace.xl),
        Row(children: [
          Expanded(
            child: Text(
                kPayAfterService ? 'Pay after the service' : 'To pay',
                style: AppText.small),
          ),
          Text(rupees(b.bill.total), style: AppText.bodyStrong),
        ]),
      ]),
    );
  }
}
