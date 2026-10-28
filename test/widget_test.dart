import 'package:cleancruisers_app/core/format.dart';
import 'package:cleancruisers_app/core/pricing.dart';
import 'package:cleancruisers_app/models/booking.dart';
import 'package:cleancruisers_app/models/service.dart';
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

    test('ids are unique', () {
      final ids = serviceCatalog.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('time slots', () {
    final evening = timeSlots.last;
    final morning = timeSlots.first;

    test('future days are always available', () {
      final now = DateTime(2026, 9, 29, 19);
      expect(morning.isAvailable(DateTime(2026, 9, 30), now: now), isTrue);
    });

    test('a slot closes 2 hours before it ends', () {
      final day = DateTime(2026, 9, 29);
      expect(morning.isAvailable(day, now: DateTime(2026, 9, 29, 8, 30)), isTrue);
      expect(morning.isAvailable(day, now: DateTime(2026, 9, 29, 9, 0)), isFalse);
      expect(evening.isAvailable(day, now: DateTime(2026, 9, 29, 17, 59)), isTrue);
      expect(evening.isAvailable(day, now: DateTime(2026, 9, 29, 18, 0)), isFalse);
    });

    test('past days are unavailable', () {
      expect(morning.isAvailable(DateTime(2026, 9, 28), now: DateTime(2026, 9, 29, 7)), isFalse);
    });
  });

  group('booking draft', () {
    final wash = serviceById('wash-full')!;

    test('total = service price for car + extras', () {
      final d = BookingDraft(service: wash, car: CarType.sedan, extras: const {'seat': 2, 'roof': 1});
      expect(d.servicePrice, 499);
      expect(d.extrasTotal, 2 * 100 + 200);
      expect(d.total, 899);
    });

    test('ignores extras that do not belong to the service', () {
      final monthly = serviceById('monthly-3')!;
      final d = BookingDraft(service: monthly, car: CarType.suv, extras: const {'seat': 3});
      expect(d.total, completeCarePrice[CarType.suv]);
    });

    test('validates contact details', () {
      var d = BookingDraft(service: wash, name: 'A', phone: '12345', address: 'x');
      expect(d.detailsDone, isFalse);
      d = d.copyWith(name: 'Rahul', phone: '9876543210', address: 'B-12, Janakpuri');
      expect(d.detailsDone, isTrue);
    });
  });

  group('booking record', () {
    BookingRecord make() => BookingRecord.fromDraft(
          BookingDraft(
            service: serviceById('3m-wax-exterior')!,
            car: CarType.suv,
            carModel: 'Creta',
            extras: const {'air-freshener': 1},
            date: DateTime(2026, 10, 2),
            slotId: 'morning',
            name: 'Rahul',
            phone: '9876543210',
            address: 'B-12, Janakpuri',
            pin: '28.62100,77.08900',
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
    });

    test('WhatsApp message carries the essentials', () {
      final r = make();
      final msg = r.whatsAppMessage();
      expect(msg, contains(r.ref));
      expect(msg, contains('3M Wax + Foam Wash'));
      expect(msg, contains('Creta · SUV'));
      expect(msg, contains('+91 9876543210'));
      expect(msg, contains('maps.google.com/?q=28.62100,77.08900'));
      expect(msg, contains(rupees(r.total)));
    });

    test('refs look like CC-XXXXX', () {
      expect(RegExp(r'^CC-[A-Z2-9]{5}$').hasMatch(newBookingRef()), isTrue);
    });
  });
}
