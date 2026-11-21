// Small rules the screens rely on: money and dates, the bundled catalog,
// on-site durations, the address line, the login gate and time labels.
// (Scheduling and money rules are the server's: see fake_api_test.dart.)

import 'package:cleancruisers_app/core/format.dart';
import 'package:cleancruisers_app/core/pricing.dart';
import 'package:cleancruisers_app/core/router.dart';
import 'package:cleancruisers_app/core/scheduling.dart';
import 'package:cleancruisers_app/models/booking.dart';
import 'package:cleancruisers_app/models/service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rupees use Indian digit grouping', () {
    expect(rupees(349), '₹349');
    expect(rupees(1499), '₹1,499');
    expect(rupees(149999), '₹1,49,999');
  });

  test('calendar days survive clock changes', () {
    expect(addDays(DateTime(2026, 10, 31), 2), DateTime(2026, 11, 2));
    expect(addDays(DateTime(2026, 3, 28), 2), DateTime(2026, 3, 30));
  });

  group('bundled catalog (fallback until the server catalog loads)', () {
    test('every service has a price for every car size', () {
      for (final s in serviceCatalog) {
        for (final c in CarType.values) {
          expect(s.priceFor(c), greaterThan(0), reason: '${s.id} / $c');
        }
      }
    });

    test('ids are unique', () {
      final ids = serviceCatalog.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('on-site durations (owner chart)', () {
    test('safe upper estimate plus add-on time', () {
      expect(bookingDurationMinutes('wash-full', CarType.hatchback, {}), 120);
      expect(bookingDurationMinutes('wash-full', CarType.suv, {}), 150);
      expect(
          bookingDurationMinutes(
              'wash-full', CarType.hatchback, {'seat': 3, 'ac': 1}),
          120 + 45 + 25);
      expect(bookingDurationMinutes('full-package', CarType.sedan, {}), 300);
      expect(bookingDurationMinutes('dryclean-wax-exterior', CarType.suv, {}), 270);
    });

    test('every service is at most 5 hours; unknown ones plan for 5', () {
      for (final s in serviceCatalog) {
        for (final c in CarType.values) {
          expect(baseServiceMinutes(s.id, c), lessThanOrEqualTo(300),
              reason: '${s.id} / $c');
        }
      }
      expect(baseServiceMinutes('something-new', CarType.sedan), 300);
    });
  });

  group('address line', () {
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
  });

  test('request references are long enough not to be guessed', () {
    expect(RegExp(r'^CC-[A-Z2-9]{8}$').hasMatch(newBookingRef()), isTrue);
    expect(kPhoneRe.hasMatch('9876543210'), isTrue);
    expect(kPhoneRe.hasMatch('1234567890'), isFalse);
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

    test('splash is outside the gate; builds without login skip it', () {
      expect(go('/splash'), isNull);
      expect(go('/home', configured: false), isNull);
    });
  });

  test('customer time labels', () {
    expect(timeRangeLabel(570, 630), '9:30 – 10:30 AM');
    expect(timeRangeLabel(690, 750), '11:30 AM – 12:30 PM');
    expect(clockLabel(13 * 60 + 30), '1:30 PM');
    expect(clockLabel(12 * 60), '12:00 PM');
  });
}
