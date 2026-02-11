import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/app_router.dart';
import 'core/native_bridge.dart';
import 'core/theme/app_theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/services/auth_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/squad_service.dart';
import 'core/services/scoring_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService.initialize();
  NativeBridge.setupOverlayListener();
  ScoringService.initializePeriodicSync();
  runApp(const RevokeApp());
}

class RevokeApp extends StatelessWidget {
  const RevokeApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Set up the listener for the overlay
    NativeBridge.onShowOverlay = () {
      final uid = AuthService.currentUser?.uid;
      if (uid != null) {
        ScoringService.syncFocusScore(uid);
      }
      AppRouter.router.push('/lock_screen');
    };

    // Global listener for approved pleas (Stand-down logic)
    final uid = AuthService.currentUser?.uid;
    if (uid != null) {
      final processedPleas = <String>{};
      SquadService.getUserApprovedPleasStream(uid).listen((pleas) {
        for (var plea in pleas) {
          if (!processedPleas.contains(plea.id)) {
            // Trigger native stand-down for 5 minutes
            NativeBridge.temporaryUnlock(plea.packageName, 5);
            processedPleas.add(plea.id);
          }
        }
      });
    }

    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.data == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final currentLocation = AppRouter
                .router
                .routeInformationProvider
                .value
                .uri
                .path;
            if (currentLocation != '/onboarding') {
              AppRouter.router.go('/onboarding');
            }
          });
        }

        return MaterialApp.router(
          title: 'Revoke',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          routerConfig: AppRouter.router,
        );
      },
    );
  }
}
