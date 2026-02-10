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
    int selectedIndex = location == '/home' ? 0 : 1;

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          if (index == 0) {
            context.go('/home');
          } else {
            context.go('/squad');
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: PhosphorIcon(PhosphorIcons.monitor()),
            activeIcon: PhosphorIcon(
              PhosphorIcons.monitor(PhosphorIconsStyle.fill),
            ),
            label: 'Controls',
          ),
          BottomNavigationBarItem(
            icon: PhosphorIcon(PhosphorIcons.users()),
            activeIcon: PhosphorIcon(
              PhosphorIcons.users(PhosphorIconsStyle.fill),
            ),
            label: 'The Squad',
          ),
        ],
      ),
    );
  }
}
