import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/format.dart';
import '../core/pricing.dart';
import '../core/theme.dart';
import '../data/business_info.dart';
import '../models/service.dart';
import '../providers/app_providers.dart';
import '../widgets/contact_actions.dart';
import '../widgets/service_widgets.dart';
import '../widgets/ui.dart';

/// One package (v3 design): photo, badges, name and what it does, what it
/// fixes (detailing), the price for each car size, what's included and not,
/// who it's for, the water-and-plug note, common questions, and a bottom bar
/// with this car's price and "Book this".
class ServiceDetailScreen extends ConsumerStatefulWidget {
  final String serviceId;
  const ServiceDetailScreen({super.key, required this.serviceId});

  @override
  ConsumerState<ServiceDetailScreen> createState() =>
      _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends ConsumerState<ServiceDetailScreen> {
  bool _showAllIncluded = false;

  /// The car whose price is shown. Starts as the customer's saved car;
  /// changing it here doesn't change the profile.
  CarType? _car;

  static const _needChips = {
    DetailNeed.shine: 'Fixes dull paint',
    DetailNeed.scratches: 'Fixes light scratches',
    DetailNeed.inside: 'Fixes stains and smell',
    DetailNeed.everything: 'Inside and out',
  };

  @override
  Widget build(BuildContext context) {
    final s = serviceById(widget.serviceId);
    if (s == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: EmptyState(
            icon: Icons.search_off_rounded,
            title: 'Service not found',
            message: 'This service may have been renamed or removed.',
            action: PrimaryButton(
                label: 'See all services',
                expand: false,
                onPressed: () => context.go('/services')),
          ),
        ),
      );
    }

    final car = _car ?? ref.watch(profileProvider).car ?? CarType.hatchback;
    final included =
        _showAllIncluded ? s.included : s.included.take(6).toList();
    final price = '${rupees(s.priceFor(car))}${s.priceSuffix}';
    // "Everything" already says it all; don't repeat the single fixes.
    final chips = s.needs.contains(DetailNeed.everything)
        ? [DetailNeed.everything]
        : DetailNeed.values.where(s.needs.contains).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.15,
        child: CustomScrollView(slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 270,
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            leading: Padding(
              padding: const EdgeInsets.all(6),
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 2,
                child: IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: AppColors.text, size: 20),
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go('/services?cat=${s.category.name}'),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: ServiceImage(s, radius: 0),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.bg,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
              ),
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.page, AppSpace.xl, AppSpace.page, 0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      if (s.badge != null)
                        Pill(s.badge!,
                            tone: s.category == ServiceCategory.detailing
                                ? PillTone.dark
                                : PillTone.solid),
                      Pill(s.duration, icon: Icons.schedule_rounded),
                      if (kPayAfterService)
                        const Pill('Pay after', tone: PillTone.brand),
                    ]),
                    const SizedBox(height: AppSpace.md),
                    Semantics(
                        header: true,
                        child: Text(s.listName, style: AppText.h1)),
                    const SizedBox(height: 6),
                    Text(s.description, style: AppText.body),
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: AppSpace.md),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final n in chips) Pill(_needChips[n]!),
                      ]),
                    ],
                    const SizedBox(height: AppSpace.xl),
                    _CarPrices(
                      service: s,
                      selected: car,
                      onChanged: (c) => setState(() => _car = c),
                    ),
                    const SizedBox(height: AppSpace.xl),
                    AppCard(
                      radius: AppRadius.lg,
                      padding: const EdgeInsets.all(AppSpace.lg),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                                header: true,
                                child: Text('What\'s included',
                                    style: AppText.title)),
                            const SizedBox(height: AppSpace.md),
                            for (final i in included) CheckItem(i),
                            if (s.included.length > 6)
                              TextButton(
                                onPressed: () => setState(
                                    () => _showAllIncluded = !_showAllIncluded),
                                child: Text(_showAllIncluded
                                    ? 'Show less'
                                    : 'Show all ${s.included.length} items'),
                              ),
                            if (s.notIncluded.isNotEmpty) ...[
                              const Divider(height: 24),
                              Text('Not included',
                                  style: AppText.smallStrong
                                      .copyWith(color: AppColors.textMuted)),
                              const SizedBox(height: AppSpace.sm),
                              for (final i in s.notIncluded)
                                CheckItem(i, included: false),
                            ],
                          ]),
                    ),
                    const SizedBox(height: AppSpace.md),
                    _Note(
                      color: AppColors.primarySoft,
                      child: Text.rich(
                        TextSpan(children: [
                          const TextSpan(
                              text: 'Best for: ',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                          TextSpan(text: s.bestFor),
                        ]),
                        style: AppText.small
                            .copyWith(color: AppColors.primaryDk, height: 1.45),
                      ),
                    ),
                    const SizedBox(height: AppSpace.md),
                    _Note(
                      color: AppColors.surface,
                      border: true,
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.water_drop_outlined,
                                size: 20, color: AppColors.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                  'Keep a water tap and a 5A or 15A plug point '
                                  'within 25–30 m of the car. We bring 30 m '
                                  'cables and hose, the pressure washer, vacuum '
                                  'and supplies.',
                                  style: AppText.small.copyWith(
                                      color: AppColors.text, height: 1.45)),
                            ),
                          ]),
                    ),
                    if (s.extras.isNotEmpty) ...[
                      const SizedBox(height: AppSpace.md),
                      Text(
                          'Add-ons on the next step: '
                          '${s.extras.map((e) => '${e.name} +${rupees(e.price)}').join(' · ')}',
                          style: AppText.caption),
                    ],
                    _sectionTitle('Common questions'),
                    _Faqs(service: s),
                    const SizedBox(height: AppSpace.lg),
                    AppCard(
                      onTap: () => openWhatsApp(context,
                          message: 'Hi CleanCruisers, I have a question about '
                              '"${s.name}".'),
                      padding: const EdgeInsets.all(AppSpace.md),
                      child: Row(children: [
                        const IconBadge(Icons.chat_outlined, size: 40),
                        const SizedBox(width: AppSpace.md),
                        Expanded(
                          child: Text('Still have a question? Chat with us',
                              style: AppText.smallStrong),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textSubtle),
                      ]),
                    ),
                    const SizedBox(height: AppSpace.xl),
                  ]),
            ),
          ),
        ]),
      ),
      bottomNavigationBar: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.15,
        child: BottomActionBar(
          child: Row(children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(price, style: AppText.price),
                  Text(
                      '${carTypeNames[car]}'
                      '${kPayAfterService ? ' · pay after' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: PrimaryButton(
                label: 'Book this',
                icon: Icons.arrow_forward_rounded,
                onPressed: () => context.push('/book/${s.id}?car=${car.name}'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 10),
        child: Semantics(header: true, child: Text(t, style: AppText.h3)),
      );
}

/// Car size as a segmented control, each with this package's price.
class _CarPrices extends StatelessWidget {
  final CarService service;
  final CarType selected;
  final ValueChanged<CarType> onChanged;
  const _CarPrices(
      {required this.service, required this.selected, required this.onChanged});

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
              label: '${carTypeNames[t]}, '
                  '${rupees(service.priceFor(t))}${service.priceSuffix}',
              child: ExcludeSemantics(
                child: GestureDetector(
                  onTap: () => onChanged(t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(vertical: 6),
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
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(carTypeNames[t]!,
                            style: AppText.caption.copyWith(
                                color: t == selected
                                    ? AppColors.text
                                    : AppColors.textMuted,
                                fontWeight: FontWeight.w800)),
                        Text(rupees(service.priceFor(t)),
                            style: AppText.caption.copyWith(
                                color: t == selected
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                                fontWeight: FontWeight.w800)),
                      ]),
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

class _Note extends StatelessWidget {
  final Color color;
  final bool border;
  final Widget child;
  const _Note({required this.color, required this.child, this.border = false});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.lg),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: border ? Border.all(color: AppColors.border) : null,
        ),
        child: child,
      );
}

class _Faqs extends StatelessWidget {
  final CarService service;
  const _Faqs({required this.service});

  @override
  Widget build(BuildContext context) {
    final faqs = [
      (
        'How is my booking confirmed?',
        'Send a request in the app. Our team checks the route, service time and worker availability, then confirms the appointment in the app.'
      ),
      if (kPayAfterService)
        (
          'When do I pay?',
          'After the service is done and you\'ve checked your car. There is no advance payment.'
        ),
      (
        'How long does it take?',
        'About ${service.duration}${service.category == ServiceCategory.monthly ? '' : ', depending on the car\'s condition'}.'
      ),
      (
        'Which car size am I?',
        'Hatchback: ${carTypeExamples[CarType.hatchback]}. Sedan: ${carTypeExamples[CarType.sedan]}. '
            'SUV: ${carTypeExamples[CarType.suv]}. Luxury: ${carTypeExamples[CarType.luxury]}. '
            'Not sure? Pick the closest and add your model — we\'ll check it for you.'
      ),
      (
        'Can I change the date or time?',
        'Yes. Request a change from My bookings. Our team will review it and update the status in the app.'
      ),
      (
        'Which areas do you cover?',
        '${kServiceAreas.join(', ')} and nearby areas in $kCityLabel.'
      ),
    ];
    return AppCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Column(children: [
          for (var i = 0; i < faqs.length; i++) ...[
            if (i > 0) const Divider(indent: 16, endIndent: 16),
            ExpansionTile(
              title: Text(faqs[i].$1, style: AppText.bodyStrong),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              iconColor: AppColors.primary,
              collapsedIconColor: AppColors.textSubtle,
              children: [Text(faqs[i].$2, style: AppText.small)],
            ),
          ],
        ]),
      ),
    );
  }
}
