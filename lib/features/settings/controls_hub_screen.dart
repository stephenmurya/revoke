import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/utils/theme_extensions.dart';
import 'appearance_screen.dart';
import 'pages/account_settings_page.dart';
import 'pages/advanced_settings_page.dart';
import 'pages/app_management_settings_page.dart';
import 'pages/behavioural_settings_page.dart';
import 'pages/notification_settings_page.dart';
import 'pages/privacy_settings_page.dart';
import 'pages/squad_social_settings_page.dart';
import 'widgets/settings_option_tile.dart';

class ControlsHubScreen extends StatefulWidget {
  const ControlsHubScreen({super.key});

  @override
  State<ControlsHubScreen> createState() => _ControlsHubScreenState();
}

class _ControlsHubScreenState extends State<ControlsHubScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final next = _searchController.text.trim().toLowerCase();
      if (next == _query) return;
      setState(() => _query = next);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sections = _filteredSections(_query);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Controls',
          style: context.text.headlineMedium ?? const TextStyle(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search controls...',
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  child: PhosphorIcon(
                    PhosphorIcons.magnifyingGlass(),
                    size: 18,
                    color: context.colors.textSecondary,
                  ),
                ),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 0, minHeight: 0),
              ),
            ),
            const SizedBox(height: 18),
            for (final section in sections) ...[
              SettingsOptionTile(
                title: section.title,
                subtitle: section.subtitle,
                icon: section.icon,
                onTap: () {
                  final destination = section.destination;
                  if (destination == null) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => destination),
                  );
                },
              ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }

  static List<_ControlsSection> _filteredSections(String query) {
    if (query.isEmpty) return _controlsSections;
    return _controlsSections.where((s) {
      final title = s.title.toLowerCase();
      final subtitle = s.subtitle.toLowerCase();
      return title.contains(query) || subtitle.contains(query);
    }).toList(growable: false);
  }
}

class _ControlsSection {
  _ControlsSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.destination,
  });

  final String title;
  final String subtitle;
  final PhosphorIconData icon;
  final Widget? destination;
}

final List<_ControlsSection> _controlsSections = [
  _ControlsSection(
    title: 'Account & Profile',
    subtitle: 'Identity and account controls for squad presence.',
    icon: PhosphorIcons.user(),
    destination: AccountSettingsPage(),
  ),
  _ControlsSection(
    title: 'Notifications',
    subtitle: 'Alert preferences for shame, verdicts, and digests.',
    icon: PhosphorIcons.bell(),
    destination: NotificationSettingsPage(),
  ),
  _ControlsSection(
    title: 'Privacy & Data',
    subtitle: 'Visibility and export controls for personal usage data.',
    icon: PhosphorIcons.lockSimple(),
    destination: PrivacySettingsPage(),
  ),
  _ControlsSection(
    title: 'Squad & Social',
    subtitle: 'Membership and moderation controls for squad operations.',
    icon: PhosphorIcons.users(),
    destination: SquadSocialSettingsPage(),
  ),
  _ControlsSection(
    title: 'App Management & Regimes',
    subtitle: 'Default regime behavior and block policy preferences.',
    icon: PhosphorIcons.slidersHorizontal(),
    destination: AppManagementSettingsPage(),
  ),
  _ControlsSection(
    title: 'Appearance & Experience',
    subtitle: 'Theme, feedback, and presentation preferences.',
    icon: PhosphorIcons.palette(),
    destination: AppearanceScreen(),
  ),
  _ControlsSection(
    title: 'Advanced / Power User',
    subtitle: 'System-level tuning and recovery tooling.',
    icon: PhosphorIcons.terminalWindow(),
    destination: AdvancedSettingsPage(),
  ),
  _ControlsSection(
    title: 'Behavioural / Gamification',
    subtitle: 'Streaks, benchmarks, and challenge participation settings.',
    icon: PhosphorIcons.trophy(),
    destination: BehaviouralSettingsPage(),
  ),
];
