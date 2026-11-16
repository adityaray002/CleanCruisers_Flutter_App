import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/format.dart';
import '../../core/pricing.dart';
import '../../core/scheduling.dart';
import '../../core/theme.dart';
import '../../data/booking_cloud.dart';
import '../../data/business_info.dart';
import '../../data/offers.dart';
import '../../models/booking.dart';
import '../../models/service.dart';
import '../../providers/app_providers.dart';
import '../../widgets/customer_sheets.dart';
import '../../widgets/ui.dart';
import 'booking_steps.dart';

/// The booking, in three short steps (v3 design):
/// 1. Extras (skipped for packages that have none),
/// 2. Pick a time,
/// 3. Review and "Request slot".
/// Car and address come from the customer's profile; Review has a "Change"
/// for each. The draft, coupon rules and sending are the same as before the
/// redesign; only the layout is split into steps.
///
/// The button says "Request slot" because the team still confirms the slot;
/// the page and the next screen say so in plain words.
class BookingFlowScreen extends ConsumerStatefulWidget {
  final String serviceId;
  final CarType? initialCar;
  const BookingFlowScreen(
      {super.key, required this.serviceId, this.initialCar});

  @override
  ConsumerState<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

enum _Stage { extras, time, review }

class _BookingFlowScreenState extends ConsumerState<BookingFlowScreen> {
  bool _showErrors = false;
  bool _sending = false;
  String? _sendError;
  int _index = 0;

  CarService? get _service => serviceById(widget.serviceId);
  DraftNotifier get _notifier =>
      ref.read(draftProvider(widget.serviceId).notifier);
  List<ServiceArea> get _areas =>
      ref.read(serviceAreasProvider).valueOrNull ?? const [];

  List<_Stage> get _stages => [
        if ((_service?.extras ?? const []).isNotEmpty) _Stage.extras,
        _Stage.time,
        _Stage.review,
      ];
  _Stage get _stage => _stages[_index];

  @override
  void initState() {
    super.initState();
    if (_service == null) return;
    // Providers can't change while the tree is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.initialCar != null) _notifier.setCar(widget.initialCar!);
      _applyPickedOffer();
    });
    ref.listenManual(serviceAreasProvider, (_, next) {
      final areas = next.valueOrNull;
      if (areas != null) _notifier.updateCoverage(areas);
    }, fireImmediately: true);
    // Car or address changed from a sheet: use it for this booking too.
    ref.listenManual(
        profileProvider, (_, p) => _notifier.applyProfile(p, _areas));
  }

  void _goTo(_Stage s) => setState(() => _index = _stages.indexOf(s));

  void _back() {
    if (_index > 0) {
      setState(() => _index--);
    } else {
      context.canPop() ? context.pop() : context.go('/home');
    }
  }

  /// A coupon the customer tapped "Use" on in CleanCredit is applied here,
  /// if this booking qualifies. Otherwise "Add coupon" says why not.
  void _applyPickedOffer() {
    final code = ref.read(pickedOfferProvider);
    final offer = code == null ? null : offerByCode(code);
    final d = ref.read(draftProvider(widget.serviceId));
    if (offer == null || d.couponCode != null) return;
    final first = ref.read(myBookingsProvider).isEmpty;
    if (couponBlocker(offer, d, firstBooking: first) != null) return;
    _notifier.applyCoupon(offer.code, couponDiscountFor(offer, d));
    showMessage(context, '${offer.code} applied');
  }

  /// Keeps an applied coupon honest when the bill or car changes: the
  /// discount follows the new total, or the coupon comes off with a reason.
  void _syncCoupon(BookingDraft d) {
    final code = d.couponCode;
    if (code == null) return;
    final offer = offerByCode(code);
    final why = offer == null
        ? 'no longer available'
        : couponBlocker(offer, d,
            firstBooking: ref.read(myBookingsProvider).isEmpty);
    final want = why == null ? couponDiscountFor(offer!, d) : 0;
    if (why == null && want == d.couponDiscount) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (why != null) {
        _notifier.removeCoupon();
        showMessage(context, '$code removed: $why');
      } else {
        _notifier.applyCoupon(code, want);
      }
    });
  }

  /// What still stops the booking, in the order the customer fixes it.
  String? _blocker(BookingDraft d) {
    if (d.car == null) return 'Add your car';
    if (d.address.trim().isEmpty) return 'Add your address';
    if (d.coverage == Coverage.notCovered) {
      return 'We don\'t serve this address yet';
    }
    if (!d.nameValid || !d.phoneValid) return 'Please log in again to book';
    if (d.date == null) return 'Pick a day';
    if (!d.scheduleDone) return 'Pick a time';
    return null;
  }

  void _continueFromTime(BookingDraft d) {
    if (d.date == null || !d.scheduleDone) {
      setState(() => _showErrors = true);
      showMessage(context, d.date == null ? 'Pick a day' : 'Pick a time');
      return;
    }
    _goTo(_Stage.review);
  }

  Future<void> _onBook(BookingDraft d) async {
    if (d.car == null) return showCarSheet(context, ref);
    if (d.address.trim().isEmpty) return showAddressSheet(context, ref);
    final blocker = _blocker(d);
    if (blocker == 'Pick a day' || blocker == 'Pick a time') {
      setState(() => _showErrors = true);
      _goTo(_Stage.time);
      return;
    }
    if (blocker != null) {
      showMessage(context, blocker);
      return;
    }
    await _send(d);
  }

  Future<void> _send(BookingDraft d) async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _sendError = null;
    });
    final record = BookingRecord.fromDraft(d,
        walletBalance: ref.read(walletProvider).balance);
    try {
      await ref.read(bookingCloudProvider).submit(record);
      if (!mounted) return;
      ref.invalidate(customerCloudBookingsProvider);
      try {
        await ref.read(bookingsProvider.notifier).add(record);
        // Credit is spent now; cancelling refunds it (booking detail).
        await ref
            .read(walletProvider.notifier)
            .applyCredit(record.creditUsed, record.ref);
        if (record.couponCode != null &&
            record.couponCode == ref.read(pickedOfferProvider)) {
          await ref.read(pickedOfferProvider.notifier).pick(null);
        }
      } on Object {
        // The central booking is already safely recorded. Local convenience
        // caching must never turn a submitted request into an error message.
      }
      if (mounted) context.pushReplacement('/booking-sent/${record.ref}');
    } on BookingCloudException catch (error) {
      if (!mounted) return;
      if (error.slotTaken) {
        setState(() => _sending = false);
        await _offerOtherSlots(d);
        return;
      }
      setState(() => _sendError = error.message);
    } on Object {
      // Nothing is shown as sent: the draft stays here so the customer can
      // retry, and the retry reuses the same reference (no duplicates).
      if (mounted) setState(() => _sendError = 'Please try again in a moment.');
    }
    if (mounted) setState(() => _sending = false);
  }

  /// The chosen window filled up while the customer was deciding. Offer the
  /// windows still open that day, or a way back to the day picker.
  Future<void> _offerOtherSlots(BookingDraft d) async {
    final date = d.date!;
    final capacity = ref.read(capacityProvider(dateKey(date))).valueOrNull ??
        CapacityDay.open;
    final open = [
      for (final s in timeSlots)
        if (s.id != d.slotId &&
            customerWindowState(
                  windowStart: s.startMinute,
                  windowId: s.id,
                  date: date,
                  serviceMinutes: d.serviceDurationMinutes,
                  capacity: capacity,
                ) ==
                WindowState.preference)
          s,
    ];
    final taken = slotById(d.slotId)?.short ?? 'That time';
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _SlotTakenSheet(
        takenLabel: taken,
        day: friendlyDate(date),
        open: open,
      ),
    );
    if (!mounted) return;
    if (picked == null) {
      _goTo(_Stage.time);
      return;
    }
    _notifier.setSlot(picked);
    await _send(ref.read(draftProvider(widget.serviceId)));
  }

  @override
  Widget build(BuildContext context) {
    final service = _service;
    if (service == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: EmptyState(
            icon: Icons.search_off_rounded,
            title: 'Service not found',
            message: 'Please choose a service to book.',
            action: PrimaryButton(
                label: 'See services',
                expand: false,
                onPressed: () => context.go('/services')),
          ),
        ),
      );
    }

    final d = ref.watch(draftProvider(widget.serviceId));
    final notifier = ref.read(draftProvider(widget.serviceId).notifier);
    _syncCoupon(d);
    final wallet = ref.watch(walletProvider);
    final payable =
        d.car == null ? service.fromPrice : d.payableTotal(wallet.balance);
    final stage = _stage;
    final title = switch (stage) {
      _Stage.extras => 'Add extras',
      _Stage.time => 'Pick a time',
      _Stage.review => 'Review and request',
    };

    final body = switch (stage) {
      _Stage.extras => [
          BookingItemCard(draft: d),
          const SizedBox(height: AppSpace.xxl),
          Row(children: [
            Expanded(
                child: Semantics(
                    header: true,
                    child: Text('Popular add-ons', style: AppText.h3))),
            Text('Optional', style: AppText.caption),
          ]),
          const SizedBox(height: AppSpace.md),
          AddOnStrip(draft: d, notifier: notifier),
          const SizedBox(height: AppSpace.md),
          Text('Extras are done in the same visit, by the same expert.',
              style: AppText.small),
        ],
      _Stage.time => [
          SlotPicker(draft: d, notifier: notifier, showErrors: _showErrors),
          const SizedBox(height: AppSpace.lg),
          const NoticeBox(
            icon: Icons.schedule_rounded,
            text: 'This is a request. We confirm your slot in the app, '
                'usually within $kConfirmUsually.',
          ),
        ],
      _Stage.review => [
          _ReviewRows(
            draft: d,
            onChangeTime: () => _goTo(_Stage.time),
            onChangeAddress: () => showAddressSheet(context, ref),
            onChangeCar: () => showCarSheet(context, ref),
          ),
          if (_sendError != null) ...[
            const SizedBox(height: AppSpace.md),
            _SendFailed(message: _sendError!),
          ],
          const SizedBox(height: AppSpace.md),
          BillCard(draft: d, notifier: notifier),
          const SizedBox(height: AppSpace.md),
          const _BeforeYouRequest(),
        ],
    };

    final slot = d.scheduleDone ? d.slot : null;
    final bar = switch (stage) {
      _Stage.extras => _Bar(
          price: rupees(payable),
          line: d.selectedExtras.isEmpty
              ? '${service.listName} · no extras'
              : '${service.listName} + ${d.selectedExtras.length} '
                  '${d.selectedExtras.length == 1 ? 'extra' : 'extras'}',
          button: PrimaryButton(
            label: 'Continue',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => _goTo(_Stage.time),
          ),
        ),
      _Stage.time => _Bar(
          price: d.date == null ? 'Pick a day' : friendlyDate(d.date!),
          priceSmall: true,
          line: slot == null ? 'Pick a time window' : slot.short,
          button: PrimaryButton(
            label: 'Continue',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => _continueFromTime(d),
          ),
        ),
      _Stage.review => _Bar(
          price: rupees(payable),
          line: kPayAfterService ? 'pay after service' : 'to pay',
          button: PrimaryButton(
            label: _sendError == null ? 'Request slot' : 'Try again',
            icon: _sendError == null ? null : Icons.refresh_rounded,
            loading: _sending,
            onPressed: () => _onBook(d),
          ),
        ),
    };

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.15,
          child: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.page, AppSpace.sm, AppSpace.page, AppSpace.xxl),
              children: [
                _StepHeader(
                  step: _index + 1,
                  of: _stages.length,
                  title: title,
                  onBack: _back,
                  onSkip: stage == _Stage.extras
                      ? () {
                          for (final e in service.extras) {
                            notifier.setExtra(e.id, 0);
                          }
                          _goTo(_Stage.time);
                        }
                      : null,
                ),
                const SizedBox(height: AppSpace.xl),
                ...body,
              ],
            ),
          ),
        ),
        bottomNavigationBar: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.15,
          child: bar,
        ),
      ),
    );
  }
}

// ── Header: back, "Step 2 of 3", title, progress ─────────────────────────────
class _StepHeader extends StatelessWidget {
  final int step, of;
  final String title;
  final VoidCallback onBack;
  final VoidCallback? onSkip;
  const _StepHeader({
    required this.step,
    required this.of,
    required this.title,
    required this.onBack,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Semantics(
          button: true,
          label: 'Back',
          child: ExcludeSemantics(
            child: Material(
              color: AppColors.surface,
              shape:
                  const CircleBorder(side: BorderSide(color: AppColors.border)),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onBack,
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
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Step $step of $of', style: AppText.caption),
            Semantics(header: true, child: Text(title, style: AppText.h2)),
          ]),
        ),
        if (onSkip != null)
          TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle: AppText.bodyStrong,
              minimumSize: const Size(44, 44),
            ),
            child: const Text('Skip'),
          ),
      ]),
      const SizedBox(height: AppSpace.md),
      Semantics(
        label: 'Step $step of $of',
        child: ExcludeSemantics(
          child: Row(children: [
            for (var i = 0; i < of; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 4,
                  decoration: BoxDecoration(
                    color:
                        i < step ? AppColors.primary : const Color(0xFFDDE1E5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ),
    ]);
  }
}

// ── Review: when, where, which car ───────────────────────────────────────────
class _ReviewRows extends StatelessWidget {
  final BookingDraft draft;
  final VoidCallback onChangeTime, onChangeAddress, onChangeCar;
  const _ReviewRows({
    required this.draft,
    required this.onChangeTime,
    required this.onChangeAddress,
    required this.onChangeCar,
  });

  @override
  Widget build(BuildContext context) {
    final d = draft;
    final slot = d.scheduleDone ? d.slot : null;
    final noAddress = d.address.trim().isEmpty;
    final outside = d.coverage == Coverage.notCovered;
    final carTitle = d.car == null
        ? 'Add your car'
        : d.carModel.trim().isEmpty
            ? carTypeNames[d.car]!
            : d.carModel.trim();
    return AppCard(
      radius: AppRadius.lg,
      padding: EdgeInsets.zero,
      child: Column(children: [
        _row(
          icon: Icons.calendar_today_rounded,
          title: d.date == null ? 'Pick a day' : friendlyDate(d.date!),
          line: slot == null
              ? 'Pick a time window'
              : 'Expert arrives ${slot.short}',
          onChange: onChangeTime,
        ),
        const Divider(height: 1),
        _row(
          icon: Icons.location_on_outlined,
          title: noAddress ? 'Add your address' : 'Car parked at',
          line: noAddress
              ? 'Where should the expert come?'
              : outside
                  ? 'We don\'t serve this address yet'
                  : withParking(d.address, null),
          warn: noAddress || outside,
          onChange: onChangeAddress,
        ),
        const Divider(height: 1),
        _row(
          icon: Icons.directions_car_outlined,
          title: carTitle,
          line: d.car == null
              ? 'Prices depend on the size'
              : carTypeNames[d.car]!,
          warn: d.car == null,
          onChange: onChangeCar,
        ),
      ]),
    );
  }

  Widget _row({
    required IconData icon,
    required String title,
    required String line,
    required VoidCallback onChange,
    bool warn = false,
  }) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.lg, AppSpace.md, AppSpace.sm, AppSpace.md),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: warn ? AppColors.warningSoft : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon,
                size: 18, color: warn ? AppColors.warning : AppColors.text),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppText.title),
              Text(line,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.small.copyWith(
                      color: warn ? AppColors.warning : AppColors.textMuted)),
            ]),
          ),
          TextButton(
            onPressed: onChange,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle: AppText.smallStrong,
              minimumSize: const Size(44, 44),
            ),
            child: const Text('Change'),
          ),
        ]),
      );
}

/// Red notice when the request didn't reach us. Nothing was booked; the
/// choices stay, and the button below says "Try again".
class _SendFailed extends StatelessWidget {
  final String message;
  const _SendFailed({required this.message});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.lg),
        decoration: BoxDecoration(
          color: AppColors.errorSoft,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: const Color(0xFFF7C9C9)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.error_outline_rounded,
              size: 22, color: AppColors.error),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Your request didn\'t send',
                  style: AppText.bodyStrong
                      .copyWith(color: const Color(0xFF991B1B))),
              const SizedBox(height: 2),
              Text('Nothing was booked. $message Your choices are saved.',
                  style: AppText.small
                      .copyWith(color: const Color(0xFF7F1D1D), height: 1.4)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// The things to know before tapping "Request slot". This is the one
/// place on the booking page that mentions water and power.
class _BeforeYouRequest extends StatelessWidget {
  const _BeforeYouRequest();

  @override
  Widget build(BuildContext context) {
    const rows = [
      (
        Icons.schedule_send_rounded,
        'We confirm your slot in the app, usually within $kConfirmUsually.'
      ),
      (
        Icons.electrical_services_rounded,
        'Keep a water tap and plug point ready. We bring 30 m cords and pipes.'
      ),
      if (kPayAfterService)
        (Icons.payments_rounded, 'Pay after the wash, cash or UPI.'),
      (
        Icons.event_available_rounded,
        'Free to cancel until 4 hours before your slot.'
      ),
    ];
    return AppCard(
      radius: AppRadius.lg,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Before you request', style: AppText.title),
        const SizedBox(height: AppSpace.sm),
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
      ]),
    );
  }
}

// ── Bottom bar: a number on the left, one button ─────────────────────────────
class _Bar extends StatelessWidget {
  final String price, line;
  final bool priceSmall;
  final Widget button;
  const _Bar({
    required this.price,
    required this.line,
    required this.button,
    this.priceSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    return BottomActionBar(
      child: Row(children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(price,
                    key: ValueKey(price),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: priceSmall
                        ? AppText.title
                        : AppText.price),
              ),
              Text(line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption),
            ],
          ),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(child: button),
      ]),
    );
  }
}

// ── "That slot just filled up" ───────────────────────────────────────────────
/// Returns the id of the open window the customer picks, or null for
/// "See other days".
class _SlotTakenSheet extends StatefulWidget {
  final String takenLabel, day;
  final List<TimeSlot> open;
  const _SlotTakenSheet(
      {required this.takenLabel, required this.day, required this.open});

  @override
  State<_SlotTakenSheet> createState() => _SlotTakenSheetState();
}

class _SlotTakenSheetState extends State<_SlotTakenSheet> {
  String? _pick;

  @override
  void initState() {
    super.initState();
    _pick = widget.open.firstOrNull?.id;
  }

  @override
  Widget build(BuildContext context) {
    final open = widget.open;
    final chosen = open.where((s) => s.id == _pick).firstOrNull;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.page, 0, AppSpace.page, AppSpace.lg),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: IconBadge(Icons.schedule_rounded, size: 48),
              ),
              const SizedBox(height: AppSpace.md),
              Text('${widget.takenLabel} just filled up', style: AppText.h3),
              const SizedBox(height: 4),
              Text(
                  open.isEmpty
                      ? 'Someone booked it a moment ago, and ${widget.day} is now full.'
                      : 'Someone booked it a moment ago. These times are still '
                          'open ${widget.day.toLowerCase()}:',
                  style: AppText.small),
              if (open.isNotEmpty) ...[
                const SizedBox(height: AppSpace.lg),
                Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
                  for (final s in open)
                    ChoiceChip(
                      label: Text(s.short),
                      selected: s.id == _pick,
                      onSelected: (_) => setState(() => _pick = s.id),
                      labelStyle: AppText.smallStrong.copyWith(
                          color: s.id == _pick ? Colors.white : AppColors.text),
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      showCheckmark: false,
                      side: BorderSide(
                          color: s.id == _pick
                              ? AppColors.primary
                              : AppColors.border),
                    ),
                ]),
                const SizedBox(height: AppSpace.lg),
                PrimaryButton(
                  label: chosen == null
                      ? 'Request this time'
                      : 'Request ${chosen.short}',
                  onPressed: chosen == null
                      ? null
                      : () => Navigator.pop(context, chosen.id),
                ),
              ],
              const SizedBox(height: AppSpace.sm),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                child: const Text('See other days'),
              ),
            ]),
      ),
    );
  }
}
