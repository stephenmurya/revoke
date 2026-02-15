import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/utils/theme_extensions.dart';

class ChallengesScreen extends StatelessWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(
              PhosphorIcons.flag(PhosphorIconsStyle.fill),
              size: 64,
              color: context.scheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Challenges: Coming Soon',
              textAlign: TextAlign.center,
              style: context.text.titleLarge?.copyWith(
                    color: context.scheme.onSurface.withValues(alpha: 0.78),
                  ) ??
                  TextStyle(color: context.scheme.onSurface.withValues(alpha: 0.78)),
            ),
          ],
        ),
      ),
    );
  }
}
