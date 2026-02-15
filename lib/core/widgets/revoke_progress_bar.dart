import 'package:flutter/material.dart';

import '../utils/theme_extensions.dart';

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
              color: index <= currentStep
                  ? context.scheme.primary
                  : context.scheme.surface,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
