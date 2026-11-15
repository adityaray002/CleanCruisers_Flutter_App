import 'package:cleancruisers_app/core/format.dart';
import 'package:cleancruisers_app/core/pricing.dart';
import 'package:cleancruisers_app/core/router.dart';
import 'package:cleancruisers_app/core/scheduling.dart';
import 'package:cleancruisers_app/data/booking_cloud.dart';
import 'package:cleancruisers_app/models/booking.dart';
import 'package:cleancruisers_app/models/service.dart';
import 'package:cleancruisers_app/providers/app_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('rupees', () {
    test('uses Indian digit grouping', () {
      expect(rupees(349), '₹349');
      expect(rupees(1499), '₹1,499');
      expect(rupees(149999), '₹1,49,999');
    });
  });

  group('catalog', () {
    test('every service has a price for every car size', () {
      for (final s in serviceCatalog) {
        for (final c in CarType.values) {
          expect(s.priceFor(c), greaterThan(0), reason: '${s.id} / $c');
        }
      }
    });

    test('every service has an owner-chart duration', () {
      for (final s in serviceCatalog) {
        for (final c in CarType.values) {
          expect(baseServiceMinutes(s.id, c), lessThan(300 + 1),
              reason: '${s.id} / $c');
        }
      }
    });

    test('ids are unique', () {
      final ids = serviceCatalog.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('time slots', () {
    final first = timeSlots.first;
    final last = timeSlots.last;

    test('one-hour windows start at 8:30 AM', () {
      expect(first.startMinute, 8 * 60 + 30);
      for (final s in timeSlots) {
        expect(s.endMinute - s.startMinute, 60);
      }
    });

    test('future days are available', () {
      final now = DateTime(2026, 9, 29, 19);
      expect(first.isAvailable(DateTime(2026, 9, 30), now: now), isTrue);
    });

    test('a window closes once it has started', () {
      final day = DateTime(2026, 9, 29);
      expect(first.isAvailable(day, now: DateTime(2026, 9, 29, 8, 29)), isTrue);
      expect(
          first.isAvailable(day, now: DateTime(2026, 9, 29, 8, 30)), isFalse);
      expect(last.isAvailable(day, now: DateTime(2026, 9, 29, 15, 0)), isTrue);
    });

    test('past days are unavailable', () {
      expect(
          first.isAvailable(DateTime(2026, 9, 28),
              now: DateTime(2026, 9, 29, 7)),
          isFalse);
    });
  });

  group('booking draft', () {
    final wash = serviceById('wash-full')!;
    BookingDraft complete() => BookingDraft(
          service: wash,
          name: 'Rahul',
          phone: '9876543210',
          address: 'B-12, Janakpuri',
        );

    test('total = service price for car + extras', () {
      final d = BookingDraft(
          service: wash,
          car: CarType.sedan,
          extras: const {'seat': 2, 'roof': 1});
      expect(d.servicePrice, 499);
      expect(d.extrasTotal, 2 * 100 + 200);
      expect(d.total, 899);
      expect(d.serviceDurationMinutes, 120 + 30 + 60);
    });

    test('ignores extras that do not belong to the service', () {
      final monthly = serviceById('monthly-3')!;
      final d = BookingDraft(
          service: monthly, car: CarType.suv, extras: const {'seat': 3});
      expect(d.total, completeCarePrice[CarType.suv]);
      expect(d.serviceDurationMinutes, 150);
    });

    test('details need a valid contact and address', () {
      final d =
          BookingDraft(service: wash, name: 'A', phone: '12345', address: 'x');
      expect(d.detailsDone, isFalse);
      expect(complete().detailsDone, isTrue);
    });

    test('an address outside the service area blocks the request', () {
      expect(complete().copyWith(coverage: Coverage.notCovered).detailsDone,
          isFalse);
      expect(complete().copyWith(coverage: Coverage.unverified).detailsDone,
          isTrue);
    });

    test('booking for someone else needs their name, not their phone', () {
      var d = complete().copyWith(bookingFor: BookingFor.someoneElse);
      expect(d.detailsDone, isFalse);
      d = d.copyWith(recipientName: 'Sunita');
      expect(d.detailsDone, isTrue);
      // Updates to them need their number.
      expect(d.copyWith(notifyRecipient: true).detailsDone, isFalse);
      expect(
          d
              .copyWith(notifyRecipient: true, recipientPhone: '9812345678')
              .detailsDone,
          isTrue);
    });

    test('someone else\'s booking never uses the booker\'s GPS pin', () {
      final d = complete().copyWith(
          bookingFor: BookingFor.someoneElse,
          recipientName: 'Sunita',
          pin: '28.62100,77.08900',
          pinSource: PinSource.gps);
      expect(d.pinValid, isFalse);
      expect(d.detailsDone, isFalse);

      // A pin they shared (pasted) is fine.
      final shared = d.copyWith(pinSource: PinSource.pasted);
      expect(shared.detailsDone, isTrue);
    });

    test('switching to someone else drops a GPS pin', () {
      final n = DraftNotifier(complete());
      n.setPin('28.62100,77.08900', source: PinSource.gps);
      expect(n.state.pin, isNotNull);
      n.setBookingFor(BookingFor.someoneElse, const []);
      expect(n.state.pin, isNull);
      expect(n.state.coverage, Coverage.unverified);
    });

    test('a 5-hour service cannot be scheduled too late', () {
      final d = BookingDraft(
        service: serviceById('full-package')!,
        car: CarType.sedan,
        date: DateTime.now().add(const Duration(days: 2)),
        slotId: '1330',
      );
      expect(d.scheduleDone, isFalse);
      expect(d.copyWith(slotId: '1230').scheduleDone, isTrue);
    });
  });

  group('structured address', () {
    test('needs house and area; adds building, landmark and parking', () {
      expect(composeAddress({'flat': 'B-12'}), '');
      expect(composeAddress({'area': 'Janakpuri'}), '');
      expect(
          composeAddress({
            'flat': 'B-12',
            'building': 'Pocket 3',
            'area': 'Janakpuri',
            'landmark': 'near metro',
            'parking': 'Basement parking',
          }),
          'B-12, Pocket 3, Janakpuri, near metro · Parking: Basement parking');
    });

    test('parking note can be swapped or removed', () {
      const a = 'B-12, Janakpuri · Parking: Open parking';
      expect(parkingOf(a), 'Open parking');
      expect(withParking(a, 'Basement parking'),
          'B-12, Janakpuri · Parking: Basement parking');
      expect(withParking(a, null), 'B-12, Janakpuri');
    });

    test('saved address is used for me, never for someone else', () {
      final n = DraftNotifier(BookingDraft(
        service: serviceById('wash-full')!,
        address: 'B-12, Janakpuri',
        savedAddress: 'B-12, Janakpuri',
        savedPin: '28.62100,77.08900',
        pin: '28.62100,77.08900',
        pinSource: PinSource.pasted,
        usingSaved: true,
      ));
      n.setBookingFor(BookingFor.someoneElse, const []);
      expect(n.state.usingSaved, isFalse);
      expect(n.state.address, '');
      expect(n.state.pin, isNull);
      n.setBookingFor(BookingFor.me, const []);
      expect(n.state.usingSaved, isTrue);
      expect(n.state.address, 'B-12, Janakpuri');
      expect(n.state.pin, '28.62100,77.08900');
    });

    test('typing a new address replaces the saved one', () {
      final n = DraftNotifier(BookingDraft(
          service: serviceById('wash-full')!,
          address: 'B-12, Janakpuri',
          savedAddress: 'B-12, Janakpuri',
          usingSaved: true));
      n.useNewAddress();
      n.setAddressPart('flat', '44');
      n.setAddressPart('area', 'Dwarka Sector 7');
      expect(n.state.address, '44, Dwarka Sector 7');
      n.setAddressPart('parking', 'Open parking');
      expect(n.state.address, '44, Dwarka Sector 7 · Parking: Open parking');
    });
  });

  group('booking record', () {
    BookingRecord make({String ref = 'CC-ABCDEFGH'}) => BookingRecord.fromDraft(
          BookingDraft(
            service: serviceById('3m-wax-exterior')!,
            bookingRef: ref,
            car: CarType.suv,
            carModel: 'Creta',
            extras: const {'air-freshener': 1},
            date: DateTime(2026, 10, 2),
            slotId: '0930',
            bookingFor: BookingFor.someoneElse,
            name: 'Rahul',
            phone: '9876543210',
            recipientName: 'Sunita',
            recipientPhone: '9812345678',
            notifyRecipient: true,
            address: 'B-12, Janakpuri',
            pin: '28.62100,77.08900',
            pinSource: PinSource.pasted,
            coverage: Coverage.covered,
          ),
          now: DateTime(2026, 9, 29, 10),
        );

    test('survives a JSON round trip', () {
      final a = make();
      final b = BookingRecord.fromJson(a.toJson());
      expect(b.ref, a.ref);
      expect(b.total, a.total);
      expect(b.extras, a.extras);
      expect(b.date, a.date);
      expect(b.pin, a.pin);
      expect(b.recipientName, 'Sunita');
      expect(b.notifyRecipient, isTrue);
      expect(b.coverage, Coverage.covered);
      expect(b.history.single.status, BookingStatus.requested);
      expect(b.durationNeedsConfirmation, isTrue);
      expect(b.catalogVersion, kCatalogVersion);
    });

    test('a retry reuses the draft reference (no duplicate booking)', () {
      expect(make().ref, make().ref);
    });

    test('customer payload cannot carry operations fields', () {
      final j = make().toCustomerJson();
      for (final k in [
        'workerId',
        'legIn',
        'plannedArrivalMinute',
        'amountCollected',
        'customerNote',
      ]) {
        expect(j.containsKey(k), isFalse, reason: k);
      }
      expect(j['dateKey'], '2026-10-02');
      expect(j['capacityHeld'], isTrue);
      expect(j['consentAt'], isNotNull);
    });

    test('arrival time is only shown once confirmed', () {
      final requested = BookingRecord.fromJson(
          {...make().toJson(), 'plannedArrivalMinute': 600, 'workerId': 'w1'});
      expect(requested.confirmedArrivalLabel, isNull);
      final confirmed = BookingRecord.fromJson({
        ...make().toJson(),
        'plannedArrivalMinute': 600,
        'workerId': 'w1',
        'status': 'confirmed',
      });
      expect(confirmed.confirmedArrivalLabel, '10:00 AM');
    });

    test('reads statuses saved by the earlier version', () {
      expect(parseStatus('assigned'), BookingStatus.confirmed);
      expect(parseStatus('inProgress'), BookingStatus.inService);
      expect(parseStatus('weatherHold'), BookingStatus.rescheduleNeeded);
      expect(parseStatus('nonsense'), BookingStatus.requested);
    });

    test('reschedule-needed and final states release capacity', () {
      expect(BookingStatus.requested.holdsCapacity, isTrue);
      expect(BookingStatus.confirmed.holdsCapacity, isTrue);
      expect(BookingStatus.rescheduleNeeded.holdsCapacity, isFalse);
      expect(BookingStatus.cancelled.holdsCapacity, isFalse);
      expect(BookingStatus.unableToServe.holdsCapacity, isFalse);
    });

    test('refs are long enough not to be guessed', () {
      expect(RegExp(r'^CC-[A-Z2-9]{8}$').hasMatch(newBookingRef()), isTrue);
    });
  });

  group('login gate', () {
    String? go(String path,
            {bool configured = true,
            bool signedIn = false,
            bool hasName = false,
            bool hasSetup = true}) =>
        authRedirect(path,
            configured: configured,
            signedIn: signedIn,
            hasName: hasName,
            hasSetup: hasSetup);

    test('customers must log in with OTP before using the app', () {
      expect(go('/home'), '/login');
      expect(go('/book/wash-full'), '/login');
      expect(go('/login'), isNull);
      expect(go('/login/otp'), isNull);
      expect(go('/login/name'), '/login');
    });

    test('first login asks for a name, then opens the app', () {
      expect(go('/home', signedIn: true), '/login/name');
      expect(go('/login/name', signedIn: true), isNull);
      expect(go('/login', signedIn: true, hasName: true), '/home');
      expect(go('/home', signedIn: true, hasName: true), isNull);
    });

    test('car and address are asked once, before the first booking', () {
      String? noSetup(String path) =>
          go(path, signedIn: true, hasName: true, hasSetup: false);
      expect(noSetup('/home'), '/login/address');
      expect(noSetup('/book/wash-full'), '/login/address');
      expect(noSetup('/login/address'), isNull);
      expect(go('/login/address'), '/login');
      expect(go('/login/address', signedIn: true, hasName: true), '/home');
    });

    test('splash and the staff desk are outside the customer gate', () {
      expect(go('/splash'), isNull);
      expect(go('/ops'), isNull);
      expect(go('/ops/login'), isNull);
    });

    test('builds without Firebase skip the gate', () {
      expect(go('/home', configured: false), isNull);
    });
  });

  test('calendar days survive clock changes', () {
    expect(addDays(DateTime(2026, 10, 31), 2), DateTime(2026, 11, 2));
    expect(addDays(DateTime(2026, 3, 28), 2), DateTime(2026, 3, 30));
  });

  group('customer time labels', () {
    test('slots read as plain time ranges', () {
      expect(slotById('0930')!.short, '9:30 – 10:30 AM');
      expect(slotById('1130')!.short, '11:30 AM – 12:30 PM');
      expect(slotById('1230')!.short, '12:30 – 1:30 PM');
    });
  });

  group('without Firebase configured', () {
    test('submitting fails closed with a clear message', () async {
      final cloud = BookingCloud();
      expect(cloud.configured, isFalse);
      await expectLater(
        cloud.submit(BookingRecord.fromDraft(BookingDraft(
          service: serviceById('wash-full')!,
          car: CarType.sedan,
          date: DateTime.now().add(const Duration(days: 1)),
          slotId: '0930',
          name: 'Rahul',
          phone: '9876543210',
          address: 'B-12, Janakpuri',
        ))),
        throwsA(isA<BookingCloudException>()),
      );
    });

    test('no service areas means coverage stays unverified', () async {
      expect(await BookingCloud().serviceAreas(), isEmpty);
    });
  });
}
