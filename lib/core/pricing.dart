// All pricing data mirrors cleancruisers web app (src/lib/pricing.ts)

enum CarType { hatchback, sedan, suv, luxury }

enum ServiceType { oneTime, premiumAddons, completeCare }

enum WashPackage { exteriorInterior, exteriorOnly, interiorOnly }

const Map<CarType, String> carTypeNames = {
  CarType.hatchback: 'Hatchback',
  CarType.sedan: 'Sedan',
  CarType.suv: 'SUV',
  CarType.luxury: 'Luxury',
};

const Map<CarType, String> carTypeIcons = {
  CarType.hatchback: '🚗',
  CarType.sedan: '🚘',
  CarType.suv: '🚙',
  CarType.luxury: '🏎',
};

// ── One-Time Wash Package Prices ───────────────────────────────────────────────
const Map<WashPackage, Map<CarType, int>> washPackagePrices = {
  WashPackage.exteriorInterior: {
    CarType.hatchback: 449,
    CarType.sedan: 499,
    CarType.suv: 549,
    CarType.luxury: 549,
  },
  WashPackage.exteriorOnly: {
    CarType.hatchback: 349,
    CarType.sedan: 349,
    CarType.suv: 399,
    CarType.luxury: 399,
  },
  WashPackage.interiorOnly: {
    CarType.hatchback: 349,
    CarType.sedan: 349,
    CarType.suv: 399,
    CarType.luxury: 399,
  },
};

const Map<WashPackage, String> washPackageNames = {
  WashPackage.exteriorInterior: 'Exterior + Interior Wash',
  WashPackage.exteriorOnly: 'Exterior Wash Only',
  WashPackage.interiorOnly: 'Interior Deep Clean',
};

const Map<WashPackage, List<String>> washPackageInclusions = {
  WashPackage.exteriorInterior: [
    'Foam shampoo & high-pressure wash',
    'Alloy wheel & tyre cleaning',
    'Tyre polishing',
    'Interior vacuuming',
    'Exterior + interior black part polish',
    'Footmat cleaning',
    'Dashboard polish',
    'Dicky vacuuming',
  ],
  WashPackage.exteriorOnly: [
    'Foam wash & high-pressure wash',
    'Alloy & tyre cleaning',
    'Tyre polishing',
    'Exterior black part & body polish',
  ],
  WashPackage.interiorOnly: [
    'Interior cleaning & vacuum',
    'Interior black part polishing',
    'Footmat cleaning',
    'Dashboard polish',
    'Seats vacuuming',
    'Dicky vacuuming',
  ],
};

// ── Optional Wash Add-ons ──────────────────────────────────────────────────────
const Map<String, String> washAddonNames = {
  'seat': 'Seat Cleaning (per seat)',
  'roof': 'Roof Cleaning',
  'door': 'Door & Dashboard Shampoo Cleaning',
  'ac': 'AC Vent & Foam Cleaning',
};

const Map<String, int> washAddonPrices = {
  'seat': 100,
  'roof': 200,
  'door': 250,
  'ac': 250,
};

// ── Premium Add-on Services ────────────────────────────────────────────────────
class AddonService {
  final String id;
  final String name;
  final String description;
  final List<String> inclusions;
  const AddonService({
    required this.id,
    required this.name,
    required this.description,
    required this.inclusions,
  });
}

const premiumAddons = <AddonService>[
  AddonService(
    id: 'rubbing-exterior',
    name: 'Rubbing + Exterior Foam Wash',
    description: 'A deep paint restoration service that removes oxidation, light scratches, and dullness, followed by a premium foam wash for a glossy finish.',
    inclusions: [
      'Full Body Rubbing & Buffing (Rotary Machine)',
      'Exterior Foam Shampoo Wash',
      'High-Pressure Water Wash',
      'Alloy Wheel & Tyre Cleaning',
      'Tyre Polishing',
      'Exterior Black Part Polishing',
    ],
  ),
  AddonService(
    id: '3m-wax-exterior',
    name: '3M Wax + Exterior Foam Wash',
    description: 'A high-quality wax polish by 3M for paint protection and shine, combined with a professional foam wash.',
    inclusions: [
      '3M Wax Polish',
      'Exterior Foam Shampoo Wash',
      'High-Pressure Water Wash',
      'Alloy Wheel & Tyre Cleaning',
      'Tyre Polishing',
      'Exterior Black Part Polishing',
    ],
  ),
  AddonService(
    id: 'rubbing-wax-exterior',
    name: 'Rubbing + 3M Wax + Exterior Foam Wash',
    description: 'A complete exterior treatment with rubbing, wax, and foam wash for maximum shine and protection.',
    inclusions: [
      'Full Body Rubbing & Buffing (Rotary Machine)',
      '3M Wax Polish',
      'Exterior Foam Shampoo Wash',
      'High-Pressure Water Wash',
      'Alloy Wheel & Tyre Cleaning',
      'Tyre Polishing',
      'Exterior Black Part Polishing',
    ],
  ),
  AddonService(
    id: 'full-package',
    name: 'Rubbing + 3M Wax + Dry Cleaning + Exterior Foam Wash',
    description: 'Complete car care – inside and out. Our most comprehensive package for a full showroom-level transformation.',
    inclusions: [
      'Full Body Rubbing & Buffing (Rotary Machine)',
      '3M Wax Polish',
      'Exterior Foam Shampoo Wash',
      'High-Pressure Water Wash',
      'Alloy Wheel & Tyre Cleaning',
      'Tyre Polishing',
      'Exterior Black Part Polishing',
      'Car Interior Dashboard Cleaning & Polishing',
      'Deep Clean & Shampoo Of Car Seats (Upholstery)',
      'Floor Mats Cleaning',
      'Seat Belts Cleaning',
      'Roof Cleaning',
      'Door Cleaning & Polishing',
      'Car Interior Vacuum Cleaning & Floor Deep Cleaning',
      'Boot (Diggi) Cleaning & Polishing',
      'Polishing All Plastic Parts',
      'AC Vents Dry Dusting',
    ],
  ),
  AddonService(
    id: 'rubbing-dryclean-exterior',
    name: 'Rubbing + Dry Cleaning + Exterior Foam Wash',
    description: 'Exterior paint polish plus full interior dry cleaning — the best of both worlds.',
    inclusions: [
      'Full Body Rubbing & Buffing (Rotary Machine)',
      'Exterior Foam Shampoo Wash',
      'High-Pressure Water Wash',
      'Alloy Wheel & Tyre Cleaning',
      'Tyre Polishing',
      'Exterior Black Part Polishing',
      'Car Interior Dashboard Cleaning & Polishing',
      'Deep Clean & Shampoo Of Car Seats (Upholstery)',
      'Floor Mats Cleaning',
      'Seat Belts Cleaning',
      'Roof Cleaning',
      'Door Cleaning & Polishing',
      'Car Interior Vacuum Cleaning & Floor Deep Cleaning',
      'Boot (Diggi) Cleaning & Polishing',
      'Polishing All Plastic Parts',
      'AC Vents Dry Dusting',
    ],
  ),
  AddonService(
    id: 'dryclean-wax-exterior',
    name: 'Dry Cleaning + 3M Wax + Exterior Foam Wash',
    description: 'Balanced inside-out care with 3M wax protection and a deep interior dry clean.',
    inclusions: [
      '3M Wax Polish',
      'Exterior Foam Shampoo Wash',
      'Car Interior Dashboard Cleaning & Polishing',
      'Deep Clean & Shampoo Of Car Seats (Upholstery)',
      'Floor Mats Cleaning',
      'Seat Belts Cleaning',
      'Roof Cleaning',
      'Door Cleaning & Polishing',
      'Car Interior Vacuum Cleaning & Floor Deep Cleaning',
      'Boot (Diggi) Cleaning & Polishing',
      'Polishing All Plastic Parts',
      'AC Vents Dry Dusting',
    ],
  ),
  AddonService(
    id: 'dry-cleaning',
    name: 'Dry Cleaning',
    description: 'Deep interior cleaning for seats, mats, roof, and dashboard. Makes your cabin feel brand new.',
    inclusions: [
      'Car Interior Dashboard Cleaning & Polishing',
      'Deep Clean & Shampoo Of Car Seats (Upholstery)',
      'Floor Mats Cleaning',
      'Seat Belts Cleaning',
      'Roof Cleaning',
      'Door Cleaning & Polishing',
      'Car Interior Vacuum Cleaning & Floor Deep Cleaning',
      'Boot (Diggi) Cleaning & Polishing',
      'Polishing All Plastic Parts',
      'AC Vents Dry Dusting',
    ],
  ),
  AddonService(
    id: 'air-freshener',
    name: 'Air Freshener',
    description: 'Keeps your car smelling fresh and inviting after every drive.',
    inclusions: [
      'Premium Long-Lasting Fragrance',
      'Keeps Cabin Fresh & Pleasant',
    ],
  ),
];

const Map<String, Map<CarType, int>> premiumAddonPrices = {
  'rubbing-exterior': {
    CarType.hatchback: 1599,
    CarType.sedan: 1599,
    CarType.suv: 1799,
    CarType.luxury: 1899,
  },
  '3m-wax-exterior': {
    CarType.hatchback: 649,
    CarType.sedan: 649,
    CarType.suv: 749,
    CarType.luxury: 949,
  },
  'rubbing-wax-exterior': {
    CarType.hatchback: 1699,
    CarType.sedan: 1699,
    CarType.suv: 1899,
    CarType.luxury: 1999,
  },
  'full-package': {
    CarType.hatchback: 2499,
    CarType.sedan: 2499,
    CarType.suv: 2699,
    CarType.luxury: 2799,
  },
  'rubbing-dryclean-exterior': {
    CarType.hatchback: 2199,
    CarType.sedan: 2199,
    CarType.suv: 2399,
    CarType.luxury: 2499,
  },
  'dryclean-wax-exterior': {
    CarType.hatchback: 1499,
    CarType.sedan: 1499,
    CarType.suv: 1699,
    CarType.luxury: 1799,
  },
  'dry-cleaning': {
    CarType.hatchback: 999,
    CarType.sedan: 999,
    CarType.suv: 1099,
    CarType.luxury: 1099,
  },
  'air-freshener': {
    CarType.hatchback: 149,
    CarType.sedan: 149,
    CarType.suv: 149,
    CarType.luxury: 149,
  },
};

// ── Complete Care Monthly Package Prices ────────────────────────────────────────
const Map<CarType, int> completeCarePrice = {
  CarType.hatchback: 1399,
  CarType.sedan: 1499,
  CarType.suv: 1599,
  CarType.luxury: 1599,
};

const completeCareInclusions = [
  'Interior Cleaning + Vacuum',
  'Interior Black Part Polish',
  'Exterior Foam Wash',
  'Dicky Cleaning',
  'Tyre Polishing',
  'Exterior Black Part Polish',
  'Footmat Cleaning',
  'Free Dustbin (1 pc)',
  'Free Room Odor / Air Freshener',
  '3 Premium Washes Included',
];

// ── Monthly Doorstep Plan ───────────────────────────────────────────────────────
const Map<CarType, int> monthlyPlanPrice = {
  CarType.hatchback: 799,
  CarType.sedan: 799,
  CarType.suv: 999,
  CarType.luxury: 1199,
};
