import 'package:cleancruisers_app/core/pricing.dart';
import 'package:cleancruisers_app/core/scheduling.dart';
import 'package:cleancruisers_app/models/booking.dart';
import 'package:cleancruisers_app/models/service.dart';
import 'package:cleancruisers_app/models/worker.dart';
import 'package:flutter_test/flutter_test.dart';

// Thursday 5 Nov 2026.
final day = DateTime(2026, 11, 5);

WorkerRecord regular({
  String weeklyOff = 'Sunday',
  List<String> leave = const [],
  Set<ServiceCategory> skills = const {},
  Map<String, DisruptionType> disruptions = const {},
}) =>
    WorkerRecord(
      id: 'w1',
      name: 'Amit',
      isEmergency: false,
      active: true,
      homeArea: 'Dwarka',
      weeklyOff: weeklyOff,
      unavailableDates: leave,
      skills: skills,
      disruptions: disruptions,
    );

const emergencyWorker = WorkerRecord(
  id: 'e1',
  name: 'Ravi',
  isEmergency: true,
  active: true,
  homeArea: 'Standby office',
  weeklyOff: 'Sunday',
);

RouteLeg leg(double km, int minutes) => RouteLeg(km: km, minutes: minutes);

PlannedJob job(String ref, String slotId, int minutes,
        {RouteLeg? legIn, ServiceCategory category = ServiceCategory.wash}) =>
    PlannedJob(
      ref: ref,
      windowStart: slotById(slotId)!.startMinute,
      windowEnd: slotById(slotId)!.endMinute,
      serviceMinutes: minutes,
      category: category,
      legIn: legIn,
    );

Set<RouteIssueCode> codes(DayPlan p) => {for (final i in p.issues) i.code};

void main() {
  group('service duration', () {
    test('uses the safe upper estimate and adds add-on time', () {
      // Interior + Exterior hatchback is "1.5–2 h": plan for 2 h.
      expect(bookingDurationMinutes('wash-full', CarType.hatchback, {}), 120);
      expect(bookingDurationMinutes('wash-full', CarType.suv, {}), 150);
      // 3 seats × 15 min + AC vents 25 min.
      expect(
          bookingDurationMinutes(
              'wash-full', CarType.hatchback, {'seat': 3, 'ac': 1}),
          120 + 45 + 25);
      expect(bookingDurationMinutes('full-package', CarType.sedan, {}), 300);
      expect(bookingDurationMinutes('rubbing-wax-exterior', CarType.sedan, {}),
          120);
      expect(bookingDurationMinutes('dryclean-wax-exterior', CarType.suv, {}),
          270);
    });

    test('unknown add-on time blocks silent shortening', () {
      final d = BookingDraft(
          service: serviceById('3m-wax-exterior')!,
          car: CarType.sedan,
          extras: const {'air-freshener': 1});
      expect(d.durationNeedsConfirmation, isTrue);
      expect(d.serviceDurationMinutes, 120);
    });

    test('an unknown service is planned as the longest job', () {
      expect(baseServiceMinutes('something-new', CarType.sedan), 300);
    });
  });

  group('customer windows', () {
    final now = DateTime(2026, 11, 4, 10);

    test('5-hour detail fits at 12:30 (with lunch) but not at 13:30', () {
      expect(canFinishByClose(12 * 60 + 30, 300), isTrue); // ends 18:00
      expect(
          customerWindowState(
              windowStart: 13 * 60 + 30,
              windowId: '1330',
              date: day,
              serviceMinutes: 300,
              now: now),
          WindowState.tooLate);
    });

    test('admin cap: the last opening is full once it is held', () {
      const cap = CapacityDay(caps: {'0930': 1}, held: {'0930': 1});
      expect(
          customerWindowState(
              windowStart: 9 * 60 + 30,
              windowId: '0930',
              date: day,
              serviceMinutes: 60,
              capacity: cap,
              now: now),
          WindowState.full);
      expect(
          customerWindowState(
              windowStart: 10 * 60 + 30,
              windowId: '1030',
              date: day,
              serviceMinutes: 60,
              capacity: cap,
              now: now),
          WindowState.preference);
    });

    test('closed dates and windows are not offered', () {
      expect(
          customerWindowState(
              windowStart: 8 * 60 + 30,
              windowId: '0830',
              date: day,
              serviceMinutes: 60,
              capacity: const CapacityDay(closed: true),
              now: now),
          WindowState.closedByTeam);
      expect(
          customerWindowState(
              windowStart: 8 * 60 + 30,
              windowId: '0830',
              date: day,
              serviceMinutes: 60,
              capacity: const CapacityDay(closedWindows: {'0830'}),
              now: now),
          WindowState.closedByTeam);
    });

    test('a window that has started today is passed', () {
      expect(
          customerWindowState(
              windowStart: 9 * 60 + 30,
              windowId: '0930',
              date: DateTime(2026, 11, 4),
              serviceMinutes: 60,
              now: now),
          WindowState.passed);
    });

    test('capacity counters are read from flat held_ fields', () {
      final cap = CapacityDay.fromJson({
        'held_0830': 2,
        'caps': {'0830': 2},
        'closedWindows': ['1530'],
      });
      expect(cap.held, {'0830': 2});
      expect(cap.isFull('0830'), isTrue);
      expect(cap.closedWindows, {'1530'});
    });
  });

  group('worker availability', () {
    test('weekly off blocks the day', () {
      final p = planWorkerDay(
          worker: regular(weeklyOff: 'Thursday'),
          date: day,
          jobs: [job('A', '0930', 60, legIn: leg(10, 25))],
          returnLeg: leg(10, 25));
      expect(codes(p), contains(RouteIssueCode.weeklyOff));
    });

    test('approved leave blocks the day', () {
      final p = planWorkerDay(
          worker: regular(leave: ['2026-11-05']),
          date: day,
          jobs: [job('A', '0930', 60, legIn: leg(10, 25))],
          returnLeg: leg(10, 25));
      expect(codes(p), contains(RouteIssueCode.onLeave));
    });

    test('a reported puncture stops new assignments that day', () {
      final p = planWorkerDay(
          worker: regular(disruptions: {'2026-11-05': DisruptionType.puncture}),
          date: day,
          jobs: [job('A', '0930', 60, legIn: leg(10, 25))],
          returnLeg: leg(10, 25));
      expect(codes(p), contains(RouteIssueCode.disrupted));
    });

    test('skills are respected', () {
      final p = planWorkerDay(
          worker: regular(skills: {ServiceCategory.wash}),
          date: day,
          jobs: [
            job('A', '0930', 180,
                legIn: leg(10, 25), category: ServiceCategory.detailing)
          ],
          returnLeg: leg(10, 25));
      expect(codes(p), contains(RouteIssueCode.missingSkill));
    });
  });

  group('25 km road-leg rule', () {
    test('a valid day passes', () {
      final p = planWorkerDay(
          worker: regular(),
          date: day,
          jobs: [
            job('A', '0830', 60, legIn: leg(12, 25)),
            job('B', '1030', 120, legIn: leg(8, 20)),
          ],
          returnLeg: leg(15, 30));
      expect(p.issues, isEmpty);
      expect(p.stopFor('A')!.arriveAt, 8 * 60 + 30);
      expect(p.stopFor('B')!.arriveAt, 10 * 60 + 30);
    });

    test('a site-to-site leg over 25 km is rejected', () {
      final p = planWorkerDay(
          worker: regular(),
          date: day,
          jobs: [
            job('A', '0830', 60, legIn: leg(12, 25)),
            job('B', '1130', 60, legIn: leg(26, 50)),
          ],
          returnLeg: leg(10, 20));
      expect(p.issues.where((i) => i.code == RouteIssueCode.legTooLong),
          hasLength(1));
      expect(p.issues.first.ref, 'B');
    });

    test('the final leg home over 25 km is rejected', () {
      final p = planWorkerDay(
          worker: regular(),
          date: day,
          jobs: [job('A', '0930', 60, legIn: leg(12, 25))],
          returnLeg: leg(25.5, 45));
      expect(codes(p), contains(RouteIssueCode.legTooLong));
    });

    test('exactly 25 km is allowed', () {
      final p = planWorkerDay(
          worker: regular(),
          date: day,
          jobs: [job('A', '0930', 60, legIn: leg(25, 45))],
          returnLeg: leg(25, 45));
      expect(p.issues, isEmpty);
    });

    test('a missing leg must be entered before confirming', () {
      final p = planWorkerDay(
          worker: regular(),
          date: day,
          jobs: [job('A', '0930', 60)],
          returnLeg: null);
      expect(p.issues.where((i) => i.code == RouteIssueCode.missingLeg),
          hasLength(2));
    });
  });

  group('time rules', () {
    test('overlapping jobs are rejected', () {
      final p = planWorkerDay(
          worker: regular(),
          date: day,
          jobs: [
            job('A', '0830', 180, legIn: leg(10, 20)),
            job('B', '0930', 60, legIn: leg(5, 15)),
          ],
          returnLeg: leg(10, 20));
      expect(codes(p), contains(RouteIssueCode.overlap));
    });

    test('drive time that misses the window is rejected', () {
      final p = planWorkerDay(
          worker: regular(),
          date: day,
          jobs: [job('A', '0830', 60, legIn: leg(24, 95))],
          returnLeg: leg(24, 60));
      expect(codes(p), contains(RouteIssueCode.missedWindow));
    });

    test('5-hour detail near 6 PM: 12:30 fits, 13:30 does not', () {
      final ok = planWorkerDay(
          worker: regular(),
          date: day,
          jobs: [job('A', '1230', 300, legIn: leg(10, 20))],
          returnLeg: leg(10, 20));
      expect(ok.issues, isEmpty);
      expect(ok.stopFor('A')!.workEnd, 18 * 60); // incl. 30 min lunch

      final late = planWorkerDay(
          worker: regular(),
          date: day,
          jobs: [job('A', '1330', 300, legIn: leg(10, 20))],
          returnLeg: leg(10, 20));
      expect(codes(late), contains(RouteIssueCode.finishAfterClose));
    });

    test('lunch pauses work that runs through 1 PM', () {
      final p = planWorkerDay(
          worker: regular(),
          date: day,
          jobs: [job('A', '1130', 180, legIn: leg(10, 20))],
          returnLeg: leg(10, 20));
      expect(p.lunchAt, 13 * 60);
      expect(p.stopFor('A')!.workEnd, 11 * 60 + 30 + 180 + 30);
    });

    test('lunch is taken in a free gap when one fits', () {
      final p = planWorkerDay(
          worker: regular(),
          date: day,
          jobs: [
            job('A', '1030', 120, legIn: leg(10, 20)), // ends 12:30
            job('B', '1430', 60, legIn: leg(5, 15)),
          ],
          returnLeg: leg(10, 20));
      expect(p.lunchAt, 13 * 60);
      expect(p.stopFor('B')!.arriveAt, 14 * 60 + 30);
      expect(p.issues, isEmpty);
    });

    test('lunch can be staggered to 1:30 PM', () {
      final rules = const ScheduleRules()
          .copyWith(lunchStartOptions: const [13 * 60 + 30]);
      final p = planWorkerDay(
          worker: regular(),
          date: day,
          jobs: [job('A', '1130', 180, legIn: leg(10, 20))],
          returnLeg: leg(10, 20),
          rules: rules);
      expect(p.lunchAt, 13 * 60 + 30);
    });
  });

  group('emergency cover worker', () {
    test('one morning job returning to standby by 11 AM is allowed', () {
      final p = planWorkerDay(
          worker: emergencyWorker,
          date: day,
          jobs: [job('A', '0830', 60, legIn: leg(10, 20))],
          returnLeg: leg(10, 20));
      expect(p.issues, isEmpty);
      expect(p.endOfDay, 9 * 60 + 50);
    });

    test('returning after 11 AM is rejected', () {
      final p = planWorkerDay(
          worker: emergencyWorker,
          date: day,
          jobs: [job('A', '0830', 120, legIn: leg(10, 20))],
          returnLeg: leg(20, 40)); // back 11:10
      expect(codes(p), contains(RouteIssueCode.emergencyLateReturn));
    });

    test('a second normal job is rejected', () {
      final p = planWorkerDay(
          worker: emergencyWorker,
          date: day,
          jobs: [
            job('A', '0830', 60, legIn: leg(5, 10)),
            job('B', '0930', 60, legIn: leg(5, 10)),
          ],
          returnLeg: leg(5, 10));
      expect(codes(p), contains(RouteIssueCode.emergencyTooManyJobs));
    });

    test('beyond 25 km only with an emergency dispatch allowance', () {
      final blocked = planWorkerDay(
          worker: emergencyWorker,
          date: day,
          jobs: [job('A', '0830', 60, legIn: leg(30, 25))],
          returnLeg: leg(30, 25));
      expect(codes(blocked), contains(RouteIssueCode.legTooLong));
      final allowed = planWorkerDay(
          worker: emergencyWorker,
          date: day,
          jobs: [job('A', '0830', 60, legIn: leg(30, 25))],
          returnLeg: leg(30, 25),
          allowEmergencyLongLegs: true);
      expect(codes(allowed), isNot(contains(RouteIssueCode.legTooLong)));
    });

    test('regular workers never get the long-leg allowance', () {
      final p = planWorkerDay(
          worker: regular(),
          date: day,
          jobs: [job('A', '0830', 60, legIn: leg(30, 25))],
          returnLeg: leg(10, 20),
          allowEmergencyLongLegs: true);
      expect(codes(p), contains(RouteIssueCode.legTooLong));
    });
  });

  group('service area', () {
    // Rough square around West Delhi.
    const west = ServiceArea('West Delhi', [
      LatLng(28.55, 77.00),
      LatLng(28.55, 77.15),
      LatLng(28.70, 77.15),
      LatLng(28.70, 77.00),
    ]);

    test('covered / not covered / unverified', () {
      expect(
          checkCoverage(const LatLng(28.62, 77.08), [west]), Coverage.covered);
      expect(checkCoverage(const LatLng(28.45, 77.30), [west]),
          Coverage.notCovered);
      // GPS denied or typed address only: no pin.
      expect(checkCoverage(null, [west]), Coverage.unverified);
      // No areas configured yet: never claim "covered".
      expect(
          checkCoverage(const LatLng(28.62, 77.08), []), Coverage.unverified);
    });

    test('reads pins from coordinates and map links', () {
      expect(parsePin('28.6210, 77.0890')?.lat, 28.6210);
      expect(parsePin('https://www.google.com/maps/@28.6210,77.0890,17z')?.lng,
          77.0890);
      expect(parsePin('https://maps.google.com/?q=28.62100,77.08900')?.lat,
          28.621);
      expect(parsePin('B-12 Janakpuri'), isNull);
      expect(parsePin('99.0,77.0'), isNull);
    });

    test('serialises and reloads', () {
      final back = ServiceArea.fromJson(west.toJson())!;
      expect(back.contains(const LatLng(28.62, 77.08)), isTrue);
    });
  });
}
