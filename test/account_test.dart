// CleanCredit, offers, referral, monthly plans, saved addresses and live
// prices, on the test-build server (contract §4, §7–§9; owner rules J4, J5).

import 'package:cleancruisers_app/core/format.dart';
import 'package:cleancruisers_app/core/pricing.dart';
import 'package:cleancruisers_app/data/api/fake/fake_api.dart';
import 'package:cleancruisers_app/data/api/models.dart';
import 'package:cleancruisers_app/models/address.dart';
import 'package:cleancruisers_app/models/service.dart';
import 'package:cleancruisers_app/providers/app_providers.dart';
import 'package:cleancruisers_app/screens/booking/booking_flow_screen.dart';
import 'package:cleancruisers_app/screens/plans_screen.dart';
import 'package:cleancruisers_app/screens/referral_screen.dart';
import 'package:cleancruisers_app/screens/wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fixtures.dart';
import 'layout_test.dart' show pumpAt;

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

const hatch = ApiCar(CarType.hatchback, 'White Swift');
final tomorrow = addDays(dateOnly(DateTime.now()), 1);

/// A Complete Care plan whose first visit is done.
Future<Plan> activePlan(FakeApi api) async {
  final a = await api.addAddress(const ApiAddress(
      flat: 'B-12', building: 'Pocket 3', area: 'Janakpuri', pincode: '110058'));
  final r = await api.buyPlan(
      clientRef: 'PL-T', planId: 'monthly-3', car: hatch, addressId: a.id!,
      firstVisit: SlotPick(tomorrow, 9 * 60));
  api.adminConfirm(r.booking.ref);
  api.adminOnTheWay(r.booking.ref);
  api.adminStart(r.booking.ref);
  api.adminComplete(r.booking.ref);
  return (await api.plans()).single;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('Offers tab: credit, expiry, history and coupons from the server', (t) async {
    final api = fixtureApi();
    await fixtureBooking(api, Fx.completed); // ₹649 → 5% = ₹32 back
    await pumpAt(t, const WalletScreen(),
        textScale: 1.0, saved: profile, overrides: fakeOverrides(api));
    await settle(t);
    expect(find.text('₹32'), findsWidgets);
    expect(find.textContaining('expires on'), findsOneWidget);
    expect(find.text('Cashback'), findsOneWidget);
    expect(find.text('FIRST50'), findsOneWidget);
    expect(find.text('Invite a friend, both get ₹100'), findsOneWidget);
  });

  testWidgets('Referral: your code, and a friend\'s code before the first booking', (t) async {
    final api = fixtureApi();
    api.signIn('9000000001');
    final friendCode = (await api.me()).referralCode;
    api.signIn('9876543210');
    await pumpAt(t, const ReferralScreen(),
        textScale: 1.0, saved: profile, overrides: fakeOverrides(api));
    await settle(t);
    expect(find.text((await api.me()).referralCode), findsOneWidget);

    await t.enterText(find.byType(TextField), 'NOPE123');
    await t.tap(find.text('Add'));
    await settle(t);
    expect(find.text('This referral code is not valid.'), findsOneWidget);

    await t.enterText(find.byType(TextField), friendCode);
    await t.tap(find.text('Add'));
    await settle(t);
    expect(find.textContaining('Code added'), findsOneWidget);
  });

  testWidgets('My plans: visits and "Book next visit"', (t) async {
    final api = fixtureApi();
    await activePlan(api);
    await pumpAt(t, const PlansScreen(),
        textScale: 1.0, saved: profile, overrides: fakeOverrides(api));
    await settle(t);
    expect(find.text('Complete Care'), findsOneWidget);
    expect(find.text('1 done · 0 booked · 2 left'), findsOneWidget);
    expect(find.text('Book next visit'), findsOneWidget);
  });

  testWidgets('a plan visit costs ₹0 and has no coupon or credit', (t) async {
    final api = fixtureApi();
    final plan = await activePlan(api);
    await pumpAt(t, BookingFlowScreen(serviceId: 'wash-full', planId: plan.id),
        textScale: 1.0, saved: profile, overrides: fakeOverrides(api));
    await settle(t);
    await t.tap(find.text('Continue').last);
    await settle(t);
    await t.tap(find.text('Tmrw'));
    await settle(t);
    await t.tap(find.text('11:30 AM'));
    await settle(t);
    await t.tap(find.text('Continue').last);
    await settle(t);
    expect(find.text('Plan visit'), findsOneWidget);
    expect(find.text('₹0'), findsWidgets);
    expect(find.text('Add coupon'), findsNothing);
  });

  group('saved addresses on the server', () {
    Future<(ProviderContainer, FakeApi)> container([Map<String, Object> saved = const {}]) async {
      SharedPreferences.setMockInitialValues(saved);
      final prefs = await SharedPreferences.getInstance();
      final api = fixtureApi();
      final c = ProviderContainer(overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        ...fakeOverrides(api),
      ]);
      addTearDown(c.dispose);
      return (c, api);
    }

    test('saving copies to the server; deleting removes it there', () async {
      final (c, api) = await container();
      await c.read(addressBookProvider.notifier).save(const SavedAddress(
          id: 'home', label: AddressLabel.home,
          address: 'B-12, Pocket 3, Janakpuri, near metro · Parking: Basement parking'));
      final server = await api.addresses();
      expect(server.single.flat, 'B-12');
      expect(server.single.parking, 'Basement parking');
      expect(c.read(addressBookProvider).items.single.serverId, server.single.id);

      await c.read(addressBookProvider.notifier).remove('home');
      expect(await api.addresses(), isEmpty);
    });

    test('a new phone gets the saved addresses back', () async {
      final (c, api) = await container();
      await api.addAddress(const ApiAddress(
          label: 'work', flat: 'Plot 7', area: 'Okhla Phase 2', parking: 'Office parking'));
      await c.read(addressBookProvider.notifier).restoreFromServer();
      final book = c.read(addressBookProvider);
      expect(book.items.single.label, AddressLabel.work);
      expect(book.items.single.address, 'Plot 7, Okhla Phase 2 · Parking: Office parking');
      expect(c.read(profileProvider).address, book.items.single.address);
    });
  });

  test('prices on every screen follow the server catalog', () {
    final bucket = serviceById('monthly-bucket')!;
    expect(bucket.priceFor(CarType.hatchback), 799); // bundled
    useServerPrices({'monthly-bucket': {for (final c in CarType.values) c: 899}});
    expect(bucket.priceFor(CarType.hatchback), 899);
    expect(bucket.fromPrice, 899);
    useServerPrices({});
    expect(bucket.priceFor(CarType.hatchback), 799);
  });
}
