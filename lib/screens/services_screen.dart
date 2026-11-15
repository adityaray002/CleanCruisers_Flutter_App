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
import '../widgets/book_button.dart';
import '../widgets/brand_header.dart';
import '../widgets/trust_widgets.dart';
import '../widgets/ui.dart';

/// Packages of one category (wash, detailing or monthly; set by `?cat=`).
/// Top to bottom:
/// 1. back, category name, where the car is parked,
/// 2. trust pills (facts from business_info.dart only),
/// 3. car type, each with its lowest price (prices below follow it),
/// 4. the featured package as a photo card with "Book now",
/// 5. the other packages as compact rows, so they fit above the fold,
/// 6. "Compare what each package includes", help.
class ServicesScreen extends ConsumerStatefulWidget {
  final ServiceCategory? initialCategory;
  const ServicesScreen({super.key, this.initialCategory});

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  late CarType _car;

  static const _gutter = AppSpace.lg;

  ServiceCategory get _cat => widget.initialCategory ?? ServiceCategory.wash;

  @override
  void initState() {
    super.initState();
    _car = ref.read(profileProvider).car ?? CarType.hatchback;
  }

  @override
  Widget build(BuildContext context) {
    final services = servicesIn(_cat);
    final featured = services.where((s) => s.badge != null).toList();
    final others = services.where((s) => s.badge == null).toList();
    const pad = EdgeInsets.symmetric(horizontal: _gutter);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.15,
          child: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSpace.xxl),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      _gutter, AppSpace.sm, _gutter, AppSpace.md),
                  child: Row(children: [
                    Semantics(
                      button: true,
                      label: 'Back to Home',
                      child: ExcludeSemantics(
                        child: RoundSurface(
                          onTap: () => context.go('/home'),
                          padding: const EdgeInsets.all(10),
                          child: const Icon(Icons.arrow_back_rounded,
                              size: 22, color: AppColors.text),
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
                            const ParkedAtLine(),
                          ]),
                    ),
                  ]),
                ),
                const Padding(padding: pad, child: _TrustPills()),
                const SizedBox(height: AppSpace.lg),
                Padding(
                  padding: pad,
                  child: Text('Your car type', style: AppText.title),
                ),
                const SizedBox(height: AppSpace.sm),
                Padding(
                  padding: pad,
                  child: _CarTypeSelector(
                    selected: _car,
                    services: services,
                    onChanged: (c) {
                      HapticFeedback.selectionClick();
                      setState(() => _car = c);
                    },
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                for (final s in featured)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        _gutter, 0, _gutter, AppSpace.lg),
                    child: _PackageCard(
                      service: s,
                      car: _car,
                      onTap: () => context.push('/service/${s.id}'),
                    ),
                  ),
                if (others.isNotEmpty) ...[
                  Padding(
                    padding: pad,
                    child: Text(featured.isEmpty ? 'Packages' : 'More packages',
                        style: AppText.title),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Padding(
                    padding: pad,
                    child: AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(children: [
                        for (var i = 0; i < others.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _PackageRow(
                            service: others[i],
                            car: _car,
                            onTap: () =>
                                context.push('/service/${others[i].id}'),
                          ),
                        ],
                      ]),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpace.sm),
                Center(
                  child: TextButton.icon(
                    onPressed: () => _showIncluded(context, services),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      textStyle: AppText.smallStrong,
                      minimumSize: const Size(0, 44),
                    ),
                    icon: const Icon(Icons.checklist_rounded, size: 18),
                    label: const Text('Compare what each package includes'),
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                Padding(
                  padding: pad,
                  child: HelpCard(
                    title: 'Need a custom service?',
                    line: 'Chat with our team',
                    message: 'Hi CleanCruisers, I need help choosing a '
                        'service for my ${carTypeNames[_car]}.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Each package and everything it includes, in one sheet.
  void _showIncluded(BuildContext context, List<CarService> services) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(
              AppSpace.page, 0, AppSpace.page, AppSpace.section),
          children: [
            Text('What\'s included', style: AppText.h3),
            const SizedBox(height: AppSpace.lg),
            for (final s in services) ...[
              Text(s.name, style: AppText.title),
              const SizedBox(height: AppSpace.sm),
              for (final item in s.included) CheckItem(item),
              const SizedBox(height: AppSpace.md),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Trust pills: facts from business_info.dart only ──────────────────────────
class _TrustPills extends StatelessWidget {
  const _TrustPills();

  @override
  Widget build(BuildContext context) {
    return const Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
      if (kRatingValue != null && kRatingSource != null)
        Pill('$kRatingValue on $kRatingSource',
            icon: Icons.star_rounded, tone: PillTone.brand),
      if (kPayAfterService)
        Pill('Pay after service',
            icon: Icons.payments_outlined, tone: PillTone.brand),
      Pill('$kDaysLabel, $kHoursLabel', icon: Icons.schedule_rounded),
      if (kEstablished != null) Pill('Since $kEstablished'),
    ]);
  }
}

// ── Car type: prices below follow it ─────────────────────────────────────────
/// Each tile shows the lowest price in this category for that car, so the
/// customer sees what they will pay before tapping.
class _CarTypeSelector extends StatelessWidget {
  final CarType selected;
  final List<CarService> services;
  final ValueChanged<CarType> onChanged;
  const _CarTypeSelector(
      {required this.selected,
      required this.services,
      required this.onChanged});

  int? _fromPrice(CarType t) {
    final prices = services.map((s) => s.priceFor(t)).where((p) => p > 0);
    return prices.isEmpty ? null : prices.reduce((a, b) => a < b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (final t in CarType.values) ...[
        if (t != CarType.values.first) const SizedBox(width: AppSpace.sm),
        Expanded(child: _tile(t)),
      ],
    ]);
  }

  Widget _tile(CarType t) {
    final on = t == selected;
    final from = _fromPrice(t);
    return Semantics(
      button: true,
      selected: on,
      label: '${carTypeNames[t]}'
          '${from == null ? '' : ', from ${rupees(from)}'}',
      child: ExcludeSemantics(
        child: AppCard(
          selected: on,
          onTap: () => onChanged(t),
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpace.xs, vertical: 10),
          child: Column(children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(carTypeNames[t]!,
                  maxLines: 1,
                  softWrap: false,
                  style: (on ? AppText.smallStrong : AppText.small).copyWith(
                      color: on ? AppColors.primaryDk : AppColors.text)),
            ),
            if (from != null) ...[
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('from ${rupees(from)}',
                    maxLines: 1,
                    softWrap: false,
                    style: AppText.caption.copyWith(
                        color: on ? AppColors.primary : AppColors.textSubtle)),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

// ── Package card ─────────────────────────────────────────────────────────────
/// Photo across the top (badge and duration sit on it), then the name and a
/// short summary, the highlights, and a footer with the price and "Book now".
/// The whole card opens the package page. Only the featured package gets a
/// filled button and a green border, so it is the one that stands out.
class _PackageCard extends StatelessWidget {
  final CarService service;
  final CarType car;
  final VoidCallback onTap;
  const _PackageCard(
      {required this.service, required this.car, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = service;
    final featured = s.badge != null;
    final amount = rupees(s.priceFor(car));
    const top = Radius.circular(AppRadius.lg - 1);

    return Semantics(
      button: true,
      label: '${s.name}${featured ? ', ${s.badge}' : ''}. ${s.summary}. '
          'Takes ${s.duration}. ${s.highlights.join(', ')}. '
          '$amount${s.priceSuffix} for a ${carTypeNames[car]}. '
          'Tap to know more',
      child: AppCard(
        onTap: onTap,
        radius: AppRadius.lg,
        selected: featured,
        color: AppColors.surface,
        padding: EdgeInsets.zero,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Photo, with the badge and duration on it.
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: top),
            child: AspectRatio(
              aspectRatio: 2.8,
              child: Stack(fit: StackFit.expand, children: [
                s.cardPhoto != null
                    ? Image.asset(s.cardPhoto!,
                        fit: BoxFit.cover,
                        cacheWidth: 900,
                        excludeFromSemantics: true)
                    : ColoredBox(
                        color: AppColors.primarySoft,
                        child: Icon(s.icon, color: AppColors.primary, size: 40),
                      ),
                // Soft shade at the bottom so the duration pill reads.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.55, 1],
                      colors: [Colors.transparent, Color(0x66000000)],
                    ),
                  ),
                ),
                if (featured)
                  Positioned(
                    top: AppSpace.md,
                    left: AppSpace.md,
                    child: ExcludeSemantics(
                      child: Pill(s.badge!,
                          icon: Icons.star_rounded, tone: PillTone.solid),
                    ),
                  ),
                Positioned(
                  left: AppSpace.md,
                  bottom: AppSpace.md,
                  child: ExcludeSemantics(
                    child: Pill(s.duration,
                        icon: Icons.schedule_rounded, tone: PillTone.dark),
                  ),
                ),
              ]),
            ),
          ),
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg, 14, AppSpace.lg, AppSpace.xs),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name, style: AppText.h3),
                    const SizedBox(height: AppSpace.sm),
                    // Highlights, two to a row.
                    LayoutBuilder(builder: (context, c) {
                      final w = (c.maxWidth - AppSpace.md) / 2;
                      return Wrap(
                          spacing: AppSpace.md,
                          runSpacing: 6,
                          children: [
                            for (final h in s.highlights)
                              SizedBox(width: w, child: _Tick(h)),
                          ]);
                    }),
                  ]),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.lg, AppSpace.md, AppSpace.md, AppSpace.md),
            child: Row(children: [
              Expanded(
                child: ExcludeSemantics(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$amount${s.priceSuffix}',
                            style: AppText.priceSm
                                .copyWith(color: AppColors.text)),
                        Text(
                            'for ${carTypeNames[car]}'
                            '${kPayAfterService ? ' · pay after service' : ''}',
                            style: AppText.caption
                                .copyWith(fontWeight: FontWeight.w500)),
                      ]),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              BookButton(s, primary: featured),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Compact package row ──────────────────────────────────────────────────────
/// Thumbnail, name, duration and two highlights, and this car's price. The
/// whole row opens the package page (one tap target, no separate button).
class _PackageRow extends StatelessWidget {
  final CarService service;
  final CarType car;
  final VoidCallback onTap;
  const _PackageRow(
      {required this.service, required this.car, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = service;
    final amount = rupees(s.priceFor(car));
    final photo = s.cardPhoto;
    return Semantics(
      button: true,
      label: '${s.name}. Takes ${s.duration}. '
          '${s.highlights.take(2).join(', ')}. '
          '$amount${s.priceSuffix} for a ${carTypeNames[car]}. '
          'Tap to know more',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.md, AppSpace.md, AppSpace.sm, AppSpace.md),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.thumb),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: photo != null
                      ? Image.asset(photo,
                          fit: BoxFit.cover,
                          cacheWidth: 200,
                          excludeFromSemantics: true)
                      : ColoredBox(
                          color: AppColors.primarySoft,
                          child:
                              Icon(s.icon, color: AppColors.primary, size: 24),
                        ),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, style: AppText.title),
                      const SizedBox(height: 2),
                      Text([s.duration, ...s.highlights.take(2)].join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.small),
                    ]),
              ),
              const SizedBox(width: AppSpace.sm),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(amount,
                    style: AppText.bodyStrong.copyWith(color: AppColors.text)),
                if (s.priceSuffix.isNotEmpty)
                  Text(s.priceSuffix.trim(), style: AppText.caption),
              ]),
              const Icon(Icons.chevron_right_rounded,
                  size: 22, color: AppColors.textSubtle),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Tick extends StatelessWidget {
  final String text;
  const _Tick(this.text);

  @override
  Widget build(BuildContext context) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.check_rounded, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 6),
        Expanded(
            child: Text(text,
                style: AppText.small.copyWith(color: AppColors.text))),
      ]);
}
