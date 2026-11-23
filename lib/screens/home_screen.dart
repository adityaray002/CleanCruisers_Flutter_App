import '../providers/api_providers.dart';
import '../core/scheduling.dart' show clockLabel;
import '../data/api/models.dart'
    show Booking, BookingState, Coverage, PublicOffer;
import '../providers/booking_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/format.dart';
import '../core/pricing.dart';
import '../core/theme.dart';
import '../data/business_info.dart';
import '../models/service.dart';
import '../widgets/booking_progress.dart';
import '../widgets/brand_header.dart';
import '../providers/app_providers.dart';
import '../widgets/contact_actions.dart';
import '../widgets/customer_sheets.dart';
import '../widgets/motion.dart';
import '../widgets/ui.dart';

/// Home (v4, one photo style like the big home-service apps). Top to bottom:
/// 1. a green band: where the car is parked ("Home ⌄" and the address), car
///    pill, bell, the promise, "pay after" and the first-booking offer, and
///    our expert. Once it scrolls away a white header takes its place,
/// 2. two big cards on the band's edge: Car wash and Detailing,
/// 3. the live booking, if any, or "Book again" with the last finished wash,
/// 4. popular services: the same expert doing each job (3 per row),
/// 5. the monthly plan,
/// 6. new customers: how it works,
/// 7. before / after photo (only when kBeforeAfterPhoto is set),
/// 8. "Relax, your car is in expert hands" with real facts and chat, eco
///    promise (only when confirmed).
///
/// All Home pictures come from one photo shoot (docs/HOME_ILLUSTRATION_BRIEF.md):
/// the same expert, uniform, car and white studio.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  static const _gutter = AppSpace.lg;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scroll = ScrollController();

  /// The green band has scrolled away: a white header takes its place.
  final _scrolled = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() => _scrolled.value = _scroll.offset > 64);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _scrolled.dispose();
    super.dispose();
  }

  static EdgeInsets _section({double top = 0, double bottom = AppSpace.xxl}) =>
      EdgeInsets.fromLTRB(HomeScreen._gutter, top, HomeScreen._gutter, bottom);

  @override
  Widget build(BuildContext context) {
    final mine =
        ref.watch(myApiBookingsProvider).valueOrNull ?? MyBookings.none;
    ref.watch(catalogProvider); // prices follow the server catalog
    final car = ref.watch(profileProvider).car;
    final live = mine.upcoming.firstOrNull;
    final isNew = mine.isEmpty;
    // Past comes newest first from the server.
    final lastDone = mine.past
        .where((b) =>
            b.status == BookingState.completed &&
            b.plan == null &&
            serviceById(b.service.id) != null)
        .firstOrNull;
    // The server's first-booking coupon (contract `GET /offers`), if any.
    final firstOffer = isNew
        ? (ref.watch(publicOffersProvider).valueOrNull ?? const [])
            .where((o) => o.conditions.contains('First booking only'))
            .firstOrNull
        : null;

    final list = ListView(
      controller: _scroll,
      padding: const EdgeInsets.only(
          bottom: kTrustPhoto == null && !kEcoFriendly ? AppSpace.xxl : 0),
      children: [
        _Top(hasUpdate: live != null, firstOffer: firstOffer, car: car),
        const SizedBox(height: AppSpace.xl),
        if (live != null)
          Padding(
            padding: _section(),
            child: _LiveBookingCard(booking: live),
          )
        else if (lastDone != null)
          Padding(
            padding: _section(),
            child: _BookAgain(booking: lastDone),
          ),
        Padding(
          padding: _section(bottom: AppSpace.section),
          child: Reveal(child: _PopularServices(car: car)),
        ),
        Padding(
          padding: _section(bottom: AppSpace.section),
          child: Reveal(child: _MonthlyCard(car: car)),
        ),
        if (isNew)
          Padding(
              padding: _section(bottom: AppSpace.section),
              child: const _HowItWorks()),
        if (kBeforeAfterPhoto != null)
          Padding(
            padding: _section(bottom: AppSpace.lg),
            child: _BeforeAfter(photo: kBeforeAfterPhoto!),
          ),
        const _Trust(),
        if (kEcoFriendly)
          Padding(padding: _section(), child: const _EcoBanner()),
      ],
    );

    return ValueListenableBuilder<bool>(
      valueListenable: _scrolled,
      builder: (context, scrolled, _) => AnnotatedRegion<SystemUiOverlayStyle>(
        // Light status-bar icons over the green band, dark over the white
        // header.
        value: (scrolled ? AppTheme.overlayDark : SystemUiOverlayStyle.light)
            .copyWith(statusBarColor: Colors.transparent),
        child: Scaffold(
          backgroundColor: AppColors.surface,
          // Dense cards: system text may grow, but only to 1.15x so the cards
          // keep their shape on small phones.
          body: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.15,
            child: Stack(children: [
              list,
              if (scrolled)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: _StickyHeader(hasUpdate: live != null),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The white header that stays on top once the green band scrolled away.
class _StickyHeader extends StatelessWidget {
  final bool hasUpdate;
  const _StickyHeader({required this.hasUpdate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          HomeScreen._gutter,
          MediaQuery.paddingOf(context).top + AppSpace.sm,
          HomeScreen._gutter,
          AppSpace.sm),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: _Header(hasUpdate: hasUpdate, onDark: false),
    );
  }
}

// ── Top: green band with the expert and the two big cards ────────────────────
class _Top extends StatelessWidget {
  final bool hasUpdate;
  final PublicOffer? firstOffer;
  final CarType? car;
  const _Top(
      {required this.hasUpdate, required this.firstOffer, required this.car});

  static const _band = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [Color(0xFF1A8F4C), AppColors.primary, AppColors.primaryDk],
      stops: [0, 0.45, 1],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Stack(children: [
      const Positioned.fill(child: DecoratedBox(decoration: _band)),
      // Soft light circle, top right.
      Positioned(
        right: -70,
        top: -90,
        child: Container(
          width: 260,
          height: 260,
          decoration: const BoxDecoration(
              color: Color(0x0FFFFFFF), shape: BoxShape.circle),
        ),
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(HomeScreen._gutter, top + AppSpace.sm,
            HomeScreen._gutter, AppSpace.lg),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _Header(hasUpdate: hasUpdate),
          const SizedBox(height: AppSpace.section),
          // The promise on the left, our expert on the right. He stands
          // on the cards' top edge (the crop at his waist hides under it).
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.lg),
                child: _Promise(firstOffer: firstOffer),
              ),
            ),
            // He takes less height than he shows: his head rises into the
            // space under the header, so the hero stays short and Popular
            // services fit on the first screen.
            Transform.translate(
              offset: const Offset(AppSpace.sm, 22),
              child: SizedBox(
                width: 117,
                height: 148,
                child: OverflowBox(
                  minHeight: 172,
                  maxHeight: 172,
                  alignment: Alignment.bottomCenter,
                  child: Image.asset('assets/images/pro_hero.png',
                      height: 172,
                      fit: BoxFit.contain,
                      cacheHeight: 540,
                      excludeFromSemantics: true),
                ),
              ),
            ),
          ]),
          _ActionCards(car: car),
        ]),
      ),
    ]);
  }
}

// ── Header: where the car is, car pill, bell ─────────────────────────────────
class _Header extends ConsumerStatefulWidget {
  /// A booking is in progress: the bell shows a dot and opens it.
  final bool hasUpdate;

  /// On the green band (this one asks for an address once per launch);
  /// false for the white sticky header.
  final bool onDark;
  const _Header({required this.hasUpdate, this.onDark = true});

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
      if (!mounted || _askedThisLaunch || !widget.onDark) return;
      if (ref.read(addressBookProvider).items.isNotEmpty) {
        // Once per launch: addresses the server doesn't have yet go up.
        _askedThisLaunch = true;
        ref.read(addressBookProvider.notifier).restoreFromServer();
        return;
      }
      _askedThisLaunch = true;
      showAddressSheet(context, ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final sel = ref.watch(addressBookProvider).selected;
    final coverage = sel == null ? null : addressCoverage(ref, sel);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
            child: ParkedAtLine(withOverline: true, onDark: widget.onDark)),
        const SizedBox(width: AppSpace.sm),
        CarPill(onDark: widget.onDark),
        const SizedBox(width: AppSpace.sm),
        Semantics(
          button: true,
          label: widget.hasUpdate
              ? 'Booking updates. Your booking is in progress'
              : 'Booking updates',
          child: ExcludeSemantics(
            child: RoundSurface(
              onDark: widget.onDark,
              onTap: () => context.go('/bookings'),
              padding: const EdgeInsets.all(11),
              child: Stack(clipBehavior: Clip.none, children: [
                Icon(Icons.notifications_none_rounded,
                    size: 20,
                    color: widget.onDark ? Colors.white : AppColors.text),
                if (widget.hasUpdate)
                  Positioned(
                    top: 0,
                    right: 1,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: widget.onDark
                                ? AppColors.primary
                                : AppColors.surface,
                            width: 1.5),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ]),
      if (widget.onDark && coverage == Coverage.notCovered) ...[
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

// ── The promise, on the band's left (the expert stands on the right) ─────────
class _Promise extends StatelessWidget {
  final PublicOffer? firstOffer;
  const _Promise({required this.firstOffer});

  @override
  Widget build(BuildContext context) {
    final o = firstOffer;
    final off = o?.headline.replaceAll('OFF', 'off');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Semantics(
        header: true,
        label: 'A spotless car, right where it\'s parked',
        // Always three lines. 32px is already large text, so it isn't
        // scaled up; on narrow phones it shrinks just enough to fit.
        child: ExcludeSemantics(
          child: MediaQuery.withNoTextScaling(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                const TextSpan(children: [
                  TextSpan(text: 'A spotless car,\n'),
                  TextSpan(
                      text: 'right where\n',
                      style: TextStyle(color: AppColors.brand)),
                  TextSpan(text: 'it\'s parked'),
                ]),
                style: AppText.h1.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                    letterSpacing: -0.2),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: AppSpace.md),
      Wrap(
          spacing: AppSpace.md,
          runSpacing: AppSpace.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (kPayAfterService)
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle_rounded,
                    size: 16, color: AppColors.brand),
                const SizedBox(width: 6),
                Text('Pay after the service',
                    style: AppText.small.copyWith(
                        color: const Color(0xE6FFFFFF),
                        fontWeight: FontWeight.w500)),
              ]),
            if (o != null)
              Semantics(
                button: true,
                label: '$off your first booking. Code ${o.code}. Tap to copy',
                child: ExcludeSemantics(
                  child: GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: o.code));
                      showMessage(context, 'Code ${o.code} copied');
                    },
                    child: _HeroPill('$off · ${o.code}'),
                  ),
                ),
              ),
          ]),
    ]);
  }
}

class _HeroPill extends StatelessWidget {
  final String text;
  const _HeroPill(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(text,
          style: AppText.caption
              .copyWith(color: AppColors.ink, fontWeight: FontWeight.w800)),
    );
  }
}

// ── The two big cards: Car wash and Detailing ────────────────────────────────
class _ActionCards extends StatelessWidget {
  final CarType? car;
  const _ActionCards({required this.car});

  @override
  Widget build(BuildContext context) {
    int priceOf(CarService s) => car == null ? s.fromPrice : s.priceFor(car!);
    int cheapestIn(ServiceCategory c) =>
        servicesIn(c).map(priceOf).reduce((a, b) => a < b ? a : b);

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: _ActionCard(
            title: 'Car wash',
            line: 'Outside and inside',
            from: cheapestIn(ServiceCategory.wash),
            image: 'assets/images/icon3d_wash.png',
            // The foam cannon is long and thin: give it more width.
            iconWidth: 116,
            iconHeight: 84,
            onTap: () => context.go('/services?cat=wash'),
          ),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: _ActionCard(
            title: 'Detailing',
            line: 'Polish, wax, dry clean',
            from: cheapestIn(ServiceCategory.detailing),
            image: 'assets/images/icon3d_polish.png',
            // The polisher is compact and heavy; a bit smaller it weighs
            // the same as the long, thin foam cannon.
            iconHeight: 76,
            onTap: () => context.go('/services?cat=detailing'),
          ),
        ),
      ]),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title, line, image;
  final int from;
  final VoidCallback onTap;
  final double iconHeight, iconWidth;
  const _ActionCard({
    required this.title,
    required this.line,
    required this.from,
    required this.image,
    required this.onTap,
    this.iconHeight = 72,
    this.iconWidth = 92,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $line. From ${rupees(from)}',
      child: ExcludeSemantics(
        child: PressScale(
          // A raised key: a darker mint edge under the card and a soft
          // shadow, so it looks like something to press.
          child: Container(
            padding: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFA9DDBE),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x40052E16),
                    blurRadius: 18,
                    offset: Offset(0, 8)),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              clipBehavior: Clip.antiAlias,
              child: Ink(
                // White fading into a soft mint, like glass on the band.
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Color(0xFFEAF7EF)],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: const Color(0xB3FFFFFF)),
                ),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onTap();
                  },
                  // Like Pronto's cards: the title and price top left, a
                  // round "go" button bottom left, and the 3D icon big in the
                  // bottom-right corner, running off the card's edge.
                  child: Stack(children: [
                    Positioned(
                      right: -6,
                      bottom: -6,
                      child: Image.asset(image,
                          width: iconWidth,
                          height: iconHeight,
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomRight,
                          cacheHeight: 240,
                          excludeFromSemantics: true),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: AppText.title
                                    .copyWith(color: AppColors.text)),
                            const SizedBox(height: 2),
                            Text('from ${rupees(from)}',
                                style: AppText.caption.copyWith(
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: AppSpace.xxl),
                            Container(
                              width: 34,
                              height: 34,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      color: Color(0x5515803D),
                                      blurRadius: 8,
                                      offset: Offset(0, 3)),
                                ],
                              ),
                              child: const Icon(Icons.arrow_forward_rounded,
                                  size: 18, color: Colors.white),
                            ),
                          ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Book again (returning customers) ─────────────────────────────────────────
/// The last finished wash, one tap from booking again. The price is today's
/// price for that car, not what was paid last time.
class _BookAgain extends StatelessWidget {
  final Booking booking;
  const _BookAgain({required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final s = serviceById(b.service.id)!;
    final car = b.car.type;
    final price = '${rupees(s.priceFor(car))}${s.priceSuffix}';
    final photo = _PopularServices.photos[s.id] ?? s.cardPhoto;
    void book() {
      HapticFeedback.selectionClick();
      context.push('/book/${s.id}?car=${car.name}');
    }

    return Semantics(
      button: true,
      label: 'Book ${s.name} again for your ${carTypeNames[car]}. '
          'Last done ${friendlyDate(b.slot.date)}. $price',
      child: ExcludeSemantics(
        child: AppCard(
          onTap: book,
          radius: AppRadius.lg,
          padding: const EdgeInsets.all(AppSpace.md),
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
                        child: Icon(s.icon, color: AppColors.primary, size: 24),
                      ),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BOOK AGAIN',
                        style: AppText.caption.copyWith(
                            color: AppColors.primary, letterSpacing: 0.4)),
                    Text(s.listName,
                        style: AppText.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text('Last done ${friendlyDate(b.slot.date)} · $price',
                        style: AppText.small),
                  ]),
            ),
            const SizedBox(width: AppSpace.sm),
            ElevatedButton(
              onPressed: book,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                textStyle: AppText.smallStrong,
              ),
              child: const Text('Book'),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Popular services: the expert doing each job, 3 per row ───────────────────
class _PopularServices extends StatelessWidget {
  final CarType? car;
  const _PopularServices({required this.car});

  /// Home photos, one per service: close-ups of the job from the same shoot
  /// (same car, gloves, white studio), so each tile looks different.
  static const photos = {
    'wash-full': 'assets/images/cu_full_wash.jpg',
    'wash-exterior': 'assets/images/cu_exterior.jpg',
    'wash-interior': 'assets/images/cu_interior.jpg',
    'wash-bucket': 'assets/images/cu_bucket.jpg',
    'dry-cleaning': 'assets/images/cu_dry_clean.jpg',
    'rubbing-exterior': 'assets/images/cu_rubbing.jpg',
    '3m-wax-exterior': 'assets/images/cu_wax.jpg',
    'full-package': 'assets/images/cu_full_package.jpg',
  };

  /// Three on Home, one of each kind (the rest are one tap away in "See all"):
  /// the most booked wash, seat dry cleaning and the full detailing. Their
  /// photos look different (foam door, seat close-up, finished car).
  static const _popular = ['wash-full', 'dry-cleaning', 'full-package'];

  /// What you get, in a few words, under the name on the tiles.
  static const whatYouGet = {
    'wash-full': 'Foam + vacuum',
    'wash-exterior': 'Foam + wheels',
    'wash-interior': 'Vacuum + dash',
    'wash-bucket': 'Hand wash',
    'dry-cleaning': 'Seats + roof',
    'rubbing-exterior': 'Light marks',
    '3m-wax-exterior': 'Gloss + shield',
    'full-package': 'Rubbing + wax',
  };

  /// Short names for the small tiles (the full name is on the service page).
  static const shortNames = {
    'wash-full': 'Full wash',
    'wash-exterior': 'Outside wash',
    'wash-interior': 'Inside clean',
    'wash-bucket': 'Bucket wash',
    'dry-cleaning': 'Dry cleaning',
    'rubbing-exterior': 'Rubbing',
    '3m-wax-exterior': '3M wax',
    'full-package': 'Full detailing',
  };

  @override
  Widget build(BuildContext context) {
    final services = _popular.map(serviceById).whereType<CarService>().toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text('Popular services',
                style: AppText.h2.copyWith(fontWeight: FontWeight.w700)),
          ),
        ),
        TextButton(
          onPressed: () => context.go('/services'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            textStyle: AppText.smallStrong,
            minimumSize: const Size(0, 40),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
          ),
          child: const Text('See all'),
        ),
      ]),
      const SizedBox(height: AppSpace.md),
      LayoutBuilder(builder: (context, c) {
        const gap = AppSpace.md;
        final w = ((c.maxWidth - 2 * gap) / 3).floorToDouble();
        // One row, all three the same height (names wrap differently).
        return IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < services.length; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              SizedBox(
                width: w,
                child: _ServiceTile(
                    service: services[i],
                    car: car,
                    photo: photos[services[i].id]!),
              ),
            ],
          ]),
        );
      }),
    ]);
  }
}

class _ServiceTile extends StatelessWidget {
  final CarService service;
  final CarType? car;
  final String photo;
  const _ServiceTile(
      {required this.service, required this.car, required this.photo});

  @override
  Widget build(BuildContext context) {
    final s = service;
    final from = car == null;
    final amount = rupees(from ? s.fromPrice : s.priceFor(car!));

    // Like the big home-service apps: a photo with a small tag in its
    // corner, then just the name and the price. The whole tile opens the
    // service (with "Book" at the bottom of that page).
    return Semantics(
      button: true,
      label: '${s.name}. Takes ${s.duration}. '
          '${from ? 'From ' : ''}$amount. See details',
      child: ExcludeSemantics(
        child: Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: const BorderSide(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              context.push('/service/${s.id}');
            },
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Stack(fit: StackFit.expand, children: [
                      Image.asset(photo,
                          fit: BoxFit.cover,
                          cacheWidth: 360,
                          excludeFromSemantics: true),
                      // How long it takes, tucked into the top-right corner.
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 96),
                          padding: const EdgeInsets.fromLTRB(7, 3, 8, 4),
                          decoration: const BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(AppRadius.sm)),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.schedule_rounded,
                                  size: 12, color: AppColors.textSubtle),
                              const SizedBox(width: 3),
                              Text(s.duration,
                                  maxLines: 1,
                                  style: AppText.caption.copyWith(
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w500)),
                            ]),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_PopularServices.shortNames[s.id] ?? s.listName,
                              style: AppText.body.copyWith(
                                  color: AppColors.text,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          // One line; shrinks a little on narrow tiles.
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                                _PopularServices.whatYouGet[s.id] ?? s.tagline,
                                maxLines: 1,
                                style: AppText.caption.copyWith(
                                    color: AppColors.textSubtle,
                                    fontWeight: FontWeight.w500)),
                          ),
                        ]),
                  ),
                  // Price at the bottom of every tile, so they line up,
                  // with a small arrow that says "open".
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 8, 10),
                    child: Row(children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text.rich(
                            TextSpan(children: [
                              if (from) const TextSpan(text: 'from '),
                              TextSpan(
                                  text: amount,
                                  style: AppText.bodyStrong.copyWith(
                                      color: AppColors.text,
                                      fontWeight: FontWeight.w800)),
                            ]),
                            maxLines: 1,
                            style: AppText.caption
                                .copyWith(color: AppColors.textSubtle),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                            color: AppColors.primarySoft,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.arrow_forward_rounded,
                            size: 14, color: AppColors.primary),
                      ),
                    ]),
                  ),
                ]),
          ),
        ),
      ),
    );
  }
}

// ── Monthly plan ─────────────────────────────────────────────────────────────
/// The 3-wash plan as a light mint card: a small green tag, the promise,
/// the price, one button, and the 3D calendar. The price follows the car.
class _MonthlyCard extends StatelessWidget {
  final CarType? car;
  const _MonthlyCard({required this.car});

  @override
  Widget build(BuildContext context) {
    final plan = serviceById('monthly-3')!;
    final amount = car == null ? plan.fromPrice : plan.priceFor(car!);
    void open() => context.go('/services?cat=monthly');

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF2FBF5), Color(0xFFDDF4E5)],
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: const Color(0xFFCDEBD8)),
        ),
        child: InkWell(
          onTap: open,
          child: Stack(children: [
            // A soft mint blob behind the calendar.
            Positioned(
              right: -30,
              bottom: -40,
              child: Container(
                width: 150,
                height: 150,
                decoration: const BoxDecoration(
                    color: Color(0xFFC9EED7), shape: BoxShape.circle),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
              child: Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.sm, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text('MONTHLY PLAN',
                              style: AppText.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6)),
                        ),
                        const SizedBox(height: AppSpace.sm),
                        Semantics(
                          header: true,
                          child: Text('Clean all month.\nBook once.',
                              style: AppText.h3.copyWith(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2)),
                        ),
                        const SizedBox(height: 2),
                        Text('3 full washes at your door',
                            style: AppText.small
                                .copyWith(color: AppColors.textMuted)),
                        const SizedBox(height: AppSpace.sm),
                        Text.rich(
                          TextSpan(children: [
                            if (car == null)
                              TextSpan(
                                  text: 'From ',
                                  style: AppText.small
                                      .copyWith(color: AppColors.textMuted)),
                            TextSpan(text: rupees(amount)),
                            TextSpan(
                                text: ' /month',
                                style: AppText.small
                                    .copyWith(color: AppColors.textMuted)),
                          ]),
                          style: AppText.priceSm.copyWith(color: AppColors.ink),
                        ),
                        const SizedBox(height: AppSpace.md),
                        ElevatedButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            open();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpace.lg),
                            textStyle: AppText.smallStrong
                                .copyWith(fontWeight: FontWeight.w800),
                          ),
                          child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Explore plan'),
                                SizedBox(width: AppSpace.xs),
                                Icon(Icons.arrow_forward_rounded, size: 18),
                              ]),
                        ),
                      ]),
                ),
                const SizedBox(width: AppSpace.sm),
                Image.asset('assets/images/icon3d_calendar.png',
                    height: 104, cacheHeight: 312, excludeFromSemantics: true),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── How it works (new customers only) ────────────────────────────────────────
/// One quiet line of three steps, no card.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  static const _steps = [
    'Pick a package',
    'Request a slot',
    kPayAfterService ? 'Pay after' : 'We clean',
  ];

  @override
  Widget build(BuildContext context) {
    final spoken = [
      for (var i = 0; i < _steps.length; i++) '${i + 1}, ${_steps[i]}'
    ].join('. ');
    Widget dot(int i) => Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
              color: AppColors.primarySoft, shape: BoxShape.circle),
          child: Text('${i + 1}',
              style: AppText.smallStrong.copyWith(color: AppColors.primaryDk)),
        );
    return Semantics(
      label: 'How it works: $spoken',
      child: ExcludeSemantics(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('How it works',
              style: AppText.h3.copyWith(color: AppColors.text)),
          const SizedBox(height: AppSpace.lg),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < _steps.length; i++)
              Expanded(
                child: Column(children: [
                  // The number, with a thin line to the next step.
                  Row(children: [
                    Expanded(
                        child: Container(
                            height: 1,
                            color: i == 0 ? null : AppColors.border)),
                    dot(i),
                    Expanded(
                        child: Container(
                            height: 1,
                            color: i == _steps.length - 1
                                ? null
                                : AppColors.border)),
                  ]),
                  const SizedBox(height: AppSpace.sm),
                  Text(_steps[i],
                      textAlign: TextAlign.center,
                      style: AppText.caption.copyWith(
                          color: AppColors.text, fontWeight: FontWeight.w500)),
                ]),
              ),
          ]),
        ]),
      ),
    );
  }
}

// ── Before / after photo ─────────────────────────────────────────────────────
class _BeforeAfter extends StatelessWidget {
  final String photo;
  const _BeforeAfter({required this.photo});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(
          header: true, child: Text('See the difference', style: AppText.h2)),
      const SizedBox(height: AppSpace.md),
      Semantics(
        image: true,
        label: 'A dirty wheel before cleaning, and the same wheel after',
        child: ExcludeSemantics(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: AspectRatio(
              aspectRatio: 16 / 10,
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
                  child: Pill('After our wash', tone: PillTone.solid),
                ),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
}

// ── Trust: a calm closing section with real facts ────────────────────────────
/// "Relax, your car is in expert hands" and two facts from business_info
/// (no ratings or customer counts until they are real data), then chat.
class _Trust extends StatelessWidget {
  const _Trust();

  @override
  Widget build(BuildContext context) {
    Widget fact(String top, String big, String bottom) => Expanded(
          child: Column(children: [
            Text(top,
                textAlign: TextAlign.center,
                style: AppText.caption.copyWith(
                    color: AppColors.textSubtle, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(big,
                textAlign: TextAlign.center,
                style: AppText.h1.copyWith(color: AppColors.text)),
            const SizedBox(height: 2),
            Text(bottom,
                textAlign: TextAlign.center,
                style: AppText.caption.copyWith(
                    color: AppColors.textSubtle, fontWeight: FontWeight.w500)),
          ]),
        );

    return Container(
      margin: const EdgeInsets.only(top: AppSpace.sm),
      padding: const EdgeInsets.fromLTRB(HomeScreen._gutter, AppSpace.section,
          HomeScreen._gutter, AppSpace.lg),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(children: [
        Semantics(
          header: true,
          child: Text('Relax, your car is in\nexpert hands',
              textAlign: TextAlign.center,
              style: AppText.h2
                  .copyWith(fontWeight: FontWeight.w600, height: 1.3)),
        ),
        const SizedBox(height: AppSpace.xxl),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: HomeScreen._gutter),
            child: IntrinsicHeight(
              child: Row(children: [
                if (kEstablished != null) ...[
                  fact('Serving since', kEstablished!, kCityLabel),
                  const VerticalDivider(
                      width: 1, thickness: 1, color: AppColors.border),
                ],
                fact('Open', kDaysLabel.replaceFirst('All ', ''), kHoursLabel),
              ]),
            )),
        const SizedBox(height: AppSpace.xl),
        TextButton.icon(
          onPressed: () => openWhatsApp(context),
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
          label: const Text('Questions? Chat with us on WhatsApp'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            textStyle: AppText.smallStrong,
            minimumSize: const Size(0, 44),
          ),
        ),
        // Our expert, arms crossed, in front of a line-drawn city: the
        // calm last picture of Home (like the big home-service apps).
        if (kTrustPhoto != null) ...[
          const SizedBox(height: AppSpace.md),
          Image.asset(kTrustPhoto!,
              width: double.infinity,
              fit: BoxFit.fitWidth,
              cacheWidth: 1080,
              excludeFromSemantics: true),
        ] else
          const SizedBox(height: AppSpace.lg),
      ]),
    );
  }
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
            Text('A cleaner car for a cleaner tomorrow',
                style: AppText.bodyStrong.copyWith(color: Colors.white)),
            const SizedBox(height: AppSpace.xs),
            Text('We use water-saving techniques and eco-friendly products.',
                style: AppText.small.copyWith(color: Colors.white)),
          ]),
        ),
      ]),
    );
  }
}

// ── Live booking (only when a booking is in progress) ────────────────────────
/// Dark status card: when the expert arrives (the slot is the promise, the
/// planned arrival a hint), and five progress dots.
class _LiveBookingCard extends StatelessWidget {
  final Booking booking;
  const _LiveBookingCard({required this.booking});

  static const _muted = Color(0xFFB8C0C7);

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final service = serviceById(b.service.id);
    final carLabel = b.car.model.trim().isEmpty
        ? carTypeNames[b.car.type]!
        : b.car.model.trim();
    final line = [
      if (b.status != BookingState.requested)
        'Ready by about ${clockLabel(b.slot.end)}',
      service?.listName ?? b.service.name,
      carLabel,
    ].join(' · ');
    final step = progressIndex(b.status);
    final (chip, _) = chipOf(b.status);

    return Semantics(
      button: true,
      label: '$chip, ${friendlyDate(b.slot.date)}. '
          '${headlineOf(b)}. $line. Open booking',
      child: ExcludeSemantics(
        child: Material(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: () => context.push('/bookings/${b.ref}'),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                            color: AppColors.brand, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                            '$chip · ${friendlyDate(b.slot.date)}'
                                .toUpperCase(),
                            style: AppText.overline
                                .copyWith(color: AppColors.brand)),
                      ),
                      Text('View',
                          style: AppText.smallStrong.copyWith(color: _muted)),
                      const Icon(Icons.chevron_right_rounded,
                          size: 18, color: _muted),
                    ]),
                    const SizedBox(height: AppSpace.sm),
                    Text(headlineOf(b),
                        style: AppText.h3.copyWith(color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(line,
                        style: AppText.small.copyWith(color: _muted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    if (step != null) ...[
                      const SizedBox(height: 14),
                      _DarkDots(current: step),
                    ],
                  ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Five progress dots for a dark card.
class _DarkDots extends StatelessWidget {
  final int current;
  const _DarkDots({required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (var i = 0; i < 5; i++) ...[
        if (i > 0)
          Expanded(
            child: Container(
              height: 3,
              color: i <= current ? AppColors.brand : const Color(0xFF2A3336),
            ),
          ),
        if (i == current)
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.brand,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: AppColors.brand.withValues(alpha: 0.25),
                    spreadRadius: 4)
              ],
            ),
          )
        else
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: i < current ? AppColors.brand : null,
              shape: BoxShape.circle,
              border: i < current
                  ? null
                  : Border.all(color: const Color(0xFF3A4448), width: 2),
            ),
          ),
      ],
    ]);
  }
}
