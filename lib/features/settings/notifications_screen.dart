import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/models/user_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/theme_extensions.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final Map<String, bool> _pendingValues = <String, bool>{};
  final Set<String> _savingKeys = <String>{};

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
              final wantsPleaRequests = _resolveValue(
                key: 'pleaRequests',
                fallback: userModel.wantsPleaRequests,
              );
              final wantsVerdicts = _resolveValue(
                key: 'verdicts',
                fallback: userModel.wantsVerdicts,
              );

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                children: [
                  _NotificationToggleRow(
                    icon: PhosphorIcons.warningCircle(),
                    title: 'Shame Alerts',
                    subtitle: 'When someone shames you.',
                    value: wantsShameAlerts,
                    activeColor: context.colors.accent,
                    isSaving: _savingKeys.contains('shameAlerts'),
                    onChanged: (value) => _updatePref('shameAlerts', value),
                  ),
                  _NotificationToggleRow(
                    icon: PhosphorIcons.handsPraying(),
                    title: 'Begging Requests',
                    subtitle: 'When a squad mate begs for time.',
                    value: wantsPleaRequests,
                    activeColor: context.colors.accent,
                    isSaving: _savingKeys.contains('pleaRequests'),
                    onChanged: (value) => _updatePref('pleaRequests', value),
                  ),
                  _NotificationToggleRow(
                    icon: PhosphorIcons.gavel(),
                    title: 'Conclave Verdicts',
                    subtitle: 'Whether time was granted or denied.',
                    value: wantsVerdicts,
                    activeColor: context.colors.accent,
                    isSaving: _savingKeys.contains('verdicts'),
                    onChanged: (value) => _updatePref('verdicts', value),
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
