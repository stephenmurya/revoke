import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class SquadSocialSettingsPage extends StatelessWidget {
  const SquadSocialSettingsPage({super.key});

  static const int itemCount = 7;

  static const List<_SettingItem> _items = [
    _SettingItem(
      title: 'Leave Squad',
      description: 'Confirm exit; maybe notifies squad.',
    ),
    _SettingItem(
      title: 'Create New Squad',
      description: 'Generates fresh squad code.',
    ),
    _SettingItem(
      title: 'Regenerate Squad Code',
      description: 'Invalidate old invites.',
    ),
    _SettingItem(
      title: 'Kick Member',
      description: 'Only for squad admins (if you implement roles).',
    ),
    _SettingItem(
      title: 'Make Admin',
      description: 'Transfer squad leadership.',
    ),
    _SettingItem(
      title: 'Block User',
      description: 'Prevent someone from sending begs.',
    ),
    _SettingItem(
      title: 'Quiet Mode',
      description: 'Temporarily stop receiving begs (e.g., during exams).',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.background,
      appBar: AppBar(
        backgroundColor: AppSemanticColors.background,
        elevation: 0,
        title: Text('Squad & Social', style: AppTheme.xlMedium),
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
