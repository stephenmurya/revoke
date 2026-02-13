import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class SquadScreen extends StatelessWidget {
  const SquadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('The Squad', style: AppTheme.h2),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.groups, size: 64, color: AppSemanticColors.primaryText),
            const SizedBox(height: 16),
            Text('No squad members yet', style: AppTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(
              'You are surviving alone',
              style: AppTheme.bodyMedium.copyWith(
                color: AppSemanticColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
