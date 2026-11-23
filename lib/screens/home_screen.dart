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
/// 1. a green band: logo, where the car is parked, car pill, bell, the
///    promise, "pay after" and the first-booking offer, and our expert,
/// 2. two big cards on the band's edge: Car wash and Detailing,
/// 3. the live booking, if any, or "Book again" with the last finished wash,
/// 4. popular services: the same expert doing each job (3 per row),
/// 5. the monthly plan,
/// 6. new customers: how it works,
/// 7. before / after photo (only when kBeforeAfterPhoto is set),
/// 8. three facts and a chat tile, eco promise (only when confirmed).
///
/// All Home pictures come from one photo shoot (docs/HOME_ILLUSTRATION_BRIEF.md):
/// the same expert, uniform, car and white studio.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _gutter = AppSpace.lg;

  static EdgeInsets _section({double top = 0, double bottom = AppSpace.xxl}) =>
      EdgeInsets.fromLTRB(_gutter, top, _gutter, bottom);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status-bar icons over the green band.
      value: SystemUiOverlayStyle.light
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: AppColors.surface,
        // Dense cards: system text may grow, but only to 1.15x so the cards
        // keep their shape on small phones.
        body: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.15,
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpace.xxl),
            children: [
              _Top(hasUpdate: live != null, firstOffer: firstOffer, car: car),
              const SizedBox(height: AppSpace.lg),
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
                padding: _section(),
                child: Reveal(child: _PopularServices(car: car)),
              ),
              Padding(
                padding: _section(),
                child: Reveal(child: _MonthlyCard(car: car)),
              ),
              if (isNew)
                Padding(padding: _section(), child: const _HowItWorks()),
              if (kBeforeAfterPhoto != null)
                Padding(
                  padding: _section(bottom: AppSpace.lg),
                  child: _BeforeAfter(photo: kBeforeAfterPhoto!),
                ),
              Padding(padding: _section(), child: const _Facts()),
              if (kEcoFriendly)
                Padding(padding: _section(), child: const _EcoBanner()),
            ],
          ),
        ),
      ),
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
                padding: const EdgeInsets.only(bottom: AppSpace.xl),
                child: _Promise(firstOffer: firstOffer),
              ),
            ),
            Transform.translate(
              offset: const Offset(AppSpace.sm, AppSpace.md),
              child: Image.asset('assets/images/pro_hero.png',
                  height: 150,
                  fit: BoxFit.contain,
                  cacheHeight: 492,
                  excludeFromSemantics: true),
            ),
          ]),
          _ActionCards(car: car),
        ]),
      ),
    ]);
  }
}

// ── Header: logo, address, car pill, bell (on the green band) ────────────────
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
        ClipOval(
          child: Image.asset('assets/images/logo.png',
              width: 36,
              height: 36,
              cacheWidth: 144,
              excludeFromSemantics: true),
        ),
        const SizedBox(width: 10),
        const Expanded(child: ParkedAtLine(withOverline: true, onDark: true)),
        const SizedBox(width: AppSpace.sm),
        const CarPill(),
        const SizedBox(width: AppSpace.sm),
        Semantics(
          button: true,
          label: widget.hasUpdate
              ? 'Booking updates. Your booking is in progress'
              : 'Booking updates',
          child: ExcludeSemantics(
            child: RoundSurface(
              onTap: () => context.go('/bookings'),
              padding: const EdgeInsets.all(11),
              child: Stack(clipBehavior: Clip.none, children: [
                const Icon(Icons.notifications_none_rounded,
                    size: 20, color: AppColors.text),
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
                        border:
                            Border.all(color: AppColors.surface, width: 1.5),
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
                      style: TextStyle(
                          color: AppColors.brand, fontWeight: FontWeight.w600)),
                  TextSpan(text: 'it\'s parked'),
                ]),
                style: AppText.h2.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                    letterSpacing: -0.2),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: AppSpace.md),
      Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
        if (kPayAfterService)
          const _HeroPill('Pay after the service', icon: Icons.check_rounded),
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
                child: _HeroPill('$off · ${o.code}', bright: true),
              ),
            ),
          ),
      ]),
    ]);
  }
}

class _HeroPill extends StatelessWidget {
  final String text;
  final bool bright;
  final IconData? icon;
  const _HeroPill(this.text, {this.bright = false, this.icon});

  @override
  Widget build(BuildContext context) {
    final color = bright ? AppColors.ink : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bright ? AppColors.brand : const Color(0x26FFFFFF),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: bright ? null : Border.all(color: const Color(0x991DE874)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: bright ? AppColors.ink : AppColors.brand),
          const SizedBox(width: AppSpace.xs),
        ],
        Flexible(
          child: Text(text,
              style: AppText.caption
                  .copyWith(color: color, fontWeight: FontWeight.w800)),
        ),
      ]),
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
  const _ActionCard({
    required this.title,
    required this.line,
    required this.from,
    required this.image,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $line. From ${rupees(from)}',
      child: ExcludeSemantics(
        child: PressScale(
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onTap();
              },
              // Compact like a button: title and line on top, the price
              // button bottom left, the 3D icon whole in the bottom right.
              child: Stack(children: [
                Positioned(
                  right: AppSpace.sm,
                  bottom: AppSpace.sm,
                  child: Image.asset(image,
                      height: 60,
                      width: 64,
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomRight,
                      cacheHeight: 180,
                      excludeFromSemantics: true),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppText.title),
                        const SizedBox(height: AppSpace.xl),
                        Container(
                          padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(color: AppColors.primary),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text('from ${rupees(from)}',
                                style: AppText.caption.copyWith(
                                    color: AppColors.primaryDk,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(width: 2),
                            const Icon(Icons.arrow_forward_rounded,
                                size: 13, color: AppColors.primary),
                          ]),
                        ),
                      ]),
                ),
              ]),
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

  @override
  Widget build(BuildContext context) {
    final services = _popular.map(serviceById).whereType<CarService>().toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text('Popular services', style: AppText.h2),
          ),
        ),
        TextButton(
          onPressed: () => context.go('/services'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            textStyle: AppText.smallStrong,
            minimumSize: const Size(0, 40),
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
    final price =
        car == null ? 'from ${rupees(s.fromPrice)}' : rupees(s.priceFor(car!));
    void open() {
      HapticFeedback.selectionClick();
      context.push('/service/${s.id}');
    }

    void book() {
      HapticFeedback.selectionClick();
      context.push('/book/${s.id}${car == null ? '' : '?car=${car!.name}'}');
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AspectRatio(
          aspectRatio: 1,
          child: Stack(fit: StackFit.expand, children: [
            Semantics(
              button: true,
              label: '${s.listName}. $price. See details',
              child: GestureDetector(
                onTap: open,
                child: Image.asset(photo,
                    fit: BoxFit.cover,
                    cacheWidth: 360,
                    excludeFromSemantics: true),
              ),
            ),
            // Book it straight away.
            Positioned(
              right: 6,
              bottom: 6,
              child: Semantics(
                button: true,
                label: 'Book ${s.listName}',
                child: Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  elevation: 3,
                  shadowColor: const Color(0x40101828),
                  child: InkWell(
                    onTap: book,
                    borderRadius: BorderRadius.circular(10),
                    child: const SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(Icons.add_rounded,
                          size: 26, color: AppColors.primary),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
        Expanded(
          child: ExcludeSemantics(
            child: InkWell(
              onTap: open,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.listName,
                          style: AppText.smallStrong
                              .copyWith(color: AppColors.text),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(price,
                          style: AppText.bodyStrong
                              .copyWith(fontWeight: FontWeight.w800)),
                    ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Monthly plan ─────────────────────────────────────────────────────────────
/// The 3-wash plan as a light mint card with the 3D calendar and a solid
/// "Book plan" button. The price follows the car.
class _MonthlyCard extends StatelessWidget {
  final CarType? car;
  const _MonthlyCard({required this.car});

  @override
  Widget build(BuildContext context) {
    final plan = serviceById('monthly-3')!;
    final amount = car == null ? plan.fromPrice : plan.priceFor(car!);
    final price = '${car == null ? 'From ' : ''}${rupees(amount)}';

    return Material(
      color: AppColors.primarySoft,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: Color(0xFFBFE3CC)),
      ),
      clipBehavior: Clip.antiAlias,
      // The card opens all plans; the button books this one.
      child: InkWell(
        onTap: () => context.go('/services?cat=monthly'),
        child: Stack(children: [
          Positioned(
            right: -4,
            bottom: -6,
            child: Image.asset('assets/images/icon3d_calendar.png',
                height: 116, cacheHeight: 348, excludeFromSemantics: true),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: FractionallySizedBox(
              widthFactor: 0.64,
              alignment: Alignment.centerLeft,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Pill('Best value', tone: PillTone.solid),
                    const SizedBox(height: AppSpace.sm),
                    Semantics(
                      header: true,
                      child: Text('Clean all month.\nBook once.',
                          style: AppText.h3.copyWith(height: 1.15)),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text('Monthly plan · 3 full washes at your door',
                        style:
                            AppText.small.copyWith(color: AppColors.primaryDk)),
                    const SizedBox(height: AppSpace.sm),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: price),
                        TextSpan(text: ' /month', style: AppText.small),
                      ]),
                      style: AppText.priceSm,
                    ),
                    const SizedBox(height: AppSpace.md),
                    ElevatedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        context.push('/book/monthly-3'
                            '${car == null ? '' : '?car=${car!.name}'}');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDk,
                        minimumSize: const Size(0, 44),
                        padding:
                            const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                        textStyle: AppText.smallStrong,
                      ),
                      child:
                          const Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('Book plan'),
                        SizedBox(width: AppSpace.xs),
                        Icon(Icons.arrow_forward_rounded, size: 18),
                      ]),
                    ),
                  ]),
            ),
          ),
        ]),
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
    return Semantics(
      label: 'How it works: $spoken',
      child: ExcludeSemantics(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('HOW IT WORKS',
              style: AppText.overline.copyWith(color: AppColors.textSubtle)),
          const SizedBox(height: AppSpace.sm),
          Row(children: [
            for (var i = 0; i < _steps.length; i++) ...[
              if (i > 0)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpace.xs),
                  child: Icon(Icons.chevron_right_rounded,
                      size: 16, color: AppColors.textSubtle),
                ),
              Flexible(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                        color: AppColors.primarySoft, shape: BoxShape.circle),
                    child: Text('${i + 1}',
                        style: AppText.caption
                            .copyWith(color: AppColors.primaryDk)),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(_steps[i],
                        style: AppText.caption.copyWith(color: AppColors.text)),
                  ),
                ]),
              ),
            ],
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

// ── Trust strip: hours, since when, chat ─────────────────────────────────────
/// One soft strip with three facts; the chat one opens WhatsApp.
class _Facts extends StatelessWidget {
  const _Facts();

  @override
  Widget build(BuildContext context) {
    Widget fact(IconData icon, String top, String bottom,
            {VoidCallback? onTap}) =>
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
              child: Column(children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(height: AppSpace.xs),
                Text(top,
                    textAlign: TextAlign.center,
                    style: AppText.smallStrong.copyWith(
                        color: onTap == null
                            ? AppColors.text
                            : AppColors.primary)),
                Text(bottom,
                    textAlign: TextAlign.center, style: AppText.caption),
              ]),
            ),
          ),
        );
    Widget divider() => Container(
        width: 1,
        margin: const EdgeInsets.symmetric(vertical: AppSpace.lg),
        color: AppColors.border);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          fact(Icons.schedule_rounded, kDaysLabel, kHoursLabel),
          if (kEstablished != null) ...[
            divider(),
            fact(Icons.verified_outlined, 'Since $kEstablished', kCityLabel),
          ],
          divider(),
          fact(Icons.chat_bubble_outline_rounded, 'Chat with us', 'on WhatsApp',
              onTap: () => openWhatsApp(context)),
        ]),
      ),
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
