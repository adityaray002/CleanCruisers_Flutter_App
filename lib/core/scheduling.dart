import 'dart:math' as math;

import '../models/service.dart';
import '../models/worker.dart';

// ── Operating rules ───────────────────────────────────────────────────────────
// All times are minutes after midnight. The defaults are the owner's confirmed
// rules from the operations brief (31 Oct 2026). Anything not confirmed by the
// owner (buffers, latest return) defaults to "off" and is set by an admin.

class ScheduleRules {
  final int dayStart; // regular duty starts
  final int firstArrival; // earliest customer arrival window
  final int customerFinish; // all customer vehicle work done by
  final double maxLegKm; // every regular road leg
  final List<int> lunchStartOptions;
  final int lunchMinutes;
  final int bufferMinutes; // per job, on top of service time
  final int emergencyStandbyBy; // emergency worker back at standby by
  final int emergencyMaxJobs;

  const ScheduleRules({
    this.dayStart = 8 * 60,
    this.firstArrival = 8 * 60 + 30,
    this.customerFinish = 18 * 60,
    this.maxLegKm = 25,
    this.lunchStartOptions = const [13 * 60, 13 * 60 + 30],
    this.lunchMinutes = 30,
    this.bufferMinutes = 0,
    this.emergencyStandbyBy = 11 * 60,
    this.emergencyMaxJobs = 1,
  });

  ScheduleRules copyWith({int? bufferMinutes, List<int>? lunchStartOptions}) =>
      ScheduleRules(
        dayStart: dayStart,
        firstArrival: firstArrival,
        customerFinish: customerFinish,
        maxLegKm: maxLegKm,
        lunchStartOptions: lunchStartOptions ?? this.lunchStartOptions,
        lunchMinutes: lunchMinutes,
        bufferMinutes: bufferMinutes ?? this.bufferMinutes,
        emergencyStandbyBy: emergencyStandbyBy,
        emergencyMaxJobs: emergencyMaxJobs,
      );
}

/// "9:30 – 10:30 AM", "11:30 AM – 12:30 PM": compact, for customers.
String timeRangeLabel(int start, int end) {
  String hm(int m) {
    final h = (m ~/ 60) % 12 == 0 ? 12 : (m ~/ 60) % 12;
    final mm = m % 60;
    return mm == 0 ? '$h' : '$h:${mm.toString().padLeft(2, '0')}';
  }

  String ap(int m) => m < 12 * 60 ? 'AM' : 'PM';
  return ap(start) == ap(end)
      ? '${hm(start)} – ${hm(end)} ${ap(end)}'
      : '${hm(start)} ${ap(start)} – ${hm(end)} ${ap(end)}';
}

String clockLabel(int minuteOfDay) {
  final hour = minuteOfDay ~/ 60;
  final minute = minuteOfDay % 60;
  final suffix = hour < 12 ? 'AM' : 'PM';
  final shown = hour % 12 == 0 ? 12 : hour % 12;
  return '$shown:${minute.toString().padLeft(2, '0')} $suffix';
}

/// Expected completion time for customer reassurance (e.g. "Ready by ~11:30 AM").
String readyByLabel(int arrivalMinute, int durationMinutes) {
  final finishMinute = arrivalMinute + durationMinutes;
  return 'Ready by ~${clockLabel(finishMinute)}';
}

// ── Route legs ────────────────────────────────────────────────────────────────

/// One road leg of a worker's day. Distance is road km, never straight-line.
class RouteLeg {
  final double km;
  final int minutes;
  final String source; // 'manual' until a routing provider is configured
  final DateTime? recordedAt;

  const RouteLeg({
    required this.km,
    required this.minutes,
    this.source = 'manual',
    this.recordedAt,
  });

  bool get isManual => source == 'manual';

  Map<String, dynamic> toJson() => {
        'km': km,
        'minutes': minutes,
        'source': source,
        'recordedAt': recordedAt?.toIso8601String(),
      };

  static RouteLeg? fromJson(Object? j) {
    if (j is! Map) return null;
    final km = j['km'];
    final minutes = j['minutes'];
    if (km is! num || minutes is! num) return null;
    return RouteLeg(
      km: km.toDouble(),
      minutes: minutes.toInt(),
      source: j['source'] as String? ?? 'manual',
      recordedAt: DateTime.tryParse(j['recordedAt'] as String? ?? ''),
    );
  }
}

// ── Day planning ──────────────────────────────────────────────────────────────

class PlannedJob {
  final String ref;
  final int windowStart, windowEnd; // customer arrival window
  final int serviceMinutes; // safe upper estimate incl. add-ons, no travel
  final ServiceCategory category;
  final RouteLeg? legIn; // previous stop (or home/standby) → this site

  const PlannedJob({
    required this.ref,
    required this.windowStart,
    required this.windowEnd,
    required this.serviceMinutes,
    required this.category,
    this.legIn,
  });

  PlannedJob withLegIn(RouteLeg? leg) => PlannedJob(
        ref: ref,
        windowStart: windowStart,
        windowEnd: windowEnd,
        serviceMinutes: serviceMinutes,
        category: category,
        legIn: leg,
      );
}

enum RouteIssueCode {
  inactive,
  weeklyOff,
  onLeave,
  disrupted,
  missingSkill,
  missingLeg,
  legTooLong,
  overlap,
  missedWindow,
  finishAfterClose,
  emergencyTooManyJobs,
  emergencyLateReturn,
}

class RouteIssue {
  final RouteIssueCode code;
  final String message;
  final String? ref;
  const RouteIssue(this.code, this.message, {this.ref});

  @override
  String toString() => message;
}

class StopPlan {
  final String ref;
  final int departAt, arriveAt, workStart, workEnd;
  const StopPlan(
      {required this.ref,
      required this.departAt,
      required this.arriveAt,
      required this.workStart,
      required this.workEnd});
}

class DayPlan {
  final List<StopPlan> stops;
  final int? lunchAt;
  final int? endOfDay; // back home / at standby
  final List<RouteIssue> issues;
  const DayPlan(
      {required this.stops,
      required this.lunchAt,
      required this.endOfDay,
      required this.issues});

  bool get feasible => issues.isEmpty;
  StopPlan? stopFor(String ref) => stops.where((s) => s.ref == ref).firstOrNull;
}

/// Simulates one worker's day and lists every hard-rule violation.
///
/// Jobs are visited in arrival-window order. The worker leaves home (or the
/// standby office for the emergency worker) at duty start. A 30-minute lunch
/// is taken at the first allowed start time when the worker is free; if they
/// are driving or working then, the work pauses for lunch.
DayPlan planWorkerDay({
  required WorkerRecord worker,
  required DateTime date,
  required List<PlannedJob> jobs,
  required RouteLeg? returnLeg,
  ScheduleRules rules = const ScheduleRules(),
  bool allowEmergencyLongLegs = false,
}) {
  final issues = <RouteIssue>[];
  final key = dateKey(date);
  final name = worker.name;

  if (!worker.active) {
    issues.add(RouteIssue(RouteIssueCode.inactive, '$name is not active.'));
  }
  if (worker.weeklyOff == weekdayName(date)) {
    issues.add(RouteIssue(
        RouteIssueCode.weeklyOff, '$name has their weekly off on this day.'));
  }
  if (worker.unavailableDates.contains(key)) {
    issues
        .add(RouteIssue(RouteIssueCode.onLeave, '$name is on leave this day.'));
  }
  final disruption = worker.disruptions[key];
  if (disruption != null) {
    issues.add(RouteIssue(RouteIssueCode.disrupted,
        '$name reported "${disruption.label}" for this day. Resolve it before assigning more work.'));
  }
  if (worker.isEmergency && jobs.length > rules.emergencyMaxJobs) {
    issues.add(RouteIssue(RouteIssueCode.emergencyTooManyJobs,
        'The emergency cover worker can take only ${rules.emergencyMaxJobs} normal morning booking.'));
  }

  final sorted = [...jobs]
    ..sort((a, b) => a.windowStart.compareTo(b.windowStart));
  final lunchOptions = [...rules.lunchStartOptions]..sort();
  int? lunchAt;

  // Busy time (driving or working) from [start] for [minutes]; pauses for
  // lunch if an allowed lunch start falls inside it.
  int busy(int start, int minutes) {
    var end = start + minutes;
    if (lunchAt == null) {
      for (final l in lunchOptions) {
        if (l >= start && l < end) {
          lunchAt = l;
          end += rules.lunchMinutes;
          break;
        }
      }
    }
    return end;
  }

  // Idle gap: take lunch here if a whole lunch break fits.
  void idle(int from, int to) {
    if (lunchAt != null) return;
    for (final l in lunchOptions) {
      if (l >= from && l + rules.lunchMinutes <= to) {
        lunchAt = l;
        return;
      }
    }
  }

  void checkLeg(RouteLeg? leg, String label, String? ref) {
    if (leg == null) {
      issues.add(RouteIssue(RouteIssueCode.missingLeg,
          'Enter road distance and drive time for $label.',
          ref: ref));
      return;
    }
    final longOk = worker.isEmergency && allowEmergencyLongLegs;
    if (leg.km > rules.maxLegKm && !longOk) {
      issues.add(RouteIssue(RouteIssueCode.legTooLong,
          '$label is ${_km(leg.km)} km; every leg must be ${_km(rules.maxLegKm)} km or less.',
          ref: ref));
    }
  }

  final stops = <StopPlan>[];
  var t = rules.dayStart;
  String previous = worker.isEmergency ? 'standby office' : 'home';
  for (final job in sorted) {
    if (!worker.canDo(job.category)) {
      issues.add(RouteIssue(RouteIssueCode.missingSkill,
          '$name is not set up for ${serviceCategoryNames[job.category]} jobs.',
          ref: job.ref));
    }
    checkLeg(job.legIn, '$previous → ${job.ref}', job.ref);
    final depart = t;
    final driveEnd = busy(t, job.legIn?.minutes ?? 0);
    final earliest = math.max(job.windowStart, rules.firstArrival);
    final arrive = math.max(driveEnd, earliest);
    idle(driveEnd, arrive);
    if (arrive > job.windowEnd) {
      issues.add(RouteIssue(
          stops.isEmpty ? RouteIssueCode.missedWindow : RouteIssueCode.overlap,
          'Arrival at ${job.ref} would be ${clockLabel(arrive)}, after the ${clockLabel(job.windowStart)}–${clockLabel(job.windowEnd)} window.',
          ref: job.ref));
    }
    final workEnd = busy(arrive, job.serviceMinutes + rules.bufferMinutes);
    final customerDone = workEnd - rules.bufferMinutes;
    if (customerDone > rules.customerFinish) {
      issues.add(RouteIssue(RouteIssueCode.finishAfterClose,
          '${job.ref} would finish at ${clockLabel(customerDone)}; customer work must end by ${clockLabel(rules.customerFinish)}.',
          ref: job.ref));
    }
    stops.add(StopPlan(
        ref: job.ref,
        departAt: depart,
        arriveAt: arrive,
        workStart: arrive,
        workEnd: workEnd));
    t = workEnd;
    previous = job.ref;
  }

  int? endOfDay;
  if (sorted.isNotEmpty) {
    final home = worker.isEmergency ? 'standby office' : 'home';
    checkLeg(returnLeg, '$previous → $home', sorted.last.ref);
    endOfDay = busy(t, returnLeg?.minutes ?? 0);
    if (worker.isEmergency && endOfDay > rules.emergencyStandbyBy) {
      issues.add(RouteIssue(RouteIssueCode.emergencyLateReturn,
          'The emergency worker would be back at standby at ${clockLabel(endOfDay)}; they must be back by ${clockLabel(rules.emergencyStandbyBy)}.'));
    }
  }

  return DayPlan(
      stops: stops, lunchAt: lunchAt, endOfDay: endOfDay, issues: issues);
}

String _km(double km) =>
    km == km.roundToDouble() ? km.toStringAsFixed(0) : km.toStringAsFixed(1);

// ── Customer-facing window states ─────────────────────────────────────────────

/// Admin-controlled caps for one date. These are hard limits layered over
/// worker feasibility; they never create worker time.
class CapacityDay {
  final bool closed;
  final Set<String> closedWindows;
  final Map<String, int> caps; // window id → max requests
  final Map<String, int> held; // window id → requests holding capacity
  final String? note;

  const CapacityDay({
    this.closed = false,
    this.closedWindows = const {},
    this.caps = const {},
    this.held = const {},
    this.note,
  });

  static const open = CapacityDay();

  bool isFull(String windowId) {
    final cap = caps[windowId];
    return cap != null && (held[windowId] ?? 0) >= cap;
  }

  factory CapacityDay.fromJson(Map<String, dynamic>? j) {
    if (j == null) return open;
    Map<String, int> ints(Object? m) => {
          for (final e in ((m as Map?) ?? const {}).entries)
            if (e.value is num) e.key as String: (e.value as num).toInt(),
        };
    return CapacityDay(
      closed: j['closed'] as bool? ?? false,
      closedWindows: {
        for (final w in (j['closedWindows'] as List? ?? const [])) w as String
      },
      caps: ints(j['caps']),
      // Flat "held_0830" fields, so security rules can check that a customer
      // request adds exactly one to exactly one window.
      held: {
        for (final e in j.entries)
          if (e.key.startsWith(heldPrefix) && e.value is num)
            e.key.substring(heldPrefix.length): (e.value as num).toInt(),
      },
      note: j['note'] as String?,
    );
  }

  static const heldPrefix = 'held_';
}

enum WindowState { preference, passed, tooLate, closedByTeam, full }

/// Whether a customer may pick this arrival window as a preference. This is
/// never a confirmation: only an assigned, validated route confirms a booking.
WindowState customerWindowState({
  required int windowStart,
  required String windowId,
  required DateTime date,
  required int serviceMinutes,
  CapacityDay capacity = CapacityDay.open,
  ScheduleRules rules = const ScheduleRules(),
  DateTime? now,
}) {
  final n = now ?? DateTime.now();
  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(n.year, n.month, n.day);
  if (day.isBefore(today)) return WindowState.passed;
  if (day == today && n.hour * 60 + n.minute >= windowStart) {
    return WindowState.passed;
  }
  if (!canFinishByClose(windowStart, serviceMinutes, rules)) {
    return WindowState.tooLate;
  }
  if (capacity.closed || capacity.closedWindows.contains(windowId)) {
    return WindowState.closedByTeam;
  }
  if (capacity.isFull(windowId)) return WindowState.full;
  return WindowState.preference;
}

/// Starting work at [start], does the job (with a lunch pause if it spans
/// lunch) end by the customer-finish time?
bool canFinishByClose(int start, int serviceMinutes,
    [ScheduleRules rules = const ScheduleRules()]) {
  var end = start + serviceMinutes;
  if (rules.lunchStartOptions.any((l) => l >= start && l < end)) {
    end += rules.lunchMinutes;
  }
  return end <= rules.customerFinish;
}

// ── Service area ──────────────────────────────────────────────────────────────

class LatLng {
  final double lat, lng;
  const LatLng(this.lat, this.lng);

  @override
  String toString() => '${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';
}

/// Reads "28.6210,77.0890", a Google Maps link containing "@lat,lng" or
/// "q=lat,lng", or similar. Returns null when no valid coordinate is found.
LatLng? parsePin(String? text) {
  if (text == null) return null;
  final m = RegExp(r'(-?\d{1,2}\.\d+)\s*,\s*(-?\d{1,3}\.\d+)').firstMatch(text);
  if (m == null) return null;
  final lat = double.parse(m.group(1)!);
  final lng = double.parse(m.group(2)!);
  if (lat.abs() > 90 || lng.abs() > 180) return null;
  return LatLng(lat, lng);
}

class ServiceArea {
  final String name;
  final List<LatLng> polygon;
  const ServiceArea(this.name, this.polygon);

  bool contains(LatLng p) {
    if (polygon.length < 3) return false;
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[i], b = polygon[j];
      final crosses = (a.lat > p.lat) != (b.lat > p.lat) &&
          p.lng < (b.lng - a.lng) * (p.lat - a.lat) / (b.lat - a.lat) + a.lng;
      if (crosses) inside = !inside;
    }
    return inside;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'polygon': [
          for (final p in polygon) {'lat': p.lat, 'lng': p.lng}
        ],
      };

  static ServiceArea? fromJson(Object? j) {
    if (j is! Map) return null;
    final points = <LatLng>[
      for (final p in (j['polygon'] as List? ?? const []))
        if (p is Map && p['lat'] is num && p['lng'] is num)
          LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()),
    ];
    if (points.length < 3) return null;
    return ServiceArea(j['name'] as String? ?? 'Area', points);
  }
}

enum Coverage { covered, notCovered, unverified }

/// Coverage of a pin against admin-configured areas. Without a pin, or
/// without configured areas, the answer is "unverified" — never "covered".
Coverage checkCoverage(LatLng? pin, List<ServiceArea> areas) {
  if (pin == null || areas.isEmpty) return Coverage.unverified;
  return areas.any((a) => a.contains(pin))
      ? Coverage.covered
      : Coverage.notCovered;
}

// ── Admin settings ────────────────────────────────────────────────────────────

/// Staff-only operating settings, editable on the booking desk.
class OpsSettings {
  /// Internal target for answering a new request. Not shown to customers
  /// until the team meets it consistently.
  final int reviewTargetMinutes;
  final int bufferMinutes;
  final List<int> lunchStartOptions;

  /// Soft goal for productive service hours per worker per day. Shown as a
  /// shortfall warning only; it never changes what can be booked.
  final double? productiveHoursTarget;

  const OpsSettings({
    this.reviewTargetMinutes = 15,
    this.bufferMinutes = 0,
    this.lunchStartOptions = const [13 * 60, 13 * 60 + 30],
    this.productiveHoursTarget,
  });

  ScheduleRules get rules => const ScheduleRules().copyWith(
      bufferMinutes: bufferMinutes, lunchStartOptions: lunchStartOptions);

  Map<String, dynamic> toJson() => {
        'reviewTargetMinutes': reviewTargetMinutes,
        'bufferMinutes': bufferMinutes,
        'lunchStartOptions': lunchStartOptions,
        'productiveHoursTarget': productiveHoursTarget,
      };

  factory OpsSettings.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const OpsSettings();
    final lunch = [
      for (final l in (j['lunchStartOptions'] as List? ?? const []))
        if (l is num) l.toInt(),
    ];
    return OpsSettings(
      reviewTargetMinutes: (j['reviewTargetMinutes'] as num?)?.toInt() ?? 15,
      bufferMinutes: (j['bufferMinutes'] as num?)?.toInt() ?? 0,
      lunchStartOptions: lunch.isEmpty ? const [13 * 60, 13 * 60 + 30] : lunch,
      productiveHoursTarget: (j['productiveHoursTarget'] as num?)?.toDouble(),
    );
  }
}
