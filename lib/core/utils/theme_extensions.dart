import 'package:flutter/material.dart';

import '../theme/app_colors_extension.dart';
import '../theme/app_theme.dart';

extension ThemeContextExtensions on BuildContext {
  AppColorsExtension get colors =>
      Theme.of(this).extension<AppColorsExtension>()!;

  TextTheme get text => Theme.of(this).textTheme;

  ColorScheme get scheme => Theme.of(this).colorScheme;
}

/// Semantic typography accessors keep feature code independent from numeric
/// Material type tiers while preserving the existing ThemeData/TextTheme base.
extension RevokeTextThemeExtensions on TextTheme {
  TextStyle get display => AppTheme.display;
  TextStyle get pageTitle => AppTheme.pageTitle;
  TextStyle get sectionTitle => AppTheme.sectionTitle;
  TextStyle get cardTitle => AppTheme.cardTitle;
  TextStyle get body => AppTheme.body;
  TextStyle get bodySecondary => AppTheme.bodySecondary;
  TextStyle get label => AppTheme.label;
  TextStyle get caption => AppTheme.caption;
  TextStyle get numericDisplay => AppTheme.numericDisplay;
  TextStyle get numericStat => AppTheme.numericStat;
  TextStyle get button => AppTheme.button;
}
