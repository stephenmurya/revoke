import 'package:flutter/material.dart';

import '../../core/utils/theme_extensions.dart';

class LockScreen extends StatelessWidget {
  const LockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_rounded,
                size: 80,
                color: context.scheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'COOKED',
                style: (context.text.displayMedium ?? const TextStyle()).copyWith(
                  color: context.scheme.primary,
                  letterSpacing: 4.0,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'YOUR TIME IS UP. GO TOUCH GRASS.',
                textAlign: TextAlign.center,
                style: (context.text.titleMedium ?? const TextStyle()).copyWith(
                  color: context.scheme.onSurface,
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
