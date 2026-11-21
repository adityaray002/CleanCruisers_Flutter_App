// HttpApi: the real ShineStaff client, against a fake HTTP server.
// (test/http_api_e2e_test.dart runs the same client against a real local
// ShineStaff.)

import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:cleancruisers_app/core/pricing.dart';
import 'package:cleancruisers_app/data/api/http_api.dart';
import 'package:cleancruisers_app/data/api/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const base = 'https://shinestaff.example.invalid/api/app/v1';

Map<String, dynamic> bookingJson({String status = 'requested'}) => {
      'ref': 'CC-7K4Q2X9M',
      'createdAt': '2026-11-21T22:10:00+05:30',
      'status': status,
      'statusNote': "We'll confirm it by 10:00 AM tomorrow.",
      'confirmBy': '2026-11-22T10:00:00+05:30',
      'service': {'id': 'wash-full', 'name': 'Exterior + Interior Wash', 'category': 'wash'},
      'car': {'type': 'hatchback', 'model': 'Swift'},
      'extras': [],
      'slot': {'date': '2026-11-22', 'start': '09:00', 'end': '11:00', 'label': '9 – 11 AM', 'open': true},
      'durationMinutes': 120,
      'address': {'label': 'home', 'flat': 'B-12', 'building': '', 'area': 'Janakpuri', 'landmark': '', 'pincode': '110058', 'parking': null, 'pin': null, 'line': 'B-12, Janakpuri', 'isDefault': true},
      'coverage': 'covered',
      'notes': '',
      'recipient': null,
      'bill': {
        'items': [{'kind': 'service', 'name': 'Exterior + Interior Wash', 'qty': 1, 'amount': 449}],
        'subtotal': 449,
        'discounts': [],
        'lateCancelFee': 0,
        'total': 449,
        'gst': {'taxable': 381, 'cgst': 34, 'sgst': 34, 'rate': 18},
        'discountCapNote': null,
        'payAfterService': true,
      },
      'plan': null,
      'history': [
        {'status': 'requested', 'at': '2026-11-21T22:10:00+05:30', 'note': 'Request sent'}
      ],
      'teamMessage': null,
      'offer': null,
      'pendingChange': null,
      'openRequest': null,
      'payment': {'status': 'pending', 'method': null, 'paidAt': null},
      'invoice': null,
      'canCancel': true,
      'canChangeTime': true,
      'cancelPolicy': {'freeUntil': '2026-11-22T05:00:00+05:30', 'feeAfter': '2026-11-22T07:00:00+05:30', 'fee': 100},
    };

http.Response json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  late List<http.Request> seen;
  late List<bool> refreshes;

  HttpApi api(Future<http.Response> Function(http.Request r) handler, {String? token = 'tok'}) {
    seen = [];
    refreshes = [];
    return HttpApi(base,
        token: ({bool refresh = false}) async {
          refreshes.add(refresh);
          return token == null ? null : (refresh ? '$token-new' : token);
        },
        client: MockClient((r) {
          seen.add(r);
          return handler(r);
        }));
  }

  test('IST times are read as IST wall-clock on any phone', () async {
    final b = await api((_) async => json({'booking': bookingJson()})).booking('CC-7K4Q2X9M');
    expect(b.confirmBy, DateTime(2026, 11, 22, 10));
    expect(b.confirmBy!.isUtc, isFalse);
    expect(b.createdAt, DateTime(2026, 11, 21, 22, 10));
    expect(b.cancelPolicy!.freeUntil, DateTime(2026, 11, 22, 5));
    expect(b.history.single.at, DateTime(2026, 11, 21, 22, 10));
    expect(seen.single.headers['Authorization'], 'Bearer tok');
    expect(seen.single.url.toString(), '$base/bookings/CC-7K4Q2X9M');
  });

  test('a contract error becomes ApiException with its code and details', () async {
    final a = api((_) async => json({
          'error': {
            'code': 'SLOT_TAKEN',
            'message': 'That time was just taken.',
            'details': {
              'alternatives': [
                {'date': '2026-11-22', 'start': '11:00', 'end': '13:00', 'label': '11 AM – 1 PM', 'open': true}
              ]
            }
          }
        }, 409));
    try {
      await a.createBooking(BookingRequest(
          serviceId: 'wash-full', car: const ApiCar(CarType.hatchback, 'Swift'), slot: SlotPick(DateTime(2026, 11, 22), 540), addressId: 'AD-1'));
      fail('expected SLOT_TAKEN');
    } on ApiException catch (e) {
      expect(e.code, ApiCode.slotTaken);
      expect(e.message, 'That time was just taken.');
      expect((e.details['alternatives'] as List).single['start'], '11:00');
    }
    final body = jsonDecode(seen.single.body) as Map<String, dynamic>;
    expect(seen.single.method, 'POST');
    expect(body['slot'], {'date': '2026-11-22', 'start': '09:00'});
    expect(body['car'], {'type': 'hatchback', 'model': 'Swift'});
    expect(body['addressId'], 'AD-1');
  });

  test('a refused token is refreshed once and the call retried', () async {
    final a = api((r) async => r.headers['Authorization'] == 'Bearer tok-new'
        ? json({'phone': '9876543210', 'name': 'Rahul', 'car': null, 'isFirstBooking': true, 'wallet': {'balance': 0, 'nextExpiry': null}, 'referralCode': 'ABC', 'activePlans': [], 'lateCancelFeeDue': 0})
        : json({'error': {'code': 'AUTH_REQUIRED', 'message': 'Please log in again.', 'details': {}}}, 401));
    final me = await a.me();
    expect(me.name, 'Rahul');
    expect(refreshes, [false, true]);
  });

  test('not logged in: AUTH_REQUIRED without calling the server', () async {
    final a = api((_) async => json({}), token: null);
    await expectLater(a.wallet(), throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiCode.authRequired)));
    expect(seen, isEmpty);
  });

  test('public calls need no login', () async {
    final a = api((_) async => json({'offers': []}), token: null);
    expect(await a.offers(), isEmpty);
    expect(seen.single.headers.containsKey('Authorization'), isFalse);
  });

  test('no internet or a server crash: UNAVAILABLE with a readable message', () async {
    final offline = api((_) async => throw const SocketException('Failed host lookup'));
    await expectLater(offline.config(),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiCode.unavailable).having((e) => e.message, 'message', contains('internet'))));
    final crash = api((_) async => http.Response('<html>Bad gateway</html>', 502));
    await expectLater(crash.config(), throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiCode.unavailable)));
  });

  test('a build without a server address says so', () async {
    final a = HttpApi('', token: ({bool refresh = false}) async => 'tok', client: MockClient((_) async => json({})));
    await expectLater(a.config(), throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiCode.unavailable)));
  });

  test('availability sends the contract query', () async {
    final a = api((_) async => json({'date': '2026-11-22', 'durationMinutes': 150, 'slots': [], 'closedReason': 'Closed for Diwali'}));
    final av = await a.availability(
        serviceId: 'wash-full', car: const ApiCar(CarType.suv, ''), extras: const {'seat': 2, 'ac': 1}, date: DateTime(2026, 11, 22));
    expect(av.closedReason, 'Closed for Diwali');
    expect(seen.single.url.queryParameters, {'serviceId': 'wash-full', 'car': 'suv', 'extras': 'seat:2,ac:1', 'date': '2026-11-22'});
  });

  test('after-booking actions go to their paths', () async {
    final a = api((_) async => json({'booking': bookingJson(status: 'confirmed')}));
    await a.cancel('CC-1', reason: 'Plans changed');
    await a.changeTime('CC-1', SlotPick(DateTime(2026, 11, 23), 660));
    await a.acceptOffer('CC-1');
    await a.declineOffer('CC-1');
    await a.keepAsPlanned('CC-1');
    await a.acceptChange('CC-1', 'CH-9');
    await a.rejectChange('CC-1', 'CH-9');
    expect(seen.map((r) => '${r.method} ${r.url.path.replaceFirst('/api/app/v1', '')}').toList(), [
      'POST /bookings/CC-1/cancel',
      'POST /bookings/CC-1/change-time',
      'POST /bookings/CC-1/offer/accept',
      'POST /bookings/CC-1/offer/decline',
      'POST /bookings/CC-1/keep-as-planned',
      'POST /bookings/CC-1/changes/CH-9/accept',
      'POST /bookings/CC-1/changes/CH-9/reject',
    ]);
    expect(jsonDecode(seen[0].body), {'reason': 'Plans changed'});
    expect(jsonDecode(seen[1].body), {
      'slot': {'date': '2026-11-23', 'start': '11:00'}
    });
  });
}
