import 'dart:math';
import '../core/format.dart';
import '../core/pricing.dart';
import '../core/scheduling.dart';
import 'service.dart';
import 'worker.dart';

// ── Time slots ────────────────────────────────────────────────────────────────
/// A one-hour preferred arrival window. Operations confirms it only after a
/// worker's whole day route validates (see core/scheduling.dart).
class TimeSlot {
  final String id, name;
  final int startMinute, endMinute;
  const TimeSlot(this.id, this.name, this.startMinute, this.endMinute);

  String get range => '${clockLabel(startMinute)} – ${clockLabel(endMinute)}';

  /// "9:30 – 10:30 AM": what customers see.
  String get short => timeRangeLabel(startMinute, endMinute);
  bool get isMorning => startMinute < 12 * 60;
  String get label => '$name, $range';

  bool isAvailable(DateTime day, {DateTime? now}) {
    final n = now ?? DateTime.now();
    if (dateOnly(day).isBefore(dateOnly(n))) return false;
    if (dateOnly(day).isAfter(dateOnly(n))) return true;
    return n.hour * 60 + n.minute < startMinute;
  }
}

const timeSlots = [
  TimeSlot('0830', 'Early morning', 8 * 60 + 30, 9 * 60 + 30),
  TimeSlot('0930', 'Morning', 9 * 60 + 30, 10 * 60 + 30),
  TimeSlot('1030', 'Late morning', 10 * 60 + 30, 11 * 60 + 30),
  TimeSlot('1130', 'Midday', 11 * 60 + 30, 12 * 60 + 30),
  TimeSlot('1230', 'Early afternoon', 12 * 60 + 30, 13 * 60 + 30),
  TimeSlot('1330', 'Afternoon', 13 * 60 + 30, 14 * 60 + 30),
  TimeSlot('1430', 'Late afternoon', 14 * 60 + 30, 15 * 60 + 30),
  TimeSlot('1530', 'Late afternoon', 15 * 60 + 30, 16 * 60 + 30),
];

TimeSlot? slotById(String? id) =>
    timeSlots.where((s) => s.id == id).firstOrNull;

// ── Status ────────────────────────────────────────────────────────────────────
enum BookingStatus {
  requested,
  teamReview,
  confirmed,
  onTheWay,
  inService,
  rescheduleNeeded,
  completed,
  cancelled,
  unableToServe,
}

extension BookingStatusLabel on BookingStatus {
  String get label => switch (this) {
        BookingStatus.requested => 'Requested',
        BookingStatus.teamReview => 'Team review',
        BookingStatus.confirmed => 'Confirmed',
        BookingStatus.onTheWay => 'On the way',
        BookingStatus.inService => 'In service',
        BookingStatus.rescheduleNeeded => 'Reschedule needed',
        BookingStatus.completed => 'Completed',
        BookingStatus.cancelled => 'Cancelled',
        BookingStatus.unableToServe => 'Unable to serve',
      };

  /// What the status means for the customer, in plain words.
  String get customerMeaning => switch (this) {
        BookingStatus.requested =>
          'Your slot is reserved. An expert is scheduled for your visit.',
        BookingStatus.teamReview =>
          'Our team is checking your booking or needs a detail from you.',
        BookingStatus.confirmed => 'An expert is booked for your slot.',
        BookingStatus.onTheWay => 'Your expert is on the way to your car.',
        BookingStatus.inService => 'Work on your car has started.',
        BookingStatus.rescheduleNeeded =>
          'We can\'t attend at the planned time. Please agree a new date or time with us.',
        BookingStatus.completed => 'Service complete. Thank you!',
        BookingStatus.cancelled => 'This booking was cancelled.',
        BookingStatus.unableToServe =>
          'We\'re sorry, we can\'t serve this booking.',
      };

  bool get isFinal => {
        BookingStatus.completed,
        BookingStatus.cancelled,
        BookingStatus.unableToServe,
      }.contains(this);

  /// Statuses where capacity for the date/window is still held.
  bool get holdsCapacity => !isFinal && this != BookingStatus.rescheduleNeeded;
}

/// Reads stored statuses, including names used by earlier app versions.
BookingStatus parseStatus(Object? raw) => switch (raw) {
      'assigned' => BookingStatus.confirmed,
      'inProgress' => BookingStatus.inService,
      'rescheduleRequested' => BookingStatus.teamReview,
      'weatherHold' => BookingStatus.rescheduleNeeded,
      _ => BookingStatus.values.where((s) => s.name == raw).firstOrNull ??
          BookingStatus.requested,
    };

class StatusEvent {
  final BookingStatus status;
  final DateTime at;
  final String? note; // customer-visible
  const StatusEvent(this.status, this.at, [this.note]);

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'at': at.toIso8601String(),
        if (note != null) 'note': note,
      };

  static StatusEvent? fromJson(Object? j) {
    if (j is! Map) return null;
    final at = DateTime.tryParse(j['at'] as String? ?? '');
    if (at == null) return null;
    return StatusEvent(parseStatus(j['status']), at, j['note'] as String?);
  }
}

/// Number of days ahead a customer can book.
const kBookingWindowDays = 14;

// ── Service time ──────────────────────────────────────────────────────────────
/// Bump when prices or durations change so each booking records which
/// catalog it was priced from.
const kCatalogVersion = '2026-10-31';

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

// ── Booking draft (while the customer is going through the flow) ──────────────
enum BookingFor { me, someoneElse }

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

enum PinSource { gps, pasted }

class BookingDraft {
  /// Display reference, also the idempotency key: retries reuse it, so a
  /// double tap or a lost acknowledgement never creates a second booking.
  final String bookingRef;
  final CarService service;
  final CarType? car;
  final String carModel;
  final Map<String, int> extras; // extra id → qty
  final DateTime? date;
  final String? slotId;
  final BookingFor bookingFor;
  final String name; // booker
  final String phone; // booker
  final String recipientName;
  final String recipientPhone;
  final bool notifyRecipient;
  final String address; // where the car is
  final String? pin; // "lat,lng" of the car
  final PinSource? pinSource;
  final Coverage coverage;

  /// Address typed field by field (flat, building, area, landmark, parking).
  final Map<String, String> addressParts;

  /// The customer's saved address and pin, offered as a one-tap choice.
  final String savedAddress;
  final String? savedPin;
  final bool usingSaved;
  final bool useCleanCredit;
  final String? couponCode;
  final int couponDiscount;

  const BookingDraft({
    required this.service,
    this.bookingRef = '',
    this.car,
    this.carModel = '',
    this.extras = const {},
    this.date,
    this.slotId,
    this.bookingFor = BookingFor.me,
    this.name = '',
    this.phone = '',
    this.recipientName = '',
    this.recipientPhone = '',
    this.notifyRecipient = false,
    this.address = '',
    this.pin,
    this.pinSource,
    this.coverage = Coverage.unverified,
    this.addressParts = const {},
    this.savedAddress = '',
    this.savedPin,
    this.usingSaved = false,
    this.useCleanCredit = true,
    this.couponCode,
    this.couponDiscount = 0,
  });

  BookingDraft copyWith({
    CarType? car,
    String? carModel,
    Map<String, int>? extras,
    DateTime? date,
    String? slotId,
    bool clearSlot = false,
    BookingFor? bookingFor,
    String? name,
    String? phone,
    String? recipientName,
    String? recipientPhone,
    bool? notifyRecipient,
    String? address,
    String? pin,
    PinSource? pinSource,
    bool clearPin = false,
    Coverage? coverage,
    Map<String, String>? addressParts,
    bool? usingSaved,
    bool? useCleanCredit,
    String? couponCode,
    int? couponDiscount,
    bool clearCoupon = false,
  }) =>
      BookingDraft(
        service: service,
        bookingRef: bookingRef,
        car: car ?? this.car,
        carModel: carModel ?? this.carModel,
        extras: extras ?? this.extras,
        date: date ?? this.date,
        slotId: clearSlot ? null : (slotId ?? this.slotId),
        bookingFor: bookingFor ?? this.bookingFor,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        recipientName: recipientName ?? this.recipientName,
        recipientPhone: recipientPhone ?? this.recipientPhone,
        notifyRecipient: notifyRecipient ?? this.notifyRecipient,
        address: address ?? this.address,
        pin: clearPin ? null : (pin ?? this.pin),
        pinSource: clearPin ? null : (pinSource ?? this.pinSource),
        coverage: coverage ?? this.coverage,
        addressParts: addressParts ?? this.addressParts,
        savedAddress: savedAddress,
        savedPin: savedPin,
        usingSaved: usingSaved ?? this.usingSaved,
        useCleanCredit: useCleanCredit ?? this.useCleanCredit,
        couponCode: clearCoupon ? null : (couponCode ?? this.couponCode),
        couponDiscount:
            clearCoupon ? 0 : (couponDiscount ?? this.couponDiscount),
      );

  TimeSlot? get slot => slotById(slotId);
  bool get forSomeoneElse => bookingFor == BookingFor.someoneElse;

  int get servicePrice => car == null ? 0 : service.priceFor(car!);

  List<(Extra, int)> get selectedExtras => [
        for (final e in service.extras)
          if ((extras[e.id] ?? 0) > 0) (e, extras[e.id]!),
      ];

  int get extrasTotal =>
      selectedExtras.fold(0, (sum, x) => sum + x.$1.price * x.$2);

  int get total => servicePrice + extrasTotal;

  int get maxAllowedDiscount => total;
  int get maxCouponDiscount => (total * 0.40).floor();

  int maxCleanCreditDeduction(int walletBalance) =>
      min(walletBalance, max(0, total - couponDiscount));

  int cleanCreditDeduction(int walletBalance) =>
      useCleanCredit ? maxCleanCreditDeduction(walletBalance) : 0;

  int payableTotal(int walletBalance) =>
      max(0, total - couponDiscount - cleanCreditDeduction(walletBalance));

  Map<String, int> get _validExtras => {
        for (final (e, q) in selectedExtras) e.id: q,
      };

  int get serviceDurationMinutes =>
      bookingDurationMinutes(service.id, car, _validExtras);

  bool get durationNeedsConfirmation =>
      _validExtras.keys.any(addonsWithUnconfirmedTime.contains);

  // Step validity
  bool get carDone => car != null;

  static final phoneRe = RegExp(r'^[6-9]\d{9}$');
  bool get nameValid => name.trim().length >= 2;
  bool get phoneValid => phoneRe.hasMatch(phone.trim());
  bool get addressValid => address.trim().length >= 8;
  bool get recipientNameValid =>
      !forSomeoneElse || recipientName.trim().length >= 2;
  bool get recipientPhoneValid =>
      !forSomeoneElse ||
      (recipientPhone.trim().isEmpty
          ? !notifyRecipient
          : phoneRe.hasMatch(recipientPhone.trim()));

  /// A GPS pin is the booker's own position, so it can't stand in for
  /// someone else's car.
  bool get pinValid =>
      !(forSomeoneElse && pinSource == PinSource.gps && pin != null);

  bool get detailsDone =>
      nameValid &&
      phoneValid &&
      addressValid &&
      recipientNameValid &&
      recipientPhoneValid &&
      pinValid &&
      coverage != Coverage.notCovered;

  bool get scheduleDone =>
      date != null &&
      slot != null &&
      slot!.isAvailable(date!) &&
      canFinishByClose(slot!.startMinute, serviceDurationMinutes);
}

// ── Payment ───────────────────────────────────────────────────────────────────
enum PaymentMethod { cash, upi }

// ── Saved booking request ─────────────────────────────────────────────────────
class BookingRecord {
  final String ref;
  final DateTime createdAt;
  final String catalogVersion;
  final String serviceId;
  final String serviceName;
  final ServiceCategory category;
  final CarType car;
  final String carModel;
  final List<(String name, int qty, int price)> extras;
  final int servicePrice;
  final int total;

  /// Coupon used on this booking (see lib/data/offers.dart), if any.
  final String? couponCode;
  final int couponDiscount;

  /// CleanCredit taken off this booking.
  final int creditUsed;
  final int serviceDurationMinutes;
  final bool durationNeedsConfirmation;
  final DateTime date;
  final String slotId;
  final String slotLabel;
  final BookingStatus status;
  final List<StatusEvent> history;
  final bool capacityHeld; // counted in the date's capacity record
  final DateTime? offeredDate; // alternative proposed by the team
  final String? offeredSlotId;

  // People. "name/phone" is always the booker.
  final String name;
  final String phone;
  final bool forSomeoneElse;
  final String? recipientName;
  final String? recipientPhone;
  final bool notifyRecipient;

  // Where the car is.
  final String address;
  final String? pin;
  final PinSource? pinSource;
  final Coverage coverage;
  final DateTime? consentAt;

  // Operations.
  final String? workerId;
  final RouteLeg? legIn;
  final RouteLeg? returnLeg;
  final int? plannedArrivalMinute;
  final int? plannedFinishMinute;
  final String? operationsNote;
  final String? customerNote; // last message to the customer
  final String? customerChangeRequest;
  final String? riskFlag;
  final bool creditPreserved;

  // After service.
  final int? amountCollected;
  final PaymentMethod? paymentMethod;
  final DateTime? collectedAt;
  final double? actualKm;
  final int? actualMinutes;

  const BookingRecord({
    required this.ref,
    required this.createdAt,
    this.catalogVersion = kCatalogVersion,
    required this.serviceId,
    required this.serviceName,
    this.category = ServiceCategory.wash,
    required this.car,
    required this.carModel,
    required this.extras,
    required this.servicePrice,
    required this.total,
    this.couponCode,
    this.couponDiscount = 0,
    this.creditUsed = 0,
    required this.serviceDurationMinutes,
    this.durationNeedsConfirmation = false,
    required this.date,
    required this.slotId,
    required this.slotLabel,
    this.status = BookingStatus.requested,
    this.history = const [],
    this.capacityHeld = false,
    this.offeredDate,
    this.offeredSlotId,
    required this.name,
    required this.phone,
    this.forSomeoneElse = false,
    this.recipientName,
    this.recipientPhone,
    this.notifyRecipient = false,
    required this.address,
    this.pin,
    this.pinSource,
    this.coverage = Coverage.unverified,
    this.consentAt,
    this.workerId,
    this.legIn,
    this.returnLeg,
    this.plannedArrivalMinute,
    this.plannedFinishMinute,
    this.operationsNote,
    this.customerNote,
    this.customerChangeRequest,
    this.riskFlag,
    this.creditPreserved = false,
    this.amountCollected,
    this.paymentMethod,
    this.collectedAt,
    this.actualKm,
    this.actualMinutes,
  });

  factory BookingRecord.fromDraft(BookingDraft d,
      {DateTime? now, int walletBalance = 0}) {
    final t = now ?? DateTime.now();
    final other = d.forSomeoneElse;
    return BookingRecord(
      ref: d.bookingRef.isEmpty ? newBookingRef() : d.bookingRef,
      createdAt: t,
      serviceId: d.service.id,
      serviceName: d.service.name,
      category: d.service.category,
      car: d.car!,
      carModel: d.carModel.trim(),
      extras: [
        for (final (e, q) in d.selectedExtras) (e.name, q, e.price * q),
      ],
      servicePrice: d.servicePrice,
      total: d.total,
      couponCode: d.couponDiscount > 0 ? d.couponCode : null,
      couponDiscount: d.couponDiscount,
      creditUsed: d.cleanCreditDeduction(walletBalance),
      serviceDurationMinutes: d.serviceDurationMinutes,
      durationNeedsConfirmation: d.durationNeedsConfirmation,
      date: dateOnly(d.date!),
      slotId: d.slot!.id,
      slotLabel: d.slot!.label,
      history: [StatusEvent(BookingStatus.requested, t)],
      capacityHeld: true,
      name: d.name.trim(),
      phone: d.phone.trim(),
      forSomeoneElse: other,
      recipientName: other ? d.recipientName.trim() : null,
      recipientPhone: other && d.recipientPhone.trim().isNotEmpty
          ? d.recipientPhone.trim()
          : null,
      notifyRecipient: other && d.notifyRecipient,
      address: d.address.trim(),
      pin: d.pinValid ? d.pin : null,
      pinSource: d.pinValid ? d.pinSource : null,
      coverage: d.coverage,
      // Sending follows the consent text shown next to the Send button.
      consentAt: t,
    );
  }

  /// What the customer pays after the wash: total minus coupon and credit.
  int get payable => max(0, total - couponDiscount - creditUsed);

  bool isUpcoming({DateTime? now}) =>
      !dateOnly(date).isBefore(dateOnly(now ?? DateTime.now()));

  String get carLabel => carModel.isEmpty
      ? carTypeNames[car]!
      : '$carModel · ${carTypeNames[car]}';

  /// Arrival time, shown only once the booking is confirmed.
  String? get confirmedArrivalLabel {
    final m = plannedArrivalMinute;
    if (m == null || workerId == null) return null;
    if (!{
      BookingStatus.confirmed,
      BookingStatus.onTheWay,
      BookingStatus.inService,
    }.contains(status)) {
      return null;
    }
    return clockLabel(m);
  }

  DateTime get lastUpdated =>
      history.isEmpty ? createdAt : history.map((e) => e.at).reduce(_later);

  static DateTime _later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  String? get mapsUrl {
    if (pin == null) return null;
    return 'https://maps.google.com/?q=${pin!.replaceAll(' ', '')}';
  }

  Map<String, dynamic> toJson() => {
        'ref': ref,
        'createdAt': createdAt.toIso8601String(),
        'catalogVersion': catalogVersion,
        'serviceId': serviceId,
        'serviceName': serviceName,
        'category': category.name,
        'car': car.name,
        'carModel': carModel,
        'extras': [
          for (final (n, q, p) in extras) {'n': n, 'q': q, 'p': p}
        ],
        'servicePrice': servicePrice,
        'total': total,
        'couponCode': couponCode,
        'couponDiscount': couponDiscount,
        'creditUsed': creditUsed,
        // What the team collects after the wash.
        'payable': payable,
        'serviceDurationMinutes': serviceDurationMinutes,
        'durationNeedsConfirmation': durationNeedsConfirmation,
        'date': date.toIso8601String(),
        'dateKey': dateKey(date),
        'slotId': slotId,
        'slotLabel': slotLabel,
        'status': status.name,
        'history': [for (final e in history) e.toJson()],
        'capacityHeld': capacityHeld,
        'offeredDate': offeredDate?.toIso8601String(),
        'offeredSlotId': offeredSlotId,
        'name': name,
        'phone': phone,
        'forSomeoneElse': forSomeoneElse,
        'recipientName': recipientName,
        'recipientPhone': recipientPhone,
        'notifyRecipient': notifyRecipient,
        'address': address,
        'pin': pin,
        'pinSource': pinSource?.name,
        'coverage': coverage.name,
        'consentAt': consentAt?.toIso8601String(),
        'workerId': workerId,
        'legIn': legIn?.toJson(),
        'returnLeg': returnLeg?.toJson(),
        'plannedArrivalMinute': plannedArrivalMinute,
        'plannedFinishMinute': plannedFinishMinute,
        'operationsNote': operationsNote,
        'customerNote': customerNote,
        'customerChangeRequest': customerChangeRequest,
        'riskFlag': riskFlag,
        'creditPreserved': creditPreserved,
        'amountCollected': amountCollected,
        'paymentMethod': paymentMethod?.name,
        'collectedAt': collectedAt?.toIso8601String(),
        'actualKm': actualKm,
        'actualMinutes': actualMinutes,
      };

  /// Fields a customer may write when creating a request. Operations fields
  /// are left out so Firestore rules can reject a forged assignment.
  Map<String, dynamic> toCustomerJson() {
    final j = toJson();
    for (final k in const [
      'workerId',
      'legIn',
      'returnLeg',
      'plannedArrivalMinute',
      'plannedFinishMinute',
      'operationsNote',
      'customerNote',
      'customerChangeRequest',
      'riskFlag',
      'creditPreserved',
      'amountCollected',
      'paymentMethod',
      'collectedAt',
      'actualKm',
      'actualMinutes',
      'offeredDate',
      'offeredSlotId',
    ]) {
      j.remove(k);
    }
    return j;
  }

  factory BookingRecord.fromJson(Map<String, dynamic> j) {
    DateTime? date(String k) => DateTime.tryParse(j[k] as String? ?? '');
    final status = parseStatus(j['status']);
    final createdAt = DateTime.parse(j['createdAt'] as String);
    final history = [
      for (final e in (j['history'] as List? ?? const []))
        StatusEvent.fromJson(e),
    ].whereType<StatusEvent>().toList();
    return BookingRecord(
      ref: j['ref'] as String,
      createdAt: createdAt,
      catalogVersion: j['catalogVersion'] as String? ?? 'legacy',
      serviceId: j['serviceId'] as String,
      serviceName: j['serviceName'] as String,
      category: ServiceCategory.values
              .where((c) => c.name == j['category'])
              .firstOrNull ??
          ServiceCategory.wash,
      car: CarType.values.byName(j['car'] as String),
      carModel: j['carModel'] as String? ?? '',
      extras: [
        for (final e in (j['extras'] as List? ?? const []))
          ((e as Map)['n'] as String, e['q'] as int, e['p'] as int),
      ],
      servicePrice: j['servicePrice'] as int,
      total: j['total'] as int,
      couponCode: j['couponCode'] as String?,
      couponDiscount: (j['couponDiscount'] as num?)?.toInt() ?? 0,
      creditUsed: (j['creditUsed'] as num?)?.toInt() ?? 0,
      serviceDurationMinutes: j['serviceDurationMinutes'] as int? ?? 0,
      durationNeedsConfirmation:
          j['durationNeedsConfirmation'] as bool? ?? false,
      date: DateTime.parse(j['date'] as String),
      slotId: j['slotId'] as String? ?? '0830',
      slotLabel: j['slotLabel'] as String,
      status: status,
      history: history.isEmpty
          ? [StatusEvent(BookingStatus.requested, createdAt)]
          : history,
      capacityHeld: j['capacityHeld'] as bool? ?? false,
      offeredDate: date('offeredDate'),
      offeredSlotId: j['offeredSlotId'] as String?,
      name: j['name'] as String,
      phone: j['phone'] as String,
      forSomeoneElse: j['forSomeoneElse'] as bool? ?? false,
      recipientName: j['recipientName'] as String?,
      recipientPhone: j['recipientPhone'] as String?,
      notifyRecipient: j['notifyRecipient'] as bool? ?? false,
      address: j['address'] as String,
      pin: j['pin'] as String?,
      pinSource:
          PinSource.values.where((p) => p.name == j['pinSource']).firstOrNull,
      coverage:
          Coverage.values.where((c) => c.name == j['coverage']).firstOrNull ??
              Coverage.unverified,
      consentAt: date('consentAt'),
      workerId: j['workerId'] as String?,
      legIn: RouteLeg.fromJson(j['legIn']),
      returnLeg: RouteLeg.fromJson(j['returnLeg']),
      plannedArrivalMinute: j['plannedArrivalMinute'] as int?,
      plannedFinishMinute: j['plannedFinishMinute'] as int?,
      operationsNote: j['operationsNote'] as String?,
      customerNote: j['customerNote'] as String?,
      customerChangeRequest: j['customerChangeRequest'] as String?,
      riskFlag: j['riskFlag'] as String?,
      creditPreserved: j['creditPreserved'] as bool? ?? false,
      amountCollected: (j['amountCollected'] as num?)?.toInt(),
      paymentMethod: PaymentMethod.values
          .where((p) => p.name == j['paymentMethod'])
          .firstOrNull,
      collectedAt: date('collectedAt'),
      actualKm: (j['actualKm'] as num?)?.toDouble(),
      actualMinutes: (j['actualMinutes'] as num?)?.toInt(),
    );
  }
}

/// Booking reference like "CC-7K4Q2X9M". Eight characters from a 32-letter
/// alphabet, so it can't practically be guessed; Firestore rules still only
/// let the booker and staff read a booking.
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
