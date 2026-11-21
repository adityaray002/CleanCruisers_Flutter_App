import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format.dart';
import '../../core/pricing.dart';
import '../../core/scheduling.dart' show clockLabel;
import '../../core/theme.dart';
import '../../data/api/models.dart';
import '../../data/business_info.dart';
import '../../models/service.dart';
import '../../providers/api_providers.dart';
import '../../providers/app_providers.dart';
import '../../providers/booking_providers.dart';
import '../../widgets/offer_card.dart';
import '../../widgets/service_widgets.dart';
import '../../widgets/ui.dart';

/// Pieces of the three-step booking (see booking_flow_screen.dart). Prices,
/// start times and the bill come from the server.

Widget _error(String text) => Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child:
          Text(text, style: AppText.caption.copyWith(color: AppColors.error)),
    );

// ── Service being booked ──────────────────────────────────────────────────────
/// Photo, name, how long it takes, and the price for the customer's car.
class BookingItemCard extends StatelessWidget {
  final CarService display;
  final CatalogService service;
  final CarType? car;
  const BookingItemCard(
      {super.key, required this.display, required this.service, this.car});

  @override
  Widget build(BuildContext context) {
    final s = display;
    final from = service.prices.values.reduce((a, b) => a < b ? a : b);
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
            Text(s.listName,
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
        Text(rupees(car == null ? from : service.priceFor(car!)),
            style: AppText.bodyStrong),
      ]),
    );
  }
}

// ── Add-ons: one list, a stepper for per-seat extras, a tick for the rest ──
class AddOnStrip extends StatelessWidget {
  final CatalogService service;
  final RequestDraft draft;
  final RequestDraftNotifier notifier;
  const AddOnStrip(
      {super.key,
      required this.service,
      required this.draft,
      required this.notifier});

  @override
  Widget build(BuildContext context) {
    final extras = service.extras;
    return AppCard(
      radius: AppRadius.lg,
      padding: EdgeInsets.zero,
      child: Column(children: [
        for (var i = 0; i < extras.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          _ExtraRow(
            extra: extras[i],
            qty: draft.extras[extras[i].id] ?? 0,
            onChanged: (q) => notifier.setExtra(extras[i].id, q),
          ),
        ],
      ]),
    );
  }
}

class _ExtraRow extends StatelessWidget {
  final CatalogExtra extra;
  final int qty;
  final ValueChanged<int> onChanged;
  const _ExtraRow(
      {required this.extra, required this.qty, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final on = qty > 0;
    final price = '${rupees(extra.price)}'
        '${extra.unit != null ? ' per ${extra.unit}' : ''}'
        '${extra.maxQty > 1 ? ' · up to ${extra.maxQty}' : ''}';
    final text = Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(extra.name, style: AppText.title),
        const SizedBox(height: 2),
        Text(extra.maxQty > 1 ? price : '+$price', style: AppText.small),
      ]),
    );

    if (extra.maxQty > 1) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.lg, AppSpace.md, AppSpace.md, AppSpace.md),
        child: Row(children: [
          text,
          const SizedBox(width: AppSpace.sm),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _Step(Icons.remove_rounded, 'One ${extra.unit ?? ''} less',
                  qty > 0 ? () => onChanged(qty - 1) : null,
                  filled: false),
              Semantics(
                liveRegion: true,
                label: '$qty ${extra.unit ?? ''}${qty == 1 ? '' : 's'}',
                child: ExcludeSemantics(
                  child: SizedBox(
                    width: 30,
                    child: Text('$qty',
                        textAlign: TextAlign.center, style: AppText.bodyStrong),
                  ),
                ),
              ),
              _Step(Icons.add_rounded, 'One ${extra.unit ?? ''} more',
                  qty < extra.maxQty ? () => onChanged(qty + 1) : null),
            ]),
          ),
        ]),
      );
    }

    return Semantics(
      button: true,
      selected: on,
      label: '${extra.name}, +${rupees(extra.price)}',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(on ? 0 : 1);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.lg, vertical: AppSpace.md),
            child: Row(children: [
              text,
              const SizedBox(width: AppSpace.sm),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: on ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: on ? AppColors.primary : const Color(0xFFB9C2BC),
                      width: 2),
                ),
                child: on
                    ? const Icon(Icons.check_rounded,
                        size: 16, color: Colors.white)
                    : null,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool filled;
  const _Step(this.icon, this.tooltip, this.onTap, {this.filled = true});

  @override
  Widget build(BuildContext context) {
    final bg = filled ? AppColors.primary : AppColors.surfaceAlt;
    final fg = filled ? Colors.white : AppColors.text;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: onTap == null ? AppColors.surfaceAlt : bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon,
                size: 20, color: onTap == null ? AppColors.textSubtle : fg),
          ),
        ),
      ),
    );
  }
}

// ── Time picker ───────────────────────────────────────────────────────────────
/// Days in a row, then the start times the server says are open that day.
/// A start time shows when the expert arrives and when the car is ready.
class SlotPicker extends ConsumerWidget {
  /// The service whose time is booked (for a plan: the plan's wash).
  final String serviceId;
  final RequestDraft draft;
  final RequestDraftNotifier notifier;
  final int windowDays;
  final bool showErrors;

  const SlotPicker({
    super.key,
    required this.serviceId,
    required this.draft,
    required this.notifier,
    required this.windowDays,
    required this.showErrors,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = dateOnly(DateTime.now());
    final days = [for (var i = 0; i < windowDays; i++) addDays(today, i)];
    final date = draft.date;
    final car = draft.car;

    Widget times() {
      if (date == null || car == null) return const SizedBox.shrink();
      final key = (serviceId, car, draft.extrasKey, dateKey(date));
      final async = ref.watch(availabilityProvider(key));
      return async.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpace.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Column(children: [
          NoticeBox(
            icon: Icons.wifi_off_rounded,
            warning: true,
            text: e is ApiException
                ? e.message
                : 'Couldn\'t load the times. Check your connection.',
          ),
          TextButton(
            onPressed: () => ref.invalidate(availabilityProvider(key)),
            child: const Text('Try again'),
          ),
        ]),
        data: (a) {
          if (a.closedReason != null) {
            return NoticeBox(
                icon: Icons.event_busy_outlined,
                warning: true,
                text: '${a.closedReason}. Please pick another day.');
          }
          final open = a.openSlots;
          if (open.isEmpty) {
            return NoticeBox(
              icon: Icons.event_busy_outlined,
              warning: true,
              text: dateOnly(date) == today
                  ? 'No times left today. Please pick another day.'
                  : 'This day is full. Please pick another day.',
            );
          }
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (label, icon, morning) in const [
                  ('Morning', Icons.wb_twilight_rounded, true),
                  ('Afternoon', Icons.wb_sunny_rounded, false),
                ])
                  if (open.any((s) => (s.start < 12 * 60) == morning)) ...[
                    Row(children: [
                      Icon(icon, size: 16, color: AppColors.textSubtle),
                      const SizedBox(width: 6),
                      Text(label, style: AppText.smallStrong),
                    ]),
                    const SizedBox(height: AppSpace.sm),
                    LayoutBuilder(builder: (context, c) {
                      const gap = AppSpace.sm;
                      final w = (c.maxWidth - gap * 2) / 3;
                      return Wrap(spacing: gap, runSpacing: gap, children: [
                        for (final s in open
                            .where((s) => (s.start < 12 * 60) == morning))
                          SizedBox(
                            width: w,
                            child: _TimeChip(
                              slot: s,
                              selected: draft.start == s.start,
                              onTap: () => notifier.setTime(date, s.start),
                            ),
                          ),
                      ]);
                    }),
                    const SizedBox(height: AppSpace.md),
                  ],
              ]);
        },
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 78,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: days.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpace.sm),
          itemBuilder: (_, i) => _DayChip(
            day: days[i],
            today: today,
            selected: date != null && dateOnly(date) == days[i],
            onTap: () => notifier.setDate(days[i]),
          ),
        ),
      ),
      if (showErrors && date == null) _error('Please pick a day.'),
      if (date != null) ...[
        const SizedBox(height: AppSpace.lg),
        times(),
        if (showErrors && !draft.timePicked) _error('Please pick a time.'),
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
            color: selected ? AppColors.ink : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border:
                Border.all(color: selected ? AppColors.ink : AppColors.border),
          ),
          child: ExcludeSemantics(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(top,
                  style: AppText.caption.copyWith(
                      color: selected
                          ? const Color(0xFFB8C0C7)
                          : AppColors.textSubtle)),
              Text('${day.day}',
                  style: AppText.h3.copyWith(
                      color: selected ? Colors.white : AppColors.text)),
              Text(monthShort(day),
                  style: AppText.caption.copyWith(
                      color: selected
                          ? const Color(0xFFB8C0C7)
                          : AppColors.textSubtle)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// "9:30 AM" (when the expert arrives) and "ready ~11:30" underneath.
class _TimeChip extends StatelessWidget {
  final Slot slot;
  final bool selected;
  final VoidCallback onTap;
  const _TimeChip(
      {required this.slot, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Expert arrives ${clockLabel(slot.start)}, '
          'car ready by about ${clockLabel(slot.end)}',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.border),
          ),
          child: ExcludeSemantics(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(clockLabel(slot.start),
                  textAlign: TextAlign.center,
                  style: AppText.bodyStrong.copyWith(
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : AppColors.text)),
              // "ready ~1:30": short enough for one line on small phones;
              // the full time is in the accessible label.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('ready ~${clockLabel(slot.end).split(' ').first}',
                    maxLines: 1,
                    style: AppText.caption.copyWith(
                        color: selected ? Colors.white : AppColors.primary)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Bill ──────────────────────────────────────────────────────────────────────
/// The server's bill: one line per item and discount, GST, and the total.
class BillCard extends ConsumerWidget {
  final AsyncValue<Quote> quote;
  final RequestDraft draft;
  final RequestDraftNotifier notifier;
  final VoidCallback onRetry;
  const BillCard({
    super.key,
    required this.quote,
    required this.draft,
    required this.notifier,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(meProvider).valueOrNull?.walletBalance ?? 0;

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

    String discountLabel(BillDiscount d) => switch (d.kind) {
          'coupon' => 'Coupon ${d.code ?? ''}',
          'credit' => 'CleanCredit',
          'plan' => d.name ?? 'Plan visit',
          _ => d.name ?? 'Offer',
        };

    final body = quote.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpace.lg),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Column(children: [
        Text(
            e is ApiException
                ? e.message
                : 'Couldn\'t get the price. Check your connection.',
            style: AppText.small.copyWith(color: AppColors.error)),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ]),
      data: (q) {
        final b = q.bill;
        return Column(children: [
          for (final i in b.items)
            row(i.qty > 1 ? '${i.name} × ${i.qty}' : i.name, rupees(i.amount)),
          for (final d in b.discounts)
            row(discountLabel(d), '-${rupees(d.amount)}', green: true),
          if (b.lateCancelFee > 0)
            row('Late cancellation fee (earlier booking)',
                rupees(b.lateCancelFee)),
          if (b.discountCapNote != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(b.discountCapNote!, style: AppText.caption),
              ),
            ),
          const Divider(height: AppSpace.lg),
          Row(children: [
            Expanded(
                child: Text(
                    kPayAfterService ? 'To pay after the service' : 'To pay',
                    style: AppText.bodyStrong)),
            Text(rupees(b.total), style: AppText.price),
          ]),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
                'Includes GST ${rupees(b.gst.cgst + b.gst.sgst)} '
                '(${b.gst.rate}%)',
                style: AppText.caption),
          ),
        ]);
      },
    );

    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        body,
        const SizedBox(height: AppSpace.sm),
        // Plan visits are already paid: no coupon or credit.
        if (draft.planId == null)
          Wrap(
            spacing: AppSpace.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero, minimumSize: const Size(0, 44)),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (ctx) =>
                      CouponSheet(draft: draft, notifier: notifier),
                ),
                icon: const Icon(Icons.local_offer_outlined, size: 18),
                label: Text(
                    draft.couponCode == null ? 'Add coupon' : 'Change coupon'),
              ),
              if (balance > 0)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Use CleanCredit (${rupees(balance)})',
                      style: AppText.small.copyWith(color: AppColors.text)),
                  Switch(
                    value: draft.useCredit,
                    onChanged: notifier.setUseCredit,
                  ),
                ]),
            ],
          ),
      ]),
    );
  }
}

// ── Coupons ───────────────────────────────────────────────────────────────────
/// Offers from the server. "Apply" asks the server whether this booking
/// qualifies; if not, the reason shows under the field.
class CouponSheet extends ConsumerStatefulWidget {
  final RequestDraft draft;
  final RequestDraftNotifier notifier;
  const CouponSheet({super.key, required this.draft, required this.notifier});

  @override
  ConsumerState<CouponSheet> createState() => _CouponSheetState();
}

class _CouponSheetState extends ConsumerState<CouponSheet> {
  final _code = TextEditingController();
  String? _error;
  String? _checking;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _apply(String raw) async {
    final code = raw.trim().toUpperCase();
    if (code.isEmpty || _checking != null) return;
    final address = apiAddressOf(ref.read(profileProvider));
    final request = widget.draft.copyWith(couponCode: code).request(address);
    if (request == null) {
      setState(() => _error = 'Pick a time first');
      return;
    }
    setState(() {
      _checking = code;
      _error = null;
    });
    try {
      final q = await ref.read(apiProvider).quote(request);
      if (!mounted) return;
      if (!q.couponApplied) {
        setState(() => _error = q.couponReason ?? 'This code can’t be used');
        return;
      }
      HapticFeedback.selectionClick();
      widget.notifier.setCoupon(code);
      Navigator.pop(context);
      showMessage(
          context, '$code applied: ${rupees(q.bill.discountOf('coupon'))} off');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Object {
      if (mounted) {
        setState(() => _error = 'Couldn\'t check the code. Try again.');
      }
    } finally {
      if (mounted) setState(() => _checking = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final offers = ref.watch(publicOffersProvider).valueOrNull ?? const [];
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
                      onSubmitted: _apply,
                      decoration: InputDecoration(
                        hintText: 'Have a code? Type it',
                        errorText: _error,
                        errorMaxLines: 2,
                        prefixIcon: const Icon(Icons.local_offer_outlined),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                SizedBox(
                  height: 54,
                  child: OutlinedButton(
                    onPressed: _code.text.trim().isEmpty || _checking != null
                        ? null
                        : () => _apply(_code.text),
                    child: const Text('Apply'),
                  ),
                ),
              ]),
              const SizedBox(height: AppSpace.lg),
              for (final o in offers) ...[
                OfferCard.public(
                  offer: o,
                  applied: d.couponCode == o.code,
                  actionLabel: d.couponCode == o.code
                      ? 'Applied'
                      : _checking == o.code
                          ? 'Checking…'
                          : 'Apply',
                  onAction: () => _apply(o.code),
                ),
                const SizedBox(height: 10),
              ],
              if (d.couponCode != null)
                TextButton.icon(
                  onPressed: () {
                    widget.notifier.setCoupon(null);
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
