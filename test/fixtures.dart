// Shared test data: a signed-in customer with a car, an address and one
// booking in different states. Used by layout tests and the screenshot tool.
import 'dart:convert';
import 'dart:math';

import 'package:cleancruisers_app/data/api/fake/fake_api.dart';
import 'package:cleancruisers_app/data/api/models.dart';
import 'package:cleancruisers_app/data/auth_service.dart';
import 'package:cleancruisers_app/providers/api_providers.dart';
import 'package:cleancruisers_app/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cleancruisers_app/core/format.dart';
import 'package:cleancruisers_app/models/booking.dart';
import 'package:cleancruisers_app/models/service.dart';
import 'package:cleancruisers_app/core/pricing.dart';

const profile = {
  'profile_v1':
      '{"name":"Rahul Sharma","phone":"9876543210","address":"B-12, Pocket 3, Janakpuri, near metro","car":"hatchback","carModel":"White Swift"}'
};

final sampleBooking = {
  ...BookingRecord.fromDraft(BookingDraft(
    service: serviceById('wash-full')!,
    bookingRef: 'CC-7K4Q2X9M',
    car: CarType.hatchback,
    carModel: 'White Swift',
    extras: const {'seat': 2},
    date: addDays(DateTime.now(), 1),
    slotId: '0930',
    name: 'Rahul Sharma',
    phone: '9876543210',
    address: 'B-12, Pocket 3, Janakpuri, near metro',
  )).toJson(),
};

Map<String, Object> bookingPrefs({bool confirmed = true}) => {
      ...profile,
      'bookings_v1': jsonEncode([
        {
          ...sampleBooking,
          if (confirmed) ...{
            'status': 'confirmed',
            'workerId': 'w1',
            'plannedArrivalMinute': 595,
            'history': [
              ...(sampleBooking['history'] as List),
              StatusEvent(BookingStatus.confirmed, DateTime.now(),
                      'Expert booked. Arriving around 9:55 AM.')
                  .toJson(),
            ],
          },
        }
      ]),
    };

/// A returning customer with one finished wash and nothing in progress
/// (Home shows "Book again").
Map<String, Object> repeatPrefs() => {
      ...profile,
      'bookings_v1': jsonEncode([
        {
          ...sampleBooking,
          'date': addDays(DateTime.now(), -11).toIso8601String(),
          'status': 'completed',
        }
      ]),
    };

/// Rain hold: the team offers another slot and leaves a note.
Map<String, Object> holdPrefs() => {
      ...profile,
      'bookings_v1': jsonEncode([
        {
          ...sampleBooking,
          'status': 'rescheduleNeeded',
          'offeredDate': addDays(DateTime.now(), 2).toIso8601String(),
          'offeredSlotId': '0930',
        }
      ]),
    };


// ── Test-build server (slice 3+) ─────────────────────────────────────────────

/// A fake server with the fixture customer (9876543210) signed in.
FakeApi fixtureApi() => FakeApi(random: Random(1))..signIn('9876543210');

/// Overrides that make a screen talk to [api] like a test build does.
List<Override> fakeOverrides(FakeApi api) => [
      fakeApiProvider.overrideWithValue(api),
      apiProvider.overrideWithValue(api),
      authServiceProvider.overrideWith(
          (ref) => FakeAuthService(api, ref.watch(sharedPrefsProvider))),
    ];

/// Sends the fixture request (wash-full, 2 seats, tomorrow 9:00 AM) and
/// returns its reference.
Future<String> fixtureRequest(FakeApi api) async {
  final a = await api.addAddress(const ApiAddress(
      flat: 'B-12', building: 'Pocket 3', area: 'Janakpuri', pincode: '110058'));
  final b = await api.createBooking(BookingRequest(
    serviceId: 'wash-full',
    car: const ApiCar(CarType.hatchback, 'White Swift'),
    extras: const {'seat': 2},
    slot: SlotPick(addDays(dateOnly(DateTime.now()), 1), 9 * 60),
    addressId: a.id,
  ));
  return b.ref;
}

/// Shows [then] once the fixture request exists on [api] (sent once).
class AfterRequest extends StatefulWidget {
  final FakeApi api;
  final Widget Function(String ref) then;
  const AfterRequest({super.key, required this.api, required this.then});

  @override
  State<AfterRequest> createState() => _AfterRequestState();
}

class _AfterRequestState extends State<AfterRequest> {
  late final Future<String> _ref = fixtureRequest(widget.api);

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
        future: _ref,
        builder: (_, s) => s.hasData ? widget.then(s.data!) : const SizedBox(),
      );
}

/// Booking states the screens are checked in (built with the admin actions).
enum Fx {
  requested,
  confirmed,
  onTheWay,
  inService,
  offered,
  rain,
  carSize,
  cancelAsked,
  completed,
  missed,
  cancelled,
}

/// Sends the fixture request and moves it to [state]; returns its reference.
Future<String> fixtureBooking(FakeApi api, Fx state) async {
  final ref = await fixtureRequest(api);
  final next = SlotPick(addDays(dateOnly(DateTime.now()), 2), 10 * 60);
  void confirm() => api.adminConfirm(ref);
  switch (state) {
    case Fx.requested:
      break;
    case Fx.confirmed:
      confirm();
    case Fx.onTheWay:
      confirm();
      api.adminOnTheWay(ref);
    case Fx.inService:
      confirm();
      api.adminOnTheWay(ref);
      api.adminStart(ref);
    case Fx.offered:
      api.adminOfferTime(ref, next);
    case Fx.rain:
      confirm();
      api.adminRain(ref, next);
    case Fx.carSize:
      confirm();
      api.adminOnTheWay(ref);
      api.adminCarSize(ref, CarType.suv);
    case Fx.cancelAsked:
      confirm();
      await api.cancel(ref, reason: 'Plans changed');
    case Fx.completed:
      confirm();
      api.adminOnTheWay(ref);
      api.adminStart(ref);
      api.adminComplete(ref, method: 'upi');
    case Fx.missed:
      confirm();
      api.adminMissed(ref);
    case Fx.cancelled:
      await api.cancel(ref, reason: 'Plans changed');
  }
  return ref;
}

/// Shows [then] once [fixtureBooking] has put a booking in [state].
class AfterBooking extends StatefulWidget {
  final FakeApi api;
  final Fx state;
  final Widget Function(String ref) then;
  const AfterBooking(
      {super.key, required this.api, required this.state, required this.then});

  @override
  State<AfterBooking> createState() => _AfterBookingState();
}

class _AfterBookingState extends State<AfterBooking> {
  late final Future<String> _ref = fixtureBooking(widget.api, widget.state);

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
        future: _ref,
        builder: (_, s) => s.hasData ? widget.then(s.data!) : const SizedBox(),
      );
}
