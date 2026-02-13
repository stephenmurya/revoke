import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/native_bridge.dart';
import '../../core/theme/app_theme.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with WidgetsBindingObserver {
  bool _hasUsageStats = false;
  bool _hasOverlay = false;
  StreamSubscription? _permissionSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();

    // Check every 2 seconds while on this screen
    _permissionSubscription = Stream.periodic(const Duration(seconds: 2))
        .listen((_) {
          _checkPermissions();
        });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _permissionSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final perms = await NativeBridge.checkPermissions();
    if (mounted) {
      setState(() {
        _hasUsageStats = perms['usage_stats'] ?? false;
        _hasOverlay = perms['overlay'] ?? false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Text(
                'Revoke is blind.',
                style: AppTheme.h1.copyWith(
                  color: AppSemanticColors.danger,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You revoked our access. We cannot see your activity.',
                style: AppTheme.bodySmall.copyWith(
                  color: AppSemanticColors.primaryText,
                ),
              ),
              const SizedBox(height: 48),
              _buildPermissionCard(
                title: 'Usage access',
                description:
                    'Required to detect when restricted apps are opened.',
                isGranted: _hasUsageStats,
                onGrant: () => NativeBridge.requestUsageStats(),
                color: AppSemanticColors.accent,
              ),
              const SizedBox(height: 20),
              _buildPermissionCard(
                title: 'Draw over apps',
                description: 'Required to show the block screen overlay.',
                isGranted: _hasOverlay,
                onGrant: () => NativeBridge.requestOverlay(),
                color: AppSemanticColors.accent,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_hasUsageStats && _hasOverlay)
                      ? () => context.go('/home')
                      : null,
                  style: AppTheme.primaryButtonStyle,
                  child: const Text('Restore vision'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onGrant,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppSemanticColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted
              ? Colors.greenAccent
              : AppSemanticColors.primaryText.withValues(alpha: 0.1),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.h3),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppSemanticColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (isGranted)
            const Icon(Icons.check_circle, color: AppSemanticColors.success)
          else
            ElevatedButton(
              onPressed: onGrant,
              style: AppTheme.secondaryButtonStyle.copyWith(
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                backgroundColor: const WidgetStatePropertyAll(AppSemanticColors.background),
              ),
              child: Text('Grant', style: AppTheme.baseBold),
            ),
        ],
      ),
    );
  }
}
