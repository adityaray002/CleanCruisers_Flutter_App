// Data shapes of the app ↔ ShineStaff API (docs/API_CONTRACT.md, v1).
//
// Every class here mirrors one object in the contract and round-trips
// through JSON, so the fake server, the HTTP client and the tests all agree
// on one shape. Field names match the contract exactly.

import '../../core/pricing.dart';

// ── JSON helpers ──────────────────────────────────────────────────────────────

String _two(int n) => n.toString().padLeft(2, '0');

/// `2026-11-22`
String dateKey(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

DateTime parseDateKey(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

/// Minutes after midnight → `09:30`.
String hhmm(int minuteOfDay) =>
    '${_two(minuteOfDay ~/ 60)}:${_two(minuteOfDay % 60)}';

int parseHhmm(String s) {
  final p = s.split(':').map(int.parse).toList();
  return p[0] * 60 + p[1];
}

DateTime? _ts(Object? v) => v is String ? DateTime.parse(v) : null;
String? _tsOut(DateTime? d) => d?.toIso8601String();

CarType carTypeFrom(String s) =>
    CarType.values.firstWhere((c) => c.name == s, orElse: () => CarType.hatchback);

Map<CarType, int> _carMap(Object? j) => {
      for (final e in (j as Map? ?? const {}).entries)
        carTypeFrom(e.key as String): (e.value as num).toInt(),
    };

Map<String, int> _carMapOut(Map<CarType, int> m) =>
    {for (final e in m.entries) e.key.name: e.value};

List<T> _list<T>(Object? j, T Function(Map<String, dynamic>) f) => [
      for (final e in (j as List? ?? const [])) f(Map<String, dynamic>.from(e as Map)),
    ];

T? _obj<T>(Object? j, T Function(Map<String, dynamic>) f) =>
    j is Map ? f(Map<String, dynamic>.from(j)) : null;

// ── Errors ────────────────────────────────────────────────────────────────────

/// Error codes from the contract (section 1, "Errors").
abstract final class ApiCode {
  static const invalidInput = 'INVALID_INPUT';
  static const authRequired = 'AUTH_REQUIRED';
  static const notYours = 'NOT_YOURS';
  static const notFound = 'NOT_FOUND';
  static const slotTaken = 'SLOT_TAKEN';
  static const pendingLimit = 'PENDING_LIMIT';
  static const priceChanged = 'PRICE_CHANGED';
  static const changeNotAllowed = 'CHANGE_NOT_ALLOWED';
  static const offerExpired = 'OFFER_EXPIRED';
  static const notCovered = 'NOT_COVERED';
  static const couponInvalid = 'COUPON_INVALID';
  static const planNotUsable = 'PLAN_NOT_USABLE';
  static const tooManyRequests = 'TOO_MANY_REQUESTS';
  static const unavailable = 'UNAVAILABLE';
}

/// A failed API call. [message] is safe to show to the customer; the app
/// decides what to do from [code].
class ApiException implements Exception {
  final String code;
  final String message;
  final Map<String, dynamic> details;
  const ApiException(this.code, this.message, [this.details = const {}]);

  factory ApiException.fromJson(Map<String, dynamic> j) {
    final e = Map<String, dynamic>.from(j['error'] as Map);
    return ApiException(e['code'] as String, e['message'] as String? ?? '',
        Map<String, dynamic>.from(e['details'] as Map? ?? const {}));
  }

  Map<String, dynamic> toJson() =>
      {'error': {'code': code, 'message': message, 'details': details}};

  @override
  String toString() => 'ApiException($code: $message)';
}

// ── Config and catalog ────────────────────────────────────────────────────────

class ApiConfig {
  final int openMinute, closeMinute;
  final int confirmWithinMinutes;
  final int bookingWindowDays;
  final int cancelFreeHoursBefore, cancelFeeHoursBefore, cancelFee;
  final String supportWhatsApp;
  final String catalogVersion;
  final String minAppVersion;

  const ApiConfig({
    required this.openMinute,
    required this.closeMinute,
    required this.confirmWithinMinutes,
    required this.bookingWindowDays,
    required this.cancelFreeHoursBefore,
    required this.cancelFeeHoursBefore,
    required this.cancelFee,
    required this.supportWhatsApp,
    required this.catalogVersion,
    required this.minAppVersion,
  });

  factory ApiConfig.fromJson(Map<String, dynamic> j) {
    final h = Map<String, dynamic>.from(j['workingHours'] as Map);
    final c = Map<String, dynamic>.from(j['cancelPolicy'] as Map);
    return ApiConfig(
      openMinute: parseHhmm(h['open'] as String),
      closeMinute: parseHhmm(h['close'] as String),
      confirmWithinMinutes: j['confirmWithinMinutes'] as int,
      bookingWindowDays: j['bookingWindowDays'] as int,
      cancelFreeHoursBefore: c['freeHoursBefore'] as int,
      cancelFeeHoursBefore: c['feeHoursBefore'] as int,
      cancelFee: c['fee'] as int,
      supportWhatsApp: j['supportWhatsApp'] as String,
      catalogVersion: j['catalogVersion'] as String,
      minAppVersion: j['minAppVersion'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'workingHours': {'open': hhmm(openMinute), 'close': hhmm(closeMinute)},
        'confirmWithinMinutes': confirmWithinMinutes,
        'bookingWindowDays': bookingWindowDays,
        'cancelPolicy': {
          'freeHoursBefore': cancelFreeHoursBefore,
          'feeHoursBefore': cancelFeeHoursBefore,
          'fee': cancelFee,
        },
        'supportWhatsApp': supportWhatsApp,
        'catalogVersion': catalogVersion,
        'minAppVersion': minAppVersion,
      };
}

class CatalogExtra {
  final String id, name;
  final int price, maxQty, minutes;
  final String? unit;
  const CatalogExtra({
    required this.id,
    required this.name,
    required this.price,
    this.maxQty = 1,
    this.unit,
    required this.minutes,
  });

  factory CatalogExtra.fromJson(Map<String, dynamic> j) => CatalogExtra(
        id: j['id'] as String,
        name: j['name'] as String,
        price: j['price'] as int,
        maxQty: j['maxQty'] as int? ?? 1,
        unit: j['unit'] as String?,
        minutes: j['minutes'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'maxQty': maxQty,
        'unit': unit,
        'minutes': minutes,
      };
}

class CatalogService {
  final String id;
  final String category; // wash | detailing
  final String name;
  final bool active;
  final Map<CarType, int> prices;
  final Map<CarType, int> durationMinutes;
  final List<CatalogExtra> extras;

  const CatalogService({
    required this.id,
    required this.category,
    required this.name,
    this.active = true,
    required this.prices,
    required this.durationMinutes,
    this.extras = const [],
  });

  int priceFor(CarType c) => prices[c] ?? 0;
  CatalogExtra? extra(String id) =>
      extras.where((e) => e.id == id).firstOrNull;

  factory CatalogService.fromJson(Map<String, dynamic> j) => CatalogService(
        id: j['id'] as String,
        category: j['category'] as String,
        name: j['name'] as String,
        active: j['active'] as bool? ?? true,
        prices: _carMap(j['prices']),
        durationMinutes: _carMap(j['durationMinutes']),
        extras: _list(j['extras'], CatalogExtra.fromJson),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'name': name,
        'active': active,
        'prices': _carMapOut(prices),
        'durationMinutes': _carMapOut(durationMinutes),
        'extras': [for (final e in extras) e.toJson()],
      };
}

class CatalogPlan {
  final String id, name, serviceId;
  final int visits, days;
  final Map<CarType, int> prices;
  final List<String> includes;
  final bool onlyInAreas;

  const CatalogPlan({
    required this.id,
    required this.name,
    required this.serviceId,
    required this.visits,
    required this.days,
    required this.prices,
    this.includes = const [],
    this.onlyInAreas = false,
  });

  factory CatalogPlan.fromJson(Map<String, dynamic> j) => CatalogPlan(
        id: j['id'] as String,
        name: j['name'] as String,
        serviceId: j['serviceId'] as String,
        visits: j['visits'] as int,
        days: j['days'] as int,
        prices: _carMap(j['prices']),
        includes: [for (final s in (j['includes'] as List? ?? const [])) s as String],
        onlyInAreas: j['onlyInAreas'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'serviceId': serviceId,
        'visits': visits,
        'days': days,
        'prices': _carMapOut(prices),
        'includes': includes,
        'onlyInAreas': onlyInAreas,
      };
}

class Catalog {
  final String version;
  final List<CatalogService> services;
  final List<CatalogPlan> plans;
  const Catalog({required this.version, required this.services, required this.plans});

  CatalogService? service(String id) =>
      services.where((s) => s.id == id).firstOrNull;
  CatalogPlan? plan(String id) => plans.where((p) => p.id == id).firstOrNull;

  factory Catalog.fromJson(Map<String, dynamic> j) => Catalog(
        version: j['version'] as String,
        services: _list(j['services'], CatalogService.fromJson),
        plans: _list(j['plans'], CatalogPlan.fromJson),
      );

  Map<String, dynamic> toJson() => {
        'version': version,
        'services': [for (final s in services) s.toJson()],
        'plans': [for (final p in plans) p.toJson()],
      };
}

class PublicOffer {
  final String code, title, headline;
  final List<String> conditions;
  final DateTime? validTill;
  const PublicOffer({
    required this.code,
    required this.title,
    required this.headline,
    this.conditions = const [],
    this.validTill,
  });

  factory PublicOffer.fromJson(Map<String, dynamic> j) => PublicOffer(
        code: j['code'] as String,
        title: j['title'] as String,
        headline: j['headline'] as String,
        conditions: [for (final s in (j['conditions'] as List? ?? const [])) s as String],
        validTill: j['validTill'] == null ? null : parseDateKey(j['validTill'] as String),
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'title': title,
        'headline': headline,
        'conditions': conditions,
        'validTill': validTill == null ? null : dateKey(validTill!),
      };
}

// ── Small shared objects ──────────────────────────────────────────────────────

enum Coverage { covered, notCovered, unverified }

Coverage coverageFrom(String? s) =>
    Coverage.values.firstWhere((c) => c.name == s, orElse: () => Coverage.unverified);

class ApiCar {
  final CarType type;
  final String model;
  const ApiCar(this.type, [this.model = '']);

  factory ApiCar.fromJson(Map<String, dynamic> j) =>
      ApiCar(carTypeFrom(j['type'] as String), j['model'] as String? ?? '');

  Map<String, dynamic> toJson() => {'type': type.name, 'model': model};

  @override
  bool operator ==(Object other) =>
      other is ApiCar && other.type == type && other.model == model;
  @override
  int get hashCode => Object.hash(type, model);
}

/// A start time the customer can pick. [start] is when the expert arrives,
/// [end] when the car should be ready; both are minutes after midnight.
class Slot {
  final DateTime date;
  final int start, end;
  final String label;
  final bool open;
  const Slot({
    required this.date,
    required this.start,
    required this.end,
    required this.label,
    this.open = true,
  });

  factory Slot.fromJson(Map<String, dynamic> j) => Slot(
        date: parseDateKey(j['date'] as String),
        start: parseHhmm(j['start'] as String),
        end: j['end'] == null ? parseHhmm(j['start'] as String) : parseHhmm(j['end'] as String),
        label: j['label'] as String? ?? '',
        open: j['open'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'date': dateKey(date),
        'start': hhmm(start),
        'end': hhmm(end),
        'label': label,
        'open': open,
      };
}

/// What the app sends to pick a time: a day and a start.
class SlotPick {
  final DateTime date;
  final int start;
  const SlotPick(this.date, this.start);

  factory SlotPick.fromJson(Map<String, dynamic> j) =>
      SlotPick(parseDateKey(j['date'] as String), parseHhmm(j['start'] as String));

  Map<String, dynamic> toJson() => {'date': dateKey(date), 'start': hhmm(start)};
}

enum PinSource { gps, pasted }

class ApiPin {
  final double lat, lng;
  final PinSource source;
  const ApiPin(this.lat, this.lng, this.source);

  factory ApiPin.fromJson(Map<String, dynamic> j) => ApiPin(
        (j['lat'] as num).toDouble(),
        (j['lng'] as num).toDouble(),
        PinSource.values.firstWhere((p) => p.name == j['source'], orElse: () => PinSource.gps),
      );

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng, 'source': source.name};
}

class ApiAddress {
  final String? id;
  final String label; // home | work | other
  final String flat, building, area, landmark, pincode;
  final String? parking;
  final ApiPin? pin;
  final String line; // server-built, read-only
  final bool isDefault;
  final Coverage? coverage;

  const ApiAddress({
    this.id,
    this.label = 'home',
    required this.flat,
    this.building = '',
    required this.area,
    this.landmark = '',
    this.pincode = '',
    this.parking,
    this.pin,
    this.line = '',
    this.isDefault = false,
    this.coverage,
  });

  ApiAddress copyWith({String? id, String? line, bool? isDefault, Coverage? coverage}) =>
      ApiAddress(
        id: id ?? this.id,
        label: label,
        flat: flat,
        building: building,
        area: area,
        landmark: landmark,
        pincode: pincode,
        parking: parking,
        pin: pin,
        line: line ?? this.line,
        isDefault: isDefault ?? this.isDefault,
        coverage: coverage ?? this.coverage,
      );

  factory ApiAddress.fromJson(Map<String, dynamic> j) => ApiAddress(
        id: j['id'] as String?,
        label: j['label'] as String? ?? 'home',
        flat: j['flat'] as String? ?? '',
        building: j['building'] as String? ?? '',
        area: j['area'] as String? ?? '',
        landmark: j['landmark'] as String? ?? '',
        pincode: j['pincode'] as String? ?? '',
        parking: j['parking'] as String?,
        pin: _obj(j['pin'], ApiPin.fromJson),
        line: j['line'] as String? ?? '',
        isDefault: j['isDefault'] as bool? ?? false,
        coverage: j['coverage'] == null ? null : coverageFrom(j['coverage'] as String),
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'label': label,
        'flat': flat,
        'building': building,
        'area': area,
        'landmark': landmark,
        'pincode': pincode,
        'parking': parking,
        'pin': pin?.toJson(),
        'line': line,
        'isDefault': isDefault,
        if (coverage != null) 'coverage': coverage!.name,
      };
}

class Recipient {
  final String name, phone;
  final bool notify;
  final DateTime? consentAt;
  const Recipient({required this.name, this.phone = '', this.notify = false, this.consentAt});

  factory Recipient.fromJson(Map<String, dynamic> j) => Recipient(
        name: j['name'] as String,
        phone: j['phone'] as String? ?? '',
        notify: j['notify'] as bool? ?? false,
        consentAt: _ts(j['consentAt']),
      );

  Map<String, dynamic> toJson() =>
      {'name': name, 'phone': phone, 'notify': notify, 'consentAt': _tsOut(consentAt)};
}

// ── Bill ──────────────────────────────────────────────────────────────────────

class BillItem {
  final String kind; // service | extra | plan
  final String name;
  final int qty, amount;
  const BillItem({required this.kind, required this.name, this.qty = 1, required this.amount});

  factory BillItem.fromJson(Map<String, dynamic> j) => BillItem(
        kind: j['kind'] as String,
        name: j['name'] as String,
        qty: j['qty'] as int? ?? 1,
        amount: j['amount'] as int,
      );

  Map<String, dynamic> toJson() => {'kind': kind, 'name': name, 'qty': qty, 'amount': amount};
}

class BillDiscount {
  final String kind; // coupon | auto | credit | plan
  final String? code, name;
  final int amount;
  const BillDiscount({required this.kind, this.code, this.name, required this.amount});

  factory BillDiscount.fromJson(Map<String, dynamic> j) => BillDiscount(
        kind: j['kind'] as String,
        code: j['code'] as String?,
        name: j['name'] as String?,
        amount: j['amount'] as int,
      );

  Map<String, dynamic> toJson() => {
        'kind': kind,
        if (code != null) 'code': code,
        if (name != null) 'name': name,
        'amount': amount,
      };
}

class GstSplit {
  final int taxable, cgst, sgst, rate;
  const GstSplit({required this.taxable, required this.cgst, required this.sgst, required this.rate});

  /// Splits a GST-inclusive [total] so taxable + cgst + sgst == total.
  factory GstSplit.ofInclusive(int total, {int rate = 18}) {
    final taxable = (total * 100 / (100 + rate)).round();
    final tax = total - taxable;
    final cgst = tax ~/ 2;
    return GstSplit(taxable: taxable, cgst: cgst, sgst: tax - cgst, rate: rate);
  }

  factory GstSplit.fromJson(Map<String, dynamic> j) => GstSplit(
        taxable: j['taxable'] as int,
        cgst: j['cgst'] as int,
        sgst: j['sgst'] as int,
        rate: j['rate'] as int,
      );

  Map<String, dynamic> toJson() => {'taxable': taxable, 'cgst': cgst, 'sgst': sgst, 'rate': rate};
}

class Bill {
  final List<BillItem> items;
  final int subtotal;
  final List<BillDiscount> discounts;
  final int lateCancelFee;
  final int total;
  final GstSplit gst;
  final String? discountCapNote;
  final bool payAfterService;

  const Bill({
    required this.items,
    required this.subtotal,
    this.discounts = const [],
    this.lateCancelFee = 0,
    required this.total,
    required this.gst,
    this.discountCapNote,
    this.payAfterService = true,
  });

  int get discountTotal => discounts.fold(0, (s, d) => s + d.amount);
  int discountOf(String kind) =>
      discounts.where((d) => d.kind == kind).fold(0, (s, d) => s + d.amount);

  factory Bill.fromJson(Map<String, dynamic> j) => Bill(
        items: _list(j['items'], BillItem.fromJson),
        subtotal: j['subtotal'] as int,
        discounts: _list(j['discounts'], BillDiscount.fromJson),
        lateCancelFee: j['lateCancelFee'] as int? ?? 0,
        total: j['total'] as int,
        gst: GstSplit.fromJson(Map<String, dynamic>.from(j['gst'] as Map)),
        discountCapNote: j['discountCapNote'] as String?,
        payAfterService: j['payAfterService'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'items': [for (final i in items) i.toJson()],
        'subtotal': subtotal,
        'discounts': [for (final d in discounts) d.toJson()],
        'lateCancelFee': lateCancelFee,
        'total': total,
        'gst': gst.toJson(),
        'discountCapNote': discountCapNote,
        'payAfterService': payAfterService,
      };
}

class Quote {
  final String id;
  final Bill bill;
  final int durationMinutes;
  final bool couponApplied;
  final String? couponReason;
  final DateTime expiresAt;

  const Quote({
    required this.id,
    required this.bill,
    required this.durationMinutes,
    this.couponApplied = false,
    this.couponReason,
    required this.expiresAt,
  });

  factory Quote.fromJson(Map<String, dynamic> j) {
    final c = Map<String, dynamic>.from(j['coupon'] as Map? ?? const {});
    return Quote(
      id: j['id'] as String,
      bill: Bill.fromJson(Map<String, dynamic>.from(j['bill'] as Map)),
      durationMinutes: j['durationMinutes'] as int,
      couponApplied: c['applied'] as bool? ?? false,
      couponReason: c['reason'] as String?,
      expiresAt: DateTime.parse(j['expiresAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'bill': bill.toJson(),
        'durationMinutes': durationMinutes,
        'coupon': {'applied': couponApplied, 'reason': couponReason},
        'expiresAt': expiresAt.toIso8601String(),
      };
}

// ── Booking ───────────────────────────────────────────────────────────────────

enum BookingState {
  requested,
  confirmed,
  onTheWay,
  inService,
  rescheduleNeeded,
  completed,
  missed,
  cancelled,
  unableToServe,
}

BookingState bookingStateFrom(String s) =>
    BookingState.values.firstWhere((v) => v.name == s, orElse: () => BookingState.requested);

extension BookingStateInfo on BookingState {
  /// Still ahead of the customer (shown under Upcoming).
  bool get isUpcoming => switch (this) {
        BookingState.requested ||
        BookingState.confirmed ||
        BookingState.onTheWay ||
        BookingState.inService ||
        BookingState.rescheduleNeeded =>
          true,
        _ => false,
      };
}

class StatusEntry {
  final BookingState status;
  final DateTime at;
  final String? note;
  const StatusEntry(this.status, this.at, [this.note]);

  factory StatusEntry.fromJson(Map<String, dynamic> j) => StatusEntry(
      bookingStateFrom(j['status'] as String), DateTime.parse(j['at'] as String), j['note'] as String?);

  Map<String, dynamic> toJson() => {'status': status.name, 'at': _tsOut(at), 'note': note};
}

/// The team offers another time (contract 2.1).
class TimeOffer {
  final Slot slot;
  final String reason; // rain | noWorker | customerAsked | other
  final DateTime expiresAt;
  const TimeOffer({required this.slot, required this.reason, required this.expiresAt});

  factory TimeOffer.fromJson(Map<String, dynamic> j) => TimeOffer(
        slot: Slot.fromJson(Map<String, dynamic>.from(j['slot'] as Map)),
        reason: j['reason'] as String,
        expiresAt: DateTime.parse(j['expiresAt'] as String),
      );

  Map<String, dynamic> toJson() =>
      {'slot': slot.toJson(), 'reason': reason, 'expiresAt': _tsOut(expiresAt)};
}

/// A price change found on site that the customer must accept (contract 2.2).
class PendingChange {
  final String id, kind; // kind: carSize
  final CarType from, to;
  final Bill newBill;
  final int newDurationMinutes;
  final DateTime expiresAt;
  const PendingChange({
    required this.id,
    this.kind = 'carSize',
    required this.from,
    required this.to,
    required this.newBill,
    required this.newDurationMinutes,
    required this.expiresAt,
  });

  factory PendingChange.fromJson(Map<String, dynamic> j) => PendingChange(
        id: j['id'] as String,
        kind: j['kind'] as String? ?? 'carSize',
        from: carTypeFrom(j['from'] as String),
        to: carTypeFrom(j['to'] as String),
        newBill: Bill.fromJson(Map<String, dynamic>.from(j['newBill'] as Map)),
        newDurationMinutes: j['newDurationMinutes'] as int,
        expiresAt: DateTime.parse(j['expiresAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'from': from.name,
        'to': to.name,
        'newBill': newBill.toJson(),
        'newDurationMinutes': newDurationMinutes,
        'expiresAt': _tsOut(expiresAt),
      };
}

/// A request from the customer waiting for the team (contract 2.3).
class OpenRequest {
  final String kind; // cancel | changeTime | keepAsPlanned
  final String? reason;
  final SlotPick? slot;
  final DateTime at;
  final int fee;
  const OpenRequest({required this.kind, this.reason, this.slot, required this.at, this.fee = 0});

  factory OpenRequest.fromJson(Map<String, dynamic> j) => OpenRequest(
        kind: j['kind'] as String,
        reason: j['reason'] as String?,
        slot: _obj(j['slot'], SlotPick.fromJson),
        at: DateTime.parse(j['at'] as String),
        fee: j['fee'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() =>
      {'kind': kind, 'reason': reason, 'slot': slot?.toJson(), 'at': _tsOut(at), 'fee': fee};
}

class PaymentInfo {
  final String status; // pending | paid
  final String? method; // cash | upi
  final DateTime? paidAt;
  const PaymentInfo({this.status = 'pending', this.method, this.paidAt});

  factory PaymentInfo.fromJson(Map<String, dynamic> j) => PaymentInfo(
        status: j['status'] as String? ?? 'pending',
        method: j['method'] as String?,
        paidAt: _ts(j['paidAt']),
      );

  Map<String, dynamic> toJson() => {'status': status, 'method': method, 'paidAt': _tsOut(paidAt)};
}

class InvoiceRef {
  final String number, url;
  const InvoiceRef(this.number, this.url);
  factory InvoiceRef.fromJson(Map<String, dynamic> j) =>
      InvoiceRef(j['number'] as String, j['url'] as String);
  Map<String, dynamic> toJson() => {'number': number, 'url': url};
}

class CancelPolicy {
  final DateTime freeUntil, feeAfter;
  final int fee;
  const CancelPolicy({required this.freeUntil, required this.feeAfter, required this.fee});

  factory CancelPolicy.fromJson(Map<String, dynamic> j) => CancelPolicy(
        freeUntil: DateTime.parse(j['freeUntil'] as String),
        feeAfter: DateTime.parse(j['feeAfter'] as String),
        fee: j['fee'] as int,
      );

  Map<String, dynamic> toJson() =>
      {'freeUntil': _tsOut(freeUntil), 'feeAfter': _tsOut(feeAfter), 'fee': fee};
}

class PlanRef {
  final String id;
  final int visitNumber, visitsTotal;
  const PlanRef(this.id, this.visitNumber, this.visitsTotal);
  factory PlanRef.fromJson(Map<String, dynamic> j) =>
      PlanRef(j['id'] as String, j['visitNumber'] as int, j['visitsTotal'] as int);
  Map<String, dynamic> toJson() => {'id': id, 'visitNumber': visitNumber, 'visitsTotal': visitsTotal};
}

class ServiceRef {
  final String id, name, category;
  const ServiceRef(this.id, this.name, this.category);
  factory ServiceRef.fromJson(Map<String, dynamic> j) =>
      ServiceRef(j['id'] as String, j['name'] as String, j['category'] as String);
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'category': category};
}

class BookedExtra {
  final String id, name;
  final int qty, price;
  const BookedExtra({required this.id, required this.name, required this.qty, required this.price});
  factory BookedExtra.fromJson(Map<String, dynamic> j) => BookedExtra(
      id: j['id'] as String, name: j['name'] as String, qty: j['qty'] as int, price: j['price'] as int);
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'qty': qty, 'price': price};
}

/// A booking as the customer sees it (contract section 2, "Booking").
class Booking {
  final String ref;
  final DateTime createdAt;
  final BookingState status;
  final String statusNote;
  final DateTime? confirmBy;
  final ServiceRef service;
  final ApiCar car;
  final List<BookedExtra> extras;
  final Slot slot;
  final int durationMinutes;
  final ApiAddress address;
  final Coverage coverage;
  final String notes;
  final Recipient? recipient;
  final Bill bill;
  final PlanRef? plan;
  final List<StatusEntry> history;
  final String? teamMessage;
  final TimeOffer? offer;
  final PendingChange? pendingChange;
  final OpenRequest? openRequest;
  final PaymentInfo payment;
  final InvoiceRef? invoice;
  final bool canCancel, canChangeTime;
  final CancelPolicy? cancelPolicy;

  const Booking({
    required this.ref,
    required this.createdAt,
    required this.status,
    this.statusNote = '',
    this.confirmBy,
    required this.service,
    required this.car,
    this.extras = const [],
    required this.slot,
    required this.durationMinutes,
    required this.address,
    this.coverage = Coverage.unverified,
    this.notes = '',
    this.recipient,
    required this.bill,
    this.plan,
    this.history = const [],
    this.teamMessage,
    this.offer,
    this.pendingChange,
    this.openRequest,
    this.payment = const PaymentInfo(),
    this.invoice,
    this.canCancel = false,
    this.canChangeTime = false,
    this.cancelPolicy,
  });

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
        ref: j['ref'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        status: bookingStateFrom(j['status'] as String),
        statusNote: j['statusNote'] as String? ?? '',
        confirmBy: _ts(j['confirmBy']),
        service: ServiceRef.fromJson(Map<String, dynamic>.from(j['service'] as Map)),
        car: ApiCar.fromJson(Map<String, dynamic>.from(j['car'] as Map)),
        extras: _list(j['extras'], BookedExtra.fromJson),
        slot: Slot.fromJson(Map<String, dynamic>.from(j['slot'] as Map)),
        durationMinutes: j['durationMinutes'] as int,
        address: ApiAddress.fromJson(Map<String, dynamic>.from(j['address'] as Map)),
        coverage: coverageFrom(j['coverage'] as String?),
        notes: j['notes'] as String? ?? '',
        recipient: _obj(j['recipient'], Recipient.fromJson),
        bill: Bill.fromJson(Map<String, dynamic>.from(j['bill'] as Map)),
        plan: _obj(j['plan'], PlanRef.fromJson),
        history: _list(j['history'], StatusEntry.fromJson),
        teamMessage: j['teamMessage'] as String?,
        offer: _obj(j['offer'], TimeOffer.fromJson),
        pendingChange: _obj(j['pendingChange'], PendingChange.fromJson),
        openRequest: _obj(j['openRequest'], OpenRequest.fromJson),
        payment: _obj(j['payment'], PaymentInfo.fromJson) ?? const PaymentInfo(),
        invoice: _obj(j['invoice'], InvoiceRef.fromJson),
        canCancel: j['canCancel'] as bool? ?? false,
        canChangeTime: j['canChangeTime'] as bool? ?? false,
        cancelPolicy: _obj(j['cancelPolicy'], CancelPolicy.fromJson),
      );

  Map<String, dynamic> toJson() => {
        'ref': ref,
        'createdAt': _tsOut(createdAt),
        'status': status.name,
        'statusNote': statusNote,
        'confirmBy': _tsOut(confirmBy),
        'service': service.toJson(),
        'car': car.toJson(),
        'extras': [for (final e in extras) e.toJson()],
        'slot': slot.toJson(),
        'durationMinutes': durationMinutes,
        'address': address.toJson(),
        'coverage': coverage.name,
        'notes': notes,
        'recipient': recipient?.toJson(),
        'bill': bill.toJson(),
        'plan': plan?.toJson(),
        'history': [for (final h in history) h.toJson()],
        'teamMessage': teamMessage,
        'offer': offer?.toJson(),
        'pendingChange': pendingChange?.toJson(),
        'openRequest': openRequest?.toJson(),
        'payment': payment.toJson(),
        'invoice': invoice?.toJson(),
        'canCancel': canCancel,
        'canChangeTime': canChangeTime,
        'cancelPolicy': cancelPolicy?.toJson(),
      };
}

// ── Requests the app sends ────────────────────────────────────────────────────

/// Body of `POST /quote` and `POST /bookings` (the booking fields are a
/// superset of the quote fields).
class BookingRequest {
  final String? clientRef;
  final String? quoteId;
  final int? expectedTotal;
  final String serviceId;
  final ApiCar car;
  final Map<String, int> extras; // extra id → qty
  final SlotPick slot;
  final String? addressId;
  final ApiAddress? address; // one-off address instead of addressId
  final String notes;
  final Recipient? recipient;
  final String? couponCode;
  final bool useCredit;
  final String? planId;

  const BookingRequest({
    this.clientRef,
    this.quoteId,
    this.expectedTotal,
    required this.serviceId,
    required this.car,
    this.extras = const {},
    required this.slot,
    this.addressId,
    this.address,
    this.notes = '',
    this.recipient,
    this.couponCode,
    this.useCredit = false,
    this.planId,
  });

  BookingRequest forSubmit({required String clientRef, required Quote quote}) => BookingRequest(
        clientRef: clientRef,
        quoteId: quote.id,
        expectedTotal: quote.bill.total,
        serviceId: serviceId,
        car: car,
        extras: extras,
        slot: slot,
        addressId: addressId,
        address: address,
        notes: notes,
        recipient: recipient,
        couponCode: couponCode,
        useCredit: useCredit,
        planId: planId,
      );

  factory BookingRequest.fromJson(Map<String, dynamic> j) => BookingRequest(
        clientRef: j['clientRef'] as String?,
        quoteId: j['quoteId'] as String?,
        expectedTotal: j['expectedTotal'] as int?,
        serviceId: j['serviceId'] as String,
        car: ApiCar.fromJson(Map<String, dynamic>.from(j['car'] as Map)),
        extras: {
          for (final e in (j['extras'] as List? ?? const []))
            (e as Map)['id'] as String: (e['qty'] as num).toInt(),
        },
        slot: SlotPick.fromJson(Map<String, dynamic>.from(j['slot'] as Map)),
        addressId: j['addressId'] as String?,
        address: _obj(j['address'], ApiAddress.fromJson),
        notes: j['notes'] as String? ?? '',
        recipient: _obj(j['recipient'], Recipient.fromJson),
        couponCode: j['couponCode'] as String?,
        useCredit: j['useCredit'] as bool? ?? false,
        planId: j['planId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (clientRef != null) 'clientRef': clientRef,
        if (quoteId != null) 'quoteId': quoteId,
        if (expectedTotal != null) 'expectedTotal': expectedTotal,
        'serviceId': serviceId,
        'car': car.toJson(),
        'extras': [for (final e in extras.entries) {'id': e.key, 'qty': e.value}],
        'slot': slot.toJson(),
        if (addressId != null) 'addressId': addressId,
        if (address != null) 'address': address!.toJson(),
        'notes': notes,
        'recipient': recipient?.toJson(),
        'couponCode': couponCode,
        'useCredit': useCredit,
        'planId': planId,
      };
}

// ── Wallet, plans, profile, referral ──────────────────────────────────────────

class WalletEntry {
  final String id;
  final int amount; // + earned, − used
  final String kind; // cashback | referral | rain | goodwill | used | returned | expired
  final String note;
  final DateTime at;
  final DateTime? expiresOn;
  final String? bookingRef;

  const WalletEntry({
    required this.id,
    required this.amount,
    required this.kind,
    this.note = '',
    required this.at,
    this.expiresOn,
    this.bookingRef,
  });

  factory WalletEntry.fromJson(Map<String, dynamic> j) => WalletEntry(
        id: j['id'] as String,
        amount: j['amount'] as int,
        kind: j['kind'] as String,
        note: j['note'] as String? ?? '',
        at: DateTime.parse(j['at'] as String),
        expiresOn: j['expiresOn'] == null ? null : parseDateKey(j['expiresOn'] as String),
        bookingRef: j['bookingRef'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'kind': kind,
        'note': note,
        'at': _tsOut(at),
        'expiresOn': expiresOn == null ? null : dateKey(expiresOn!),
        'bookingRef': bookingRef,
      };
}

class Wallet {
  final int balance;
  final List<WalletEntry> entries;
  const Wallet({required this.balance, this.entries = const []});

  factory Wallet.fromJson(Map<String, dynamic> j) =>
      Wallet(balance: j['balance'] as int, entries: _list(j['entries'], WalletEntry.fromJson));

  Map<String, dynamic> toJson() =>
      {'balance': balance, 'entries': [for (final e in entries) e.toJson()]};
}

enum PlanState { pendingFirstVisit, active, expired, cancelled }

class Plan {
  final String id, planId, name;
  final ApiCar car;
  final PlanState status;
  final DateTime? startsOn, endsOn;
  final int visitsTotal, visitsUsed, visitsBooked;
  final int price;
  final bool paid;
  final String? addressId;

  const Plan({
    required this.id,
    required this.planId,
    required this.name,
    required this.car,
    required this.status,
    this.startsOn,
    this.endsOn,
    required this.visitsTotal,
    this.visitsUsed = 0,
    this.visitsBooked = 0,
    required this.price,
    this.paid = false,
    this.addressId,
  });

  int get visitsLeft => visitsTotal - visitsUsed;

  factory Plan.fromJson(Map<String, dynamic> j) => Plan(
        id: j['id'] as String,
        planId: j['planId'] as String,
        name: j['name'] as String,
        car: ApiCar.fromJson(Map<String, dynamic>.from(j['car'] as Map)),
        status: PlanState.values.firstWhere((s) => s.name == j['status'],
            orElse: () => PlanState.pendingFirstVisit),
        startsOn: j['startsOn'] == null ? null : parseDateKey(j['startsOn'] as String),
        endsOn: j['endsOn'] == null ? null : parseDateKey(j['endsOn'] as String),
        visitsTotal: j['visitsTotal'] as int,
        visitsUsed: j['visitsUsed'] as int? ?? 0,
        visitsBooked: j['visitsBooked'] as int? ?? 0,
        price: j['price'] as int,
        paid: j['paid'] as bool? ?? false,
        addressId: j['addressId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'planId': planId,
        'name': name,
        'car': car.toJson(),
        'status': status.name,
        'startsOn': startsOn == null ? null : dateKey(startsOn!),
        'endsOn': endsOn == null ? null : dateKey(endsOn!),
        'visitsTotal': visitsTotal,
        'visitsUsed': visitsUsed,
        'visitsBooked': visitsBooked,
        'price': price,
        'paid': paid,
        'addressId': addressId,
      };
}

class Me {
  final String phone, name;
  final ApiCar? car;
  final bool isFirstBooking;
  final int walletBalance;
  final int? nextExpiryAmount;
  final DateTime? nextExpiryOn;
  final String referralCode;
  final List<Plan> activePlans;
  final int lateCancelFeeDue;

  const Me({
    required this.phone,
    this.name = '',
    this.car,
    this.isFirstBooking = true,
    this.walletBalance = 0,
    this.nextExpiryAmount,
    this.nextExpiryOn,
    required this.referralCode,
    this.activePlans = const [],
    this.lateCancelFeeDue = 0,
  });

  factory Me.fromJson(Map<String, dynamic> j) {
    final w = Map<String, dynamic>.from(j['wallet'] as Map? ?? const {});
    final x = w['nextExpiry'] is Map ? Map<String, dynamic>.from(w['nextExpiry'] as Map) : null;
    return Me(
      phone: j['phone'] as String,
      name: j['name'] as String? ?? '',
      car: _obj(j['car'], ApiCar.fromJson),
      isFirstBooking: j['isFirstBooking'] as bool? ?? true,
      walletBalance: w['balance'] as int? ?? 0,
      nextExpiryAmount: x?['amount'] as int?,
      nextExpiryOn: x == null ? null : parseDateKey(x['on'] as String),
      referralCode: j['referralCode'] as String? ?? '',
      activePlans: _list(j['activePlans'], Plan.fromJson),
      lateCancelFeeDue: j['lateCancelFeeDue'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'name': name,
        'car': car?.toJson(),
        'isFirstBooking': isFirstBooking,
        'wallet': {
          'balance': walletBalance,
          'nextExpiry': nextExpiryOn == null
              ? null
              : {'amount': nextExpiryAmount, 'on': dateKey(nextExpiryOn!)},
        },
        'referralCode': referralCode,
        'activePlans': [for (final p in activePlans) p.toJson()],
        'lateCancelFeeDue': lateCancelFeeDue,
      };
}

class Referral {
  final String code, shareText;
  final int rewardEach, joined, rewarded;
  const Referral({
    required this.code,
    required this.rewardEach,
    this.joined = 0,
    this.rewarded = 0,
    this.shareText = '',
  });

  factory Referral.fromJson(Map<String, dynamic> j) => Referral(
        code: j['code'] as String,
        rewardEach: j['rewardEach'] as int,
        joined: j['joined'] as int? ?? 0,
        rewarded: j['rewarded'] as int? ?? 0,
        shareText: j['shareText'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'rewardEach': rewardEach,
        'joined': joined,
        'rewarded': rewarded,
        'shareText': shareText,
      };
}

class Availability {
  final DateTime date;
  final int durationMinutes;
  final List<Slot> slots;
  final String? closedReason;
  const Availability({
    required this.date,
    required this.durationMinutes,
    required this.slots,
    this.closedReason,
  });

  List<Slot> get openSlots => slots.where((s) => s.open).toList();

  factory Availability.fromJson(Map<String, dynamic> j) => Availability(
        date: parseDateKey(j['date'] as String),
        durationMinutes: j['durationMinutes'] as int,
        slots: _list(j['slots'], Slot.fromJson),
        closedReason: j['closedReason'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'date': dateKey(date),
        'durationMinutes': durationMinutes,
        'slots': [for (final s in slots) s.toJson()],
        'closedReason': closedReason,
      };
}
