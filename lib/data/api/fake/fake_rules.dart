// Business settings and data the fake server runs on.
//
// These mirror what ShineStaff will hold in its Settings and catalog
// (docs/SHINESTAFF_ADMIN_PARITY.md, sections H, I, J). Figures marked
// ASSUMPTION are placeholders until the owner gives real numbers.

import '../../../core/pricing.dart';
import '../../../models/booking.dart' show baseServiceMinutes, addonMinutes;
import '../../../models/service.dart';
import '../models.dart';

class FakeSettings {
  /// Working hours (owner: 8 AM – 6 PM). Customer work must be done by [close].
  final int open, close;

  /// Earliest arrival at a customer (the worker leaves home at [open]).
  final int firstArrival;

  /// Start times are offered on this grid.
  final int slotStep;

  /// Starts sooner than this from now are not offered (ASSUMPTION: 2 h).
  final int minLeadMinutes;

  /// How many days ahead a customer can book.
  final int bookingWindowDays;

  /// Drive time blocked before each job, and buffer after it (ASSUMPTION).
  final int travelMinutes, bufferMinutes;

  /// A 30 min lunch must fit inside [lunchFrom, lunchTo].
  final int lunchMinutes, lunchFrom, lunchTo;

  /// The team aims to confirm within this many working minutes.
  final int confirmWithinMinutes;

  /// Max bookings waiting for confirmation per phone (H6).
  final int pendingLimit;

  /// Cost model for the margin floor (J1). ASSUMPTIONS: ₹17,000 salary over
  /// 26 days of 570 working minutes; ₹5/km × 8 km + 25 min of worker time.
  final double workerCostPerMinute;
  final int travelCostPerTrip;
  final int marginFloor;
  final int gstRate;

  /// Cancel policy: free until [cancelFreeHours] before; ₹[cancelFee] within
  /// [cancelFeeHours] (between the two: free; see open question in the spec).
  final int cancelFreeHours, cancelFeeHours, cancelFee;

  /// CleanCredit (J4).
  final int cashbackPercent, creditExpiryDays, referralReward, referralMinBill, rainCredit;

  /// Automatic offers (J3).
  final int sameBuildingOff, secondCarOff;

  /// Plans (J5).
  final int planMissExtensionDays;

  /// How long a team offer or an on-site change stays open.
  final int offerHours, changeMinutes;

  const FakeSettings({
    this.open = 8 * 60,
    this.close = 18 * 60,
    this.firstArrival = 8 * 60 + 30,
    this.slotStep = 30,
    this.minLeadMinutes = 120,
    this.bookingWindowDays = 14,
    this.travelMinutes = 25,
    this.bufferMinutes = 15,
    this.lunchMinutes = 30,
    this.lunchFrom = 12 * 60 + 30,
    this.lunchTo = 15 * 60,
    this.confirmWithinMinutes = 120,
    this.pendingLimit = 2,
    this.workerCostPerMinute = 17000 / 26 / 570,
    this.travelCostPerTrip = 69,
    this.marginFloor = 60,
    this.gstRate = 18,
    this.cancelFreeHours = 4,
    this.cancelFeeHours = 2,
    this.cancelFee = 100,
    this.cashbackPercent = 5,
    this.creditExpiryDays = 60,
    this.referralReward = 100,
    this.referralMinBill = 449,
    this.rainCredit = 50,
    this.sameBuildingOff = 50,
    this.secondCarOff = 75,
    this.planMissExtensionDays = 7,
    this.offerHours = 12,
    this.changeMinutes = 30,
  });
}

/// Material cost per job, rupees (ASSUMPTION until the owner gives real costs).
const fakeMaterialCost = <String, int>{
  'wash-full': 60,
  'wash-exterior': 40,
  'wash-interior': 40,
  'wash-bucket': 20,
  'dry-cleaning': 200,
  '3m-wax-exterior': 150,
  'rubbing-exterior': 150,
  'rubbing-wax-exterior': 250,
  'dryclean-wax-exterior': 300,
  'rubbing-dryclean-exterior': 300,
  'full-package': 350,
  // extras
  'seat': 15,
  'roof': 20,
  'door': 25,
  'ac': 25,
  'air-freshener': 60,
};

/// Air freshener has no owner-given time yet (ASSUMPTION: 10 min).
const _extraMinutes = {...addonMinutes, 'air-freshener': 10};

/// The catalog the fake server serves, built from the prices and durations
/// bundled in the app today, so the fake and the current app agree.
Catalog buildFakeCatalog() {
  final services = <CatalogService>[
    for (final s in serviceCatalog)
      if (s.category != ServiceCategory.monthly)
        CatalogService(
          id: s.id,
          category: s.category.name,
          name: s.name,
          prices: Map.of(s.prices),
          durationMinutes: {
            for (final c in CarType.values) c: baseServiceMinutes(s.id, c),
          },
          extras: [
            for (final e in s.extras)
              CatalogExtra(
                id: e.id,
                name: e.name,
                price: e.price,
                maxQty: e.maxQty,
                unit: e.unit,
                minutes: _extraMinutes[e.id] ?? 0,
              ),
          ],
        ),
  ];
  return Catalog(version: '2026-11-21', services: services, plans: const [
    CatalogPlan(
      id: 'monthly-3',
      name: 'Complete Care',
      serviceId: 'wash-full',
      visits: 3,
      days: 30,
      prices: {
        CarType.hatchback: 1399,
        CarType.sedan: 1499,
        CarType.suv: 1599,
        CarType.luxury: 1599,
      },
      includes: [
        'Free car dustbin',
        'Air freshener',
        'Fixed weekday visit',
        'Price locked for the month',
      ],
    ),
    CatalogPlan(
      id: 'monthly-bucket',
      name: 'Bucket Wash Plan',
      serviceId: 'wash-bucket',
      visits: 4,
      days: 30,
      // SUV and luxury are the suggested prices, still to be confirmed.
      prices: {
        CarType.hatchback: 899,
        CarType.sedan: 899,
        CarType.suv: 1099,
        CarType.luxury: 1299,
      },
      includes: ['One bucket wash a week'],
      onlyInAreas: true,
    ),
  ]);
}

/// Detailing jobs need a worker with the detailing skill.
bool needsDetailing(CatalogService s) => s.category == 'detailing';

// ── Workers ───────────────────────────────────────────────────────────────────

enum FakeCompany { cleanCruisers, sofaShine, both }

class FakeWorker {
  final String id, name;
  final FakeCompany company;
  final int? weeklyOff; // DateTime.monday … DateTime.sunday
  final bool detailing;
  final bool active;
  const FakeWorker(this.id, this.name,
      {this.company = FakeCompany.cleanCruisers,
      this.weeklyOff,
      this.detailing = false,
      this.active = true});

  bool worksOn(DateTime day) => active && day.weekday != weeklyOff;
  bool canDoCleanCruisers() => company != FakeCompany.sofaShine;
}

/// ASSUMPTION: a small team for testing (names are placeholders, never shown
/// to customers).
const fakeWorkers = [
  FakeWorker('w1', 'Worker 1', weeklyOff: DateTime.tuesday, detailing: true),
  FakeWorker('w2', 'Worker 2', weeklyOff: DateTime.wednesday),
  FakeWorker('w3', 'Worker 3', weeklyOff: DateTime.thursday),
  FakeWorker('w4', 'Worker 4', company: FakeCompany.both, weeklyOff: DateTime.friday, detailing: true),
  FakeWorker('w5', 'Worker 5', company: FakeCompany.both, weeklyOff: DateTime.monday),
];

// ── Coverage ──────────────────────────────────────────────────────────────────

/// ASSUMPTION: service areas as pincode prefixes (Delhi, Gurugram, Noida).
const fakeCoveredPincodePrefixes = ['110', '1220', '2013'];

/// Bucket plan areas (J5: only where several customers are close together).
const fakePlanPincodes = {'110058', '110059', '110018'};

/// Rough Delhi NCR box for pins without a pincode.
bool inNcrBox(double lat, double lng) =>
    lat >= 28.35 && lat <= 28.90 && lng >= 76.85 && lng <= 77.45;

Coverage coverageFor({double? lat, double? lng, String? pincode}) {
  final pin = pincode?.trim() ?? '';
  if (pin.length == 6) {
    return fakeCoveredPincodePrefixes.any(pin.startsWith)
        ? Coverage.covered
        : Coverage.notCovered;
  }
  if (lat != null && lng != null) {
    return inNcrBox(lat, lng) ? Coverage.covered : Coverage.notCovered;
  }
  return Coverage.unverified;
}

// ── Coupons (J2) ──────────────────────────────────────────────────────────────

class FakeCoupon {
  final String code, title;
  final int flatOff, percentOff, minBill;
  final bool firstBookingOnly, weekdaysOnly;
  final Set<CarType>? cars;
  final Set<String>? categories; // null = any
  final bool active;

  const FakeCoupon(this.code, this.title,
      {this.flatOff = 0,
      this.percentOff = 0,
      this.minBill = 0,
      this.firstBookingOnly = false,
      this.weekdaysOnly = false,
      this.cars,
      this.categories,
      this.active = true});

  String get headline => percentOff > 0 ? '$percentOff% OFF' : '₹$flatOff OFF';

  List<String> get conditions => [
        if (firstBookingOnly) 'First booking only',
        if (minBill > 0) 'Min. bill ₹$minBill',
        if (weekdaysOnly) 'Monday to Friday',
        if (cars != null) '${cars!.map((c) => carTypeNames[c]).join(' / ')} only',
        if (categories != null) '${categories!.join(' / ')} only',
      ];

  PublicOffer toPublic() =>
      PublicOffer(code: code, title: title, headline: headline, conditions: conditions);

  /// Why it can't be used, or null.
  String? whyNot({
    required int subtotal,
    required CarType car,
    required String category,
    required DateTime date,
    required bool firstBooking,
    required bool usedBefore,
  }) {
    if (!active) return 'This offer has ended';
    if (usedBefore) return 'You have already used this offer';
    if (firstBookingOnly && !firstBooking) return 'Only for a first booking';
    if (categories != null && !categories!.contains(category)) {
      return 'Not valid on this service';
    }
    if (cars != null && !cars!.contains(car)) {
      return 'Only for ${cars!.map((c) => carTypeNames[c]).join(' / ')}';
    }
    if (weekdaysOnly && date.weekday > DateTime.friday) {
      return 'Only for Monday to Friday';
    }
    if (subtotal < minBill) return 'Add ₹${minBill - subtotal} more to use it';
    return null;
  }

  int amountFor(int subtotal) =>
      percentOff > 0 ? subtotal * percentOff ~/ 100 : flatOff.clamp(0, subtotal);
}

const fakeCoupons = [
  FakeCoupon('FIRST50', 'Off your first wash',
      flatOff: 50, minBill: 349, firstBookingOnly: true, categories: {'wash'}),
  FakeCoupon('FIRST100', 'Off your first booking',
      flatOff: 100, minBill: 649, firstBookingOnly: true),
  FakeCoupon('WEEKDAY40', 'Off a weekday booking', flatOff: 40, minBill: 449, weekdaysOnly: true),
  FakeCoupon('SUVSPECIAL', 'Off for SUVs', percentOff: 10, cars: {CarType.suv}),
];
