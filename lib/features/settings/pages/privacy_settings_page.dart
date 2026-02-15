import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/utils/theme_extensions.dart';
import '../widgets/settings_option_tile.dart';

class PrivacySettingsPage extends StatelessWidget {
  const PrivacySettingsPage({super.key});

  static final List<_SettingItem> _items = [
    _SettingItem(
      title: 'App Usage Visibility',
      description: 'Let squad see which specific apps you use most? (Yes/No)',
      icon: PhosphorIcons.eye(),
    ),
    _SettingItem(
      title: 'Share Focus Score with Non-Squads',
      description: 'Off by default.',
      icon: PhosphorIcons.chartLineUp(),
    ),
    _SettingItem(
      title: 'Allow Revoke to Read Screen Time Data',
      description: 'Required for functionality.',
      icon: PhosphorIcons.shieldCheck(),
    ),
    _SettingItem(
      title: 'Export My Shame History',
      description:
          'Download a CSV of all your begs, grants, and shames (for the masochists).',
      icon: PhosphorIcons.fileCsv(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Privacy & Data', style: context.text.titleLarge),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          for (final item in _items) ...[
            SettingsOptionTile(
              title: item.title,
              subtitle: item.description,
              icon: item.icon,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Coming soon.')),
                );
              },
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _SettingItem {
  _SettingItem({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final PhosphorIconData icon;
}
