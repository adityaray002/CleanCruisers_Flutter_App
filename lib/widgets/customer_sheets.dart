import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../core/scheduling.dart';
import '../core/theme.dart';
import '../data/business_info.dart';
import '../models/address.dart';
import '../models/booking.dart';
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
        coverage: checkCoverage(parsePin(_pin),
            ref.watch(serviceAreasProvider).valueOrNull ?? const []),
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
        {required String title, required WidgetBuilder body}) =>
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
    title: 'Your vehicle',
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
              hintText: 'Model & colour (optional), e.g. White Brezza',
              prefixIcon: Icon(Icons.directions_car_outlined),
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          PrimaryButton(
            label: 'Save vehicle',
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

/// Do we serve [a]? A map pin is checked against the service areas; without
/// one, an address naming a served area counts. Otherwise: "We'll check".
Coverage addressCoverage(SavedAddress a, List<ServiceArea> areas) {
  final byPin = checkCoverage(parsePin(a.pin), areas);
  if (byPin != Coverage.unverified) return byPin;
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

/// "Where's your car?" — saved addresses, current location, add new.
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
        onEdit: (a) {
          Navigator.pop(ctx);
          showAddressForm(context, ref, existing: a);
        },
      ),
    );

class _AddressPicker extends ConsumerWidget {
  final void Function({bool locate}) onAdd;
  final ValueChanged<SavedAddress> onEdit;
  const _AddressPicker({required this.onAdd, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(addressBookProvider);
    final areas = ref.watch(serviceAreasProvider).valueOrNull ?? const [];
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
          const SizedBox(height: AppSpace.md),
          _PickerAction(
            icon: Icons.my_location_rounded,
            label: 'Use my current location',
            onTap: () => onAdd(locate: true),
          ),
          _PickerAction(
            icon: Icons.add_rounded,
            label: 'Add a new address',
            onTap: () => onAdd(),
          ),
          if (book.items.isNotEmpty) ...[
            const SizedBox(height: AppSpace.lg),
            Text('Saved addresses',
                style:
                    AppText.smallStrong.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpace.sm),
            for (final a in book.items) ...[
              _AddressTile(
                address: a,
                selected: a.id == selected,
                coverage: addressCoverage(a, areas),
                onTap: () async {
                  await ref.read(addressBookProvider.notifier).select(a.id);
                  if (context.mounted) Navigator.pop(context);
                },
                onEdit: () => onEdit(a),
                onDelete: () =>
                    ref.read(addressBookProvider.notifier).remove(a.id),
              ),
              const SizedBox(height: AppSpace.sm),
            ],
          ],
        ],
      ),
    );
  }
}

class _PickerAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PickerAction(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: ExcludeSemantics(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Text(label,
                      style: AppText.bodyStrong
                          .copyWith(color: AppColors.primary)),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSubtle),
              ]),
            ),
          ),
        ),
      );
}

class _AddressTile extends StatelessWidget {
  final SavedAddress address;
  final bool selected;
  final Coverage coverage;
  final VoidCallback onTap, onEdit, onDelete;
  const _AddressTile({
    required this.address,
    required this.selected,
    required this.coverage,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final a = address;
    return Semantics(
      selected: selected,
      child: AppCard(
        selected: selected,
        onTap: onTap,
        padding:
            const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.md, 0, AppSpace.md),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(addressLabelIcons[a.label], color: AppColors.primary),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(addressLabelNames[a.label]!,
                        style: AppText.bodyStrong),
                    CoverageChip(coverage),
                  ]),
              const SizedBox(height: 2),
              Text(withParking(a.address, null),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.small),
            ]),
          ),
          PopupMenuButton<String>(
            tooltip: 'Edit or delete ${addressLabelNames[a.label]}',
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.textSubtle),
            onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ]),
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
    title: existing == null ? 'Add an address' : 'Edit address',
    body: (ctx) => StatefulBuilder(
      builder: (ctx, setState) =>
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: AppSpace.sm, children: [
          for (final l in AddressLabel.values)
            ChoiceChip(
              avatar: Icon(addressLabelIcons[l],
                  size: 18,
                  color:
                      l == label ? AppColors.primaryDk : AppColors.textMuted),
              label: Text(addressLabelNames[l]!),
              selected: l == label,
              showCheckmark: false,
              selectedColor: AppColors.primarySoft,
              backgroundColor: AppColors.surface,
              side: BorderSide(
                  color: l == label ? AppColors.primary : AppColors.border),
              labelStyle: AppText.smallStrong.copyWith(
                  color: l == label ? AppColors.primaryDk : AppColors.text),
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
