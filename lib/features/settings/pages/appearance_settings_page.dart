import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/utils/theme_extensions.dart';
import '../widgets/settings_option_tile.dart';

class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key});

  static final List<_SettingItem> _items = [
    _SettingItem(
      title: 'Theme',
      description: 'Light / Dark / System / High Contrast.',
      icon: PhosphorIcons.moonStars(),
    ),
    _SettingItem(
      title: 'Accent Colour',
      description: 'Pick a highlight colour (brand purple, etc.).',
      icon: PhosphorIcons.palette(),
    ),
    _SettingItem(
      title: 'Shame Sound Effects',
      description: 'Optional audio when you get shamed.',
      icon: PhosphorIcons.speakerHigh(),
    ),
    _SettingItem(
      title: 'Haptics',
      description: 'Subtle buzz on denied requests.',
      icon: PhosphorIcons.vibrate(),
    ),
    _SettingItem(
      title: 'Icon Badge',
      description: 'Show pending shame count on app icon.',
      icon: PhosphorIcons.appWindow(),
    ),
    _SettingItem(title: 'Language', description: 'English (more later).'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Appearance & Experience', style: context.text.titleLarge),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          for (final item in _items) ...[
            SettingsOptionTile(
              title: item.title,
              subtitle: item.description,
              icon: item.icon ?? PhosphorIcons.sparkle(),
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
    this.icon,
  });

  final String title;
  final String description;
  final PhosphorIconData? icon;
}
