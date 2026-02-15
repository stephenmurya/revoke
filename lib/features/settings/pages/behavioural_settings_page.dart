import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/utils/theme_extensions.dart';
import '../widgets/settings_option_tile.dart';

class BehaviouralSettingsPage extends StatelessWidget {
  const BehaviouralSettingsPage({super.key});

  static final List<_SettingItem> _items = [
    _SettingItem(
      title: 'Shame Streaks',
      description: 'How many days in a row you\'ve been shamed (opt-out).',
      icon: PhosphorIcons.fire(),
    ),
    _SettingItem(
      title: 'Focus Score Benchmark',
      description: 'Compare to your own history.',
      icon: PhosphorIcons.trendUp(),
    ),
    _SettingItem(
      title: 'Weekly Challenge Opt-in',
      description: 'Squad vs. squad tournaments.',
      icon: PhosphorIcons.flagCheckered(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Behavioural / Gamification', style: context.text.titleLarge),
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
