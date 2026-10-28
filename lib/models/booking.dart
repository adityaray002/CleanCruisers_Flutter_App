import 'dart:math';
import '../core/format.dart';
import '../core/pricing.dart';
import '../data/business_info.dart';
import 'service.dart';

// ── Time slots ────────────────────────────────────────────────────────────────
class TimeSlot {
  final String id, name;
  final int startHour, endHour;
  const TimeSlot(this.id, this.name, this.startHour, this.endHour);

  String get range => '${hourLabel(startHour)} – ${hourLabel(endHour)}';
  String get label => '$name, $range';

  /// A slot is bookable if at least 2 hours of it are still ahead of us, so the
  /// team has time to arrive and finish.
  bool isAvailable(DateTime day, {DateTime? now}) {
    final n = now ?? DateTime.now();
    if (dateOnly(day).isBefore(dateOnly(n))) return false;
    if (dateOnly(day).isAfter(dateOnly(n))) return true;
    final latestStart = DateTime(n.year, n.month, n.day, endHour - 2);
    return n.isBefore(latestStart);
  }
}

const timeSlots = [
  TimeSlot('morning', 'Morning', kOpenHour, 11),
  TimeSlot('afternoon', 'Afternoon', 11, 15),
  TimeSlot('evening', 'Evening', 15, kCloseHour),
];

TimeSlot? slotById(String? id) =>
    timeSlots.where((s) => s.id == id).firstOrNull;

/// Number of days ahead a customer can book.
const kBookingWindowDays = 14;

// ── Booking draft (while the customer is going through the flow) ──────────────
class BookingDraft {
  final CarService service;
  final CarType? car;
  final String carModel;
  final Map<String, int> extras; // extra id → qty
  final DateTime? date;
  final String? slotId;
  final String name;
  final String phone;
  final String address;
  final String? pin; // "lat,lng" from GPS

  const BookingDraft({
    required this.service,
    this.car,
    this.carModel = '',
    this.extras = const {},
    this.date,
    this.slotId,
    this.name = '',
    this.phone = '',
    this.address = '',
    this.pin,
  });

  BookingDraft copyWith({
    CarType? car,
    String? carModel,
    Map<String, int>? extras,
    DateTime? date,
    String? slotId,
    bool clearSlot = false,
    String? name,
    String? phone,
    String? address,
    String? pin,
    bool clearPin = false,
  }) =>
      BookingDraft(
        service: service,
        car: car ?? this.car,
        carModel: carModel ?? this.carModel,
        extras: extras ?? this.extras,
        date: date ?? this.date,
        slotId: clearSlot ? null : (slotId ?? this.slotId),
        name: name ?? this.name,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        pin: clearPin ? null : (pin ?? this.pin),
      );

  TimeSlot? get slot => slotById(slotId);

  int get servicePrice => car == null ? 0 : service.priceFor(car!);

  List<(Extra, int)> get selectedExtras => [
        for (final e in service.extras)
          if ((extras[e.id] ?? 0) > 0) (e, extras[e.id]!),
      ];

  int get extrasTotal =>
      selectedExtras.fold(0, (sum, x) => sum + x.$1.price * x.$2);

  int get total => servicePrice + extrasTotal;

  // Step validity
  bool get carDone => car != null;
  bool get scheduleDone =>
      date != null && slot != null && slot!.isAvailable(date!);
  static final phoneRe = RegExp(r'^[6-9]\d{9}$');
  bool get nameValid => name.trim().length >= 2;
  bool get phoneValid => phoneRe.hasMatch(phone.trim());
  bool get addressValid => address.trim().length >= 8;
  bool get detailsDone => nameValid && phoneValid && addressValid;
}

// ── Saved booking request ─────────────────────────────────────────────────────
class BookingRecord {
  final String ref;
  final DateTime createdAt;
  final String serviceId;
  final String serviceName;
  final CarType car;
  final String carModel;
  final List<(String name, int qty, int price)> extras;
  final int servicePrice;
  final int total;
  final DateTime date;
  final String slotLabel;
  final String name;
  final String phone;
  final String address;
  final String? pin;

  const BookingRecord({
    required this.ref,
    required this.createdAt,
    required this.serviceId,
    required this.serviceName,
    required this.car,
    required this.carModel,
    required this.extras,
    required this.servicePrice,
    required this.total,
    required this.date,
    required this.slotLabel,
    required this.name,
    required this.phone,
    required this.address,
    this.pin,
  });

  factory BookingRecord.fromDraft(BookingDraft d, {DateTime? now}) {
    final t = now ?? DateTime.now();
    return BookingRecord(
      ref: newBookingRef(),
      createdAt: t,
      serviceId: d.service.id,
      serviceName: d.service.name,
      car: d.car!,
      carModel: d.carModel.trim(),
      extras: [
        for (final (e, q) in d.selectedExtras) (e.name, q, e.price * q),
      ],
      servicePrice: d.servicePrice,
      total: d.total,
      date: d.date!,
      slotLabel: d.slot!.label,
      name: d.name.trim(),
      phone: d.phone.trim(),
      address: d.address.trim(),
      pin: d.pin,
    );
  }

  /// Upcoming until the end of the booked day.
  bool isUpcoming({DateTime? now}) =>
      !dateOnly(date).isBefore(dateOnly(now ?? DateTime.now()));

  String get carLabel => carModel.isEmpty
      ? carTypeNames[car]!
      : '$carModel · ${carTypeNames[car]}';

  String? get mapsUrl {
    if (pin == null) return null;
    return 'https://maps.google.com/?q=${pin!.replaceAll(' ', '')}';
  }

  String whatsAppMessage() {
    final b = StringBuffer()
      ..writeln('*CleanCruisers booking request*')
      ..writeln('Ref: $ref')
      ..writeln()
      ..writeln('*Service:* $serviceName')
      ..writeln('*Car:* $carLabel');
    if (extras.isNotEmpty) {
      b.writeln('*Extras:*');
      for (final (n, q, p) in extras) {
        b.writeln('  • $n${q > 1 ? ' × $q' : ''} (${rupees(p)})');
      }
    }
    b
      ..writeln()
      ..writeln('*Date:* ${shortDate(date)} ${date.year}')
      ..writeln('*Time:* $slotLabel')
      ..writeln()
      ..writeln('*Name:* $name')
      ..writeln('*Phone:* +91 $phone')
      ..writeln('*Address:* $address');
    if (mapsUrl != null) b.writeln('*Location pin:* $mapsUrl');
    b
      ..writeln()
      ..writeln('*Estimated total:* ${rupees(total)}')
      ..writeln()
      ..write('Please confirm my slot. Thank you!');
    return b.toString();
  }

  Map<String, dynamic> toJson() => {
        'ref': ref,
        'createdAt': createdAt.toIso8601String(),
        'serviceId': serviceId,
        'serviceName': serviceName,
        'car': car.name,
        'carModel': carModel,
        'extras': [
          for (final (n, q, p) in extras) {'n': n, 'q': q, 'p': p}
        ],
        'servicePrice': servicePrice,
        'total': total,
        'date': date.toIso8601String(),
        'slotLabel': slotLabel,
        'name': name,
        'phone': phone,
        'address': address,
        'pin': pin,
      };

  factory BookingRecord.fromJson(Map<String, dynamic> j) => BookingRecord(
        ref: j['ref'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        serviceId: j['serviceId'] as String,
        serviceName: j['serviceName'] as String,
        car: CarType.values.byName(j['car'] as String),
        carModel: j['carModel'] as String? ?? '',
        extras: [
          for (final e in (j['extras'] as List? ?? const []))
            ((e as Map)['n'] as String, e['q'] as int, e['p'] as int),
        ],
        servicePrice: j['servicePrice'] as int,
        total: j['total'] as int,
        date: DateTime.parse(j['date'] as String),
        slotLabel: j['slotLabel'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String,
        address: j['address'] as String,
        pin: j['pin'] as String?,
      );
}

/// Short, readable reference like "CC-7K4Q2". No ambiguous characters.
String newBookingRef([Random? rng]) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final r = rng ?? Random();
  return 'CC-${List.generate(5, (_) => chars[r.nextInt(chars.length)]).join()}';
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
