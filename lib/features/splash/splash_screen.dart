import 'package:flutter/material.dart';

import '../../core/theme/revoke_tokens.dart';
import '../../core/utils/theme_extensions.dart';
import '../../core/widgets/revoke_components.dart';

/// The router owns auth/onboarding decisions. Splash is presentation-only so
/// it cannot independently infer completion from profile or permissions.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Revoke', style: context.text.displaySmall),
            const SizedBox(height: RevokeSpacing.lg),
            const RevokeLoadingState(label: 'Getting things ready'),
          ],
        ),
      ),
    );
  }
}
