import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class AdvancedSettingsPage extends StatelessWidget {
  const AdvancedSettingsPage({super.key});

  static const int itemCount = 5;

  static const List<_SettingItem> _items = [
    _SettingItem(
      title: 'Background App Refresh',
      description: 'Ensure Revoke can\'t be killed by battery optimisation.',
    ),
    _SettingItem(
      title: 'Bypass Detection Sensitivity',
      description: 'Aggressive / Normal / Relaxed.',
    ),
    _SettingItem(
      title: 'Focus Score Algorithm',
      description: 'Custom weighting (e.g., Instagram usage counts double).',
    ),
    _SettingItem(
      title: 'Test Mode',
      description: 'Simulate a block without affecting real screen time.',
    ),
    _SettingItem(
      title: 'Reset Onboarding',
      description: 'See the "Join a Squad" flow again.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.background,
      appBar: AppBar(
        backgroundColor: AppSemanticColors.background,
        elevation: 0,
        title: Text('Advanced / Power User', style: AppTheme.xlMedium),
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
