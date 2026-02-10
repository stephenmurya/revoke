import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/navigation/main_shell.dart';
import '../features/monitor/home_screen.dart';
import '../features/social/squad_screen.dart';
import '../features/overlay/lock_screen.dart';
import '../features/permissions/permission_screen.dart';
import 'native_bridge.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/home',
    navigatorKey: _rootNavigatorKey,
    redirect: (context, state) async {
      final perms = await NativeBridge.checkPermissions();
      final hasAll =
          (perms['usage_stats'] ?? false) && (perms['overlay'] ?? false);

      final isGoingToPermissions = state.matchedLocation == '/permissions';

      if (!hasAll && !isGoingToPermissions) {
        return '/permissions';
      }

      if (hasAll && isGoingToPermissions) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/permissions',
        builder: (context, state) => const PermissionScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return MainShell(child: child);
        },
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/squad',
            builder: (context, state) => const SquadScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/lock_screen',
        builder: (context, state) => const LockScreen(),
      ),
    ],
  );
}
