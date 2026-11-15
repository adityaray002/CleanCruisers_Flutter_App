import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/format.dart';
import '../core/pricing.dart';
import '../core/scheduling.dart' show Coverage;
import '../core/theme.dart';
import '../data/business_info.dart';
import '../data/offers.dart';
import '../models/booking.dart';
import '../models/service.dart';
import '../widgets/booking_progress.dart';
import '../widgets/brand_header.dart';
import '../providers/app_providers.dart';
import '../widgets/customer_sheets.dart';
import '../widgets/motion.dart';
import '../widgets/trust_widgets.dart';
import '../widgets/ui.dart';

/// Home. Top to bottom:
/// 1. brand, where the car is parked, booking-updates bell,
/// 2. the live booking, if any (first: it answers "when is the expert coming?"),
/// 3. hero carousel + "Book a service" (compact while a booking is live),
/// 4. new customers: offers right away (the first-booking offer leads),
/// 5. "Book again" with the last completed booking, if any,
/// 6. "What does your car need?" — wash and detailing tiles, side by side,
/// 7. new customers: how it works,
/// 8. monthly plan,
/// 9. returning customers: offers,
/// 10. before / after photo (only when kBeforeAfterPhoto is set),
/// 11. why choose us (only facts set in business_info.dart),
/// 12. eco promise (only when kEcoFriendly is confirmed),
/// 13. help.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// Home's gutter is a little tighter than other screens' so the two-up
  /// tiles get room on small phones.
  static const _gutter = AppSpace.lg;

  static EdgeInsets _section({double top = 0, double bottom = AppSpace.xxl}) =>
      EdgeInsets.fromLTRB(_gutter, top, _gutter, bottom);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(myBookingsProvider);
    final car = ref.watch(profileProvider).car;
    final live = bookings.where((b) => !b.status.isFinal).firstOrNull;
    final isNew = bookings.isEmpty;
    final lastDone = (bookings
            .where((b) =>
                b.status == BookingStatus.completed &&
                serviceById(b.serviceId) != null)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date)))
        .firstOrNull;
    // New customers see the first-booking offer in the hero, so the offers
    // section below doesn't repeat it.
    final firstOffer = isNew
        ? kOffers
            .where((o) =>
                o.firstBookingOnly &&
                (o.onlyFor == null ||
                    (car != null && o.onlyFor!.contains(car))))
            .firstOrNull
        : null;
    final offers = Padding(
      padding: _section(),
      child: _Offers(firstBooking: isNew, car: car, skip: firstOffer),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        // Dense cards: system text may grow, but only to 1.15x so the cards
        // keep their shape on small phones.
        body: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.15,
          child: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSpace.sm),
              children: [
                Padding(
                  padding: _section(top: AppSpace.sm, bottom: AppSpace.lg),
                  child: _Header(hasUpdate: live != null),
                ),
                if (live != null)
                  Padding(
                    padding: _section(bottom: AppSpace.lg),
                    child: _LiveBookingCard(booking: live),
                  ),
                Padding(
                  padding: _section(bottom: AppSpace.xxl),
                  child: _HeroCarousel(
                      compact: live != null, firstOffer: firstOffer),
                ),
                if (lastDone != null)
                  Padding(
                    padding: _section(),
                    child: _BookAgain(booking: lastDone),
                  ),
                Padding(
                  padding: _section(),
                  child: Reveal(child: _ServiceTiles(car: car)),
                ),
                if (isNew)
                  Padding(
                    padding: _section(),
                    child: const _HowItWorks(),
                  ),
                if (isNew) offers,
                Padding(
                  padding: _section(),
                  child: Reveal(child: _MonthlyCard(car: car)),
                ),
                if (!isNew) offers,
                if (kBeforeAfterPhoto != null)
                  Padding(
                    padding: _section(),
                    child: _BeforeAfter(photo: kBeforeAfterPhoto!),
                  ),
                Padding(padding: _section(), child: const WhyUsStrip()),
                if (kEcoFriendly)
                  Padding(padding: _section(), child: const _EcoBanner()),
                Padding(padding: _section(), child: const HelpCard()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Section title (H2) + "View all →".
class _SectionTitle extends StatelessWidget {
  final String title;
  final VoidCallback onViewAll;
  const _SectionTitle(this.title, {required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Semantics(header: true, child: Text(title, style: AppText.h3)),
      ),
      const SizedBox(width: AppSpace.sm),
      TextButton(
        onPressed: onViewAll,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppText.bodyStrong,
          minimumSize: const Size(0, 44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Text('View all'),
          SizedBox(width: AppSpace.xs),
          Icon(Icons.arrow_forward_rounded, size: 18),
        ]),
      ),
    ]);
  }
}

// ── Header: brand, location chip, bell ───────────────────────────────────────
class _Header extends ConsumerStatefulWidget {
  /// A booking is in progress: the bell shows a dot and opens it.
  final bool hasUpdate;
  const _Header({required this.hasUpdate});

  @override
  ConsumerState<_Header> createState() => _HeaderState();
}

class _HeaderState extends ConsumerState<_Header> {
  /// Ask once per app launch, like delivery apps do, until an address exists.
  static bool _askedThisLaunch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _askedThisLaunch) return;
      if (ref.read(addressBookProvider).items.isNotEmpty) return;
      _askedThisLaunch = true;
      showAddressSheet(context, ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final sel = ref.watch(addressBookProvider).selected;
    final areas = ref.watch(serviceAreasProvider).valueOrNull ?? const [];
    final coverage = sel == null ? null : addressCoverage(sel, areas);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Expanded(child: BrandWithAddress()),
        const SizedBox(width: AppSpace.sm),
        Semantics(
          button: true,
          label: widget.hasUpdate
              ? 'Booking updates. Your booking is in progress'
              : 'Booking updates',
          child: ExcludeSemantics(
            child: RoundSurface(
              onTap: () => context.go('/bookings'),
              padding: const EdgeInsets.all(10),
              child: Stack(clipBehavior: Clip.none, children: [
                const Icon(Icons.notifications_none_rounded,
                    size: 22, color: AppColors.text),
                if (widget.hasUpdate)
                  Positioned(
                    top: 0,
                    right: 1,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.elasticOut,
                      builder: (_, v, child) =>
                          Transform.scale(scale: v, child: child),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: AppColors.surface, width: 1.5),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ]),
      if (coverage == Coverage.notCovered) ...[
        const SizedBox(height: AppSpace.md),
        const NoticeBox(
          icon: Icons.wrong_location_outlined,
          warning: true,
          text: 'We don\'t wash cars at this address yet. '
              'Tap the address above to pick another.',
        ),
      ],
    ]);
  }
}

// ── Hero: photos slide behind a fixed headline ───────────────────────────────
class _HeroCarousel extends StatefulWidget {
  /// Shorter headline and padding, for when a live booking sits above it.
  final bool compact;

  /// New customers: the first-booking offer, as a tap-to-copy line.
  final Offer? firstOffer;
  const _HeroCarousel({this.compact = false, this.firstOffer});

  static const photos = [
    'assets/images/interior_vacuum.jpg',
    'assets/images/foam_mitt_wash.jpg',
    'assets/images/machine_polish.jpg',
  ];

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  Timer? _timer;
  int _index = 0;

  void _go(int delta) {
    final n = _HeroCarousel.photos.length;
    setState(() => _index = (_index + delta + n) % n);
  }

  void _restartTimer() {
    _timer?.cancel();
    if (MediaQuery.of(context).disableAnimations) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _go(1));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restartTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const photos = _HeroCarousel.photos;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Stack(children: [
        const Positioned.fill(child: ColoredBox(color: AppColors.forest)),
        const SizedBox(width: double.infinity),
        // Photos fill only the right half, so the headline sits on solid green
        // and never crosses a face.
        Positioned.fill(
          child: Align(
            alignment: Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: ExcludeSemantics(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragEnd: (d) {
                    final v = d.primaryVelocity ?? 0;
                    if (v.abs() < 200) return;
                    _go(v < 0 ? 1 : -1);
                    _restartTimer();
                  },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 700),
                    // Stack the outgoing and incoming photo at full size.
                    layoutBuilder: (current, previous) => Stack(
                        fit: StackFit.expand,
                        children: [...previous, if (current != null) current]),
                    // Mirrored (the people face left in the originals) and
                    // framed so each person sits at the right of the slot.
                    child: Transform.flip(
                      key: ValueKey(_index),
                      flipX: true,
                      child: Image.asset(photos[_index],
                          fit: BoxFit.cover,
                          alignment: const Alignment(-0.2, -0.2),
                          cacheWidth: 800),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Blend the photo's left edge into the green.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  stops: const [0.5, 0.8],
                  colors: [
                    AppColors.forest,
                    AppColors.forest.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: widget.compact
              ? const EdgeInsets.fromLTRB(
                  AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.lg)
              : const EdgeInsets.fromLTRB(
                  AppSpace.xl, AppSpace.xl, AppSpace.xl, AppSpace.xl),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: widget.compact ? 190 : 250,
              child: Semantics(
                header: true,
                child: Text(
                    widget.compact
                        ? 'A spotless car, right where it\'s parked'
                        : 'A spotless car.\nRight where\nit\'s parked.',
                    style: (widget.compact ? AppText.h3 : AppText.display)
                        .copyWith(color: Colors.white)),
              ),
            ),
            // One message under the headline: the first-booking offer when
            // there is one (How it works also says "pay after"), otherwise
            // "Pay after the service".
            if (kPayAfterService &&
                !widget.compact &&
                widget.firstOffer == null) ...[
              const SizedBox(height: AppSpace.sm),
              Text('Pay after the service',
                  style: AppText.bodyStrong.copyWith(color: AppColors.brand)),
            ],
            if (widget.firstOffer != null && !widget.compact) ...[
              const SizedBox(height: AppSpace.md),
              _HeroOffer(widget.firstOffer!),
            ],
            SizedBox(height: widget.compact ? AppSpace.md : AppSpace.lg),
            ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                context.go('/services');
              },
              // Logo green on the dark hero (brand is for dark backgrounds).
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: AppColors.ink,
                minimumSize: Size(0, widget.compact ? 40 : 46),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Book a service'),
                SizedBox(width: AppSpace.sm),
                Icon(Icons.arrow_forward_rounded, size: 20),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// "🏷 ₹100 off your first booking · FIRST100" on the dark hero. Tap to copy
/// the code.
class _HeroOffer extends StatelessWidget {
  final Offer offer;
  const _HeroOffer(this.offer);

  @override
  Widget build(BuildContext context) {
    final off = offer.percentOff > 0
        ? '${offer.percentOff}% off'
        : '${rupees(offer.flatOff)} off';
    return Semantics(
      button: true,
      label: '$off your first booking. Code ${offer.code}. Tap to copy',
      child: ExcludeSemantics(
        child: Material(
          // Solid, so the code stays readable where the pill runs over the photo.
          color: AppColors.forest,
          shape: const StadiumBorder(
              side: BorderSide(color: AppColors.brand, width: 1)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () {
              Clipboard.setData(ClipboardData(text: offer.code));
              showMessage(context, 'Code ${offer.code} copied');
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.local_offer_outlined,
                    size: 16, color: AppColors.brand),
                const SizedBox(width: 6),
                Flexible(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: '$off your first booking · '),
                      TextSpan(
                          text: offer.code,
                          style: const TextStyle(color: AppColors.brand)),
                    ]),
                    style: AppText.caption.copyWith(color: Colors.white),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Service tiles: wash and detailing, side by side ──────────────────────────
class _ServiceTiles extends StatelessWidget {
  final CarType? car;
  const _ServiceTiles({required this.car});

  @override
  Widget build(BuildContext context) {
    int priceOf(CarService s) => car == null ? s.fromPrice : s.priceFor(car!);
    int cheapestIn(ServiceCategory c) =>
        servicesIn(c).map(priceOf).reduce((a, b) => a < b ? a : b);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(
        header: true,
        child: Text('What does your car need?', style: AppText.h3),
      ),
      const SizedBox(height: AppSpace.md),
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: _ServiceTile(
              photo: 'assets/images/home_tile_wash.jpg',
              title: 'Car Wash',
              line: 'Foam wash, inside and out',
              price: cheapestIn(ServiceCategory.wash),
              onTap: () => context.go('/services?cat=wash'),
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: _ServiceTile(
              photo: 'assets/images/home_tile_detailing.jpg',
              title: 'Detailing & Polish',
              line: 'Polish, 3M wax and dry clean',
              price: cheapestIn(ServiceCategory.detailing),
              onTap: () => context.go('/services?cat=detailing'),
            ),
          ),
        ]),
      ),
    ]);
  }
}

/// Half-width tile: photo on top, then the title and the from-price.
class _ServiceTile extends StatelessWidget {
  final String photo, title, line;
  final int price;
  final VoidCallback onTap;

  const _ServiceTile({
    required this.photo,
    required this.title,
    required this.line,
    required this.price,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $line. From ${rupees(price)}',
      child: ExcludeSemantics(
        child: AppCard(
          onTap: onTap,
          padding: EdgeInsets.zero,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.md - 1)),
              child: AspectRatio(
                aspectRatio: 1.6,
                child: Image.asset(photo,
                    fit: BoxFit.cover,
                    cacheWidth: 500,
                    excludeFromSemantics: true),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.md, 10, AppSpace.md, AppSpace.md),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.title),
                    const SizedBox(height: 2),
                    Text('From ${rupees(price)}',
                        style: AppText.smallStrong
                            .copyWith(color: AppColors.primary)),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Monthly car care ─────────────────────────────────────────────────────────
class _MonthlyCard extends StatelessWidget {
  final CarType? car;
  const _MonthlyCard({required this.car});

  /// True for every monthly plan: visits are scheduled, nothing to re-book.
  static const _line = 'Scheduled washes at your door, every month.';

  @override
  Widget build(BuildContext context) {
    final plans = servicesIn(ServiceCategory.monthly);
    int priceOf(CarService s) => car == null ? s.fromPrice : s.priceFor(car!);
    final cheapest = plans.reduce((a, b) => priceOf(a) <= priceOf(b) ? a : b);
    final badge = plans.map((s) => s.badge).whereType<String>().firstOrNull;
    final price = 'From ${rupees(priceOf(cheapest))}${cheapest.priceSuffix}';
    void open() => context.go('/services?cat=monthly');

    return Semantics(
      container: true,
      label: 'Monthly car care. $_line $price',
      child: AppCard(
        onTap: open,
        color: AppColors.primarySoft,
        padding: EdgeInsets.zero,
        child: LayoutBuilder(builder: (context, c) {
          // As big as possible without reaching the button column.
          final carWidth = (c.maxWidth * 0.46).clamp(0.0, c.maxWidth - 186);
          return Stack(children: [
            // Soft green disc behind the car.
            Positioned(
              right: -carWidth * 0.18,
              bottom: -carWidth * 0.38,
              child: Container(
                width: carWidth * 1.15,
                height: carWidth * 1.15,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.07),
                ),
              ),
            ),
            // Cut-out car (transparent PNG), bottom-right.
            Positioned(
              right: AppSpace.sm,
              bottom: AppSpace.md,
              width: carWidth,
              child: Image.asset('assets/images/home_monthly_car.png',
                  fit: BoxFit.fitWidth, excludeFromSemantics: true),
            ),
            if (badge != null)
              Positioned(
                top: AppSpace.lg,
                right: AppSpace.lg,
                child:
                    Pill(badge, icon: Icons.star_rounded, tone: PillTone.solid),
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: SizedBox(
                width: c.maxWidth - carWidth - AppSpace.xl,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text('Monthly Car Care',
                            maxLines: 1, softWrap: false, style: AppText.h3),
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text(_line, style: AppText.small),
                      const SizedBox(height: AppSpace.sm),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(price,
                            style:
                                AppText.h3.copyWith(color: AppColors.primary)),
                      ),
                      const SizedBox(height: AppSpace.md),
                      OutlinedButton(
                        onPressed: open,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          backgroundColor: AppColors.surface,
                          side: const BorderSide(color: AppColors.primary),
                          minimumSize: const Size(0, 38),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          textStyle: AppText.bodyStrong,
                        ),
                        child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Know more'),
                              SizedBox(width: AppSpace.xs),
                              Icon(Icons.arrow_forward_rounded, size: 16),
                            ]),
                      ),
                    ]),
              ),
            ),
          ]);
        }),
      ),
    );
  }
}

// ── Limited time offers: tap a card to copy its code ─────────────────────────
class _Offers extends StatelessWidget {
  final bool firstBooking;
  final CarType? car;

  /// Already shown elsewhere (the hero), so left out here.
  final Offer? skip;
  const _Offers({required this.firstBooking, required this.car, this.skip});

  @override
  Widget build(BuildContext context) {
    final offers = kOffers
        .where((o) => o != skip)
        .where((o) => !(o.firstBookingOnly && !firstBooking))
        .where((o) =>
            o.onlyFor == null || (car != null && o.onlyFor!.contains(car)))
        .toList()
      // A first-booking offer leads: it's the biggest for a new customer.
      ..sort((a, b) =>
          (b.firstBookingOnly ? 1 : 0) - (a.firstBookingOnly ? 1 : 0));
    if (offers.isEmpty) return const SizedBox.shrink();
    final shown = offers.take(2).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _SectionTitle('Offers for you', onViewAll: () => context.go('/wallet')),
      const SizedBox(height: AppSpace.sm),
      // Full-width tickets, stacked, code on the right: side by side they
      // were too narrow on small phones ("Off first / booking").
      for (var i = 0; i < shown.length; i++) ...[
        if (i > 0) const SizedBox(height: AppSpace.sm),
        _OfferCard(shown[i], warm: i.isOdd),
      ],
    ]);
  }
}

class _OfferCard extends StatelessWidget {
  final Offer offer;
  final bool warm;
  const _OfferCard(this.offer, {this.warm = false});

  @override
  Widget build(BuildContext context) {
    final fg = warm ? AppColors.warning : AppColors.primary;
    final code = CustomPaint(
      painter: _DashedBorder(color: fg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(offer.code,
              maxLines: 1,
              softWrap: false,
              style: AppText.bodyStrong.copyWith(
                  color: warm ? AppColors.warning : AppColors.primaryDk,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4)),
        ),
      ),
    );
    return Semantics(
      button: true,
      label: '${offer.headline}, ${offer.title}. Code ${offer.code}. '
          'Tap to copy',
      child: ExcludeSemantics(
        child: AppCard(
          color: warm ? AppColors.warningSoft : AppColors.primarySoft,
          padding: const EdgeInsets.all(AppSpace.md),
          onTap: () {
            Clipboard.setData(ClipboardData(text: offer.code));
            showMessage(context, 'Code ${offer.code} copied');
          },
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Icon(
                warm
                    ? Icons.card_giftcard_outlined
                    : Icons.local_offer_outlined,
                size: 22,
                color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(offer.headline,
                        style: AppText.bodyStrong
                            .copyWith(fontWeight: FontWeight.w700)),
                    Text(offer.title,
                        style: AppText.small.copyWith(color: AppColors.text)),
                    Text('Tap to copy the code', style: AppText.caption),
                  ]),
            ),
            const SizedBox(width: AppSpace.sm),
            code,
          ]),
        ),
      ),
    );
  }
}

/// Dashed rounded outline, like a coupon code box.
class _DashedBorder extends CustomPainter {
  final Color color;
  const _DashedBorder({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.6), const Radius.circular(6)));
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 7) {
        canvas.drawPath(m.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}

/// "Eco promise". Shown only when [kEcoFriendly] is confirmed in
/// business_info.dart.
class _EcoBanner extends StatelessWidget {
  const _EcoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: AppColors.primaryDk,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(children: [
        const Icon(Icons.water_drop_rounded, size: 24, color: Colors.white),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('A Cleaner Car for a Cleaner Tomorrow',
                style: AppText.bodyStrong.copyWith(color: Colors.white)),
            const SizedBox(height: AppSpace.xs),
            Text('We use water-saving techniques and eco-friendly products.',
                style: AppText.small.copyWith(color: Colors.white)),
          ]),
        ),
        const SizedBox(width: AppSpace.md),
        const Icon(Icons.chevron_right_rounded, size: 24, color: Colors.white),
      ]),
    );
  }
}

// ── Book again: the last completed booking, one tap away ─────────────────────
/// Opens the booking page for the same package and car. The price shown is
/// today's price for that car, not what was paid last time.
class _BookAgain extends StatelessWidget {
  final BookingRecord booking;
  const _BookAgain({required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final s = serviceById(b.serviceId)!;
    final price = '${rupees(s.priceFor(b.car))}${s.priceSuffix}';
    final photo = s.cardPhoto;
    void book() {
      HapticFeedback.selectionClick();
      context.push('/book/${s.id}?car=${b.car.name}');
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(header: true, child: Text('Book again', style: AppText.h3)),
      const SizedBox(height: AppSpace.md),
      Semantics(
        button: true,
        label: 'Book ${s.name} again for your ${carTypeNames[b.car]}. '
            'Last done ${friendlyDate(b.date)}. $price',
        child: ExcludeSemantics(
          child: AppCard(
            onTap: book,
            padding: const EdgeInsets.all(AppSpace.md),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.thumb),
                child: SizedBox(
                  width: 52,
                  height: 52,
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
                      Text(
                          '${carTypeNames[b.car]} · '
                          'last done ${friendlyDate(b.date)} · $price',
                          style: AppText.small),
                    ]),
              ),
              const SizedBox(width: AppSpace.sm),
              OutlinedButton(
                onPressed: book,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  textStyle: AppText.smallStrong,
                ),
                child: const Text('Book'),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }
}

// ── How it works (new customers only) ────────────────────────────────────────
/// Three short steps in one row. The full four-step list
/// (HowItWorksSteps) is too tall for Home.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  static const _steps = [
    'Pick a Service',
    'Choose a slot',
    kPayAfterService ? 'Pay after we finish' : 'We clean at your door',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(header: true, child: Text('How it works', style: AppText.h3)),
      const SizedBox(height: AppSpace.md),
      Semantics(
        label: 'How it works: '
            '${[
          for (var i = 0; i < _steps.length; i++) '${i + 1}, ${_steps[i]}'
        ].join('. ')}',
        child: ExcludeSemantics(
          child: AppCard(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.sm, vertical: AppSpace.md),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var i = 0; i < _steps.length; i++) ...[
                if (i > 0)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(Icons.chevron_right_rounded,
                        size: 18, color: AppColors.textSubtle),
                  ),
                Expanded(
                  child: Column(children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                          color: AppColors.ink, shape: BoxShape.circle),
                      child: Text('${i + 1}',
                          style: AppText.smallStrong
                              .copyWith(color: AppColors.brand)),
                    ),
                    const SizedBox(height: 6),
                    Text(_steps[i],
                        textAlign: TextAlign.center,
                        style: AppText.small.copyWith(
                            color: i == _steps.length - 1
                                ? AppColors.primaryDk
                                : AppColors.text,
                            fontWeight: i == _steps.length - 1
                                ? FontWeight.w700
                                : null)),
                  ]),
                ),
              ],
            ]),
          ),
        ),
      ),
    ]);
  }
}

// ── Before / after photo ─────────────────────────────────────────────────────
/// A side-by-side before/after photo (left half before, right half after),
/// labelled on the photo. Shown only when kBeforeAfterPhoto is set.
class _BeforeAfter extends StatelessWidget {
  final String photo;
  const _BeforeAfter({required this.photo});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(
          header: true, child: Text('See the difference', style: AppText.h3)),
      const SizedBox(height: AppSpace.md),
      Semantics(
        image: true,
        label: 'A dirty wheel before cleaning, and the same wheel after',
        child: ExcludeSemantics(
          child: AppCard(
            padding: EdgeInsets.zero,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppRadius.md - 1)),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Stack(fit: StackFit.expand, children: [
                        Image.asset(photo, fit: BoxFit.cover, cacheWidth: 900),
                        const Positioned(
                          left: AppSpace.md,
                          bottom: AppSpace.md,
                          child: Pill('Before', tone: PillTone.dark),
                        ),
                        const Positioned(
                          right: AppSpace.md,
                          bottom: AppSpace.md,
                          child: Pill('After', tone: PillTone.solid),
                        ),
                      ]),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpace.md),
                    child: Text(
                        'Tyre and wheel cleaning, part of every '
                        'Exterior and Exterior + Interior wash.',
                        style: AppText.small),
                  ),
                ]),
          ),
        ),
      ),
    ]);
  }
}

// ── Live booking (only when a booking is in progress) ────────────────────────
class _LiveBookingCard extends StatelessWidget {
  final BookingRecord booking;
  const _LiveBookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final slot = slotById(b.slotId);
    final arrival = b.confirmedArrivalLabel;
    // Requested and confirmed headlines already name the slot.
    final headlineHasSlot = b.status == BookingStatus.requested ||
        (b.status == BookingStatus.confirmed && arrival != null);
    final line = [
      if (arrival != null) 'Likely around $arrival',
      b.serviceName,
      if (!headlineHasSlot && arrival == null) slot?.short ?? b.slotLabel,
    ].join(' · ');
    return AppCard(
      selected: true,
      color: AppColors.surface,
      onTap: () => context.push('/bookings/${b.ref}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${b.status.label} · ${friendlyDate(b.date)}',
                  style: AppText.caption.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(progressHeadline(b), style: AppText.h3),
              const SizedBox(height: 2),
              Text(line,
                  style: AppText.small,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textSubtle),
        ]),
        const SizedBox(height: 14),
        // Dots only: the status line above already names the step, and five
        // labels don't fit a phone width without shrinking.
        BookingProgress(status: b.status, showLabels: false),
      ]),
    );
  }
}
