import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/native_bridge.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/theme_extensions.dart';

class AccessibilityDisclosureScreen extends StatefulWidget {
  const AccessibilityDisclosureScreen({super.key, required this.onCompleted});

  final VoidCallback onCompleted;

  @override
  State<AccessibilityDisclosureScreen> createState() =>
      _AccessibilityDisclosureScreenState();
}

class _AccessibilityDisclosureScreenState
    extends State<AccessibilityDisclosureScreen>
    with WidgetsBindingObserver {
  bool _isChecking = false;
  bool _didComplete = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    if (_isChecking || _didComplete) return;
    _isChecking = true;
    try {
      final granted = await NativeBridge.checkAccessibilityPermission();
      if (!mounted || _didComplete) return;
      if (granted) {
        _didComplete = true;
        widget.onCompleted();
      }
    } finally {
      _isChecking = false;
    }
  }

  Future<void> _openSettings() async {
    await NativeBridge.openAccessibilitySettings();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: context.scheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              PhosphorIcons.warningCircle,
              size: 44,
              color: context.scheme.primary,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Grant Accessibility Access',
            textAlign: TextAlign.center,
            style: AppTheme.h2.copyWith(color: context.scheme.onSurface),
          ),
          const SizedBox(height: 16),
          Text(
            'Revoke uses the Accessibility Service to instantly detect when a distracting app is opened and block it. We do not collect or transmit your screen content.',
            textAlign: TextAlign.center,
            style: AppTheme.bodyMedium.copyWith(
              color: context.colors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: context.scheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.scheme.outlineVariant),
            ),
            child: Text(
              'This is the fast path that lets Revoke react before a distracting app fully appears.',
              textAlign: TextAlign.center,
              style: AppTheme.bodySmall.copyWith(
                color: context.scheme.onSurface,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _openSettings,
              child: const Text('Open Settings'),
            ),
          ),
        ],
      ),
    );
  }
}
