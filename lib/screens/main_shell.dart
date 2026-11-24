import '../providers/booking_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _tabs = ['/home', '/bookings', '/wallet', '/profile'];

  int _index(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    final i = _tabs.indexWhere((t) => loc.startsWith(t));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming =
        ref.watch(myApiBookingsProvider).valueOrNull?.upcoming.length ?? 0;
    final index = _index(context);

    return AutoRefresh(
        onTick: (ref) => ref.invalidate(myApiBookingsProvider),
        // Only Home closes the app; every other screen in the shell
        // (including Services, which has no tab) goes back to Home.
        //
        // The PopScope tells Android the app handles back on those screens:
        // with predictive back (Android 14+) the system otherwise closes the
        // app without asking. The BackButtonListener then does the work.
        child: PopScope(
            canPop: GoRouterState.of(context).uri.path.startsWith('/home'),
            child: BackButtonListener(
              onBackButtonPressed: () async {
                if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
                if (GoRouterState.of(context).uri.path.startsWith('/home')) {
                  return false;
                }
                context.go('/home');
                return true;
              },
              child: Scaffold(
                body: child,
                bottomNavigationBar:
                    Column(mainAxisSize: MainAxisSize.min, children: [
                  DecoratedBox(
                    decoration: const BoxDecoration(
                        border:
                            Border(top: BorderSide(color: AppColors.border))),
                    child: NavigationBar(
                      selectedIndex: index,
                      labelBehavior:
                          NavigationDestinationLabelBehavior.alwaysShow,
                      onDestinationSelected: (i) => context.go(_tabs[i]),
                      destinations: [
                        const NavigationDestination(
                          icon: Icon(Icons.home_outlined),
                          selectedIcon: Icon(Icons.home_rounded),
                          label: 'Home',
                        ),
                        NavigationDestination(
                          icon: Badge(
                            isLabelVisible: upcoming > 0,
                            label: Text('$upcoming'),
                            backgroundColor: AppColors.primary,
                            child: const Icon(Icons.event_note_outlined),
                          ),
                          selectedIcon: const Icon(Icons.event_note_rounded),
                          label: 'My Bookings',
                        ),
                        const NavigationDestination(
                          icon: Icon(Icons.local_offer_outlined),
                          selectedIcon: Icon(Icons.local_offer_rounded),
                          label: 'Offers',
                        ),
                        const NavigationDestination(
                          icon: Icon(Icons.person_outline_rounded),
                          selectedIcon: Icon(Icons.person_rounded),
                          label: 'Profile',
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            )));
  }
}
