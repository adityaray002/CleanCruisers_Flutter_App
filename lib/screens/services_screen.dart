import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/format.dart';
import '../core/pricing.dart';
import '../core/theme.dart';
import '../data/business_info.dart';
import '../models/service.dart';
import '../providers/app_providers.dart';
import '../widgets/brand_header.dart';
import '../widgets/contact_actions.dart';
import '../widgets/ui.dart';

/// Packages of one category (wash, detailing or monthly; set by `?cat=`),
/// v3 design. Top to bottom:
/// 1. back, category name, "at your door · pay after the service",
/// 2. car size (every price below follows it),
/// 3. detailing only: "What's bothering you?" chips that filter the list,
/// 4. the packages as selectable cards; each has its own "What's included"
///    link to the package page,
/// 5. a tip row (extras for washes, WhatsApp help for detailing),
/// and a bar pinned to the bottom with the chosen price and "Pick a time".
class ServicesScreen extends ConsumerStatefulWidget {
  final ServiceCategory? initialCategory;
  const ServicesScreen({super.key, this.initialCategory});

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  late CarType _car;
  DetailNeed? _need; // null = show all
  String? _picked;

  static const _gutter = AppSpace.lg;

  ServiceCategory get _cat => widget.initialCategory ?? ServiceCategory.wash;

  @override
  void initState() {
    super.initState();
    _car = ref.read(profileProvider).car ?? CarType.hatchback;
  }

  List<CarService> get _shown => servicesIn(_cat)
      .where((s) => _need == null || s.needs.contains(_need))
      .toList();

  CarService _chosen(List<CarService> shown) =>
      shown.where((s) => s.id == _picked).firstOrNull ??
      shown
          .where((s) => s.badge != null && _cat == ServiceCategory.wash)
          .firstOrNull ??
      shown.first;

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    final chosen = _chosen(shown);
    const pad = EdgeInsets.symmetric(horizontal: _gutter);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        bottomNavigationBar: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.15,
          child: _PickBar(
            service: chosen,
            car: _car,
            onPick: () {
              HapticFeedback.selectionClick();
              context.push('/book/${chosen.id}?car=${_car.name}');
            },
          ),
        ),
        body: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.15,
          child: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSpace.xxl),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      _gutter, AppSpace.sm, _gutter, AppSpace.lg),
                  child: Row(children: [
                    Semantics(
                      button: true,
                      label: 'Back to Home',
                      child: ExcludeSemantics(
                        child: RoundSurface(
                          onTap: () => context.go('/home'),
                          padding: const EdgeInsets.all(11),
                          child: const Icon(Icons.arrow_back_rounded,
                              size: 20, color: AppColors.text),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(serviceCategoryNames[_cat]!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.h2),
                            ),
                            Text(
                                kPayAfterService
                                    ? 'At your door · pay after the service'
                                    : 'At your door',
                                style: AppText.small),
                          ]),
                    ),
                  ]),
                ),
                Padding(
                  padding: pad,
                  child: _CarSegments(
                    selected: _car,
                    onChanged: (c) {
                      HapticFeedback.selectionClick();
                      setState(() => _car = c);
                    },
                  ),
                ),
                if (_cat == ServiceCategory.detailing) ...[
                  const SizedBox(height: AppSpace.xl),
                  Padding(
                    padding: pad,
                    child: Text('What\'s bothering you?', style: AppText.title),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Padding(
                    padding: pad,
                    child: Wrap(
                        spacing: AppSpace.sm,
                        runSpacing: AppSpace.sm,
                        children: [
                          _NeedChip(
                            label: 'Show all',
                            on: _need == null,
                            onTap: () => setState(() => _need = null),
                          ),
                          for (final n in DetailNeed.values)
                            _NeedChip(
                              label: detailNeedNames[n]!,
                              on: _need == n,
                              onTap: () => setState(() => _need = n),
                            ),
                        ]),
                  ),
                ] else ...[
                  const SizedBox(height: AppSpace.xl),
                  Padding(
                    padding: pad,
                    child: Row(children: [
                      Expanded(
                          child: Text(
                              _cat == ServiceCategory.monthly
                                  ? 'Choose a plan'
                                  : 'Choose a wash',
                              style: AppText.title)),
                      Text('Prices for your ${carTypeNames[_car]}',
                          style: AppText.caption),
                    ]),
                  ),
                ],
                const SizedBox(height: AppSpace.md),
                for (final s in shown)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        _gutter, 0, _gutter, AppSpace.md),
                    child: _PackageOption(
                      service: s,
                      car: _car,
                      selected: s.id == chosen.id,
                      onSelect: () {
                        HapticFeedback.selectionClick();
                        setState(() => _picked = s.id);
                      },
                    ),
                  ),
                if (_cat == ServiceCategory.wash)
                  Padding(
                    padding: pad,
                    child: _TipRow(
                      icon: Icons.add_rounded,
                      title: 'Add seat or roof cleaning',
                      line: 'Choose extras on the next step, '
                          'from ${rupees(washAddonPrices['seat']!)}',
                    ),
                  ),
                if (_cat == ServiceCategory.detailing)
                  Padding(
                    padding: pad,
                    child: _TipRow(
                      icon: Icons.chat_outlined,
                      title: 'Not sure which one?',
                      line: 'Send us a photo on WhatsApp',
                      onTap: () => openWhatsApp(context,
                          message: 'Hi CleanCruisers, which detailing package '
                              'does my ${carTypeNames[_car]} need?'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Car size: a segmented control ────────────────────────────────────────────
class _CarSegments extends StatelessWidget {
  final CarType selected;
  final ValueChanged<CarType> onChanged;
  const _CarSegments({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE9ECEF),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(children: [
        for (final t in CarType.values)
          Expanded(
            child: Semantics(
              button: true,
              selected: t == selected,
              label: carTypeNames[t],
              child: ExcludeSemantics(
                child: GestureDetector(
                  onTap: () => onChanged(t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t == selected ? AppColors.surface : null,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      boxShadow: t == selected
                          ? const [
                              BoxShadow(
                                  color: Color(0x290B0F10),
                                  blurRadius: 3,
                                  offset: Offset(0, 1))
                            ]
                          : null,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(carTypeNames[t]!,
                            maxLines: 1,
                            style: AppText.smallStrong.copyWith(
                                color: t == selected
                                    ? AppColors.text
                                    : AppColors.textMuted)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

class _NeedChip extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _NeedChip({required this.label, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: on,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: on ? AppColors.ink : AppColors.surface,
          shape: StadiumBorder(
              side: BorderSide(color: on ? AppColors.ink : AppColors.border)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Center(
                  widthFactor: 1,
                  child: Text(label,
                      style: AppText.smallStrong
                          .copyWith(color: on ? Colors.white : AppColors.text)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Package option ───────────────────────────────────────────────────────────
/// A selectable card: photo, name and badge, what it does or fixes, how long
/// it takes, this car's price and a radio. Underneath, a separate
/// "What's included" row opens the package page.
class _PackageOption extends StatelessWidget {
  final CarService service;
  final CarType car;
  final bool selected;
  final VoidCallback onSelect;
  const _PackageOption({
    required this.service,
    required this.car,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final s = service;
    final price = '${rupees(s.priceFor(car))}${s.priceSuffix}';
    final line = s.fixes != null ? 'Fixes: ${s.fixes}' : s.summary;
    final photo = s.cardPhoto;
    final r = BorderRadius.circular(AppRadius.lg);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: r,
        border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1),
        boxShadow: selected
            ? [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.16),
                    blurRadius: 20,
                    offset: const Offset(0, 8))
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: r,
        child: Material(
          type: MaterialType.transparency,
          child: Column(children: [
            Semantics(
              button: true,
              selected: selected,
              label: '${s.listName}${s.badge != null ? ', ${s.badge}' : ''}. '
                  '$line. Takes ${s.duration}. $price for a ${carTypeNames[car]}',
              child: ExcludeSemantics(
                child: InkWell(
                  onTap: onSelect,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.md),
                    child: Row(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.thumb),
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: photo != null
                              ? Image.asset(photo,
                                  fit: BoxFit.cover,
                                  cacheWidth: 240,
                                  excludeFromSemantics: true)
                              : ColoredBox(
                                  color: AppColors.primarySoft,
                                  child: Icon(s.icon,
                                      color: AppColors.primary, size: 28),
                                ),
                        ),
                      ),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(s.listName, style: AppText.title),
                                    if (s.badge != null)
                                      Pill(s.badge!,
                                          tone:
                                              s.category == ServiceCategory.wash
                                                  ? PillTone.solid
                                                  : PillTone.dark),
                                  ]),
                              const SizedBox(height: 2),
                              Text(line,
                                  style: (s.fixes != null
                                          ? AppText.small.copyWith(
                                              color: AppColors.primaryDk,
                                              fontWeight: FontWeight.w600)
                                          : AppText.small)
                                      .copyWith(height: 1.3)),
                              const SizedBox(height: 2),
                              Text(s.duration, style: AppText.caption),
                            ]),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(price,
                                style: AppText.bodyStrong
                                    .copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: AppSpace.sm),
                            _Radio(on: selected),
                          ]),
                    ]),
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Semantics(
              button: true,
              label: 'What\'s included in ${s.listName}',
              child: ExcludeSemantics(
                child: InkWell(
                  onTap: () => context.push('/service/${s.id}'),
                  child: SizedBox(
                    height: 44,
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpace.md),
                      child: Row(children: [
                        Expanded(
                          child: Text('What\'s included',
                              style: AppText.smallStrong
                                  .copyWith(color: AppColors.primary)),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            size: 18, color: AppColors.primary),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  final bool on;
  const _Radio({required this.on});

  @override
  Widget build(BuildContext context) => Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? AppColors.primary : null,
          border: Border.all(
              color: on ? AppColors.primary : const Color(0xFFB9C2BC),
              width: 2),
        ),
        child: on
            ? Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
              )
            : null,
      );
}

class _TipRow extends StatelessWidget {
  final IconData icon;
  final String title, line;
  final VoidCallback? onTap;
  const _TipRow(
      {required this.icon,
      required this.title,
      required this.line,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: '$title. $line',
      child: ExcludeSemantics(
        child: AppCard(
          onTap: onTap,
          padding: const EdgeInsets.all(AppSpace.md),
          child: Row(children: [
            IconBadge(icon, size: 40),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.title),
                    Text(line, style: AppText.small),
                  ]),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded,
                  size: 22, color: AppColors.textSubtle),
          ]),
        ),
      ),
    );
  }
}

// ── Bottom bar: chosen price and "Pick a time" ───────────────────────────────
class _PickBar extends StatelessWidget {
  final CarService service;
  final CarType car;
  final VoidCallback onPick;
  const _PickBar(
      {required this.service, required this.car, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final s = service;
    return BottomActionBar(
      child: Row(children: [
        ConstrainedBox(
          // Narrow enough that "Pick a time" never truncates on a
          // small phone with large text.
          constraints: const BoxConstraints(maxWidth: 120),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${rupees(s.priceFor(car))}${s.priceSuffix}',
                    style: AppText.price.copyWith(fontSize: 22)),
                Text('${s.listName} · ${carTypeNames[car]}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption),
              ]),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: PrimaryButton(
            label: 'Pick a time',
            icon: Icons.arrow_forward_rounded,
            onPressed: onPick,
          ),
        ),
      ]),
    );
  }
}
