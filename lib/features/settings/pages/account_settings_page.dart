import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/utils/theme_extensions.dart';
import '../../profile/profile_screen.dart';
import '../widgets/settings_option_tile.dart';

class AccountSettingsPage extends StatelessWidget {
  const AccountSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Account & Profile', style: context.text.titleLarge),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          SettingsOptionTile(
            title: 'Profile Details',
            subtitle: 'Photo, nickname, and account actions.',
            icon: PhosphorIcons.userCircle(),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          const SizedBox(height: 6),
          SettingsOptionTile(
            title: 'Security',
            subtitle: 'Password, devices, and session management.',
            icon: PhosphorIcons.shield(),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Coming soon.')),
              );
            },
          ),
          const SizedBox(height: 6),
          SettingsOptionTile(
            title: 'Account Deletion',
            subtitle: 'Danger zone. Permanent removal.',
            icon: PhosphorIcons.warningOctagon(),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Open Profile Details to delete.')),
              );
            },
          ),
        ],
      ),
    );
  }
}

