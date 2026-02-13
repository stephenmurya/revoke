import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class AccountSettingsPage extends StatelessWidget {
  const AccountSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.background,
      appBar: AppBar(
        backgroundColor: AppSemanticColors.background,
        elevation: 0,
        title: Text('Account & profile', style: AppTheme.h2),
        centerTitle: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'This page will handle display identity, profile photo, focus score visibility, leaderboard participation, and account deletion controls.',
            textAlign: TextAlign.center,
            style: AppTheme.bodyMedium.copyWith(
              color: AppSemanticColors.secondaryText,
              height: 1.6,
            ),
          ),
        ),
      ),
    );
  }
}
