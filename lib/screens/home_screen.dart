import 'dart:async';
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
import '../widgets/contact_actions.dart';
import '../widgets/motion.dart';
import '../widgets/service_widgets.dart';
import '../widgets/ui.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(bookingsProvider);
    final next = bookings.where((b) => b.isUpcoming()).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    // Offer one-tap rebooking of the most recent past booking.
    final hiddenRef = ref.watch(hiddenRebookProvider);
    final latest = next.isEmpty
        ? bookings.where((b) => serviceById(b.serviceId) != null).firstOrNull
        : null;
    final last = latest?.ref == hiddenRef ? null : latest;

    void hideRebook(String bookingRef) {
      ref.read(hiddenRebookProvider.notifier).hide(bookingRef);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: const Text('Book again card hidden'),
          action: SnackBarAction(
              label: 'Undo',
              onPressed: () =>
                  ref.read(hiddenRebookProvider.notifier).unhide()),
        ));
    }

    final car = ref.watch(profileProvider).car;

    Widget padded(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
        child: child);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayDark.copyWith(
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: _Hero(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (next.isNotEmpty) ...[
                      padded(_QuickCard(
                        icon: Icons.event_available_rounded,
                        overline: 'YOUR NEXT BOOKING',
                        title: next.first.serviceName,
                        subtitle:
                            '${friendlyDate(next.first.date)} · ${next.first.slotLabel}',
                        onTap: () =>
                            context.push('/bookings/${next.first.ref}'),
                      )),
                      const SizedBox(height: 28),
                    ] else if (last != null) ...[
                      padded(Dismissible(
                        key: ValueKey('rebook-${last.ref}'),
                        onDismissed: (_) => hideRebook(last.ref),
                        child: _QuickCard(
                          icon: Icons.replay_rounded,
                          overline: 'BOOK AGAIN',
                          title: last.serviceName,
                          subtitle:
                              '${last.carLabel} · ${rupees(serviceById(last.serviceId)!.priceFor(last.car))}',
                          onTap: () => context.push(
                              '/book/${last.serviceId}?car=${last.car.name}'),
                          onClose: () => hideRebook(last.ref),
                        ),
                      )),
                      const SizedBox(height: 28),
                    ],
                    Reveal(child: _WashSection(car: car)),
                    const SizedBox(height: 32),
                    Reveal(child: _DetailingSection(car: car)),
                    const SizedBox(height: 32),
                    const Reveal(child: _PlanSection()),
                    const SizedBox(height: 32),
                    Reveal(child: padded(const _HelpCard())),
                  ]),
            ),
          ),
          const SliverToBoxAdapter(child: _Tagline()),
        ]),
      ),
    );
  }
}

// ── Hero: carousel + content panel ────────────────────────────────────────────
/// Full-bleed photo carousel; a rounded panel holding [child] slides over its
/// bottom edge.
class _Hero extends StatelessWidget {
  final Widget child;
  const _Hero({required this.child});

  static const _overlap = 28.0;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final photoH = (mq.size.height * 0.5).clamp(340.0, 440.0);

    return Stack(children: [
      SizedBox(
        height: photoH,
        child: const _Carousel(bottomInset: _overlap),
      ),
      Positioned(
        top: mq.padding.top + 10,
        left: AppSpace.page,
        right: AppSpace.page,
        child: const _TopBar(),
      ),
      Padding(
        padding: EdgeInsets.only(top: photoH - _overlap),
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(_overlap)),
          ),
          padding: const EdgeInsets.only(top: 24),
          child: child,
        ),
      ),
    ]);
  }
}

/// A carousel slide: either a photo, or a designed brand banner (no photo)
/// built around a large icon.
class _Slide {
  final String line1, line2, caption, route;
  final String? image;
  final IconData icon;
  final Alignment align;
  const _Slide(this.line1, this.line2, this.caption, this.route,
      {this.image,
      this.icon = Icons.local_car_wash_rounded,
      this.align = Alignment.center});
}

class _Carousel extends StatefulWidget {
  final double bottomInset;
  const _Carousel({required this.bottomInset});

  @override
  State<_Carousel> createState() => _CarouselState();
}

class _CarouselState extends State<_Carousel> {
  static const _interval = Duration(seconds: 4);

  late final List<_Slide> _slides = [
    const _Slide('DOORSTEP', 'CAR WASH', 'Foam wash at your home or office',
        '/services?cat=wash',
        image: 'assets/images/hero_team_kit.jpg', align: Alignment(0, -0.3)),
    const _Slide('SHOWROOM', 'SHINE', '3M wax & machine rubbing',
        '/services?cat=detailing',
        image: 'assets/images/wax_finish.jpg',
        icon: Icons.auto_awesome_rounded,
        align: Alignment(0, -0.1)),
    _Slide(
        '3 WASHES',
        'A MONTH',
        'Monthly plan · ${rupees(serviceById('monthly-3')!.fromPrice)}/month',
        '/service/monthly-3',
        image: 'assets/images/clean_suv.jpg',
        icon: Icons.event_repeat_rounded,
        align: const Alignment(0, -0.2)),
    if (kPayAfterService)
      const _Slide('PAY AFTER', 'THE SERVICE',
          'No advance. Check your car first.', '/services',
          image: 'assets/images/wheel_before_after.jpg',
          icon: Icons.verified_user_rounded,
          align: Alignment(0, 0.3)),
  ];

  // Start far into an endless list so it can loop in both directions.
  late final _page = PageController(initialPage: _slides.length * 1000);
  Timer? _timer;
  int _index = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restart();
  }

  void _restart() {
    _timer?.cancel();
    if (reduceMotion(context)) return;
    _timer = Timer.periodic(_interval, (_) {
      if (_page.hasClients) {
        _page.nextPage(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      // Pause auto-advance while the user is swiping.
      NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollStartNotification && n.dragDetails != null) {
            _timer?.cancel();
          } else if (n is ScrollEndNotification) {
            _restart();
          }
          return false;
        },
        child: PageView.builder(
          controller: _page,
          onPageChanged: (i) => setState(() => _index = i % _slides.length),
          itemBuilder: (_, i) => _SlideView(_slides[i % _slides.length],
              bottomInset: widget.bottomInset),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: widget.bottomInset + 14,
        child: IgnorePointer(
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < _slides.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _index ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _index ? Colors.white : const Color(0x80FFFFFF),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
          ]),
        ),
      ),
    ]);
  }
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  final double bottomInset;
  const _SlideView(this.slide, {required this.bottomInset});

  @override
  Widget build(BuildContext context) {
    final headline = AppText.display.copyWith(
        color: Colors.white, fontSize: 32, height: 1.0, letterSpacing: -0.5);
    final image = slide.image;
    // Big headline on a fixed-size banner: cap system text scaling so it
    // never runs into the top bar.
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
          textScaler:
              MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.1)),
      child: GestureDetector(
        onTap: () => context.go(slide.route),
        child: Stack(fit: StackFit.expand, children: [
          if (image != null)
            ClipRect(
              child: KenBurns(
                child: Image.asset(image,
                    fit: BoxFit.cover,
                    alignment: slide.align,
                    semanticLabel: '${slide.line1} ${slide.line2}'),
              ),
            )
          else
            _BannerArt(slide.icon, bottomInset: bottomInset),
          // Dark behind the top bar and the headline; the middle stays clear.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                // Strong black from the bottom so the headline always reads.
                stops: [0, 0.25, 0.4, 0.7, 1],
                colors: [
                  Color(0xA6000000),
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0xB3000000),
                  Color(0xF2000000),
                ],
              ),
            ),
          ),
          Positioned(
            left: AppSpace.page,
            right: AppSpace.page,
            bottom: bottomInset + 38,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(slide.line1, style: headline),
              Text(slide.line2,
                  style: headline.copyWith(color: AppColors.brand)),
              const SizedBox(height: 8),
              Row(children: [
                Flexible(
                  child: Text(slide.caption,
                      style: AppText.smallStrong.copyWith(color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_rounded,
                    size: 16, color: Colors.white),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Designed banner background: brand-dark gradient, a soft green glow and a
/// large outlined icon on the right, above where the headline sits.
class _BannerArt extends StatelessWidget {
  final IconData icon;
  final double bottomInset;
  const _BannerArt(this.icon, {required this.bottomInset});

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.ink, Color(0xFF0F3D24)],
          ),
        ),
      ),
      Positioned(
        right: -60,
        top: 40,
        child: Container(
          width: 280,
          height: 280,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient:
                RadialGradient(colors: [Color(0x551DE874), Color(0x001DE874)]),
          ),
        ),
      ),
      Positioned(
        right: 24,
        top: 0,
        bottom: bottomInset + 40,
        child: Center(
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0x14FFFFFF),
              border: Border.all(color: const Color(0x331DE874), width: 1.5),
            ),
            child: Icon(icon, size: 72, color: AppColors.brand),
          ),
        ),
      ),
    ]);
  }
}

/// Location on the left, the customer's car (or a call button) on the right.
class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final hasAddress = profile.address.trim().isNotEmpty;
    final carLabel = profile.carModel.trim().isNotEmpty
        ? profile.carModel.trim()
        : profile.car == null
            ? null
            : carTypeNames[profile.car];

    return Row(children: [
      Expanded(
        child: GestureDetector(
          onTap: () => context.go('/profile'),
          child: Row(children: [
            if (hasAddress)
              const Icon(Icons.location_on_rounded,
                  color: Colors.white, size: 30)
            else
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: ClipOval(
                    child: Image.asset('assets/images/logo.png',
                        width: 34, height: 34)),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hasAddress ? 'Home' : 'CleanCruisers',
                        style: AppText.h3
                            .copyWith(color: Colors.white, fontSize: 17),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(
                        hasAddress
                            ? profile.address.trim()
                            : 'Doorstep car care · $kCityLabel',
                        style: AppText.caption.copyWith(color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ]),
            ),
          ]),
        ),
      ),
      const SizedBox(width: 8),
      _Chip(
        icon: carLabel == null
            ? Icons.call_rounded
            : Icons.directions_car_filled_rounded,
        label: carLabel ?? 'Call',
        onTap: carLabel == null
            ? () => callUs(context)
            : () => context.go('/profile'),
      ),
    ]);
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Chip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 150),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    style: AppText.smallStrong,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Sections ──────────────────────────────────────────────────────────────────
/// Price for the customer's car when we know it, otherwise the starting price.
Widget _price(CarService s, CarType? car, {double size = 16}) {
  final exact = car != null || s.samePriceForAll;
  return FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Text.rich(TextSpan(children: [
      if (!exact) TextSpan(text: 'Starts at ', style: AppText.caption),
      TextSpan(
          text: rupees(car != null ? s.priceFor(car) : s.fromPrice),
          style: AppText.price.copyWith(fontSize: size)),
      if (s.priceSuffix.isNotEmpty)
        TextSpan(text: s.priceSuffix, style: AppText.caption),
    ])),
  );
}

/// Section heading: icon, title, one-line subtitle and an optional "See all".
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onSeeAll;
  const _SectionTitle(
      {required this.icon,
      required this.title,
      required this.subtitle,
      this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.page, 0, 8, 12),
      child: Row(children: [
        IconBadge(icon, size: 38),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Semantics(header: true, child: Text(title, style: AppText.h2)),
            Text(subtitle,
                style: AppText.small,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ]),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('See all'),
              Icon(Icons.chevron_right_rounded, size: 18),
            ]),
          )
        else
          const SizedBox(width: 12),
      ]),
    );
  }
}

/// Narrow tiles: cap very large system text so labels stay legible.
Widget _capText(BuildContext context, Widget child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
          textScaler:
              MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.15)),
      child: child,
    );

/// Horizontally scrolling row of [_ServiceCard]s.
class _ServiceScroller extends StatelessWidget {
  final List<String> ids;
  final CarType? car;
  const _ServiceScroller({required this.ids, required this.car});

  @override
  Widget build(BuildContext context) {
    // Height comes from the content so cards never overflow.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(AppSpace.page, 0, AppSpace.page, 8),
      child: _capText(
        context,
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < ids.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              _ServiceCard(service: serviceById(ids[i])!, car: car),
            ],
          ]),
        ),
      ),
    );
  }
}

// ── Car wash: horizontally scrolling cards ────────────────────────────────────
class _WashSection extends StatelessWidget {
  final CarType? car;
  const _WashSection({required this.car});

  static const _order = [
    'wash-full',
    'wash-exterior',
    'wash-interior',
    'wash-bucket',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _SectionTitle(
        icon: Icons.local_car_wash_rounded,
        title: 'Car Wash',
        subtitle: car == null
            ? 'At your doorstep · 30 min – 2 hrs'
            : 'Prices for your ${carTypeNames[car]}',
        onSeeAll: () => context.go('/services?cat=wash'),
      ),
      _ServiceScroller(ids: _order, car: car),
    ]);
  }
}

// ── Detailing: horizontally scrolling cards ───────────────────────────────────
class _DetailingSection extends StatelessWidget {
  final CarType? car;
  const _DetailingSection({required this.car});

  static const _order = [
    'full-package',
    '3m-wax-exterior',
    'rubbing-exterior',
    'rubbing-wax-exterior',
    'dry-cleaning',
    'dryclean-wax-exterior',
    'rubbing-dryclean-exterior',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _SectionTitle(
        icon: Icons.auto_awesome_rounded,
        title: 'Detailing & Polish',
        subtitle: 'Shine & scratch removal',
        onSeeAll: () => context.go('/services?cat=detailing'),
      ),
      _ServiceScroller(ids: _order, car: car),
    ]);
  }
}

class _ServiceCard extends StatelessWidget {
  final CarService service;
  final CarType? car;
  const _ServiceCard({required this.service, required this.car});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 164,
      child: AppCard(
        onTap: () => context.push('/service/${service.id}'),
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Service photo; brand-dark icon art when there is no photo.
          Container(
            height: 100,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.ink, Color(0xFF0F3D24)],
              ),
            ),
            child: Stack(fit: StackFit.expand, children: [
              if (service.cardPhoto != null) ...[
                Image.asset(service.cardPhoto!,
                    fit: BoxFit.cover,
                    cacheWidth: 500, // card is ~164dp wide; keep decode small
                    excludeFromSemantics: true),
                if (!service.cardPhotoHasLogo) const CornerBrandMark(),
                // Darken the top so the badge stays readable on any photo.
                if (service.badge != null)
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        colors: [Color(0x80000000), Color(0x00000000)],
                      ),
                    ),
                  ),
              ] else ...[
                Positioned(
                  right: -8,
                  bottom: -12,
                  child: Icon(service.icon,
                      size: 72, color: const Color(0x261DE874)),
                ),
                Positioned(
                  left: 12,
                  bottom: 10,
                  child: Icon(service.icon, size: 28, color: AppColors.brand),
                ),
              ],
              if (service.badge != null)
                Positioned(
                  left: 12,
                  top: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(service.badge!.toUpperCase(),
                        style: AppText.overline
                            .copyWith(color: AppColors.ink, fontSize: 9)),
                  ),
                ),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service.name,
                        style: AppText.bodyStrong.copyWith(fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.schedule_rounded,
                          size: 13, color: AppColors.textSubtle),
                      const SizedBox(width: 4),
                      Text(service.duration, style: AppText.caption),
                    ]),
                    const Spacer(),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _price(service, car)),
                      const SizedBox(width: 6),
                      Container(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(
                            color: AppColors.primarySoft,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.arrow_forward_rounded,
                            size: 15, color: AppColors.primary),
                      ),
                    ]),
                  ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Monthly plan ──────────────────────────────────────────────────────────────
class _PlanSection extends StatelessWidget {
  const _PlanSection();

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _SectionTitle(
        icon: Icons.event_repeat_rounded,
        title: 'Monthly Plan',
        subtitle: 'A clean car all month, no re-booking',
        onSeeAll: () => context.go('/services?cat=monthly'),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const _PromoBanner(),
          const SizedBox(height: 10),
          _BucketPlanCard(plan: serviceById('monthly-bucket')!),
        ]),
      ),
    ]);
  }
}

class _BucketPlanCard extends StatelessWidget {
  final CarService plan;
  const _BucketPlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push('/service/${plan.id}'),
      child: Row(children: [
        IconBadge(plan.icon),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('4 bucket washes a month', style: AppText.bodyStrong),
            const SizedBox(height: 2),
            Text(plan.tagline, style: AppText.small),
            const SizedBox(height: 6),
            _price(plan, null),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.textSubtle),
      ]),
    );
  }
}

// ── Help ──────────────────────────────────────────────────────────────────────
class _HelpCard extends StatelessWidget {
  const _HelpCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const IconBadge(Icons.support_agent_rounded, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Not sure what to book?', style: AppText.h3),
              const SizedBox(height: 2),
              Text(
                  'Tell us about your car and we\'ll suggest the right service.',
                  style: AppText.small),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: PrimaryButton(
                label: 'Chat on WhatsApp',
                icon: Icons.chat_rounded,
                dense: true,
                onPressed: () => openWhatsApp(context)),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 48,
            height: 44,
            child: Tooltip(
              message: 'Call us',
              child: OutlinedButton(
                onPressed: () => callUs(context),
                style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero, minimumSize: const Size(48, 44)),
                child: const Icon(Icons.call_rounded,
                    size: 20, color: AppColors.primary),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ── Next booking / book again ─────────────────────────────────────────────────
class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String overline, title, subtitle;
  final VoidCallback onTap;
  final VoidCallback? onClose; // shows a ✕ that hides the card
  const _QuickCard({
    required this.icon,
    required this.overline,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: onClose == null
          ? const EdgeInsets.all(AppSpace.lg)
          : const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, 4, AppSpace.lg),
      child: Row(children: [
        IconBadge(icon),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(overline, style: AppText.overline),
            const SizedBox(height: 3),
            Text(title, style: AppText.bodyStrong),
            Text(subtitle, style: AppText.small),
          ]),
        ),
        if (onClose == null)
          const Icon(Icons.chevron_right_rounded, color: AppColors.textSubtle)
        else
          IconButton(
            onPressed: onClose,
            tooltip: 'Hide',
            icon: const Icon(Icons.close_rounded,
                size: 20, color: AppColors.textSubtle),
          ),
      ]),
    );
  }
}

// ── Promo banner ──────────────────────────────────────────────────────────────
class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context) {
    final plan = serviceById('monthly-3')!;
    return PressScale(
      child: GestureDetector(
        onTap: () => context.push('/service/${plan.id}'),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.ink, Color(0xFF0F3D24)],
              ),
            ),
            child: Stack(children: [
              // Decorative icon art on the right.
              const Positioned(
                right: -18,
                bottom: -22,
                child: Icon(Icons.event_repeat_rounded,
                    size: 150, color: Color(0x261DE874)),
              ),
              Positioned(
                right: 18,
                top: 18,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0x14FFFFFF),
                    border: Border.all(color: const Color(0x331DE874)),
                  ),
                  child: const Icon(Icons.local_car_wash_rounded,
                      color: AppColors.brand, size: 26),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 84, 18),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.brand,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                            (plan.badge ?? 'Monthly plan').toUpperCase(),
                            style: AppText.overline
                                .copyWith(color: AppColors.ink)),
                      ),
                      const SizedBox(height: 10),
                      Text('3 washes a month,\nno re-booking',
                          style: AppText.h2.copyWith(color: Colors.white)),
                      const SizedBox(height: 6),
                      Text(
                          '${rupees(plan.fromPrice)}${plan.priceSuffix} · at your door',
                          style: AppText.small
                              .copyWith(color: const Color(0xFFD1D5DB))),
                      const SizedBox(height: 12),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('View plan',
                            style: AppText.smallStrong
                                .copyWith(color: AppColors.brand)),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_rounded,
                            size: 16, color: AppColors.brand),
                      ]),
                    ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Tagline footer ────────────────────────────────────────────────────────────
class _Tagline extends StatelessWidget {
  const _Tagline();

  @override
  Widget build(BuildContext context) {
    final proof = [
      if (kRatingValue != null) '★ $kRatingValue',
      if (kCustomersServed != null) '$kCustomersServed customers',
      if (kEstablished != null) 'Since $kEstablished',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.page, 40, AppSpace.page, 32),
      child: Column(children: [
        Text('Doorstep car care\nacross $kCityLabel',
            textAlign: TextAlign.center,
            style: AppText.h1.copyWith(
                fontSize: 26,
                color: AppColors.textSubtle.withValues(alpha: 0.35))),
        if (proof.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(proof.join('  ·  '),
              textAlign: TextAlign.center, style: AppText.caption),
        ],
      ]),
    );
  }
}
