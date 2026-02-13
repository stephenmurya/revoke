import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class PrivacySettingsPage extends StatelessWidget {
  const PrivacySettingsPage({super.key});

  static const int itemCount = 4;

  static const List<_SettingItem> _items = [
    _SettingItem(
      title: 'App Usage Visibility',
      description: 'Let squad see which specific apps you use most? (Yes/No)',
    ),
    _SettingItem(
      title: 'Share Focus Score with Non-Squads',
      description: 'Off by default.',
    ),
    _SettingItem(
      title: 'Allow Revoke to Read Screen Time Data',
      description: 'Required for functionality.',
    ),
    _SettingItem(
      title: 'Export My Shame History',
      description:
          'Download a CSV of all your begs, grants, and shames (for the masochists).',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.background,
      appBar: AppBar(
        backgroundColor: AppSemanticColors.background,
        elevation: 0,
        title: Text('Privacy & Data', style: AppTheme.xlMedium),
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
