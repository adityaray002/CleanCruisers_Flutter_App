import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/format.dart';
import '../../core/pricing.dart';
import '../../core/theme.dart';
import '../../data/business_info.dart';
import '../../models/booking.dart';
import '../../models/service.dart';
import '../../providers/app_providers.dart';
import '../../widgets/ui.dart';
import 'booking_flow_screen.dart';

class _StepScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  const _StepScaffold(
      {required this.title, this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpace.page, 8, AppSpace.page, 32),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Semantics(header: true, child: Text(title, style: AppText.h1)),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: AppText.body),
        ],
        const SizedBox(height: 22),
        ...children,
      ],
    );
  }
}

Widget _fieldLabel(String text,
        {bool optional = false, bool forField = false}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ExcludeSemantics(
        excluding: forField,
        child: Text.rich(TextSpan(children: [
          TextSpan(text: text, style: AppText.smallStrong),
          if (optional) TextSpan(text: '  Optional', style: AppText.caption),
        ])),
      ),
    );

/// Gives a text field the same accessible name as its visible label.
Widget _labelled(String label, Widget field) =>
    Semantics(label: label, textField: true, child: field);

// ── Step 1: Car ───────────────────────────────────────────────────────────────
class CarStep extends StatefulWidget {
  final BookingDraft draft;
  final DraftNotifier notifier;
  final bool showErrors;
  const CarStep(
      {super.key,
      required this.draft,
      required this.notifier,
      required this.showErrors});

  @override
  State<CarStep> createState() => _CarStepState();
}

class _CarStepState extends State<CarStep> {
  late final _model = TextEditingController(text: widget.draft.carModel);

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final s = d.service;
    final error = widget.showErrors && d.car == null;
    return _StepScaffold(
      title: 'Which car is it?',
      subtitle: 'Price depends on the size of your car.',
      children: [
        for (final car in CarType.values) ...[
          AppCard(
            selected: d.car == car,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            onTap: () => widget.notifier.setCar(car),
            child: Row(children: [
              _Radio(selected: d.car == car),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(carTypeNames[car]!, style: AppText.bodyStrong),
                      Text('e.g. ${carTypeExamples[car]}',
                          style: AppText.caption),
                    ]),
              ),
              PriceText(s.priceFor(car), suffix: s.priceSuffix, size: 17),
            ]),
          ),
          const SizedBox(height: 10),
        ],
        if (error)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('Please select your car size.',
                style: AppText.caption.copyWith(color: AppColors.error)),
          ),
        const SizedBox(height: 14),
        _fieldLabel('Car make & model', optional: true, forField: true),
        _labelled(
            'Car make and model, optional',
            TextField(
              controller: _model,
              onChanged: widget.notifier.setCarModel,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: 'e.g. Maruti Swift, white',
                prefixIcon: Icon(Icons.directions_car_outlined),
              ),
            )),
        const SizedBox(height: 8),
        Text('Helps our team spot your car and bring the right products.',
            style: AppText.caption),
      ],
    );
  }
}

class _Radio extends StatelessWidget {
  final bool selected;
  const _Radio({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
            color: selected ? AppColors.primary : AppColors.textSubtle,
            width: selected ? 7 : 1.6),
      ),
    );
  }
}

// ── Step 2: Date & time ───────────────────────────────────────────────────────
class ScheduleStep extends StatelessWidget {
  final BookingDraft draft;
  final DraftNotifier notifier;
  final bool showErrors;
  const ScheduleStep(
      {super.key,
      required this.draft,
      required this.notifier,
      required this.showErrors});

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(DateTime.now());
    final days = [
      for (var i = 0; i < kBookingWindowDays; i++) today.add(Duration(days: i))
    ];
    // Skip today entirely if every slot has passed.
    final bookable =
        days.where((d) => timeSlots.any((s) => s.isAvailable(d))).toList();
    final monthly = draft.service.category == ServiceCategory.monthly;

    return _StepScaffold(
      title: monthly
          ? 'When should we do\nthe first wash?'
          : 'When should we come?',
      subtitle:
          'Pick your preferred slot. We\'ll confirm it with you on WhatsApp.',
      children: [
        _fieldLabel('Date'),
        SizedBox(
          height: 82,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: bookable.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final day = bookable[i];
              final selected =
                  draft.date != null && dateOnly(draft.date!) == day;
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
                    notifier.setDate(day);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 64,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.ink : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                          color: selected ? AppColors.ink : AppColors.border),
                    ),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(top,
                              style: AppText.caption.copyWith(
                                  color: selected
                                      ? Colors.white70
                                      : AppColors.textSubtle)),
                          const SizedBox(height: 2),
                          Text('${day.day}',
                              style: AppText.h2.copyWith(
                                  color: selected
                                      ? Colors.white
                                      : AppColors.text)),
                          Text(monthShort(day),
                              style: AppText.caption.copyWith(
                                  color: selected
                                      ? Colors.white70
                                      : AppColors.textSubtle)),
                        ]),
                  ),
                ),
              );
            },
          ),
        ),
        if (showErrors && draft.date == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Please pick a date.',
                style: AppText.caption.copyWith(color: AppColors.error)),
          ),
        const SizedBox(height: 26),
        _fieldLabel('Time'),
        if (draft.date == null)
          Text('Pick a date first to see available times.',
              style: AppText.small)
        else
          for (final slot in timeSlots) ...[
            _SlotTile(
              slot: slot,
              available: slot.isAvailable(draft.date!),
              selected: draft.slotId == slot.id,
              onTap: () => notifier.setSlot(slot.id),
            ),
            const SizedBox(height: 10),
          ],
        if (showErrors && draft.date != null && !draft.scheduleDone)
          Text('Please pick a time slot.',
              style: AppText.caption.copyWith(color: AppColors.error)),
        const SizedBox(height: 14),
        const NoticeBox(
          icon: Icons.info_outline_rounded,
          text:
              'Open $kHoursLabel, $kDaysLabel. Our team arrives within the slot you choose.',
        ),
      ],
    );
  }
}

class _SlotTile extends StatelessWidget {
  final TimeSlot slot;
  final bool available, selected;
  final VoidCallback onTap;
  const _SlotTile(
      {required this.slot,
      required this.available,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final icon = switch (slot.id) {
      'morning' => Icons.wb_twilight_rounded,
      'afternoon' => Icons.wb_sunny_outlined,
      _ => Icons.nights_stay_outlined,
    };
    return Opacity(
      opacity: available ? 1 : 0.5,
      child: AppCard(
        selected: selected,
        color: available ? null : AppColors.surfaceAlt,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        onTap: available ? onTap : null,
        child: Row(children: [
          Icon(icon, color: selected ? AppColors.primary : AppColors.textMuted),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(slot.name, style: AppText.bodyStrong),
              Text(slot.range, style: AppText.small),
            ]),
          ),
          if (!available)
            const Pill('Unavailable today')
          else
            _Radio(selected: selected),
        ]),
      ),
    );
  }
}

// ── Step 3: Contact & address ─────────────────────────────────────────────────
class DetailsStep extends StatefulWidget {
  final BookingDraft draft;
  final DraftNotifier notifier;
  final bool showErrors;
  final bool saveDetails;
  final ValueChanged<bool> onSaveDetailsChanged;

  const DetailsStep({
    super.key,
    required this.draft,
    required this.notifier,
    required this.showErrors,
    required this.saveDetails,
    required this.onSaveDetailsChanged,
  });

  @override
  State<DetailsStep> createState() => _DetailsStepState();
}

class _DetailsStepState extends State<DetailsStep> {
  late final _name = TextEditingController(text: widget.draft.name);
  late final _phone = TextEditingController(text: widget.draft.phone);
  late final _address = TextEditingController(text: widget.draft.address);
  final _touched = <String>{};
  bool _locating = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  bool _show(String f) => widget.showErrors || _touched.contains(f);

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          showMessage(context,
              'Turn on location on your phone, or just type your address.');
        }
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) {
          showMessage(
            context,
            'Location permission is off. You can still type your address.',
            action: perm == LocationPermission.deniedForever
                ? const SnackBarAction(
                    label: 'Settings', onPressed: Geolocator.openAppSettings)
                : null,
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      widget.notifier.setPin(
          '${pos.latitude.toStringAsFixed(5)},${pos.longitude.toStringAsFixed(5)}');
      if (mounted) {
        showMessage(context,
            'Location pin added. Please still enter your flat or house number.');
      }
    } catch (_) {
      if (mounted) {
        showMessage(
            context, 'Couldn\'t get your location. Please type your address.');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    return _StepScaffold(
      title: 'Where should we come?',
      subtitle: 'We\'ll use these details only for this booking.',
      children: [
        _fieldLabel('Full name', forField: true),
        _labelled(
            'Full name',
            TextField(
              controller: _name,
              onChanged: widget.notifier.setName,
              onEditingComplete: () {
                setState(() => _touched.add('name'));
                FocusScope.of(context).nextFocus();
              },
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              decoration: InputDecoration(
                hintText: 'e.g. Rahul Sharma',
                prefixIcon: const Icon(Icons.person_outline_rounded),
                errorText: _show('name') && !d.nameValid
                    ? 'Please enter your name'
                    : null,
              ),
            )),
        const SizedBox(height: 18),
        _fieldLabel('Mobile number', forField: true),
        _labelled(
            'Mobile number',
            TextField(
              controller: _phone,
              onChanged: (v) {
                widget.notifier.setPhone(v);
                if (v.length == 10) setState(() => _touched.add('phone'));
              },
              onEditingComplete: () {
                setState(() => _touched.add('phone'));
                FocusScope.of(context).nextFocus();
              },
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumberNational],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: InputDecoration(
                hintText: '10-digit mobile number',
                // Always visible, so people don't type the country code themselves.
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.phone_outlined),
                    const SizedBox(width: 8),
                    Text('+91',
                        style: AppText.body.copyWith(color: AppColors.text)),
                  ]),
                ),
                errorText: _show('phone') && !d.phoneValid
                    ? 'Enter a valid 10-digit Indian mobile number'
                    : null,
                helperText:
                    'Our team will call this number if they can\'t find you.',
                helperStyle: AppText.caption,
              ),
            )),
        const SizedBox(height: 18),
        _fieldLabel('Address', forField: true),
        _labelled(
            'Address',
            TextField(
              controller: _address,
              onChanged: widget.notifier.setAddress,
              onEditingComplete: () => setState(() => _touched.add('address')),
              textCapitalization: TextCapitalization.sentences,
              minLines: 2,
              maxLines: 4,
              autofillHints: const [AutofillHints.fullStreetAddress],
              decoration: InputDecoration(
                hintText:
                    'House / flat no., building or society, area, landmark',
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: Icon(Icons.home_outlined),
                ),
                errorText: _show('address') && !d.addressValid
                    ? 'Please enter your full address so our team can find you'
                    : null,
              ),
            )),
        const SizedBox(height: 10),
        if (d.pin == null)
          SecondaryButton(
            label: _locating
                ? 'Getting your location…'
                : 'Add my current location pin',
            icon: Icons.my_location_rounded,
            onPressed: _locating ? null : _locate,
          )
        else
          AppCard(
            color: AppColors.primarySoft,
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            child: Row(children: [
              const Icon(Icons.location_on_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Location pin added — shared as a map link',
                    style: AppText.small.copyWith(color: AppColors.primaryDk)),
              ),
              TextButton(
                  onPressed: () => widget.notifier.setPin(null),
                  child: const Text('Remove')),
            ]),
          ),
        const SizedBox(height: 18),
        CheckboxListTile(
          value: widget.saveDetails,
          onChanged: (v) => widget.onSaveDetailsChanged(v ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: AppColors.primary,
          title: Text('Remember these details for next time',
              style: AppText.small),
          subtitle: Text('Saved only on this phone.', style: AppText.caption),
        ),
      ],
    );
  }
}

// ── Step 4: Review ────────────────────────────────────────────────────────────
class ReviewStep extends StatelessWidget {
  final BookingDraft draft;
  final DraftNotifier notifier;
  final ValueChanged<BookingStep> onEdit;

  const ReviewStep(
      {super.key,
      required this.draft,
      required this.notifier,
      required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final d = draft;
    final s = d.service;
    return _StepScaffold(
      title: 'Review your booking',
      subtitle: 'Check everything before you send it.',
      children: [
        _ReviewCard(
          title: 'Service',
          onEdit: () => onEdit(BookingStep.car),
          rows: [
            (Icons.local_car_wash_outlined, s.name),
            (
              Icons.directions_car_outlined,
              d.carModel.trim().isEmpty
                  ? carTypeNames[d.car]!
                  : '${d.carModel.trim()} · ${carTypeNames[d.car]}'
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ReviewCard(
          title: 'When',
          onEdit: () => onEdit(BookingStep.schedule),
          rows: [
            (Icons.calendar_today_outlined, friendlyDate(d.date!)),
            (Icons.schedule_rounded, d.slot!.label),
          ],
        ),
        const SizedBox(height: 12),
        _ReviewCard(
          title: 'Where',
          onEdit: () => onEdit(BookingStep.details),
          rows: [
            (
              Icons.person_outline_rounded,
              '${d.name.trim()} · +91 ${d.phone.trim()}'
            ),
            (Icons.home_outlined, d.address.trim()),
            if (d.pin != null)
              (Icons.location_on_outlined, 'Location pin attached'),
          ],
        ),
        if (s.extras.isNotEmpty) ...[
          const SizedBox(height: 26),
          Text.rich(TextSpan(children: [
            TextSpan(text: 'Add extras', style: AppText.h3),
            TextSpan(text: '  Optional', style: AppText.caption),
          ])),
          const SizedBox(height: 10),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(children: [
              for (var i = 0; i < s.extras.length; i++) ...[
                if (i > 0) const Divider(),
                _ExtraRow(
                  extra: s.extras[i],
                  qty: d.extras[s.extras[i].id] ?? 0,
                  onChanged: (q) => notifier.setExtra(s.extras[i].id, q),
                ),
              ],
            ]),
          ),
        ],
        const SizedBox(height: 26),
        Text('Price', style: AppText.h3),
        const SizedBox(height: 10),
        AppCard(
          child: Column(children: [
            _priceLine('${s.name} (${carTypeNames[d.car]})', d.servicePrice,
                suffix: s.priceSuffix),
            for (final (e, q) in d.selectedExtras)
              _priceLine(q > 1 ? '${e.name} × $q' : e.name, e.price * q),
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
            Row(children: [
              Expanded(
                  child: Text('Estimated total', style: AppText.bodyStrong)),
              Text(rupees(d.total), style: AppText.price),
            ]),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                kPayAfterService
                    ? 'Pay the team after the service. Nothing to pay now.'
                    : 'Final amount confirmed on WhatsApp.',
                style: AppText.caption,
              ),
            ),
          ]),
        ),
        const SizedBox(height: 22),
        Text('What happens next', style: AppText.h3),
        const SizedBox(height: 10),
        const _NextSteps(),
      ],
    );
  }

  Widget _priceLine(String label, int amount, {String suffix = ''}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Text(label,
                  style: AppText.small.copyWith(color: AppColors.text))),
          const SizedBox(width: 12),
          Text('${rupees(amount)}${suffix.isEmpty ? '' : ' $suffix'}',
              style: AppText.smallStrong),
        ]),
      );
}

class _NextSteps extends StatelessWidget {
  const _NextSteps();

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        Icons.chat_outlined,
        'WhatsApp opens with your booking filled in. Tap Send.'
      ),
      (
        Icons.verified_outlined,
        'We reply to confirm your slot, usually within $kConfirmWithin.'
      ),
      (
        Icons.local_car_wash_outlined,
        'Our team arrives in your slot and cleans your car.'
      ),
    ];
    return AppCard(
      color: AppColors.surfaceAlt,
      child: Column(children: [
        for (final (icon, text) in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(text,
                      style: AppText.small.copyWith(color: AppColors.text))),
            ]),
          ),
      ]),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final String title;
  final VoidCallback onEdit;
  final List<(IconData, String)> rows;
  const _ReviewCard(
      {required this.title, required this.onEdit, required this.rows});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title.toUpperCase(), style: AppText.overline)),
          TextButton(
            onPressed: onEdit,
            child:
                Semantics(label: 'Change $title', child: const Text('Change')),
          ),
        ]),
        for (final (icon, text) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6, right: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, size: 18, color: AppColors.textSubtle),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(text,
                      style: AppText.body
                          .copyWith(color: AppColors.text, fontSize: 14.5))),
            ]),
          ),
      ]),
    );
  }
}

class _ExtraRow extends StatelessWidget {
  final Extra extra;
  final int qty;
  final ValueChanged<int> onChanged;
  const _ExtraRow(
      {required this.extra, required this.qty, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final price =
        '+${rupees(extra.price)}${extra.unit != null ? ' / ${extra.unit}' : ''}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(extra.name, style: AppText.smallStrong),
            Text(price, style: AppText.caption),
          ]),
        ),
        if (extra.maxQty == 1)
          Switch.adaptive(
            value: qty > 0,
            activeTrackColor: AppColors.primary,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v ? 1 : 0);
            },
          )
        else
          Row(children: [
            IconButton(
              tooltip: 'Remove one',
              onPressed: qty > 0 ? () => onChanged(qty - 1) : null,
              icon: const Icon(Icons.remove_circle_outline_rounded),
              color: AppColors.primary,
            ),
            SizedBox(
              width: 22,
              child: Text('$qty',
                  textAlign: TextAlign.center, style: AppText.bodyStrong),
            ),
            IconButton(
              tooltip: 'Add one',
              onPressed: qty < extra.maxQty ? () => onChanged(qty + 1) : null,
              icon: const Icon(Icons.add_circle_outline_rounded),
              color: AppColors.primary,
            ),
          ]),
      ]),
    );
  }
}
