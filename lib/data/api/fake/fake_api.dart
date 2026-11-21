// An in-app stand-in for ShineStaff that follows docs/API_CONTRACT.md.
//
// Used by test builds (--dart-define=FAKE_SERVER=true) and by tests. It is
// also the reference implementation of the business rules: ShineStaff must
// give the same answers (test/fake_api_test.dart lists them).
//
// The `admin…` methods stand in for what the admin and the worker do in
// ShineStaff (confirm, offer a time, start, complete…), so the whole flow can
// be tried on a phone without the real server.

import 'dart:math';

import '../../../core/pricing.dart';
import '../../../core/scheduling.dart' show clockLabel, timeRangeLabel;
import '../api.dart';
import '../models.dart';
import 'fake_rules.dart';

/// A WhatsApp message the real server would send (H2, contract section 10).
class FakeWhatsApp {
  final String phone, template, text;
  final DateTime at;
  const FakeWhatsApp(this.phone, this.template, this.text, this.at);
}

class _Customer {
  final String phone;
  String name = '';
  ApiCar? car;
  final String referralCode;
  String? referredBy;
  bool referralRewarded = false;
  int lateFeeDue = 0;
  int noShows = 0;
  _Customer(this.phone, this.referralCode);
}

class _Lot {
  final String entryId;
  int remaining;
  final DateTime expiresOn;
  _Lot(this.entryId, this.remaining, this.expiresOn);
}

class _PlanRec {
  final String id, planId, phone;
  final ApiCar car;
  final int price, visitsTotal, days;
  final String addressId;
  DateTime? startsOn, endsOn;
  bool paid = false;
  bool cancelled = false;
  _PlanRec(this.id, this.planId, this.phone, this.car, this.price, this.visitsTotal,
      this.days, this.addressId);
}

class _Job {
  final String ref, phone;
  final String? clientRef;
  final DateTime createdAt;
  final bool external; // a SofaShine job that only takes a worker's time
  BookingRequest request;
  CatalogService? service;
  DateTime date;
  int start, duration;
  ApiAddress address;
  Coverage coverage;
  Bill bill;
  BookingState state = BookingState.requested;
  final history = <StatusEntry>[];
  String? teamMessage;
  TimeOffer? offer;
  PendingChange? pendingChange;
  OpenRequest? openRequest;
  PaymentInfo payment = const PaymentInfo();
  InvoiceRef? invoice;
  String? workerId;
  bool needsReassign = false;
  bool lunchPause = false; // the worker takes lunch during this job (+30 min)
  DateTime? holdUntil, confirmBy;
  String? couponCode;
  int creditUsed = 0;
  String? planRecId;

  _Job({
    required this.ref,
    required this.phone,
    this.clientRef,
    required this.createdAt,
    this.external = false,
    required this.request,
    required this.service,
    required this.date,
    required this.start,
    required this.duration,
    required this.address,
    required this.coverage,
    required this.bill,
  });

  DateTime get startsAt => DateTime(date.year, date.month, date.day, start ~/ 60, start % 60);
}

class FakeApi implements CleanCruisersApi {
  final FakeSettings settings;
  final DateTime Function() clock;
  final Random _rng;
  final Catalog _catalog;

  FakeApi({
    this.settings = const FakeSettings(),
    DateTime Function()? clock,
    Random? random,
    Catalog? catalog,
  })  : clock = clock ?? DateTime.now,
        _rng = random ?? Random(),
        _catalog = catalog ?? buildFakeCatalog();

  // ── State ───────────────────────────────────────────────────────────────────

  String? _phone;
  final _customers = <String, _Customer>{};
  final _addresses = <String, List<ApiAddress>>{};
  final _jobs = <_Job>[];
  final _plans = <_PlanRec>[];
  final _entries = <String, List<WalletEntry>>{};
  final _lots = <String, List<_Lot>>{};
  final _couponUses = <String, Set<String>>{};
  final _quotes = <String, (Quote, String phone)>{};
  final _closedDays = <String, String>{};
  final _unavailable = <String>{}; // "workerId|yyyy-mm-dd"
  final outbox = <FakeWhatsApp>[];
  int _invoiceSeq = 0;
  int _idSeq = 0;

  /// Called after every change, so a test build can save the state
  /// (see [toJson] / [restore]).
  void Function()? onChange;
  void _changed() => onChange?.call();

  // ── Fake login ──────────────────────────────────────────────────────────────

  /// Test builds: any 10-digit phone, OTP is [fakeOtp].
  static const fakeOtp = '123456';

  String? get signedInPhone => _phone;
  void signIn(String phone) {
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      throw const ApiException(ApiCode.invalidInput, 'Enter a valid 10-digit mobile number.');
    }
    _phone = phone;
    _customer(phone);
    _changed();
  }

  void signOut() {
    _phone = null;
    _changed();
  }

  /// The saved name of [phone], or null (used by the fake login).
  String? nameOf(String phone) {
    final n = _customers[phone]?.name ?? '';
    return n.isEmpty ? null : n;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  DateTime get _now => clock();
  DateTime get _today => DateTime(_now.year, _now.month, _now.day);
  int get _nowMinute => _now.hour * 60 + _now.minute;

  String _id(String prefix) => '$prefix-${(++_idSeq).toString().padLeft(4, '0')}';

  static const _refChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  String _newRef() {
    String r;
    do {
      r = 'CC-${List.generate(8, (_) => _refChars[_rng.nextInt(_refChars.length)]).join()}';
    } while (_jobs.any((j) => j.ref == r));
    return r;
  }

  String _requirePhone() {
    final p = _phone;
    if (p == null) {
      throw const ApiException(ApiCode.authRequired, 'Please log in again.');
    }
    _customer(p);
    return p;
  }

  _Customer _customer(String phone) => _customers.putIfAbsent(phone, () {
        String code;
        do {
          code = List.generate(7, (_) => _refChars[_rng.nextInt(_refChars.length)]).join();
        } while (_customers.values.any((c) => c.referralCode == code));
        return _Customer(phone, code);
      });

  _Job _ownJob(String ref) {
    final phone = _requirePhone();
    final j = _jobs.where((j) => j.ref == ref && !j.external).firstOrNull;
    if (j == null) throw const ApiException(ApiCode.notFound, 'Booking not found.');
    if (j.phone != phone) throw const ApiException(ApiCode.notYours, 'Booking not found.');
    return j;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static String _line(ApiAddress a) {
    final parts = [a.flat, if (a.building.trim().isNotEmpty) a.building, a.area]
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join(', ');
    final lm = a.landmark.trim().replaceFirst(RegExp(r'^near\s+', caseSensitive: false), '');
    return lm.isEmpty ? parts : '$parts, near $lm';
  }

  /// Adds working minutes (open–close) to [from]; time outside working hours
  /// doesn't count (H1: a request at night is confirmed the next morning).
  DateTime _addWorking(DateTime from, int minutes) {
    var t = from;
    var left = minutes;
    while (true) {
      final m = t.hour * 60 + t.minute;
      if (m < settings.open) {
        t = DateTime(t.year, t.month, t.day, settings.open ~/ 60, settings.open % 60);
        continue;
      }
      if (m >= settings.close) {
        final n = DateTime(t.year, t.month, t.day + 1);
        t = DateTime(n.year, n.month, n.day, settings.open ~/ 60, settings.open % 60);
        continue;
      }
      final room = settings.close - m;
      if (left <= room) return t.add(Duration(minutes: left));
      left -= room;
      final n = DateTime(t.year, t.month, t.day + 1);
      t = DateTime(n.year, n.month, n.day, settings.open ~/ 60, settings.open % 60);
    }
  }

  // ── Worker-hours planner (H3, H5) ──────────────────────────────────────────

  bool _canWork(FakeWorker w, DateTime day, bool detailing) =>
      w.worksOn(day) &&
      w.canDoCleanCruisers() &&
      (!detailing || w.detailing) &&
      !_unavailable.contains('${w.id}|${dateKey(day)}');

  (int, int) _interval(int start, int duration) =>
      (start - settings.travelMinutes, start + duration + settings.bufferMinutes);

  bool _overlaps((int, int) a, (int, int) b) => a.$1 < b.$2 && b.$1 < a.$2;

  bool _lunchFits(List<(int, int)> busy) {
    final from = settings.lunchFrom, to = settings.lunchTo, len = settings.lunchMinutes;
    final starts = <int>{from, for (final b in busy) b.$2};
    for (final t in starts) {
      if (t < from || t + len > to) continue;
      final lunch = (t, t + len);
      if (busy.every((b) => !_overlaps(b, lunch))) return true;
    }
    return false;
  }

  /// Jobs that hold a worker's time on [day].
  /// Fixed: assigned jobs and SofaShine jobs. Floating: requests still inside
  /// their hold, open team offers, and assigned jobs whose worker dropped out.
  ({Map<String, List<(int, int)>> fixed, List<(String, int, int, bool)> floating})
      _dayLoad(DateTime day, {String? exclude}) {
    final fixed = <String, List<(int, int)>>{};
    final floating = <(String, int, int, bool)>[];
    for (final j in _jobs) {
      if (j.ref == exclude) continue;
      final det = j.service != null && needsDetailing(j.service!);
      final offer = j.offer;
      if (j.state == BookingState.rescheduleNeeded && offer != null) {
        if (_sameDay(offer.slot.date, day) && offer.expiresAt.isAfter(_now)) {
          floating.add((j.ref, offer.slot.start, j.duration, det));
        }
        continue;
      }
      if (!_sameDay(j.date, day)) continue;
      final active = j.external ||
          const [BookingState.confirmed, BookingState.onTheWay, BookingState.inService]
              .contains(j.state);
      if (active && j.workerId != null && !j.needsReassign) {
        (fixed[j.workerId!] ??= [])
            .add(_interval(j.start, j.duration + (j.lunchPause ? settings.lunchMinutes : 0)));
      } else if (active && j.needsReassign) {
        floating.add((j.ref, j.start, j.duration, det));
      } else if (j.state == BookingState.requested &&
          (j.holdUntil?.isAfter(_now) ?? false)) {
        floating.add((j.ref, j.start, j.duration, det));
      }
    }
    return (fixed: fixed, floating: floating);
  }

  /// Places every floating job plus the candidate on a worker. Returns the
  /// worker for each ref (and which jobs pause for lunch), or null if
  /// something doesn't fit.
  ///
  /// Lunch: a worker needs a free 30 min inside [lunchFrom, lunchTo]. A job
  /// that covers that window instead pauses for lunch, so it ends 30 min later.
  ({Map<String, String> worker, Set<String> paused})? _plan(DateTime day,
      {String? exclude, (String, int, int, bool)? candidate}) {
    if (candidate != null) {
      final (_, s, d, _) = candidate;
      if (s < settings.firstArrival || s + d > settings.close) return null;
    }
    final load = _dayLoad(day, exclude: exclude);
    final busy = {
      for (final w in fakeWorkers) w.id: [...?load.fixed[w.id]],
    };
    final todo = [...load.floating, if (candidate != null) candidate]
      ..sort((a, b) => a.$2.compareTo(b.$2));
    final placed = <String, String>{};
    final paused = <String>{};
    for (final (ref, s, d, det) in todo) {
      final slot = _interval(s, d);
      final coversLunch = s < settings.lunchTo && s + d > settings.lunchFrom;
      final pausedSlot = _interval(s, d + settings.lunchMinutes);
      final canPause = coversLunch && s + d + settings.lunchMinutes <= settings.close;
      final workers = fakeWorkers.where((w) => _canWork(w, day, det)).toList()
        ..sort((a, b) => busy[a.id]!.length.compareTo(busy[b.id]!.length));
      String? chosen;
      var pause = false;
      for (final w in workers) {
        final b = busy[w.id]!;
        if (!b.any((x) => _overlaps(x, slot)) && _lunchFits([...b, slot])) {
          chosen = w.id;
          break;
        }
        if (canPause && !b.any((x) => _overlaps(x, pausedSlot))) {
          chosen = w.id;
          pause = true;
          break;
        }
      }
      if (chosen == null) return null;
      busy[chosen]!.add(pause ? pausedSlot : slot);
      placed[ref] = chosen;
      if (pause) paused.add(ref);
    }
    return (worker: placed, paused: paused);
  }

  /// Whether a new job fits, and whether it would pause for lunch.
  ({bool fits, bool paused}) _fitInfo(DateTime day, int start, int duration, bool detailing,
      {String? exclude}) {
    final p = _plan(day, exclude: exclude, candidate: ('_new', start, duration, detailing));
    return (fits: p != null, paused: p?.paused.contains('_new') ?? false);
  }

  /// When the car is ready: service time plus a lunch pause if there is one.
  int _readyAt(int start, int duration, bool paused) =>
      start + duration + (paused ? settings.lunchMinutes : 0);

  int _durationOf(CatalogService s, CarType car, Map<String, int> extras) =>
      (s.durationMinutes[car] ?? 120) +
      extras.entries.fold(0, (sum, e) => sum + (s.extra(e.key)?.minutes ?? 0) * e.value);

  String? _dayClosedReason(DateTime day) => _closedDays[dateKey(day)];

  bool _inWindow(DateTime day) =>
      !day.isBefore(_today) &&
      day.isBefore(DateTime(_today.year, _today.month, _today.day + settings.bookingWindowDays));

  List<Slot> _slotsFor(DateTime day, CatalogService s, int duration, {String? exclude}) {
    final out = <Slot>[];
    if (!_inWindow(day) || _dayClosedReason(day) != null) return out;
    final det = needsDetailing(s);
    final earliest = _sameDay(day, _today) ? _nowMinute + settings.minLeadMinutes : 0;
    for (var t = settings.firstArrival; t + duration <= settings.close; t += settings.slotStep) {
      final f = t >= earliest
          ? _fitInfo(day, t, duration, det, exclude: exclude)
          : (fits: false, paused: false);
      final end = _readyAt(t, duration, f.paused);
      out.add(Slot(date: day, start: t, end: end, label: timeRangeLabel(t, end), open: f.fits));
    }
    return out;
  }

  List<Slot> _alternatives(DateTime day, CatalogService s, int duration, {String? exclude}) {
    final out = <Slot>[];
    for (var i = 0; i < 3 && out.length < 6; i++) {
      final d = DateTime(day.year, day.month, day.day + i);
      out.addAll(_slotsFor(d, s, duration, exclude: exclude).where((x) => x.open).take(6 - out.length));
    }
    return out;
  }

  // ── Money ───────────────────────────────────────────────────────────────────

  int _balance(String phone) {
    _expireLots(phone);
    return (_lots[phone] ?? const []).fold(0, (s, l) => s + l.remaining);
  }

  void _expireLots(String phone) {
    for (final l in _lots[phone] ?? <_Lot>[]) {
      if (l.remaining > 0 && l.expiresOn.isBefore(_today)) {
        _entry(phone, -l.remaining, 'expired', 'Credit expired');
        l.remaining = 0;
        _changed();
      }
    }
  }

  WalletEntry _entry(String phone, int amount, String kind, String note,
      {DateTime? expiresOn, String? bookingRef}) {
    final e = WalletEntry(
      id: _id('W'),
      amount: amount,
      kind: kind,
      note: note,
      at: _now,
      expiresOn: expiresOn,
      bookingRef: bookingRef,
    );
    (_entries[phone] ??= []).add(e);
    return e;
  }

  void _addCredit(String phone, int amount, String kind, String note, {String? bookingRef}) {
    if (amount <= 0) return;
    final expires = DateTime(_today.year, _today.month, _today.day + settings.creditExpiryDays);
    final e = _entry(phone, amount, kind, note, expiresOn: expires, bookingRef: bookingRef);
    (_lots[phone] ??= []).add(_Lot(e.id, amount, expires));
  }

  void _useCredit(String phone, int amount, String ref) {
    if (amount <= 0) return;
    var left = amount;
    final lots = [...?_lots[phone]]..sort((a, b) => a.expiresOn.compareTo(b.expiresOn));
    for (final l in lots) {
      final take = min(left, l.remaining);
      l.remaining -= take;
      left -= take;
      if (left == 0) break;
    }
    _entry(phone, -amount, 'used', 'Used on $ref', bookingRef: ref);
  }

  void _returnCredit(_Job j) {
    if (j.creditUsed <= 0) return;
    _addCredit(j.phone, j.creditUsed, 'returned', 'Returned from ${j.ref}', bookingRef: j.ref);
    j.creditUsed = 0;
  }

  bool _isFirstBooking(String phone, {String? exclude}) => !_jobs.any((j) =>
      j.phone == phone &&
      j.ref != exclude &&
      const [
        BookingState.confirmed,
        BookingState.onTheWay,
        BookingState.inService,
        BookingState.completed,
      ].contains(j.state));

  /// Rupees of cost for a job (J1): worker time, travel, materials.
  double _cost(CatalogService s, int duration, Map<String, int> extras, {bool travel = true}) =>
      duration * settings.workerCostPerMinute +
      (travel ? settings.travelCostPerTrip : 0) +
      (fakeMaterialCost[s.id] ?? 0) +
      extras.entries.fold(0, (sum, e) => sum + (fakeMaterialCost[e.key] ?? 0) * e.value);

  /// Most discount a bill can take and still leave [FakeSettings.marginFloor].
  int _maxDiscount(int subtotal, double cost) =>
      max(0, (subtotal - (cost + settings.marginFloor) * (100 + settings.gstRate) / 100).floor());

  _Job? _sameHomeJob(String phone, DateTime day, ApiAddress a, ApiCar car, {String? exclude}) =>
      _jobs.where((j) =>
          !j.external &&
          j.ref != exclude &&
          j.phone == phone &&
          _sameDay(j.date, day) &&
          j.state.isUpcoming &&
          _norm(j.address.line) == _norm(a.line) &&
          j.request.car != car).firstOrNull;

  _Job? _sameBuildingJob(DateTime day, ApiAddress a, {String? exclude}) {
    if (a.building.trim().isEmpty) return null;
    return _jobs.where((j) =>
        !j.external &&
        j.ref != exclude &&
        _sameDay(j.date, day) &&
        j.state.isUpcoming &&
        _norm(j.address.building) == _norm(a.building) &&
        _norm(j.address.area) == _norm(a.area)).firstOrNull;
  }

  /// The server-side bill (contract `Bill`). Coupon problems come back in
  /// `couponReason` instead of throwing.
  ({Bill bill, int duration, bool couponApplied, String? couponReason, int credit})
      _price(String phone, BookingRequest r, CatalogService s, ApiAddress address,
          {String? exclude, _PlanRec? plan}) {
    final car = r.car.type;
    final duration = _durationOf(s, car, r.extras);
    final items = <BillItem>[];
    if (plan != null && plan.paid == false && _planVisits(plan, exclude: exclude) == 0) {
      final p = _catalog.plan(plan.planId)!;
      items.add(BillItem(kind: 'plan', name: '${p.name} (${p.visits} visits)', amount: plan.price));
    } else {
      items.add(BillItem(kind: 'service', name: s.name, amount: s.priceFor(car)));
    }
    for (final e in r.extras.entries) {
      final x = s.extra(e.key)!;
      items.add(BillItem(kind: 'extra', name: x.name, qty: e.value, amount: x.price * e.value));
    }
    final subtotal = items.fold(0, (sum, i) => sum + i.amount);
    final discounts = <BillDiscount>[];
    String? capNote;
    var couponApplied = false;
    String? couponReason;
    var credit = 0;

    if (plan != null && items.first.kind == 'service') {
      // Later plan visits: the service part is already paid for.
      discounts.add(BillDiscount(kind: 'plan', name: 'Plan visit', amount: items.first.amount));
    } else if (plan == null) {
      final secondCar = _sameHomeJob(phone, r.slot.date, address, r.car, exclude: exclude);
      final building = secondCar == null ? _sameBuildingJob(r.slot.date, address, exclude: exclude) : null;
      final cost = _cost(s, duration, r.extras, travel: secondCar == null && building == null);
      final cap = _maxDiscount(subtotal, cost);
      var room = cap;
      var capped = false;
      void add(BillDiscount d) {
        final take = min(d.amount, room);
        if (take < d.amount) capped = true;
        if (take > 0) {
          discounts.add(BillDiscount(kind: d.kind, code: d.code, name: d.name, amount: take));
          room -= take;
        }
      }

      if (secondCar != null) {
        add(BillDiscount(kind: 'auto', name: 'Second car, same visit', amount: settings.secondCarOff));
      } else if (building != null) {
        add(BillDiscount(kind: 'auto', name: 'Same building, same day', amount: settings.sameBuildingOff));
      }
      final code = r.couponCode?.trim().toUpperCase();
      if (code != null && code.isNotEmpty) {
        final c = fakeCoupons.where((c) => c.code == code).firstOrNull;
        couponReason = c == null
            ? 'This code is not valid'
            : c.whyNot(
                subtotal: subtotal,
                car: car,
                category: s.category,
                date: r.slot.date,
                firstBooking: _isFirstBooking(phone, exclude: exclude),
                usedBefore: _couponUses[c.code]?.contains(phone) == true &&
                    !_jobs.any((j) => j.ref == exclude && j.couponCode == c.code),
              );
        if (couponReason == null) {
          final before = room;
          add(BillDiscount(kind: 'coupon', code: c!.code, amount: c.amountFor(subtotal)));
          couponApplied = room < before;
          if (!couponApplied) couponReason = 'No discount is possible on this service';
        }
      }
      if (r.useCredit) {
        final have = _balance(phone) +
            (_jobs.where((j) => j.ref == exclude).firstOrNull?.creditUsed ?? 0);
        if (have > 0) {
          final before = room;
          add(BillDiscount(kind: 'credit', amount: have));
          credit = before - room;
        }
      }
      if (capped) capNote = 'Up to ₹$cap off on this booking';
    }

    final late = _customer(phone).lateFeeDue;
    final int total = max(0, subtotal - discounts.fold<int>(0, (s, d) => s + d.amount)) + late;
    return (
      bill: Bill(
        items: items,
        subtotal: subtotal,
        discounts: discounts,
        lateCancelFee: late,
        total: total,
        gst: GstSplit.ofInclusive(total, rate: settings.gstRate),
        discountCapNote: capNote,
      ),
      duration: duration,
      couponApplied: couponApplied,
      couponReason: couponReason,
      credit: credit,
    );
  }

  // ── Plans ───────────────────────────────────────────────────────────────────

  int _planVisits(_PlanRec p, {String? exclude}) => _jobs
      .where((j) =>
          j.planRecId == p.id &&
          j.ref != exclude &&
          !const [BookingState.cancelled, BookingState.unableToServe].contains(j.state))
      .length;

  Plan _planView(_PlanRec p) {
    final used = _jobs
        .where((j) =>
            j.planRecId == p.id &&
            const [BookingState.completed, BookingState.missed].contains(j.state))
        .length;
    final booked = _jobs.where((j) => j.planRecId == p.id && j.state.isUpcoming).length;
    final cat = _catalog.plan(p.planId)!;
    final status = p.cancelled
        ? PlanState.cancelled
        : !p.paid
            ? PlanState.pendingFirstVisit
            : (p.endsOn != null && p.endsOn!.isBefore(_today)) || used >= p.visitsTotal
                ? PlanState.expired
                : PlanState.active;
    return Plan(
      id: p.id,
      planId: p.planId,
      name: cat.name,
      car: p.car,
      status: status,
      startsOn: p.startsOn,
      endsOn: p.endsOn,
      visitsTotal: p.visitsTotal,
      visitsUsed: used,
      visitsBooked: booked,
      price: p.price,
      paid: p.paid,
      addressId: p.addressId,
    );
  }

  _PlanRec _usablePlan(String phone, String planRecId, BookingRequest r) {
    final p = _plans.where((p) => p.id == planRecId && p.phone == phone).firstOrNull;
    if (p == null) throw const ApiException(ApiCode.planNotUsable, 'Plan not found.');
    final v = _planView(p);
    final cat = _catalog.plan(p.planId)!;
    if (v.status == PlanState.expired || v.status == PlanState.cancelled) {
      throw const ApiException(ApiCode.planNotUsable, 'This plan has ended.');
    }
    if (r.serviceId != cat.serviceId) {
      throw const ApiException(ApiCode.planNotUsable, 'This plan is for a different service.');
    }
    if (r.car.type != p.car.type) {
      throw const ApiException(ApiCode.planNotUsable, 'This plan is for a different car.');
    }
    if (_planVisits(p) >= p.visitsTotal) {
      throw const ApiException(ApiCode.planNotUsable, 'All visits of this plan are booked.');
    }
    if (p.endsOn != null && r.slot.date.isAfter(p.endsOn!)) {
      throw const ApiException(ApiCode.planNotUsable, 'This date is after your plan ends.');
    }
    return p;
  }

  // ── Booking view ────────────────────────────────────────────────────────────

  String _statusNote(_Job j) {
    final day = j.date;
    switch (j.state) {
      case BookingState.requested:
        final by = j.confirmBy!;
        final when = _sameDay(by, _now)
            ? 'by ${clockLabel(by.hour * 60 + by.minute)}'
            : _sameDay(by, DateTime(_now.year, _now.month, _now.day + 1))
                ? 'by ${clockLabel(by.hour * 60 + by.minute)} tomorrow'
                : 'by ${clockLabel(by.hour * 60 + by.minute)} on ${dateKey(by)}';
        return "We'll confirm it $when. You'll get a WhatsApp message.";
      case BookingState.confirmed:
        return 'Expert arrives at ${clockLabel(j.start)}${_sameDay(day, _today) ? ' today' : ''}.';
      case BookingState.onTheWay:
        return 'Your expert is on the way.';
      case BookingState.inService:
        return 'Your car is being cleaned. Ready by about ${clockLabel(_readyAt(j.start, j.duration, j.lunchPause))}.';
      case BookingState.rescheduleNeeded:
        return j.offer != null ? 'The team has offered another time.' : 'Please pick another time.';
      case BookingState.completed:
        return 'Done. Thank you!';
      case BookingState.missed:
        return "Our expert couldn't reach you or the car.";
      case BookingState.cancelled:
        return 'Cancelled.';
      case BookingState.unableToServe:
        return j.teamMessage ?? "We can't do this booking.";
    }
  }

  Booking _view(_Job j) {
    final s = j.service!;
    final plan = j.planRecId == null ? null : _plans.firstWhere((p) => p.id == j.planRecId);
    int? visitNo;
    if (plan != null) {
      final visits = _jobs.where((x) => x.planRecId == plan.id).toList();
      visitNo = visits.indexOf(j) + 1;
    }
    final changeable = j.openRequest == null &&
        const [BookingState.requested, BookingState.confirmed, BookingState.rescheduleNeeded]
            .contains(j.state);
    final starts = j.startsAt;
    return Booking(
      ref: j.ref,
      createdAt: j.createdAt,
      status: j.state,
      statusNote: _statusNote(j),
      confirmBy: j.state == BookingState.requested ? j.confirmBy : null,
      service: ServiceRef(s.id, s.name, s.category),
      car: j.request.car,
      extras: [
        for (final e in j.request.extras.entries)
          BookedExtra(id: e.key, name: s.extra(e.key)!.name, qty: e.value, price: s.extra(e.key)!.price * e.value),
      ],
      slot: Slot(
          date: j.date,
          start: j.start,
          end: _readyAt(j.start, j.duration, j.lunchPause),
          label: timeRangeLabel(j.start, _readyAt(j.start, j.duration, j.lunchPause))),
      durationMinutes: j.duration,
      address: j.address,
      coverage: j.coverage,
      notes: j.request.notes,
      recipient: j.request.recipient,
      bill: j.bill,
      plan: plan == null ? null : PlanRef(plan.id, visitNo!, plan.visitsTotal),
      history: List.unmodifiable(j.history),
      teamMessage: j.teamMessage,
      offer: j.offer,
      pendingChange: j.pendingChange,
      openRequest: j.openRequest,
      payment: j.payment,
      invoice: j.invoice,
      canCancel: changeable,
      canChangeTime: changeable,
      cancelPolicy: j.state.isUpcoming
          ? CancelPolicy(
              freeUntil: starts.subtract(Duration(hours: settings.cancelFreeHours)),
              feeAfter: starts.subtract(Duration(hours: settings.cancelFeeHours)),
              fee: settings.cancelFee,
            )
          : null,
    );
  }

  void _log(_Job j, BookingState s, String note) {
    j.state = s;
    j.history.add(StatusEntry(s, _now, note));
  }

  void _send(String phone, String template, String text) =>
      outbox.add(FakeWhatsApp(phone, template, text, _now));

  // ── Public ──────────────────────────────────────────────────────────────────

  @override
  Future<ApiConfig> config() async => ApiConfig(
        openMinute: settings.open,
        closeMinute: settings.close,
        confirmWithinMinutes: settings.confirmWithinMinutes,
        bookingWindowDays: settings.bookingWindowDays,
        cancelFreeHoursBefore: settings.cancelFreeHours,
        cancelFeeHoursBefore: settings.cancelFeeHours,
        cancelFee: settings.cancelFee,
        supportWhatsApp: '919999999999',
        catalogVersion: _catalog.version,
        minAppVersion: '1.0.0',
      );

  @override
  Future<Catalog> catalog() async => _catalog;

  @override
  Future<List<PublicOffer>> offers() async =>
      [for (final c in fakeCoupons) if (c.active) c.toPublic()];

  @override
  Future<({Coverage coverage, String? areaName})> coverage(
      {double? lat, double? lng, String? pincode}) async {
    final c = coverageFor(lat: lat, lng: lng, pincode: pincode);
    return (coverage: c, areaName: c == Coverage.covered ? 'Delhi NCR' : null);
  }

  // ── Profile ─────────────────────────────────────────────────────────────────

  @override
  Future<Me> me() async {
    final phone = _requirePhone();
    final c = _customer(phone);
    _expireLots(phone);
    final lots = (_lots[phone] ?? const <_Lot>[]).where((l) => l.remaining > 0).toList()
      ..sort((a, b) => a.expiresOn.compareTo(b.expiresOn));
    return Me(
      phone: phone,
      name: c.name,
      car: c.car,
      isFirstBooking: _isFirstBooking(phone),
      walletBalance: _balance(phone),
      nextExpiryAmount: lots.isEmpty ? null : lots.first.remaining,
      nextExpiryOn: lots.isEmpty ? null : lots.first.expiresOn,
      referralCode: c.referralCode,
      activePlans: [
        for (final p in _plans.where((p) => p.phone == phone))
          if (const [PlanState.active, PlanState.pendingFirstVisit].contains(_planView(p).status))
            _planView(p),
      ],
      lateCancelFeeDue: c.lateFeeDue,
    );
  }

  @override
  Future<Me> updateMe({String? name, ApiCar? car, String? referralCode}) async {
    final phone = _requirePhone();
    final c = _customer(phone);
    if (name != null) {
      if (name.trim().length < 2) {
        throw const ApiException(ApiCode.invalidInput, 'Please enter your name.', {'field': 'name'});
      }
      c.name = name.trim();
    }
    if (car != null) c.car = car;
    if (referralCode != null && referralCode.trim().isNotEmpty) {
      final code = referralCode.trim().toUpperCase();
      final owner = _customers.values.where((x) => x.referralCode == code).firstOrNull;
      if (c.referredBy != null) {
        throw const ApiException(ApiCode.invalidInput, 'A referral code is already added.', {'field': 'referralCode'});
      }
      if (_jobs.any((j) => j.phone == phone)) {
        throw const ApiException(ApiCode.invalidInput, 'Referral codes work before your first booking.', {'field': 'referralCode'});
      }
      if (owner == null || owner.phone == phone) {
        throw const ApiException(ApiCode.invalidInput, 'This referral code is not valid.', {'field': 'referralCode'});
      }
      c.referredBy = owner.phone;
    }
    _changed();
    return me();
  }

  @override
  Future<List<ApiAddress>> addresses() async => List.unmodifiable(_addresses[_requirePhone()] ?? const []);

  ApiAddress _checked(ApiAddress a) {
    if (a.flat.trim().isEmpty || a.area.trim().length < 3) {
      throw const ApiException(ApiCode.invalidInput, 'Please add the house number and area.', {'field': 'address'});
    }
    return a.copyWith(
      line: _line(a),
      coverage: coverageFor(lat: a.pin?.lat, lng: a.pin?.lng, pincode: a.pincode),
    );
  }

  @override
  Future<ApiAddress> addAddress(ApiAddress address) async {
    final list = _addresses[_requirePhone()] ??= [];
    final saved = _checked(address).copyWith(id: _id('AD'), isDefault: list.isEmpty || address.isDefault);
    if (saved.isDefault) {
      for (var i = 0; i < list.length; i++) {
        list[i] = list[i].copyWith(isDefault: false);
      }
    }
    list.add(saved);
    _changed();
    return saved;
  }

  @override
  Future<ApiAddress> updateAddress(ApiAddress address) async {
    final list = _addresses[_requirePhone()] ?? [];
    final i = list.indexWhere((a) => a.id == address.id);
    if (i < 0) throw const ApiException(ApiCode.notFound, 'Address not found.');
    final saved = _checked(address);
    if (saved.isDefault) {
      for (var k = 0; k < list.length; k++) {
        list[k] = list[k].copyWith(isDefault: false);
      }
    }
    list[i] = saved;
    _changed();
    return saved;
  }

  @override
  Future<void> deleteAddress(String id) async {
    final phone = _requirePhone();
    final list = _addresses[phone] ?? [];
    if (!list.any((a) => a.id == id)) throw const ApiException(ApiCode.notFound, 'Address not found.');
    if (_jobs.any((j) => j.phone == phone && j.request.addressId == id && j.state.isUpcoming)) {
      throw const ApiException(ApiCode.changeNotAllowed, 'An upcoming booking uses this address.');
    }
    list.removeWhere((a) => a.id == id);
    if (list.isNotEmpty && !list.any((a) => a.isDefault)) list[0] = list[0].copyWith(isDefault: true);
    _changed();
  }

  // ── Booking ─────────────────────────────────────────────────────────────────

  CatalogService _service(String id) {
    final s = _catalog.service(id);
    if (s == null || !s.active) {
      throw const ApiException(ApiCode.invalidInput, 'This service is not available.', {'field': 'serviceId'});
    }
    return s;
  }

  void _checkExtras(CatalogService s, Map<String, int> extras) {
    for (final e in extras.entries) {
      final x = s.extra(e.key);
      if (x == null || e.value < 1 || e.value > x.maxQty) {
        throw const ApiException(ApiCode.invalidInput, 'One of the extras is not available.', {'field': 'extras'});
      }
    }
  }

  ApiAddress _addressFor(String phone, BookingRequest r) {
    if (r.addressId != null) {
      final a = (_addresses[phone] ?? const <ApiAddress>[]).where((a) => a.id == r.addressId).firstOrNull;
      if (a == null) throw const ApiException(ApiCode.invalidInput, 'Address not found.', {'field': 'addressId'});
      return a;
    }
    if (r.address != null) return _checked(r.address!);
    throw const ApiException(ApiCode.invalidInput, 'Please add where the car is parked.', {'field': 'address'});
  }

  @override
  Future<Availability> availability({
    required String serviceId,
    required ApiCar car,
    Map<String, int> extras = const {},
    required DateTime date,
    double? lat,
    double? lng,
    String? planId,
  }) async {
    final s = _service(serviceId);
    _checkExtras(s, extras);
    final day = DateTime(date.year, date.month, date.day);
    final duration = _durationOf(s, car.type, extras);
    return Availability(
      date: day,
      durationMinutes: duration,
      slots: _slotsFor(day, s, duration),
      closedReason: _dayClosedReason(day),
    );
  }

  @override
  Future<Quote> quote(BookingRequest request) async {
    final phone = _requirePhone();
    final s = _service(request.serviceId);
    _checkExtras(s, request.extras);
    final address = _addressFor(phone, request);
    final plan = request.planId == null ? null : _usablePlan(phone, request.planId!, request);
    final p = _price(phone, request, s, address, plan: plan);
    final q = Quote(
      id: _id('Q'),
      bill: p.bill,
      durationMinutes: p.duration,
      couponApplied: p.couponApplied,
      couponReason: p.couponReason,
      expiresAt: _now.add(const Duration(minutes: 10)),
    );
    _quotes[q.id] = (q, phone);
    return q;
  }

  @override
  Future<Booking> createBooking(BookingRequest r) async {
    final phone = _requirePhone();
    if (r.clientRef != null) {
      final done = _jobs.where((j) => j.clientRef == r.clientRef && j.phone == phone).firstOrNull;
      if (done != null) return _view(done);
    }
    final s = _service(r.serviceId);
    _checkExtras(s, r.extras);
    final address = _addressFor(phone, r);
    if (address.coverage == Coverage.notCovered) {
      throw const ApiException(ApiCode.notCovered, "We don't serve this area yet.");
    }
    final plan = r.planId == null ? null : _usablePlan(phone, r.planId!, r);
    final pending = _jobs.where((j) => j.phone == phone && j.state == BookingState.requested).toList();
    if (pending.length >= settings.pendingLimit) {
      throw ApiException(ApiCode.pendingLimit,
          'You already have ${pending.length} bookings waiting for confirmation.',
          {'pending': [for (final j in pending) j.ref]});
    }
    final day = DateTime(r.slot.date.year, r.slot.date.month, r.slot.date.day);
    final duration = _durationOf(s, r.car.type, r.extras);
    final onGrid = (r.slot.start - settings.firstArrival) % settings.slotStep == 0;
    final earliest = _sameDay(day, _today) ? _nowMinute + settings.minLeadMinutes : 0;
    final fit = _fitInfo(day, r.slot.start, duration, needsDetailing(s));
    if (!_inWindow(day) ||
        _dayClosedReason(day) != null ||
        !onGrid ||
        r.slot.start < earliest ||
        !fit.fits) {
      throw ApiException(ApiCode.slotTaken, 'That time was just taken.', {
        'alternatives': [for (final a in _alternatives(day, s, duration)) a.toJson()],
      });
    }
    final p = _price(phone, r, s, address, plan: plan);
    if (r.couponCode != null && r.couponCode!.trim().isNotEmpty && !p.couponApplied) {
      throw ApiException(ApiCode.couponInvalid, p.couponReason ?? 'This coupon can’t be used.',
          {'reason': p.couponReason});
    }
    if (r.expectedTotal != null && r.expectedTotal != p.bill.total) {
      final q = await quote(r);
      throw ApiException(ApiCode.priceChanged, 'The price has changed. Please check the new bill.',
          {'quote': q.toJson()});
    }

    final j = _Job(
      ref: _newRef(),
      phone: phone,
      clientRef: r.clientRef,
      createdAt: _now,
      request: r,
      service: s,
      date: day,
      start: r.slot.start,
      duration: duration,
      address: address,
      coverage: address.coverage ?? Coverage.unverified,
      bill: p.bill,
    )
      ..holdUntil = _addWorking(_now, settings.confirmWithinMinutes)
      ..confirmBy = _addWorking(_now, settings.confirmWithinMinutes)
      ..lunchPause = fit.paused
      ..planRecId = plan?.id;
    j.history.add(StatusEntry(BookingState.requested, _now, 'Request sent'));
    final coupon = p.bill.discounts.where((d) => d.kind == 'coupon').firstOrNull;
    if (coupon != null) {
      j.couponCode = coupon.code;
      (_couponUses[coupon.code!] ??= {}).add(phone);
    }
    if (p.credit > 0) {
      _useCredit(phone, p.credit, j.ref);
      j.creditUsed = p.credit;
    }
    _jobs.add(j);

    // J3: the other car in the same building gets the same-building discount too.
    final auto = p.bill.discounts.where((d) => d.kind == 'auto').firstOrNull;
    if (auto?.name == 'Same building, same day') {
      final other = _sameBuildingJob(day, address, exclude: j.ref);
      if (other != null && !other.bill.discounts.any((d) => d.kind == 'auto')) {
        _reprice(other);
      }
    }
    _changed();
    return _view(j);
  }

  /// Recomputes an existing booking's bill (keeps its coupon and credit).
  void _reprice(_Job j) {
    final r = BookingRequest(
      serviceId: j.request.serviceId,
      car: j.request.car,
      extras: j.request.extras,
      slot: SlotPick(j.date, j.start),
      addressId: j.request.addressId,
      address: j.address,
      couponCode: j.couponCode,
      useCredit: j.creditUsed > 0,
      planId: j.request.planId,
    );
    final plan = j.planRecId == null ? null : _plans.firstWhere((p) => p.id == j.planRecId);
    final p = _price(j.phone, r, j.service!, j.address, exclude: j.ref, plan: plan);
    if (p.credit != j.creditUsed) {
      final diff = p.credit - j.creditUsed;
      if (diff > 0) {
        _useCredit(j.phone, diff, j.ref);
      } else {
        _addCredit(j.phone, -diff, 'returned', 'Returned from ${j.ref}', bookingRef: j.ref);
      }
      j.creditUsed = p.credit;
    }
    j.bill = p.bill;
  }

  @override
  Future<List<Booking>> bookings({required bool upcoming}) async {
    final phone = _requirePhone();
    final list = _jobs.where((j) => !j.external && j.phone == phone && j.state.isUpcoming == upcoming).toList()
      ..sort((a, b) => upcoming ? a.startsAt.compareTo(b.startsAt) : b.startsAt.compareTo(a.startsAt));
    return [for (final j in list) _view(j)];
  }

  @override
  Future<Booking> booking(String ref) async => _view(_ownJob(ref));

  // ── After booking ───────────────────────────────────────────────────────────

  Never _notAllowed(_Job j) => throw ApiException(
      ApiCode.changeNotAllowed, 'This booking can’t be changed now.', {'status': j.state.name});

  int _feeIfCancelledNow(_Job j) {
    final minutesLeft = j.startsAt.difference(_now).inMinutes;
    return minutesLeft < settings.cancelFeeHours * 60 ? settings.cancelFee : 0;
  }

  void _releaseCoupon(_Job j) {
    final c = j.couponCode;
    if (c != null) _couponUses[c]?.remove(j.phone);
  }

  @override
  Future<Booking> cancel(String ref, {String? reason}) async {
    final j = _ownJob(ref);
    if (j.openRequest != null) _notAllowed(j);
    switch (j.state) {
      case BookingState.requested:
      case BookingState.rescheduleNeeded:
        j.offer = null;
        _returnCredit(j);
        _releaseCoupon(j);
        _log(j, BookingState.cancelled, reason == null ? 'Cancelled' : 'Cancelled: $reason');
      case BookingState.confirmed:
        j.openRequest = OpenRequest(kind: 'cancel', reason: reason, at: _now, fee: _feeIfCancelledNow(j));
        j.history.add(StatusEntry(j.state, _now, 'Cancellation requested'));
      default:
        _notAllowed(j);
    }
    _changed();
    return _view(j);
  }

  @override
  Future<Booking> changeTime(String ref, SlotPick slot) async {
    final j = _ownJob(ref);
    if (j.openRequest != null ||
        !const [BookingState.requested, BookingState.confirmed, BookingState.rescheduleNeeded]
            .contains(j.state)) {
      _notAllowed(j);
    }
    final day = DateTime(slot.date.year, slot.date.month, slot.date.day);
    final open = _slotsFor(day, j.service!, j.duration, exclude: j.ref)
        .any((s) => s.start == slot.start && s.open);
    if (!open) {
      throw ApiException(ApiCode.slotTaken, 'That time was just taken.', {
        'alternatives': [for (final a in _alternatives(day, j.service!, j.duration, exclude: j.ref)) a.toJson()],
      });
    }
    j.openRequest = OpenRequest(kind: 'changeTime', slot: SlotPick(day, slot.start), at: _now);
    j.history.add(StatusEntry(j.state, _now, 'New time requested'));
    _changed();
    return _view(j);
  }

  @override
  Future<Booking> acceptOffer(String ref) async {
    final j = _ownJob(ref);
    final o = j.offer;
    if (o == null || j.state != BookingState.rescheduleNeeded) _notAllowed(j);
    if (!o.expiresAt.isAfter(_now)) {
      throw const ApiException(ApiCode.offerExpired, 'This offer has expired. Please pick another time.');
    }
    // The offer itself holds the time (see _dayLoad), so plan without it.
    final placed = _plan(o.slot.date, exclude: j.ref,
        candidate: (j.ref, o.slot.start, j.duration, needsDetailing(j.service!)));
    if (placed == null) {
      throw ApiException(ApiCode.slotTaken, 'That time was just taken.', {
        'alternatives': [for (final a in _alternatives(o.slot.date, j.service!, j.duration, exclude: j.ref)) a.toJson()],
      });
    }
    j.date = o.slot.date;
    j.start = o.slot.start;
    j.workerId = placed.worker[j.ref];
    j.lunchPause = placed.paused.contains(j.ref);
    j.needsReassign = false;
    j.offer = null;
    j.openRequest = null;
    _log(j, BookingState.confirmed, 'New time accepted');
    _send(j.phone, 'booking_confirmed', 'Confirmed: ${dateKey(j.date)} ${clockLabel(j.start)} (${j.ref})');
    _changed();
    return _view(j);
  }

  @override
  Future<Booking> declineOffer(String ref) async {
    final j = _ownJob(ref);
    if (j.offer == null) _notAllowed(j);
    j.offer = null;
    j.history.add(StatusEntry(j.state, _now, 'Offered time declined'));
    _changed();
    return _view(j);
  }

  @override
  Future<Booking> keepAsPlanned(String ref) async {
    final j = _ownJob(ref);
    if (j.offer?.reason != 'rain' || j.openRequest != null) _notAllowed(j);
    j.openRequest = OpenRequest(kind: 'keepAsPlanned', reason: 'Covered parking', at: _now);
    j.history.add(StatusEntry(j.state, _now, 'Asked to keep the wash: covered parking'));
    _changed();
    return _view(j);
  }

  PendingChange _openChange(_Job j, String id) {
    final c = j.pendingChange;
    if (c == null || c.id != id) _notAllowed(j);
    if (!c.expiresAt.isAfter(_now)) {
      j.pendingChange = null;
      throw const ApiException(ApiCode.offerExpired, 'This change has expired.');
    }
    return c;
  }

  @override
  Future<Booking> acceptChange(String ref, String changeId) async {
    final j = _ownJob(ref);
    final c = _openChange(j, changeId);
    j.request = BookingRequest(
      serviceId: j.request.serviceId,
      car: ApiCar(c.to, j.request.car.model),
      extras: j.request.extras,
      slot: j.request.slot,
      addressId: j.request.addressId,
      address: j.request.address,
      notes: j.request.notes,
      recipient: j.request.recipient,
      couponCode: j.request.couponCode,
      useCredit: j.request.useCredit,
      planId: j.request.planId,
      clientRef: j.request.clientRef,
    );
    j.bill = c.newBill;
    j.duration = c.newDurationMinutes;
    j.pendingChange = null;
    j.history.add(StatusEntry(j.state, _now, 'New car size accepted'));
    _changed();
    return _view(j);
  }

  @override
  Future<Booking> rejectChange(String ref, String changeId) async {
    final j = _ownJob(ref);
    _openChange(j, changeId);
    j.pendingChange = null;
    _returnCredit(j);
    _releaseCoupon(j);
    _log(j, BookingState.cancelled, 'Cancelled: car size didn’t match, no fee');
    _changed();
    return _view(j);
  }

  @override
  Future<InvoiceRef> invoice(String ref) async {
    final j = _ownJob(ref);
    final i = j.invoice;
    if (i == null) throw const ApiException(ApiCode.notFound, 'The bill is ready after the service.');
    return i;
  }

  // ── Wallet, plans, referral ─────────────────────────────────────────────────

  @override
  Future<Wallet> wallet() async {
    final phone = _requirePhone();
    final balance = _balance(phone);
    return Wallet(balance: balance, entries: List.unmodifiable((_entries[phone] ?? const []).reversed));
  }

  @override
  Future<List<Plan>> plans() async {
    final phone = _requirePhone();
    return [for (final p in _plans.where((p) => p.phone == phone)) _planView(p)];
  }

  @override
  Future<({Plan plan, Booking booking})> buyPlan({
    required String clientRef,
    required String planId,
    required ApiCar car,
    required String addressId,
    required SlotPick firstVisit,
  }) async {
    final phone = _requirePhone();
    final existing = _jobs.where((j) => j.clientRef == clientRef && j.phone == phone).firstOrNull;
    if (existing != null && existing.planRecId != null) {
      final p = _plans.firstWhere((p) => p.id == existing.planRecId);
      return (plan: _planView(p), booking: _view(existing));
    }
    final cat = _catalog.plan(planId);
    if (cat == null) throw const ApiException(ApiCode.invalidInput, 'Plan not found.', {'field': 'planId'});
    final address = (_addresses[phone] ?? const <ApiAddress>[]).where((a) => a.id == addressId).firstOrNull;
    if (address == null) throw const ApiException(ApiCode.invalidInput, 'Address not found.', {'field': 'addressId'});
    if (cat.onlyInAreas && !fakePlanPincodes.contains(address.pincode)) {
      throw const ApiException(ApiCode.notCovered, 'This plan is not available in your area yet.');
    }
    final rec = _PlanRec(_id('PL'), planId, phone, car, cat.prices[car.type]!, cat.visits, cat.days, addressId);
    _plans.add(rec);
    try {
      final b = await createBooking(BookingRequest(
        clientRef: clientRef,
        serviceId: cat.serviceId,
        car: car,
        slot: firstVisit,
        addressId: addressId,
        planId: rec.id,
      ));
      return (plan: _planView(rec), booking: b);
    } catch (_) {
      _plans.remove(rec);
      _changed();
      rethrow;
    }
  }

  @override
  Future<Referral> referral() async {
    final phone = _requirePhone();
    final c = _customer(phone);
    final joined = _customers.values.where((x) => x.referredBy == phone).toList();
    return Referral(
      code: c.referralCode,
      rewardEach: settings.referralReward,
      joined: joined.length,
      rewarded: joined.where((x) => x.referralRewarded).length,
      shareText: 'Get your car washed at your doorstep with CleanCruisers. '
          'Use my code ${c.referralCode} and we both get ₹${settings.referralReward} CleanCredit.',
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Admin and worker actions (what ShineStaff does). Test builds and tests only.
  // ════════════════════════════════════════════════════════════════════════════

  _Job _job(String ref) =>
      _jobs.firstWhere((j) => j.ref == ref, orElse: () => throw StateError('No booking $ref'));

  /// All customer bookings, newest first (for the Test tools screen).
  List<Booking> adminAllBookings() =>
      [for (final j in _jobs.reversed.where((j) => !j.external)) _view(j)];

  /// Worker assigned to a booking (admin view only; never sent to customers).
  String? adminWorkerOf(String ref) => _job(ref).workerId;

  /// Requests past their hold time (admin alert, H6).
  List<String> adminOverdue() => [
        for (final j in _jobs)
          if (j.state == BookingState.requested && !(j.holdUntil?.isAfter(_now) ?? true)) j.ref,
      ];

  /// One-tap Confirm (H2): assigns a worker, confirms, sends WhatsApp.
  /// Throws [StateError] when no worker can take it.
  Booking adminConfirm(String ref) {
    final j = _job(ref);
    final ok = j.state == BookingState.requested ||
        (j.state == BookingState.confirmed && j.needsReassign);
    if (!ok) throw StateError('Booking $ref is ${j.state.name}');
    final placed = _plan(j.date, exclude: j.ref,
        candidate: (j.ref, j.start, j.duration, needsDetailing(j.service!)));
    if (placed == null) throw StateError('No worker is free for $ref');
    j.workerId = placed.worker[j.ref];
    j.lunchPause = placed.paused.contains(j.ref);
    final wasReassign = j.needsReassign;
    j.needsReassign = false;
    if (!wasReassign) {
      _log(j, BookingState.confirmed, 'Confirmed');
      _send(j.phone, 'booking_confirmed',
          'Your CleanCruisers booking ${j.ref} is confirmed for ${dateKey(j.date)}, '
          'expert arrives at ${clockLabel(j.start)}. Estimated bill ₹${j.bill.total}, pay after the service.');
    }
    _changed();
    return _view(j);
  }

  /// Admin offers another time (contract 2.1). Releases the worker.
  Booking adminOfferTime(String ref, SlotPick slot, {String reason = 'noWorker', String? message}) {
    final j = _job(ref);
    if (!j.state.isUpcoming || j.state == BookingState.inService) {
      throw StateError('Booking $ref is ${j.state.name}');
    }
    final day = DateTime(slot.date.year, slot.date.month, slot.date.day);
    j.workerId = null;
    j.needsReassign = false;
    j.openRequest = null;
    j.offer = TimeOffer(
      slot: Slot(
          date: day,
          start: slot.start,
          end: slot.start + j.duration,
          label: timeRangeLabel(slot.start, slot.start + j.duration)),
      reason: reason,
      expiresAt: _now.add(Duration(hours: settings.offerHours)),
    );
    j.teamMessage = message;
    _log(j, BookingState.rescheduleNeeded, 'Team offered another time');
    _send(j.phone, 'time_offered', 'New time offered for ${j.ref}: ${dateKey(day)} ${clockLabel(slot.start)}');
    _changed();
    return _view(j);
  }

  /// Rain (J6): offer another time, give rain credit, extend a plan.
  Booking adminRain(String ref, SlotPick slot) {
    final j = _job(ref);
    _addCredit(j.phone, settings.rainCredit, 'rain', 'Rain: wash postponed', bookingRef: ref);
    final plan = j.planRecId == null ? null : _plans.firstWhere((p) => p.id == j.planRecId);
    if (plan?.endsOn != null) {
      final e = plan!.endsOn!;
      plan.endsOn = DateTime(e.year, e.month, e.day + settings.planMissExtensionDays);
    }
    return adminOfferTime(ref, slot, reason: 'rain', message: 'Rain expected. Is your car in covered parking?');
  }

  Booking adminOnTheWay(String ref) {
    final j = _job(ref);
    if (j.state != BookingState.confirmed) throw StateError('Booking $ref is ${j.state.name}');
    _log(j, BookingState.onTheWay, 'Expert on the way');
    _changed();
    return _view(j);
  }

  Booking adminStart(String ref) {
    final j = _job(ref);
    if (j.state != BookingState.onTheWay && j.state != BookingState.confirmed) {
      throw StateError('Booking $ref is ${j.state.name}');
    }
    if (j.pendingChange != null) throw StateError('Waiting for the customer to accept a change');
    _log(j, BookingState.inService, 'Work started');
    _changed();
    return _view(j);
  }

  /// Complete + payment: GST invoice, cashback, referral, plan, late fee.
  Booking adminComplete(String ref, {String method = 'cash'}) {
    final j = _job(ref);
    if (j.state != BookingState.inService) throw StateError('Booking $ref is ${j.state.name}');
    final c = _customer(j.phone);
    _log(j, BookingState.completed, 'Completed');
    j.payment = PaymentInfo(status: 'paid', method: method, paidAt: _now);
    _invoiceSeq++;
    j.invoice = InvoiceRef('CC/26-27/${_invoiceSeq.toString().padLeft(6, '0')}',
        'https://example.invalid/invoices/${j.ref}.pdf');
    c.lateFeeDue = max(0, c.lateFeeDue - j.bill.lateCancelFee);
    final cashback = j.bill.total * settings.cashbackPercent ~/ 100;
    _addCredit(j.phone, cashback, 'cashback', '${settings.cashbackPercent}% of ${j.ref}', bookingRef: ref);
    final firstDone = !_jobs.any((x) => x != j && x.phone == j.phone && x.state == BookingState.completed);
    if (c.referredBy != null && !c.referralRewarded && firstDone && j.bill.subtotal >= settings.referralMinBill) {
      c.referralRewarded = true;
      _addCredit(j.phone, settings.referralReward, 'referral', 'Referral reward', bookingRef: ref);
      _addCredit(c.referredBy!, settings.referralReward, 'referral', 'A friend joined with your code');
    }
    if (j.planRecId != null) {
      final p = _plans.firstWhere((p) => p.id == j.planRecId);
      if (!p.paid) {
        p.paid = true;
        p.startsOn = j.date;
        p.endsOn = DateTime(j.date.year, j.date.month, j.date.day + p.days - 1);
      }
    }
    _send(j.phone, 'invoice', 'Thank you! GST invoice ${j.invoice!.number} for ${j.ref}. '
        'You earned ₹$cashback CleanCredit.');
    _changed();
    return _view(j);
  }

  /// H9: customer not available. First time free, then ₹100 on the next booking.
  Booking adminMissed(String ref) {
    final j = _job(ref);
    if (!const [BookingState.confirmed, BookingState.onTheWay].contains(j.state)) {
      throw StateError('Booking $ref is ${j.state.name}');
    }
    final c = _customer(j.phone);
    c.noShows++;
    final fee = c.noShows > 1 ? settings.cancelFee : 0;
    c.lateFeeDue += fee;
    _returnCredit(j);
    _log(j, BookingState.missed, fee > 0 ? 'Customer not available: ₹$fee on the next booking' : 'Customer not available');
    _send(j.phone, 'missed', 'Our expert could not reach you for ${j.ref}.'
        '${fee > 0 ? ' A ₹$fee fee will be added to your next booking.' : ''}');
    _changed();
    return _view(j);
  }

  /// Admin rejects a request with a reason shown to the customer.
  Booking adminReject(String ref, String reason) {
    final j = _job(ref);
    if (j.state != BookingState.requested && j.state != BookingState.rescheduleNeeded) {
      throw StateError('Booking $ref is ${j.state.name}');
    }
    j.teamMessage = reason;
    j.offer = null;
    _returnCredit(j);
    _releaseCoupon(j);
    _log(j, BookingState.unableToServe, reason);
    _changed();
    return _view(j);
  }

  /// H11: wrong car size on site. Returns null (and doesn't change anything)
  /// when the bigger job doesn't fit before the worker's next job or closing:
  /// the admin must then move the next job or offer a new time.
  Booking? adminCarSize(String ref, CarType to) {
    final j = _job(ref);
    if (!const [BookingState.confirmed, BookingState.onTheWay].contains(j.state)) {
      throw StateError('Booking $ref is ${j.state.name}');
    }
    final s = j.service!;
    final newDuration = _durationOf(s, to, j.request.extras);
    final pause = j.lunchPause ? settings.lunchMinutes : 0;
    if (j.start + newDuration + pause > settings.close) return null;
    final mine = _interval(j.start, newDuration + pause);
    final clash = _jobs.any((x) =>
        x != j &&
        x.workerId == j.workerId &&
        _sameDay(x.date, j.date) &&
        (x.external || const [BookingState.confirmed, BookingState.onTheWay, BookingState.inService].contains(x.state)) &&
        _overlaps(_interval(x.start, x.duration + (x.lunchPause ? settings.lunchMinutes : 0)), mine));
    if (clash) return null;
    final r = BookingRequest(
      serviceId: j.request.serviceId,
      car: ApiCar(to, j.request.car.model),
      extras: j.request.extras,
      slot: SlotPick(j.date, j.start),
      address: j.address,
      couponCode: j.couponCode,
      useCredit: j.creditUsed > 0,
      planId: j.request.planId,
    );
    final plan = j.planRecId == null ? null : _plans.firstWhere((p) => p.id == j.planRecId);
    final p = _price(j.phone, r, s, j.address, exclude: j.ref, plan: plan);
    j.pendingChange = PendingChange(
      id: _id('CH'),
      from: j.request.car.type,
      to: to,
      newBill: p.bill,
      newDurationMinutes: newDuration,
      expiresAt: _now.add(Duration(minutes: settings.changeMinutes)),
    );
    j.history.add(StatusEntry(j.state, _now, 'Car size on site: ${carTypeNames[to]}'));
    _changed();
    return _view(j);
  }

  /// Approves the customer's open request (cancel, change time, keep as planned).
  Booking adminApproveRequest(String ref) {
    final j = _job(ref);
    final req = j.openRequest;
    if (req == null) throw StateError('No open request on $ref');
    switch (req.kind) {
      case 'cancel':
        _customer(j.phone).lateFeeDue += req.fee;
        _returnCredit(j);
        j.openRequest = null;
        j.workerId = null;
        _log(j, BookingState.cancelled, req.fee > 0 ? 'Cancelled: ₹${req.fee} on the next booking' : 'Cancelled');
      case 'changeTime':
        final slot = req.slot!;
        final placed = _plan(slot.date, exclude: j.ref,
            candidate: (j.ref, slot.start, j.duration, needsDetailing(j.service!)));
        if (placed == null) throw StateError('That time is no longer free');
        j.date = slot.date;
        j.start = slot.start;
        j.openRequest = null;
        j.offer = null;
        j.lunchPause = placed.paused.contains(j.ref);
        if (j.state == BookingState.requested) {
          j.history.add(StatusEntry(j.state, _now, 'Time changed'));
        } else {
          j.workerId = placed.worker[j.ref];
          _log(j, BookingState.confirmed, 'Time changed');
        }
      case 'keepAsPlanned':
        j.openRequest = null;
        j.offer = null;
        final placed = _plan(j.date, exclude: j.ref,
            candidate: (j.ref, j.start, j.duration, needsDetailing(j.service!)));
        if (placed == null) throw StateError('No worker is free at the original time');
        j.workerId = placed.worker[j.ref];
        j.lunchPause = placed.paused.contains(j.ref);
        _log(j, BookingState.confirmed, 'Wash kept as planned');
    }
    _changed();
    return _view(j);
  }

  /// Declines the open request with a message to the customer.
  Booking adminDeclineRequest(String ref, String message) {
    final j = _job(ref);
    if (j.openRequest == null) throw StateError('No open request on $ref');
    j.openRequest = null;
    j.teamMessage = message;
    j.history.add(StatusEntry(j.state, _now, message));
    _changed();
    return _view(j);
  }

  /// Worker sick / breakdown (G4, H8): their jobs that day need a new worker;
  /// customers keep seeing Confirmed.
  List<String> adminWorkerUnavailable(String workerId, DateTime day) {
    _unavailable.add('$workerId|${dateKey(day)}');
    final moved = <String>[];
    for (final j in _jobs) {
      if (j.workerId == workerId && _sameDay(j.date, day) && j.state.isUpcoming && !j.external) {
        j.workerId = null;
        j.needsReassign = true;
        moved.add(j.ref);
      }
    }
    _changed();
    return moved;
  }

  void adminCloseDay(DateTime day, String reason) {
    _closedDays[dateKey(day)] = reason;
    _changed();
  }

  void adminGoodwill(String phone, int amount, String reason) {
    _addCredit(phone, amount, 'goodwill', reason);
    _changed();
  }

  /// Clears every customer, booking and credit (Test tools: start over).
  void adminReset() {
    _phone = null;
    _customers.clear();
    _addresses.clear();
    _jobs.clear();
    _plans.clear();
    _entries.clear();
    _lots.clear();
    _couponUses.clear();
    _quotes.clear();
    _closedDays.clear();
    _unavailable.clear();
    outbox.clear();
    _invoiceSeq = 0;
    _idSeq = 0;
    _changed();
  }

  /// A SofaShine job that takes a shared worker's time (H5).
  void adminAddSofaShineJob(String workerId, DateTime day, int start, int duration) {
    _jobs.add(_Job(
      ref: _id('SS'),
      phone: '',
      createdAt: _now,
      external: true,
      request: BookingRequest(serviceId: 'sofa', car: const ApiCar(CarType.hatchback), slot: SlotPick(day, start)),
      service: null,
      date: DateTime(day.year, day.month, day.day),
      start: start,
      duration: duration,
      address: const ApiAddress(flat: '-', area: 'SofaShine'),
      coverage: Coverage.covered,
      bill: Bill(items: const [], subtotal: 0, total: 0, gst: GstSplit.ofInclusive(0)),
    )
      ..workerId = workerId
      ..state = BookingState.confirmed);
    _changed();
  }

  // ── Saving the state (test builds keep it across app restarts) ─────────────

  static String? _d(DateTime? d) => d?.toIso8601String();
  static DateTime? _p(Object? v) => v is String ? DateTime.parse(v) : null;
  static Map<String, dynamic> _m(Object? v) => Map<String, dynamic>.from(v as Map);

  Map<String, dynamic> toJson() => {
        'v': 1,
        'phone': _phone,
        'idSeq': _idSeq,
        'invoiceSeq': _invoiceSeq,
        'customers': [
          for (final c in _customers.values)
            {
              'phone': c.phone,
              'name': c.name,
              'car': c.car?.toJson(),
              'referralCode': c.referralCode,
              'referredBy': c.referredBy,
              'referralRewarded': c.referralRewarded,
              'lateFeeDue': c.lateFeeDue,
              'noShows': c.noShows,
            },
        ],
        'addresses': {
          for (final e in _addresses.entries) e.key: [for (final a in e.value) a.toJson()],
        },
        'jobs': [
          for (final j in _jobs)
            {
              'ref': j.ref,
              'phone': j.phone,
              'clientRef': j.clientRef,
              'createdAt': _d(j.createdAt),
              'external': j.external,
              'request': j.request.toJson(),
              'serviceId': j.service?.id,
              'date': dateKey(j.date),
              'start': j.start,
              'duration': j.duration,
              'address': j.address.toJson(),
              'coverage': j.coverage.name,
              'bill': j.bill.toJson(),
              'state': j.state.name,
              'history': [for (final h in j.history) h.toJson()],
              'teamMessage': j.teamMessage,
              'offer': j.offer?.toJson(),
              'pendingChange': j.pendingChange?.toJson(),
              'openRequest': j.openRequest?.toJson(),
              'payment': j.payment.toJson(),
              'invoice': j.invoice?.toJson(),
              'workerId': j.workerId,
              'needsReassign': j.needsReassign,
              'lunchPause': j.lunchPause,
              'holdUntil': _d(j.holdUntil),
              'confirmBy': _d(j.confirmBy),
              'couponCode': j.couponCode,
              'creditUsed': j.creditUsed,
              'planRecId': j.planRecId,
            },
        ],
        'plans': [
          for (final p in _plans)
            {
              'id': p.id,
              'planId': p.planId,
              'phone': p.phone,
              'car': p.car.toJson(),
              'price': p.price,
              'visitsTotal': p.visitsTotal,
              'days': p.days,
              'addressId': p.addressId,
              'startsOn': p.startsOn == null ? null : dateKey(p.startsOn!),
              'endsOn': p.endsOn == null ? null : dateKey(p.endsOn!),
              'paid': p.paid,
              'cancelled': p.cancelled,
            },
        ],
        'entries': {
          for (final e in _entries.entries) e.key: [for (final w in e.value) w.toJson()],
        },
        'lots': {
          for (final e in _lots.entries)
            e.key: [
              for (final l in e.value)
                {'entryId': l.entryId, 'remaining': l.remaining, 'expiresOn': dateKey(l.expiresOn)},
            ],
        },
        'couponUses': {for (final e in _couponUses.entries) e.key: e.value.toList()},
        'closedDays': _closedDays,
        'unavailable': _unavailable.toList(),
        'outbox': [
          for (final o in outbox)
            {'phone': o.phone, 'template': o.template, 'text': o.text, 'at': _d(o.at)},
        ],
      };

  /// Loads a state saved with [toJson]. Unknown versions are ignored.
  void restore(Map<String, dynamic> j) {
    if (j['v'] != 1) return;
    _phone = j['phone'] as String?;
    _idSeq = j['idSeq'] as int? ?? 0;
    _invoiceSeq = j['invoiceSeq'] as int? ?? 0;
    _customers
      ..clear()
      ..addAll({
        for (final raw in j['customers'] as List? ?? const [])
          (raw as Map)['phone'] as String: _Customer(raw['phone'] as String, raw['referralCode'] as String)
            ..name = raw['name'] as String? ?? ''
            ..car = raw['car'] == null ? null : ApiCar.fromJson(_m(raw['car']))
            ..referredBy = raw['referredBy'] as String?
            ..referralRewarded = raw['referralRewarded'] as bool? ?? false
            ..lateFeeDue = raw['lateFeeDue'] as int? ?? 0
            ..noShows = raw['noShows'] as int? ?? 0,
      });
    _addresses
      ..clear()
      ..addAll({
        for (final e in _m(j['addresses'] ?? const {}).entries)
          e.key: [for (final a in e.value as List) ApiAddress.fromJson(_m(a))],
      });
    _jobs
      ..clear()
      ..addAll([
        for (final raw in j['jobs'] as List? ?? const [])
          () {
            final m = _m(raw);
            final serviceId = m['serviceId'] as String?;
            return _Job(
              ref: m['ref'] as String,
              phone: m['phone'] as String,
              clientRef: m['clientRef'] as String?,
              createdAt: DateTime.parse(m['createdAt'] as String),
              external: m['external'] as bool? ?? false,
              request: BookingRequest.fromJson(_m(m['request'])),
              service: serviceId == null ? null : _catalog.service(serviceId),
              date: parseDateKey(m['date'] as String),
              start: m['start'] as int,
              duration: m['duration'] as int,
              address: ApiAddress.fromJson(_m(m['address'])),
              coverage: coverageFrom(m['coverage'] as String?),
              bill: Bill.fromJson(_m(m['bill'])),
            )
              ..state = bookingStateFrom(m['state'] as String)
              ..teamMessage = m['teamMessage'] as String?
              ..offer = m['offer'] == null ? null : TimeOffer.fromJson(_m(m['offer']))
              ..pendingChange =
                  m['pendingChange'] == null ? null : PendingChange.fromJson(_m(m['pendingChange']))
              ..openRequest = m['openRequest'] == null ? null : OpenRequest.fromJson(_m(m['openRequest']))
              ..payment = PaymentInfo.fromJson(_m(m['payment']))
              ..invoice = m['invoice'] == null ? null : InvoiceRef.fromJson(_m(m['invoice']))
              ..workerId = m['workerId'] as String?
              ..needsReassign = m['needsReassign'] as bool? ?? false
              ..lunchPause = m['lunchPause'] as bool? ?? false
              ..holdUntil = _p(m['holdUntil'])
              ..confirmBy = _p(m['confirmBy'])
              ..couponCode = m['couponCode'] as String?
              ..creditUsed = m['creditUsed'] as int? ?? 0
              ..planRecId = m['planRecId'] as String?
              ..history.addAll([for (final h in m['history'] as List? ?? const []) StatusEntry.fromJson(_m(h))]);
          }(),
      ]);
    _plans
      ..clear()
      ..addAll([
        for (final raw in j['plans'] as List? ?? const [])
          () {
            final m = _m(raw);
            return _PlanRec(
              m['id'] as String,
              m['planId'] as String,
              m['phone'] as String,
              ApiCar.fromJson(_m(m['car'])),
              m['price'] as int,
              m['visitsTotal'] as int,
              m['days'] as int,
              m['addressId'] as String,
            )
              ..startsOn = m['startsOn'] == null ? null : parseDateKey(m['startsOn'] as String)
              ..endsOn = m['endsOn'] == null ? null : parseDateKey(m['endsOn'] as String)
              ..paid = m['paid'] as bool? ?? false
              ..cancelled = m['cancelled'] as bool? ?? false;
          }(),
      ]);
    _entries
      ..clear()
      ..addAll({
        for (final e in _m(j['entries'] ?? const {}).entries)
          e.key: [for (final w in e.value as List) WalletEntry.fromJson(_m(w))],
      });
    _lots
      ..clear()
      ..addAll({
        for (final e in _m(j['lots'] ?? const {}).entries)
          e.key: [
            for (final l in e.value as List)
              _Lot((l as Map)['entryId'] as String, l['remaining'] as int, parseDateKey(l['expiresOn'] as String)),
          ],
      });
    _couponUses
      ..clear()
      ..addAll({
        for (final e in _m(j['couponUses'] ?? const {}).entries)
          e.key: {for (final p in e.value as List) p as String},
      });
    _closedDays
      ..clear()
      ..addAll({for (final e in _m(j['closedDays'] ?? const {}).entries) e.key: e.value as String});
    _unavailable
      ..clear()
      ..addAll([for (final u in j['unavailable'] as List? ?? const []) u as String]);
    outbox
      ..clear()
      ..addAll([
        for (final raw in j['outbox'] as List? ?? const [])
          FakeWhatsApp((raw as Map)['phone'] as String, raw['template'] as String, raw['text'] as String,
              DateTime.parse(raw['at'] as String)),
      ]);
  }
}
