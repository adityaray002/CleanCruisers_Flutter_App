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
  CarType? _car;
  bool _showAllIncluded = false;

  @override
  void initState() {
    super.initState();
    _car = ref.read(profileProvider).car;
  }

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
              const SizedBox(height: 8),
              Text(s.description, style: AppText.body),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                Pill(s.duration, icon: Icons.schedule_rounded),
                const Pill('At your doorstep', icon: Icons.home_outlined),
                if (kPayAfterService)
                  const Pill('Pay after service',
                      icon: Icons.payments_outlined, tone: PillTone.brand),
              ]),
              _sectionTitle('Price for your car'),
              Text('Tap your car size to see the exact price.',
                  style: AppText.small),
              const SizedBox(height: 12),
              _CarPriceGrid(
                service: s,
                selected: _car,
                onSelect: (c) => setState(() => _car = c),
              ),
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
              _sectionTitle('Best for'),
              Text(s.bestFor,
                  style: AppText.body.copyWith(color: AppColors.text)),
              if (s.extras.isNotEmpty) ...[
                _sectionTitle('Optional extras'),
                Text('You can add these while booking.', style: AppText.small),
                const SizedBox(height: 10),
                AppCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(children: [
                    for (var i = 0; i < s.extras.length; i++) ...[
                      if (i > 0) const Divider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(children: [
                          Expanded(
                              child:
                                  Text(s.extras[i].name, style: AppText.body)),
                          Text(
                              '+${rupees(s.extras[i].price)}'
                              '${s.extras[i].unit != null ? ' / ${s.extras[i].unit}' : ''}',
                              style: AppText.smallStrong),
                        ]),
                      ),
                    ],
                  ]),
                ),
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
                  _car != null
                      ? 'For ${carTypeNames[_car]}'
                      : s.samePriceForAll
                          ? 'Price'
                          : 'Starts at',
                  style: AppText.caption),
              PriceText(
                _car == null ? s.fromPrice : s.priceFor(_car!),
                suffix: s.priceSuffix,
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: PrimaryButton(
              label: 'Book this service',
              onPressed: () => context.push(
                  '/book/${s.id}${_car == null ? '' : '?car=${_car!.name}'}'),
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
        'After you send the booking, WhatsApp opens with your details filled in. '
            'Our team replies to confirm the slot, usually within $kConfirmWithin.'
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
        'Yes. Message us on WhatsApp or call before your slot and we\'ll find a new time.'
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
              title: Text(faqs[i].$1,
                  style: AppText.bodyStrong.copyWith(fontSize: 14.5)),
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
