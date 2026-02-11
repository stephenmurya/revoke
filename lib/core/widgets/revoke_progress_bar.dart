import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RevokeProgressBar extends StatelessWidget {
  final int totalSteps;
  final int currentStep;

  const RevokeProgressBar({
    super.key,
    required this.totalSteps,
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (index) {
        return Expanded(
          child: Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: index <= currentStep ? AppTheme.orange : AppTheme.darkGrey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
