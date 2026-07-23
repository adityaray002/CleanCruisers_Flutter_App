import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../screens/main_shell.dart';
import '../screens/home_screen.dart';
import '../screens/booking_screen.dart';
import '../screens/booking_success_screen.dart';
import '../screens/blog_list_screen.dart';
import '../screens/blog_detail_screen.dart';
import '../screens/contact_screen.dart';
import '../screens/onboarding_screen.dart';
import 'constants.dart';

final onboardingDoneProvider = StateProvider<bool>((ref) => false);

final routerProvider = Provider<GoRouter>((ref) {
  final onboardingDone = ref.watch(onboardingDoneProvider);
  return GoRouter(
    initialLocation: onboardingDone ? '/home' : '/onboarding',
    redirect: (context, state) {
      if (state.uri.toString() == '/') return '/home';
      return null;
    },
    errorBuilder: (context, state) => const _NotFoundScreen(),
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      ShellRoute(
        builder: (ctx, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home',    builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/blog',    builder: (_, __) => const BlogListScreen()),
          GoRoute(path: '/contact', builder: (_, __) => const ContactScreen()),
        ],
      ),
      GoRoute(
        path: '/booking',
        builder: (_, state) {
          final service = state.uri.queryParameters['service'];
          return BookingScreen(preselectedService: service);
        },
      ),
      GoRoute(
        path: '/booking-success',
        builder: (_, __) => const BookingSuccessScreen(),
      ),
      GoRoute(
        path: '/blog/:id',
        builder: (_, state) =>
            BlogDetailScreen(id: state.pathParameters['id']!),
      ),
    ],
  );
});

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgBlack,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('404', style: TextStyle(
                color: kGreen400, fontSize: 72, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('Page not found',
                style: TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}
