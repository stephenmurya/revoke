import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class AppManagementSettingsPage extends StatelessWidget {
  const AppManagementSettingsPage({super.key});

  static const int itemCount = 6;

  static const List<_SettingItem> _items = [
    _SettingItem(
      title: 'Default Block Duration',
      description: 'When you start a regime, how long it lasts.',
    ),
    _SettingItem(
      title: 'Default Blocked Apps',
      description: 'Pre-select apps to block in every regime.',
    ),
    _SettingItem(
      title: 'Allow Whitelist',
      description: 'Apps that are never blocked (e.g., Phone, Maps).',
    ),
    _SettingItem(
      title: 'Grace Period',
      description: '1-minute buffer before blocks engage.',
    ),
    _SettingItem(
      title: 'Snooze All Blocks',
      description: 'Emergency pause (maybe requires squad vote).',
    ),
    _SettingItem(
      title: 'Regime Templates',
      description: 'Save "Work", "Sleep", "Gym" presets.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.background,
      appBar: AppBar(
        backgroundColor: AppSemanticColors.background,
        elevation: 0,
        title: Text('App Management & Regimes', style: AppTheme.xlMedium),
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
