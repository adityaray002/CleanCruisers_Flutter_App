import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/service.dart';
import '../widgets/contact_actions.dart';
import '../widgets/service_widgets.dart';
import '../widgets/ui.dart';

class ServicesScreen extends StatefulWidget {
  final ServiceCategory? initialCategory;
  const ServicesScreen({super.key, this.initialCategory});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  ServiceCategory? _cat;

  static const _intro = {
    ServiceCategory.wash:
        'A regular clean. Pick outside, inside, both, or a quick bucket wash.',
    ServiceCategory.detailing:
        'For dull paint, light scratches or a stained interior. Longer, deeper work.',
    ServiceCategory.monthly:
        'A clean car all month. Pick 3 full washes or 4 bucket washes.',
  };

  @override
  void initState() {
    super.initState();
    _cat = widget.initialCategory;
  }

  @override
  void didUpdateWidget(ServicesScreen old) {
    super.didUpdateWidget(old);
    if (old.initialCategory != widget.initialCategory) {
      _cat = widget.initialCategory;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = _cat == null ? ServiceCategory.values : [_cat!];
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a service')),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.page, vertical: 6),
              children: [
                _chip('All', null),
                for (final c in ServiceCategory.values)
                  _chip(serviceCategoryNames[c]!, c),
              ],
            ),
          ),
        ),
        for (final c in cats) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.page, 20, AppSpace.page, 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                        header: true,
                        child:
                            Text(serviceCategoryNames[c]!, style: AppText.h2)),
                    const SizedBox(height: 4),
                    Text(_intro[c]!, style: AppText.small),
                  ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
            sliver: SliverList.separated(
              itemCount: servicesIn(c).length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpace.md),
              itemBuilder: (_, i) => ServiceRow(servicesIn(c)[i]),
            ),
          ),
        ],
        SliverToBoxAdapter(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(AppSpace.page, 28, AppSpace.page, 32),
            child: AppCard(
              color: AppColors.surfaceAlt,
              child: Row(children: [
                const IconBadge(Icons.support_agent_rounded),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Not sure which one?', style: AppText.bodyStrong),
                        Text(
                            'Send us a photo of your car and we\'ll suggest the right service.',
                            style: AppText.small),
                      ]),
                ),
                const SizedBox(width: 8),
                SecondaryButton(
                  label: 'Ask',
                  expand: false,
                  dense: true,
                  onPressed: () => openWhatsApp(context,
                      message:
                          'Hi CleanCruisers, which service would you recommend for my car?'),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _chip(String label, ServiceCategory? c) {
    final selected = _cat == c;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? AppColors.ink : AppColors.surface,
          shape: StadiumBorder(
              side: BorderSide(
                  color: selected ? AppColors.ink : AppColors.border)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => setState(() => _cat = c),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Text(label,
                  style: AppText.smallStrong.copyWith(
                      color: selected ? Colors.white : AppColors.text)),
            ),
          ),
        ),
      ),
    );
  }
}
