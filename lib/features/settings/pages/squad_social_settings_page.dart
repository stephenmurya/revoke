import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/utils/theme_extensions.dart';
import '../widgets/settings_option_tile.dart';

class SquadSocialSettingsPage extends StatelessWidget {
  const SquadSocialSettingsPage({super.key});

  static final List<_SettingItem> _items = [
    _SettingItem(
      title: 'Leave Squad',
      description: 'Confirm exit; maybe notifies squad.',
      icon: PhosphorIcons.signOut(),
    ),
    _SettingItem(
      title: 'Create New Squad',
      description: 'Generates fresh squad code.',
      icon: PhosphorIcons.usersThree(),
    ),
    _SettingItem(
      title: 'Regenerate Squad Code',
      description: 'Invalidate old invites.',
      icon: PhosphorIcons.ticket(),
    ),
    _SettingItem(
      title: 'Kick Member',
      description: 'Only for squad admins (if you implement roles).',
      icon: PhosphorIcons.userMinus(),
    ),
    _SettingItem(
      title: 'Make Admin',
      description: 'Transfer squad leadership.',
      icon: PhosphorIcons.crownSimple(),
    ),
    _SettingItem(
      title: 'Block User',
      description: 'Prevent someone from sending begs.',
      icon: PhosphorIcons.userMinus(),
    ),
    _SettingItem(
      title: 'Quiet Mode',
      description: 'Temporarily stop receiving begs (e.g., during exams).',
      icon: PhosphorIcons.moonStars(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Squad & Social', style: context.text.titleLarge),
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
