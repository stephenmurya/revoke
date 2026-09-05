import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/models/user_model.dart';
import '../../core/native_bridge.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/persistence_service.dart';
import '../../core/services/settings_sync_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/theme_extensions.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const List<int> _reminderFrequencyOptions = <int>[
    0,
    1,
    3,
    5,
    10,
    15,
    30,
  ];

  final Map<String, bool> _pendingValues = <String, bool>{};
  final Set<String> _savingKeys = <String>{};
  bool _softReminderEnabled = true;
  int _softReminderFrequencyMinutes = 5;
  bool _loadingReminderFrequency = true;
  bool _savingSoftReminderEnabled = false;
  bool _savingReminderFrequency = false;

  @override
  void initState() {
    super.initState();
    _loadReminderSettings();
  }

  Future<void> _loadReminderSettings() async {
    final enabled = await PersistenceService.getSoftReminderEnabled();
    final minutes = await PersistenceService.getSoftReminderFrequencyMinutes();
    if (!mounted) return;
    setState(() {
      _softReminderEnabled = enabled;
      _softReminderFrequencyMinutes = minutes;
      _loadingReminderFrequency = false;
    });
    unawaited(
      NativeBridge.syncReminderConfig(
        softReminderEnabled: enabled,
        softReminderCooldownMs: minutes * 60000,
      ).catchError((_) {}),
    );
    unawaited(_refreshReminderSettingsFromCloud());
  }

  Future<void> _refreshReminderSettingsFromCloud() async {
    try {
      await SettingsSyncService.hydrateLocalPreferencesFromCloud();
      final enabled = await PersistenceService.getSoftReminderEnabled();
      final minutes =
          await PersistenceService.getSoftReminderFrequencyMinutes();
      if (!mounted) return;
      setState(() {
        _softReminderEnabled = enabled;
        _softReminderFrequencyMinutes = minutes;
      });
    } catch (_) {}
  }

  Future<void> _updatePref(String key, bool value) async {
    setState(() {
      _pendingValues[key] = value;
      _savingKeys.add(key);
    });

    try {
      await AuthService.updateNotificationPref(key, value);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update notification setting.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingKeys.remove(key);
          _pendingValues.remove(key);
        });
      }
    }
  }

  bool _resolveValue({required String key, required bool fallback}) {
    return _pendingValues[key] ?? fallback;
  }

  Future<void> _updateSoftReminderEnabled(bool enabled) async {
    setState(() {
      _softReminderEnabled = enabled;
      _savingSoftReminderEnabled = true;
    });

    try {
      await PersistenceService.saveSoftReminderEnabled(enabled);
      await NativeBridge.syncReminderConfig(
        softReminderEnabled: enabled,
        softReminderCooldownMs: _softReminderFrequencyMinutes * 60000,
      );
      unawaited(
        SettingsSyncService.syncSoftReminderEnabledToCloud(
          enabled,
        ).catchError((_) {}),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update reminder setting.')),
      );
    } finally {
      if (mounted) {
        setState(() => _savingSoftReminderEnabled = false);
      }
    }
  }

  Future<void> _updateReminderFrequency(int minutes) async {
    final normalized = minutes.clamp(0, 120).toInt();
    setState(() {
      _softReminderFrequencyMinutes = normalized;
      _savingReminderFrequency = true;
    });

    try {
      await PersistenceService.saveSoftReminderFrequencyMinutes(normalized);
      await NativeBridge.syncReminderConfig(
        softReminderEnabled: _softReminderEnabled,
        softReminderCooldownMs: normalized * 60000,
      );
      unawaited(
        SettingsSyncService.syncSoftReminderFrequencyMinutesToCloud(
          normalized,
        ).catchError((_) {}),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update reminder setting.')),
      );
    } finally {
      if (mounted) {
        setState(() => _savingReminderFrequency = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder(
        stream: AuthService.authStateChanges,
        builder: (context, authSnapshot) {
          final user = authSnapshot.data;
          if (user == null) {
            return Center(
              child: Text(
                'Sign in to manage notifications.',
                style: AppTheme.baseRegular.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            );
          }

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting &&
                  !userSnapshot.hasData) {
                return Center(
                  child: CircularProgressIndicator(
                    color: context.scheme.primary,
                  ),
                );
              }

              final data =
                  userSnapshot.data?.data() ?? const <String, dynamic>{};
              final userModel = UserModel.fromMap({'uid': user.uid, ...data});

              final wantsShameAlerts = _resolveValue(
                key: 'shameAlerts',
                fallback: userModel.wantsShameAlerts,
              );
              final wantsOverrideRequests = _resolveValue(
                key: 'pleaRequests',
                fallback: userModel.wantsPleaRequests,
              );
              final wantsVerdicts = _resolveValue(
                key: 'verdicts',
                fallback: userModel.wantsVerdicts,
              );

              return ListView(
                padding: const EdgeInsets.fromLTRB(8, 14, 8, 28),
                children: [
                  _NotificationToggleRow(
                    icon: PhosphorIcons.warningCircle,
                    title: 'Accountability alerts',
                    subtitle:
                        'When Circle members send an accountability update.',
                    value: wantsShameAlerts,
                    activeColor: context.colors.accent,
                    isSaving: _savingKeys.contains('shameAlerts'),
                    onChanged: (value) => _updatePref('shameAlerts', value),
                  ),
                  _NotificationToggleRow(
                    icon: PhosphorIcons.handsPraying,
                    title: 'Override Requests',
                    subtitle: 'When a Circle member requests access.',
                    value: wantsOverrideRequests,
                    activeColor: context.colors.accent,
                    isSaving: _savingKeys.contains('pleaRequests'),
                    onChanged: (value) => _updatePref('pleaRequests', value),
                  ),
                  _NotificationToggleRow(
                    icon: PhosphorIcons.gavel,
                    title: 'Request decisions',
                    subtitle: 'When an Override Request is resolved.',
                    value: wantsVerdicts,
                    activeColor: context.colors.accent,
                    isSaving: _savingKeys.contains('verdicts'),
                    onChanged: (value) => _updatePref('verdicts', value),
                  ),
                  const SizedBox(height: 14),
                  _NotificationToggleRow(
                    icon: PhosphorIcons.bell,
                    title: 'Soft Reminders',
                    subtitle:
                        'Show a mindful reminder when a limited app opens.',
                    value: _softReminderEnabled,
                    activeColor: context.colors.accent,
                    isSaving: _savingSoftReminderEnabled,
                    onChanged:
                        _loadingReminderFrequency || _savingSoftReminderEnabled
                        ? null
                        : _updateSoftReminderEnabled,
                  ),
                  _ReminderFrequencyRow(
                    value: _softReminderFrequencyMinutes,
                    options: _reminderFrequencyOptions,
                    isLoading: _loadingReminderFrequency,
                    isSaving: _savingReminderFrequency,
                    onChanged: _updateReminderFrequency,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ReminderFrequencyRow extends StatelessWidget {
  final int value;
  final List<int> options;
  final bool isLoading;
  final bool isSaving;
  final ValueChanged<int> onChanged;

  const _ReminderFrequencyRow({
    required this.value,
    required this.options,
    required this.isLoading,
    required this.isSaving,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selectedValue = options.contains(value) ? value : 5;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            PhosphorIcons.timer,
            size: 20,
            color: context.colors.textPrimary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Soft Reminder Frequency', style: AppTheme.baseMedium),
                const SizedBox(height: 2),
                Text(
                  'How often mindful reminders can reappear.',
                  style: AppTheme.smRegular.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (isLoading || isSaving) ...[
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          DropdownButton<int>(
            value: selectedValue,
            underline: const SizedBox.shrink(),
            items: options
                .map(
                  (minutes) => DropdownMenuItem<int>(
                    value: minutes,
                    child: Text(minutes <= 0 ? 'Every open' : '$minutes min'),
                  ),
                )
                .toList(growable: false),
            onChanged: isLoading || isSaving
                ? null
                : (minutes) {
                    if (minutes == null) return;
                    onChanged(minutes);
                  },
          ),
        ],
      ),
    );
  }
}

class _NotificationToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool isSaving;
  final Color activeColor;

  const _NotificationToggleRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.activeColor,
    required this.onChanged,
    this.subtitle,
    this.isSaving = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: context.colors.textPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppTheme.baseMedium),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTheme.smRegular.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isSaving) ...[
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Switch.adaptive(
            value: value,
            activeTrackColor: activeColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
