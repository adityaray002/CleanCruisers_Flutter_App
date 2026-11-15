import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/format.dart';
import '../../core/pricing.dart';
import '../../core/scheduling.dart';
import '../../core/theme.dart';
import '../../data/booking_cloud.dart';
import '../../data/offers.dart';
import '../../models/booking.dart';
import '../../models/service.dart';
import '../../providers/app_providers.dart';
import '../../widgets/customer_sheets.dart';
import '../../widgets/ui.dart';
import '../auth/login_screen.dart' show CarTypePicker;
import 'booking_steps.dart';

/// The booking page: the service, optional add-ons, a slot, the bill and
/// one button. Car and address come from the customer's profile (asked once
/// at sign-up); one "Change" above the button edits them. Nothing is typed.
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

class _BookingFlowScreenState extends ConsumerState<BookingFlowScreen> {
  final _slotKey = GlobalKey();
  bool _showErrors = false;
  bool _sending = false;
  String? _sendError;

  CarService? get _service => serviceById(widget.serviceId);
  DraftNotifier get _notifier =>
      ref.read(draftProvider(widget.serviceId).notifier);
  List<ServiceArea> get _areas =>
      ref.read(serviceAreasProvider).valueOrNull ?? const [];

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

  Future<void> _onBook(BookingDraft d) async {
    if (d.car == null) return showCarSheet(context, ref);
    if (d.address.trim().isEmpty) return showAddressSheet(context, ref);
    final blocker = _blocker(d);
    if (blocker == 'Pick a day' || blocker == 'Pick a time') {
      setState(() => _showErrors = true);
      return _scrollToSlots();
    }
    if (blocker != null) {
      showMessage(context, blocker);
      return;
    }
    await _send(d);
  }

  Future<void> _scrollToSlots() async {
    final target = _slotKey.currentContext;
    if (target == null) return;
    await Scrollable.ensureVisible(target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.05);
  }

  /// One "Change" for car and address: a tiny menu of the two.
  Future<void> _changeDetails(BookingDraft d) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: Icon(
                  d.car == null
                      ? Icons.directions_car_rounded
                      : CarTypePicker.icons[d.car]!,
                  color: AppColors.primary),
              title: Text('Change car', style: AppText.bodyStrong),
              subtitle: Text(_carLabel(d), style: AppText.small),
              onTap: () {
                Navigator.pop(ctx);
                showCarSheet(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on_rounded,
                  color: AppColors.primary),
              title: Text('Change address', style: AppText.bodyStrong),
              subtitle: Text(d.address.isEmpty ? 'Not added yet' : d.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.small),
              onTap: () {
                Navigator.pop(ctx);
                showAddressSheet(context, ref);
              },
            ),
            const SizedBox(height: AppSpace.sm),
          ]),
        ),
      );

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
    } on Object catch (error) {
      // Nothing is shown as sent: the draft stays here so the customer can
      // retry, and the retry reuses the same reference (no duplicates).
      if (mounted) {
        final message = error is BookingCloudException
            ? error.message
            : 'Please try again in a moment.';
        setState(() => _sendError = message);
        showMessage(context, 'Not sent. $message');
      }
    }
    if (mounted) setState(() => _sending = false);
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
    final blocker = _blocker(d);
    // The button names the next thing to do, then the one verb: Request.
    final label = switch (blocker) {
      'Add your car' ||
      'Add your address' ||
      'Pick a day' ||
      'Pick a time' =>
        blocker!,
      _ => _sendError == null ? 'Request slot' : 'Try again',
    };
    final slot = d.scheduleDone ? d.slot : null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Text('Book a wash', style: AppText.h3),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.page, AppSpace.sm, AppSpace.page, AppSpace.xxl),
        children: [
          BookingItemCard(draft: d),
          if (service.extras.isNotEmpty) ...[
            const SizedBox(height: AppSpace.xxl),
            const StepHeading(Icons.add_circle_rounded, 'Add-ons',
                optional: true),
            AddOnStrip(draft: d, notifier: notifier),
          ],
          const SizedBox(height: AppSpace.xxl),
          KeyedSubtree(
            key: _slotKey,
            child: const StepHeading(
                Icons.schedule_rounded, 'When should the expert come?'),
          ),
          SlotPicker(draft: d, notifier: notifier, showErrors: _showErrors),
          const SizedBox(height: AppSpace.lg),
          if (_sendError != null) ...[
            NoticeBox(
              icon: Icons.cloud_off_rounded,
              warning: true,
              text: 'Not sent. $_sendError Tap "Try again".',
            ),
            const SizedBox(height: AppSpace.md),
          ],
          const StepHeading(Icons.receipt_long_rounded, 'Bill'),
          BillCard(draft: d, notifier: notifier),
          const SizedBox(height: AppSpace.md),
          const _BeforeYouRequest(),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        top: _Details(
          draft: d,
          carLabel:
              d.carModel.trim().isNotEmpty ? d.carModel.trim() : _carLabel(d),
          onChange: () => _changeDetails(d),
        ),
        child: Row(children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(rupees(payable),
                    key: ValueKey(payable), style: AppText.price),
              ),
              // The chosen slot stays in view however far they scroll.
              Text(
                  slot == null
                      ? 'Pay after wash'
                      : '${friendlyDate(d.date!)} · ${clockLabel(slot.startMinute)}',
                  style: AppText.caption.copyWith(
                      color: slot == null
                          ? AppColors.textSubtle
                          : AppColors.primaryDk,
                      fontWeight: slot == null ? null : FontWeight.w700)),
            ],
          ),
          const SizedBox(width: AppSpace.lg),
          Expanded(
            child: PrimaryButton(
              label: label,
              icon: blocker == null ? Icons.schedule_send_rounded : null,
              loading: _sending,
              onPressed: () => _onBook(d),
            ),
          ),
        ]),
      ),
    );
  }

  static String _carLabel(BookingDraft d) => d.car == null
      ? 'Add your car'
      : d.carModel.trim().isEmpty
          ? carTypeNames[d.car]!
          : '${d.carModel.trim()} · ${carTypeNames[d.car]}';
}

/// "Swift · Hatchback · Janakpuri   Change" — one line above the button.
class _Details extends StatelessWidget {
  final BookingDraft draft;
  final String carLabel;
  final VoidCallback onChange;
  const _Details(
      {required this.draft, required this.carLabel, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final d = draft;
    final noAddress = d.address.trim().isEmpty;
    final outside = d.coverage == Coverage.notCovered;
    final warn = d.car == null || noAddress || outside;
    final place = noAddress
        ? 'Add address'
        : outside
            ? 'We don\'t serve this area yet'
            : _area(d.address);
    return Semantics(
      button: true,
      label: '$carLabel at $place. Change car or address',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onChange,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 13), // ≥ 48 px tap target
            child: Row(children: [
              Icon(
                  d.car == null
                      ? Icons.directions_car_rounded
                      : CarTypePicker.icons[d.car]!,
                  size: 18,
                  color: AppColors.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(carLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.smallStrong),
              ),
              const SizedBox(width: AppSpace.md),
              Icon(Icons.location_on_rounded,
                  size: 18,
                  color: warn ? AppColors.warning : AppColors.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(place,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.smallStrong.copyWith(
                        color: warn ? AppColors.warning : AppColors.text)),
              ),
              Text('Change',
                  style: AppText.caption.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ),
    );
  }

  /// "B-12, Pocket 3, Janakpuri, near metro" → "Janakpuri".
  static String _area(String address) {
    final parts = withParking(address, null)
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && !s.toLowerCase().startsWith('near'))
        .toList();
    return parts.length < 2 ? address : parts.last;
  }
}

/// The three things to know before tapping "Request slot". This is the one
/// place on the booking page that mentions water and power.
class _BeforeYouRequest extends StatelessWidget {
  const _BeforeYouRequest();

  @override
  Widget build(BuildContext context) {
    const rows = [
      (Icons.schedule_send_rounded, 'We confirm your slot in the app'),
      (
        Icons.electrical_services_rounded,
        'Keep a water tap and plug point ready. We bring 30 m cords and pipes.'
      ),
      (Icons.payments_rounded, 'Pay after the wash, cash or UPI'),
    ];
    return AppCard(
      color: AppColors.primarySoft,
      child: Column(children: [
        for (final (icon, text) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Text(text,
                    style: AppText.small.copyWith(color: AppColors.primaryDk)),
              ),
            ]),
          ),
      ]),
    );
  }
}
