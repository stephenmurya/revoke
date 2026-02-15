import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/utils/theme_extensions.dart';
import '../widgets/settings_option_tile.dart';

class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key});

  static final List<_SettingItem> _items = [
    _SettingItem(
      title: 'Shame Alerts',
      description: 'When someone shames you.',
      icon: PhosphorIcons.gavel(),
    ),
    _SettingItem(
      title: 'Begging Requests',
      description: 'When a squad mate begs for time.',
      icon: PhosphorIcons.hand(),
    ),
    _SettingItem(
      title: 'Conclave Verdicts',
      description: 'Whether time was granted or denied.',
      icon: PhosphorIcons.scales(),
    ),
    _SettingItem(
      title: 'Cheater Detection',
      description: 'Friend bypassed Revoke? You get pinged.',
      icon: PhosphorIcons.warningCircle(),
    ),
    _SettingItem(
      title: 'Daily Focus Score Report',
      description: 'Morning recap of yesterday\'s screen time.',
      icon: PhosphorIcons.chartLineUp(),
    ),
    _SettingItem(
      title: 'Squad Activity Digest',
      description: 'Weekly summary of who begged/shamed most.',
      icon: PhosphorIcons.users(),
    ),
    _SettingItem(
      title: 'Notification Sounds',
      description: 'On / Off / Custom tones (e.g., a gavel slam for verdicts).',
      icon: PhosphorIcons.speakerHigh(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications', style: context.text.titleLarge),
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
