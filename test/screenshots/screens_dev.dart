// Dev tool: renders customer screens to PNG for visual review.
// Run: flutter test test/screenshots/screens_dev.dart [--dart-define=ONLY=a,b]
// Each screen is saved twice: "<name>_fold" at phone height (what is visible
// without scrolling) and "<name>_full" at full length.
import 'dart:convert';
import 'package:cleancruisers_app/core/format.dart';
import 'package:cleancruisers_app/core/pricing.dart';
import 'package:cleancruisers_app/data/booking_cloud.dart';
import 'package:cleancruisers_app/models/booking.dart';
import 'package:cleancruisers_app/models/service.dart';
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
import 'package:flutter_test/flutter_test.dart';
import 'shots.dart';

const profile = {
  'profile_v1':
      '{"name":"Rahul Sharma","phone":"9876543210","address":"B-12, Pocket 3, Janakpuri, near metro","car":"hatchback","carModel":"White Swift"}'
};

final _booking = {
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
          ..._booking,
          if (confirmed) ...{
            'status': 'confirmed',
            'workerId': 'w1',
            'plannedArrivalMinute': 595,
            'history': [
              ...(_booking['history'] as List),
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
          ..._booking,
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
          ..._booking,
          'status': 'rescheduleNeeded',
          'offeredDate': addDays(DateTime.now(), 2).toIso8601String(),
          'offeredSlotId': '0930',
        }
      ]),
    };

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
      Future<void> Function(WidgetTester)? interact}) {
    if (!want(name)) return;
    testWidgets(
        '${name}_fold',
        (t) => shoot(t, '${name}_fold', screen,
            prefs: prefs, height: 800, interact: interact));
    testWidgets(
        '${name}_full',
        (t) => shoot(t, '${name}_full', screen,
            prefs: prefs, height: full, interact: interact));
  }

  both('login', const LoginScreen(), 800);
  both('otp', const OtpScreen(session: OtpSession(phone: '9876543210')), 800,
      interact: (t) => t.enterText(find.byType(TextField), '4821'));
  both('name', const NameScreen(), 800);
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
  both('wallet', const WalletScreen(), 1400, prefs: profile);
}
