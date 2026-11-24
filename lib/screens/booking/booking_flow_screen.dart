import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/format.dart';
import '../../core/pricing.dart';
import '../../core/scheduling.dart' show clockLabel;
import '../../core/theme.dart';
import '../../data/api/models.dart';
import '../../data/business_info.dart';
import '../../models/booking.dart' show withParking;
import '../../models/service.dart';
import '../../providers/api_providers.dart';
import '../../providers/app_providers.dart';
import '../../providers/booking_providers.dart';
import '../../widgets/customer_sheets.dart';
import '../../widgets/ui.dart';
import 'booking_steps.dart';

/// The booking, in three short steps (v3 design):
/// 1. Extras (skipped for packages that have none),
/// 2. Pick a time,
/// 3. Review and "Request slot".
/// Car and address come from the customer's profile; Review has a "Change"
/// for each. Start times, the bill, coupons and credit come from the server
/// (docs/API_CONTRACT.md §5); the app only shows them.
///
/// The button says "Request slot" because the team still confirms the slot;
/// the page and the next screen say so in plain words.
class BookingFlowScreen extends ConsumerStatefulWidget {
  final String serviceId;
  final CarType? initialCar;

  /// Booking a visit of this monthly plan (contract §8): the wash is paid.
  final String? planId;
  const BookingFlowScreen(
      {super.key, required this.serviceId, this.initialCar, this.planId});

  @override
  ConsumerState<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

enum _Stage { extras, time, review }

class _BookingFlowScreenState extends ConsumerState<BookingFlowScreen> {
  bool _showErrors = false;
  bool _sending = false;
  String? _sendError;
  int _index = 0;
  String? _lastCouponNotice;

  /// Set when the customer is buying a monthly plan: the first visit is
  /// booked here, the plan price is paid at that visit.
  CatalogPlan? _plan;

  CarService? get _display => serviceById(widget.serviceId);
  RequestDraftNotifier get _notifier =>
      ref.read(requestDraftProvider(widget.serviceId).notifier);

  List<_Stage> _stages(CatalogService s) => [
        if (_plan == null && s.extras.isNotEmpty) _Stage.extras,
        _Stage.time,
        _Stage.review,
      ];

  @override
  void initState() {
    super.initState();
    // Keep this screen's draft alive while the catalog loads (nothing else
    // watches it yet), so the car, plan and coupon set below aren't lost.
    ref.listenManual(requestDraftProvider(widget.serviceId), (_, __) {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = ref.read(profileProvider);
      final car = widget.initialCar ?? p.car;
      if (car != null) _notifier.setCar(car, p.carModel);
      if (widget.planId != null) _notifier.setPlan(widget.planId!);
      // A coupon tapped "Use" on in Offers: the server says if it applies.
      final picked = ref.read(pickedOfferProvider);
      if (picked != null && widget.planId == null) _notifier.setCoupon(picked);
    });
    // Car changed from a sheet: use it for this booking too.
    ref.listenManual(profileProvider, (prev, p) {
      if (p.car != null && (p.car != prev?.car || p.carModel != prev?.carModel)) {
        _notifier.setCar(p.car!, p.carModel);
      }
    });
  }

  void _goTo(CatalogService s, _Stage stage) =>
      setState(() => _index = _stages(s).indexOf(stage));

  void _back() {
    if (_index > 0) {
      setState(() => _index--);
    } else {
      context.canPop() ? context.pop() : context.go('/home');
    }
  }

  /// A coupon the server won't take comes off, with its reason, once.
  void _syncCoupon(RequestDraft d, Quote? q) {
    final code = d.couponCode;
    if (code == null || q == null || q.couponApplied) return;
    final notice = '$code removed: ${q.couponReason ?? 'not valid here'}';
    if (_lastCouponNotice == notice) return;
    _lastCouponNotice = notice;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.setCoupon(null);
      showMessage(context, notice);
    });
  }

  /// What still stops the booking, in the order the customer fixes it.
  String? _blocker(RequestDraft d, ApiAddress? address) {
    if (d.car == null) return 'Add your car';
    if (address == null) return 'Add your address';
    if (!ref.read(authServiceProvider).signedIn) return 'Please log in again to book';
    if (d.date == null) return 'Pick a day';
    if (d.start == null) return 'Pick a time';
    return null;
  }

  void _continueFromTime(CatalogService s, RequestDraft d) {
    if (!d.timePicked) {
      setState(() => _showErrors = true);
      showMessage(context, d.date == null ? 'Pick a day' : 'Pick a time');
      return;
    }
    _goTo(s, _Stage.review);
  }

  Future<void> _onBook(CatalogService s, RequestDraft d, ApiAddress? address,
      Quote? quote) async {
    if (d.car == null) return showCarSheet(context, ref);
    if (address == null) return showAddressSheet(context, ref);
    final blocker = _blocker(d, address);
    if (blocker == 'Pick a day' || blocker == 'Pick a time') {
      setState(() => _showErrors = true);
      _goTo(s, _Stage.time);
      return;
    }
    if (blocker != null) {
      showMessage(context, blocker);
      return;
    }
    final plan = _plan;
    if (plan != null) return _sendPlan(s, plan, d, address);
    if (quote == null) {
      showMessage(context, 'Getting the price, one moment…');
      return;
    }
    await _send(s, d.request(address)!, quote);
  }

  /// Buys a monthly plan together with its first visit (contract §8).
  Future<void> _sendPlan(
      CatalogService s, CatalogPlan plan, RequestDraft d, ApiAddress address) async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      final api = ref.read(apiProvider);
      // Plans need a saved address on the server (saved addresses move
      // there fully in a later step); reuse it if it is already saved.
      final saved = (await api.addresses()).where((a) =>
              a.flat == address.flat &&
              a.building == address.building &&
              a.area == address.area)
          .firstOrNull ??
          await api.addAddress(address);
      final r = await api.buyPlan(
        clientRef: d.clientRef,
        planId: plan.id,
        car: d.apiCar!,
        addressId: saved.id!,
        firstVisit: SlotPick(d.date!, d.start!),
      );
      if (!mounted) return;
      ref.invalidate(meProvider);
      context.pushReplacement('/booking-sent/${r.booking.ref}');
      return;
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == ApiCode.slotTaken) {
        setState(() => _sending = false);
        showMessage(context, 'That time was just taken. Please pick another.');
        _goTo(s, _Stage.time);
        return;
      }
      setState(() => _sendError = e.message);
    } on Object {
      if (mounted) setState(() => _sendError = 'Please try again in a moment.');
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _send(CatalogService s, BookingRequest r, Quote quote) async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _sendError = null;
    });
    final draft = ref.read(requestDraftProvider(widget.serviceId));
    try {
      final booking = await ref
          .read(apiProvider)
          .createBooking(r.forSubmit(clientRef: draft.clientRef, quote: quote));
      if (!mounted) return;
      ref.invalidate(meProvider);
      ref.invalidate(myPlansProvider);
      ref.invalidate(myApiBookingsProvider);
      if (r.couponCode != null && r.couponCode == ref.read(pickedOfferProvider)) {
        await ref.read(pickedOfferProvider.notifier).pick(null);
      }
      if (mounted) context.pushReplacement('/booking-sent/${booking.ref}');
      return;
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      switch (e.code) {
        case ApiCode.slotTaken:
          final alternatives = [
            for (final a in (e.details['alternatives'] as List? ?? const []))
              Slot.fromJson(Map<String, dynamic>.from(a as Map)),
          ];
          await _offerOtherTimes(s, r, alternatives);
        case ApiCode.priceChanged:
          ref.invalidate(quoteProvider(quoteKey(r)));
          showMessage(context, 'The price changed. Please check the bill and request again.');
        case ApiCode.couponInvalid:
          _notifier.setCoupon(null);
          showMessage(context, '${r.couponCode} removed: ${e.message}');
        case ApiCode.pendingLimit:
          setState(() => _sendError = '${e.message} Please wait for them to be '
              'confirmed, or cancel one under My bookings.');
        default:
          setState(() => _sendError = e.message);
      }
      return;
    } on Object {
      // Nothing is shown as sent: the draft stays here so the customer can
      // retry, and the retry reuses the same reference (no duplicates).
      if (mounted) setState(() => _sendError = 'Please try again in a moment.');
    }
    if (mounted) setState(() => _sending = false);
  }

  /// The chosen time filled up while the customer was deciding. Offer the
  /// times the server says are still open, or a way back to the day picker.
  Future<void> _offerOtherTimes(
      CatalogService s, BookingRequest r, List<Slot> open) async {
    final picked = await showModalBottomSheet<Slot>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _SlotTakenSheet(
        takenLabel: clockLabel(r.slot.start),
        day: friendlyDate(r.slot.date),
        open: open,
      ),
    );
    if (!mounted) return;
    final d = ref.read(requestDraftProvider(widget.serviceId));
    if (picked == null) {
      _notifier.setDate(d.date ?? r.slot.date);
      _goTo(s, _Stage.time);
      return;
    }
    _notifier.setTime(picked.date, picked.start);
    final next = ref.read(requestDraftProvider(widget.serviceId))
        .request(apiAddressOf(ref.read(profileProvider)))!;
    try {
      final q = await ref.read(apiProvider).quote(next);
      if (mounted) await _send(s, next, q);
    } on ApiException catch (e) {
      if (mounted) setState(() => _sendError = e.message);
    }
  }

  Widget _notFound() => Scaffold(
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

  @override
  Widget build(BuildContext context) {
    final display = _display;
    if (display == null) return _notFound();
    final catalog = ref.watch(catalogProvider);
    final config = ref.watch(apiConfigProvider).valueOrNull;
    return catalog.when(
      loading: () => const Scaffold(
          backgroundColor: AppColors.bg,
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: EmptyState(
            icon: Icons.wifi_off_rounded,
            title: 'Couldn\'t load prices',
            message: 'Check your connection and try again.',
            action: PrimaryButton(
                label: 'Try again',
                expand: false,
                onPressed: () => ref.invalidate(catalogProvider)),
          ),
        ),
      ),
      data: (c) {
        final plan = c.plan(widget.serviceId);
        final s = c.service(plan?.serviceId ?? widget.serviceId);
        if (s == null) return _notFound();
        _plan = plan;
        return _flow(display, s, config?.bookingWindowDays ?? 14);
      },
    );
  }

  Widget _flow(CarService display, CatalogService service, int windowDays) {
    final d = ref.watch(requestDraftProvider(widget.serviceId));
    final notifier = _notifier;
    final address = apiAddressOf(ref.watch(profileProvider));
    final stages = _stages(service);
    if (_index >= stages.length) _index = stages.length - 1;
    final stage = stages[_index];

    final plan = _plan;
    final request = plan == null ? d.request(address) : null;
    final quote = stage == _Stage.review && request != null
        ? ref.watch(quoteProvider(quoteKey(request)))
        : null;
    final q = quote?.valueOrNull;
    _syncCoupon(d, q);

    final extrasTotal = d.extras.entries.fold<int>(
        0, (sum, e) => sum + (service.extra(e.key)?.price ?? 0) * e.value);
    final from = service.prices.values.reduce((a, b) => a < b ? a : b);
    final listPrice =
        (d.car == null ? from : service.priceFor(d.car!)) + extrasTotal;

    final title = switch (stage) {
      _Stage.extras => 'Add extras',
      _Stage.time => 'Pick a time',
      _Stage.review => 'Review and request',
    };

    final body = switch (stage) {
      _Stage.extras => [
          BookingItemCard(display: display, service: service, car: d.car),
          const SizedBox(height: AppSpace.xxl),
          Row(children: [
            Expanded(
                child: Semantics(
                    header: true,
                    child: Text('Popular add-ons', style: AppText.h3))),
            Text('Optional', style: AppText.caption),
          ]),
          const SizedBox(height: AppSpace.md),
          AddOnStrip(service: service, draft: d, notifier: notifier),
          const SizedBox(height: AppSpace.md),
          Text('Extras are done in the same visit, by the same expert.',
              style: AppText.small),
        ],
      _Stage.time => [
          if (d.car == null)
            const NoticeBox(
              icon: Icons.directions_car_outlined,
              warning: true,
              text: 'Add your car first: the time depends on its size.',
            )
          else
            SlotPicker(
                serviceId: service.id,
                draft: d,
                notifier: notifier,
                windowDays: windowDays,
                showErrors: _showErrors),
          const SizedBox(height: AppSpace.lg),
          const NoticeBox(
            icon: Icons.schedule_rounded,
            text: 'This is a request. We confirm your slot on WhatsApp and '
                'in the app, usually within $kConfirmUsually.',
          ),
        ],
      _Stage.review => [
          _ReviewRows(
            draft: d,
            address: address,
            onChangeTime: () => _goTo(service, _Stage.time),
            onChangeAddress: () => showAddressSheet(context, ref),
            onChangeCar: () => showCarSheet(context, ref),
          ),
          if (_sendError != null) ...[
            const SizedBox(height: AppSpace.md),
            _SendFailed(message: _sendError!),
          ],
          const SizedBox(height: AppSpace.md),
          if (plan != null)
            _PlanBill(plan: plan, car: d.car)
          else if (quote != null)
            BillCard(
              quote: quote,
              draft: d,
              notifier: notifier,
              onRetry: () => ref.invalidate(quoteProvider(quoteKey(request!))),
            ),
          const SizedBox(height: AppSpace.md),
          const _BeforeYouRequest(),
        ],
    };

    final bar = switch (stage) {
      _Stage.extras => _Bar(
          price: rupees(listPrice),
          line: d.extras.isEmpty
              ? '${display.listName} · no extras'
              : '${display.listName} + ${d.extras.length} '
                  '${d.extras.length == 1 ? 'extra' : 'extras'}',
          button: PrimaryButton(
            label: 'Continue',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => _goTo(service, _Stage.time),
          ),
        ),
      _Stage.time => _Bar(
          price: d.date == null ? 'Pick a day' : friendlyDate(d.date!),
          priceSmall: true,
          line: d.start == null
              ? 'Pick a time'
              : 'Expert arrives ${clockLabel(d.start!)}',
          button: PrimaryButton(
            label: 'Continue',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => _continueFromTime(service, d),
          ),
        ),
      _Stage.review => _Bar(
          price: plan != null
              ? (d.car == null ? '…' : rupees(plan.prices[d.car]!))
              : q == null
                  ? '…'
                  : rupees(q.bill.total),
          line: kPayAfterService ? 'pay after service' : 'to pay',
          button: PrimaryButton(
            label: _sendError == null ? 'Request slot' : 'Try again',
            icon: _sendError == null ? null : Icons.refresh_rounded,
            loading: _sending,
            onPressed: () => _onBook(service, d, address, q),
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
                  of: stages.length,
                  title: title,
                  onBack: _back,
                  onSkip: stage == _Stage.extras
                      ? () {
                          notifier.clearExtras();
                          _goTo(service, _Stage.time);
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
  final RequestDraft draft;
  final ApiAddress? address;
  final VoidCallback onChangeTime, onChangeAddress, onChangeCar;
  const _ReviewRows({
    required this.draft,
    required this.address,
    required this.onChangeTime,
    required this.onChangeAddress,
    required this.onChangeCar,
  });

  @override
  Widget build(BuildContext context) {
    final d = draft;
    final noAddress = address == null;
    final carTitle = d.car == null
        ? 'Add your car'
        : d.carModel.trim().isEmpty
            ? carTypeNames[d.car]!
            : d.carModel.trim();
    final a = address;
    return AppCard(
      radius: AppRadius.lg,
      padding: EdgeInsets.zero,
      child: Column(children: [
        _row(
          icon: Icons.calendar_today_rounded,
          title: d.date == null ? 'Pick a day' : friendlyDate(d.date!),
          line: d.start == null
              ? 'Pick a time'
              : 'Expert arrives ${clockLabel(d.start!)}',
          onChange: onChangeTime,
        ),
        const Divider(height: 1),
        _row(
          icon: Icons.location_on_outlined,
          title: noAddress ? 'Add your address' : 'Car parked at',
          line: noAddress
              ? 'Where should the expert come?'
              : withParking(
                  [a!.flat, if (a.building.isNotEmpty) a.building, a.area]
                      .join(', '),
                  null),
          warn: noAddress,
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
        'We confirm your slot on WhatsApp, usually within $kConfirmUsually '
            '(8 AM – 6 PM).'
      ),
      (
        Icons.electrical_services_rounded,
        'Keep a water tap and plug point ready. We bring 30 m cords and pipes.'
      ),
      if (kPayAfterService)
        (Icons.payments_rounded, 'Pay after the wash, cash or UPI.'),
      (
        Icons.event_available_rounded,
        'Free to cancel until 2 hours before your slot. Later, ₹100 is added '
            'to your next booking.'
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

/// The plan's price, paid at the first visit (no coupons or credit on plans).
class _PlanBill extends StatelessWidget {
  final CatalogPlan plan;
  final CarType? car;
  const _PlanBill({required this.plan, required this.car});

  @override
  Widget build(BuildContext context) {
    final price = car == null ? null : plan.prices[car];
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text('${plan.name} · ${plan.visits} visits in '
                  '${plan.days} days',
                  style: AppText.small.copyWith(color: AppColors.text))),
          const SizedBox(width: AppSpace.md),
          Text(price == null ? '…' : rupees(price), style: AppText.smallStrong),
        ]),
        for (final i in plan.includes)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(children: [
              const Icon(Icons.check_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(child: Text(i, style: AppText.small)),
            ]),
          ),
        const Divider(height: AppSpace.lg),
        Row(children: [
          Expanded(
              child: Text('To pay at the first visit', style: AppText.bodyStrong)),
          Text(price == null ? '…' : rupees(price), style: AppText.price),
        ]),
        Text('Includes GST. You book the other visits from My bookings.',
            style: AppText.caption),
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
                    style: priceSmall ? AppText.title : AppText.price),
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

// ── "That time just filled up" ───────────────────────────────────────────────
/// Returns the open time the customer picks, or null for "See other days".
class _SlotTakenSheet extends StatefulWidget {
  final String takenLabel, day;
  final List<Slot> open;
  const _SlotTakenSheet(
      {required this.takenLabel, required this.day, required this.open});

  @override
  State<_SlotTakenSheet> createState() => _SlotTakenSheetState();
}

class _SlotTakenSheetState extends State<_SlotTakenSheet> {
  Slot? _pick;

  @override
  void initState() {
    super.initState();
    _pick = widget.open.firstOrNull;
  }

  String _label(Slot s) {
    final today = dateOnly(DateTime.now());
    final sameDay = dateOnly(s.date) == dateOnly(widget.open.first.date);
    return sameDay && dateOnly(s.date) != today
        ? clockLabel(s.start)
        : '${friendlyDate(s.date)}, ${clockLabel(s.start)}';
  }

  @override
  Widget build(BuildContext context) {
    final open = widget.open;
    final chosen = _pick;
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
                      : 'Someone booked it a moment ago. These times are still open:',
                  style: AppText.small),
              if (open.isNotEmpty) ...[
                const SizedBox(height: AppSpace.lg),
                Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
                  for (final s in open)
                    ChoiceChip(
                      label: Text(_label(s)),
                      selected: identical(s, _pick),
                      onSelected: (_) => setState(() => _pick = s),
                      labelStyle: AppText.smallStrong.copyWith(
                          color: identical(s, _pick)
                              ? Colors.white
                              : AppColors.text),
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      showCheckmark: false,
                      side: BorderSide(
                          color: identical(s, _pick)
                              ? AppColors.primary
                              : AppColors.border),
                    ),
                ]),
                const SizedBox(height: AppSpace.lg),
                PrimaryButton(
                  label: chosen == null
                      ? 'Request this time'
                      : 'Request ${clockLabel(chosen.start)}',
                  onPressed:
                      chosen == null ? null : () => Navigator.pop(context, chosen),
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
