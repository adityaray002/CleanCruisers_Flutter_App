// End to end: the app's HttpApi against a real ShineStaff running locally on
// a throw-away database (never production). Skipped unless given:
//
//   flutter test test/http_api_e2e_test.dart \
//     --dart-define=E2E_API=http://localhost:5000 \
//     --dart-define=E2E_ADMIN_PHONE=… --dart-define=E2E_ADMIN_PASSWORD=…
//
// The server must run with APP_AUTH_DEV=true (dev tokens) and have at least
// one active CleanCruisers worker.

import 'dart:convert';
import 'dart:math';

import 'package:cleancruisers_app/core/pricing.dart';
import 'package:cleancruisers_app/data/api/http_api.dart';
import 'package:cleancruisers_app/data/api/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const server = String.fromEnvironment('E2E_API');
const adminPhone = String.fromEnvironment('E2E_ADMIN_PHONE');
const adminPassword = String.fromEnvironment('E2E_ADMIN_PASSWORD');

void main() {
  final skip = server.isEmpty ? 'Set E2E_API to run against a local ShineStaff' : null;
  final rng = Random();
  final phone = '98${List.generate(8, (_) => rng.nextInt(10)).join()}';
  final other = '97${List.generate(8, (_) => rng.nextInt(10)).join()}';
  late HttpApi api;
  late String adminToken;

  HttpApi as(String p) => HttpApi('$server/api/app/v1', token: ({bool refresh = false}) async => 'dev:$p');

  Future<Map<String, dynamic>> admin(String method, String path, [Object? body]) async {
    final req = http.Request(method, Uri.parse('$server/api$path'))
      ..headers.addAll({'Authorization': 'Bearer $adminToken', 'Content-Type': 'application/json'})
      ..body = jsonEncode(body ?? {});
    final res = await http.Response.fromStream(await req.send());
    expect(res.statusCode, lessThan(300), reason: '$method $path → ${res.body}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  setUpAll(() async {
    if (skip != null) return;
    api = as(phone);
    final r = await http.post(Uri.parse('$server/api/auth/login'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'phone': adminPhone, 'password': adminPassword}));
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    adminToken = (j['accessToken'] ?? j['token']) as String;
  });

  test('a customer books, the team confirms and completes, the customer gets the invoice', () async {
    // Public calls.
    final config = await api.config();
    expect(config.openMinute, 8 * 60);
    final catalog = await api.catalog();
    expect(catalog.services.map((s) => s.id), contains('wash-full'));
    expect((await api.offers()).map((o) => o.code), contains('FIRST100'));
    expect((await api.coverage(pincode: '110058')).coverage, Coverage.covered);

    // Profile and address.
    final me = await api.updateMe(name: 'E2E Customer', car: const ApiCar(CarType.hatchback, 'Swift'));
    expect(me.phone, phone);
    expect(me.isFirstBooking, isTrue);
    final address = await api.addAddress(const ApiAddress(
        flat: 'B-12', building: 'Green Park', area: 'Pocket C, Janakpuri', pincode: '110058', parking: 'Basement Covered · P2 pillar 14'));
    expect(address.coverage, Coverage.covered);
    expect((await api.addresses()).single.id, address.id);

    // Find an open time in the next days.
    Slot? slot;
    final today = DateTime.now();
    for (var i = 1; i < 7 && slot == null; i++) {
      final day = DateTime(today.year, today.month, today.day + i);
      final av = await api.availability(serviceId: 'wash-full', car: const ApiCar(CarType.hatchback, 'Swift'), date: day);
      slot = av.slots.where((s) => s.open).firstOrNull;
    }
    expect(slot, isNotNull, reason: 'No open time: is there an active CleanCruisers worker?');

    // Quote and send the request, twice with the same clientRef.
    final req = BookingRequest(
      serviceId: 'wash-full',
      car: const ApiCar(CarType.hatchback, 'Swift'),
      extras: const {'seat': 2},
      slot: SlotPick(slot!.date, slot.start),
      addressId: address.id,
      notes: 'E2E test booking',
    );
    final quote = await api.quote(req);
    expect(quote.bill.subtotal, 649);
    final clientRef = 'E2E-${rng.nextInt(1 << 30)}';
    final b = await api.createBooking(req.forSubmit(clientRef: clientRef, quote: quote));
    expect(b.status, BookingState.requested);
    expect(b.bill.total, quote.bill.total);
    expect(b.confirmBy!.hour, inInclusiveRange(8, 18));
    expect((await api.createBooking(req.forSubmit(clientRef: clientRef, quote: quote))).ref, b.ref);
    expect((await api.bookings(upcoming: true)).map((x) => x.ref), [b.ref]);

    // Someone else can't see it.
    await expectLater(as(other).booking(b.ref), throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiCode.notYours)));

    // The team confirms (one tap).
    final confirmed = (await admin('POST', '/app-admin/bookings/${b.ref}/confirm'))['booking'] as Map<String, dynamic>;
    expect((await api.booking(b.ref)).status, BookingState.confirmed);

    // Cancel is a request; the team declines it with a message.
    final asked = await api.cancel(b.ref, reason: 'Plans changed');
    expect(asked.openRequest?.kind, 'cancel');
    expect(asked.canCancel, isFalse);
    await admin('POST', '/app-admin/bookings/${b.ref}/decline-request', {'message': 'E2E: please keep it'});
    final kept = await api.booking(b.ref);
    expect(kept.openRequest, isNull);
    expect(kept.teamMessage, 'E2E: please keep it');

    // The team offers another time; the customer accepts it.
    final free = (await admin('GET', '/app-admin/bookings/${b.ref}/free-slots'))['slots'] as List;
    final pick = Map<String, dynamic>.from(free.first as Map);
    await admin('POST', '/app-admin/bookings/${b.ref}/offer-time', {'slot': {'date': pick['date'], 'start': pick['start']}});
    final offered = await api.booking(b.ref);
    expect(offered.status, BookingState.rescheduleNeeded);
    expect(offered.offer, isNotNull);
    final moved = await api.acceptOffer(b.ref);
    expect(moved.status, BookingState.confirmed);
    expect(hhmm(moved.slot.start), pick['start']);

    // Done (the admin completes it, paid by UPI): invoice and cashback.
    await admin('PUT', '/jobs/${confirmed['jobId']}/admin-complete',
        {'reason': 'E2E test', 'paymentStatus': 'received', 'paymentMode': 'upi_online'});
    final done = await api.booking(b.ref);
    expect(done.status, BookingState.completed);
    expect(done.payment.status, 'paid');
    final inv = await api.invoice(b.ref);
    expect(inv.number, startsWith('CC/'));
    final pdf = await http.get(Uri.parse(inv.url));
    expect(pdf.statusCode, 200);
    expect(utf8.decode(pdf.bodyBytes.sublist(0, 5), allowMalformed: true), '%PDF-');
    final wallet = await api.wallet();
    expect(wallet.balance, done.bill.total * 5 ~/ 100);
    expect(wallet.entries.first.kind, 'cashback');
    expect((await api.bookings(upcoming: false)).map((x) => x.ref), contains(b.ref));
    expect((await api.me()).isFirstBooking, isFalse);
    expect((await api.referral()).code, isNotEmpty);
    expect(await api.plans(), isEmpty);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));
}
