import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/constants.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    if (loc.startsWith('/blog')) return 2;
    if (loc.startsWith('/contact')) return 3;
    return 0; // home
  }

  @override
  Widget build(BuildContext context) {
    final idx = _currentIndex(context);
    return Scaffold(
      body: child,
      floatingActionButton: idx == 0
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/booking'),
              backgroundColor: kGreen400,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.local_car_wash, size: 20),
              label: const Text('Book Now',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: kGray700, width: 0.5)),
        ),
        child: NavigationBar(
          backgroundColor: kBgCard,
          indicatorColor: kGreen400.withAlpha(40),
          selectedIndex: idx,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (i) {
            switch (i) {
              case 0: context.go('/home'); break;
              case 1: context.push('/booking'); break;
              case 2: context.go('/blog'); break;
              case 3: context.go('/contact'); break;
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: kGreen400),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.local_car_wash_outlined),
              selectedIcon: Icon(Icons.local_car_wash, color: kGreen400),
              label: 'Book',
            ),
            NavigationDestination(
              icon: Icon(Icons.article_outlined),
              selectedIcon: Icon(Icons.article, color: kGreen400),
              label: 'Blog',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: kGreen400),
              label: 'Contact',
            ),
          ],
        ),
      ),
    );
  }
}
