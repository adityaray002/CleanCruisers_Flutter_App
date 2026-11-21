import 'package:cleancruisers_app/core/theme.dart';
import 'package:cleancruisers_app/data/api/fake/fake_api.dart';
import 'package:cleancruisers_app/data/auth_service.dart';
import 'package:cleancruisers_app/data/booking_cloud.dart' show OtpSession;
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
import 'package:cleancruisers_app/screens/splash_screen.dart';
import 'package:cleancruisers_app/screens/wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fixtures.dart';

/// Renders a screen at phone size and fails on any RenderFlex overflow.
Future<void> pumpAt(WidgetTester tester, Widget screen,
    {required double textScale,
    Map<String, Object> saved = const {},
    List<Override> overrides = const []}) async {
  SharedPreferences.setMockInitialValues(saved);
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize =
      const Size(360, 3000); // small phone, tall to lay out everything
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ProviderScope(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs), ...overrides],
    child: MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
            size: const Size(360, 3000),
            textScaler: TextScaler.linear(textScale)),
        child: screen,
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const ref = 'CC-7K4Q2X9M';
  // name -> (screen, saved data it starts with)
  final screens = <String, (Widget, Map<String, Object>)>{
    'Home': (const HomeScreen(), const {}),
    'Home (booked)': (const HomeScreen(), bookingPrefs()),
    'Home (book again)': (const HomeScreen(), repeatPrefs()),
    'Services': (const ServicesScreen(), const {}),
    'Services (detailing)': (
      const ServicesScreen(initialCategory: ServiceCategory.detailing),
      profile
    ),
    'Service detail (monthly)':
        (const ServiceDetailScreen(serviceId: 'monthly-3'), const {}),
    'Service detail (full detailing)':
        (const ServiceDetailScreen(serviceId: 'full-package'), const {}),
    'Bookings (empty)': (const BookingsScreen(), const {}),
    'Bookings (upcoming)': (const BookingsScreen(), bookingPrefs()),
    'Booking detail (waiting)': (
      const BookingDetailScreen(bookingRef: ref),
      bookingPrefs(confirmed: false)
    ),
    'Booking detail (confirmed)':
        (const BookingDetailScreen(bookingRef: ref), bookingPrefs()),
    'Booking detail (new time offered)':
        (const BookingDetailScreen(bookingRef: ref), holdPrefs()),
    'Booking detail (done)':
        (const BookingDetailScreen(bookingRef: ref), repeatPrefs()),
    'Profile': (const ProfileScreen(), profile),
    'Offers': (const WalletScreen(), profile),
    'My addresses': (const AddressesScreen(), bookingPrefs()),
    'My addresses (empty)': (const AddressesScreen(), const {}),
    'Login': (const LoginScreen(), const {}),
    'OTP': (
      const OtpScreen(session: OtpSession(phone: '9876543210')),
      const {}
    ),
    'Sign up: name and car': (const NameScreen(), const {}),
    'Sign up: address': (const AddressScreen(), const {}),
  };

  for (final scale in [1.0, 1.3]) {
    for (final e in screens.entries) {
      testWidgets('${e.key} has no overflow at text scale $scale',
          (tester) async {
        final (screen, prefs) = e.value;
        await pumpAt(tester, screen, textScale: scale, saved: prefs);
        expect(tester.takeException(), isNull);
      });
    }

    for (final e in {
      'Login (test build)': const LoginScreen(),
      'OTP (test build)': const OtpScreen(session: OtpSession(phone: '9876543210')),
    }.entries) {
      testWidgets('${e.key} has no overflow at text scale $scale', (tester) async {
        await pumpAt(tester, e.value, textScale: scale, overrides: [
          authServiceProvider.overrideWith(
              (ref) => FakeAuthService(FakeApi(), ref.watch(sharedPrefsProvider))),
        ]);
        expect(tester.takeException(), isNull);
      });
    }

    // Booking flow on the test-build server (contract §5).
    Future<void> step(WidgetTester t, String text) async {
      await t.tap(find.text(text).last);
      for (var i = 0; i < 5; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
    }

    final flows = <String, (Widget, Future<void> Function(WidgetTester)?)>{
      'Booking flow (plan)': (const BookingFlowScreen(serviceId: 'monthly-3'), null),
      'Booking flow (extras)': (const BookingFlowScreen(serviceId: 'wash-full'), null),
      'Booking flow: time': (
        const BookingFlowScreen(serviceId: 'wash-full'),
        (t) async {
          await step(t, 'Continue');
          await step(t, 'Tmrw');
          await step(t, '9:00 AM');
        }
      ),
      'Booking flow: review': (
        const BookingFlowScreen(serviceId: 'wash-full'),
        (t) async {
          await step(t, 'Continue');
          await step(t, 'Tmrw');
          await step(t, '9:00 AM');
          await step(t, 'Continue');
        }
      ),
      'Booking flow: plan review': (
        const BookingFlowScreen(serviceId: 'monthly-3'),
        (t) async {
          await step(t, 'Tmrw');
          await step(t, '9:00 AM');
          await step(t, 'Continue');
        }
      ),
    };
    for (final e in flows.entries) {
      testWidgets('${e.key} has no overflow at text scale $scale', (tester) async {
        final (screen, interact) = e.value;
        await pumpAt(tester, screen,
            textScale: scale, saved: profile, overrides: fakeOverrides(fixtureApi()));
        if (interact != null) await interact(tester);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Booking sent has no overflow at text scale $scale', (tester) async {
      final api = fixtureApi();
      await pumpAt(
          tester,
          AfterRequest(api: api, then: (ref) => BookingSentScreen(bookingRef: ref)),
          textScale: scale,
          saved: profile,
          overrides: fakeOverrides(api));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Slot requested'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Splash renders at text scale $scale, then goes home',
        (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(initialLocation: '/splash', routes: [
        GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
        GoRoute(path: '/home', builder: (_, __) => const Text('HOME')),
      ]);
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 1600));
      expect(tester.takeException(), isNull);
      expect(find.text('HOME'), findsNothing);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      expect(find.text('HOME'), findsOneWidget);
    });
  }
}
