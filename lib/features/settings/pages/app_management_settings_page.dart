import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/utils/theme_extensions.dart';
import '../widgets/settings_option_tile.dart';

class AppManagementSettingsPage extends StatelessWidget {
  const AppManagementSettingsPage({super.key});

  static final List<_SettingItem> _items = [
    _SettingItem(
      title: 'Default Block Duration',
      description: 'When you start a regime, how long it lasts.',
      icon: PhosphorIcons.timer(),
    ),
    _SettingItem(
      title: 'Default Blocked Apps',
      description: 'Pre-select apps to block in every regime.',
      icon: PhosphorIcons.appWindow(),
    ),
    _SettingItem(
      title: 'Allow Whitelist',
      description: 'Apps that are never blocked (e.g., Phone, Maps).',
      icon: PhosphorIcons.checkCircle(),
    ),
    _SettingItem(
      title: 'Grace Period',
      description: '1-minute buffer before blocks engage.',
      icon: PhosphorIcons.hourglassSimpleLow(),
    ),
    _SettingItem(
      title: 'Snooze All Blocks',
      description: 'Emergency pause (maybe requires squad vote).',
      icon: PhosphorIcons.pauseCircle(),
    ),
    _SettingItem(
      title: 'Regime Templates',
      description: 'Save "Work", "Sleep", "Gym" presets.',
      icon: PhosphorIcons.stack(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('App Management & Regimes', style: context.text.titleLarge),
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
