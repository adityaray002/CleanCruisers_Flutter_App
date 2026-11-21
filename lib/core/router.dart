import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/booking_cloud.dart';
import '../providers/api_providers.dart';
import '../models/service.dart';
import '../providers/app_providers.dart';
import '../screens/addresses_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/blog_detail_screen.dart';
import '../screens/blog_list_screen.dart';
import '../screens/booking/booking_flow_screen.dart';
import '../screens/booking_detail_screen.dart';
import '../screens/booking_sent_screen.dart';
import '../screens/bookings_screen.dart';
import '../screens/home_screen.dart';
import '../screens/main_shell.dart';
import '../screens/ops/ops_dashboard_screen.dart';
import '../screens/ops/ops_login_screen.dart';
import '../screens/plans_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/referral_screen.dart';
import '../screens/service_detail_screen.dart';
import '../screens/services_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/test_tools_screen.dart';
import '../screens/wallet_screen.dart';
import '../widgets/ui.dart';
import 'pricing.dart';

NoTransitionPage<void> _tab(Widget child) => NoTransitionPage(child: child);

/// Re-runs the router's redirect whenever the signed-in user changes.
class _AuthRefresh extends ChangeNotifier {
  late final StreamSubscription<Object?> _sub;
  _AuthRefresh(Stream<Object?> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  /// Something else the redirect depends on changed (the saved profile).
  void ping() => notifyListeners();

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// Customers log in with a phone OTP, then give their name, car and address
/// once (so bookings never ask for them). The staff desk
/// (/ops) has its own email login. Builds where OTP login isn't available
/// (no Firebase, not a test build) skip the gate (booking then fails closed).
String? authRedirect(
  String path, {
  required bool configured,
  required bool signedIn,
  required bool hasName,
  bool hasSetup = true,
}) {
  if (path == '/') return '/home';
  if (path == '/splash' || path.startsWith('/ops') || !configured) return null;
  final onLogin = path.startsWith('/login');
  const onboarding = {'/login/name', '/login/address'};
  if (!signedIn) {
    return onLogin && !onboarding.contains(path) ? null : '/login';
  }
  if (!hasName) return path == '/login/name' ? null : '/login/name';
  if (!hasSetup) return path == '/login/address' ? null : '/login/address';
  return onLogin ? '/home' : null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authServiceProvider);
  final refresh = _AuthRefresh(auth.changes);
  ref.onDispose(refresh.dispose);
  ref.listen(profileProvider.select((p) => p.ready), (_, __) => refresh.ping());
  ref.listen(setupSkippedProvider, (_, __) => refresh.ping());
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) => authRedirect(
      state.uri.path,
      configured: auth.available,
      signedIn: auth.signedIn,
      hasName: auth.name != null,
      hasSetup:
          ref.read(profileProvider).ready || ref.read(setupSkippedProvider),
    ),
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
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/login/otp',
        redirect: (_, s) => s.extra is OtpSession ? null : '/login',
        builder: (_, s) => OtpScreen(session: s.extra! as OtpSession),
      ),
      GoRoute(path: '/login/name', builder: (_, __) => const NameScreen()),
      GoRoute(
          path: '/login/address', builder: (_, __) => const AddressScreen()),
      GoRoute(path: '/ops/login', builder: (_, __) => const OpsLoginScreen()),
      GoRoute(path: '/ops', builder: (_, __) => const OpsDashboardScreen()),
      if (kFakeServer)
        GoRoute(path: '/test-tools', builder: (_, __) => const TestToolsScreen()),
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
          // CleanCredit: credit balance + offers (coupons).
          GoRoute(
              path: '/wallet',
              pageBuilder: (_, __) => _tab(const WalletScreen())),
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
            planId: s.uri.queryParameters['plan'],
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
      GoRoute(path: '/addresses', builder: (_, __) => const AddressesScreen()),
      GoRoute(path: '/plans', builder: (_, __) => const PlansScreen()),
      GoRoute(path: '/referral', builder: (_, __) => const ReferralScreen()),
      GoRoute(path: '/blog', builder: (_, __) => const BlogListScreen()),
      GoRoute(
        path: '/blog/:id',
        builder: (_, s) => BlogDetailScreen(id: s.pathParameters['id']!),
      ),
    ],
  );
});
