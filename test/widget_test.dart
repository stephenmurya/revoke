import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:revoke/core/theme/app_theme.dart';
import 'package:revoke/features/auth/onboarding_screen.dart';

void main() {
  testWidgets('Revoke onboarding welcome is a real product entry point', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.create(
          brightness: Brightness.light,
          accent: const Color(0xFFFF5A1F),
        ),
        home: const Scaffold(body: OnboardingWelcome()),
      ),
    );

    expect(find.text('A clearer way to change your habits'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
  });
}
