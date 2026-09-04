import 'package:flutter/material.dart';

class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  const AppColorsExtension({
    required this.accent,
    required this.accentSoft,
    required this.danger,
    required this.success,
    required this.warning,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceSubtle,
    required this.background,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.borderSubtle,
    required this.disabled,
    required this.enforcement,
  });

  final Color accent;
  final Color accentSoft;
  final Color danger;
  final Color success;
  final Color warning;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceSubtle;
  final Color background;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color borderSubtle;
  final Color disabled;
  final Color enforcement;

  /// V2 semantic name retained alongside the legacy `danger` field.
  Color get destructive => danger;

  Color get actionPrimary => accent;
  Color get actionSecondary => surfaceElevated;

  @override
  AppColorsExtension copyWith({
    Color? accent,
    Color? accentSoft,
    Color? danger,
    Color? success,
    Color? warning,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceSubtle,
    Color? background,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? borderSubtle,
    Color? disabled,
    Color? enforcement,
  }) {
    return AppColorsExtension(
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      danger: danger ?? this.danger,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      background: background ?? this.background,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      disabled: disabled ?? this.disabled,
      enforcement: enforcement ?? this.enforcement,
    );
  }

  @override
  AppColorsExtension lerp(ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) return this;
    return AppColorsExtension(
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      background: Color.lerp(background, other.background, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
      enforcement: Color.lerp(enforcement, other.enforcement, t)!,
    );
  }
}
