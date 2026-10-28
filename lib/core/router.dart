import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/service.dart';
import '../screens/blog_detail_screen.dart';
import '../screens/blog_list_screen.dart';
import '../screens/booking/booking_flow_screen.dart';
import '../screens/booking_detail_screen.dart';
import '../screens/booking_sent_screen.dart';
import '../screens/bookings_screen.dart';
import '../screens/home_screen.dart';
import '../screens/main_shell.dart';
import '../screens/profile_screen.dart';
import '../screens/service_detail_screen.dart';
import '../screens/services_screen.dart';
import '../screens/splash_screen.dart';
import '../widgets/ui.dart';
import 'pricing.dart';

NoTransitionPage<void> _tab(Widget child) => NoTransitionPage(child: child);

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) => state.uri.path == '/' ? '/home' : null,
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(),
      body: Center(
        child: EmptyState(
          icon: Icons.explore_off_outlined,
          title: 'Page not found',
          message: 'This link doesn\'t lead anywhere.',
          action: PrimaryButton(
              label: 'Go to home',
              expand: false,
              onPressed: () => context.go('/home')),
        ),
      ),
    ),
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      ShellRoute(
        builder: (_, __, child) => MainShell(child: child),
        routes: [
          GoRoute(
              path: '/home', pageBuilder: (_, __) => _tab(const HomeScreen())),
          GoRoute(
            path: '/services',
            pageBuilder: (_, s) {
              final cat = s.uri.queryParameters['cat'];
              return _tab(ServicesScreen(
                key: ValueKey(cat),
                initialCategory: ServiceCategory.values
                    .where((c) => c.name == cat)
                    .firstOrNull,
              ));
            },
          ),
          GoRoute(
              path: '/bookings',
              pageBuilder: (_, __) => _tab(const BookingsScreen())),
          GoRoute(
              path: '/profile',
              pageBuilder: (_, __) => _tab(const ProfileScreen())),
        ],
      ),
      GoRoute(
        path: '/service/:id',
        builder: (_, s) =>
            ServiceDetailScreen(serviceId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/book/:id',
        builder: (_, s) {
          final car = s.uri.queryParameters['car'];
          return BookingFlowScreen(
            serviceId: s.pathParameters['id']!,
            initialCar: CarType.values.where((c) => c.name == car).firstOrNull,
          );
        },
      ),
      GoRoute(
        path: '/booking-sent/:ref',
        builder: (_, s) =>
            BookingSentScreen(bookingRef: s.pathParameters['ref']!),
      ),
      GoRoute(
        path: '/bookings/:ref',
        builder: (_, s) =>
            BookingDetailScreen(bookingRef: s.pathParameters['ref']!),
      ),
      GoRoute(path: '/blog', builder: (_, __) => const BlogListScreen()),
      GoRoute(
        path: '/blog/:id',
        builder: (_, s) => BlogDetailScreen(id: s.pathParameters['id']!),
      ),
    ],
  );
});
