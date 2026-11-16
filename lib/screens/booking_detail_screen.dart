import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/format.dart';
import '../core/scheduling.dart' show canFinishByClose, clockLabel;
import '../core/theme.dart';
import '../data/business_info.dart';
import '../models/booking.dart';
import '../models/service.dart';
import '../providers/app_providers.dart';
import '../widgets/booking_progress.dart';
import '../widgets/contact_actions.dart';
import '../widgets/ui.dart';
import 'bookings_screen.dart' show statusChip;

/// One booking (v3 design), built only from what the booking really holds:
/// a status card for its state, any change the customer has asked for,
/// the expert (once assigned), where and which car, the bill or receipt,
/// the status history, and the actions that fit the state.
///
/// Cancelling and changing the time are *requests* to the team
/// (requestCustomerChange); the page says so and never shows them as done.
class BookingDetailScreen extends ConsumerWidget {
  final String bookingRef;
  const BookingDetailScreen({super.key, required this.bookingRef});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = ref
        .watch(myBookingsProvider)
        .where((item) => item.ref == bookingRef)
        .firstOrNull;

    if (b == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: EmptyState(
            icon: Icons.event_busy_rounded,
            title: 'Booking not found',
            message: 'It may have been removed from this phone.',
            action: PrimaryButton(
                label: 'My bookings',
                expand: false,
                onPressed: () => context.go('/bookings')),
          ),
        ),
      );
    }

    final service = serviceById(b.serviceId);
    final s = b.status;
    final active = !s.isFinal;
    final canChange = s == BookingStatus.requested ||
        s == BookingStatus.teamReview ||
        s == BookingStatus.confirmed;
    final actions = _actions(context, ref, b, service, canChange);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.15,
          child: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(customerCloudBookingsProvider),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.xxl),
                children: [
                  _Header(
                    title: service?.listName ?? b.serviceName,
                    bookingRef: b.ref,
                  ),
                  const SizedBox(height: AppSpace.lg),
                  _StatusCard(booking: b, service: service),
                  if (b.customerChangeRequest != null && active) ...[
                    const SizedBox(height: AppSpace.md),
                    NoticeBox(
                      icon: Icons.hourglass_top_rounded,
                      warning: true,
                      text: 'You asked: "${b.customerChangeRequest}". '
                          'We\'ll confirm in the app.',
                    ),
                  ],
                  if (s == BookingStatus.rescheduleNeeded) ...[
                    const SizedBox(height: AppSpace.md),
                    _HoldOptions(
                      booking: b,
                      onSend: (text) => _send(context, ref, b, text),
                      onPickOther: () => _changeTime(context, ref, b),
                    ),
                  ],
                  if (b.workerId != null && active) ...[
                    const SizedBox(height: AppSpace.md),
                    const _ExpertRow(),
                  ],
                  if (active) ...[
                    const SizedBox(height: AppSpace.md),
                    const NoticeBox(
                      icon: Icons.water_drop_outlined,
                      text: 'Before the slot: keep a water tap and plug point '
                          'ready near the car. We bring 30 m cords and pipes.',
                    ),
                  ],
                  const SizedBox(height: AppSpace.md),
                  _Details(booking: b),
                  const SizedBox(height: AppSpace.md),
                  _Updates(booking: b),
                  const SizedBox(height: AppSpace.md),
                  AppCard(
                    onTap: () => openWhatsApp(context),
                    padding: const EdgeInsets.all(AppSpace.md),
                    child: Row(children: [
                      const IconBadge(Icons.chat_outlined, size: 40),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  s == BookingStatus.completed
                                      ? 'Something not right?'
                                      : 'Need help?',
                                  style: AppText.title),
                              Text('Chat with us on WhatsApp',
                                  style: AppText.small),
                            ]),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textSubtle),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: actions == null
            ? null
            : MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.15, child: actions),
      ),
    );
  }

  Widget? _actions(BuildContext context, WidgetRef ref, BookingRecord b,
      CarService? service, bool canChange) {
    if (b.status == BookingStatus.completed && service != null) {
      return BottomActionBar(
        child: Row(children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(rupees(service.priceFor(b.car)),
                  style: AppText.price.copyWith(fontSize: 22)),
              Text('today\'s price', style: AppText.caption),
            ],
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: PrimaryButton(
              label: 'Book again',
              onPressed: () =>
                  context.push('/book/${service.id}?car=${b.car.name}'),
            ),
          ),
        ]),
      );
    }
    if (canChange && b.customerChangeRequest == null) {
      return BottomActionBar(
        child: Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _cancel(context, ref, b),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 54),
                foregroundColor: AppColors.text,
                side: const BorderSide(color: AppColors.border, width: 1.5),
                textStyle: AppText.bodyStrong,
              ),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            flex: 2,
            child: SecondaryButton(
              label: 'Change time',
              icon: Icons.edit_calendar_outlined,
              onPressed: () => _changeTime(context, ref, b),
            ),
          ),
        ]),
      );
    }
    if (b.status == BookingStatus.onTheWay) {
      return BottomActionBar(
        top: Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.sm),
          child: Text(
              'The expert has left. Cancelling now adds ₹100 to your next '
              'booking.',
              textAlign: TextAlign.center,
              style: AppText.caption),
        ),
        child: PrimaryButton(
          label: 'Need help? Chat with us',
          icon: Icons.chat_outlined,
          onPressed: () => openWhatsApp(context),
        ),
      );
    }
    return null;
  }

  // ── Requests to the team ───────────────────────────────────────────────────
  static Future<void> _send(BuildContext context, WidgetRef ref,
      BookingRecord booking, String request) async {
    try {
      await ref
          .read(bookingCloudProvider)
          .requestCustomerChange(booking, request);
      ref.invalidate(customerCloudBookingsProvider);
      if (context.mounted) {
        showMessage(context, 'Request sent. We\'ll confirm in the app.');
      }
    } catch (_) {
      if (context.mounted) {
        showMessage(
            context, 'Couldn\'t send. Check your internet and try again.');
      }
    }
  }

  /// Days (from tomorrow) and windows the customer can ask to move to.
  static Future<void> _changeTime(
      BuildContext context, WidgetRef ref, BookingRecord booking) async {
    final today = dateOnly(DateTime.now());
    final minutes = booking.serviceDurationMinutes;
    final days = [
      for (var i = 1; i <= 7; i++) addDays(today, i),
    ]
        .where((d) => timeSlots.any((s) =>
            s.isAvailable(d) && canFinishByClose(s.startMinute, minutes)))
        .take(5)
        .toList();
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _ChangeTimeSheet(days: days, minutes: minutes),
    );
    if (picked != null && context.mounted) {
      await _send(context, ref, booking, picked);
    }
  }

  static Future<void> _cancel(
      BuildContext context, WidgetRef ref, BookingRecord booking) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => const _CancelSheet(),
    );
    if (result == null || !context.mounted) return;
    if (result == _CancelSheet.changeInstead) {
      return _changeTime(context, ref, booking);
    }
    // CleanCredit used on this booking goes back to the wallet, as before.
    final wallet = ref.read(walletProvider);
    final appliedTx = wallet.transactions
        .where((t) => t.referenceId == booking.ref && t.amount < 0)
        .firstOrNull;
    if (appliedTx != null) {
      await ref
          .read(walletProvider.notifier)
          .refundCredit(appliedTx.amount.abs(), booking.ref);
    }
    if (!context.mounted) return;
    await _send(context, ref, booking, result);
  }
}

// ── Header ───────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String title, bookingRef;
  const _Header({required this.title, required this.bookingRef});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Semantics(
        button: true,
        label: 'Back to my bookings',
        child: ExcludeSemantics(
          child: Material(
            color: AppColors.surface,
            shape:
                const CircleBorder(side: BorderSide(color: AppColors.border)),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () =>
                  context.canPop() ? context.pop() : context.go('/bookings'),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(Icons.arrow_back_rounded,
                    size: 20, color: AppColors.text),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: AppSpace.md),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(
            header: true,
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.h2),
          ),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: bookingRef));
              showMessage(context, 'Booking ID copied');
            },
            child: Text('Booking $bookingRef', style: AppText.caption),
          ),
        ]),
      ),
    ]);
  }
}

// ── Status card, one look per state ──────────────────────────────────────────
class _StatusCard extends StatelessWidget {
  final BookingRecord booking;
  final CarService? service;
  const _StatusCard({required this.booking, required this.service});

  static const _muted = Color(0xFFB8C0C7);

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final slot = slotById(b.slotId)?.short ?? b.slotLabel;
    final arrival = b.confirmedArrivalLabel;
    final (chip, tone) = statusChip(b);

    switch (b.status) {
      case BookingStatus.confirmed:
      case BookingStatus.onTheWay:
      case BookingStatus.inService:
        final step = progressIndex(b.status) ?? 1;
        return Container(
          padding: const EdgeInsets.all(AppSpace.lg),
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$chip · ${friendlyDate(b.date)}'.toUpperCase(),
                style: AppText.overline.copyWith(color: AppColors.brand)),
            const SizedBox(height: AppSpace.md),
            Text(
                b.status == BookingStatus.onTheWay
                    ? 'Your expert is on the way'
                    : b.status == BookingStatus.inService
                        ? 'Your car is being cleaned'
                        : 'Your expert arrives',
                style: AppText.small.copyWith(color: _muted)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(slot,
                  style: AppText.display.copyWith(color: Colors.white)),
            ),
            if (arrival != null)
              Text('Likely around $arrival',
                  style: AppText.small.copyWith(color: _muted)),
            const SizedBox(height: AppSpace.lg),
            _DarkProgress(current: step),
          ]),
        );
      case BookingStatus.requested:
      case BookingStatus.teamReview:
        return _LightCard(
          border: const Color(0xFFF3D9A8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Pill(chip, tone: tone),
            const SizedBox(height: AppSpace.md),
            Text('You asked for ${friendlyDate(b.date)}', style: AppText.small),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(slot, style: AppText.display),
            ),
            const SizedBox(height: 4),
            Text(
                b.customerNote ??
                    'We usually confirm within $kConfirmUsually. '
                        'You\'ll see it here.',
                style: AppText.small),
            const SizedBox(height: AppSpace.lg),
            BookingProgress(status: b.status),
          ]),
        );
      case BookingStatus.rescheduleNeeded:
        return _LightCard(
          border: const Color(0xFFF3D9A8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.thunderstorm_outlined,
                    color: AppColors.warning),
              ),
              const SizedBox(width: AppSpace.md),
              Flexible(child: Pill(chip, tone: tone)),
            ]),
            const SizedBox(height: AppSpace.md),
            Text('Your slot needs a new time', style: AppText.h3),
            const SizedBox(height: 4),
            Text(
                b.customerNote ??
                    'Your wash on ${friendlyDate(b.date)}, $slot is on hold. '
                        'Choose what works for you below.',
                style: AppText.small),
          ]),
        );
      case BookingStatus.completed:
        final photo = service?.cardPhoto;
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: SizedBox(
            height: 170,
            child: Stack(fit: StackFit.expand, children: [
              if (photo != null)
                Image.asset(photo,
                    fit: BoxFit.cover,
                    cacheWidth: 800,
                    excludeFromSemantics: true)
              else
                const ColoredBox(color: AppColors.forest),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.3, 1],
                    colors: [Color(0x000B0F10), Color(0xD90B0F10)],
                  ),
                ),
              ),
              Positioned(
                left: AppSpace.lg,
                right: AppSpace.lg,
                bottom: AppSpace.lg,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.brand,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                            'DONE · ${friendlyDate(b.date)}'.toUpperCase(),
                            style: AppText.overline
                                .copyWith(color: AppColors.ink)),
                      ),
                      const SizedBox(height: AppSpace.sm),
                      Text('All clean. Hope you love it.',
                          style: AppText.h3.copyWith(color: Colors.white)),
                    ]),
              ),
            ]),
          ),
        );
      case BookingStatus.cancelled:
      case BookingStatus.unableToServe:
        return _LightCard(
          border: AppColors.border,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Pill(chip, tone: tone),
            const SizedBox(height: AppSpace.md),
            Text(
                b.status == BookingStatus.cancelled
                    ? 'Booking cancelled'
                    : 'We couldn\'t take this booking',
                style: AppText.h3),
            const SizedBox(height: 4),
            Text(
                b.customerNote ??
                    '${friendlyDate(b.date)}, $slot. Nothing to pay.',
                style: AppText.small),
          ]),
        );
    }
  }
}

class _LightCard extends StatelessWidget {
  final Color border;
  final Widget child;
  const _LightCard({required this.border, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: border, width: 1.5),
        ),
        child: child,
      );
}

/// Five steps with labels, for the dark status card.
class _DarkProgress extends StatelessWidget {
  final int current;
  const _DarkProgress({required this.current});

  static const _labels = [
    'Requested',
    'Confirmed',
    'On the way',
    'Cleaning',
    'Done'
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step ${current + 1} of 5, ${_labels[current]}',
      child: ExcludeSemantics(
        child: Column(children: [
          Row(children: [
            for (var i = 0; i < 5; i++) ...[
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 3,
                    color: i <= current
                        ? AppColors.brand
                        : const Color(0xFF2A3336),
                  ),
                ),
              Container(
                width: i == current ? 16 : 11,
                height: i == current ? 16 : 11,
                decoration: BoxDecoration(
                  color: i <= current ? AppColors.brand : null,
                  shape: BoxShape.circle,
                  border: i <= current
                      ? null
                      : Border.all(color: const Color(0xFF3A4448), width: 2),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 8),
          Row(children: [
            for (var i = 0; i < 5; i++)
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: i == 0
                      ? Alignment.centerLeft
                      : i == 4
                          ? Alignment.centerRight
                          : Alignment.center,
                  child: Text(_labels[i],
                      style: AppText.caption.copyWith(
                          color: i == current
                              ? Colors.white
                              : const Color(0xFF8A949B),
                          fontWeight: i == current
                              ? FontWeight.w800
                              : FontWeight.w600)),
                ),
              ),
          ]),
        ]),
      ),
    );
  }
}

// ── Rain hold: the team's offer, covered parking, or another time ────────────
class _HoldOptions extends StatelessWidget {
  final BookingRecord booking;
  final ValueChanged<String> onSend;
  final VoidCallback onPickOther;
  const _HoldOptions(
      {required this.booking, required this.onSend, required this.onPickOther});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final offeredSlot = slotById(b.offeredSlotId);
    final offer = b.offeredDate != null && offeredSlot != null
        ? '${friendlyDate(b.offeredDate!)}, ${offeredSlot.short}'
        : null;

    Widget option(String title, String line, VoidCallback onTap,
            {bool primary = false}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.sm),
          child: AppCard(
            onTap: onTap,
            radius: AppRadius.lg,
            selected: primary,
            color: AppColors.surface,
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppText.title),
                      Text(line, style: AppText.small),
                    ]),
              ),
              if (primary)
                const Pill('Held for you', tone: PillTone.solid)
              else
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSubtle),
            ]),
          ),
        );

    return Column(children: [
      if (offer != null)
        option('Take the new slot', offer,
            () => onSend('Accept the offered slot: $offer'),
            primary: true),
      option('My car is in covered parking', 'Keep the wash as planned',
          () => onSend('Covered parking: keep the wash as planned')),
      option('Pick another day or time', 'Choose a time that suits you',
          onPickOther),
    ]);
  }
}

class _ExpertRow extends StatelessWidget {
  const _ExpertRow();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration:
              const BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
          child:
              const Icon(Icons.person_outline_rounded, color: AppColors.brand),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Expert assigned', style: AppText.title),
            Text('A CleanCruisers expert is booked for your slot',
                style: AppText.small),
          ]),
        ),
      ]),
    );
  }
}

// ── Where, which car, and the bill or receipt ────────────────────────────────
class _Details extends StatelessWidget {
  final BookingRecord booking;
  const _Details({required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final done = b.status == BookingStatus.completed;
    final paid = b.amountCollected ?? b.payable;
    final method = switch (b.paymentMethod) {
      PaymentMethod.cash => 'Cash',
      PaymentMethod.upi => 'UPI',
      null => null,
    };
    Widget line(String label, String value, {bool green = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Text(label,
                    style: AppText.small.copyWith(color: AppColors.text))),
            const SizedBox(width: AppSpace.md),
            Text(value,
                style: AppText.smallStrong.copyWith(
                    color: green ? AppColors.primaryDk : AppColors.text)),
          ]),
        );
    Widget place(IconData icon, String title, String text) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.md),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18, color: AppColors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.smallStrong),
                    Text(text, style: AppText.small),
                  ]),
            ),
          ]),
        );

    return AppCard(
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        place(Icons.location_on_outlined, 'Car parked at', b.address),
        place(Icons.directions_car_outlined, b.carLabel,
            '${friendlyDate(b.date)}, ${slotById(b.slotId)?.short ?? b.slotLabel}'),
        if (b.forSomeoneElse && b.recipientName != null)
          place(Icons.person_outline_rounded, 'At the car',
              '${b.recipientName}${b.recipientPhone == null ? '' : ' · ${phoneLabel(b.recipientPhone!)}'}'),
        const Divider(height: AppSpace.lg),
        Row(children: [
          Expanded(
              child: Text(done ? 'Receipt' : 'Bill', style: AppText.title)),
          if (done && method != null)
            Pill('Paid · $method',
                icon: Icons.check_rounded, tone: PillTone.brand),
        ]),
        const SizedBox(height: AppSpace.sm),
        line(serviceById(b.serviceId)?.listName ?? b.serviceName,
            rupees(b.servicePrice)),
        for (final (name, qty, price) in b.extras)
          line(qty > 1 ? '$name × $qty' : name, rupees(price)),
        if (b.couponDiscount > 0)
          line('Coupon ${b.couponCode ?? ''}', '-${rupees(b.couponDiscount)}',
              green: true),
        if (b.creditUsed > 0)
          line('CleanCredit', '-${rupees(b.creditUsed)}', green: true),
        const Divider(height: AppSpace.lg),
        Row(children: [
          Expanded(
            child: Text(
                done
                    ? 'Paid'
                    : kPayAfterService
                        ? 'Pay after the service'
                        : 'To pay',
                style: AppText.bodyStrong),
          ),
          Text(rupees(done ? paid : b.payable), style: AppText.priceSm),
        ]),
        if (!done && kPayAfterService)
          Text('Cash or UPI to the expert', style: AppText.caption),
      ]),
    );
  }
}

// ── Status history, newest first ─────────────────────────────────────────────
class _Updates extends StatelessWidget {
  final BookingRecord booking;
  const _Updates({required this.booking});

  @override
  Widget build(BuildContext context) {
    final events = [...booking.history]..sort((a, b) => b.at.compareTo(a.at));
    if (events.isEmpty) return const SizedBox.shrink();
    return AppCard(
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Updates', style: AppText.title),
        const SizedBox(height: AppSpace.md),
        for (var i = 0; i < events.length; i++)
          IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Column(children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    color: i == 0 ? AppColors.primary : const Color(0xFFC9CED3),
                    shape: BoxShape.circle,
                  ),
                ),
                if (i < events.length - 1)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.border,
                    ),
                  ),
              ]),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      bottom: i < events.length - 1 ? AppSpace.md : 0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(events[i].status.label,
                            style: AppText.smallStrong.copyWith(
                                color: i == 0
                                    ? AppColors.text
                                    : AppColors.textMuted)),
                        Text(
                            '${friendlyDate(events[i].at)}, '
                            '${clockLabel(events[i].at.hour * 60 + events[i].at.minute)}'
                            '${events[i].note == null ? '' : ' · ${events[i].note}'}',
                            style: AppText.caption),
                      ]),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}

// ── Change time: a request with the day and window chosen ────────────────────
class _ChangeTimeSheet extends StatefulWidget {
  final List<DateTime> days;
  final int minutes;
  const _ChangeTimeSheet({required this.days, required this.minutes});

  @override
  State<_ChangeTimeSheet> createState() => _ChangeTimeSheetState();
}

class _ChangeTimeSheetState extends State<_ChangeTimeSheet> {
  late DateTime? _day = widget.days.firstOrNull;
  TimeSlot? _slot;

  @override
  Widget build(BuildContext context) {
    final day = _day;
    final slots = day == null
        ? const <TimeSlot>[]
        : timeSlots
            .where((s) =>
                s.isAvailable(day) &&
                canFinishByClose(s.startMinute, widget.minutes))
            .toList();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.page, 0, AppSpace.page, AppSpace.lg),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Change the time', style: AppText.h2),
              const SizedBox(height: 4),
              Text(
                  'We\'ll check it and confirm in the app. Free until 4 hours '
                  'before your slot.',
                  style: AppText.small),
              const SizedBox(height: AppSpace.lg),
              Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
                for (final d in widget.days)
                  ChoiceChip(
                    label: Text(friendlyDate(d)),
                    selected: d == _day,
                    showCheckmark: false,
                    selectedColor: AppColors.ink,
                    labelStyle: AppText.smallStrong.copyWith(
                        color: d == _day ? Colors.white : AppColors.text),
                    onSelected: (_) => setState(() {
                      _day = d;
                      _slot = null;
                    }),
                  ),
              ]),
              const SizedBox(height: AppSpace.lg),
              Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
                for (final s in slots)
                  ChoiceChip(
                    label: Text(s.short),
                    selected: s.id == _slot?.id,
                    showCheckmark: false,
                    selectedColor: AppColors.primary,
                    labelStyle: AppText.smallStrong.copyWith(
                        color:
                            s.id == _slot?.id ? Colors.white : AppColors.text),
                    onSelected: (_) => setState(() => _slot = s),
                  ),
              ]),
              const SizedBox(height: AppSpace.xl),
              PrimaryButton(
                label: 'Request this time',
                onPressed: day == null || _slot == null
                    ? null
                    : () => Navigator.pop(context,
                        'Change time to ${friendlyDate(day)}, ${_slot!.short}'),
              ),
            ]),
      ),
    );
  }
}

// ── Cancel: policy, optional reason, and a nudge to change the time ──────────
class _CancelSheet extends StatefulWidget {
  const _CancelSheet();

  /// Returned when the customer would rather move the booking.
  static const changeInstead = '__change__';

  @override
  State<_CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends State<_CancelSheet> {
  static const _reasons = [
    'Plans changed',
    'Car not available',
    'Booked by mistake',
    'Other',
  ];
  String? _reason;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.page, 0, AppSpace.page, AppSpace.lg),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Cancel this booking?', style: AppText.h2),
              const SizedBox(height: AppSpace.md),
              const NoticeBox(
                icon: Icons.info_outline_rounded,
                text: 'Free to cancel until 4 hours before your slot. '
                    'Cancelling within 2 hours of your slot, or after the '
                    'expert has left, adds ₹100 to your next booking.',
              ),
              const SizedBox(height: AppSpace.lg),
              Text('Why are you cancelling? (optional)',
                  style: AppText.smallStrong),
              const SizedBox(height: AppSpace.sm),
              Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
                for (final r in _reasons)
                  ChoiceChip(
                    label: Text(r),
                    selected: r == _reason,
                    showCheckmark: false,
                    selectedColor: AppColors.ink,
                    labelStyle: AppText.smallStrong.copyWith(
                        color: r == _reason ? Colors.white : AppColors.text),
                    onSelected: (_) => setState(() => _reason = r),
                  ),
              ]),
              const SizedBox(height: AppSpace.xl),
              PrimaryButton(
                label: 'Change the time instead',
                onPressed: () =>
                    Navigator.pop(context, _CancelSheet.changeInstead),
              ),
              const SizedBox(height: AppSpace.sm),
              TextButton(
                onPressed: () => Navigator.pop(
                    context,
                    _reason == null
                        ? 'Cancel this booking'
                        : 'Cancel this booking: $_reason'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  minimumSize: const Size(0, 48),
                  textStyle: AppText.bodyStrong,
                ),
                child: const Text('Yes, request cancellation'),
              ),
            ]),
      ),
    );
  }
}
