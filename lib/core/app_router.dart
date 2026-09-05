import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../features/navigation/main_shell.dart';
import '../features/today/today_screen.dart';
import '../features/circle/circle_screen.dart';
import '../features/circle/override_history_screen.dart';
import '../features/circle/override_policy_screen.dart';
import '../features/circle/override_request_screen.dart';
import '../features/squad/tribunal_screen.dart';
import '../features/permissions/permission_screen.dart';
import '../features/home/focus_score_detail_screen.dart';
import '../features/monitor/create_schedule_screen.dart';
import '../features/commitments/commitments_screen.dart';
import '../features/commitments/commitment_detail_screen.dart';
import '../features/commitments/commitment_presentation.dart';
import '../features/commitments/create_commitment_screen.dart';
import '../features/insights/insights_screen.dart';
import '../features/settings/controls_hub_screen.dart';
import '../features/settings/appearance_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/settings/notifications_screen.dart'
    as settings_notifications;
import '../features/admin/god_mode_dashboard.dart';
import '../features/admin/ui_tests/prototypes/squad_hud_v2_prototype.dart';
import '../features/admin/ui_tests/ui_test_directory_screen.dart';
import '../core/models/schedule_model.dart';

import '../core/services/auth_service.dart';
import 'models/onboarding_state.dart';
import 'services/onboarding_state_service.dart';
import '../features/auth/onboarding_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/premium/premium_paywall_screen.dart';
import '../features/credits/credit_details_screen.dart';
import '../features/credits/credit_backing_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  static const Duration _cacheTtl = Duration(seconds: 8);

  static String? _cachedUid;
  static bool? _cachedIsAdmin;
  static DateTime? _cachedIsAdminAt;
  static Future<bool>? _pendingAdminCheck;
  static OnboardingState? _cachedOnboardingState;
  static String? _cachedOnboardingUid;
  static Future<OnboardingState>? _pendingOnboardingState;

  static void clearSessionCaches() {
    _cachedUid = null;
    _cachedIsAdmin = null;
    _cachedIsAdminAt = null;
    _pendingAdminCheck = null;
    _cachedOnboardingState = null;
    _cachedOnboardingUid = null;
    _pendingOnboardingState = null;
  }

  static void invalidateOnboardingCache() {
    _cachedOnboardingState = null;
    _cachedOnboardingUid = null;
    _pendingOnboardingState = null;
  }

  static Future<OnboardingState> _getOnboardingState(String uid) async {
    if (_cachedOnboardingUid == uid && _cachedOnboardingState != null) {
      return _cachedOnboardingState!;
    }
    if (_cachedOnboardingUid != uid) {
      _cachedOnboardingUid = uid;
      _cachedOnboardingState = null;
    }
    _pendingOnboardingState ??= OnboardingStateService.loadOrCreate()
        .then((state) {
          _cachedOnboardingUid = uid;
          _cachedOnboardingState = state;
          return state;
        })
        .whenComplete(() => _pendingOnboardingState = null);
    return _pendingOnboardingState!;
  }

  static bool _isAdminLocation(String location) {
    return location == '/god-mode' || location.startsWith('/admin/');
  }

  static Future<bool> _getCachedIsAdmin(User user) async {
    final now = DateTime.now();
    if (_cachedIsAdmin != null &&
        _cachedIsAdminAt != null &&
        now.difference(_cachedIsAdminAt!) < _cacheTtl) {
      return _cachedIsAdmin!;
    }

    _pendingAdminCheck ??= user
        .getIdTokenResult()
        .then((result) {
          final isAdmin = result.claims?['admin'] == true;
          _cachedIsAdmin = isAdmin;
          _cachedIsAdminAt = DateTime.now();
          return isAdmin;
        })
        .catchError((_) {
          _cachedIsAdmin = false;
          _cachedIsAdminAt = DateTime.now();
          return false;
        })
        .whenComplete(() => _pendingAdminCheck = null);

    return _pendingAdminCheck!;
  }

  static final router = GoRouter(
    initialLocation: '/',
    navigatorKey: _rootNavigatorKey,
    redirect: (context, state) async {
      final user = AuthService.currentUser;
      final location = state.matchedLocation;
      final isGoingToOnboarding = location == '/onboarding';
      final forceAuth = state.uri.queryParameters['force_auth'] == '1';

      if (user == null) {
        clearSessionCaches();
        // Never stay on splash when unauthenticated; route to onboarding.
        if (isGoingToOnboarding) return null;
        return '/onboarding';
      }

      if (forceAuth && isGoingToOnboarding) {
        return null;
      }

      if (_cachedUid != user.uid) {
        clearSessionCaches();
        _cachedUid = user.uid;
      }
      final isAdminLocation = _isAdminLocation(location);

      if (isAdminLocation) {
        final isAdmin = await _getCachedIsAdmin(user);
        if (!isAdmin) {
          return '/onboarding';
        }
      }

      try {
        final onboarding = await _getOnboardingState(user.uid);
        return OnboardingRoutePolicy.redirect(
          authenticated: true,
          complete: onboarding.isComplete,
          location: location,
          forceAuth: forceAuth,
        );
      } catch (_) {
        // Conservative failure: an authenticated user with no readable
        // onboarding record resumes onboarding rather than entering the app
        // with an unknown setup state.
        if (!isGoingToOnboarding) return '/onboarding';
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
            builder: (context, state) => const TodayScreen(),
          ),
          GoRoute(
            path: '/commitments',
            builder: (context, state) => const CommitmentsScreen(),
          ),
          // Legacy route alias (pre-rename). Keeps older deep links / restored state working.
          GoRoute(path: '/marketplace', redirect: (context, state) => '/home'),
          GoRoute(
            path: '/squad',
            builder: (context, state) => const CircleScreen(),
          ),
          GoRoute(
            path: '/insights',
            builder: (context, state) => const InsightsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/insights/app',
        builder: (context, state) {
          final packageName =
              state.uri.queryParameters['packageName']?.trim() ?? '';
          if (packageName.isEmpty) return const InsightsScreen();
          return AppInsightsScreen(packageName: packageName);
        },
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
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
        path: '/settings/notifications',
        builder: (context, state) =>
            const settings_notifications.NotificationsScreen(),
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
            return const TodayScreen();
          }
          final commitmentId =
              (extra?['commitmentId'] as String?)?.trim() ?? '';
          return OverrideRequestScreen(
            appName: appName,
            packageName: packageName,
            commitmentId: commitmentId,
          );
        },
      ),
      GoRoute(
        path: '/override-history',
        builder: (context, state) => const OverrideHistoryScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/premium',
        builder: (context, state) =>
            PremiumPaywallScreen(reason: (state.extra as String?)?.trim()),
      ),
      GoRoute(
        path: '/credits',
        builder: (context, state) => const CreditDetailsScreen(),
      ),
      GoRoute(
        path: '/commitment/back',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is CommitmentViewModel) {
            return CreditBackingScreen(commitment: extra);
          }
          return const CommitmentsScreen();
        },
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
        path: '/commitment/new',
        builder: (context, state) => const CreateCommitmentScreen(),
      ),
      GoRoute(
        path: '/commitment/detail',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is CommitmentViewModel) {
            return CommitmentDetailScreen(commitment: extra);
          }
          return const CommitmentsScreen();
        },
      ),
      GoRoute(
        path: '/commitment/edit',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is CommitmentViewModel) {
            return CreateCommitmentScreen(
              existingSchedule: extra.sourceSchedule,
              existingPlan: extra.taperPlan,
            );
          }
          return const CommitmentsScreen();
        },
      ),
      GoRoute(
        path: '/commitment/override-policy',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is CommitmentViewModel) {
            return OverridePolicyScreen(commitment: extra);
          }
          return const CommitmentsScreen();
        },
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
        path: '/admin/ui-tests',
        builder: (context, state) => const UITestDirectoryScreen(),
      ),
      GoRoute(
        path: '/admin/ui-tests/squad-hud-v2',
        builder: (context, state) => const SquadHudV2Prototype(),
      ),
      GoRoute(
        path: '/tribunal/:pleaId',
        builder: (context, state) {
          final pleaId = (state.pathParameters['pleaId'] ?? '').trim();
          if (pleaId.isEmpty) return const CircleScreen();
          return TribunalScreen(pleaId: pleaId);
        },
      ),
    ],
  );
}
