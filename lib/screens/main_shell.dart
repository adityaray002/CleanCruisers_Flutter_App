import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../providers/app_providers.dart';

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _tabs = ['/home', '/services', '/bookings', '/profile'];

  int _index(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    final i = _tabs.indexWhere((t) => loc.startsWith(t));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming =
        ref.watch(bookingsProvider).where((b) => b.isUpcoming()).length;
    final index = _index(context);
    // Back from any tab other than Home returns to Home instead of closing
    // the app; only Home lets the system back gesture exit. A PopScope here
    // is never consulted: go_router only asks the tabs' nested navigator,
    // which has a single page, so listen to the back button directly.
    return BackButtonListener(
      onBackButtonPressed: () async {
        // A pushed screen (service detail, booking…) handles its own back.
        if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
        if (_index(context) == 0) return false;
        context.go('/home');
        return true;
      },
      child: Scaffold(
        body: child,
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border))),
          child: NavigationBar(
            selectedIndex: index,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (i) => context.go(_tabs[i]),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              const NavigationDestination(
                icon: Icon(Icons.local_car_wash_outlined),
                selectedIcon: Icon(Icons.local_car_wash_rounded),
                label: 'Services',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: upcoming > 0,
                  label: Text('$upcoming'),
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.event_note_outlined),
                ),
                selectedIcon: const Icon(Icons.event_note_rounded),
                label: 'Bookings',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
