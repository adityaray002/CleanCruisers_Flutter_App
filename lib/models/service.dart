import 'package:flutter/material.dart';
import '../core/pricing.dart';

enum ServiceCategory { wash, detailing, monthly }

const serviceCategoryNames = {
  ServiceCategory.wash: 'Car Wash',
  ServiceCategory.detailing: 'Detailing & Polish',
  ServiceCategory.monthly: 'Monthly Plan',
};

class Extra {
  final String id, name;
  final int price;
  final int maxQty; // 1 = on/off toggle
  final String? unit;
  const Extra(this.id, this.name, this.price, {this.maxQty = 1, this.unit});
}

/// One bookable service, as the customer sees it.
class CarService {
  final String id;
  final ServiceCategory category;
  final String name;
  final String tagline; // one line, shown on cards
  final String description; // shown on the detail page
  final String? image; // null → branded illustration tile
  final String? cardImage; // home-screen card photo; falls back to [image]
  final IconData icon;
  final String duration;
  final Map<CarType, int> prices;
  final List<String> included;
  final List<String> notIncluded;
  final String bestFor;
  final String? badge;
  final String priceSuffix;

  const CarService({
    required this.id,
    required this.category,
    required this.name,
    required this.tagline,
    required this.description,
    required this.icon,
    required this.duration,
    required this.prices,
    required this.included,
    required this.bestFor,
    this.image,
    this.cardImage,
    this.notIncluded = const [],
    this.badge,
    this.priceSuffix = '',
  });

  /// Whether the photo already shows our logo (uniform, bag, bucket). Photos
  /// without it get a small logo badge so every service image is branded.
  bool get photoHasLogo => _brandedPhotos.contains(image);

  /// Photo for the small home-screen cards.
  String? get cardPhoto => cardImage ?? image;
  bool get cardPhotoHasLogo => _brandedPhotos.contains(cardPhoto);

  int priceFor(CarType car) => prices[car] ?? 0;
  int get fromPrice => prices.values.reduce((a, b) => a < b ? a : b);
  bool get samePriceForAll => prices.values.toSet().length == 1;

  /// Optional extras that can be added to this service.
  List<Extra> get extras {
    switch (category) {
      case ServiceCategory.wash:
        return washExtras;
      case ServiceCategory.detailing:
        return [airFreshenerExtra];
      case ServiceCategory.monthly:
        return const [];
    }
  }
}

const _brandedPhotos = {
  'assets/images/wash_collage.jpg',
  'assets/images/bucket_wash.jpg',
  'assets/images/seat_shampoo.jpg',
  'assets/images/dryclean_wax.jpg',
  'assets/images/rubbing_dryclean.jpg',
  'assets/images/detailing_collage.jpg',
};

final washExtras = [
  Extra('seat', 'Seat cleaning', washAddonPrices['seat']!,
      maxQty: 7, unit: 'seat'),
  Extra('roof', 'Roof cleaning', washAddonPrices['roof']!),
  Extra('door', 'Door & dashboard shampoo', washAddonPrices['door']!),
  Extra('ac', 'AC vent & foam cleaning', washAddonPrices['ac']!),
  airFreshenerExtra,
];

final airFreshenerExtra = Extra('air-freshener', 'Air freshener',
    premiumAddonPrices['air-freshener']![CarType.hatchback]!);

List<String> _addonInclusions(String id) =>
    premiumAddons.firstWhere((a) => a.id == id).inclusions;

String _addonDescription(String id) =>
    premiumAddons.firstWhere((a) => a.id == id).description;

final serviceCatalog = <CarService>[
  // ── Car wash ────────────────────────────────────────────────────────────────
  CarService(
    id: 'wash-full',
    category: ServiceCategory.wash,
    name: 'Exterior + Interior Wash',
    tagline: 'Foam wash outside, vacuum and polish inside.',
    description:
        'Our most booked wash. A foam shampoo and high-pressure rinse for the body and wheels, plus a full interior vacuum, dashboard polish and footmat cleaning.',
    image: 'assets/images/wash_collage.jpg',
    icon: Icons.local_car_wash_rounded,
    duration: '1–2 hrs',
    prices: washPackagePrices[WashPackage.exteriorInterior]!,
    included: washPackageInclusions[WashPackage.exteriorInterior]!,
    notIncluded: const [
      'Seat cleaning (available as an extra)',
      'Paint rubbing or waxing'
    ],
    bestFor: 'A regular clean for a car that is used every day.',
    badge: 'Most booked',
  ),
  CarService(
    id: 'wash-exterior',
    category: ServiceCategory.wash,
    name: 'Exterior Wash',
    tagline: 'Foam wash, wheels and tyre polish.',
    description:
        'A thorough outside-only clean: foam shampoo, high-pressure rinse, alloy and tyre cleaning, tyre polish and black-part polish.',
    image: 'assets/images/pressure_rinse.jpg',
    icon: Icons.water_drop_rounded,
    duration: '1–2 hrs',
    prices: washPackagePrices[WashPackage.exteriorOnly]!,
    included: washPackageInclusions[WashPackage.exteriorOnly]!,
    notIncluded: const ['Any interior cleaning'],
    bestFor: 'Cars with a clean cabin that need the dust and grime washed off.',
  ),
  CarService(
    id: 'wash-interior',
    category: ServiceCategory.wash,
    name: 'Interior Clean',
    tagline: 'Vacuum, dashboard polish and footmats.',
    description:
        'An inside-only clean: full vacuum of seats, floor and boot, interior black-part polish, dashboard polish and footmat cleaning.',
    image: 'assets/images/interior_vacuum.jpg',
    icon: Icons.airline_seat_recline_normal_rounded,
    duration: '1–2 hrs',
    prices: washPackagePrices[WashPackage.interiorOnly]!,
    included: washPackageInclusions[WashPackage.interiorOnly]!,
    notIncluded: const [
      'Exterior wash',
      'Seat shampoo (see Interior Dry Cleaning)'
    ],
    bestFor: 'A dusty cabin when the outside is already clean.',
  ),
  CarService(
    id: 'wash-bucket',
    category: ServiceCategory.wash,
    name: 'Bucket Wash',
    tagline: 'Quick hand wash and wipe-down, no pressure washer.',
    description:
        'A quick, water-saving hand wash: the body is washed and wiped with microfiber, glass and mirrors are cleaned, tyres and wheels wiped, and the cabin and footmats dusted.',
    image: 'assets/images/bucket_wash.jpg',
    icon: Icons.water_rounded,
    duration: '30–45 mins',
    prices: washPackagePrices[WashPackage.bucket]!,
    included: washPackageInclusions[WashPackage.bucket]!,
    notIncluded: const ['Foam or high-pressure wash', 'Interior vacuuming'],
    bestFor: 'Keeping a lightly dusty car tidy between full washes.',
  ),

  // ── Detailing ───────────────────────────────────────────────────────────────
  CarService(
    id: 'dry-cleaning',
    category: ServiceCategory.detailing,
    name: 'Interior Dry Cleaning',
    tagline: 'Deep shampoo of seats, roof, doors and mats.',
    description: _addonDescription('dry-cleaning'),
    image: 'assets/images/seat_shampoo.jpg',
    icon: Icons.cleaning_services_rounded,
    duration: '2–3 hrs',
    prices: premiumAddonPrices['dry-cleaning']!,
    included: _addonInclusions('dry-cleaning'),
    notIncluded: const ['Exterior wash'],
    bestFor:
        'Stained seats, bad odour, or a cabin that has not been deep-cleaned in months.',
  ),
  CarService(
    id: '3m-wax-exterior',
    category: ServiceCategory.detailing,
    name: '3M Wax + Foam Wash',
    tagline: 'Glossy shine and paint protection.',
    description: _addonDescription('3m-wax-exterior'),
    image: 'assets/images/wax_finish.jpg',
    icon: Icons.auto_awesome_rounded,
    duration: '2–3 hrs',
    prices: premiumAddonPrices['3m-wax-exterior']!,
    included: _addonInclusions('3m-wax-exterior'),
    notIncluded: const ['Scratch removal (see Rubbing)', 'Interior cleaning'],
    bestFor: 'Paint that looks dull but has no visible scratches.',
  ),
  CarService(
    id: 'rubbing-exterior',
    category: ServiceCategory.detailing,
    name: 'Rubbing + Foam Wash',
    tagline: 'Machine rubbing for light scratches and dullness.',
    description: _addonDescription('rubbing-exterior'),
    image: 'assets/images/machine_polish.jpg',
    icon: Icons.blur_on_rounded,
    duration: '2–3 hrs',
    prices: premiumAddonPrices['rubbing-exterior']!,
    included: _addonInclusions('rubbing-exterior'),
    notIncluded: const ['Wax coating', 'Interior cleaning'],
    bestFor: 'Oxidised or faded paint and light surface scratches.',
  ),
  CarService(
    id: 'rubbing-wax-exterior',
    category: ServiceCategory.detailing,
    name: 'Rubbing + 3M Wax',
    tagline: 'Restore the paint, then seal it with wax.',
    description: _addonDescription('rubbing-wax-exterior'),
    image: 'assets/images/rubbing_wax.jpg',
    icon: Icons.diamond_outlined,
    duration: '2–3 hrs',
    prices: premiumAddonPrices['rubbing-wax-exterior']!,
    included: _addonInclusions('rubbing-wax-exterior'),
    notIncluded: const ['Interior cleaning'],
    bestFor: 'The best exterior finish we offer.',
  ),
  CarService(
    id: 'dryclean-wax-exterior',
    category: ServiceCategory.detailing,
    name: 'Dry Cleaning + 3M Wax',
    tagline: 'Deep-cleaned cabin and a waxed exterior.',
    description: _addonDescription('dryclean-wax-exterior'),
    image: 'assets/images/dryclean_wax.jpg',
    icon: Icons.layers_rounded,
    duration: '2–3 hrs',
    prices: premiumAddonPrices['dryclean-wax-exterior']!,
    included: _addonInclusions('dryclean-wax-exterior'),
    notIncluded: const ['Machine rubbing'],
    bestFor: 'Inside-and-out refresh without paint correction.',
  ),
  CarService(
    id: 'rubbing-dryclean-exterior',
    category: ServiceCategory.detailing,
    name: 'Rubbing + Dry Cleaning',
    tagline: 'Paint rubbing plus a full interior dry clean.',
    description: _addonDescription('rubbing-dryclean-exterior'),
    image: 'assets/images/rubbing_dryclean.jpg',
    icon: Icons.handyman_rounded,
    duration: '2–3 hrs',
    prices: premiumAddonPrices['rubbing-dryclean-exterior']!,
    included: _addonInclusions('rubbing-dryclean-exterior'),
    notIncluded: const ['Wax coating'],
    bestFor: 'Faded paint and a tired interior at the same time.',
  ),
  CarService(
    id: 'full-package',
    category: ServiceCategory.detailing,
    name: 'Full Detailing Package',
    tagline: 'Rubbing, 3M wax and interior dry clean.',
    description: _addonDescription('full-package'),
    image: 'assets/images/detailing_collage.jpg',
    icon: Icons.workspace_premium_rounded,
    duration: '2–3 hrs',
    prices: premiumAddonPrices['full-package']!,
    included: _addonInclusions('full-package'),
    bestFor:
        'Before selling a car, after a long trip, or once or twice a year.',
    badge: 'Complete care',
  ),

  // ── Monthly ─────────────────────────────────────────────────────────────────
  const CarService(
    id: 'monthly-3',
    category: ServiceCategory.monthly,
    name: 'Monthly Plan · 3 Washes',
    tagline: '3 exterior + interior washes a month at your door.',
    description:
        'Three complete washes every month, scheduled at times that suit you. Each visit covers a foam wash, interior vacuum and polish. Includes a free car dustbin and air freshener.',
    image: 'assets/images/clean_suv.jpg',
    icon: Icons.event_repeat_rounded,
    duration: '3 visits / month',
    prices: completeCarePrice,
    included: completeCareInclusions,
    bestFor: 'Anyone who wants a clean car all month without re-booking.',
    badge: 'Best value',
    priceSuffix: '/month',
  ),
  const CarService(
    id: 'monthly-bucket',
    category: ServiceCategory.monthly,
    name: 'Monthly Bucket Wash · 4 Washes',
    tagline: 'A bucket wash every week at your door.',
    description:
        'Four bucket washes every month, one a week, scheduled at times that suit you. Each visit covers a hand wash and wipe-down, glass, tyres and a quick cabin dusting.',
    image: 'assets/images/foam_mitt_wash.jpg',
    icon: Icons.water_rounded,
    duration: '4 visits / month',
    prices: bucketPlanPrice,
    included: bucketPlanInclusions,
    notIncluded: ['Foam or high-pressure wash', 'Interior vacuuming'],
    bestFor: 'A car that stays tidy week to week on a budget.',
    priceSuffix: '/month',
  ),
];

CarService? serviceById(String id) =>
    serviceCatalog.where((s) => s.id == id).firstOrNull;

List<CarService> servicesIn(ServiceCategory c) =>
    serviceCatalog.where((s) => s.category == c).toList();

/// Shown on the home screen.
final popularServices = [
  serviceById('wash-full')!,
  serviceById('3m-wax-exterior')!,
  serviceById('dry-cleaning')!,
  serviceById('monthly-3')!,
];
