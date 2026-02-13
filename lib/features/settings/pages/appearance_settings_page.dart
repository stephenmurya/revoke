import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key});

  static const int itemCount = 6;

  static const List<_SettingItem> _items = [
    _SettingItem(
      title: 'Theme',
      description: 'Light / Dark / System / High Contrast.',
    ),
    _SettingItem(
      title: 'Accent Colour',
      description: 'Pick a highlight colour (brand purple, etc.).',
    ),
    _SettingItem(
      title: 'Shame Sound Effects',
      description: 'Optional audio when you get shamed.',
    ),
    _SettingItem(
      title: 'Haptics',
      description: 'Subtle buzz on denied requests.',
    ),
    _SettingItem(
      title: 'Icon Badge',
      description: 'Show pending shame count on app icon.',
    ),
    _SettingItem(title: 'Language', description: 'English (more later).'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.background,
      appBar: AppBar(
        backgroundColor: AppSemanticColors.background,
        elevation: 0,
        title: Text('Appearance & Experience', style: AppTheme.xlMedium),
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
