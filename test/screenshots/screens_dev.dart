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
import 'package:cleancruisers_app/screens/wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../fixtures.dart';
import 'shots.dart';

/// Saved car + address: the flow opens on the time step. Pick a slot.
Future<void> toSlot(WidgetTester t) async {
  await t.tap(find.text('Tmrw'));
  await t.pump();
  await t.tap(find.text('11:30 AM – 12:30 PM'));
  await t.pump();
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
  both('home', const HomeScreen(), 2600, prefs: bookingPrefs());
  both('home_new', const HomeScreen(), 2400);
  both('home_repeat', const HomeScreen(), 2400, prefs: repeatPrefs());
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
  both('book', const BookingFlowScreen(serviceId: 'wash-full'), 1200,
      prefs: profile, interact: (t) async {
    await t.tap(find.text('Seat cleaning'));
    await t.pump(const Duration(milliseconds: 300));
  });
  both('book_slot', const BookingFlowScreen(serviceId: 'wash-full'), 1400,
      prefs: profile, interact: (t) async {
    await t.tap(find.text('Continue'));
    await t.pump(const Duration(milliseconds: 300));
    await toSlot(t);
  });
  both('book_review', const BookingFlowScreen(serviceId: 'wash-full'), 1500,
      prefs: profile, interact: (t) async {
    await t.tap(find.text('Continue'));
    await t.pump(const Duration(milliseconds: 300));
    await toSlot(t);
    await t.tap(find.text('Continue'));
    await t.pump(const Duration(milliseconds: 300));
  });
  both('onboard_address', const AddressScreen(), 1000);
  both('sent', const BookingSentScreen(bookingRef: 'CC-7K4Q2X9M'), 1000,
      prefs: bookingPrefs(confirmed: false));
  both('bookings', const BookingsScreen(), 800, prefs: bookingPrefs());
  both('bookings_past', const BookingsScreen(), 800, prefs: repeatPrefs(),
      interact: (t) async {
    await t.tap(find.textContaining('Past'));
    await t.pump(const Duration(milliseconds: 300));
  });
  both('bookings_empty', const BookingsScreen(), 800, prefs: profile);
  both('detail', const BookingDetailScreen(bookingRef: 'CC-7K4Q2X9M'), 1700,
      prefs: bookingPrefs());
  both('detail_waiting', const BookingDetailScreen(bookingRef: 'CC-7K4Q2X9M'),
      1700,
      prefs: bookingPrefs(confirmed: false));
  both(
      'detail_done', const BookingDetailScreen(bookingRef: 'CC-7K4Q2X9M'), 1700,
      prefs: repeatPrefs());
  both(
      'detail_hold', const BookingDetailScreen(bookingRef: 'CC-7K4Q2X9M'), 1700,
      prefs: holdPrefs());
  both('profile', const ProfileScreen(), 2000, prefs: profile);
  both('addresses', const AddressesScreen(), 1000, prefs: bookingPrefs());
  both('address_sheet', const HomeScreen(), 800, prefs: profile,
      interact: (t) async {
    await t.tap(find.text('Car parked at'));
    await t.pumpAndSettle();
  });
  both('wallet', const WalletScreen(), 1400, prefs: profile);
}
