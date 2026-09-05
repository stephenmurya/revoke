import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:revoke/core/services/theme_service.dart';
import 'package:revoke/core/theme/app_colors_extension.dart';
import 'package:revoke/core/theme/app_theme.dart';
import 'package:revoke/core/theme/revoke_tokens.dart';
import 'package:revoke/core/widgets/revoke_components.dart';
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

  testWidgets('shared state primitives expose semantic content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.create(
          brightness: Brightness.dark,
          accent: ThemeService.accentPalette.first,
        ),
        home: Scaffold(
          body: Column(
            children: [
              RevokeStatusBanner(
                title: 'Tracking needs attention',
                message: 'Open permissions to restore monitoring.',
                icon: PhosphorIcons.warning,
                tone: RevokeStatusTone.warning,
              ),
              RevokeSettingRow(
                title: 'Theme',
                subtitle: 'Follow the system',
                onTap: _noop,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Tracking needs attention'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    final semantics = tester.ensureSemantics();
    final node = tester.getSemantics(find.byType(RevokeSettingRow));
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.label, contains('Theme'));
    expect(node.label, contains('Follow the system'));
    semantics.dispose();
  });

  test('theme defaults use the documented restrained surface hierarchy', () {
    final light = AppTheme.create(
      brightness: Brightness.light,
      accent: ThemeService.accentPalette.first,
    );
    final dark = AppTheme.create(
      brightness: Brightness.dark,
      accent: ThemeService.accentPalette.first,
    );

    expect(light.scaffoldBackgroundColor, RevokePalette.backgroundLight);
    expect(dark.scaffoldBackgroundColor, RevokePalette.backgroundDark);
    expect(light.dialogTheme.elevation, RevokeElevation.raised);
    expect(dark.bottomSheetTheme.elevation, RevokeElevation.raised);
  });
}

void _noop() {}
