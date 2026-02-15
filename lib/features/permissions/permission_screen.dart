import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/native_bridge.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/theme_extensions.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with WidgetsBindingObserver {
  bool _hasUsageStats = false;
  bool _hasOverlay = false;
  bool _hasBatteryOptOut = false;
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
        _hasBatteryOptOut = perms['battery_optimization_ignored'] ?? false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  color: context.colors.danger,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You revoked our access. We cannot see your activity.',
                style: AppTheme.baseRegular.copyWith(
                  color: context.scheme.onSurface,
                ),
              ),
              const SizedBox(height: 48),
              _buildPermissionCard(
                title: 'Usage access',
                description:
                    'Required to detect when restricted apps are opened.',
                isGranted: _hasUsageStats,
                onGrant: () => NativeBridge.requestUsageStats(),
              ),
              const SizedBox(height: 20),
              _buildPermissionCard(
                title: 'Draw over apps',
                description: 'Required to show the block screen overlay.',
                isGranted: _hasOverlay,
                onGrant: () => NativeBridge.requestOverlay(),
              ),
              const SizedBox(height: 20),
              _buildPermissionCard(
                title: 'Battery optimization',
                description:
                    'Required so Revoke can survive background restrictions and reboots.',
                isGranted: _hasBatteryOptOut,
                onGrant: () => NativeBridge.requestBatteryOptimizations(),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_hasUsageStats && _hasOverlay && _hasBatteryOptOut)
                      ? () => context.go('/home')
                      : null,
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
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted
              ? context.colors.success
              : Theme.of(context).colorScheme.outlineVariant,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.lgMedium),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTheme.baseRegular.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (isGranted)
            Icon(Icons.check_circle, color: context.colors.success)
          else
            ElevatedButton(
              onPressed: onGrant,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                foregroundColor: context.scheme.onSurface,
                side: BorderSide(color: context.scheme.outlineVariant),
              ),
              child: Text('Grant', style: AppTheme.baseBold),
            ),
        ],
      ),
    );
  }
}
