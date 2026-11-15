import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format.dart';
import '../../core/scheduling.dart';
import '../../core/theme.dart';
import '../../data/offers.dart';
import '../../models/booking.dart';
import '../../models/service.dart';
import '../../models/worker.dart' show dateKey;
import '../../providers/app_providers.dart';
import '../../widgets/offer_card.dart';
import '../../widgets/service_widgets.dart';
import '../../widgets/ui.dart';

/// Sections of the one-page checkout (see booking_flow_screen.dart).

class StepHeading extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool optional;
  const StepHeading(this.icon, this.text, {super.key, this.optional = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.md),
        child: Semantics(
          header: true,
          child: Row(children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: AppSpace.sm),
            Flexible(child: Text(text, style: AppText.h3)),
            if (optional) ...[
              const SizedBox(width: AppSpace.sm),
              Text('Optional', style: AppText.caption),
            ],
          ]),
        ),
      );
}

/// Gives a text field the same accessible name as its visible label.

Widget _error(String text) => Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child:
          Text(text, style: AppText.caption.copyWith(color: AppColors.error)),
    );

// ── Service being booked ──────────────────────────────────────────────────────
/// Photo, name, how long it takes, and the price for the customer's car.
class BookingItemCard extends StatelessWidget {
  final BookingDraft draft;
  const BookingItemCard({super.key, required this.draft});

  @override
  Widget build(BuildContext context) {
    final s = draft.service;
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Row(children: [
        SizedBox(
          width: 64,
          height: 64,
          child: ServiceImage(s, radius: AppRadius.sm),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.name,
                style: AppText.bodyStrong,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.timer_outlined,
                  size: 14, color: AppColors.textSubtle),
              const SizedBox(width: 4),
              // "2 hrs wash": how long it takes, not when the expert arrives.
              Flexible(
                child: Text(
                    s.duration.contains('hr')
                        ? '${s.duration} wash'
                        : s.duration,
                    style: AppText.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
          ]),
        ),
        const SizedBox(width: AppSpace.sm),
        Text(
            draft.car == null
                ? rupees(s.fromPrice)
                : rupees(draft.servicePrice),
            style: AppText.bodyStrong),
      ]),
    );
  }
}

// ── Add-ons: "add more" strip ─────────────────────────────────────────────────
class AddOnStrip extends StatelessWidget {
  final BookingDraft draft;
  final DraftNotifier notifier;
  const AddOnStrip({super.key, required this.draft, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final extras = draft.service.extras;
    // Height comes from the content so large text never clips.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < extras.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            SizedBox(
              width: 132,
              child: _AddOnCard(
                extra: extras[i],
                qty: draft.extras[extras[i].id] ?? 0,
                onChanged: (q) => notifier.setExtra(extras[i].id, q),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

class _AddOnCard extends StatelessWidget {
  final Extra extra;
  final int qty;
  final ValueChanged<int> onChanged;
  const _AddOnCard(
      {required this.extra, required this.qty, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final on = qty > 0;
    return AppCard(
      selected: on,
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(extra.name,
            style: AppText.bodyStrong,
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(
            '${rupees(extra.price)}'
            '${extra.unit != null ? ' / ${extra.unit}' : ''}',
            style: AppText.caption),
        const Spacer(),
        const SizedBox(height: AppSpace.sm),
        if (!on)
          Semantics(
            button: true,
            label: 'Add ${extra.name}',
            child: ExcludeSemantics(
              child: InlineButton(
                  label: 'Add', expand: true, onPressed: () => onChanged(1)),
            ),
          )
        else
          // Shop-style stepper: − qty +
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(children: [
              _Step(
                  Icons.remove_rounded, 'Remove one', () => onChanged(qty - 1)),
              Expanded(
                child: Text('$qty',
                    textAlign: TextAlign.center,
                    style: AppText.smallStrong.copyWith(color: Colors.white)),
              ),
              _Step(Icons.add_rounded, 'Add one',
                  qty < extra.maxQty ? () => onChanged(qty + 1) : null),
            ]),
          ),
      ]),
    );
  }
}

class _Step extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  const _Step(this.icon, this.tooltip, this.onTap);

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon,
                size: 18, color: onTap == null ? Colors.white38 : Colors.white),
          ),
        ),
      );
}

// ── Slot picker ───────────────────────────────────────────────────────────────
class SlotPicker extends ConsumerWidget {
  final BookingDraft draft;
  final DraftNotifier notifier;
  final bool showErrors;

  const SlotPicker({
    super.key,
    required this.draft,
    required this.notifier,
    required this.showErrors,
  });

  /// Days the customer can book this service on (today is skipped once no
  /// slot can still fit it).
  static List<DateTime> bookableDays(BookingDraft draft) {
    final today = dateOnly(DateTime.now());
    final minutes = draft.serviceDurationMinutes;
    return [for (var i = 0; i < kBookingWindowDays; i++) addDays(today, i)]
        .where((d) => timeSlots.any((s) =>
            s.isAvailable(d) && canFinishByClose(s.startMinute, minutes)))
        .toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = dateOnly(DateTime.now());
    final minutes = draft.serviceDurationMinutes;
    final bookable = bookableDays(draft);
    final capacity = draft.date == null
        ? CapacityDay.open
        : ref.watch(capacityProvider(dateKey(draft.date!))).valueOrNull ??
            CapacityDay.open;
    final states = {
      if (draft.date != null)
        for (final slot in timeSlots)
          slot.id: customerWindowState(
            windowStart: slot.startMinute,
            windowId: slot.id,
            date: draft.date!,
            serviceMinutes: minutes,
            capacity: capacity,
          ),
    };
    final noneFit = states.isNotEmpty &&
        states.values.every((s) => s != WindowState.preference);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 78,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: bookable.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpace.sm),
          itemBuilder: (_, i) => _DayChip(
            day: bookable[i],
            today: today,
            selected:
                draft.date != null && dateOnly(draft.date!) == bookable[i],
            onTap: () => notifier.setDate(bookable[i]),
          ),
        ),
      ),
      if (showErrors && draft.date == null) _error('Please pick a day.'),
      if (draft.date != null) ...[
        const SizedBox(height: AppSpace.lg),
        if (capacity.closed)
          const NoticeBox(
            icon: Icons.event_busy_outlined,
            warning: true,
            text: 'No bookings on this day. Please pick another day.',
          )
        else ...[
          if (noneFit)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpace.md),
              child: NoticeBox(
                icon: Icons.event_busy_outlined,
                warning: true,
                text: 'This day is full. Please pick another day.',
              ),
            ),
          for (final (label, icon, morning) in const [
            ('Morning', Icons.wb_twilight_rounded, true),
            ('Afternoon', Icons.wb_sunny_rounded, false),
          ]) ...[
            Row(children: [
              Icon(icon, size: 16, color: AppColors.textSubtle),
              const SizedBox(width: 6),
              Text(label, style: AppText.smallStrong),
            ]),
            const SizedBox(height: AppSpace.sm),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpace.sm,
              crossAxisSpacing: AppSpace.sm,
              childAspectRatio: 2.5,
              children: [
                for (final slot
                    in timeSlots.where((s) => s.isMorning == morning))
                  _SlotChip(
                    slot: slot,
                    state: states[slot.id]!,
                    durationMinutes: minutes,
                    selected: draft.slotId == slot.id,
                    onTap: () => notifier.setSlot(slot.id),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
          ],
        ],
        if (showErrors && !draft.scheduleDone)
          _error('Please pick an available slot.'),
      ],
    ]);
  }
}

class _DayChip extends StatelessWidget {
  final DateTime day, today;
  final bool selected;
  final VoidCallback onTap;
  const _DayChip(
      {required this.day,
      required this.today,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final diff = day.difference(today).inDays;
    final top = diff == 0
        ? 'Today'
        : diff == 1
            ? 'Tmrw'
            : weekdayShort(day);
    return Semantics(
      button: true,
      selected: selected,
      label: friendlyDate(day),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 62,
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 1.8 : 1),
          ),
          child: ExcludeSemantics(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(top,
                  style: AppText.caption.copyWith(
                      color: selected
                          ? AppColors.primaryDk
                          : AppColors.textSubtle)),
              Text('${day.day}',
                  style: AppText.h3.copyWith(
                      color: selected ? AppColors.primaryDk : AppColors.text)),
              Text(monthShort(day),
                  style: AppText.caption.copyWith(
                      color: selected
                          ? AppColors.primaryDk
                          : AppColors.textSubtle)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Price breakdown with coupon, kept short: one line per item.
class BillCard extends ConsumerWidget {
  final BookingDraft draft;
  final DraftNotifier notifier;
  const BillCard({super.key, required this.draft, required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = draft;
    final s = d.service;
    final wallet = ref.watch(walletProvider);
    final credit = d.cleanCreditDeduction(wallet.balance);
    final payable = d.payableTotal(wallet.balance);

    Widget row(String label, String value, {bool green = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
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

    return AppCard(
      child: Column(children: [
        row(
            s.name,
            '${rupees(d.servicePrice)}'
            '${s.priceSuffix.isEmpty ? '' : ' ${s.priceSuffix}'}'),
        for (final (e, q) in d.selectedExtras)
          row(q > 1 ? '${e.name} × $q' : e.name, rupees(e.price * q)),
        if (d.couponDiscount > 0)
          row('Coupon ${d.couponCode ?? ''}', '-${rupees(d.couponDiscount)}',
              green: true),
        if (credit > 0)
          row('CleanCredit Wallet Applied', '-${rupees(credit)}', green: true),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (ctx) => _CouponSheet(draft: d, notifier: notifier),
            ),
            icon: const Icon(Icons.local_offer_outlined, size: 18),
            label: Text(d.couponCode == null ? 'Add coupon' : 'Change coupon'),
          ),
        ),
        const Divider(height: AppSpace.lg),
        Row(children: [
          Expanded(child: Text('To pay', style: AppText.bodyStrong)),
          Text(rupees(payable), style: AppText.price),
        ]),
      ]),
    );
  }
}

class _SlotChip extends StatelessWidget {
  final TimeSlot slot;
  final WindowState state;
  final int durationMinutes;
  final bool selected;
  final VoidCallback onTap;
  const _SlotChip(
      {required this.slot,
      required this.state,
      this.durationMinutes = 0,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final open = state == WindowState.preference;
    final on = selected && open;
    final reason = switch (state) {
      WindowState.full => 'Fully booked',
      WindowState.tooLate => 'Too late for this service',
      WindowState.closedByTeam => 'Not available',
      WindowState.passed => 'Time passed',
      WindowState.preference => null,
    };
    return Semantics(
      button: open,
      selected: on,
      label: '${slot.short}${reason == null ? '' : ', $reason'}',
      child: GestureDetector(
        onTap: open
            ? () {
                HapticFeedback.selectionClick();
                onTap();
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: on
                ? AppColors.primarySoft
                : open
                    ? AppColors.surface
                    : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
                color: on
                    ? AppColors.primary
                    : open
                        ? AppColors.border
                        : Colors.transparent,
                width: on ? 1.8 : 1),
          ),
          child: ExcludeSemantics(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              FittedBox(
                child: Text(slot.short,
                    style: AppText.bodyStrong.copyWith(
                        color: on
                            ? AppColors.primaryDk
                            : open
                                ? AppColors.text
                                : AppColors.textSubtle)),
              ),
              if (reason != null)
                FittedBox(
                  child: Text(reason, style: AppText.caption.copyWith()),
                )
              else if (durationMinutes > 0)
                FittedBox(
                  child: Text(
                    readyByLabel(slot.startMinute, durationMinutes),
                    style: AppText.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: on ? AppColors.primaryDk : AppColors.primary,
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Coupons ───────────────────────────────────────────────────────────────────
// Offers come from lib/data/offers.dart, the same list the CleanCredit tab
// shows, so there is one place to add or stop a coupon.

/// Rupees [o] takes off this booking, after the 40% coupon cap.
int couponDiscountFor(Offer o, BookingDraft d) =>
    min(o.discountFor(d.total), d.maxCouponDiscount);

/// Why [o] can't be used on this booking right now, or null.
String? couponBlocker(Offer o, BookingDraft d, {required bool firstBooking}) =>
    o.whyNot(total: d.total, car: d.car, firstBooking: firstBooking);

class _CouponSheet extends ConsumerStatefulWidget {
  final BookingDraft draft;
  final DraftNotifier notifier;
  const _CouponSheet({required this.draft, required this.notifier});

  @override
  ConsumerState<_CouponSheet> createState() => _CouponSheetState();
}

class _CouponSheetState extends ConsumerState<_CouponSheet> {
  final _code = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  bool get _first => ref.read(myBookingsProvider).isEmpty;

  void _apply(Offer o) {
    final why = couponBlocker(o, widget.draft, firstBooking: _first);
    if (why != null) {
      setState(() => _error = why);
      return;
    }
    HapticFeedback.selectionClick();
    widget.notifier.applyCoupon(o.code, couponDiscountFor(o, widget.draft));
    Navigator.pop(context);
    showMessage(context,
        '${o.code} applied: ${rupees(couponDiscountFor(o, widget.draft))} off');
  }

  void _applyTyped() {
    final o = offerByCode(_code.text);
    if (o == null) {
      setState(() => _error = 'This code doesn\'t exist');
      return;
    }
    _apply(o);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final first = ref.watch(myBookingsProvider).isEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpace.page, 0, AppSpace.page,
          AppSpace.lg + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Coupons', style: AppText.h2),
              const SizedBox(height: AppSpace.md),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Semantics(
                    label: 'Coupon code',
                    textField: true,
                    child: TextField(
                      controller: _code,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (_) => setState(() => _error = null),
                      onSubmitted: (_) => _applyTyped(),
                      decoration: InputDecoration(
                        hintText: 'Have a code? Type it',
                        errorText: _error,
                        prefixIcon: const Icon(Icons.local_offer_outlined),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                SizedBox(
                  height: 54,
                  child: OutlinedButton(
                    onPressed: _code.text.trim().isEmpty ? null : _applyTyped,
                    child: const Text('Apply'),
                  ),
                ),
              ]),
              const SizedBox(height: AppSpace.lg),
              for (final o in kOffers) ...[
                OfferCard(
                  offer: o,
                  blockedReason: couponBlocker(o, d, firstBooking: first),
                  applied: d.couponCode == o.code,
                  actionLabel: d.couponCode == o.code ? 'Applied' : 'Apply',
                  onAction: () => _apply(o),
                ),
                const SizedBox(height: 10),
              ],
              if (d.couponCode != null)
                TextButton.icon(
                  onPressed: () {
                    widget.notifier.removeCoupon();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Remove coupon'),
                ),
            ]),
      ),
    );
  }
}
