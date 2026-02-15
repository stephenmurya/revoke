import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_theme.dart';

class ChallengesScreen extends StatelessWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(
              PhosphorIcons.flag(PhosphorIconsStyle.fill),
              size: 64,
              color: AppSemanticColors.accent,
            ),
            const SizedBox(height: 16),
            Text(
              'Challenges: Coming Soon',
              textAlign: TextAlign.center,
              style: AppTheme.h3.copyWith(color: AppSemanticColors.primaryText),
            ),
          ],
        ),
      ),
    );
  }
}
