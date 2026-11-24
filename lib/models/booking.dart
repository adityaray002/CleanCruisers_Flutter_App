import 'dart:math';
import '../core/pricing.dart';

// What the app keeps about a customer and their bookings on the phone. The
// bookings themselves live on the server (docs/API_CONTRACT.md); this file
// only holds the saved profile, address-line helpers, the booking reference
// and the on-site durations the test-build server uses.

/// Indian mobile number, 10 digits, starting 6–9.
final kPhoneRe = RegExp(r'^[6-9]\d{9}$');

// ── Service time ──────────────────────────────────────────────────────────────
/// Added minutes per unit for each add-on, from the owner's chart.
const addonMinutes = {'seat': 15, 'roof': 60, 'door': 60, 'ac': 25};

/// Add-ons sold in the app whose time is not on the owner's chart. A booking
/// with one of these can't be auto-confirmed until the owner sets a time.
const addonsWithUnconfirmedTime = {'air-freshener'};

/// Owner supplied on-site durations in minutes (safe upper estimate where the
/// chart gives a range). Includes tools, setup and pack-up; excludes travel.
int baseServiceMinutes(String serviceId, CarType? car) {
  final type = car ?? CarType.hatchback;
  final big = type == CarType.suv || type == CarType.luxury;
  return switch (serviceId) {
    'wash-full' => big ? 150 : 120,
    'wash-exterior' ||
    'wash-interior' ||
    'wash-bucket' ||
    'monthly-bucket' =>
      60,
    'monthly-3' => big ? 150 : 120,
    'dry-cleaning' => 180,
    '3m-wax-exterior' => 120,
    'rubbing-exterior' => 180,
    'rubbing-wax-exterior' => type == CarType.sedan ? 120 : 180,
    'dryclean-wax-exterior' => big ? 270 : 240,
    'rubbing-dryclean-exterior' || 'full-package' => 300,
    _ => 300, // unknown service: assume the longest job, never shorter
  };
}

int bookingDurationMinutes(
        String serviceId, CarType? car, Map<String, int> extras) =>
    baseServiceMinutes(serviceId, car) +
    extras.entries
        .fold(0, (sum, e) => sum + (addonMinutes[e.key] ?? 0) * e.value);

String durationLabel(int minutes) => minutes % 60 == 0
    ? '${minutes ~/ 60} hr${minutes == 60 ? '' : 's'}'
    : minutes < 60
        ? '$minutes min'
        : '${minutes ~/ 60} hr ${minutes % 60} min';

// ── Address line ──────────────────────────────────────────────────────────────
/// Where the car stands, so the expert knows where to look.
const parkingOptions = [
  'Basement parking',
  'Open parking',
  'Outside the house',
  'Office parking',
];

const _parkingTag = ' · Parking: ';

/// Builds one address line from its parts. Returns '' until the two parts an
/// expert can't do without (house/flat and area) are filled in.
String composeAddress(Map<String, String> parts) {
  String part(String k) => (parts[k] ?? '').trim();
  final flat = part('flat'), area = part('area');
  if (flat.isEmpty || area.length < 3) return '';
  final landmark = part('landmark')
      .replaceFirst(RegExp(r'^near\s+', caseSensitive: false), '');
  final line = [flat, if (part('building').isNotEmpty) part('building'), area]
      .join(', ');
  return withParking(
      landmark.isEmpty ? line : '$line, near $landmark', parts['parking']);
}

/// [address] with its parking note replaced by [parking] (or removed).
String withParking(String address, String? parking) {
  final i = address.indexOf(_parkingTag);
  final base = (i < 0 ? address : address.substring(0, i)).trim();
  if (base.isEmpty) return '';
  return parking == null || parking.isEmpty
      ? base
      : '$base$_parkingTag$parking';
}

/// The parking note inside [address], if any.
String? parkingOf(String address) {
  final i = address.indexOf(_parkingTag);
  return i < 0 ? null : address.substring(i + _parkingTag.length).trim();
}

/// A request reference like "CC-7K4Q2X9M", made on the phone and sent as
/// the `clientRef` (contract §1): a retry with the same one never creates a
/// second booking.
String newBookingRef([Random? rng]) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final r = rng ?? Random.secure();
  return 'CC-${List.generate(8, (_) => chars[r.nextInt(chars.length)]).join()}';
}

// ── Saved customer details (so repeat bookings are one tap) ───────────────────
class CustomerProfile {
  final String name, phone, address;
  final String? pin;
  final CarType? car;
  final String carModel;

  const CustomerProfile({
    this.name = '',
    this.phone = '',
    this.address = '',
    this.pin,
    this.car,
    this.carModel = '',
  });

  bool get isEmpty =>
      name.isEmpty && phone.isEmpty && address.isEmpty && car == null;

  /// Car and address are saved, so bookings need no questions.
  bool get ready => car != null && address.trim().isNotEmpty;

  CustomerProfile copyWith({
    String? name,
    String? phone,
    String? address,
    String? pin,
    bool clearPin = false,
    CarType? car,
    String? carModel,
  }) =>
      CustomerProfile(
        name: name ?? this.name,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        pin: clearPin ? null : (pin ?? this.pin),
        car: car ?? this.car,
        carModel: carModel ?? this.carModel,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'address': address,
        'pin': pin,
        'car': car?.name,
        'carModel': carModel,
      };

  factory CustomerProfile.fromJson(Map<String, dynamic> j) => CustomerProfile(
        name: j['name'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        address: j['address'] as String? ?? '',
        pin: j['pin'] as String?,
        car:
            j['car'] == null ? null : CarType.values.byName(j['car'] as String),
        carModel: j['carModel'] as String? ?? '',
      );
}
