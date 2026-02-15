import 'package:flutter/material.dart';

class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  const AppColorsExtension({
    required this.accent,
    required this.danger,
    required this.success,
    required this.warning,
    required this.surface,
    required this.background,
    required this.textPrimary,
    required this.textSecondary,
  });

  final Color accent;
  final Color danger;
  final Color success;
  final Color warning;
  final Color surface;
  final Color background;
  final Color textPrimary;
  final Color textSecondary;

  @override
  AppColorsExtension copyWith({
    Color? accent,
    Color? danger,
    Color? success,
    Color? warning,
    Color? surface,
    Color? background,
    Color? textPrimary,
    Color? textSecondary,
  }) {
    return AppColorsExtension(
      accent: accent ?? this.accent,
      danger: danger ?? this.danger,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      surface: surface ?? this.surface,
      background: background ?? this.background,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
    );
  }

  @override
  AppColorsExtension lerp(
    ThemeExtension<AppColorsExtension>? other,
    double t,
  ) {
    if (other is! AppColorsExtension) return this;
    return AppColorsExtension(
      accent: Color.lerp(accent, other.accent, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      background: Color.lerp(background, other.background, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
    );
  }
}

