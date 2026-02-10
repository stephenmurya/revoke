import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class LockScreen extends StatelessWidget {
  const LockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded, size: 80, color: AppTheme.orange),
              const SizedBox(height: 24),
              Text(
                'COOKED',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: AppTheme.orange,
                  letterSpacing: 4.0,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'YOUR TIME IS UP. GO TOUCH GRASS.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
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
