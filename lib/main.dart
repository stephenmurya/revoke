import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/app_router.dart';
import 'core/models/plea_model.dart';
import 'core/native_bridge.dart';
import 'core/services/auth_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/schedule_service.dart';
import 'core/services/scoring_service.dart';
import 'core/services/squad_service.dart';
import 'core/services/theme_service.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await ThemeService.instance.loadTheme();
  await NotificationService.initialize();
  await NotificationService.subscribeToGlobalCitizensTopic();
  await AuthService.initializeMessagingTokenSync();
  NativeBridge.setupOverlayListener();
  ScoringService.initializePeriodicSync();

  runApp(const GlobalAppServices(child: AppRoot()));
}

class RevokeApp extends StatelessWidget {
  const RevokeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const GlobalAppServices(child: AppRoot());
  }
}

class GlobalAppServices extends StatefulWidget {
  final Widget child;
  const GlobalAppServices({super.key, required this.child});

  @override
  State<GlobalAppServices> createState() => _GlobalAppServicesState();
}

class _GlobalAppServicesState extends State<GlobalAppServices> {
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<List<PleaModel>>? _approvedPleasSubscription;
  final Set<String> _processedPleas = <String>{};
  String? _approvedPleasUid;

  @override
  void initState() {
    super.initState();
    debugPrint('[GlobalAppServices] init');
    _bindGlobalCallbacks();
    unawaited(_syncNativeScheduleStateOnce());
    _authSubscription = AuthService.authStateChanges.listen(_handleAuthChange);
    _handleAuthChange(AuthService.currentUser);
  }

  @override
  void dispose() {
    debugPrint('[GlobalAppServices] dispose');
    _authSubscription?.cancel();
    _approvedPleasSubscription?.cancel();
    super.dispose();
  }

  void _bindGlobalCallbacks() {
    NativeBridge.onShowOverlay = () {
      final uid = AuthService.currentUser?.uid;
      if (uid != null) {
        ScoringService.syncFocusScore(uid);
      }
      AppRouter.router.push('/lock_screen');
    };

    NativeBridge.onRequestPlea = (appName, packageName) {
      AppRouter.router.go(
        '/plea-compose',
        extra: {'appName': appName, 'packageName': packageName},
      );
    };

    NativeBridge.onBlockedAttempt = (appName, packageName, blockedAtMs) {
      ScoringService.recordBlockedAttempt(
        appName: appName,
        packageName: packageName,
        blockedAtMs: blockedAtMs,
      );
    };
  }

  Future<void> _syncNativeScheduleStateOnce() async {
    try {
      await ScheduleService.syncWithNative();
      debugPrint('[GlobalAppServices] native schedule state synced');
    } catch (_) {
      // Native sync is best-effort. Flutter routing must still boot cleanly.
    }
  }

  Future<void> _handleAuthChange(User? user) async {
    final nextUid = user?.uid.trim();
    if (_approvedPleasUid != nextUid) {
      debugPrint(
        '[GlobalAppServices] auth changed: uid=${nextUid ?? 'null'}; '
        'resetting approved-plea listener',
      );
      await _approvedPleasSubscription?.cancel();
      _approvedPleasSubscription = null;
      _processedPleas.clear();
      _approvedPleasUid = nextUid;

      if (nextUid != null && nextUid.isNotEmpty) {
        _approvedPleasSubscription = SquadService.getUserApprovedPleasStream(
          nextUid,
        ).listen(_handleApprovedPleas);
      }
    }

    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppRouter.router.refresh();
    });
  }

  void _handleApprovedPleas(List<PleaModel> pleas) {
    for (final plea in pleas) {
      if (_processedPleas.contains(plea.id)) continue;

      final packageName = plea.packageName.trim();
      final grantedMinutes = plea.durationMinutes > 0
          ? plea.durationMinutes
          : 5;
      if (packageName.isEmpty) {
        _processedPleas.add(plea.id);
        continue;
      }

      if (packageName.startsWith('regime-delete:')) {
        final regimeId = packageName.replaceFirst('regime-delete:', '').trim();
        if (regimeId.isNotEmpty) {
          ScheduleService.deleteSchedule(regimeId);
        }
      } else if (packageName.startsWith('regime:')) {
        NativeBridge.pauseMonitoring(grantedMinutes);
      } else {
        NativeBridge.temporaryUnlock(packageName, grantedMinutes);
      }
      _processedPleas.add(plea.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  late final Listenable _themeListenable;

  @override
  void initState() {
    super.initState();
    debugPrint('[AppRoot] init');
    _themeListenable = Listenable.merge([
      ThemeService.instance.themeMode,
      ThemeService.instance.accentColor,
    ]);
  }

  @override
  void dispose() {
    debugPrint('[AppRoot] dispose');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeListenable,
      builder: (context, _) {
        final accent = ThemeService.instance.accentColor.value;
        final mode = ThemeService.instance.themeMode.value;

        return MaterialApp.router(
          title: 'Revoke',
          debugShowCheckedModeBanner: false,
          routerConfig: AppRouter.router,
          theme: AppTheme.create(brightness: Brightness.light, accent: accent),
          darkTheme: AppTheme.create(
            brightness: Brightness.dark,
            accent: accent,
          ),
          themeMode: mode,
        );
      },
    );
  }
}
