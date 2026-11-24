// The booking flow end to end on the test-build server: extras, a start
// time from the server, the server's bill, coupons, "that time just filled
// up", the 2-request limit, buying a plan, and the "Slot requested" screen.

import 'package:cleancruisers_app/core/format.dart';
import 'package:cleancruisers_app/core/pricing.dart';
import 'package:cleancruisers_app/core/theme.dart';
import 'package:cleancruisers_app/data/api/fake/fake_api.dart';
import 'package:cleancruisers_app/data/api/models.dart';
import 'package:cleancruisers_app/providers/app_providers.dart';
import 'package:cleancruisers_app/screens/booking/booking_flow_screen.dart';
import 'package:cleancruisers_app/screens/booking_sent_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fixtures.dart';

final tomorrow = addDays(dateOnly(DateTime.now()), 1);

Future<void> open(WidgetTester t, FakeApi api, String serviceId) async {
  t.view.physicalSize = const Size(390, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues(profile);
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(initialLocation: '/book', routes: [
    GoRoute(path: '/book', builder: (_, __) => BookingFlowScreen(serviceId: serviceId)),
    GoRoute(
        path: '/booking-sent/:ref',
        builder: (_, s) => BookingSentScreen(bookingRef: s.pathParameters['ref']!)),
  ]);
  await t.pumpWidget(ProviderScope(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs), ...fakeOverrides(api)],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  ));
  await settle(t);
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> tap(WidgetTester t, String text) async {
  await t.tap(find.text(text).last);
  await settle(t);
}

/// The Apply button next to the typed code (offer cards have their own).
Future<void> applyTyped(WidgetTester t) async {
  await t.tap(find.widgetWithText(OutlinedButton, 'Apply').first);
  await settle(t);
}

/// Extras step → tomorrow at [time] → Review.
Future<void> toReview(WidgetTester t, {String time = '9:00 AM', bool extras = true}) async {
  if (extras) await tap(t, 'Continue');
  await tap(t, 'Tmrw');
  await tap(t, time);
  await tap(t, 'Continue');
}

/// Other customers book [start] tomorrow until it is full.
Future<void> fillUp(FakeApi api, int start) async {
  final me = api.signedInPhone!;
  for (var i = 0; i < 8; i++) {
    final a = await api.availability(serviceId: 'wash-full', car: const ApiCar(CarType.hatchback), date: tomorrow);
    if (!a.slots.firstWhere((s) => s.start == start).open) break;
    api.signIn('90000000${i.toString().padLeft(2, '0')}');
    final addr = await api.addAddress(ApiAddress(flat: 'F-$i', area: 'Dwarka', pincode: '110075'));
    await api.createBooking(BookingRequest(
        serviceId: 'wash-full',
        car: const ApiCar(CarType.hatchback),
        slot: SlotPick(tomorrow, start),
        addressId: addr.id));
  }
  api.signIn(me);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('a request goes through with the server’s bill', (t) async {
    final api = fixtureApi();
    await open(t, api, 'wash-full');
    await t.tap(find.byTooltip('One seat more'));
    await settle(t);
    await toReview(t);

    expect(find.text('Seat cleaning × 1'), findsNothing);
    expect(find.text('Exterior + Interior Wash'), findsWidgets);
    expect(find.text('₹549'), findsWidgets); // 449 + 1 seat (100)
    expect(find.textContaining('Includes GST'), findsOneWidget);

    await tap(t, 'Request slot');
    expect(find.text('Slot requested'), findsOneWidget);
    expect(find.textContaining('WhatsApp'), findsWidgets);
    final mine = await api.bookings(upcoming: true);
    expect(mine, hasLength(1));
    expect(mine.single.slot.start, 9 * 60);
    expect(mine.single.extras.single.qty, 1);
  });

  testWidgets('coupons are checked by the server', (t) async {
    final api = fixtureApi();
    await open(t, api, 'wash-full');
    await toReview(t);
    await tap(t, 'Add coupon');
    await t.enterText(find.byType(TextField).last, 'FIRST100');
    await settle(t);
    await applyTyped(t);
    expect(find.text('Add ₹200 more to use it'), findsOneWidget);

    await t.enterText(find.byType(TextField).last, 'FIRST50');
    await settle(t);
    await applyTyped(t);
    expect(find.text('Coupon FIRST50'), findsOneWidget);
    expect(find.text('-₹50'), findsOneWidget);
    expect(find.text('₹399'), findsWidgets);
  });

  testWidgets('a time that fills up offers the times still open', (t) async {
    final api = fixtureApi();
    await open(t, api, 'wash-full');
    await toReview(t);
    await fillUp(api, 9 * 60);
    await tap(t, 'Request slot');
    expect(find.text('9:00 AM just filled up'), findsOneWidget);
    await t.tap(find.textContaining('Request ').last);
    await settle(t);
    expect(find.text('Slot requested'), findsOneWidget);
    final mine = await api.bookings(upcoming: true);
    expect(mine.single.slot.start, isNot(9 * 60));
  });

  testWidgets('a third request while two wait is refused, nothing booked', (t) async {
    final api = fixtureApi();
    await fixtureRequest(api);
    final addr = (await api.addresses()).single;
    await api.createBooking(BookingRequest(
        serviceId: 'wash-full',
        car: const ApiCar(CarType.hatchback),
        slot: SlotPick(tomorrow, 14 * 60),
        addressId: addr.id));
    await open(t, api, 'wash-full');
    await toReview(t, time: '11:30 AM');
    await tap(t, 'Request slot');
    expect(find.text('Your request didn\'t send'), findsOneWidget);
    expect(find.textContaining('waiting for confirmation'), findsOneWidget);
    expect(await api.bookings(upcoming: true), hasLength(2));
  });

  testWidgets('buying a monthly plan books its first visit', (t) async {
    final api = fixtureApi();
    await open(t, api, 'monthly-3');
    expect(find.text('Step 1 of 2'), findsOneWidget);
    await toReview(t, extras: false);
    expect(find.text('To pay at the first visit'), findsOneWidget);
    expect(find.text('₹1,399'), findsWidgets);
    await tap(t, 'Request slot');
    expect(find.text('Slot requested'), findsOneWidget);
    final plan = (await api.plans()).single;
    expect(plan.planId, 'monthly-3');
    expect(plan.visitsBooked, 1);
  });
}
