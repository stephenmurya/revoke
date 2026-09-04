import 'package:flutter/material.dart';

import '../services/theme_service.dart';
import 'app_colors_extension.dart';
import 'revoke_tokens.dart';

class AppTheme {
  static const String fontFamily = 'NeueMontreal';
  static const List<String> fontFamilyFallback = [
    'sans-serif',
    'Roboto',
    'Arial',
  ];
  static const Color prototypeBannerColor = Color(0xFFD100A6);
  static const Color prototypeBannerOnColor = Color(0xFFFFFFFF);

  static TextStyle _type({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  // Typography size scale
  static const double sizeXs = 10;
  static const double sizeSm = 12;
  static const double sizeBase = 14;
  static const double sizeLg = 16;
  static const double sizeXl = 20;
  static const double sizeXxl = 24;
  static const double size3xl = 32;
  static const double size4xl = 40;
  static const double size5xl = 48;

  static const TextCapitalization defaultTextCapitalization =
      TextCapitalization.sentences;

  static Brightness _resolveEffectiveBrightness() {
    final mode = ThemeService.instance.themeMode.value;
    switch (mode) {
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness;
    }
  }

  static Color _resolveEffectiveAccent() {
    return ThemeService.normalizeAccent(
      ThemeService.instance.accentColor.value,
    );
  }

  static InputDecoration defaultInputDecoration({
    String? hintText,
    String? labelText,
    Widget? prefixIcon,
  }) {
    final brightness = _resolveEffectiveBrightness();
    final accent = _resolveEffectiveAccent();
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF10131A) : const Color(0xFFFFFFFF);
    final onSurface = isDark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF000000);
    final muted = onSurface.withValues(alpha: 0.65);

    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: RevokeSpacing.lg,
        vertical: RevokeSpacing.lg,
      ),
      border: OutlineInputBorder(
        borderRadius: RevokeRadii.controlRadius,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: RevokeRadii.controlRadius,
        borderSide: BorderSide(color: onSurface.withValues(alpha: 0.10)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: RevokeRadii.controlRadius,
        borderSide: BorderSide(color: accent, width: RevokeBorders.emphasis),
      ),
      labelStyle: bodyMedium.copyWith(
        color: muted,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w700,
      ),
      floatingLabelStyle: bodyMedium.copyWith(
        color: accent,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w700,
      ),
      hintStyle: bodyMedium.copyWith(
        color: onSurface.withValues(alpha: 0.55),
        letterSpacing: 0.2,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  static ThemeData create({
    required Brightness brightness,
    required Color accent,
  }) {
    final bool isDark = brightness == Brightness.dark;
    final Color safeAccent = ThemeService.normalizeAccent(accent);

    // Fixed neutral surfaces. Avoid Material seed tinting.
    final Color background = isDark
        ? const Color(0xFF000000)
        : const Color(0xFFF2F2F7);
    final Color surface = isDark
        ? const Color(0xFF10131A)
        : const Color(0xFFFFFFFF);
    final Color surfaceElevated = isDark
        ? const Color(0xFF141923)
        : const Color(0xFFFFFFFF);
    final Color surfaceSubtle = isDark
        ? const Color(0xFF0D1117)
        : const Color(0xFFF2F2F7);
    final Color onSurface = isDark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF000000);
    final Color textSecondary = onSurface.withValues(
      alpha: isDark ? 0.70 : 0.75,
    );
    final Color danger = const Color(0xFFFF3B30);
    final Color success = const Color(0xFF34C759);
    final Color warning = const Color(0xFFFFCC00);
    final Color enforcement = isDark
        ? const Color(0xFFFF915A)
        : const Color(0xFFC2410C);
    final Color textMuted = isDark
        ? const Color(0xFF6E7888)
        : onSurface.withValues(alpha: 0.55);
    final Color borderSubtle = isDark
        ? const Color(0xFF273142)
        : onSurface.withValues(alpha: 0.10);
    final Color disabled = onSurface.withValues(alpha: 0.38);

    final ColorScheme seedScheme = ColorScheme.fromSeed(
      seedColor: safeAccent,
      brightness: brightness,
    );

    final ColorScheme scheme = seedScheme.copyWith(
      primary: safeAccent,
      surface: surface,
      onSurface: onSurface,
      error: danger,
    );

    final appColors = AppColorsExtension(
      accent: safeAccent,
      accentSoft: safeAccent.withValues(alpha: 0.12),
      danger: danger,
      success: success,
      warning: warning,
      surface: surface,
      surfaceElevated: surfaceElevated,
      surfaceSubtle: surfaceSubtle,
      background: background,
      textPrimary: onSurface,
      textSecondary: textSecondary,
      textMuted: textMuted,
      borderSubtle: borderSubtle,
      disabled: disabled,
      enforcement: enforcement,
    );

    final TextTheme baseTextTheme = TextTheme(
      displayLarge: size5xlBold,
      displayMedium: size4xlBold,
      displaySmall: size3xlBold,
      headlineLarge: xxlBold,
      headlineMedium: xxlMedium,
      headlineSmall: xlBold,
      titleLarge: xlMedium,
      titleMedium: lgMedium,
      titleSmall: baseMedium,
      bodyLarge: lgRegular,
      bodyMedium: baseRegular,
      bodySmall: smRegular,
      labelLarge: baseBold,
      labelMedium: smMedium,
      labelSmall: xsBold,
    ).apply(bodyColor: onSurface, displayColor: onSurface);

    final ButtonStyle primary = ElevatedButton.styleFrom(
      backgroundColor: safeAccent,
      foregroundColor: scheme.onPrimary,
      textStyle: bodyMedium.copyWith(fontWeight: FontWeight.w500),
      shape: const RoundedRectangleBorder(
        borderRadius: RevokeRadii.controlRadius,
      ),
      padding: const EdgeInsets.symmetric(
        vertical: RevokeSpacing.lg,
        horizontal: RevokeSpacing.xl,
      ),
      elevation: RevokeElevation.none,
    );

    final ButtonStyle outlined = OutlinedButton.styleFrom(
      foregroundColor: safeAccent,
      textStyle: bodyMedium.copyWith(fontWeight: FontWeight.w500),
      shape: const RoundedRectangleBorder(
        borderRadius: RevokeRadii.controlRadius,
      ),
      side: BorderSide(
        color: safeAccent.withValues(alpha: 0.45),
        width: RevokeBorders.subtle,
      ),
      padding: const EdgeInsets.symmetric(
        vertical: RevokeSpacing.lg,
        horizontal: RevokeSpacing.xl,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      extensions: <ThemeExtension<dynamic>>[appColors],

      // Typography
      textTheme: baseTextTheme,

      // App bar
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: onSurface,
        elevation: RevokeElevation.none,
        scrolledUnderElevation: RevokeElevation.none,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: h2.copyWith(color: onSurface),
        iconTheme: IconThemeData(color: onSurface),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(style: primary),
      outlinedButtonTheme: OutlinedButtonThemeData(style: outlined),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: RevokeSpacing.lg,
          vertical: RevokeSpacing.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: RevokeRadii.controlRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: RevokeRadii.controlRadius,
          borderSide: BorderSide(color: borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: RevokeRadii.controlRadius,
          borderSide: BorderSide(
            color: safeAccent,
            width: RevokeBorders.emphasis,
          ),
        ),
        labelStyle: bodyMedium.copyWith(
          color: textSecondary,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: bodyMedium.copyWith(
          color: safeAccent,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: bodyMedium.copyWith(
          color: onSurface.withValues(alpha: 0.55),
          letterSpacing: 0.2,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: safeAccent,
        unselectedItemColor: textSecondary,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: RevokeElevation.none,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: safeAccent.withValues(alpha: 0.14),
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: RevokeRadii.controlRadius,
        ),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>(
          (states) => IconThemeData(
            size: RevokeIconSizes.emphasis,
            color: states.contains(WidgetState.selected)
                ? safeAccent
                : textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
          (states) =>
              (states.contains(WidgetState.selected) ? smMedium : smRegular)
                  .copyWith(
                    color: states.contains(WidgetState.selected)
                        ? safeAccent
                        : textSecondary,
                  ),
        ),
      ),
    );
  }

  @Deprecated(
    'Use AppTheme.create(brightness: Brightness.dark, accent: ...) instead.',
  )
  static ThemeData get darkTheme =>
      create(brightness: Brightness.dark, accent: const Color(0xFFFF4500));

  // Typography Tokens
  // Rule: do not create ad hoc TextStyles in feature code. Use these tokens.
  // Each token is documented by intended usage context.

  // xs (10): micro text
  // xsRegular: legal microcopy, metadata footnotes, passive helper text.
  static final TextStyle xsRegular = _type(
    size: sizeXs,
    weight: FontWeight.w400,
  );
  // xsMedium: compact caption emphasis, timestamps in dense lists.
  static final TextStyle xsMedium = _type(
    size: sizeXs,
    weight: FontWeight.w500,
  );
  // xsBold: labels, micro badges, tiny counters, chip micro labels.
  static final TextStyle xsBold = _type(size: sizeXs, weight: FontWeight.w700);

  // sm (12): caption text
  // smRegular: captions, secondary metadata, subdued info rows.
  static final TextStyle smRegular = _type(
    size: sizeSm,
    weight: FontWeight.w400,
  );
  // smMedium: emphasized captions and compact supporting text.
  static final TextStyle smMedium = _type(
    size: sizeSm,
    weight: FontWeight.w500,
  );
  // smBold: short labels under icons, compact status tags, KPI micro headers.
  static final TextStyle smBold = _type(size: sizeSm, weight: FontWeight.w700);

  // base (14): default reading size
  // baseRegular: standard body text, feed text, chat lines, form help text.
  static final TextStyle baseRegular = _type(
    size: sizeBase,
    weight: FontWeight.w400,
  );
  // baseMedium: medium-emphasis body text and control labels.
  static final TextStyle baseMedium = _type(
    size: sizeBase,
    weight: FontWeight.w500,
  );
  // baseBold: button labels, warning lines, important short statements.
  static final TextStyle baseBold = _type(
    size: sizeBase,
    weight: FontWeight.w700,
  );

  // lg (16): prominent body size
  // lgRegular: long-form body where readability is prioritized.
  static final TextStyle lgRegular = _type(
    size: sizeLg,
    weight: FontWeight.w400,
  );
  // lgMedium: primary body blocks, list row titles, social feed author lines.
  static final TextStyle lgMedium = _type(
    size: sizeLg,
    weight: FontWeight.w500,
  );
  // lgBold: action-forward body text, emphasized row headers, compact CTAs.
  static final TextStyle lgBold = _type(size: sizeLg, weight: FontWeight.w700);

  // xl (20): section-level hierarchy
  // xlRegular: relaxed section intros and subhead copy.
  static final TextStyle xlRegular = _type(
    size: sizeXl,
    weight: FontWeight.w400,
  );
  // xlMedium: section headers and major card titles.
  static final TextStyle xlMedium = _type(
    size: sizeXl,
    weight: FontWeight.w500,
  );
  // xlBold: high-attention section headers and compact overlay headlines.
  static final TextStyle xlBold = _type(size: sizeXl, weight: FontWeight.w700);

  // xxl (24): page-title tier
  // xxlRegular: relaxed page title treatment.
  static final TextStyle xxlRegular = _type(
    size: sizeXxl,
    weight: FontWeight.w400,
  );
  // xxlMedium: default page titles in app bars and major screens.
  static final TextStyle xxlMedium = _type(
    size: sizeXxl,
    weight: FontWeight.w500,
  );
  // xxlBold: punchy page titles and modal headline emphasis.
  static final TextStyle xxlBold = _type(
    size: sizeXxl,
    weight: FontWeight.w700,
  );

  // 3xl (32): hero headline tier
  // size3xlRegular: light hero headings.
  static final TextStyle size3xlRegular = _type(
    size: size3xl,
    weight: FontWeight.w400,
  );
  // size3xlMedium: medium hero titles.
  static final TextStyle size3xlMedium = _type(
    size: size3xl,
    weight: FontWeight.w500,
  );
  // size3xlBold: strong hero titles and key numeric emphasis.
  static final TextStyle size3xlBold = _type(
    size: size3xl,
    weight: FontWeight.w700,
  );

  // 4xl (40): display headline tier
  // size4xlRegular: display text where tone is calm.
  static final TextStyle size4xlRegular = _type(
    size: size4xl,
    weight: FontWeight.w400,
  );
  // size4xlMedium: display headings for high-priority states.
  static final TextStyle size4xlMedium = _type(
    size: size4xl,
    weight: FontWeight.w500,
  );
  // size4xlBold: overlays, lock-screen statements, high-alert banners.
  static final TextStyle size4xlBold = _type(
    size: size4xl,
    weight: FontWeight.w700,
  );

  // 5xl (48): hero numeric/display tier
  // size5xlRegular: large numeric readouts where subtlety is preferred.
  static final TextStyle size5xlRegular = _type(
    size: size5xl,
    weight: FontWeight.w400,
  );
  // size5xlMedium: large values, focus score, dashboard headline metrics.
  static final TextStyle size5xlMedium = _type(
    size: size5xl,
    weight: FontWeight.w500,
  );
  // size5xlBold: highest-emphasis metrics and splash/hero impact lines.
  static final TextStyle size5xlBold = _type(
    size: size5xl,
    weight: FontWeight.w700,
  );

  // Legacy aliases (keep for migration safety).
  // h1: large headline (hero/major screen title).
  static final TextStyle h1 = size3xlBold;

  // h2: page title (app bars, top-level sections).
  static final TextStyle h2 = xxlMedium;

  // h3: section title (cards, grouped content blocks).
  static final TextStyle h3 = xlMedium;

  // bodyLarge: emphasized body text (list titles, feed headings).
  static final TextStyle bodyLarge = lgMedium;

  // bodyMedium: default body text (chat messages, form text, paragraphs).
  static final TextStyle bodyMedium = baseRegular;

  // bodySmall: muted support text (captions, helper copy, metadata).
  static final TextStyle bodySmall = smRegular;

  // squadCodeInput: large alphanumeric code display/input treatment.
  static final TextStyle squadCodeInput = size3xlBold.copyWith(
    letterSpacing: 2,
  );

  // labelSmall: compact labels (chips, tiny headers, status labels).
  static final TextStyle labelSmall = xsBold.copyWith(letterSpacing: 0.6);

  // Revoke 2.0 semantic roles. Feature code should prefer these names over
  // selecting a numeric size directly.
  static final TextStyle display = size4xlBold;
  static final TextStyle numericDisplay = size3xlBold;
  static final TextStyle pageTitle = xxlMedium;
  static final TextStyle sectionTitle = xlMedium;
  static final TextStyle cardTitle = lgMedium;
  static final TextStyle body = lgRegular;
  static final TextStyle bodySecondary = baseRegular;
  static final TextStyle label = smMedium;
  static final TextStyle caption = xsRegular;
  static final TextStyle numericStat = size3xlMedium;
  static final TextStyle button = baseMedium;

  static final SliderThemeData vowSliderTheme = SliderThemeData(
    activeTrackColor: _resolveEffectiveAccent(),
    inactiveTrackColor: _resolveEffectiveBrightness() == Brightness.dark
        ? const Color(0xFF1C1C1E)
        : const Color(0xFFFFFFFF),
    thumbColor: _resolveEffectiveAccent(),
    overlayColor: _resolveEffectiveAccent().withValues(alpha: 0.16),
    trackHeight: 4,
    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
    overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
  );

  // Button Styles
  static ButtonStyle get primaryButtonStyle {
    final accent = _resolveEffectiveAccent();
    final brightness = _resolveEffectiveBrightness();
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    );
    return ElevatedButton.styleFrom(
      backgroundColor: accent,
      foregroundColor: scheme.onPrimary,
      textStyle: bodyMedium.copyWith(fontWeight: FontWeight.w500),
      shape: const RoundedRectangleBorder(
        borderRadius: RevokeRadii.controlRadius,
      ),
      padding: const EdgeInsets.symmetric(
        vertical: RevokeSpacing.lg,
        horizontal: RevokeSpacing.xl,
      ),
      elevation: RevokeElevation.none,
    );
  }

  static ButtonStyle get secondaryButtonStyle {
    final brightness = _resolveEffectiveBrightness();
    final surface = brightness == Brightness.dark
        ? const Color(0xFF1C1C1E)
        : const Color(0xFFFFFFFF);
    final onSurface = brightness == Brightness.dark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF000000);
    return ElevatedButton.styleFrom(
      backgroundColor: surface,
      foregroundColor: onSurface,
      textStyle: bodyMedium.copyWith(fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(
        borderRadius: RevokeRadii.controlRadius,
        side: BorderSide(color: onSurface.withValues(alpha: 0.10), width: 1),
      ),
      padding: const EdgeInsets.symmetric(
        vertical: RevokeSpacing.lg,
        horizontal: RevokeSpacing.xl,
      ),
      elevation: RevokeElevation.none,
    );
  }

  static ButtonStyle get dangerButtonStyle {
    final brightness = _resolveEffectiveBrightness();
    final background = brightness == Brightness.dark
        ? const Color(0xFF000000)
        : const Color(0xFFF2F2F7);
    const danger = Color(0xFFFF3B30);
    return ElevatedButton.styleFrom(
      backgroundColor: background,
      foregroundColor: danger,
      textStyle: bodyMedium.copyWith(fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(
        borderRadius: RevokeRadii.controlRadius,
        side: const BorderSide(color: danger, width: 2),
      ),
      padding: const EdgeInsets.symmetric(
        vertical: RevokeSpacing.lg,
        horizontal: RevokeSpacing.xl,
      ),
      elevation: RevokeElevation.none,
    );
  }

  static BoxDecoration get avatarBorderStyle => BoxDecoration(
    shape: BoxShape.circle,
    border: Border.all(color: _resolveEffectiveAccent(), width: 2),
  );

  // Chip decoration
  static BoxDecoration chipDecoration({Color? borderColor, Color? fillColor}) {
    final accent = _resolveEffectiveAccent();
    return BoxDecoration(
      color: fillColor ?? accent.withValues(alpha: 0.15),
      border: Border.all(color: borderColor ?? accent, width: 1.5),
      borderRadius: BorderRadius.circular(10),
    );
  }

  static BoxDecoration get chatBubbleUserDecoration => BoxDecoration(
    color: _resolveEffectiveAccent(),
    borderRadius: BorderRadius.circular(16),
  );

  static BoxDecoration get chatBubbleOtherDecoration => BoxDecoration(
    color: _resolveEffectiveBrightness() == Brightness.dark
        ? const Color(0xFF1C1C1E)
        : const Color(0xFFFFFFFF),
    border: Border.all(
      color:
          (_resolveEffectiveBrightness() == Brightness.dark
                  ? const Color(0xFFFFFFFF)
                  : const Color(0xFF000000))
              .withValues(alpha: 0.10),
      width: 1,
    ),
    borderRadius: BorderRadius.circular(16),
  );

  static BoxDecoration get warningBannerDecoration => BoxDecoration(
    color: _resolveEffectiveAccent(),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(
      color: _resolveEffectiveBrightness() == Brightness.dark
          ? const Color(0xFF000000)
          : const Color(0xFFF2F2F7),
      width: 2,
    ),
    boxShadow: [
      BoxShadow(
        color: _resolveEffectiveAccent().withValues(alpha: 0.35),
        blurRadius: 14,
        spreadRadius: 1,
      ),
    ],
  );

  static TextStyle get warningBannerTextStyle => baseBold.copyWith(
    color: ColorScheme.fromSeed(
      seedColor: _resolveEffectiveAccent(),
      brightness: _resolveEffectiveBrightness(),
    ).onPrimary,
    letterSpacing: 1.2,
  );

  static BoxDecoration get tribunalScoreboardDecoration => BoxDecoration(
    color: _resolveEffectiveBrightness() == Brightness.dark
        ? const Color(0xFF000000)
        : const Color(0xFFF2F2F7),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color:
          (_resolveEffectiveBrightness() == Brightness.dark
                  ? const Color(0xFFFFFFFF)
                  : const Color(0xFF000000))
              .withValues(alpha: 0.90),
      width: 2,
    ),
    boxShadow: [
      BoxShadow(
        color:
            (_resolveEffectiveBrightness() == Brightness.dark
                    ? const Color(0xFFFFFFFF)
                    : const Color(0xFF000000))
                .withValues(alpha: 0.12),
        blurRadius: 10,
        spreadRadius: 1,
      ),
    ],
  );

  static ButtonStyle tribunalVoteButtonStyle({
    required bool isSelected,
    bool isDanger = false,
  }) {
    final accent = _resolveEffectiveAccent();
    final brightness = _resolveEffectiveBrightness();
    final background = brightness == Brightness.dark
        ? const Color(0xFF000000)
        : const Color(0xFFF2F2F7);
    final onSurface = brightness == Brightness.dark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF000000);
    const danger = Color(0xFFFF3B30);

    final Color active = isDanger ? danger : accent;
    final bgColor = isSelected ? active : background;
    final fgColor = isSelected ? onSurface : active;
    final borderColor = active;

    return ElevatedButton.styleFrom(
      backgroundColor: bgColor,
      foregroundColor: fgColor,
      textStyle: baseMedium.copyWith(
        letterSpacing: 0.8,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: borderColor, width: 2.5),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      elevation: 0,
    );
  }

  static InputDecoration get nicknameInputDecoration =>
      defaultInputDecoration(hintText: 'e.g. Terminator');
}
