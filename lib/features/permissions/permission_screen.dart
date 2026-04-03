import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/app_router.dart';
import '../../core/native_bridge.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/theme_extensions.dart';
import '../../core/widgets/revoke_progress_bar.dart';

enum _PermissionKey { accessibility, usageAccess, overlay, exactAlarm }

class _PermissionDisclosure {
  const _PermissionDisclosure({
    required this.key,
    required this.title,
    required this.shortTitle,
    required this.icon,
    required this.whyNeeded,
    required this.prominentDisclosure,
  });

  final _PermissionKey key;
  final String title;
  final String shortTitle;
  final IconData icon;
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
      key: _PermissionKey.accessibility,
      title: 'Grant Accessibility Access',
      shortTitle: 'Accessibility',
      icon: PhosphorIcons.lightning(),
      whyNeeded:
          'Without this permission, Revoke loses its instant fast path and may react later to app launches.',
      prominentDisclosure:
          'Revoke uses the Accessibility Service to instantly detect when a distracting app is opened and block it. We do not collect or transmit your screen content.',
    ),
    _PermissionDisclosure(
      key: _PermissionKey.usageAccess,
      title: 'Grant Usage Access',
      shortTitle: 'Usage Access',
      icon: PhosphorIcons.chartBar(),
      whyNeeded:
          'Without this permission, Revoke cannot tell when a restricted app is on screen.',
      prominentDisclosure:
          'Revoke needs Usage Access to detect the app currently on screen so blocking can start at the right moment.',
    ),
    _PermissionDisclosure(
      key: _PermissionKey.overlay,
      title: 'Allow Display Over Other Apps',
      shortTitle: 'Display Over Apps',
      icon: PhosphorIcons.appWindow(),
      whyNeeded:
          'Without this permission, Revoke can detect a distraction but cannot cover it with the blocker.',
      prominentDisclosure:
          'Revoke needs Display Over Other Apps so it can place the blocker above restricted apps.',
    ),
    _PermissionDisclosure(
      key: _PermissionKey.exactAlarm,
      title: 'Allow Exact Alarms',
      shortTitle: 'Exact Alarms',
      icon: PhosphorIcons.alarm(),
      whyNeeded:
          'Without this permission, a regime may start late instead of at the exact scheduled minute.',
      prominentDisclosure:
          'Revoke needs Exact Alarms so scheduled enforcement can wake up exactly on time.',
    ),
  ];

  bool _hasAccessibility = false;
  bool _hasUsageStats = false;
  bool _hasOverlay = false;
  bool _hasExactAlarm = false;
  int _currentStep = 0;
  StreamSubscription<int>? _permissionSubscription;

  bool get _allGranted =>
      _hasAccessibility && _hasUsageStats && _hasOverlay && _hasExactAlarm;
  int get _currentStageNumber =>
      _allGranted ? _disclosures.length : _currentStep + 1;

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

    final nextAccessibility = perms['accessibility'] ?? false;
    final nextUsage = perms['usage_stats'] ?? false;
    final nextOverlay = perms['overlay'] ?? false;
    final nextExactAlarm = perms['exact_alarm'] ?? false;
    final changed =
        nextAccessibility != _hasAccessibility ||
        nextUsage != _hasUsageStats ||
        nextOverlay != _hasOverlay ||
        nextExactAlarm != _hasExactAlarm;

    setState(() {
      _hasAccessibility = nextAccessibility;
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
      _PermissionKey.accessibility => _hasAccessibility,
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
      case _PermissionKey.accessibility:
        await NativeBridge.openAccessibilitySettings();
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
            padding: EdgeInsets.fromLTRB(
              24,
              20,
              24,
              16 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildStageProgress(),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 240),
                          child: _buildDisclosureCard(disclosure, isGranted),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          isGranted
                              ? (_allGranted
                                    ? 'All four required Android permissions are enabled.'
                                    : '${disclosure.shortTitle} is enabled. Continue to the next disclosure.')
                              : 'Tap the button below only after you understand what this permission allows Revoke to do.',
                          style: AppTheme.bodySmall.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
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

  Widget _buildStageProgress() {
    final disclosure = _disclosures[_currentStep];
    final stageGranted = _isGranted(disclosure.key);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${disclosure.shortTitle} - $_currentStageNumber/${_disclosures.length}',
              style: AppTheme.smMedium.copyWith(
                color: context.scheme.onSurface,
                letterSpacing: 0.4,
              ),
            ),
            const Spacer(),
            Icon(
              stageGranted
                  ? PhosphorIcons.checkCircle()
                  : PhosphorIcons.dotsThree(),
              size: 20,
              color: stageGranted
                  ? context.colors.success
                  : context.colors.textSecondary,
            ),
          ],
        ),
        const SizedBox(height: 10),
        RevokeProgressBar(
          totalSteps: _disclosures.length,
          currentStep: _allGranted ? _disclosures.length - 1 : _currentStep,
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Grant Revoke Permissions',
          style: AppTheme.h2.copyWith(
            color: context.scheme.onSurface,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Before Revoke can enforce anything, Android needs four core permissions.',
          style: AppTheme.baseRegular.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      ],
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compact) ...[
                Row(
                  children: [
                    _buildDisclosureIcon(disclosure, isGranted),
                    const Spacer(),
                    _buildStatusPill(isGranted),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Prominent disclosure',
                  style: AppTheme.xsMedium.copyWith(
                    color: context.colors.textSecondary,
                    letterSpacing: 0.9,
                  ),
                ),
                const SizedBox(height: 4),
                Text(disclosure.title, style: AppTheme.h2),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDisclosureIcon(disclosure, isGranted),
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
                    const SizedBox(width: 16),
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
              const SizedBox(height: 18),
              _buildSection(
                title: 'Why Revoke needs it',
                body: disclosure.whyNeeded,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDisclosureIcon(
    _PermissionDisclosure disclosure,
    bool isGranted,
  ) {
    return Container(
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
        color: isGranted ? context.colors.success : context.scheme.primary,
        size: 28,
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
      return 'Grant ${disclosure.shortTitle}';
    }
    if (_allGranted) {
      return 'Continue to Revoke';
    }
    return 'Continue';
  }
}
