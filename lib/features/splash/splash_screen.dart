import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/auth_service.dart';
import '../../core/native_bridge.dart';
import '../../core/utils/theme_extensions.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _status = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // 1. Check Auth Status (Synchronous)
      final user = AuthService.currentUser;

      if (user == null) {
        if (mounted) context.go('/onboarding');
        return;
      }

      // 2. Check User Data (Async)
      setState(() => _status = 'Syncing profile...');

      // Add a timeout to prevent hanging forever
      final userData = await AuthService.getUserData().timeout(
        const Duration(seconds: 10),
        onTimeout: () => null,
      );

      if (userData == null) {
        // If we can't get user data (offline or error), we might want to:
        // a) Retry
        // b) Go to onboarding if it's critical
        // c) Let them into home if we can tolerate missing data
        // For now, if we can't confirm a nickname, we assume something is wrong.
        // But if it's just a network timeout, maybe let them retry?
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Network issues. Please check your connection."),
            ),
          );
          // Retry or go to onboarding? Safe bet is stay here with a retry button.
          // But for user flow, let's try to fetch again or go to onboarding (safe fallback).
          // Actually, if we just fixed permission errors, maybe data is missing.
          context.go('/onboarding');
        }
        return;
      }

      final hasNickname = userData['nickname'] != null;
      if (!hasNickname) {
        if (mounted) context.go('/onboarding');
        return;
      }

      // 3. Check Permissions
      setState(() => _status = 'Checking permissions...');
      final perms = await NativeBridge.checkPermissions();
      final hasAll =
          (perms['usage_stats'] ?? false) && (perms['overlay'] ?? false);

      if (!hasAll) {
        if (mounted) context.go('/permissions');
        return;
      }

      // 4. All Good
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Error: $e');
      }
      // Consider adding a retry button in the UI if this happens
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo / Initial Text
            Text(
              'Revoke',
              style: AppTheme.size5xlBold.copyWith(
                color: context.scheme.onSurface,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 24),
            // Loading Indicator
            CircularProgressIndicator(color: context.scheme.primary),
            const SizedBox(height: 24),
            // Status Text
            Text(
              _status,
              style: AppTheme.bodyMedium.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
