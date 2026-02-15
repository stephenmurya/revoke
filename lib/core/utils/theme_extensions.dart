import 'package:flutter/material.dart';

import '../theme/app_colors_extension.dart';

extension ThemeContextExtensions on BuildContext {
  AppColorsExtension get colors =>
      Theme.of(this).extension<AppColorsExtension>()!;

  TextTheme get text => Theme.of(this).textTheme;

  ColorScheme get scheme => Theme.of(this).colorScheme;
}

