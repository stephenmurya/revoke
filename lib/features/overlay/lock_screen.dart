import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class LockScreen extends StatelessWidget {
  const LockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded, size: 80, color: AppSemanticColors.accent),
              const SizedBox(height: 24),
              Text(
                'COOKED',
                style: AppTheme.size4xlBold.copyWith(
                  color: AppSemanticColors.accentText,
                  letterSpacing: 4.0,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'YOUR TIME IS UP. GO TOUCH GRASS.',
                textAlign: TextAlign.center,
                style: AppTheme.lgBold.copyWith(
                  color: AppSemanticColors.primaryText,
                ),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () {
                  // This would normally be handled by the native layer
                },
                child: const Text('REDEEM YOURSELF'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
