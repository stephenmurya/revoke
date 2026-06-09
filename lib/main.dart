import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_router.dart';
import 'core/models/plea_model.dart';
import 'core/native_bridge.dart';
import 'core/services/auth_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/schedule_service.dart';
import 'core/services/scoring_service.dart';
import 'core/services/settings_sync_service.dart';
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

class _GlobalAppServicesState extends State<GlobalAppServices>
    with WidgetsBindingObserver {
  static const int _maxProcessedApprovedPleas = 250;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<List<PleaModel>>? _approvedPleasSubscription;
  final Set<String> _processedPleas = <String>{};
  String? _approvedPleasUid;

  @override
  void initState() {
    super.initState();
    debugPrint('[GlobalAppServices] init');
    WidgetsBinding.instance.addObserver(this);
    _bindGlobalCallbacks();
    unawaited(_checkAndReviveNativeService());
    unawaited(_syncNativeScheduleStateOnce());
    _authSubscription = AuthService.authStateChanges.listen(_handleAuthChange);
    _handleAuthChange(AuthService.currentUser);
  }

  @override
  void dispose() {
    debugPrint('[GlobalAppServices] dispose');
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _approvedPleasSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkAndReviveNativeService());
      unawaited(_syncNativeUserOverlayContext());
    }
  }

  void _bindGlobalCallbacks() {
    NativeBridge.onRequestPlea = (appName, packageName) {
      AppRouter.router.go(
        '/plea-compose',
        extra: {'appName': appName, 'packageName': packageName},
      );
    };

    NativeBridge.onOpenSquadSetup = () {
      AppRouter.router.go('/onboarding?step=share_squad');
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
      await _syncNativeUserOverlayContext();
      debugPrint('[GlobalAppServices] native schedule state synced');
    } catch (_) {
      // Native sync is best-effort. Flutter routing must still boot cleanly.
    }
  }

  Future<void> _checkAndReviveNativeService() async {
    try {
      await NativeBridge.checkAndReviveService();
    } catch (_) {
      // Best-effort watchdog poke; app boot must continue even if native rejects.
    }
  }

  Future<void> _syncNativeUserOverlayContext() async {
    final user = AuthService.currentUser;
    if (user == null) {
      try {
        await NativeBridge.syncUserOverlayContext(hasSquad: false);
      } catch (_) {}
      return;
    }

    try {
      final userData = await AuthService.getUserData();
      final squadId = (userData?['squadId'] as String?)?.trim();
      await NativeBridge.syncUserOverlayContext(
        hasSquad: squadId != null && squadId.isNotEmpty,
      );
    } catch (_) {
      // Best-effort native context sync; blocker should still function safely.
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
        _processedPleas.addAll(await _loadProcessedPleas(nextUid));
        _approvedPleasSubscription =
            SquadService.getUserApprovedPleasStream(nextUid).listen((pleas) {
              unawaited(_handleApprovedPleas(nextUid, pleas));
            });
      }
    }

    if (nextUid != null && nextUid.isNotEmpty) {
      unawaited(
        SettingsSyncService.hydrateLocalPreferencesFromCloud().catchError(
          (_) {},
        ),
      );
    }

    unawaited(_syncNativeUserOverlayContext());

    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppRouter.router.refresh();
    });
  }

  Future<Set<String>> _loadProcessedPleas(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final stored =
        prefs.getStringList(_processedApprovedPleasKey(uid)) ??
        const <String>[];
    return stored.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
  }

  Future<void> _persistProcessedPleas(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final values = _processedPleas
        .where((id) => id.trim().isNotEmpty)
        .take(_maxProcessedApprovedPleas)
        .toList(growable: false);
    await prefs.setStringList(_processedApprovedPleasKey(uid), values);
  }

  String _processedApprovedPleasKey(String uid) =>
      'processed_approved_pleas_$uid';

  bool _isApprovalStillActionable(PleaModel plea, DateTime now) {
    final packageName = plea.packageName.trim();
    if (packageName.isEmpty) return false;
    if (packageName.startsWith('regime-delete:')) {
      return true;
    }

    final grantedMinutes = plea.durationMinutes > 0 ? plea.durationMinutes : 5;
    final effectiveAt = plea.resolvedAt ?? plea.createdAt;
    final expiresAt = effectiveAt.add(Duration(minutes: grantedMinutes));
    return now.isBefore(expiresAt);
  }

  Future<void> _handleApprovedPleas(String uid, List<PleaModel> pleas) async {
    var didChangeProcessedSet = false;
    final now = DateTime.now();

    for (final plea in pleas) {
      if (_processedPleas.contains(plea.id)) continue;

      final packageName = plea.packageName.trim();
      final shouldApply = _isApprovalStillActionable(plea, now);
      if (!shouldApply) {
        _processedPleas.add(plea.id);
        didChangeProcessedSet = true;
        continue;
      }

      final grantedMinutes = plea.durationMinutes > 0
          ? plea.durationMinutes
          : 5;
      if (packageName.isEmpty) {
        _processedPleas.add(plea.id);
        didChangeProcessedSet = true;
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
      didChangeProcessedSet = true;
    }

    if (didChangeProcessedSet && _approvedPleasUid == uid) {
      await _persistProcessedPleas(uid);
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
