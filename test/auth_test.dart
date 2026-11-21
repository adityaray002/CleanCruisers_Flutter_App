// Test-build login (OTP 123456) and saving the fake server on the phone.

import 'dart:convert';
import 'dart:math';

import 'package:cleancruisers_app/core/pricing.dart';
import 'package:cleancruisers_app/core/router.dart';
import 'package:cleancruisers_app/data/api/fake/fake_api.dart';
import 'package:cleancruisers_app/data/api/models.dart';
import 'package:cleancruisers_app/data/auth_service.dart';
import 'package:cleancruisers_app/providers/api_providers.dart';
import 'package:cleancruisers_app/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const hatch = ApiCar(CarType.hatchback, 'Swift');

Future<SharedPreferences> freshPrefs([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('test login', () {
    test('a wrong OTP is refused; 123456 signs in and is remembered', () async {
      final prefs = await freshPrefs();
      final auth = FakeAuthService(FakeApi(), prefs);
      final session = await auth.sendOtp('9876543210');
      await expectLater(auth.verifyOtp(session, '000000'), throwsA(isA<AuthException>()));
      expect(auth.signedIn, isFalse);

      await auth.verifyOtp(session, '123456');
      expect(auth.signedIn, isTrue);
      expect(auth.phone, '9876543210');
      expect(auth.name, isNull); // sign-up not finished

      // App restart: a new fake server and login read the same phone storage.
      final again = FakeAuthService(FakeApi(), prefs);
      expect(again.phone, '9876543210');
    });

    test('a bad number is refused before any OTP', () async {
      final auth = FakeAuthService(FakeApi(), await freshPrefs());
      await expectLater(auth.sendOtp('12345'), throwsA(isA<AuthException>()));
    });

    test('saving the name finishes sign-up; logging out forgets the phone', () async {
      final prefs = await freshPrefs();
      final auth = FakeAuthService(FakeApi(), prefs);
      await auth.verifyOtp(await auth.sendOtp('9876543210'), '123456');
      await auth.saveName('Rahul');
      expect(auth.name, 'Rahul');
      await auth.signOut();
      expect(auth.signedIn, isFalse);
      expect(FakeAuthService(FakeApi(), prefs).signedIn, isFalse);
    });
  });

  group('saving the fake server', () {
    test('every booking, credit and plan survives a save and load', () async {
      var now = DateTime(2026, 11, 23, 10);
      final api = FakeApi(clock: () => now, random: Random(3));
      api.signIn('9876543210');
      final a = await api.addAddress(const ApiAddress(
          flat: 'B-12', building: 'Green Park', area: 'Janakpuri', pincode: '110058'));
      api.adminGoodwill('9876543210', 200, 'Welcome');
      final b = await api.createBooking(BookingRequest(
          serviceId: 'wash-full', car: hatch, slot: SlotPick(DateTime(2026, 11, 24), 540),
          addressId: a.id, useCredit: true, couponCode: 'FIRST50'));
      api.adminConfirm(b.ref);
      await api.buyPlan(
          clientRef: 'P1', planId: 'monthly-3', car: hatch, addressId: a.id!,
          firstVisit: SlotPick(DateTime(2026, 11, 25), 540));

      final copy = FakeApi(clock: () => now, random: Random(3))
        ..restore(Map<String, dynamic>.from(jsonDecode(jsonEncode(api.toJson())) as Map));

      String dump(Object x) => jsonEncode(x);
      expect(dump([for (final x in await copy.bookings(upcoming: true)) x.toJson()]),
          dump([for (final x in await api.bookings(upcoming: true)) x.toJson()]));
      expect(dump((await copy.wallet()).toJson()), dump((await api.wallet()).toJson()));
      expect(dump([for (final p in await copy.plans()) p.toJson()]),
          dump([for (final p in await api.plans()) p.toJson()]));
      expect(dump((await copy.me()).toJson()), dump((await api.me()).toJson()));
      expect(copy.adminWorkerOf(b.ref), api.adminWorkerOf(b.ref));
      // The coupon stays used after loading.
      final q = await copy.quote(BookingRequest(
          serviceId: 'wash-full', car: hatch, slot: SlotPick(DateTime(2026, 11, 26), 540),
          addressId: a.id, couponCode: 'FIRST50'));
      expect(q.couponReason, isNotNull);
      now = now.add(const Duration(days: 1));
    });

    test('the test build saves after each change and loads on start', () async {
      final prefs = await freshPrefs();
      final c1 = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
      final api = c1.read(fakeApiProvider);
      api.signIn('9876543210');
      await api.addAddress(const ApiAddress(flat: 'B-12', area: 'Janakpuri', pincode: '110058'));
      c1.dispose();

      final c2 = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
      addTearDown(c2.dispose);
      final loaded = c2.read(fakeApiProvider);
      expect(loaded.signedInPhone, '9876543210');
      expect(await loaded.addresses(), hasLength(1));
    });

    test('a state the build can’t read starts fresh instead of crashing', () async {
      final prefs = await freshPrefs({'fake_server_v1': '{not json'});
      final c = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
      addTearDown(c.dispose);
      expect(c.read(fakeApiProvider).signedInPhone, isNull);
    });
  });

  testWidgets('sign-up runs end to end on the test build', (tester) async {
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final prefs = await freshPrefs();
    final api = FakeApi();
    final auth = FakeAuthService(api, prefs);
    final container = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      fakeApiProvider.overrideWithValue(api),
      apiProvider.overrideWithValue(api),
      authServiceProvider.overrideWithValue(auth),
    ]);
    addTearDown(container.dispose);
    final GoRouter router = container.read(routerProvider);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    String at() => router.routerDelegate.currentConfiguration.uri.path;

    router.go('/home');
    await settle();
    expect(at(), '/login');
    expect(find.textContaining('the OTP is 123456'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '9876543210');
    await tester.pump(const Duration(seconds: 1)); // the button fades in once the number is valid
    await tester.tap(find.text('Get OTP'));
    await settle();
    expect(find.text('Enter the OTP'), findsOneWidget); // pushed on top of /login

    await tester.enterText(find.byType(TextField), '111111');
    await settle();
    expect(find.textContaining('OTP is incorrect'), findsOneWidget);
    expect(auth.signedIn, isFalse);

    await tester.enterText(find.byType(TextField), '123456');
    await settle();
    expect(at(), '/login/name');

    await tester.enterText(find.byType(TextField).first, 'Rahul');
    await tester.tap(find.text('Hatchback'));
    await settle();
    await tester.tap(find.text('Continue'));
    await settle();
    expect(at(), '/login/address');
    expect(auth.name, 'Rahul');

    await tester.tap(find.text('Skip, just browsing'));
    await settle();
    expect(at(), '/home');
    expect((await api.me()).name, 'Rahul');
  });
}
