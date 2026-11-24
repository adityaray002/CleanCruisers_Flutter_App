// My bookings and one booking, on the test-build server: what the customer
// sees in each state, and every action they can take (contract §6). Also
// the Test tools screen that acts as the admin in test builds.

import 'package:cleancruisers_app/data/api/fake/fake_api.dart';
import 'package:cleancruisers_app/data/api/models.dart';
import 'package:cleancruisers_app/screens/booking_detail_screen.dart';
import 'package:cleancruisers_app/screens/bookings_screen.dart';
import 'package:cleancruisers_app/screens/test_tools_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'fixtures.dart';
import 'layout_test.dart' show pumpAt;

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<String> openDetail(WidgetTester t, FakeApi api, Fx state) async {
  final ref = await fixtureBooking(api, state);
  await pumpAt(t, BookingDetailScreen(bookingRef: ref),
      textScale: 1.0, saved: profile, overrides: fakeOverrides(api));
  await settle(t);
  return ref;
}

Future<void> tap(WidgetTester t, String text) async {
  await t.tap(find.text(text).last);
  await settle(t);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('a request not yet confirmed cancels at once, free', (t) async {
    final api = fixtureApi();
    final ref = await openDetail(t, api, Fx.requested);
    expect(find.text('Waiting for confirmation'), findsOneWidget);
    await tap(t, 'Cancel');
    expect(find.textContaining('cancels right away, free'), findsOneWidget);
    await tap(t, 'Yes, cancel');
    expect((await api.booking(ref)).status, BookingState.cancelled);
    expect(find.text('Booking cancelled'), findsWidgets);
  });

  testWidgets('cancelling a confirmed booking is a request', (t) async {
    final api = fixtureApi();
    final ref = await openDetail(t, api, Fx.confirmed);
    expect(find.text('Your expert arrives'), findsOneWidget);
    await tap(t, 'Cancel');
    await tap(t, 'Plans changed');
    await tap(t, 'Yes, request cancellation');
    final b = await api.booking(ref);
    expect(b.status, BookingState.confirmed);
    expect(b.openRequest?.kind, 'cancel');
    expect(find.textContaining('You asked to cancel'), findsOneWidget);
  });

  testWidgets('change time asks for an open time the server lists', (t) async {
    final api = fixtureApi();
    final ref = await openDetail(t, api, Fx.confirmed);
    await tap(t, 'Change time');
    // Tomorrow is picked first; its current time (9:00 AM) isn't offered.
    expect(find.widgetWithText(ChoiceChip, '9:00 AM'), findsNothing);
    await tap(t, '11:00 AM');
    await t.tap(find.textContaining('Request 11:00 AM'));
    await settle(t);
    final b = await api.booking(ref);
    expect(b.openRequest?.kind, 'changeTime');
    expect(b.openRequest?.slot?.start, 11 * 60);
    expect(find.textContaining('You asked to move it'), findsOneWidget);
  });

  testWidgets('taking the team’s new slot confirms it', (t) async {
    final api = fixtureApi();
    final ref = await openDetail(t, api, Fx.offered);
    expect(find.text('Your slot needs a new time'), findsOneWidget);
    await tap(t, 'Take the new slot');
    final b = await api.booking(ref);
    expect(b.status, BookingState.confirmed);
    expect(b.slot.start, 10 * 60);
    expect(find.text('Your expert arrives'), findsOneWidget);
  });

  testWidgets('rain: "covered parking" keeps the wash', (t) async {
    final api = fixtureApi();
    final ref = await openDetail(t, api, Fx.rain);
    await tap(t, 'My car is in covered parking');
    expect((await api.booking(ref)).openRequest?.kind, 'keepAsPlanned');
    expect(find.textContaining('covered parking'), findsWidgets);
  });

  testWidgets('a bigger car on site needs the customer to accept', (t) async {
    final api = fixtureApi();
    final ref = await openDetail(t, api, Fx.carSize);
    expect(find.textContaining('The expert found an SUV'), findsOneWidget);
    await tap(t, 'Accept ₹749');
    final b = await api.booking(ref);
    expect(b.pendingChange, isNull);
    expect(b.bill.total, 749);
    expect(find.text('₹749'), findsWidgets);
  });

  testWidgets('a finished wash shows the GST invoice and Book again', (t) async {
    final api = fixtureApi();
    await openDetail(t, api, Fx.completed);
    expect(find.textContaining('GST invoice CC/26-27/'), findsOneWidget);
    expect(find.text('Book again'), findsOneWidget);
    expect(find.textContaining('Paid'), findsWidgets);
  });

  testWidgets('My bookings lists upcoming and past from the server', (t) async {
    final api = fixtureApi();
    await fixtureBooking(api, Fx.completed);
    await fixtureBooking(api, Fx.confirmed);
    await pumpAt(t, const BookingsScreen(),
        textScale: 1.0, saved: profile, overrides: fakeOverrides(api));
    await settle(t);
    expect(find.text('Upcoming · 1'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
    await tap(t, 'Past · 1');
    expect(find.text('Done · paid'), findsOneWidget);
    expect(find.text('Book again'), findsOneWidget);
  });

  testWidgets('Test tools confirm a request and log the WhatsApp message', (t) async {
    final api = fixtureApi();
    final ref = await fixtureRequest(api);
    await pumpAt(t, const TestToolsScreen(),
        textScale: 1.0, saved: profile, overrides: fakeOverrides(api));
    await settle(t);
    await tap(t, 'Confirm');
    expect((await api.booking(ref)).status, BookingState.confirmed);
    expect(find.textContaining('booking_confirmed'), findsOneWidget);
    await tap(t, 'On the way');
    expect((await api.booking(ref)).status, BookingState.onTheWay);
  });
}
