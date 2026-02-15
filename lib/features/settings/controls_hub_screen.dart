import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../profile/profile_screen.dart';
import 'pages/notification_settings_page.dart';
import 'pages/privacy_settings_page.dart';
import 'pages/squad_social_settings_page.dart';
import 'pages/app_management_settings_page.dart';
import 'pages/appearance_settings_page.dart';
import 'pages/advanced_settings_page.dart';
import 'pages/behavioural_settings_page.dart';

class ControlsHubScreen extends StatelessWidget {
  const ControlsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.background,
      appBar: AppBar(
        backgroundColor: AppSemanticColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text('Controls', style: AppTheme.h2),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            ..._controlsSections.map(
              (section) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ControlsTile(section: section),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlsTile extends StatelessWidget {
  const _ControlsTile({required this.section});

  final _ControlsSection section;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => section.destination));
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppSemanticColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppSemanticColors.primaryText.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppSemanticColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppSemanticColors.accent, width: 1.2),
                ),
                child: Icon(section.icon, color: AppSemanticColors.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(section.title, style: AppTheme.bodyLarge),
                    const SizedBox(height: 4),
                    Text(
                      section.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppSemanticColors.mutedText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${section.itemCount} pages',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppSemanticColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppSemanticColors.mutedText,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlsSection {
  const _ControlsSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.itemCount,
    required this.destination,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final int itemCount;
  final Widget destination;
}

const List<_ControlsSection> _controlsSections = [
  _ControlsSection(
    title: 'Account & Profile',
    subtitle: 'Identity and account controls for squad presence.',
    icon: Icons.person_outline,
    itemCount: 1,
    destination: ProfileScreen(),
  ),
  _ControlsSection(
    title: 'Notifications',
    subtitle: 'Alert preferences for shame, verdicts, and digests.',
    icon: Icons.notifications_none,
    itemCount: NotificationSettingsPage.itemCount,
    destination: NotificationSettingsPage(),
  ),
  _ControlsSection(
    title: 'Privacy & Data',
    subtitle: 'Visibility and export controls for personal usage data.',
    icon: Icons.lock_outline,
    itemCount: PrivacySettingsPage.itemCount,
    destination: PrivacySettingsPage(),
  ),
  _ControlsSection(
    title: 'Squad & Social',
    subtitle: 'Membership and moderation controls for squad operations.',
    icon: Icons.groups_outlined,
    itemCount: SquadSocialSettingsPage.itemCount,
    destination: SquadSocialSettingsPage(),
  ),
  _ControlsSection(
    title: 'App Management & Regimes',
    subtitle: 'Default regime behavior and block policy preferences.',
    icon: Icons.settings_input_component,
    itemCount: AppManagementSettingsPage.itemCount,
    destination: AppManagementSettingsPage(),
  ),
  _ControlsSection(
    title: 'Appearance & Experience',
    subtitle: 'Theme, feedback, and presentation preferences.',
    icon: Icons.palette_outlined,
    itemCount: AppearanceSettingsPage.itemCount,
    destination: AppearanceSettingsPage(),
  ),
  _ControlsSection(
    title: 'Advanced / Power User',
    subtitle: 'System-level tuning and recovery tooling.',
    icon: Icons.terminal_rounded,
    itemCount: AdvancedSettingsPage.itemCount,
    destination: AdvancedSettingsPage(),
  ),
  _ControlsSection(
    title: 'Behavioural / Gamification',
    subtitle: 'Streaks, benchmarks, and challenge participation settings.',
    icon: Icons.emoji_events_outlined,
    itemCount: BehaviouralSettingsPage.itemCount,
    destination: BehaviouralSettingsPage(),
  ),
];
