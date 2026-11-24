import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../data/api/models.dart' show Coverage;
import '../core/theme.dart';
import '../data/business_info.dart';
import '../models/address.dart';
import '../models/booking.dart';
import '../providers/api_providers.dart';
import '../providers/app_providers.dart';
import '../screens/auth/login_screen.dart' show CarTypePicker;
import 'contact_actions.dart';
import 'ui.dart';

/// The customer's car and parking address are asked once (at onboarding)
/// and reused for every booking. These sheets change them from anywhere:
/// home, a service page or checkout.

// ── Address form ──────────────────────────────────────────────────────────────

/// Parking Bay + House no. + area + optional landmark, with a one-tap GPS pin.
/// Reports the composed address line ('' until house and area are filled).
class AddressForm extends ConsumerStatefulWidget {
  final String initialAddress;
  final String? initialPin;
  final void Function(String address, String? pin) onChanged;
  final bool autofocus;

  /// Start finding the GPS location as soon as the form opens
  /// ("Use my current location" in the address picker).
  final bool locateOnStart;

  const AddressForm({
    super.key,
    this.initialAddress = '',
    this.initialPin,
    required this.onChanged,
    this.autofocus = false,
    this.locateOnStart = false,
  });

  @override
  ConsumerState<AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends ConsumerState<AddressForm> {
  late final Map<String, TextEditingController> _c;
  late String? _pin = widget.initialPin;
  String _parkingType = 'Basement';
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    if (widget.locateOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _locate();
      });
    }
    final (parts, parking) = _split(widget.initialAddress);
    if (parking.toLowerCase().contains('open')) {
      _parkingType = 'Open Sky';
    } else if (parking.toLowerCase().contains('stilt')) {
      _parkingType = 'Stilt / Covered';
    } else {
      _parkingType = 'Basement';
    }
    _c = {
      for (final k in const ['flat', 'area', 'landmark'])
        k: TextEditingController(text: parts[k] ?? ''),
      'parking': TextEditingController(
          text: parking
              .replaceAll(
                  RegExp(r'^(Basement|Stilt|Open)[^·]*·?\s*',
                      caseSensitive: false),
                  '')
              .trim()),
    };
  }

  /// "B-12, Pocket 3, Janakpuri, near metro · parking: ..." → parts + parking.
  static (Map<String, String>, String) _split(String address) {
    final parking = parkingOf(address) ?? '';
    final parts = withParking(address, null)
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return (const {}, parking);
    String? landmark;
    if (parts.length > 1 && parts.last.toLowerCase().startsWith('near ')) {
      landmark = parts.removeLast().substring(5).trim();
    }
    return (
      {
        'flat': parts.first,
        if (parts.length > 1) 'area': parts.skip(1).join(', '),
        if (landmark != null) 'landmark': landmark,
      },
      parking
    );
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit() {
    final base = composeAddress({
      'flat': _c['flat']?.text ?? '',
      'area': _c['area']?.text ?? '',
      'landmark': _c['landmark']?.text ?? '',
    });
    final pText = _c['parking']?.text.trim() ?? '';
    final fullParking = _parkingType == 'Open Sky'
        ? (pText.isEmpty ? 'Open Driveway' : 'Open Driveway · $pText')
        : (_parkingType == 'Stilt / Covered'
            ? (pText.isEmpty ? 'Stilt Covered' : 'Stilt Covered · $pText')
            : (pText.isEmpty
                ? 'Basement Covered'
                : 'Basement Covered · $pText'));
    final full = withParking(base, fullParking);
    widget.onChanged(full, _pin);
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) showMessage(context, 'Turn on location, or type it in.');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) {
          showMessage(context, 'Location is off. You can type the address.');
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      setState(() => _pin =
          '${pos.latitude.toStringAsFixed(5)},${pos.longitude.toStringAsFixed(5)}');
      _emit();
    } catch (_) {
      if (mounted) showMessage(context, 'Couldn\'t find you. Type it in.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Widget _field(String key, String label, IconData icon,
          {String? hint, bool last = false, bool autofocus = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.md),
        child: Semantics(
          label: label,
          textField: true,
          child: TextField(
            controller: _c[key],
            autofocus: autofocus,
            onChanged: (_) => _emit(),
            textCapitalization: TextCapitalization.words,
            textInputAction: last ? TextInputAction.done : TextInputAction.next,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              prefixIcon: Icon(icon),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AppCard(
        selected: _pin != null,
        padding: const EdgeInsets.all(AppSpace.md),
        onTap: _locating ? null : _locate,
        child: Row(children: [
          SizedBox(
            width: 40,
            height: 40,
            child: _locating
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(strokeWidth: 2.4))
                : Icon(
                    _pin == null
                        ? Icons.my_location_rounded
                        : Icons.where_to_vote_rounded,
                    color: AppColors.primary),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  _pin == null
                      ? 'Pin my location (optional)'
                      : 'Location pinned on map',
                  style: AppText.bodyStrong.copyWith(color: AppColors.primary)),
              Text(
                  _pin == null
                      ? 'Helps the expert find your car'
                      : 'Now add the house details below',
                  style: AppText.caption),
            ]),
          ),
          if (_pin != null)
            IconButton(
              tooltip: 'Remove pin',
              onPressed: () {
                setState(() => _pin = null);
                _emit();
              },
              icon: const Icon(Icons.close_rounded,
                  size: 20, color: AppColors.textSubtle),
            ),
        ]),
      ),
      const SizedBox(height: AppSpace.lg),
      Text('Where is your car parked?', style: AppText.smallStrong),
      const SizedBox(height: 8),
      Row(children: [
        for (final (label, icon) in const [
          ('Basement', Icons.garage_rounded),
          ('Stilt / Covered', Icons.roofing_rounded),
          ('Open Sky', Icons.wb_sunny_outlined),
        ])
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                onTap: () {
                  setState(() => _parkingType = label);
                  _emit();
                },
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _parkingType == label
                        ? AppColors.primarySoft
                        : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: _parkingType == label
                          ? AppColors.primary
                          : AppColors.border,
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(icon,
                          size: 18,
                          color: _parkingType == label
                              ? AppColors.primary
                              : AppColors.textSubtle),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: AppText.caption.copyWith(
                          fontWeight: _parkingType == label
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _parkingType == label
                              ? AppColors.primaryDk
                              : AppColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 12),
      _field('parking', 'Pillar / Bay No. / Floor', Icons.local_parking_rounded,
          hint: 'e.g. Basement 2, Pillar B-42'),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded,
                size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Water tap & electricity plug accessible near parking (our team brings 30m wires & pipes)',
                style: AppText.caption.copyWith(
                  color: AppColors.primaryDk,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Text('Apartment & Society Details', style: AppText.smallStrong),
      const SizedBox(height: 8),
      _field('area', 'Area / society', Icons.apartment_rounded,
          hint: 'e.g. DLF Phase 5, Gurugram'),
      _field('flat', 'House / flat no.', Icons.home_outlined,
          hint: 'e.g. Tower 3, Flat 402', autofocus: widget.autofocus),
      _field(
          'landmark', 'Nearby Gate / Landmark (optional)', Icons.place_outlined,
          hint: 'e.g. near gate 2 entry', last: true),
      const SizedBox(height: 4),
      _CoverageHint(
        coverage: ref.watch(coverageProvider(coverageKey(
                    [_c['area']?.text ?? '', _c['landmark']?.text ?? ''].join(' '),
                    _pin))).valueOrNull ??
            Coverage.unverified,
      ),
    ]);
  }
}

/// Do we serve this spot? Shown while the address is entered, so nobody
/// finds out only after picking a service and a slot.
class _CoverageHint extends StatelessWidget {
  final Coverage coverage;
  const _CoverageHint({required this.coverage});

  @override
  Widget build(BuildContext context) {
    switch (coverage) {
      case Coverage.covered:
        return const NoticeBox(
            icon: Icons.check_circle_outline_rounded,
            text: 'Great, we serve this spot.');
      case Coverage.notCovered:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const NoticeBox(
            icon: Icons.wrong_location_outlined,
            warning: true,
            text: 'We don\'t serve this spot yet. You can still look around.',
          ),
          TextButton.icon(
            onPressed: () => openWhatsApp(context,
                message: 'Hi CleanCruisers, do you serve my area?'),
            icon: const Icon(Icons.chat_outlined, size: 18),
            label: const Text('Ask us on WhatsApp'),
          ),
        ]);
      case Coverage.unverified:
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.map_outlined, size: 16, color: AppColors.textSubtle),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
                'We serve ${kServiceAreas.take(5).join(', ')} and nearby '
                'areas in $kCityLabel.',
                style: AppText.caption),
          ),
        ]);
    }
  }
}

// ── Sheets ────────────────────────────────────────────────────────────────────

Future<void> _sheet(BuildContext context,
        {required String title,
        String? subtitle,
        required WidgetBuilder body}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(AppSpace.page, 0, AppSpace.page,
            AppSpace.lg + MediaQuery.viewInsetsOf(ctx).bottom),
        child: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: AppText.h2),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle, style: AppText.small),
                ],
                const SizedBox(height: AppSpace.lg),
                body(ctx),
              ]),
        ),
      ),
    );

/// Pick the car type and model.
Future<void> showCarSheet(BuildContext context, WidgetRef ref) {
  final p = ref.read(profileProvider);
  var car = p.car;
  final model = TextEditingController(text: p.carModel);
  return _sheet(
    context,
    title: 'Which car is it?',
    subtitle: 'Prices depend on the size of your car.',
    body: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CarTypePicker(
            selected: car,
            onChanged: (c) => setState(() => car = c),
          ),
          const SizedBox(height: AppSpace.md),
          TextField(
            controller: model,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Model and colour (optional)',
              hintText: 'e.g. White Brezza',
              prefixIcon: Icon(Icons.directions_car_outlined),
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          PrimaryButton(
            label: 'Save',
            onPressed: car == null
                ? null
                : () async {
                    await ref.read(profileProvider.notifier).save(p.copyWith(
                          car: car,
                          carModel: model.text.trim(),
                        ));
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
          ),
        ],
      ),
    ),
  );
}

// ── Saved addresses (Zomato / Blinkit style) ────────────────────────────────

/// Do we serve [a]? The server decides from the map pin or the pincode;
/// until it answers (or offline), an address naming a served area counts as
/// served, anything else "We'll check".
Coverage addressCoverage(WidgetRef ref, SavedAddress a) {
  final server =
      ref.watch(coverageProvider(coverageKey(a.address, a.pin))).valueOrNull;
  if (server != null && server != Coverage.unverified) return server;
  final text = a.address.toLowerCase();
  return kServiceAreas.any((n) => text.contains(n.toLowerCase()))
      ? Coverage.covered
      : Coverage.unverified;
}

/// Small availability badge: We serve here / Not here yet / We'll check.
class CoverageChip extends StatelessWidget {
  final Coverage coverage;
  const CoverageChip(this.coverage, {super.key});

  @override
  Widget build(BuildContext context) {
    final (icon, label, fg, bg) = switch (coverage) {
      Coverage.covered => (
          Icons.check_circle_rounded,
          'We serve here',
          AppColors.primaryDk,
          AppColors.primarySoft
        ),
      Coverage.notCovered => (
          Icons.do_not_disturb_on_rounded,
          'Not here yet',
          AppColors.warning,
          AppColors.warningSoft
        ),
      Coverage.unverified => (
          Icons.help_outline_rounded,
          'We\'ll check',
          AppColors.textMuted,
          AppColors.surfaceAlt
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: fg),
        const SizedBox(width: 4),
        Text(label,
            style: AppText.caption
                .copyWith(color: fg, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// "Where's your car?" (v3): current location, saved addresses with
/// coverage, add new, and a link to edit saved ones. An address we don't
/// cover can't be picked; the sheet says why instead.
/// Every place that changes the address opens this.
Future<void> showAddressSheet(BuildContext context, WidgetRef ref) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _AddressPicker(
        onAdd: ({bool locate = false}) {
          Navigator.pop(ctx);
          showAddressForm(context, ref, locate: locate);
        },
        onManage: () {
          Navigator.pop(ctx);
          GoRouter.of(context).push('/addresses');
        },
      ),
    );

class _AddressPicker extends ConsumerStatefulWidget {
  final void Function({bool locate}) onAdd;
  final VoidCallback onManage;
  const _AddressPicker({required this.onAdd, required this.onManage});

  @override
  ConsumerState<_AddressPicker> createState() => _AddressPickerState();
}

class _AddressPickerState extends ConsumerState<_AddressPicker> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    final book = ref.watch(addressBookProvider);
    final selected = book.selected?.id;
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
            AppSpace.page, 0, AppSpace.page, AppSpace.xxl),
        children: [
          Text('Where\'s your car?', style: AppText.h2),
          if (book.items.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('For new bookings. A booked wash keeps its own address.',
                style: AppText.small),
          ],
          const SizedBox(height: AppSpace.lg),
          AppCard(
            color: AppColors.primarySoft,
            onTap: () => widget.onAdd(locate: true),
            padding: const EdgeInsets.all(AppSpace.md),
            child: Row(children: [
              const Icon(Icons.my_location_rounded, color: AppColors.primary),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Text('Use my current location',
                    style: AppText.bodyStrong
                        .copyWith(color: AppColors.primaryDk)),
              ),
            ]),
          ),
          if (book.items.isNotEmpty) ...[
            const SizedBox(height: AppSpace.lg),
            Text('SAVED', style: AppText.overline),
            const SizedBox(height: AppSpace.sm),
            for (final a in book.items) ...[
              _AddressTile(
                address: a,
                selected: a.id == selected,
                coverage: addressCoverage(ref, a),
                onTap: () async {
                  if (addressCoverage(ref, a) == Coverage.notCovered) {
                    setState(() => _error =
                        'We don\'t wash cars at ${addressLabelNames[a.label]} '
                            'yet. Pick another address.');
                    return;
                  }
                  await ref.read(addressBookProvider.notifier).select(a.id);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              const SizedBox(height: AppSpace.sm),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.sm),
                child: Text(_error!,
                    style: AppText.small.copyWith(
                        color: AppColors.warning, fontWeight: FontWeight.w700)),
              ),
          ],
          const SizedBox(height: AppSpace.sm),
          OutlinedButton.icon(
            onPressed: () => widget.onAdd(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add a new address'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: Color(0xFFB9C2BC), width: 1.5),
              textStyle: AppText.bodyStrong,
            ),
          ),
          if (book.items.isNotEmpty)
            TextButton(
              onPressed: widget.onManage,
              style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
              child: const Text('Edit saved addresses'),
            ),
        ],
      ),
    );
  }
}

/// A saved address as a radio card with its coverage.
class _AddressTile extends StatelessWidget {
  final SavedAddress address;
  final bool selected;
  final Coverage coverage;
  final VoidCallback onTap;
  const _AddressTile({
    required this.address,
    required this.selected,
    required this.coverage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final a = address;
    return Semantics(
      button: true,
      selected: selected,
      label: '${addressLabelNames[a.label]}, ${withParking(a.address, null)}',
      child: ExcludeSemantics(
        child: AppCard(
          selected: selected,
          color: AppColors.surface,
          onTap: onTap,
          padding: const EdgeInsets.all(AppSpace.md),
          child: Row(children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.primary : null,
                border: Border.all(
                    color:
                        selected ? AppColors.primary : const Color(0xFFB9C2BC),
                    width: 2),
              ),
              child: selected
                  ? Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle))
                  : null,
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(addressLabelNames[a.label]!, style: AppText.title),
                    Text(withParking(a.address, null),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.small),
                  ]),
            ),
            const SizedBox(width: AppSpace.sm),
            CoverageChip(coverage),
          ]),
        ),
      ),
    );
  }
}

/// Add a new address (optionally starting from the GPS location), or edit
/// a saved one. Saving selects it.
Future<void> showAddressForm(BuildContext context, WidgetRef ref,
    {SavedAddress? existing, bool locate = false}) {
  final taken = {for (final a in ref.read(addressBookProvider).items) a.label};
  var label = existing?.label ??
      (!taken.contains(AddressLabel.home)
          ? AddressLabel.home
          : !taken.contains(AddressLabel.work)
              ? AddressLabel.work
              : AddressLabel.other);
  var address = existing?.address ?? '';
  var pin = existing?.pin;
  return _sheet(
    context,
    title: existing == null ? 'Add address' : 'Edit address',
    subtitle: existing == null
        ? null
        : 'Saving changes your next bookings. A wash you have already '
            'booked keeps the address it was booked with.',
    body: (ctx) => StatefulBuilder(
      builder: (ctx, setState) =>
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: AppSpace.sm, children: [
          for (final l in AddressLabel.values)
            ChoiceChip(
              avatar: Icon(addressLabelIcons[l],
                  size: 18,
                  color: l == label ? Colors.white : AppColors.textMuted),
              label: Text(addressLabelNames[l]!),
              selected: l == label,
              showCheckmark: false,
              selectedColor: AppColors.ink,
              backgroundColor: AppColors.surface,
              side: BorderSide(
                  color: l == label ? AppColors.ink : AppColors.border),
              labelStyle: AppText.smallStrong
                  .copyWith(color: l == label ? Colors.white : AppColors.text),
              onSelected: (_) => setState(() => label = l),
            ),
        ]),
        const SizedBox(height: AppSpace.lg),
        AddressForm(
          initialAddress: existing?.address ?? '',
          initialPin: existing?.pin,
          locateOnStart: locate,
          onChanged: (a, pn) => setState(() {
            address = a;
            pin = pn;
          }),
        ),
        const SizedBox(height: AppSpace.md),
        PrimaryButton(
          label: 'Save address',
          onPressed: address.isEmpty
              ? null
              : () async {
                  await ref
                      .read(addressBookProvider.notifier)
                      .save(SavedAddress(
                        id: existing?.id ??
                            DateTime.now().microsecondsSinceEpoch.toString(),
                        label: label,
                        address: address,
                        pin: pin,
                      ));
                  if (ctx.mounted) Navigator.pop(ctx);
                },
        ),
      ]),
    ),
  );
}
