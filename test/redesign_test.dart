// Behaviour checks for the v3 redesign: package data the screens rely on,
// the detailing "What's bothering you?" filter, the 3-step booking flow and
// the "address in use" rule on My addresses.
import 'package:cleancruisers_app/models/address.dart';
import 'package:cleancruisers_app/models/booking.dart';
import 'package:cleancruisers_app/models/service.dart';
import 'package:cleancruisers_app/screens/addresses_screen.dart';
import 'package:cleancruisers_app/screens/booking/booking_flow_screen.dart';
import 'package:cleancruisers_app/screens/services_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'fixtures.dart';
import 'layout_test.dart' show pumpAt;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final detailing =
      serviceCatalog.where((s) => s.category == ServiceCategory.detailing).toList();

  group('catalog for the v3 screens', () {
    test('every detailing package says what it fixes and who it is for', () {
      expect(detailing, isNotEmpty);
      for (final s in detailing) {
        expect(s.fixes, isNotNull, reason: s.id);
        expect(s.fixes!.trim(), isNotEmpty, reason: s.id);
        expect(s.needs, isNotEmpty, reason: s.id);
      }
    });

    test('every need chip matches at least one package', () {
      for (final n in DetailNeed.values) {
        expect(detailing.where((s) => s.needs.contains(n)), isNotEmpty,
            reason: detailNeedNames[n]);
      }
    });

    test('list names are unique inside each category', () {
      for (final c in ServiceCategory.values) {
        final names = serviceCatalog
            .where((s) => s.category == c)
            .map((s) => s.listName)
            .toList();
        expect(names.toSet().length, names.length, reason: '$c');
      }
    });
  });

  group('AddressesScreen.bookingUsing', () {
    final booking = BookingRecord.fromJson(sampleBooking);
    const home = SavedAddress(
        id: 'a1',
        label: AddressLabel.home,
        address: 'B-12, Pocket 3, Janakpuri, near metro');
    const work = SavedAddress(
        id: 'a2', label: AddressLabel.work, address: 'Plot 7, Okhla Phase 2');

    test('finds the upcoming booking at that address', () {
      expect(AddressesScreen.bookingUsing(home, [booking])?.ref, booking.ref);
    });

    test('ignores other addresses', () {
      expect(AddressesScreen.bookingUsing(work, [booking]), isNull);
    });

    test('ignores finished bookings', () {
      final done = BookingRecord.fromJson({...sampleBooking, 'status': 'completed'});
      expect(AddressesScreen.bookingUsing(home, [done]), isNull);
      final cancelled =
          BookingRecord.fromJson({...sampleBooking, 'status': 'cancelled'});
      expect(AddressesScreen.bookingUsing(home, [cancelled]), isNull);
    });

    test('an empty address never matches', () {
      const empty = SavedAddress(id: 'a3', label: AddressLabel.other, address: ' ');
      expect(AddressesScreen.bookingUsing(empty, [booking]), isNull);
    });
  });

  testWidgets('detailing need chips filter the packages', (tester) async {
    await pumpAt(
        tester, const ServicesScreen(initialCategory: ServiceCategory.detailing),
        textScale: 1.0, saved: profile);

    for (final s in detailing) {
      expect(find.text(s.listName), findsWidgets, reason: 'all: ${s.id}');
    }
    for (final n in DetailNeed.values) {
      await tester.tap(find.text(detailNeedNames[n]!));
      await tester.pump();
      for (final s in detailing) {
        expect(find.text(s.listName),
            s.needs.contains(n) ? findsWidgets : findsNothing,
            reason: '${detailNeedNames[n]}: ${s.id}');
      }
    }
    await tester.tap(find.text('Show all'));
    await tester.pump();
    for (final s in detailing) {
      expect(find.text(s.listName), findsWidgets, reason: 'back to all');
    }
  });

  testWidgets('booking goes Extras → Pick a time → Review, and back',
      (tester) async {
    await pumpAt(tester, const BookingFlowScreen(serviceId: 'wash-full'),
        textScale: 1.0, saved: profile);

    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(find.text('Add extras'), findsWidgets);

    await tester.tap(find.text('Continue').last);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Step 2 of 3'), findsOneWidget);

    await tester.tap(find.text('Tmrw'));
    await tester.pump();
    await tester.tap(find.text('11:30 AM – 12:30 PM'));
    await tester.pump();
    await tester.tap(find.text('Continue').last);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Step 3 of 3'), findsOneWidget);
    expect(find.text('Review and request'), findsWidgets);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Step 2 of 3'), findsOneWidget);
  });

  testWidgets('a package without extras starts on Pick a time',
      (tester) async {
    final noExtras = serviceCatalog.firstWhere((s) => s.extras.isEmpty);
    await pumpAt(tester, BookingFlowScreen(serviceId: noExtras.id),
        textScale: 1.0, saved: profile);
    expect(find.text('Step 1 of 2'), findsOneWidget);
    expect(find.text('Pick a time'), findsWidgets);
  });
}
