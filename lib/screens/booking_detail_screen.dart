import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/format.dart';
import '../core/pricing.dart';
import '../core/scheduling.dart' show clockLabel;
import '../core/theme.dart';
import '../data/api/api.dart';
import '../data/api/models.dart';
import '../data/business_info.dart';
import '../models/service.dart';
import '../providers/api_providers.dart';
import '../providers/booking_providers.dart';
import '../widgets/booking_progress.dart';
import '../widgets/contact_actions.dart';
import '../widgets/ui.dart';

/// One booking (v3 design), from the server (refreshed every 30 s and on
/// pull): a status card for its state, any request the customer has made or
/// change the expert found on site, where and which car, the bill or GST
/// invoice, the status history, and the actions that fit the state.
///
/// Cancelling a confirmed booking and changing the time are *requests* to
/// the team (contract §6); the page says so and never shows them as done.
class BookingDetailScreen extends ConsumerWidget {
  final String bookingRef;
  const BookingDetailScreen({super.key, required this.bookingRef});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(apiBookingProvider(bookingRef));
    final b = async.valueOrNull;

    if (b == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: async.isLoading
              ? const CircularProgressIndicator()
              : EmptyState(
                  icon: Icons.event_busy_rounded,
                  title: 'Booking not found',
                  message: async.error is ApiException
                      ? (async.error as ApiException).message
                      : 'Check your connection and try again.',
                  action: PrimaryButton(
                      label: 'My bookings',
                      expand: false,
                      onPressed: () => context.go('/bookings')),
                ),
        ),
      );
    }

    final display = serviceById(b.service.id);
    final s = b.status;
    final upcoming = s.isUpcoming;
    final actions = _actions(context, ref, b, display);

    return AutoRefresh(
        onTick: (ref) => ref.invalidate(apiBookingProvider(bookingRef)),
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark
              .copyWith(statusBarColor: Colors.transparent),
          child: Scaffold(
            backgroundColor: AppColors.bg,
            body: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.15,
              child: SafeArea(
                bottom: false,
                child: RefreshIndicator(
                  onRefresh: () =>
                      ref.refresh(apiBookingProvider(bookingRef).future),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.xxl),
                    children: [
                      _Header(
                        title: display?.listName ?? b.service.name,
                        bookingRef: b.ref,
                      ),
                      const SizedBox(height: AppSpace.lg),
                      _StatusCard(booking: b, display: display),
                      if (b.pendingChange != null) ...[
                        const SizedBox(height: AppSpace.md),
                        _ChangeOnSite(
                          booking: b,
                          onAccept: () => _run(
                              context,
                              ref,
                              b,
                              (api) =>
                                  api.acceptChange(b.ref, b.pendingChange!.id),
                              'New car size accepted. The expert can start.'),
                          onReject: () => _rejectChange(context, ref, b),
                        ),
                      ],
                      if (b.openRequest != null && upcoming) ...[
                        const SizedBox(height: AppSpace.md),
                        NoticeBox(
                          icon: Icons.hourglass_top_rounded,
                          warning: true,
                          text: _requestText(b.openRequest!),
                        ),
                      ],
                      if (b.teamMessage != null &&
                          upcoming &&
                          s != BookingState.rescheduleNeeded) ...[
                        const SizedBox(height: AppSpace.md),
                        NoticeBox(
                          icon: Icons.chat_bubble_outline_rounded,
                          text: 'From the team: ${b.teamMessage}',
                        ),
                      ],
                      if (s == BookingState.rescheduleNeeded &&
                          b.openRequest == null) ...[
                        const SizedBox(height: AppSpace.md),
                        _HoldOptions(
                          booking: b,
                          onAccept: () => _run(
                              context,
                              ref,
                              b,
                              (api) => api.acceptOffer(b.ref),
                              'New time confirmed.'),
                          onKeep: () => _run(
                              context,
                              ref,
                              b,
                              (api) => api.keepAsPlanned(b.ref),
                              'Sent. We\'ll confirm on WhatsApp.'),
                          onPickOther: () => _changeTime(context, ref, b),
                        ),
                      ],
                      if (const [
                        BookingState.confirmed,
                        BookingState.onTheWay,
                        BookingState.inService
                      ].contains(s)) ...[
                        const SizedBox(height: AppSpace.md),
                        const _ExpertRow(),
                      ],
                      if (upcoming) ...[
                        const SizedBox(height: AppSpace.md),
                        const NoticeBox(
                          icon: Icons.water_drop_outlined,
                          text:
                              'Before the slot: keep a water tap and plug point '
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
                                      s == BookingState.completed
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
        ));
  }

  static String _requestText(OpenRequest r) => switch (r.kind) {
        'cancel' => r.fee > 0
            ? 'You asked to cancel. ₹${r.fee} will be added to your next '
                'booking. We\'ll confirm on WhatsApp.'
            : 'You asked to cancel, free of charge. We\'ll confirm on WhatsApp.',
        'changeTime' => r.slot == null
            ? 'You asked for a new time. We\'ll confirm on WhatsApp.'
            : 'You asked to move it to ${friendlyDate(r.slot!.date)}, '
                '${clockLabel(r.slot!.start)}. We\'ll confirm on WhatsApp.',
        'keepAsPlanned' =>
          'You told us the car is in covered parking. We\'ll confirm the wash.',
        _ => 'Your request is with the team.',
      };

  Widget? _actions(
      BuildContext context, WidgetRef ref, Booking b, CarService? display) {
    if (b.status == BookingState.completed &&
        display != null &&
        b.plan == null) {
      final today = ref.watch(catalogProvider).valueOrNull?.service(display.id);
      final price = today?.priceFor(b.car.type) ?? display.priceFor(b.car.type);
      return BottomActionBar(
        child: Row(children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(rupees(price), style: AppText.price),
              Text('today\'s price', style: AppText.caption),
            ],
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: PrimaryButton(
              label: 'Book again',
              onPressed: () =>
                  context.push('/book/${display.id}?car=${b.car.type.name}'),
            ),
          ),
        ]),
      );
    }
    if (b.canCancel || b.canChangeTime) {
      return BottomActionBar(
        child: Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: b.canCancel ? () => _cancel(context, ref, b) : null,
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
              onPressed:
                  b.canChangeTime ? () => _changeTime(context, ref, b) : null,
            ),
          ),
        ]),
      );
    }
    if (b.status == BookingState.onTheWay) {
      return BottomActionBar(
        top: Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.sm),
          child: Text(
              'The expert has left. To cancel now, chat with us; ₹100 is '
              'added to your next booking.',
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

  // ── Calls to the server ────────────────────────────────────────────────────
  /// Runs one customer action and shows the result (or the server's reason).
  static Future<void> _run(BuildContext context, WidgetRef ref, Booking b,
      Future<Booking> Function(CleanCruisersApi api) call, String done) async {
    try {
      await call(ref.read(apiProvider));
      refreshBooking(ref, b.ref);
      if (context.mounted) showMessage(context, done);
    } on ApiException catch (e) {
      refreshBooking(ref, b.ref);
      if (context.mounted) showMessage(context, e.message);
    } on Object {
      if (context.mounted) {
        showMessage(
            context, 'Couldn\'t send. Check your internet and try again.');
      }
    }
  }

  /// Ask for another start time (the server lists what is open).
  static Future<void> _changeTime(
      BuildContext context, WidgetRef ref, Booking b) async {
    final picked = await showModalBottomSheet<SlotPick>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _ChangeTimeSheet(booking: b),
    );
    if (picked == null || !context.mounted) return;
    await _run(context, ref, b, (api) => api.changeTime(b.ref, picked),
        'New time requested. We\'ll confirm on WhatsApp.');
  }

  static Future<void> _cancel(
      BuildContext context, WidgetRef ref, Booking b) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _CancelSheet(booking: b),
    );
    if (result == null || !context.mounted) return;
    if (result == _CancelSheet.changeInstead) {
      return _changeTime(context, ref, b);
    }
    final reason = result.isEmpty ? null : result;
    await _run(
        context,
        ref,
        b,
        (api) => api.cancel(b.ref, reason: reason),
        b.status == BookingState.confirmed
            ? 'Cancellation requested. We\'ll confirm on WhatsApp.'
            : 'Booking cancelled.');
  }

  static Future<void> _rejectChange(
      BuildContext context, WidgetRef ref, Booking b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this wash?'),
        content: const Text(
            'Without the new price the expert can\'t start. The booking is '
            'cancelled with no fee, and you can book again for the right car.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Go back')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancel wash')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _run(
        context,
        ref,
        b,
        (api) => api.rejectChange(b.ref, b.pendingChange!.id),
        'Cancelled. No fee.');
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
  final Booking booking;
  final CarService? display;
  const _StatusCard({required this.booking, required this.display});

  static const _muted = Color(0xFFB8C0C7);

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final arrives = clockLabel(b.slot.start);
    final ready = clockLabel(b.slot.end);
    final (chip, tone) = chipOf(b.status);

    switch (b.status) {
      case BookingState.confirmed:
      case BookingState.onTheWay:
      case BookingState.inService:
        final step = progressIndex(b.status) ?? 1;
        return Container(
          padding: const EdgeInsets.all(AppSpace.lg),
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$chip · ${friendlyDate(b.slot.date)}'.toUpperCase(),
                style: AppText.overline.copyWith(color: AppColors.brand)),
            const SizedBox(height: AppSpace.md),
            Text(
                b.status == BookingState.onTheWay
                    ? 'Your expert is on the way'
                    : b.status == BookingState.inService
                        ? 'Your car is being cleaned'
                        : 'Your expert arrives',
                style: AppText.small.copyWith(color: _muted)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                  b.status == BookingState.inService
                      ? 'Ready ~$ready'
                      : arrives,
                  style: AppText.display.copyWith(color: Colors.white)),
            ),
            if (b.status != BookingState.inService)
              Text('Car ready by about $ready',
                  style: AppText.small.copyWith(color: _muted)),
            const SizedBox(height: AppSpace.lg),
            _DarkProgress(current: step),
          ]),
        );
      case BookingState.requested:
        return _LightCard(
          border: const Color(0xFFF3D9A8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Pill(chip, tone: tone),
            const SizedBox(height: AppSpace.md),
            Text('You asked for ${friendlyDate(b.slot.date)}',
                style: AppText.small),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(arrives, style: AppText.display),
            ),
            const SizedBox(height: 4),
            Text(b.statusNote, style: AppText.small),
            const SizedBox(height: AppSpace.lg),
            BookingProgress(status: b.status),
          ]),
        );
      case BookingState.rescheduleNeeded:
        final rain = b.offer?.reason == 'rain';
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
                child: Icon(
                    rain
                        ? Icons.thunderstorm_outlined
                        : Icons.event_repeat_rounded,
                    color: AppColors.warning),
              ),
              const SizedBox(width: AppSpace.md),
              Flexible(child: Pill(chip, tone: tone)),
            ]),
            const SizedBox(height: AppSpace.md),
            Text('Your slot needs a new time', style: AppText.h3),
            const SizedBox(height: 4),
            Text(
                b.teamMessage ??
                    'Your wash on ${friendlyDate(b.slot.date)}, $arrives is on '
                        'hold. Choose what works for you below.',
                style: AppText.small),
          ]),
        );
      case BookingState.completed:
        final photo = display?.cardPhoto;
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
                            'DONE · ${friendlyDate(b.slot.date)}'.toUpperCase(),
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
      case BookingState.missed:
      case BookingState.cancelled:
      case BookingState.unableToServe:
        return _LightCard(
          border: AppColors.border,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Pill(chip, tone: tone),
            const SizedBox(height: AppSpace.md),
            Text(headlineOf(b), style: AppText.h3),
            const SizedBox(height: 4),
            Text(
                b.teamMessage ??
                    (b.status == BookingState.missed
                        ? 'The expert came on ${shortDate(b.slot.date)} but '
                            "couldn't find you or the car. Book again any time."
                        : '${friendlyDate(b.slot.date)}, $arrives. Nothing to pay.'),
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
                // Gap between labels so they never run together when
                // they shrink on narrow phones.
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
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
              ),
          ]),
        ]),
      ),
    );
  }
}

// ── The team asks for a new time: their offer, covered parking, or another ──
class _HoldOptions extends StatelessWidget {
  final Booking booking;
  final VoidCallback onAccept, onKeep, onPickOther;
  const _HoldOptions(
      {required this.booking,
      required this.onAccept,
      required this.onKeep,
      required this.onPickOther});

  @override
  Widget build(BuildContext context) {
    final o = booking.offer;
    final expired = o != null && !o.expiresAt.isAfter(DateTime.now());

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
      if (o != null && !expired)
        option(
            'Take the new slot',
            '${friendlyDate(o.slot.date)}, expert arrives '
                '${clockLabel(o.slot.start)}',
            onAccept,
            primary: true),
      if (o?.reason == 'rain')
        option(
            'My car is in covered parking', 'Keep the wash as planned', onKeep),
      option('Pick another day or time', 'Choose a time that suits you',
          onPickOther),
    ]);
  }
}

// ── Car size found on site (contract 2.2) ─────────────────────────────────────
/// "a Hatchback", "an SUV", "a luxury car".
String _aCar(CarType c) => switch (c) {
      CarType.suv => 'an SUV',
      CarType.luxury => 'a luxury car',
      _ => 'a ${carTypeNames[c]}',
    };

String _capital(String s) => s[0].toUpperCase() + s.substring(1);

class _ChangeOnSite extends StatelessWidget {
  final Booking booking;
  final VoidCallback onAccept, onReject;
  const _ChangeOnSite(
      {required this.booking, required this.onAccept, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final c = booking.pendingChange!;
    return _LightCard(
      border: AppColors.warning,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('The expert found ${_aCar(c.to)}', style: AppText.h3),
        const SizedBox(height: 4),
        Text(
            'You booked for ${_aCar(c.from)}. '
            '${_capital(_aCar(c.to))} takes longer, so the price changes from '
            '${rupees(booking.bill.total)} to ${rupees(c.newBill.total)}. '
            'The expert starts once you accept.',
            style: AppText.small),
        const SizedBox(height: AppSpace.md),
        PrimaryButton(
            label: 'Accept ${rupees(c.newBill.total)}', onPressed: onAccept),
        TextButton(
          onPressed: onReject,
          style: TextButton.styleFrom(
              foregroundColor: AppColors.error, minimumSize: const Size(0, 44)),
          child: const Text('Don\'t accept, cancel the wash'),
        ),
      ]),
    );
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
  final Booking booking;
  const _Details({required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final bill = b.bill;
    final done = b.status == BookingState.completed;
    final paid = b.payment.status == 'paid';
    final notCharged = const [
      BookingState.cancelled,
      BookingState.missed,
      BookingState.unableToServe,
    ].contains(b.status);
    final method = switch (b.payment.method) {
      'cash' => 'Cash',
      'upi' => 'UPI',
      _ => null,
    };
    final car = b.car.model.trim().isEmpty
        ? carTypeNames[b.car.type]!
        : '${b.car.model.trim()} · ${carTypeNames[b.car.type]}';
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
    String discountLabel(BillDiscount d) => switch (d.kind) {
          'coupon' => 'Coupon ${d.code ?? ''}',
          'credit' => 'CleanCredit',
          'plan' => d.name ?? 'Plan visit',
          _ => d.name ?? 'Offer',
        };

    return AppCard(
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        place(Icons.location_on_outlined, 'Car parked at',
            b.address.line.isEmpty ? b.address.area : b.address.line),
        place(
            Icons.directions_car_outlined,
            car,
            '${friendlyDate(b.slot.date)}, expert arrives '
            '${clockLabel(b.slot.start)}'),
        if (b.plan != null)
          place(Icons.event_repeat_rounded, 'Monthly plan',
              'Visit ${b.plan!.visitNumber} of ${b.plan!.visitsTotal}'),
        if (b.recipient != null)
          place(Icons.person_outline_rounded, 'At the car',
              '${b.recipient!.name}${b.recipient!.phone.isEmpty ? '' : ' · ${phoneLabel(b.recipient!.phone)}'}'),
        const Divider(height: AppSpace.lg),
        Row(children: [
          Expanded(
              child: Text(done ? 'Receipt' : 'Bill', style: AppText.title)),
          if (paid)
            Pill('Paid${method == null ? '' : ' · $method'}',
                icon: Icons.check_rounded, tone: PillTone.brand),
        ]),
        const SizedBox(height: AppSpace.sm),
        for (final i in bill.items)
          line(i.qty > 1 ? '${i.name} × ${i.qty}' : i.name, rupees(i.amount)),
        for (final d in bill.discounts)
          line(discountLabel(d), '-${rupees(d.amount)}', green: true),
        if (bill.lateCancelFee > 0)
          line('Late cancellation fee (earlier booking)',
              rupees(bill.lateCancelFee)),
        const Divider(height: AppSpace.lg),
        Row(children: [
          Expanded(
            child: Text(
                paid
                    ? 'Paid'
                    : notCharged
                        ? 'Not charged'
                        : kPayAfterService
                            ? 'Pay after the service'
                            : 'To pay',
                style: AppText.bodyStrong),
          ),
          Text(notCharged && !paid ? '₹0' : rupees(bill.total),
              style: AppText.priceSm),
        ]),
        if (!notCharged)
          Text(
            'Includes GST ${rupees(bill.gst.cgst + bill.gst.sgst)} '
            '(${bill.gst.rate}%)${!paid && kPayAfterService ? ' · cash or UPI to the expert' : ''}',
            style: AppText.caption),
        if (b.invoice != null) ...[
          const SizedBox(height: AppSpace.md),
          SecondaryButton(
            label: 'GST invoice ${b.invoice!.number}',
            icon: Icons.receipt_long_outlined,
            onPressed: () => openLink(context, b.invoice!.url),
          ),
        ],
      ]),
    );
  }
}

// ── Status history, newest first ─────────────────────────────────────────────
class _Updates extends StatelessWidget {
  final Booking booking;
  const _Updates({required this.booking});

  static String _label(BookingState s) => switch (s) {
        BookingState.requested => 'Requested',
        BookingState.confirmed => 'Confirmed',
        BookingState.onTheWay => 'On the way',
        BookingState.inService => 'Cleaning',
        BookingState.rescheduleNeeded => 'New time needed',
        BookingState.completed => 'Done',
        BookingState.missed => 'Missed',
        BookingState.cancelled => 'Cancelled',
        BookingState.unableToServe => 'Couldn\'t take it',
      };

  @override
  Widget build(BuildContext context) {
    // The server appends in order, so newest first is simply reversed (two
    // updates can share a timestamp).
    final events = booking.history.reversed.toList();
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
                        Text(events[i].note ?? _label(events[i].status),
                            style: AppText.smallStrong.copyWith(
                                color: i == 0
                                    ? AppColors.text
                                    : AppColors.textMuted)),
                        Text(
                            '${friendlyDate(events[i].at)}, '
                            '${clockLabel(events[i].at.hour * 60 + events[i].at.minute)}',
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

// ── Change time: the server's open start times for the next days ──────────────
class _ChangeTimeSheet extends ConsumerStatefulWidget {
  final Booking booking;
  const _ChangeTimeSheet({required this.booking});

  @override
  ConsumerState<_ChangeTimeSheet> createState() => _ChangeTimeSheetState();
}

class _ChangeTimeSheetState extends ConsumerState<_ChangeTimeSheet> {
  final _days = [
    for (var i = 0; i < 7; i++) addDays(dateOnly(DateTime.now()), i),
  ];
  late DateTime _day = _days[1];
  int? _start;

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final extras =
        (b.extras.map((e) => '${e.id}:${e.qty}').toList()..sort()).join(',');
    final avail = ref.watch(availabilityProvider(
        (b.service.id, b.car.type, extras, dateKey(_day))));
    final open = [
      for (final s in avail.valueOrNull?.openSlots ?? const <Slot>[])
        if (!(dateOnly(s.date) == dateOnly(b.slot.date) &&
            s.start == b.slot.start))
          s,
    ];
    final policy = b.cancelPolicy;
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
                  'We\'ll check it and confirm on WhatsApp.'
                  '${policy == null ? '' : ' Free until ${clockLabel(policy.feeAfter.hour * 60 + policy.feeAfter.minute)}, ${friendlyDate(policy.feeAfter)}.'}',
                  style: AppText.small),
              const SizedBox(height: AppSpace.lg),
              SizedBox(
                height: 44,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final d in _days) ...[
                    ChoiceChip(
                      label: Text(friendlyDate(d)),
                      selected: d == _day,
                      showCheckmark: false,
                      selectedColor: AppColors.ink,
                      labelStyle: AppText.smallStrong.copyWith(
                          color: d == _day ? Colors.white : AppColors.text),
                      onSelected: (_) => setState(() {
                        _day = d;
                        _start = null;
                      }),
                    ),
                    const SizedBox(width: AppSpace.sm),
                  ],
                ]),
              ),
              const SizedBox(height: AppSpace.lg),
              if (avail.isLoading && !avail.hasValue)
                const Center(child: CircularProgressIndicator())
              else if (open.isEmpty)
                Text(
                    avail.valueOrNull?.closedReason ??
                        'No times open this day. Try another day.',
                    style: AppText.small)
              else
                Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
                  for (final s in open)
                    ChoiceChip(
                      label: Text(clockLabel(s.start)),
                      selected: s.start == _start,
                      showCheckmark: false,
                      selectedColor: AppColors.primary,
                      labelStyle: AppText.smallStrong.copyWith(
                          color: s.start == _start
                              ? Colors.white
                              : AppColors.text),
                      onSelected: (_) => setState(() => _start = s.start),
                    ),
                ]),
              const SizedBox(height: AppSpace.xl),
              PrimaryButton(
                label: _start == null
                    ? 'Request this time'
                    : 'Request ${clockLabel(_start!)}',
                onPressed: _start == null
                    ? null
                    : () => Navigator.pop(context, SlotPick(_day, _start!)),
              ),
            ]),
      ),
    );
  }
}

// ── Cancel: policy, optional reason, and a nudge to change the time ──────────
class _CancelSheet extends StatefulWidget {
  final Booking booking;
  const _CancelSheet({required this.booking});

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
    final b = widget.booking;
    final policy = b.cancelPolicy;
    final late = policy != null && !DateTime.now().isBefore(policy.feeAfter);
    final text = b.status == BookingState.confirmed
        ? (late
            ? 'Your slot is less than 2 hours away, so ₹${policy.fee} is added '
                'to your next booking. The team confirms the cancellation on '
                'WhatsApp.'
            : 'Free to cancel until 2 hours before your slot. The team '
                'confirms the cancellation on WhatsApp.')
        : 'Nothing is confirmed yet, so this cancels right away, free.';
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
              NoticeBox(
                icon: Icons.info_outline_rounded,
                warning: late,
                text: text,
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
                onPressed: () => Navigator.pop(context, _reason ?? ''),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  minimumSize: const Size(0, 48),
                  textStyle: AppText.bodyStrong,
                ),
                child: Text(b.status == BookingState.confirmed
                    ? 'Yes, request cancellation'
                    : 'Yes, cancel'),
              ),
            ]),
      ),
    );
  }
}
