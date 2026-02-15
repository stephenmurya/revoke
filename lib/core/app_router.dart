import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/navigation/main_shell.dart';
import '../features/navigation/placeholder_screen.dart';
import '../features/regimes/regimes_screen.dart';
import '../features/regimes/challenges_screen.dart';
import '../features/squad/squad_screen.dart';
import '../features/squad/tribunal_screen.dart';
import '../features/overlay/lock_screen.dart';
import '../features/permissions/permission_screen.dart';
import '../features/home/focus_score_detail_screen.dart';
import '../features/plea/plea_compose_screen.dart';
import '../features/monitor/create_schedule_screen.dart';
import '../features/settings/controls_hub_screen.dart';
import '../features/settings/appearance_screen.dart';
import '../features/admin/god_mode_dashboard.dart';
import '../core/models/schedule_model.dart';

import '../core/services/auth_service.dart';
import '../features/auth/onboarding_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/profile/profile_screen.dart';
import 'native_bridge.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  static const Duration _cacheTtl = Duration(seconds: 8);

  static String? _cachedUid;
  static Map<String, dynamic>? _cachedUserData;
  static DateTime? _cachedUserDataAt;
  static Future<Map<String, dynamic>?>? _pendingUserDataFetch;

  static bool? _cachedHasAllPermissions;
  static DateTime? _cachedPermissionsAt;
  static Future<bool>? _pendingPermissionsCheck;

  static bool _hasSessionBootstrap = false;

  static bool _isShellLocation(String location) {
    return location == '/home' ||
        location == '/challenges' ||
        location == '/squad';
  }

  static void clearSessionCaches() {
    _cachedUid = null;
    _cachedUserData = null;
    _cachedUserDataAt = null;
    _pendingUserDataFetch = null;
    _cachedHasAllPermissions = null;
    _cachedPermissionsAt = null;
    _pendingPermissionsCheck = null;
    _hasSessionBootstrap = false;
  }

  static Future<Map<String, dynamic>?> _getCachedUserData(String uid) async {
    final now = DateTime.now();
    if (_cachedUid != uid) {
      clearSessionCaches();
      _cachedUid = uid;
    }

    if (_cachedUserData != null &&
        _cachedUserDataAt != null &&
        now.difference(_cachedUserDataAt!) < _cacheTtl) {
      return _cachedUserData;
    }

    _pendingUserDataFetch ??= AuthService.getUserData()
        .then((data) {
          _cachedUserData = data;
          _cachedUserDataAt = DateTime.now();
          return data;
        })
        .whenComplete(() => _pendingUserDataFetch = null);

    return _pendingUserDataFetch!;
  }

  static Future<bool> _getCachedPermissions() async {
    final now = DateTime.now();
    if (_cachedHasAllPermissions != null &&
        _cachedPermissionsAt != null &&
        now.difference(_cachedPermissionsAt!) < _cacheTtl) {
      return _cachedHasAllPermissions!;
    }

    _pendingPermissionsCheck ??= NativeBridge.checkPermissions()
        .then((perms) {
          final hasAll =
              (perms['usage_stats'] ?? false) &&
              (perms['overlay'] ?? false) &&
              (perms['battery_optimization_ignored'] ?? false);
          _cachedHasAllPermissions = hasAll;
          _cachedPermissionsAt = DateTime.now();
          return hasAll;
        })
        .whenComplete(() => _pendingPermissionsCheck = null);

    return _pendingPermissionsCheck!;
  }

  static final router = GoRouter(
    initialLocation: '/',
    navigatorKey: _rootNavigatorKey,
    redirect: (context, state) async {
      final user = AuthService.currentUser;
      final location = state.matchedLocation;
      final isGoingToOnboarding = location == '/onboarding';
      final isSplash = location == '/';
      final isPermissions = location == '/permissions';
      final isShellLocation = _isShellLocation(location);
      final forceAuth = state.uri.queryParameters['force_auth'] == '1';
      final isShareSquadResume =
          state.uri.queryParameters['step'] == 'share_squad';

      if (user == null) {
        clearSessionCaches();
        if (isSplash || isGoingToOnboarding) return null;
        return '/onboarding';
      }

      if (forceAuth && isGoingToOnboarding) {
        return null;
      }

      if (_cachedUid != user.uid) {
        clearSessionCaches();
        _cachedUid = user.uid;
      }

      if (_hasSessionBootstrap && isShellLocation) {
        return null;
      }

      final userData = await _getCachedUserData(user.uid);
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
        final hasAll = await _getCachedPermissions();

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

        if (hasAll && hasSquad && isShellLocation) {
          _hasSessionBootstrap = true;
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
            builder: (context, state) => const RegimesScreen(),
          ),
          // Legacy route alias (pre-rename). Keeps older deep links / restored state working.
          GoRoute(
            path: '/marketplace',
            redirect: (context, state) => '/challenges',
          ),
          GoRoute(
            path: '/challenges',
            builder: (context, state) => const ChallengesScreen(),
          ),
          GoRoute(
            path: '/squad',
            builder: (context, state) => const SquadScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/analytics',
        builder: (context, state) => const PlaceholderScreen(title: 'Analytics'),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) =>
            const PlaceholderScreen(title: 'Notifications'),
      ),
      GoRoute(
        path: '/controls',
        builder: (context, state) => const ControlsHubScreen(),
      ),
      GoRoute(
        path: '/settings/appearance',
        builder: (context, state) => const AppearanceScreen(),
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
            return const RegimesScreen();
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
        path: '/regime/new',
        builder: (context, state) => const CreateScheduleScreen(),
      ),
      GoRoute(
        path: '/regime/edit',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is ScheduleModel) {
            return CreateScheduleScreen(existingSchedule: extra);
          }
          return const CreateScheduleScreen();
        },
      ),
      GoRoute(
        path: '/god-mode',
        builder: (context, state) => const GodModeDashboard(),
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
