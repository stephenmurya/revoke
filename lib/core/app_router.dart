import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/navigation/main_shell.dart';
import '../features/monitor/home_screen.dart';
import '../features/squad/squad_screen.dart';
import '../features/squad/tribunal_screen.dart';
import '../features/overlay/lock_screen.dart';
import '../features/permissions/permission_screen.dart';
import '../features/home/focus_score_detail_screen.dart';
import '../features/plea/plea_compose_screen.dart';

import '../core/services/auth_service.dart';
import '../features/auth/onboarding_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/profile/profile_screen.dart';
import 'native_bridge.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    navigatorKey: _rootNavigatorKey,
    redirect: (context, state) async {
      final user = AuthService.currentUser;
      final isGoingToOnboarding = state.matchedLocation == '/onboarding';
      final isSplash = state.matchedLocation == '/';
      final isPermissions = state.matchedLocation == '/permissions';
      final isShareSquadResume =
          state.uri.queryParameters['step'] == 'share_squad';

      if (user == null) {
        if (isSplash || isGoingToOnboarding) return null;
        return '/onboarding';
      }

      final userData = await AuthService.getUserData();
      final squadId = (userData?['squadId'] as String?)?.trim();
      final nickname = (userData?['nickname'] as String?)?.trim();
      final hasSquad = squadId != null && squadId.isNotEmpty;
      final hasNickname = nickname != null && nickname.isNotEmpty;

      if (hasSquad && (isSplash || isGoingToOnboarding)) {
        return '/home';
      }

      if (!hasSquad &&
          hasNickname &&
          isGoingToOnboarding &&
          !isShareSquadResume) {
        return '/onboarding?step=share_squad';
      }

      if (isSplash) {
        if (hasSquad) return '/home';
        if (hasNickname) return '/onboarding?step=share_squad';
        return '/onboarding';
      }

      try {
        final perms = await NativeBridge.checkPermissions();
        final hasAll =
            (perms['usage_stats'] ?? false) && (perms['overlay'] ?? false);

        if (isPermissions) {
          if (hasAll) {
            if (hasSquad) return '/home';
            if (hasNickname) return '/onboarding?step=share_squad';
            return '/onboarding';
          }
          return null;
        }

        if (!hasAll) {
          return '/permissions';
        }

        if (!hasSquad && hasNickname && !isGoingToOnboarding) {
          return '/onboarding?step=share_squad';
        }
        if (!hasSquad && !hasNickname && !isGoingToOnboarding) {
          return '/onboarding';
        }

        return null;
      } catch (e) {
        print("Router Error: $e");
        return null;
      }
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
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
      GoRoute(
        path: '/plea-compose',
        builder: (context, state) {
          final extra = state.extra as Map?;
          final appName = (extra?['appName'] as String?)?.trim();
          final packageName = (extra?['packageName'] as String?)?.trim();
          if (appName == null ||
              appName.isEmpty ||
              packageName == null ||
              packageName.isEmpty) {
            return const HomeScreen();
          }
          return BegForTimeScreen(appName: appName, packageName: packageName);
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/focus-score',
        builder: (context, state) => const FocusScoreDetailScreen(),
      ),
      GoRoute(
        path: '/tribunal/:pleaId',
        builder: (context, state) {
          final pleaId = (state.pathParameters['pleaId'] ?? '').trim();
          if (pleaId.isEmpty) return const SquadScreen();
          return TribunalScreen(pleaId: pleaId);
        },
      ),
    ],
  );
}
