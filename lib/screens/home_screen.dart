import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import '../core/pricing.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgBlack,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header()),
            SliverToBoxAdapter(child: _HeroCarousel()),
            SliverToBoxAdapter(child: _ServiceTiles()),
            SliverToBoxAdapter(child: _StatStrip()),
            SliverToBoxAdapter(child: _HowItWorks()),
            SliverToBoxAdapter(child: _Reviews()),
            SliverToBoxAdapter(child: _BottomCta()),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
      child: Row(children: [
        ClipOval(
          child: Image.asset('assets/images/logo.png',
              width: 38, height: 38, fit: BoxFit.cover),
        ),
        const SizedBox(width: 10),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CleanCruisers',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17, fontWeight: FontWeight.w800)),
            Row(children: [
              Icon(Icons.location_on, color: kGreen400, size: 12),
              SizedBox(width: 2),
              Text('Delhi NCR',
                  style: TextStyle(color: kGray400, fontSize: 12)),
            ]),
          ],
        ),
        const Spacer(),
        IconButton(
          onPressed: () async {
            final uri = Uri.parse('tel:$kPhone');
            if (await canLaunchUrl(uri)) await launchUrl(uri);
          },
          icon: const Icon(Icons.call_outlined, color: kGreen400, size: 22),
        ),
      ]),
    );
  }
}

// ── Hero Carousel ─────────────────────────────────────────────────────────────
class _HeroCarousel extends StatefulWidget {
  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  final _ctrl = PageController();
  int _page = 0;
  Timer? _timer;

  static const _slides = [
    _Slide(
      tag: 'DOORSTEP SERVICE',
      title: 'Professional Car\nWash at Your\nDoorstep',
//       sub: 'Trained team at your home\n7 days a week • 8 AM–6 PM',
      emoji: '🚗',
      cta: 'Book Now',
      service: null,
      grad: [Color(0xFF064E24), Color(0xFF031A0C)],
    ),
    _Slide(
      tag: 'EXTERIOR + INTERIOR',
      title: 'Deep Foam Wash\n+ Interior Clean\nFrom ₹449',
//       sub: 'Foam wash • Vacuum • Dashboard\nTyre polish • Black part polish',
      emoji: '🫧',
      cta: 'Book Wash',
      service: 'oneTime',
      grad: [Color(0xFF0A3A5C), Color(0xFF021422)],
    ),
    _Slide(
      tag: 'PREMIUM DETAILING',
      title: '3M Wax & Rubbing\nShowroom Shine\nFrom ₹649',
//       sub: 'Full body rubbing • 3M wax\nProfessional-grade treatment',
      emoji: '✨',
      cta: 'Book Detailing',
      service: 'premiumAddons',
      grad: [Color(0xFF2D1B4E), Color(0xFF0E0520)],
    ),
    _Slide(
      tag: 'MONTHLY PACKAGE',
      title: '3 Washes Every\nMonth at Your\nDoorstep ₹1,399',
//       sub: 'Best value • Free air freshener\nFree dustbin • All inclusive',
      emoji: '📅',
      cta: 'Subscribe',
      service: 'completeCare',
      grad: [Color(0xFF1A3A1A), Color(0xFF050F05)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final next = (_page + 1) % _slides.length;
      _ctrl.animateToPage(next,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => _SlideView(
                slide: _slides[i],
                onTap: () {
                  final s = _slides[i].service;
                  context.push(s != null ? '/booking?service=$s' : '/booking');
                }),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_slides.length, (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == _page ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == _page ? kGreen400 : kGray700,
              borderRadius: BorderRadius.circular(3),
            ),
          )),
        ),
      ],
    );
  }
}

class _Slide {
  final String tag, title, emoji, cta;
  final String? service;
  final List<Color> grad;
  const _Slide({
    required this.tag, required this.title,
    required this.emoji, required this.cta, required this.service,
    required this.grad,
  });
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  final VoidCallback onTap;
  const _SlideView({required this.slide, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: slide.grad,
          ),
          border: Border.all(color: kGreen400.withAlpha(50)),
        ),
        child: Stack(
          children: [
            // Background texture circle
            Positioned(
              right: -20, top: -20,
              child: Container(
                width: 140, height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(8),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 110, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: kGreen400.withAlpha(35),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kGreen400.withAlpha(80)),
                    ),
                    child: Text(slide.tag,
                        style: const TextStyle(
                            color: kGreen400, fontSize: 9,
                            fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                  ),
                  // Title
                  Text(slide.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20, fontWeight: FontWeight.w900,
                          height: 1.15, letterSpacing: -0.3)),
                  // Sub
//                   Text(slide.sub,
//                       style: const TextStyle(
//                           color: Colors.white60, fontSize: 11, height: 1.4)),
                  // CTA chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: kGreen400,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${slide.cta} →',
                        style: const TextStyle(
                            color: Colors.black,
                            fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
            // Emoji illustration
            Positioned(
              right: 14, bottom: 14,
              child: Text(slide.emoji,
                  style: const TextStyle(fontSize: 66)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Service Tiles ─────────────────────────────────────────────────────────────
class _ServiceTiles extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tiles = [
      _ServiceData(
        icon: Icons.water_drop,
        iconColor: const Color(0xFF38BDF8),
        name: 'Car Wash\n& Care',
        price: '₹${washPackagePrices[WashPackage.exteriorOnly]![CarType.hatchback]!}',
        tag: '1–2 hrs',
        color: const Color(0xFF052E16),
        border: const Color(0xFF16A34A),
        service: 'oneTime',
      ),
      _ServiceData(
        icon: Icons.auto_awesome,
        iconColor: const Color(0xFFA78BFA),
        name: 'Complete\nCar Care',
        price: '₹${premiumAddonPrices['3m-wax-exterior']![CarType.hatchback]!}',
        tag: '2–3 hrs',
        color: const Color(0xFF1E1B4B),
        border: const Color(0xFF6366F1),
        service: 'premiumAddons',
      ),
      _ServiceData(
        icon: Icons.calendar_month,
        iconColor: const Color(0xFF4ADE80),
        name: 'Monthly\nPackage',
        price: '₹${completeCarePrice[CarType.hatchback]!}',
        tag: '3 washes',
        color: const Color(0xFF1A0533),
        border: const Color(0xFF9333EA),
        service: 'completeCare',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 14),
          child: Text('Our Services',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        SizedBox(
          height: 162,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: tiles.length,
            itemBuilder: (_, i) => _ServiceTile(data: tiles[i]),
          ),
        ),
      ],
    );
  }
}

class _ServiceData {
  final IconData icon;
  final Color iconColor;
  final String name, price, tag, service;
  final Color color, border;
  const _ServiceData({
    required this.icon, required this.iconColor,
    required this.name, required this.price, required this.tag,
    required this.color, required this.border, required this.service,
  });
}

class _ServiceTile extends StatelessWidget {
  final _ServiceData data;
  const _ServiceTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/booking?service=${data.service}'),
      child: Container(
        width: 142,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: data.color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: data.border.withAlpha(100)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: data.iconColor.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(data.icon, color: data.iconColor, size: 22),
            ),
            const Spacer(),
            Text(data.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14, fontWeight: FontWeight.w700, height: 1.2)),
            const SizedBox(height: 6),
            Text(data.price,
                style: const TextStyle(
                    color: kGreen400,
                    fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(data.tag,
                style: const TextStyle(color: kGray400, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ── Stats Strip ───────────────────────────────────────────────────────────────
class _StatStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGray700.withAlpha(100)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: const [
          _StatItem(value: '4.9★', label: 'Rating'),
          _Divider(),
          _StatItem(value: '1000+', label: 'Customers'),
          _Divider(),
          _StatItem(value: '8AM–6PM', label: 'All Days'),
          _Divider(),
          _StatItem(value: '₹0', label: 'Advance'),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value, label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value,
          style: const TextStyle(
              color: kGreen400, fontSize: 14, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text(label,
          style: const TextStyle(color: kGray400, fontSize: 11)),
    ]);
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 28, color: kGray700.withAlpha(150));
  }
}

// ── How It Works ──────────────────────────────────────────────────────────────
class _HowItWorks extends StatelessWidget {
  static const _steps = [
    (Icons.local_car_wash, 'Choose\nService'),
    (Icons.event_available, 'Pick Date\n& Time'),
    (Icons.chat_bubble_outline, 'Confirm on\nWhatsApp'),
    (Icons.home_outlined, 'We Come\nto You'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How It Works',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Row(
            children: _steps.asMap().entries.map((e) {
              final isLast = e.key == _steps.length - 1;
              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 50, height: 50,
                            decoration: BoxDecoration(
                              color: kBgCard,
                              shape: BoxShape.circle,
                              border: Border.all(color: kGreen400.withAlpha(80)),
                            ),
                            child: Icon(e.value.$1, color: kGreen400, size: 22),
                          ),
                          const SizedBox(height: 8),
                          Text(e.value.$2,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11, height: 1.3)),
                        ],
                      ),
                    ),
                    if (!isLast)
                      const Icon(Icons.chevron_right,
                          color: kGray700, size: 18),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Reviews ───────────────────────────────────────────────────────────────────
class _Reviews extends StatelessWidget {
  static const _reviews = [
    ('Priya S.', 'South Delhi',
        'Amazing! They came on time, car looks showroom clean. Will book again!', 5),
    ('Rahul M.', 'Dwarka',
        'Very professional team. Best doorstep car wash in Delhi!', 5),
    ('Anjali K.', 'Janakpuri',
        'Booked on WhatsApp, team arrived in 30 mins. Perfectly done.', 5),
    ('Sanjay T.', 'Uttam Nagar',
        'Monthly package saves so much time. Three washes at doorstep!', 5),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 28, 20, 14),
          child: Row(children: [
            Text('Customer Reviews',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18, fontWeight: FontWeight.w800)),
            SizedBox(width: 8),
            Text('4.9★',
                style: TextStyle(
                    color: kGreen400, fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _reviews.length,
            itemBuilder: (_, i) {
              final r = _reviews[i];
              final initials = r.$1.trim().split(' ')
                  .where((w) => w.isNotEmpty).take(2)
                  .map((w) => w[0].toUpperCase()).join();
              return Container(
                width: 230,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kBgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kGray700.withAlpha(100)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      CircleAvatar(
                        backgroundColor: kGreen400,
                        radius: 14,
                        child: Text(initials,
                            style: const TextStyle(
                                color: Colors.black,
                                fontSize: 10, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r.$1,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12, fontWeight: FontWeight.w700)),
                          Text(r.$2,
                              style: const TextStyle(color: kGray400, fontSize: 10)),
                        ]),
                      ),
                      Row(children: List.generate(r.$4,
                          (_) => const Icon(Icons.star_rounded,
                              color: kGreen400, size: 11))),
                    ]),
                    const SizedBox(height: 10),
                    Text(r.$3,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12, height: 1.4),
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Bottom CTA ────────────────────────────────────────────────────────────────
class _BottomCta extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.push('/booking'),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Book a Car Wash',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final uri = Uri.parse(kWhatsAppUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.chat, size: 16),
              label: const Text('Chat on WhatsApp'),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.access_time, color: kGray400, size: 12),
              SizedBox(width: 4),
              Text('8 AM – 6 PM  •  7 Days a Week  •  Delhi NCR',
                  style: TextStyle(color: kGray400, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
