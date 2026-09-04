import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revoke/core/services/theme_service.dart';
import 'package:revoke/core/theme/app_theme.dart';
import 'package:revoke/features/commitments/create_commitment_screen.dart';

void main() {
  testWidgets('starts with behavioral Reduce and Protect choices', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.create(
          brightness: Brightness.dark,
          accent: ThemeService.accentPalette.first,
        ),
        home: const CreateCommitmentScreen(),
      ),
    );

    expect(find.text('What do you want to do?'), findsOneWidget);
    expect(find.text('Reduce'), findsOneWidget);
    expect(find.text('Protect'), findsOneWidget);
    expect(find.text('Create Schedule'), findsNothing);

    await tester.tap(find.text('Reduce'));
    await tester.pump();
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets(
    'Protect intent can be selected without exposing schedule types',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.create(
            brightness: Brightness.dark,
            accent: ThemeService.accentPalette.first,
          ),
          home: const CreateCommitmentScreen(),
        ),
      );

      await tester.tap(find.text('Protect'));
      await tester.pump();
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Time Block'), findsNothing);
      expect(find.text('Usage Limit'), findsNothing);
      expect(find.text('Launch Count'), findsNothing);
    },
  );
}
