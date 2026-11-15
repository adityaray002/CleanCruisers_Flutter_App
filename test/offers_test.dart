import 'package:cleancruisers_app/core/pricing.dart';
import 'package:cleancruisers_app/data/offers.dart';
import 'package:cleancruisers_app/models/booking.dart';
import 'package:cleancruisers_app/models/service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('offers', () {
    const flat = Offer(code: 'F40', title: 't', flatOff: 40, minTotal: 449);
    const pct =
        Offer(code: 'P10', title: 't', percentOff: 10, onlyFor: {CarType.suv});
    const first =
        Offer(code: 'NEW', title: 't', flatOff: 100, firstBookingOnly: true);

    test('says why an offer can\'t be used', () {
      expect(flat.whyNot(total: 400, car: CarType.sedan, firstBooking: true),
          'Add ₹49 more to use it');
      expect(flat.whyNot(total: 449, car: CarType.sedan, firstBooking: true),
          isNull);
      expect(pct.whyNot(total: 999, car: CarType.sedan, firstBooking: true),
          'Only for SUV');
      expect(first.whyNot(total: 999, car: CarType.suv, firstBooking: false),
          'Only for a first booking');
    });

    test('works out the discount', () {
      expect(flat.discountFor(500), 40);
      expect(pct.discountFor(549), 54);
      expect(flat.discountFor(30), 30, reason: 'never more than the bill');
      expect(flat.headline, '₹40 OFF');
      expect(pct.headline, '10% OFF');
    });

    test('codes are matched case-insensitively', () {
      expect(offerByCode(' weekday40 ')?.code, 'WEEKDAY40');
      expect(offerByCode('NOPE'), isNull);
    });
  });

  test('a booking keeps its coupon and credit, and the amount to pay', () {
    final d = BookingDraft(
      service: serviceById('wash-full')!,
      bookingRef: 'CC-ABCDEFGH',
      car: CarType.hatchback,
      date: DateTime(2030, 1, 2),
      slotId: '0930',
      name: 'A B',
      phone: '9876543210',
      address: 'B-12, Janakpuri',
      couponCode: 'WEEKDAY40',
      couponDiscount: 40,
    );
    final r = BookingRecord.fromDraft(d, walletBalance: 100);
    expect(r.couponCode, 'WEEKDAY40');
    expect(r.creditUsed, 100);
    expect(r.payable, d.total - 40 - 100);

    final back = BookingRecord.fromJson(r.toJson());
    expect(back.couponDiscount, 40);
    expect(back.creditUsed, 100);
    expect(back.payable, r.payable);
    expect(r.toJson()['payable'], r.payable);
  });
}
