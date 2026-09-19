import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bottom-navigation shell for the four main sections of the app. Each
/// branch keeps its own navigation stack/state via [StatefulShellRoute].
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Головна'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Теми'),
          NavigationDestination(
              icon: Icon(Icons.smart_display_outlined),
              selectedIcon: Icon(Icons.smart_display),
              label: 'Відео'),
          // "Громадянство" is too wide for a fifth of a phone screen and got
          // clipped; the screen itself still says "Підготовка до співбесіди".
          NavigationDestination(
              icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag), label: 'Співбесіда'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Профіль'),
        ],
      ),
    );
  }
}
