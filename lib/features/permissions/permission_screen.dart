import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/app_router.dart';
import '../../core/native_bridge.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/theme_extensions.dart';

enum _PermissionKey { usageAccess, overlay, exactAlarm }

class _PermissionDisclosure {
  const _PermissionDisclosure({
    required this.key,
    required this.title,
    required this.shortTitle,
    required this.icon,
    required this.accessedData,
    required this.whyNeeded,
    required this.prominentDisclosure,
  });

  final _PermissionKey key;
  final String title;
  final String shortTitle;
  final IconData icon;
  final String accessedData;
  final String whyNeeded;
  final String prominentDisclosure;
}

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with WidgetsBindingObserver {
  static final List<_PermissionDisclosure> _disclosures = [
    _PermissionDisclosure(
      key: _PermissionKey.usageAccess,
      title: 'Grant Usage Access',
      shortTitle: 'Usage Access',
      icon: PhosphorIcons.chartBar(),
      accessedData:
          'Android tells Revoke which apps are currently running on your screen so enforcement can react to the foreground app.',
      whyNeeded:
          'Without this access, Revoke cannot detect when a distracting app is open and cannot enforce a focus regime.',
      prominentDisclosure:
          'Revoke needs Usage Access to monitor which apps are currently running on your screen. This allows us to enforce your focus regimes and block distracting apps. We do not transmit or store your browsing history.',
    ),
    _PermissionDisclosure(
      key: _PermissionKey.overlay,
      title: 'Allow Display Over Other Apps',
      shortTitle: 'Display Over Apps',
      icon: PhosphorIcons.appWindow(),
      accessedData:
          'Revoke draws a full-screen blocker over restricted apps when you try to open them during an active regime.',
      whyNeeded:
          'This is the enforcement surface. Without overlay permission, the app can detect the distraction but cannot actually stop access.',
      prominentDisclosure:
          'Revoke needs \'Display Over Other Apps\' permission to draw the strict lock-screen over distracting apps when a regime is active, preventing you from accessing them.',
    ),
    _PermissionDisclosure(
      key: _PermissionKey.exactAlarm,
      title: 'Allow Exact Alarms',
      shortTitle: 'Exact Alarms',
      icon: PhosphorIcons.alarm(),
      accessedData:
          'Revoke stores the next regime start time and asks Android to wake the app at that exact minute.',
      whyNeeded:
          'This lets enforcement begin on time without running a battery-draining foreground service all day.',
      prominentDisclosure:
          'Revoke needs \'Exact Alarms\' to wake up your device at the precise minute your focus regime begins.',
    ),
  ];

  bool _hasUsageStats = false;
  bool _hasOverlay = false;
  bool _hasExactAlarm = false;
  int _currentStep = 0;
  StreamSubscription<int>? _permissionSubscription;

  bool get _allGranted => _hasUsageStats && _hasOverlay && _hasExactAlarm;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
    _permissionSubscription =
        Stream.periodic(const Duration(seconds: 2), (tick) => tick).listen((_) {
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
    if (!mounted) return;

    final nextUsage = perms['usage_stats'] ?? false;
    final nextOverlay = perms['overlay'] ?? false;
    final nextExactAlarm = perms['exact_alarm'] ?? false;
    final changed =
        nextUsage != _hasUsageStats ||
        nextOverlay != _hasOverlay ||
        nextExactAlarm != _hasExactAlarm;

    setState(() {
      _hasUsageStats = nextUsage;
      _hasOverlay = nextOverlay;
      _hasExactAlarm = nextExactAlarm;
      _currentStep = _nextIncompleteStep();
    });

    if (changed) {
      AppRouter.invalidatePermissionCache();
    }
  }

  int _nextIncompleteStep() {
    for (var i = 0; i < _disclosures.length; i++) {
      if (!_isGranted(_disclosures[i].key)) {
        return i;
      }
    }
    return _disclosures.length - 1;
  }

  bool _isGranted(_PermissionKey key) {
    return switch (key) {
      _PermissionKey.usageAccess => _hasUsageStats,
      _PermissionKey.overlay => _hasOverlay,
      _PermissionKey.exactAlarm => _hasExactAlarm,
    };
  }

  Future<void> _handlePrimaryAction() async {
    final disclosure = _disclosures[_currentStep];
    if (_isGranted(disclosure.key)) {
      if (_allGranted) {
        AppRouter.invalidatePermissionCache();
        if (!mounted) return;
        context.go('/home');
        return;
      }
      setState(() {
        _currentStep = (_currentStep + 1).clamp(0, _disclosures.length - 1);
      });
      return;
    }

    switch (disclosure.key) {
      case _PermissionKey.usageAccess:
        await NativeBridge.requestUsageStats();
      case _PermissionKey.overlay:
        await NativeBridge.requestOverlay();
      case _PermissionKey.exactAlarm:
        await NativeBridge.requestExactAlarms();
    }
  }

  @override
  Widget build(BuildContext context) {
    final disclosure = _disclosures[_currentStep];
    final isGranted = _isGranted(disclosure.key);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildProgressRow(),
                const SizedBox(height: 24),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    child: _buildDisclosureCard(disclosure, isGranted),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isGranted
                      ? (_allGranted
                            ? 'All three required Android permissions are enabled.'
                            : '${disclosure.shortTitle} is enabled. Continue to the next disclosure.')
                      : 'Tap the button below only after you understand what this permission allows Revoke to do.',
                  style: AppTheme.bodySmall.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _handlePrimaryAction,
                    child: Text(_buildPrimaryLabel(disclosure, isGranted)),
                  ),
                ),
                if (!isGranted) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _checkPermissions,
                      child: const Text('I already granted this'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Before Revoke can enforce anything, Android needs three core permissions.',
          style: AppTheme.h2.copyWith(
            color: context.scheme.onSurface,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Read each disclosure, then choose “I Understand / Grant” to open the relevant Android settings page.',
          style: AppTheme.baseRegular.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressRow() {
    return Row(
      children: List.generate(_disclosures.length, (index) {
        final disclosure = _disclosures[index];
        final granted = _isGranted(disclosure.key);
        final isCurrent = index == _currentStep;

        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
              right: index == _disclosures.length - 1 ? 0 : 10,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: granted
                  ? context.colors.success.withValues(alpha: 0.14)
                  : isCurrent
                  ? context.scheme.primary.withValues(alpha: 0.12)
                  : context.scheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: granted
                    ? context.colors.success
                    : isCurrent
                    ? context.scheme.primary
                    : context.scheme.outlineVariant,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  granted ? PhosphorIcons.checkCircle() : disclosure.icon,
                  size: 16,
                  color: granted
                      ? context.colors.success
                      : isCurrent
                      ? context.scheme.primary
                      : context.colors.textSecondary,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    disclosure.shortTitle,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.xsMedium.copyWith(
                      color: granted
                          ? context.colors.success
                          : isCurrent
                          ? context.scheme.primary
                          : context.colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDisclosureCard(
    _PermissionDisclosure disclosure,
    bool isGranted,
  ) {
    return Container(
      key: ValueKey<_PermissionKey>(disclosure.key),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.scheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isGranted
              ? context.colors.success
              : context.scheme.outlineVariant,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isGranted
                      ? context.colors.success.withValues(alpha: 0.12)
                      : context.scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isGranted ? PhosphorIcons.checkCircle() : disclosure.icon,
                  color: isGranted
                      ? context.colors.success
                      : context.scheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prominent disclosure',
                      style: AppTheme.xsMedium.copyWith(
                        color: context.colors.textSecondary,
                        letterSpacing: 0.9,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(disclosure.title, style: AppTheme.h2),
                  ],
                ),
              ),
              _buildStatusPill(isGranted),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: context.scheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              disclosure.prominentDisclosure,
              style: AppTheme.baseRegular.copyWith(
                color: context.scheme.onSurface,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'What Revoke accesses',
            body: disclosure.accessedData,
          ),
          const SizedBox(height: 16),
          _buildSection(
            title: 'Why Revoke needs it',
            body: disclosure.whyNeeded,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(bool isGranted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isGranted
            ? context.colors.success.withValues(alpha: 0.14)
            : context.colors.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isGranted ? 'Granted' : 'Required',
        style: AppTheme.xsMedium.copyWith(
          color: isGranted ? context.colors.success : context.colors.warning,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required String body}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTheme.smMedium.copyWith(
            color: context.colors.textSecondary,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          style: AppTheme.baseRegular.copyWith(
            color: context.scheme.onSurface,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  String _buildPrimaryLabel(_PermissionDisclosure disclosure, bool isGranted) {
    if (!isGranted) {
      return 'I Understand / Grant ${disclosure.shortTitle}';
    }
    if (_allGranted) {
      return 'Continue to Revoke';
    }
    return 'Continue';
  }
}
