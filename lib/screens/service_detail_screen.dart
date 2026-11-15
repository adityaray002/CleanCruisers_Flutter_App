import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/format.dart';
import '../core/pricing.dart';
import '../core/theme.dart';
import '../data/business_info.dart';
import '../models/service.dart';
import '../providers/app_providers.dart';
import 'auth/login_screen.dart' show CarTypePicker;
import '../widgets/contact_actions.dart';
import '../widgets/customer_sheets.dart';
import '../widgets/how_it_works.dart';
import '../widgets/service_widgets.dart';
import '../widgets/ui.dart';

class ServiceDetailScreen extends ConsumerStatefulWidget {
  final String serviceId;
  const ServiceDetailScreen({super.key, required this.serviceId});

  @override
  ConsumerState<ServiceDetailScreen> createState() =>
      _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends ConsumerState<ServiceDetailScreen> {
  bool _showAllIncluded = false;

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

    final included =
        _showAllIncluded ? s.included : s.included.take(6).toList();
    // The customer's own car (saved at sign-up) decides the price.
    final car = ref.watch(profileProvider).car;

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 260,
          backgroundColor: AppColors.surface,
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded,
                    color: AppColors.text, size: 20),
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/services'),
              ),
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: ServiceImage(s, radius: 0),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.page, AppSpace.xl, AppSpace.page, 0),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(serviceCategoryNames[s.category]!.toUpperCase(),
                  style: AppText.overline),
              const SizedBox(height: 6),
              Text(s.name, style: AppText.h1),
              if (car != null) ...[
                const SizedBox(height: AppSpace.sm),
                Row(children: [
                  PriceText(s.priceFor(car), suffix: s.priceSuffix, size: 26),
                  const SizedBox(width: AppSpace.sm),
                  Icon(CarTypePicker.icons[car],
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(carTypeNames[car]!,
                        style: AppText.smallStrong
                            .copyWith(color: AppColors.primaryDk),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  TextButton(
                    onPressed: () => showCarSheet(context, ref),
                    child: const Text('Change car'),
                  ),
                ]),
              ],
              const SizedBox(height: 8),
              Text(s.description, style: AppText.body),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                Pill(s.duration, icon: Icons.schedule_rounded),
                const Pill('At your doorstep', icon: Icons.home_outlined),
                const Pill('Water tap & plug needed',
                    icon: Icons.electrical_services_rounded,
                    tone: PillTone.brand),
                if (kPayAfterService)
                  const Pill('Pay after service',
                      icon: Icons.payments_outlined),
              ]),
              // Only when we don't know the car yet.
              if (car == null) ...[
                _sectionTitle('Pick your car'),
                _CarPriceGrid(
                  service: s,
                  selected: null,
                  onSelect: (c) => ref
                      .read(profileProvider.notifier)
                      .save(ref.read(profileProvider).copyWith(car: c)),
                ),
              ],
              _sectionTitle('What\'s included'),
              AppCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final i in included) CheckItem(i),
                      if (s.included.length > 6)
                        TextButton(
                          onPressed: () => setState(
                              () => _showAllIncluded = !_showAllIncluded),
                          child: Text(_showAllIncluded
                              ? 'Show less'
                              : 'Show all ${s.included.length} items'),
                        ),
                    ]),
              ),
              if (s.notIncluded.isNotEmpty) ...[
                const SizedBox(height: 12),
                AppCard(
                  color: AppColors.surfaceAlt,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Not included', style: AppText.smallStrong),
                        const SizedBox(height: 10),
                        for (final i in s.notIncluded)
                          CheckItem(i, included: false),
                      ]),
                ),
              ],
              _sectionTitle('What we need from you'),
              const AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RequirementRow(
                      icon: Icons.water_drop_rounded,
                      title: 'Standard Water Tap Connection',
                      description:
                          'A normal running water tap within 25–30 meters of your vehicle. We carry tap adapters.',
                    ),
                    Divider(height: 18, color: AppColors.border),
                    _RequirementRow(
                      icon: Icons.electrical_services_rounded,
                      title: 'Standard Power Socket',
                      description:
                          'A standard 5A or 15A plug point within 25–30 meters for our pressure washer & vacuum.',
                    ),
                    Divider(height: 18, color: AppColors.border),
                    _RequirementRow(
                      icon: Icons.cable_rounded,
                      title: 'We Bring Everything Else',
                      description:
                          '30-meter industrial extension cables, water hose, pressure washer, vacuum, and detailing supplies.',
                    ),
                  ],
                ),
              ),
              _sectionTitle('Best for'),
              Text(s.bestFor,
                  style: AppText.body.copyWith(color: AppColors.text)),
              if (s.extras.isNotEmpty) ...[
                _sectionTitle('Add-ons at checkout'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final e in s.extras)
                    Pill('${e.name} +${rupees(e.price)}',
                        icon: Icons.add_rounded),
                ]),
              ],
              _sectionTitle('How it works'),
              const AppCard(child: HowItWorksSteps()),
              _sectionTitle('Common questions'),
              _Faqs(service: s),
              const SizedBox(height: 20),
              AppCard(
                color: AppColors.surfaceAlt,
                child: Row(children: [
                  Expanded(
                    child: Text('Still have a question about this service?',
                        style: AppText.smallStrong),
                  ),
                  TextButton.icon(
                    onPressed: () => openWhatsApp(context,
                        message:
                            'Hi CleanCruisers, I have a question about "${s.name}".'),
                    icon: const Icon(Icons.chat_outlined, size: 18),
                    label: const Text('Ask us'),
                  ),
                ]),
              ),
              const SizedBox(height: 28),
            ]),
          ),
        ),
      ]),
      bottomNavigationBar: BottomActionBar(
        child: Row(children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  car != null
                      ? 'For ${carTypeNames[car]}'
                      : s.samePriceForAll
                          ? 'Price'
                          : 'From',
                  style: AppText.caption),
              PriceText(
                car == null ? s.fromPrice : s.priceFor(car),
                suffix: s.priceSuffix,
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: PrimaryButton(
              label: 'Book',
              icon: Icons.event_available_rounded,
              onPressed: () => context.push('/book/${s.id}'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(top: 30, bottom: 10),
        child: Semantics(header: true, child: Text(t, style: AppText.h2)),
      );
}

class _CarPriceGrid extends StatelessWidget {
  final CarService service;
  final CarType? selected;
  final ValueChanged<CarType> onSelect;

  const _CarPriceGrid(
      {required this.service, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - 12) / 2;
      return Wrap(spacing: 12, runSpacing: 12, children: [
        for (final car in CarType.values)
          SizedBox(
            width: w,
            child: AppCard(
              selected: selected == car,
              padding: const EdgeInsets.all(14),
              onTap: () => onSelect(car),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(carTypeNames[car]!,
                              style: AppText.bodyStrong)),
                      if (selected == car)
                        const Icon(Icons.check_circle_rounded,
                            size: 18, color: AppColors.primary),
                    ]),
                    Text(carTypeExamples[car]!,
                        style: AppText.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    PriceText(service.priceFor(car),
                        suffix: service.priceSuffix, size: 18),
                  ]),
            ),
          ),
      ]);
    });
  }
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

class _RequirementRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  const _RequirementRow(
      {required this.icon, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: const BoxDecoration(
            color: AppColors.primarySoft,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.smallStrong),
              const SizedBox(height: 2),
              Text(description,
                  style: AppText.caption
                      .copyWith(color: AppColors.text, height: 1.35)),
            ],
          ),
        ),
      ],
    );
  }
}
