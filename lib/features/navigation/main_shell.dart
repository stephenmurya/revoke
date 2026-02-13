import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Get the current location to determine which tab is active
    final String location = GoRouterState.of(context).uri.toString();
    int selectedIndex = 0;
    if (location.startsWith('/squad')) {
      selectedIndex = 1;
    } else if (location.startsWith('/analytics')) {
      selectedIndex = 2;
    } else if (location.startsWith('/controls')) {
      selectedIndex = 3;
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/home');
              break;
            case 1:
              context.go('/squad');
              break;
            case 2:
              context.go('/analytics');
              break;
            case 3:
              context.go('/controls');
              break;
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: PhosphorIcon(PhosphorIcons.monitor()),
            activeIcon: PhosphorIcon(
              PhosphorIcons.monitor(PhosphorIconsStyle.fill),
            ),
            label: 'Regimes',
          ),
          BottomNavigationBarItem(
            icon: PhosphorIcon(PhosphorIcons.users()),
            activeIcon: PhosphorIcon(
              PhosphorIcons.users(PhosphorIconsStyle.fill),
            ),
            label: 'The Squad',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            activeIcon: Icon(Icons.bar_chart_rounded),
            label: 'Analytics',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Controls',
          ),
        ],
      ),
    );
  }
}
