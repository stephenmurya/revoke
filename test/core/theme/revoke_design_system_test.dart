import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:revoke/core/services/theme_service.dart';
import 'package:revoke/core/theme/app_colors_extension.dart';
import 'package:revoke/core/theme/app_theme.dart';
import 'package:revoke/core/theme/revoke_tokens.dart';
import 'package:revoke/core/widgets/revoke_credits_pill.dart';

void main() {
  test('Revoke token scales stay deliberately compact', () {
    expect(RevokeSpacing.xs, lessThan(RevokeSpacing.sm));
    expect(RevokeSpacing.sm, lessThan(RevokeSpacing.md));
    expect(RevokeSpacing.md, lessThan(RevokeSpacing.lg));
    expect(RevokeSpacing.lg, lessThan(RevokeSpacing.xl));
    expect(RevokeRadii.control, lessThan(RevokeRadii.card));
    expect(RevokeIconSizes.compact, lessThan(RevokeIconSizes.emphasis));
  });

  test('accent normalization migrates legacy and rejects arbitrary colors', () {
    expect(
      ThemeService.normalizeAccent(const Color(0xFFFF4500)),
      const Color(0xFFC2410C),
    );
    expect(
      ThemeService.normalizeAccent(const Color(0xFF123456)),
      ThemeService.accentPalette.first,
    );
  });

  testWidgets('theme exposes semantic colors and Credits pill', (tester) async {
    final theme = AppTheme.create(
      brightness: Brightness.dark,
      accent: ThemeService.accentPalette.first,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(body: RevokeCreditsPill(onPressed: () {})),
      ),
    );

    final colors = theme.extension<AppColorsExtension>();
    expect(colors, isNotNull);
    expect(colors!.surfaceElevated, isNot(colors.surface));
    expect(colors.destructive, colors.danger);
    expect(colors.actionPrimary, colors.accent);
    expect(find.text('0'), findsOneWidget);
    expect(find.byIcon(PhosphorIcons.coins), findsOneWidget);
  });
}
