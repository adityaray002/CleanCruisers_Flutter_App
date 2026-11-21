import '../providers/api_providers.dart';
import '../core/scheduling.dart' show clockLabel;
import '../data/api/models.dart' show Booking, BookingState, Coverage, PublicOffer;
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

/// Home (v3 design). Top to bottom:
/// 1. logo, where the car is parked, car pill (prices follow it), bell,
/// 2. the live booking, if any, as a dark status card,
/// 3. new customers: a photo hero with "pay after" and the first-booking
///    offer; returning customers: "Book again" with the last finished wash,
/// 4. "What does your car need?" — Car Wash and Detailing & Polish cards,
///    then the monthly plan,
/// 5. new customers: how it works,
/// 6. before / after photo (only when kBeforeAfterPhoto is set),
/// 7. three facts and a chat tile, eco promise (only when confirmed).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _gutter = AppSpace.lg;

  static EdgeInsets _section({double top = 0, double bottom = AppSpace.xxl}) =>
      EdgeInsets.fromLTRB(_gutter, top, _gutter, bottom);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myApiBookingsProvider).valueOrNull ?? MyBookings.none;
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
              padding: const EdgeInsets.only(bottom: AppSpace.xxl),
              children: [
                Padding(
                  padding: _section(top: AppSpace.sm, bottom: AppSpace.md),
                  child: _Header(hasUpdate: live != null),
                ),
                if (live != null)
                  Padding(
                    padding: _section(bottom: AppSpace.md),
                    child: _LiveBookingCard(booking: live),
                  ),
                if (isNew)
                  Padding(
                    padding: _section(),
                    child: _Hero(firstOffer: firstOffer),
                  )
                else if (lastDone != null)
                  Padding(
                    padding: _section(),
                    child: _BookAgain(booking: lastDone),
                  ),
                Padding(
                  padding: _section(bottom: AppSpace.md),
                  child: Reveal(child: _Categories(car: car)),
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
      ),
    );
  }
}

// ── Header: logo, address, car pill, bell ────────────────────────────────────
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
        const Expanded(child: ParkedAtLine(withOverline: true)),
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

// ── Hero (new customers) ─────────────────────────────────────────────────────
/// Our team's photo with the promise and, when one is live, the
/// first-booking offer. Text sits on a dark fade so it reads on any crop.
class _Hero extends StatelessWidget {
  final PublicOffer? firstOffer;
  const _Hero({required this.firstOffer});

  @override
  Widget build(BuildContext context) {
    final o = firstOffer;
    final off = o?.headline.replaceAll('OFF', 'off');
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Stack(children: [
        Positioned.fill(
          child: Image.asset('assets/images/hero_team_kit.jpg',
              fit: BoxFit.cover,
              alignment: const Alignment(-0.1, -0.7),
              cacheWidth: 1000,
              excludeFromSemantics: true),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.3, 0.62, 1],
                colors: [Color(0x000B0F10), Color(0xB80B0F10), AppColors.ink],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 170, 18, 16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Semantics(
              header: true,
              // Always two lines. 32px is already large text, so it isn't
              // scaled up; on narrow phones it shrinks just enough to fit
              // instead of going to three lines over the photo.
              child: MediaQuery.withNoTextScaling(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('A spotless car, right\nwhere it\'s parked',
                      style: AppText.hero.copyWith(color: Colors.white)),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
              if (kPayAfterService) const _HeroPill('Pay after the service'),
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
            const SizedBox(height: AppSpace.lg),
            ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                context.go('/services?cat=wash');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: AppColors.ink,
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Book a wash'),
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

class _HeroPill extends StatelessWidget {
  final String text;
  final bool bright;
  const _HeroPill(this.text, {this.bright = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bright ? AppColors.brand : const Color(0x29FFFFFF),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(text,
            style: AppText.caption.copyWith(
                color: bright ? AppColors.ink : Colors.white,
                fontWeight: FontWeight.w800)),
      );
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
    final photo = s.cardPhoto;
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

// ── Categories: wash and detailing, side by side ─────────────────────────────
class _Categories extends ConsumerWidget {
  final CarType? car;
  const _Categories({required this.car});

  static const _durations = {
    ServiceCategory.wash: '1–2.5 hrs',
    ServiceCategory.detailing: '2–5 hrs',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    int priceOf(CarService s) => car == null ? s.fromPrice : s.priceFor(car!);
    int cheapestIn(ServiceCategory c) =>
        servicesIn(c).map(priceOf).reduce((a, b) => a < b ? a : b);
    String meta(ServiceCategory c) =>
        '${servicesIn(c).length} packages · ${_durations[c]}';

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(
        header: true,
        child: Text('What does your car need?', style: AppText.h2),
      ),
      const SizedBox(height: 2),
      Row(children: [
        Flexible(
          child: Text(
              car == null
                  ? 'Pick your car to see exact prices'
                  : 'Prices for a ${carTypeNames[car]}',
              style: AppText.small),
        ),
        TextButton(
          onPressed: () => showCarSheet(context, ref),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            textStyle: AppText.smallStrong,
            minimumSize: const Size(0, 40),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
          ),
          child: Text(car == null ? 'Choose car' : 'Change'),
        ),
      ]),
      const SizedBox(height: AppSpace.sm),
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: _CategoryCard(
              photo: 'assets/images/pressure_rinse.jpg',
              title: 'Car Wash',
              line: 'Dust and dirt off, inside and out',
              meta: meta(ServiceCategory.wash),
              from: cheapestIn(ServiceCategory.wash),
              badge: 'Most booked',
              onTap: () => context.go('/services?cat=wash'),
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: _CategoryCard(
              photo: 'assets/images/wax_finish.jpg',
              title: 'Detailing & Polish',
              line: 'Shine, scratches, stains and smell',
              meta: meta(ServiceCategory.detailing),
              from: cheapestIn(ServiceCategory.detailing),
              onTap: () => context.go('/services?cat=detailing'),
            ),
          ),
        ]),
      ),
    ]);
  }
}

class _CategoryCard extends StatelessWidget {
  final String photo, title, line, meta;
  final int from;
  final String? badge;
  final VoidCallback onTap;
  const _CategoryCard({
    required this.photo,
    required this.title,
    required this.line,
    required this.meta,
    required this.from,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $line. $meta. From ${rupees(from)}',
      child: ExcludeSemantics(
        child: AppCard(
          onTap: onTap,
          radius: AppRadius.lg,
          padding: EdgeInsets.zero,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.lg - 1)),
              child: SizedBox(
                height: 132,
                child: Stack(fit: StackFit.expand, children: [
                  Image.asset(photo,
                      fit: BoxFit.cover,
                      cacheWidth: 500,
                      excludeFromSemantics: true),
                  if (badge != null)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Pill(badge!, tone: PillTone.solid),
                    ),
                ]),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppText.h3),
                      const SizedBox(height: 2),
                      Text(line, style: AppText.small),
                      const SizedBox(height: 2),
                      Text(meta, style: AppText.caption),
                      const Spacer(),
                      const SizedBox(height: AppSpace.sm),
                      Row(children: [
                        Expanded(
                          child: Text('from ${rupees(from)}',
                              style: AppText.bodyStrong.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800)),
                        ),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                              color: AppColors.ink, shape: BoxShape.circle),
                          child: const Icon(Icons.arrow_forward_rounded,
                              size: 16, color: AppColors.brand),
                        ),
                      ]),
                    ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Monthly plan ─────────────────────────────────────────────────────────────
/// The 3-wash plan (Best value) as a photo card. The price follows the car.
class _MonthlyCard extends StatelessWidget {
  final CarType? car;
  const _MonthlyCard({required this.car});

  @override
  Widget build(BuildContext context) {
    final plan = serviceById('monthly-3')!;
    final amount = car == null ? plan.fromPrice : plan.priceFor(car!);
    final price = '${car == null ? 'From ' : ''}${rupees(amount)}';
    void open() => context.go('/services?cat=monthly');

    return Semantics(
      button: true,
      label: 'Monthly plan, best value. Clean all month, book once. '
          '3 full washes at your door. $price a month',
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: open,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: ColoredBox(
              color: AppColors.ink,
              child: Stack(children: [
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 210,
                  child: Image.asset('assets/images/clean_suv.jpg',
                      fit: BoxFit.cover,
                      cacheWidth: 600,
                      excludeFromSemantics: true),
                ),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        stops: [0.38, 0.62, 1],
                        colors: [
                          AppColors.ink,
                          Color(0x8C0B0F10),
                          Color(0x000B0F10)
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: FractionallySizedBox(
                    widthFactor: 0.66,
                    alignment: Alignment.centerLeft,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MONTHLY PLAN · BEST VALUE',
                              style: AppText.overline
                                  .copyWith(color: AppColors.brand)),
                          const SizedBox(height: 6),
                          Text('Clean all month.\nBook once.',
                              style: AppText.h3
                                  .copyWith(color: Colors.white, height: 1.15)),
                          const SizedBox(height: 6),
                          Text('3 full washes at your door',
                              style: AppText.small
                                  .copyWith(color: const Color(0xFFB8C0C7))),
                          const SizedBox(height: AppSpace.lg),
                          Text.rich(
                            TextSpan(children: [
                              TextSpan(text: price),
                              TextSpan(
                                  text: ' /month',
                                  style: AppText.small.copyWith(
                                      color: const Color(0xFFB8C0C7))),
                            ]),
                            style:
                                AppText.priceSm.copyWith(color: Colors.white),
                          ),
                        ]),
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

// ── How it works (new customers only) ────────────────────────────────────────
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  static const _steps = [
    ('Pick a package', 'See the exact price'),
    ('Request a slot', 'We confirm in the app'),
    kPayAfterService
        ? ('Pay after', 'Cash or UPI')
        : ('We clean', 'At your door'),
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'How it works: '
          '${[
        for (var i = 0; i < _steps.length; i++) '${i + 1}, ${_steps[i].$1}'
      ].join('. ')}',
      child: ExcludeSemantics(
        child: AppCard(
          radius: AppRadius.lg,
          padding: const EdgeInsets.all(AppSpace.lg),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('How it works', style: AppText.title),
            const SizedBox(height: AppSpace.md),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var i = 0; i < _steps.length; i++)
                Expanded(
                  child: Column(children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i == _steps.length - 1
                            ? AppColors.primary
                            : AppColors.ink,
                        shape: BoxShape.circle,
                      ),
                      child: Text('${i + 1}',
                          style: AppText.smallStrong.copyWith(
                              color: i == _steps.length - 1
                                  ? Colors.white
                                  : AppColors.brand)),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Text(_steps[i].$1,
                        textAlign: TextAlign.center,
                        style: AppText.smallStrong.copyWith(
                            color: i == _steps.length - 1
                                ? AppColors.primaryDk
                                : AppColors.text)),
                    Text(_steps[i].$2,
                        textAlign: TextAlign.center, style: AppText.caption),
                  ]),
                ),
            ]),
          ]),
        ),
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

// ── Facts and chat ───────────────────────────────────────────────────────────
class _Facts extends StatelessWidget {
  const _Facts();

  @override
  Widget build(BuildContext context) {
    Widget tile(String top, String bottom, {VoidCallback? onTap}) => Expanded(
          child: AppCard(
            onTap: onTap,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.xs, vertical: AppSpace.md),
            child: Column(children: [
              Text(top,
                  textAlign: TextAlign.center,
                  style: AppText.smallStrong.copyWith(
                      color:
                          onTap == null ? AppColors.text : AppColors.primary)),
              const SizedBox(height: 2),
              Text(bottom, textAlign: TextAlign.center, style: AppText.caption),
            ]),
          ),
        );
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        tile(kDaysLabel, kHoursLabel.replaceAll(' ', ' ')),
        const SizedBox(width: AppSpace.sm),
        if (kEstablished != null) ...[
          tile('Since $kEstablished', kCityLabel),
          const SizedBox(width: AppSpace.sm),
        ],
        tile('Chat with us', 'on WhatsApp', onTap: () => openWhatsApp(context)),
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
