import 'package:flutter/material.dart';
import 'core/app_router.dart';
import 'core/native_bridge.dart';
import 'core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  NativeBridge.setupOverlayListener();
  runApp(const RevokeApp());
}

class RevokeApp extends StatelessWidget {
  const RevokeApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Set up the listener for the overlay
    NativeBridge.onShowOverlay = () {
      AppRouter.router.push('/lock_screen');
    };

    return MaterialApp.router(
      title: 'Revoke',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: AppRouter.router,
    );
  }
}
