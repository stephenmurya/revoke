import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/utils/theme_extensions.dart';
import '../widgets/settings_option_tile.dart';

class AdvancedSettingsPage extends StatelessWidget {
  const AdvancedSettingsPage({super.key});

  static final List<_SettingItem> _items = [
    _SettingItem(
      title: 'Background App Refresh',
      description: 'Ensure Revoke can\'t be killed by battery optimisation.',
      icon: PhosphorIcons.batteryWarning(),
    ),
    _SettingItem(
      title: 'Bypass Detection Sensitivity',
      description: 'Aggressive / Normal / Relaxed.',
      icon: PhosphorIcons.slidersHorizontal(),
    ),
    _SettingItem(
      title: 'Focus Score Algorithm',
      description: 'Custom weighting (e.g., Instagram usage counts double).',
      icon: PhosphorIcons.function(),
    ),
    _SettingItem(
      title: 'Test Mode',
      description: 'Simulate a block without affecting real screen time.',
      icon: PhosphorIcons.flask(),
    ),
    _SettingItem(
      title: 'Reset Onboarding',
      description: 'See the "Join a Squad" flow again.',
      icon: PhosphorIcons.arrowCounterClockwise(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Advanced / Power User', style: context.text.titleLarge),
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
