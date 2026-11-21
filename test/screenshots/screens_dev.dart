// Dev tool: renders customer screens to PNG for visual review.
// Run: flutter test test/screenshots/screens_dev.dart [--dart-define=ONLY=a,b]
// Each screen is saved twice: "<name>_fold" at phone height (what is visible
// without scrolling) and "<name>_full" at full length.
import 'package:cleancruisers_app/data/api/fake/fake_api.dart';
import 'package:cleancruisers_app/data/auth_service.dart';
import 'package:cleancruisers_app/data/booking_cloud.dart';
import 'package:cleancruisers_app/models/service.dart';
import 'package:cleancruisers_app/providers/api_providers.dart';
import 'package:cleancruisers_app/providers/app_providers.dart';
import 'package:cleancruisers_app/screens/addresses_screen.dart';
import 'package:cleancruisers_app/screens/auth/login_screen.dart';
import 'package:cleancruisers_app/screens/booking/booking_flow_screen.dart';
import 'package:cleancruisers_app/screens/booking_detail_screen.dart';
import 'package:cleancruisers_app/screens/booking_sent_screen.dart';
import 'package:cleancruisers_app/screens/bookings_screen.dart';
import 'package:cleancruisers_app/screens/home_screen.dart';
import 'package:cleancruisers_app/screens/profile_screen.dart';
import 'package:cleancruisers_app/screens/service_detail_screen.dart';
import 'package:cleancruisers_app/screens/services_screen.dart';
import 'package:cleancruisers_app/screens/plans_screen.dart';
import 'package:cleancruisers_app/screens/referral_screen.dart';
import 'package:cleancruisers_app/screens/test_tools_screen.dart';
import 'package:cleancruisers_app/core/format.dart';
import 'package:cleancruisers_app/core/pricing.dart';
import 'package:cleancruisers_app/data/api/models.dart' show ApiCar, SlotPick;
import 'package:cleancruisers_app/screens/wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../fixtures.dart';
import 'shots.dart';

/// Saved car + address: the flow opens on the time step. Pick a slot.
Future<void> toSlot(WidgetTester t) async {
  await t.tap(find.text('Tmrw'));
  await t.pump(const Duration(milliseconds: 300));
  await t.pump(const Duration(milliseconds: 300));
  await t.tap(find.text('11:30 AM'));
  await t.pump(const Duration(milliseconds: 300));
}

Future<void> next(WidgetTester t) async {
  await t.tap(find.text('Continue').last);
  await t.pump(const Duration(milliseconds: 300));
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(loadFonts);
  const only = String.fromEnvironment('ONLY');
  bool want(String n) => only.isEmpty || only.split(',').contains(n);

  void both(String name, Widget screen, double full,
      {Map<String, Object> prefs = const {},
      List<Override> overrides = const [],
      Future<void> Function(WidgetTester)? interact}) {
    if (!want(name)) return;
    testWidgets(
        '${name}_fold',
        (t) => shoot(t, '${name}_fold', screen,
            prefs: prefs, overrides: overrides, height: 800, interact: interact));
    testWidgets(
        '${name}_full',
        (t) => shoot(t, '${name}_full', screen,
            prefs: prefs, overrides: overrides, height: full, interact: interact));
  }

  // Test build (--dart-define=FAKE_SERVER=true): fake login, OTP 123456.
  final testBuild = [
    authServiceProvider.overrideWith(
        (ref) => FakeAuthService(FakeApi(), ref.watch(sharedPrefsProvider))),
  ];

  both('login', const LoginScreen(), 800);
  both('otp', const OtpScreen(session: OtpSession(phone: '9876543210')), 800,
      interact: (t) => t.enterText(find.byType(TextField), '4821'));
  both('name', const NameScreen(), 800);
  both('login_test', const LoginScreen(), 800, overrides: testBuild);
  both('otp_test', const OtpScreen(session: OtpSession(phone: '9876543210')), 800,
      overrides: testBuild);
  /// [screen] once the fixture customer has a booking in [state].
  void withBooking(String name, Fx state, Widget Function(String ref) screen, double full,
      {Future<void> Function(WidgetTester)? interact}) {
    final api = fixtureApi();
    both(name, AfterBooking(api: api, state: state, then: screen), full,
        prefs: profile, overrides: fakeOverrides(api), interact: interact);
  }

  withBooking('home', Fx.confirmed, (_) => const HomeScreen(), 2600);
  both('home_new', const HomeScreen(), 2400);
  withBooking('home_repeat', Fx.completed, (_) => const HomeScreen(), 2400);
  both('services', const ServicesScreen(), 1600, prefs: profile);
  both('services_detailing',
      const ServicesScreen(initialCategory: ServiceCategory.detailing), 2000,
      prefs: profile);
  both('service', const ServiceDetailScreen(serviceId: 'wash-full'), 2000,
      prefs: profile);
  both('service_detailing',
      const ServiceDetailScreen(serviceId: 'rubbing-wax-exterior'), 2000,
      prefs: profile);
  // Booking, three steps: car + address come from the profile.
  // On the test-build server: times and the bill come from it.
  both('book', const BookingFlowScreen(serviceId: 'wash-full'), 1200,
      prefs: profile, overrides: fakeOverrides(fixtureApi()), interact: (t) async {
    await t.tap(find.text('Roof cleaning'));
    await t.pump(const Duration(milliseconds: 300));
  });
  both('book_slot', const BookingFlowScreen(serviceId: 'wash-full'), 1600,
      prefs: profile, overrides: fakeOverrides(fixtureApi()), interact: (t) async {
    await next(t);
    await toSlot(t);
  });
  both('book_review', const BookingFlowScreen(serviceId: 'wash-full'), 1500,
      prefs: profile, overrides: fakeOverrides(fixtureApi()), interact: (t) async {
    await t.tap(find.text('Roof cleaning'));
    await next(t);
    await toSlot(t);
    await next(t);
  });
  both('book_plan', const BookingFlowScreen(serviceId: 'monthly-3'), 1500,
      prefs: profile, overrides: fakeOverrides(fixtureApi()), interact: (t) async {
    await toSlot(t);
    await next(t);
  });
  both('onboard_address', const AddressScreen(), 1000);
  final sentApi = fixtureApi();
  both('sent',
      AfterRequest(api: sentApi, then: (ref) => BookingSentScreen(bookingRef: ref)),
      1000,
      prefs: profile,
      overrides: fakeOverrides(sentApi));
  withBooking('bookings', Fx.confirmed, (_) => const BookingsScreen(), 800);
  withBooking('bookings_past', Fx.completed, (_) => const BookingsScreen(), 800,
      interact: (t) async {
    await t.tap(find.textContaining('Past'));
    await t.pump(const Duration(milliseconds: 300));
  });
  both('bookings_empty', const BookingsScreen(), 800,
      prefs: profile, overrides: fakeOverrides(fixtureApi()));
  for (final (name, state) in [
    ('detail', Fx.confirmed),
    ('detail_waiting', Fx.requested),
    ('detail_done', Fx.completed),
    ('detail_hold', Fx.rain),
    ('detail_offer', Fx.offered),
    ('detail_car', Fx.carSize),
    ('detail_cancel_asked', Fx.cancelAsked),
    ('detail_missed', Fx.missed),
  ]) {
    withBooking(name, state, (ref) => BookingDetailScreen(bookingRef: ref), 1900);
  }
  final toolsApi = fixtureApi();
  both('test_tools',
      AfterBooking(api: toolsApi, state: Fx.confirmed, then: (_) => const TestToolsScreen()),
      1400,
      prefs: profile,
      overrides: fakeOverrides(toolsApi));
  both('profile', const ProfileScreen(), 2000, prefs: profile);
  both('addresses', const AddressesScreen(), 1000, prefs: bookingPrefs());
  both('address_sheet', const HomeScreen(), 800, prefs: profile,
      interact: (t) async {
    await t.tap(find.text('Car parked at'));
    await t.pumpAndSettle();
  });
  withBooking('wallet', Fx.completed, (_) => const WalletScreen(), 1600);
  withBooking('referral', Fx.requested, (_) => const ReferralScreen(), 1000);
  final planApi = fixtureApi();
  Future<String> planSetup() async {
    final ref = await fixtureBooking(planApi, Fx.requested);
    final a = (await planApi.addresses()).first;
    final r = await planApi.buyPlan(
        clientRef: 'PL-S', planId: 'monthly-3',
        car: const ApiCar(CarType.hatchback, 'White Swift'), addressId: a.id!,
        firstVisit: SlotPick(addDays(dateOnly(DateTime.now()), 2), 9 * 60));
    planApi.adminConfirm(r.booking.ref);
    planApi.adminOnTheWay(r.booking.ref);
    planApi.adminStart(r.booking.ref);
    planApi.adminComplete(r.booking.ref);
    return ref;
  }
  final planReady = planSetup();
  both('plans', FutureBuilder(future: planReady,
      builder: (_, s) => s.hasData ? const PlansScreen() : const SizedBox()), 1000,
      prefs: profile, overrides: fakeOverrides(planApi));
}
