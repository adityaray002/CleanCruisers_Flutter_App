import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import '../core/pricing.dart';
import '../models/booking_state.dart';
import '../providers/booking_provider.dart';
import '../widgets/green_button.dart';
import '../widgets/inclusion_chip.dart';

class BookingScreen extends ConsumerStatefulWidget {
  final String? preselectedService;
  const BookingScreen({super.key, this.preselectedService});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  @override
  void initState() {
    super.initState();
    final svc = widget.preselectedService;
    if (svc != null) {
      // Pre-select service type from query param (e.g. home screen cards)
      ServiceType? type;
      if (svc == 'oneTime') type = ServiceType.oneTime;
      if (svc == 'premiumAddons') type = ServiceType.premiumAddons;
      if (svc == 'completeCare') type = ServiceType.completeCare;
      if (type != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(bookingProvider.notifier).selectServiceType(type!);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookingProvider);
    return PopScope(
      canPop: state.step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(bookingProvider.notifier).prevStep();
      },
      child: Scaffold(
        backgroundColor: kBgBlack,
        appBar: AppBar(
          backgroundColor: kBgBlack,
          leading: state.step == 0
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => ref.read(bookingProvider.notifier).prevStep(),
                ),
          title: Text(_stepTitle(state)),
          actions: [
            if (state.step > 0)
              TextButton(
                onPressed: () => ref.read(bookingProvider.notifier).reset(),
                child: const Text('Reset',
                    style: TextStyle(color: kGray400, fontSize: 13)),
              ),
          ],
        ),
        body: Column(
          children: [
            if (state.step > 0) _ProgressBar(state: state),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, anim) {
                  // Direction-aware slide: forward→right, backward→left
                  final begin = state.forward
                      ? const Offset(0.05, 0)
                      : const Offset(-0.05, 0);
                  return SlideTransition(
                    position: Tween<Offset>(begin: begin, end: Offset.zero)
                        .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                    child: FadeTransition(opacity: anim, child: child),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(state.step),
                  child: _buildStep(context, ref, state),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _stepTitle(BookingState s) {
    if (s.step == 0) return 'Choose Service';
    switch (s.serviceType) {
      case ServiceType.oneTime:
        return [
          'Car Wash & Care',
          'Select Car Type',
          'Choose Package',
          'Add-ons (Optional)',
          'Your Details',
          'Confirm Booking',
        ][s.step.clamp(0, 5)];
      case ServiceType.premiumAddons:
        return [
          'Complete Car Care',
          'Select Car Type',
          'Select Services',
          'Your Details',
          'Confirm Booking',
        ][s.step.clamp(0, 4)];
      case ServiceType.completeCare:
        return [
          'Monthly Package',
          'Select Car Type',
          'Package Details',
          'Your Details',
          'Confirm Booking',
        ][s.step.clamp(0, 4)];
    }
  }

  Widget _buildStep(BuildContext ctx, WidgetRef ref, BookingState state) {
    if (state.step == 0) return const _ServiceTypeStep();
    switch (state.serviceType) {
      case ServiceType.oneTime:
        switch (state.step) {
          case 1: return const _CarTypeStep();
          case 2: return _WashPackageStep(state: state);
          case 3: return _WashAddonsStep(state: state);
          case 4: return _DetailsStep(state: state);
          case 5: return _SummaryStep(state: state);
        }
      case ServiceType.premiumAddons:
        switch (state.step) {
          case 1: return const _CarTypeStep();
          case 2: return _PremiumAddonsStep(state: state);
          case 3: return _DetailsStep(state: state);
          case 4: return _SummaryStep(state: state);
        }
      case ServiceType.completeCare:
        switch (state.step) {
          case 1: return const _CarTypeStep();
          case 2: return _CompleteCareStep(state: state);
          case 3: return _DetailsStep(state: state);
          case 4: return _SummaryStep(state: state);
        }
    }
    return const SizedBox.shrink();
  }
}

// ── Progress Bar ──────────────────────────────────────────────────────────────
class _ProgressBar extends StatelessWidget {
  final BookingState state;
  const _ProgressBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final progress = state.step / state.totalSteps;
    return Column(
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: kGray700,
          valueColor: const AlwaysStoppedAnimation<Color>(kGreen400),
          minHeight: 3,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Step ${state.step} of ${state.totalSteps}',
                  style: const TextStyle(color: kGray400, fontSize: 12)),
              Text('${(progress * 100).round()}% complete',
                  style: const TextStyle(
                      color: kGreen400, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Step 0: Service Type ─────────────────────────────────────────────────────
class _ServiceTypeStep extends ConsumerWidget {
  const _ServiceTypeStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Choose a Service',
              style: TextStyle(
                  color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.location_on, size: 13, color: kGreen400),
            const SizedBox(width: 4),
            Text('Delhi NCR  ·  8AM – 6PM  ·  No advance payment',
                style: TextStyle(color: kGray400.withAlpha(200), fontSize: 12)),
          ]),
          const SizedBox(height: 28),
          _ServiceCard(
            imagePath: 'assets/images/service_carwash.jpg',
            badge: null,
            title: 'Car Wash & Care',
            subtitle: 'Quick one-time doorstep wash',
            price: '₹${washPackagePrices[WashPackage.exteriorOnly]![CarType.hatchback]!}',
            features: const [
              'High-pressure foam wash',
              'Interior vacuum & wipe',
              'Tyre dressing & dash polish',
            ],
            duration: '1 – 2 hrs',
            type: ServiceType.oneTime,
          ),
          const SizedBox(height: 16),
          _ServiceCard(
            imagePath: 'assets/images/service_detailing.jpg',
            badge: 'POPULAR',
            title: 'Complete Car Care',
            subtitle: 'Deep detailing & polishing',
            price: '₹${premiumAddonPrices['3m-wax-exterior']![CarType.hatchback]!}',
            features: const [
              'Rubbing, buffing & paint restore',
              '3M wax for lasting shine',
              'Interior dry clean & deodorize',
            ],
            duration: '2 – 3 hrs',
            type: ServiceType.premiumAddons,
          ),
          const SizedBox(height: 16),
          _ServiceCard(
            imagePath: 'assets/images/service_monthly.jpg',
            badge: 'BEST VALUE',
            title: 'Monthly Package',
            subtitle: '3 premium washes every month',
            price: '₹${completeCarePrice[CarType.hatchback]!}',
            features: const [
              '3 sessions per month',
              'Interior + exterior each time',
              'Free dustbin & air freshener',
            ],
            duration: '3 sessions / month',
            type: ServiceType.completeCare,
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends ConsumerWidget {
  final String imagePath;
  final String? badge;
  final String title, subtitle, price, duration;
  final List<String> features;
  final ServiceType type;

  const _ServiceCard({
    required this.imagePath,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.features,
    required this.duration,
    required this.type,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        ref.read(bookingProvider.notifier).selectServiceType(type);
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: kBgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kGray700.withAlpha(80)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Photo header ──────────────────────────────────────────────────
            SizedBox(
              height: 130,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(imagePath, fit: BoxFit.cover),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x22000000), Color(0xBB000000)],
                      ),
                    ),
                  ),
                  if (badge != null)
                    Positioned(
                      top: 10, left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: kGreen400.withAlpha(40),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: kGreen400.withAlpha(160)),
                        ),
                        child: Text(badge!,
                            style: const TextStyle(
                                color: kGreen400,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8)),
                      ),
                    ),
                ],
              ),
            ),

            // ── Card body ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('from',
                              style: TextStyle(
                                  color: kGray400.withAlpha(150),
                                  fontSize: 10)),
                          Text(price,
                              style: const TextStyle(
                                  color: kGreen400,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(color: kGray400, fontSize: 12)),
                  const SizedBox(height: 12),

                  // Features
                  ...features.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Icon(Icons.check_circle,
                              size: 13, color: kGreen400.withAlpha(200)),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(f,
                              style: const TextStyle(
                                  color: kGray400,
                                  fontSize: 12.5,
                                  height: 1.3)),
                        ),
                      ],
                    ),
                  )),

                  const SizedBox(height: 10),
                  Divider(height: 1, color: kGray700.withAlpha(80)),
                  const SizedBox(height: 10),

                  // Footer: duration + CTA
                  Row(
                    children: [
                      Icon(Icons.schedule,
                          size: 12, color: kGray400.withAlpha(150)),
                      const SizedBox(width: 4),
                      Text(duration,
                          style: TextStyle(
                              color: kGray400.withAlpha(150),
                              fontSize: 11.5)),
                      const Spacer(),
                      const Text('Book now',
                          style: TextStyle(
                              color: kGreen400,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(width: 3),
                      const Icon(Icons.arrow_forward,
                          size: 13, color: kGreen400),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 1: Car Type ──────────────────────────────────────────────────────────
class _CarTypeStep extends ConsumerWidget {
  const _CarTypeStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('What type of car\ndo you have?',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24, fontWeight: FontWeight.w800, height: 1.2)),
          const SizedBox(height: 8),
          const Text('Pricing varies by car size.',
              style: TextStyle(color: kGray400, fontSize: 14)),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(children: [
                  _CarCard(car: CarType.hatchback),
                  const SizedBox(height: 14),
                  _CarCard(car: CarType.suv),
                ]),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(children: [
                  _CarCard(car: CarType.sedan),
                  const SizedBox(height: 14),
                  _CarCard(car: CarType.luxury),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CarCard extends ConsumerWidget {
  final CarType car;
  const _CarCard({required this.car});

  static const _examples = {
    CarType.hatchback: 'Maruti Swift, WagonR, i20',
    CarType.sedan: 'Honda City, Dzire, Verna',
    CarType.suv: 'Creta, Brezza, Fortuner',
    CarType.luxury: 'BMW, Audi, Mercedes',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        ref.read(bookingProvider.notifier).selectCarType(car);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: kBgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kGray700.withAlpha(128)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(carTypeIcons[car]!, style: const TextStyle(fontSize: 38)),
            const SizedBox(height: 8),
            Text(carTypeNames[car]!,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(_examples[car]!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: kGray400, fontSize: 9),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            const Text('Tap to select →',
                style: TextStyle(
                    color: kGreen400, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Step 2 (oneTime): Wash Package ────────────────────────────────────────────
class _WashPackageStep extends ConsumerWidget {
  final BookingState state;
  const _WashPackageStep({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final car = state.carType!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Choose your wash\npackage for ${carTypeNames[car]}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24, fontWeight: FontWeight.w800, height: 1.2)),
          const SizedBox(height: 28),
          ...WashPackage.values.map((pkg) {
            final price = washPackagePrices[pkg]![car]!;
            final inclusions = washPackageInclusions[pkg]!;
            return _PackageCard(
              pkg: pkg,
              price: price,
              inclusions: inclusions,
              isSelected: state.washPackage == pkg,
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(bookingProvider.notifier).selectWashPackage(pkg);
              },
            );
          }),
        ],
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final WashPackage pkg;
  final int price;
  final List<String> inclusions;
  final bool isSelected;
  final VoidCallback onTap;

  const _PackageCard({
    required this.pkg, required this.price, required this.inclusions,
    required this.isSelected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: kBgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? kGreen400 : kGray700.withAlpha(128),
            width: isSelected ? 2 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(washPackageNames[pkg]!,
                    style: TextStyle(
                        color: isSelected ? kGreen400 : Colors.white,
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              PriceTag(price: price),
            ]),
            const SizedBox(height: 14),
            ...inclusions.map((s) => InclusionItem(s)),
            const SizedBox(height: 10),
            if (isSelected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: kGreen400.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_circle, color: kGreen400, size: 14),
                  SizedBox(width: 6),
                  Text('Selected ✓ — tap Next to continue',
                      style: TextStyle(color: kGreen400, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              )
            else
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Tap to select →',
                      style: TextStyle(color: kGreen400, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ── Step 3 (oneTime): Optional Wash Add-ons ───────────────────────────────────
class _WashAddonsStep extends ConsumerWidget {
  final BookingState state;
  const _WashAddonsStep({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addons = state.washAddons;

    int getQty(String id) {
      final item = addons.where((a) => a.id == id);
      return item.isEmpty ? 0 : item.first.qty;
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add extra services?\n(Optional)',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24, fontWeight: FontWeight.w800, height: 1.2)),
                const SizedBox(height: 8),
                const Text('Charged extra. Skip if not needed.',
                    style: TextStyle(color: kGray400, fontSize: 14)),
                const SizedBox(height: 24),
                ...washAddonNames.entries.map((e) {
                  final id = e.key;
                  final name = e.value;
                  final price = washAddonPrices[id]!;
                  final qty = getQty(id);
                  final isSeat = id == 'seat';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kBgCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: qty > 0 ? kGreen400.withAlpha(128) : kGray700.withAlpha(128),
                      ),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            Text('₹$price${isSeat ? " per seat" : ""}',
                                style: const TextStyle(
                                    color: kGreen400, fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      if (isSeat)
                        _QtySelector(
                          qty: qty, max: 7,
                          onChanged: (v) {
                            HapticFeedback.selectionClick();
                            ref.read(bookingProvider.notifier).setWashAddonQty(id, v);
                          },
                        )
                      else
                        Switch(
                          value: qty > 0,
                          activeThumbColor: kGreen400,
                          activeTrackColor: kGreen400.withAlpha(100),
                          onChanged: (v) {
                            HapticFeedback.selectionClick();
                            ref.read(bookingProvider.notifier).setWashAddonQty(id, v ? 1 : 0);
                          },
                        ),
                    ]),
                  );
                }),
              ],
            ),
          ),
        ),
        _BottomBar(
          total: state.computeTotal(),
          label: 'Next: Your Details',
          onTap: () => ref.read(bookingProvider.notifier).nextStep(),
          skipLabel: 'Skip Add-ons',
          onSkip: () => ref.read(bookingProvider.notifier).nextStep(),
        ),
      ],
    );
  }
}

class _QtySelector extends StatelessWidget {
  final int qty;
  final int max;
  final ValueChanged<int> onChanged;
  const _QtySelector({required this.qty, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      IconButton(
        icon: const Icon(Icons.remove_circle_outline, color: kGreen400),
        onPressed: qty > 0 ? () => onChanged(qty - 1) : null,
      ),
      Text('$qty',
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
      IconButton(
        icon: const Icon(Icons.add_circle_outline, color: kGreen400),
        onPressed: qty < max ? () => onChanged(qty + 1) : null,
      ),
    ]);
  }
}

// ── Step 2 (premiumAddons): Premium Add-ons ───────────────────────────────────
class _PremiumAddonsStep extends ConsumerWidget {
  final BookingState state;
  const _PremiumAddonsStep({required this.state});

  static const _addonEmoji = {
    'rubbing-exterior':         '🪞',
    '3m-wax-exterior':          '✨',
    'rubbing-wax-exterior':     '🏆',
    'full-package':             '💎',
    'rubbing-dryclean-exterior':'🧽',
    'dryclean-wax-exterior':    '🌟',
    'dry-cleaning':             '🧹',
    'air-freshener':            '🌸',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIds = state.selectedAddonIds;
    final car = state.carType!;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Choose detailing\nservices for ${carTypeNames[car]}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24, fontWeight: FontWeight.w800, height: 1.2)),
                const SizedBox(height: 6),
                const Text('Select one or more services. You can mix and match.',
                    style: TextStyle(color: kGray400, fontSize: 13)),
                const SizedBox(height: 6),
                // Selected count badge
                if (selectedIds.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: kGreen400.withAlpha(26),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kGreen400.withAlpha(77)),
                    ),
                    child: Text('${selectedIds.length} service${selectedIds.length > 1 ? "s" : ""} selected',
                        style: const TextStyle(
                            color: kGreen400, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(height: 20),
                ...premiumAddons.map((addon) {
                  final isSelected = selectedIds.contains(addon.id);
                  final price = premiumAddonPrices[addon.id]![car]!;
                  final emoji = _addonEmoji[addon.id] ?? '✨';
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(bookingProvider.notifier).toggleAddon(addon.id);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isSelected ? kGreen400.withAlpha(10) : kBgCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? kGreen400 : kGray700.withAlpha(128),
                          width: isSelected ? 2 : 0.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: emoji + title + price + check badge
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? kGreen400.withAlpha(40)
                                      : kGray700.withAlpha(60),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(emoji,
                                      style: const TextStyle(fontSize: 22)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(addon.name,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14, fontWeight: FontWeight.w700,
                                            height: 1.3)),
                                    const SizedBox(height: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: kGreen400.withAlpha(26),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: kGreen400.withAlpha(77)),
                                      ),
                                      child: Text('₹$price',
                                          style: const TextStyle(
                                              color: kGreen400, fontSize: 12,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  width: 26, height: 26,
                                  decoration: const BoxDecoration(
                                      color: kGreen400, shape: BoxShape.circle),
                                  child: const Icon(Icons.check,
                                      color: Colors.black, size: 16),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Divider(color: kGray700, height: 1),
                          const SizedBox(height: 12),
                          // "What is it?"
                          const Text('What is it?',
                              style: TextStyle(
                                  color: kGray400, fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3)),
                          const SizedBox(height: 4),
                          Text(addon.description,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12, height: 1.5)),
                          const SizedBox(height: 12),
                          // "What's Included?"
                          const Text("What's Included?",
                              style: TextStyle(
                                  color: kGray400, fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3)),
                          const SizedBox(height: 6),
                          ...addon.inclusions.map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.check_circle_outline,
                                    color: isSelected ? kGreen400 : kGray400,
                                    size: 13),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(s,
                                      style: TextStyle(
                                          color: isSelected
                                              ? Colors.white70
                                              : kGray400,
                                          fontSize: 12, height: 1.4)),
                                ),
                              ],
                            ),
                          )),
                          // Tap hint
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (isSelected) ...[
                                const Icon(Icons.check_circle,
                                    color: kGreen400, size: 14),
                                const SizedBox(width: 4),
                                const Text('Selected ✓ — tap to deselect',
                                    style: TextStyle(
                                        color: kGreen400, fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                              ] else
                                const Text('Tap to select →',
                                    style: TextStyle(
                                        color: kGreen400, fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        _BottomBar(
          total: state.computeTotal(),
          label: 'Next: Your Details',
          onTap: selectedIds.isEmpty
              ? null
              : () => ref.read(bookingProvider.notifier).nextStep(),
          disabledNote: selectedIds.isEmpty ? 'Select at least one service' : null,
        ),
      ],
    );
  }
}

// ── Step 2 (completeCare): Package Details ────────────────────────────────────
class _CompleteCareStep extends ConsumerWidget {
  final BookingState state;
  const _CompleteCareStep({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final car = state.carType!;
    final price = completeCarePrice[car]!;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your Monthly Care\nPackage',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24, fontWeight: FontWeight.w800, height: 1.2)),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      kGreen500.withAlpha(26), kBgCard,
                    ]),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: kGreen400.withAlpha(77)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Text('📅', style: TextStyle(fontSize: 28)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Complete Care Monthly Package',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16, fontWeight: FontWeight.w700)),
                              Text('For ${carTypeNames[car]}',
                                  style: const TextStyle(color: kGray400, fontSize: 13)),
                            ],
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      PriceTag(price: price, suffix: '/ month'),
                      const SizedBox(height: 4),
                      const Text('Includes 3 premium washes',
                          style: TextStyle(color: kGray400, fontSize: 12)),
                      const SizedBox(height: 16),
                      const Divider(color: kGray700),
                      const SizedBox(height: 12),
                      const Text("What's Included:",
                          style: TextStyle(
                              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      ...completeCareInclusions.map((s) => InclusionItem(s)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _InfoTile(icon: Icons.calendar_month,
                    label: '3 Washes Per Month',
                    value: 'Scheduled at your convenience'),
                const SizedBox(height: 10),
                _InfoTile(icon: Icons.payment,
                    label: 'No Advance Payment',
                    value: 'Pay after every service'),
                const SizedBox(height: 10),
                _InfoTile(icon: Icons.access_time,
                    label: '7 AM – 8 PM, All Days',
                    value: 'Book any day including weekends'),
              ],
            ),
          ),
        ),
        _BottomBar(
          total: price,
          label: 'Next: Your Details',
          onTap: () => ref.read(bookingProvider.notifier).nextStep(),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGray700.withAlpha(128)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: kGreen400.withAlpha(26), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: kGreen400, size: 18),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(color: kGray400, fontSize: 12)),
        ]),
      ]),
    );
  }
}

// ── Step: Customer Details ────────────────────────────────────────────────────
class _DetailsStep extends ConsumerStatefulWidget {
  final BookingState state;
  const _DetailsStep({required this.state});

  @override
  ConsumerState<_DetailsStep> createState() => _DetailsStepState();
}

class _DetailsStepState extends ConsumerState<_DetailsStep> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _locCtrl;
  late final TextEditingController _modelCtrl;
  bool _loadingGps = false;

  static const _timeSlots = [
    'Morning (7 AM – 11 AM)',
    'Afternoon (11 AM – 3 PM)',
    'Evening (3 PM – 8 PM)',
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.state;
    _nameCtrl  = TextEditingController(text: s.name);
    _phoneCtrl = TextEditingController(text: s.phone);
    _locCtrl   = TextEditingController(text: s.location);
    _modelCtrl = TextEditingController(text: s.carModel);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _locCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  bool get _valid {
    final phone = _phoneCtrl.text.trim();
    return _nameCtrl.text.trim().isNotEmpty &&
        RegExp(r'^[6-9]\d{9}$').hasMatch(phone);
  }

  Future<void> _getLocation() async {
    setState(() => _loadingGps = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enable Location Services in device settings.'),
              backgroundColor: Color(0xFF374151),
            ),
          );
        }
        setState(() => _loadingGps = false);
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location permission denied. Allow it in app settings.'),
              backgroundColor: const Color(0xFF374151),
              action: SnackBarAction(
                label: 'Settings',
                textColor: kGreen400,
                onPressed: () => Geolocator.openAppSettings(),
              ),
            ),
          );
        }
        setState(() => _loadingGps = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      _locCtrl.text =
          '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      ref.read(bookingProvider.notifier).updateDetails(location: _locCtrl.text);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not get location. Type your address below.'),
            backgroundColor: Color(0xFF374151),
          ),
        );
      }
    }
    setState(() => _loadingGps = false);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.state.preferredDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 14)),
      helpText: 'Choose Wash Date',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: kGreen400,
            onPrimary: Colors.black,
            surface: Color(0xFF141A1C),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      ref.read(bookingProvider.notifier).updateSchedule(date: picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final schedule = widget.state;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your Details',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('We need these to confirm your booking.',
                    style: TextStyle(color: kGray400, fontSize: 14)),
                const SizedBox(height: 28),
                _label('Full Name *'),
                TextField(
                  controller: _nameCtrl,
                  onChanged: (v) {
                    ref.read(bookingProvider.notifier).updateDetails(name: v);
                    setState(() {});
                  },
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Rahul Sharma',
                    prefixIcon: Icon(Icons.person_outline, color: kGray400),
                  ),
                ),
                const SizedBox(height: 18),
                _label('Mobile Number *'),
                TextField(
                  controller: _phoneCtrl,
                  onChanged: (v) {
                    ref.read(bookingProvider.notifier).updateDetails(phone: v);
                    setState(() {});
                  },
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: const InputDecoration(
                    hintText: '10-digit mobile number',
                    prefixIcon: Icon(Icons.phone_outlined, color: kGray400),
                    prefixText: '+91  ',
                    prefixStyle: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 6),
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text(
                    'By confirming, you agree to be contacted on WhatsApp for booking updates.',
                    style: TextStyle(color: kGray400, fontSize: 10, height: 1.4),
                  ),
                ),
                const SizedBox(height: 18),
                _label('Car Model (Optional)'),
                TextField(
                  controller: _modelCtrl,
                  onChanged: (v) {
                    ref.read(bookingProvider.notifier).updateDetails(carModel: v);
                  },
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Maruti Swift, Honda City',
                    prefixIcon: Icon(Icons.directions_car_outlined, color: kGray400),
                  ),
                ),
                const SizedBox(height: 18),
                // Date picker
                _label('Preferred Date (Optional)'),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: kBgCard2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: schedule.preferredDate != null
                              ? kGreen400.withAlpha(128)
                              : kGray700.withAlpha(128)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_outlined,
                          color: kGray400, size: 18),
                      const SizedBox(width: 12),
                      Text(
                        schedule.preferredDate != null
                            ? schedule.formattedDate
                            : 'Tap to choose a date',
                        style: TextStyle(
                          color: schedule.preferredDate != null ? Colors.white : kGray400,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.chevron_right, color: kGray400, size: 18),
                    ]),
                  ),
                ),
                const SizedBox(height: 18),
                // Time slot chips
                _label('Preferred Time Slot (Optional)'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _timeSlots.map((slot) {
                    final isSelected = schedule.preferredTimeSlot == slot;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(bookingProvider.notifier).updateSchedule(
                          timeSlot: isSelected ? '' : slot,
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? kGreen400.withAlpha(26) : kBgCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? kGreen400 : kGray700.withAlpha(128),
                            width: isSelected ? 1.5 : 0.5,
                          ),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (isSelected)
                            const Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: Icon(Icons.check_circle, color: kGreen400, size: 14),
                            ),
                          Text(slot,
                              style: TextStyle(
                                  color: isSelected ? kGreen400 : Colors.white70,
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400)),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                // Location field
                Row(children: [
                  _label('Your Location (Optional)'),
                  const Spacer(),
                  GestureDetector(
                    onTap: _loadingGps ? null : _getLocation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: kGreen400.withAlpha(26),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kGreen400.withAlpha(77)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (_loadingGps)
                          const SizedBox(
                              width: 12, height: 12,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: kGreen400))
                        else
                          const Icon(Icons.gps_fixed, color: kGreen400, size: 14),
                        const SizedBox(width: 5),
                        Text(_loadingGps ? 'Getting...' : 'Use GPS',
                            style: const TextStyle(
                                color: kGreen400, fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                TextField(
                  controller: _locCtrl,
                  onChanged: (v) =>
                      ref.read(bookingProvider.notifier).updateDetails(location: v),
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Flat no., society, area — or tap GPS',
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 20),
                      child: Icon(Icons.location_on_outlined, color: kGray400),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: kGreen400.withAlpha(13),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kGreen400.withAlpha(51)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: kGreen400, size: 16),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No advance payment required. Pay only after service is done.',
                          style: TextStyle(color: kGray400, fontSize: 12, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _BottomBar(
          total: widget.state.computeTotal(),
          label: 'Review Booking',
          onTap: _valid
              ? () {
                  FocusScope.of(context).unfocus();
                  ref.read(bookingProvider.notifier).nextStep();
                }
              : null,
          disabledNote: !_valid ? 'Enter valid name and 10-digit mobile' : null,
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text,
        style: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
  );
}

// ── Summary / Confirm ──────────────────────────────────────────────────────────
class _SummaryStep extends ConsumerStatefulWidget {
  final BookingState state;
  const _SummaryStep({required this.state});

  @override
  ConsumerState<_SummaryStep> createState() => _SummaryStepState();
}

class _SummaryStepState extends ConsumerState<_SummaryStep> {
  bool _sending = false;

  Future<void> _confirm() async {
    if (_sending) return;
    setState(() => _sending = true);

    final msg = widget.state.buildWhatsAppMessage();
    final url = Uri.parse('https://wa.me/$kBookingWhatsApp?text=$msg');

    try {
      final canLaunch = await canLaunchUrl(url);
      if (canLaunch) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        if (mounted) context.push('/booking-success');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('WhatsApp not installed. Call us: $kPhoneDisplay'),
              backgroundColor: const Color(0xFF374151),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Call',
                textColor: kGreen400,
                onPressed: () async {
                  final tel = Uri.parse('tel:$kPhone');
                  if (await canLaunchUrl(tel)) await launchUrl(tel);
                },
              ),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open WhatsApp. Call us: $kPhoneDisplay'),
            backgroundColor: Color(0xFF374151),
          ),
        );
      }
    }

    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final car = state.carType;
    final total = state.computeTotal();

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Review Your\nBooking',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 26, fontWeight: FontWeight.w800, height: 1.2)),
                const SizedBox(height: 8),
                const Text('Tap confirm to proceed on WhatsApp.',
                    style: TextStyle(color: kGray400, fontSize: 14)),
                const SizedBox(height: 24),
                _SummaryCard(
                    icon: Icons.miscellaneous_services,
                    title: 'Service',
                    value: state.serviceTypeLabel),
                const SizedBox(height: 10),
                _SummaryCard(
                    icon: Icons.directions_car,
                    title: 'Car Type',
                    value: car != null ? carTypeNames[car]! : '—'),
                if (state.carModel.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _SummaryCard(
                      icon: Icons.car_repair,
                      title: 'Car Model',
                      value: state.carModel),
                ],
                if (state.serviceType == ServiceType.oneTime &&
                    state.washPackage != null) ...[
                  const SizedBox(height: 10),
                  _SummaryCard(
                      icon: Icons.water_drop,
                      title: 'Package',
                      value: washPackageNames[state.washPackage]!),
                ],
                if (state.serviceType == ServiceType.premiumAddons &&
                    state.selectedAddonIds.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kBgCard, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kGray700.withAlpha(128)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(children: [
                          Icon(Icons.star_outline, color: kGreen400, size: 16),
                          SizedBox(width: 8),
                          Text('Selected Services',
                              style: TextStyle(color: kGray400, fontSize: 12)),
                        ]),
                        const SizedBox(height: 10),
                        ...state.selectedAddonIds.map((id) {
                          final addon = premiumAddons.firstWhere(
                              (a) => a.id == id,
                              orElse: () =>
                                  const AddonService(id: '', name: '', description: '', inclusions: []));
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('• ${addon.name}',
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                _SummaryCard(icon: Icons.person, title: 'Name', value: state.name),
                const SizedBox(height: 10),
                _SummaryCard(
                    icon: Icons.phone,
                    title: 'Phone',
                    value: '+91 ${state.phone}'),
                if (state.preferredDate != null) ...[
                  const SizedBox(height: 10),
                  _SummaryCard(
                      icon: Icons.calendar_today,
                      title: 'Date',
                      value: state.formattedDate),
                ],
                if (state.preferredTimeSlot.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _SummaryCard(
                      icon: Icons.schedule,
                      title: 'Time',
                      value: state.preferredTimeSlot),
                ],
                if (state.location.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _SummaryCard(
                      icon: Icons.location_on,
                      title: 'Location',
                      value: state.location),
                ],
                if (total > 0) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        kGreen500.withAlpha(26), kBgCard,
                      ]),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kGreen400.withAlpha(77)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Estimated Total',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        PriceTag(price: total),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                WhatsAppButton(
                  label: 'Confirm Booking on WhatsApp',
                  loading: _sending,
                  onTap: _confirm,
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    'Our team will confirm your slot within minutes.',
                    style: TextStyle(color: kGray400, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _SummaryCard({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kBgCard, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGray700.withAlpha(128)),
      ),
      child: Row(children: [
        Icon(icon, color: kGreen400, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: kGray400, fontSize: 11)),
            Text(value,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }
}

// ── Bottom Bar ────────────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final int total;
  final String label;
  final VoidCallback? onTap;
  final String? skipLabel;
  final VoidCallback? onSkip;
  final String? disabledNote;

  const _BottomBar({
    required this.total,
    required this.label,
    required this.onTap,
    this.skipLabel,
    this.onSkip,
    this.disabledNote,
  });

  @override
  Widget build(BuildContext context) {
    // SafeArea-aware bottom padding
    final bottomPad = MediaQuery.of(context).padding.bottom + 12;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPad),
      decoration: BoxDecoration(
        color: kBgCard,
        border: const Border(top: BorderSide(color: kGray700, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (disabledNote != null) ...[
            Text(disabledNote!,
                style: const TextStyle(color: kGray400, fontSize: 12)),
            const SizedBox(height: 8),
          ],
          Row(children: [
            if (total > 0) ...[
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Total', style: TextStyle(color: kGray400, fontSize: 11)),
                Text('₹$total',
                    style: const TextStyle(
                        color: kGreen400, fontSize: 20, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: ElevatedButton(
                onPressed: onTap,
                child: Text(label),
              ),
            ),
          ]),
          if (skipLabel != null && onSkip != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onSkip,
              child: Text(skipLabel!,
                  style: const TextStyle(
                      color: kGray400, fontSize: 13,
                      decoration: TextDecoration.underline)),
            ),
          ],
        ],
      ),
    );
  }
}
