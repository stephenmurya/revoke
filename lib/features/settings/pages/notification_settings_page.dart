import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key});

  static const int itemCount = 7;

  static const List<_SettingItem> _items = [
    _SettingItem(
      title: 'Shame Alerts',
      description: 'When someone shames you.',
    ),
    _SettingItem(
      title: 'Begging Requests',
      description: 'When a squad mate begs for time.',
    ),
    _SettingItem(
      title: 'Conclave Verdicts',
      description: 'Whether time was granted or denied.',
    ),
    _SettingItem(
      title: 'Cheater Detection',
      description: 'Friend bypassed Revoke? You get pinged.',
    ),
    _SettingItem(
      title: 'Daily Focus Score Report',
      description: 'Morning recap of yesterday\'s screen time.',
    ),
    _SettingItem(
      title: 'Squad Activity Digest',
      description: 'Weekly summary of who begged/shamed most.',
    ),
    _SettingItem(
      title: 'Notification Sounds',
      description: 'On / Off / Custom tones (e.g., a gavel slam for verdicts).',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.background,
      appBar: AppBar(
        backgroundColor: AppSemanticColors.background,
        elevation: 0,
        title: Text('Notifications', style: AppTheme.xlMedium),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        itemCount: _items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = _items[index];
          return Container(
            decoration: BoxDecoration(
              color: AppSemanticColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppSemanticColors.primaryText.withValues(alpha: 0.08)),
            ),
            child: ListTile(
              title: Text(item.title, style: AppTheme.lgMedium),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  item.description,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppSemanticColors.secondaryText,
                    height: 1.45,
                  ),
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppSemanticColors.secondaryText,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SettingItem {
  const _SettingItem({required this.title, required this.description});

  final String title;
  final String description;
}
