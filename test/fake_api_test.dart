// Business rules of the server (docs/API_CONTRACT.md and
// docs/SHINESTAFF_ADMIN_PARITY.md sections H, I, J), checked against the
// in-app fake. ShineStaff must pass the same cases.
//
// Clock: Monday 23 Nov 2026, 10:00. "Tue" is the next day; worker 1 is off on
// Tuesdays, so 4 workers work that day and only worker 4 does detailing.

import 'dart:convert';
import 'dart:math';

import 'package:cleancruisers_app/core/pricing.dart';
import 'package:cleancruisers_app/data/api/fake/fake_api.dart';
import 'package:cleancruisers_app/data/api/models.dart';
import 'package:flutter_test/flutter_test.dart';

final mon = DateTime(2026, 11, 23);
final tue = DateTime(2026, 11, 24);
final wed = DateTime(2026, 11, 25);
final sat = DateTime(2026, 11, 28);
int at(int h, [int m = 0]) => h * 60 + m;

const hatch = ApiCar(CarType.hatchback, 'Swift');
const sedan = ApiCar(CarType.sedan, 'City');

late DateTime now;
late FakeApi api;

Future<void> expectCode(Future<Object?> f, String code) async {
  try {
    await f;
    fail('expected $code');
  } on ApiException catch (e) {
    expect(e.code, code, reason: e.message);
  }
}

/// Signs in [phone] and gives it a covered address (returns the address id).
Future<String> customer(String phone,
    {String flat = 'B-12', String building = 'Green Park', String pincode = '110058'}) async {
  api.signIn(phone);
  final a = await api.addAddress(ApiAddress(
      flat: flat, building: building, area: 'Pocket C, Janakpuri', pincode: pincode));
  return a.id!;
}

BookingRequest req(String addressId,
        {String service = 'wash-full',
        ApiCar car = hatch,
        DateTime? day,
        int start = 9 * 60,
        String? coupon,
        bool credit = false,
        String? clientRef,
        String? planId,
        Map<String, int> extras = const {}}) =>
    BookingRequest(
      clientRef: clientRef,
      serviceId: service,
      car: car,
      extras: extras,
      slot: SlotPick(day ?? tue, start),
      addressId: addressId,
      couponCode: coupon,
      useCredit: credit,
      planId: planId,
    );

/// Books, confirms, starts and completes a job.
Future<Booking> completed(BookingRequest r) async {
  final b = await api.createBooking(r);
  api.adminConfirm(b.ref);
  api.adminOnTheWay(b.ref);
  api.adminStart(b.ref);
  return api.adminComplete(b.ref, method: 'upi');
}

void main() {
  setUp(() {
    now = DateTime(2026, 11, 23, 10);
    api = FakeApi(clock: () => now, random: Random(7));
  });

  group('contract shapes', () {
    test('booking, catalog and errors survive a JSON round trip', () async {
      final a = await customer('9876543210');
      final b = await api.createBooking(req(a));
      final again = Booking.fromJson(jsonDecode(jsonEncode(b.toJson())) as Map<String, dynamic>);
      expect(jsonEncode(again.toJson()), jsonEncode(b.toJson()));

      final c = await api.catalog();
      expect(jsonEncode(Catalog.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>).toJson()),
          jsonEncode(c.toJson()));

      const e = ApiException(ApiCode.slotTaken, 'Taken', {'alternatives': []});
      expect(ApiException.fromJson(e.toJson()).code, ApiCode.slotTaken);
    });

    test('calls that need a login fail without one', () async {
      await expectCode(api.me(), ApiCode.authRequired);
    });

    test('GST lines add up to the total', () {
      final g = GstSplit.ofInclusive(449);
      expect(g.taxable + g.cgst + g.sgst, 449);
      expect((g.taxable, g.cgst, g.sgst), (381, 34, 34));
    });
  });

  group('availability (H3, H5, working hours)', () {
    test('start times run 8:30 → latest start that finishes by 6 PM', () async {
      final a = await api.availability(serviceId: 'wash-full', car: hatch, date: tue);
      expect(a.durationMinutes, 120);
      expect(a.slots.first.start, at(8, 30));
      expect(a.slots.last.start, at(16));
      expect(a.slots.every((s) => s.open), isTrue);
    });

    test('today, nothing sooner than 2 hours from now', () async {
      final a = await api.availability(serviceId: 'wash-full', car: hatch, date: mon);
      expect(a.slots.where((s) => s.open).first.start, at(12));
    });

    test('capacity is counted in worker hours, not slots', () async {
      for (final p in ['9000000001', '9000000002', '9000000003', '9000000004']) {
        await api.createBooking(req(await customer(p)));
      }
      final a = await api.availability(serviceId: 'wash-full', car: hatch, date: tue);
      bool open(int m) => a.slots.firstWhere((s) => s.start == m).open;
      expect(open(at(8, 30)), isFalse); // overlaps the 9:00 jobs
      expect(open(at(9)), isFalse);
      expect(open(at(11, 30)), isFalse); // travel + buffer still overlap
      expect(open(at(12)), isTrue);
    });

    test('SofaShine jobs use the shared workers too', () async {
      api.adminAddSofaShineJob('w4', tue, at(8, 30), 270);
      api.adminAddSofaShineJob('w5', tue, at(8, 30), 270);
      await api.createBooking(req(await customer('9000000001')));
      await api.createBooking(req(await customer('9000000002')));
      await expectCode(api.createBooking(req(await customer('9000000003'))), ApiCode.slotTaken);
    });

    test('detailing needs a detailing worker', () async {
      final a = await customer('9000000001');
      await api.createBooking(req(a, service: 'full-package', start: at(8, 30)));
      final det = await api.availability(serviceId: 'full-package', car: hatch, date: tue);
      final wash = await api.availability(serviceId: 'wash-full', car: hatch, date: tue);
      expect(det.slots.firstWhere((s) => s.start == at(8, 30)).open, isFalse);
      expect(wash.slots.firstWhere((s) => s.start == at(8, 30)).open, isTrue);
    });

    test('a long job over lunch pauses for it and is ready 30 min later', () async {
      final a = await api.availability(serviceId: 'full-package', car: hatch, date: tue);
      final ten = a.slots.firstWhere((s) => s.start == at(10));
      expect(ten.open, isTrue);
      expect(ten.end, at(15, 30)); // 5 h + 30 min lunch
    });

    test('a closed day offers nothing and says why', () async {
      api.adminCloseDay(tue, 'Closed for Diwali');
      final a = await api.availability(serviceId: 'wash-full', car: hatch, date: tue);
      expect(a.slots, isEmpty);
      expect(a.closedReason, 'Closed for Diwali');
    });
  });

  group('sending a request', () {
    test('a request holds its time for 2 working hours, then the admin is alerted', () async {
      for (final p in ['9000000001', '9000000002', '9000000003', '9000000004']) {
        await api.createBooking(req(await customer(p)));
      }
      Future<bool> nineOpen() async =>
          (await api.availability(serviceId: 'wash-full', car: hatch, date: tue))
              .slots
              .firstWhere((s) => s.start == at(9))
              .open;
      expect(await nineOpen(), isFalse);
      now = DateTime(2026, 11, 23, 12, 1);
      expect(await nineOpen(), isTrue);
      expect(api.adminOverdue(), hasLength(4));
    });

    test('at most 2 requests waiting per phone (H6)', () async {
      final a = await customer('9876543210');
      await api.createBooking(req(a, start: at(9)));
      await api.createBooking(req(a, start: at(13)));
      await expectCode(api.createBooking(req(a, day: wed)), ApiCode.pendingLimit);
    });

    test('night request: confirmed the next morning (H1)', () async {
      now = DateTime(2026, 11, 23, 22, 10);
      final a = await customer('9876543210');
      final b = await api.createBooking(req(a, day: wed));
      expect(b.status, BookingState.requested);
      expect(b.confirmBy, DateTime(2026, 11, 24, 10));
      expect(b.statusNote, contains('tomorrow'));
      expect(b.statusNote, contains('WhatsApp'));
    });

    test('the same clientRef never creates a second booking', () async {
      final a = await customer('9876543210');
      final b1 = await api.createBooking(req(a, clientRef: 'CC-AAAA'));
      final b2 = await api.createBooking(req(a, clientRef: 'CC-AAAA'));
      expect(b2.ref, b1.ref);
      expect(await api.bookings(upcoming: true), hasLength(1));
    });

    test('a time off the grid or too soon is refused with alternatives', () async {
      final a = await customer('9876543210');
      try {
        await api.createBooking(req(a, start: at(9, 10)));
        fail('expected SLOT_TAKEN');
      } on ApiException catch (e) {
        expect(e.code, ApiCode.slotTaken);
        expect(e.details['alternatives'], isNotEmpty);
      }
      await expectCode(api.createBooking(req(a, day: mon, start: at(10, 30))), ApiCode.slotTaken);
    });

    test('a bill different from the quote is refused', () async {
      final a = await customer('9876543210');
      final r = req(a);
      final q = await api.quote(r);
      await expectCode(
          api.createBooking(BookingRequest(
              serviceId: r.serviceId, car: r.car, slot: r.slot, addressId: a, expectedTotal: q.bill.total - 1)),
          ApiCode.priceChanged);
    });

    test('an address outside the service area is refused', () async {
      final a = await customer('9876543210', pincode: '400001');
      await expectCode(api.createBooking(req(a)), ApiCode.notCovered);
    });

    test('a booking belongs to its phone only', () async {
      final b = await api.createBooking(req(await customer('9000000001')));
      await customer('9000000002');
      await expectCode(api.booking(b.ref), ApiCode.notYours);
    });
  });

  group('money rules (J1–J4)', () {
    test('discounts never push a job below ₹60 contribution (J1)', () async {
      final a = await customer('9876543210');
      api.adminGoodwill('9876543210', 500, 'Test');
      final wash = await api.quote(req(a, credit: true));
      expect(wash.bill.discountOf('credit'), 63);
      expect(wash.bill.discountCapNote, 'Up to ₹63 off on this booking');
      expect(wash.bill.total, 449 - 63);

      final bucket = await api.quote(req(a, service: 'wash-bucket', credit: true));
      expect(bucket.bill.discountOf('credit'), 0);
      expect(bucket.bill.total, 249);
    });

    test('coupons follow their rules (J2)', () async {
      final a = await customer('9876543210');
      final low = await api.quote(req(a, coupon: 'FIRST100'));
      expect(low.couponApplied, isFalse);
      expect(low.couponReason, 'Add ₹200 more to use it');

      final wax = await api.quote(req(a, service: '3m-wax-exterior', coupon: 'FIRST100'));
      expect(wax.couponApplied, isTrue);
      expect(wax.bill.total, 549);

      final b = await api.createBooking(req(a, service: '3m-wax-exterior', coupon: 'FIRST100'));
      final again = await api.quote(req(a, service: '3m-wax-exterior', coupon: 'FIRST100', day: wed));
      expect(again.couponReason, 'You have already used this offer');

      api.adminConfirm(b.ref);
      final first50 = await api.quote(req(a, coupon: 'FIRST50', day: wed));
      expect(first50.couponReason, 'Only for a first booking');

      final weekend = await api.quote(req(a, coupon: 'WEEKDAY40', day: sat));
      expect(weekend.couponReason, 'Only for Monday to Friday');

      final suv = await api.quote(req(a, coupon: 'SUVSPECIAL'));
      expect(suv.couponReason, 'Only for SUV');

      await expectCode(api.createBooking(req(a, coupon: 'NOPE', day: wed)), ApiCode.couponInvalid);
    });

    test('second car at the same home on the same day: ₹75 off (J3)', () async {
      final a = await customer('9876543210');
      await api.createBooking(req(a, car: hatch));
      final second = await api.createBooking(req(a, car: sedan));
      expect(second.bill.discounts.single.name, 'Second car, same visit');
      expect(second.bill.discountOf('auto'), 75);
    });

    test('same building, same day: ₹50 off both bookings (J3)', () async {
      final first = await api.createBooking(req(await customer('9000000001', flat: 'A-1')));
      final b2 = await api.createBooking(req(await customer('9000000002', flat: 'C-4')));
      expect(b2.bill.discountOf('auto'), 50);
      api.signIn('9000000001');
      expect((await api.booking(first.ref)).bill.discountOf('auto'), 50);
    });

    test('5% cashback on completion, expiring after 60 days (J4)', () async {
      final a = await customer('9876543210');
      await completed(req(a));
      final w = await api.wallet();
      expect(w.balance, 22);
      expect(w.entries.first.kind, 'cashback');
      expect(w.entries.first.expiresOn, DateTime(2027, 1, 22)); // 23 Nov + 60 days
      now = DateTime(2027, 1, 24, 10);
      final later = await api.wallet();
      expect(later.balance, 0);
      expect(later.entries.first.kind, 'expired');
    });

    test('credit used on a cancelled booking comes back', () async {
      final a = await customer('9876543210');
      api.adminGoodwill('9876543210', 500, 'Test');
      final b = await api.createBooking(req(a, credit: true));
      expect((await api.wallet()).balance, 437);
      await api.cancel(b.ref);
      expect((await api.wallet()).balance, 500);
    });

    test('referral: both get ₹100 after the friend’s first completed booking', () async {
      await customer('9000000001');
      final code = (await api.me()).referralCode;
      final b = await customer('9000000002');
      await api.updateMe(referralCode: code);
      await completed(req(b));
      expect((await api.wallet()).balance, 22 + 100);
      await expectCode(api.updateMe(referralCode: code), ApiCode.invalidInput);
      api.signIn('9000000001');
      expect((await api.wallet()).balance, 100);
      expect((await api.referral()).rewarded, 1);
    });
  });

  group('after booking (contract section 6)', () {
    test('cancelling a request is instant and free', () async {
      final b = await api.createBooking(req(await customer('9876543210')));
      expect((await api.cancel(b.ref, reason: 'Plans changed')).status, BookingState.cancelled);
    });

    test('cancelling a confirmed booking is a request; free more than 2 h before', () async {
      final b = await api.createBooking(req(await customer('9876543210')));
      api.adminConfirm(b.ref);
      final asked = await api.cancel(b.ref);
      expect(asked.status, BookingState.confirmed);
      expect(asked.openRequest?.kind, 'cancel');
      expect(asked.openRequest?.fee, 0);
      expect(asked.canCancel, isFalse);
      expect(api.adminApproveRequest(b.ref).status, BookingState.cancelled);
      expect((await api.me()).lateCancelFeeDue, 0);
    });

    test('late cancel adds ₹100 to the next bill, cleared once paid', () async {
      final a = await customer('9876543210');
      final b = await api.createBooking(req(a, day: mon, start: at(12, 30)));
      api.adminConfirm(b.ref);
      now = DateTime(2026, 11, 23, 11);
      expect((await api.cancel(b.ref)).openRequest?.fee, 100);
      api.adminApproveRequest(b.ref);
      final next = await completed(req(a, day: wed));
      expect(next.bill.lateCancelFee, 100);
      expect(next.bill.total, 549);
      expect((await api.me()).lateCancelFeeDue, 0);
    });

    test('customer not available: first time free, then ₹100 (H9)', () async {
      final a = await customer('9876543210');
      final b1 = await api.createBooking(req(a));
      api.adminConfirm(b1.ref);
      expect(api.adminMissed(b1.ref).status, BookingState.missed);
      expect((await api.me()).lateCancelFeeDue, 0);
      final b2 = await api.createBooking(req(a, day: wed));
      api.adminConfirm(b2.ref);
      api.adminMissed(b2.ref);
      expect((await api.me()).lateCancelFeeDue, 100);
    });

    test('team offers a time: accept moves and confirms; it expires', () async {
      final a = await customer('9876543210');
      final b = await api.createBooking(req(a));
      final offered = api.adminOfferTime(b.ref, SlotPick(tue, at(13)));
      expect(offered.status, BookingState.rescheduleNeeded);
      final accepted = await api.acceptOffer(b.ref);
      expect(accepted.status, BookingState.confirmed);
      expect(accepted.slot.start, at(13));

      final b2 = await api.createBooking(req(a, day: wed));
      api.adminOfferTime(b2.ref, SlotPick(wed, at(14)));
      now = now.add(const Duration(hours: 13));
      await expectCode(api.acceptOffer(b2.ref), ApiCode.offerExpired);
      expect((await api.declineOffer(b2.ref)).offer, isNull);
    });

    test('rain: ₹50 credit, and "covered parking" keeps the wash', () async {
      final b = await api.createBooking(req(await customer('9876543210')));
      api.adminConfirm(b.ref);
      final r = api.adminRain(b.ref, SlotPick(wed, at(9)));
      expect(r.offer?.reason, 'rain');
      expect((await api.wallet()).balance, 50);
      expect((await api.keepAsPlanned(b.ref)).openRequest?.kind, 'keepAsPlanned');
      final kept = api.adminApproveRequest(b.ref);
      expect(kept.status, BookingState.confirmed);
      expect(kept.slot.date, tue);
    });

    test('wrong car size on site needs the customer to accept (H11)', () async {
      final a = await customer('9876543210');
      final b = await api.createBooking(req(a));
      api.adminConfirm(b.ref);
      final asked = api.adminCarSize(b.ref, CarType.suv)!;
      expect(asked.pendingChange!.newDurationMinutes, 150);
      expect(asked.pendingChange!.newBill.subtotal, 549);
      expect(() => api.adminStart(b.ref), throwsStateError);
      final ok = await api.acceptChange(b.ref, asked.pendingChange!.id);
      expect(ok.car.type, CarType.suv);
      expect(ok.bill.subtotal, 549);

      final late = await api.createBooking(req(a, day: wed, start: at(16)));
      api.adminConfirm(late.ref);
      expect(api.adminCarSize(late.ref, CarType.suv), isNull); // 4 PM + 2.5 h is past 6 PM
    });

    test('rejecting the new car size cancels with no fee', () async {
      final b = await api.createBooking(req(await customer('9876543210')));
      api.adminConfirm(b.ref);
      final c = api.adminCarSize(b.ref, CarType.suv)!.pendingChange!;
      expect((await api.rejectChange(b.ref, c.id)).status, BookingState.cancelled);
      expect((await api.me()).lateCancelFeeDue, 0);
    });

    test('a worker who drops out is replaced; the customer still sees Confirmed (H8)', () async {
      final b = await api.createBooking(req(await customer('9876543210')));
      api.adminConfirm(b.ref);
      final first = api.adminWorkerOf(b.ref)!;
      expect(api.adminWorkerUnavailable(first, tue), [b.ref]);
      expect((await api.booking(b.ref)).status, BookingState.confirmed);
      api.adminConfirm(b.ref);
      expect(api.adminWorkerOf(b.ref), isNot(first));
    });

    test('confirm and completion go out on WhatsApp; invoice after completion (H2)', () async {
      final a = await customer('9876543210');
      final b = await api.createBooking(req(a));
      await expectCode(api.invoice(b.ref), ApiCode.notFound);
      api.adminConfirm(b.ref);
      expect(api.outbox.last.template, 'booking_confirmed');
      expect(api.outbox.last.phone, '9876543210');
      api.adminOnTheWay(b.ref);
      api.adminStart(b.ref);
      final done = api.adminComplete(b.ref);
      expect(api.outbox.last.template, 'invoice');
      expect(done.invoice?.number, 'CC/26-27/000001');
      expect(done.payment.status, 'paid');
    });

    test('an address used by an upcoming booking can’t be deleted', () async {
      final a = await customer('9876543210');
      await api.createBooking(req(a));
      await expectCode(api.deleteAddress(a), ApiCode.changeNotAllowed);
    });
  });

  group('monthly plans (J5)', () {
    test('first visit carries the plan price; later visits are ₹0', () async {
      final a = await customer('9876543210');
      final bought = await api.buyPlan(
          clientRef: 'PL-1', planId: 'monthly-3', car: hatch, addressId: a, firstVisit: SlotPick(tue, at(9)));
      expect(bought.booking.bill.total, 1399);
      expect(bought.plan.status, PlanState.pendingFirstVisit);

      api.adminConfirm(bought.booking.ref);
      api.adminOnTheWay(bought.booking.ref);
      api.adminStart(bought.booking.ref);
      api.adminComplete(bought.booking.ref);
      final plan = (await api.plans()).single;
      expect(plan.status, PlanState.active);
      expect(plan.endsOn, DateTime(2026, 12, 23));

      final v2 = await api.createBooking(req(a, day: wed, planId: plan.id));
      expect(v2.bill.total, 0);
      expect(v2.plan?.visitNumber, 2);
      api.adminConfirm(v2.ref);
      final v3 = await api.createBooking(req(a, day: sat, planId: plan.id));
      api.adminConfirm(v3.ref);
      await expectCode(api.createBooking(req(a, day: DateTime(2026, 11, 30), planId: plan.id)),
          ApiCode.planNotUsable);

      api.adminRain(v2.ref, SlotPick(DateTime(2026, 11, 26), at(9)));
      expect((await api.plans()).single.endsOn, DateTime(2026, 12, 30));
    });

    test('bucket plan only where the admin enabled it', () async {
      final a = await customer('9876543210', pincode: '110092');
      await expectCode(
          api.buyPlan(clientRef: 'PL-2', planId: 'monthly-bucket', car: hatch, addressId: a, firstVisit: SlotPick(tue, at(9))),
          ApiCode.notCovered);
    });
  });
}
