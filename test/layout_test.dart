import 'package:cleancruisers_app/core/theme.dart';
import 'package:cleancruisers_app/providers/app_providers.dart';
import 'package:cleancruisers_app/screens/booking/booking_flow_screen.dart';
import 'package:cleancruisers_app/screens/bookings_screen.dart';
import 'package:cleancruisers_app/screens/home_screen.dart';
import 'package:cleancruisers_app/screens/profile_screen.dart';
import 'package:cleancruisers_app/screens/service_detail_screen.dart';
import 'package:cleancruisers_app/screens/services_screen.dart';
import 'package:cleancruisers_app/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders a screen at phone size and fails on any RenderFlex overflow.
Future<void> pumpAt(WidgetTester tester, Widget screen,
    {required double textScale}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize =
      const Size(360, 3000); // small phone, tall to lay out everything
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ProviderScope(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
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

  final screens = <String, Widget>{
    'Home': const HomeScreen(),
    'Services': const ServicesScreen(),
    'Service detail (monthly)':
        const ServiceDetailScreen(serviceId: 'monthly-3'),
    'Service detail (full detailing)':
        const ServiceDetailScreen(serviceId: 'full-package'),
    'Booking flow': const BookingFlowScreen(serviceId: 'monthly-3'),
    'Bookings (empty)': const BookingsScreen(),
    'Profile': const ProfileScreen(),
  };

  for (final scale in [1.0, 1.3]) {
    for (final e in screens.entries) {
      testWidgets('${e.key} has no overflow at text scale $scale',
          (tester) async {
        await pumpAt(tester, e.value, textScale: scale);
        expect(tester.takeException(), isNull);
      });
    }

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
