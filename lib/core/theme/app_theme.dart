import 'package:flutter/material.dart';

class AppPalette {
  const AppPalette._();

  // Base palette
  static const Color black = Color(0xFF000000);
  static const Color darkGrey = Color(0xFF121212);
  static const Color orange = Color(0xFFFF4500);
  static const Color deepRed = Color(0xFFFF3131);
  static const Color white = Color(0xFFFFFFFF);
  static const Color grey = Color(0xFF757575);
  static const Color lightGrey = Color(0xFFB0B0B0);
  static const Color trendUp = Color(0xFF00FF41);
  static const Color trendDown = Color(0xFFFF3131);
  static const Color acidGreen = Color(0xFFB7FF00);
}

class AppSemanticColors {
  const AppSemanticColors._();

  // Surfaces
  static const Color background = AppPalette.black;
  static const Color surface = Color(0xFF121212);
  static const Color accent = AppPalette.orange;
  static const Color danger = AppPalette.deepRed;
  static const Color success = AppPalette.trendUp;
  static const Color approve = AppPalette.acidGreen;
  static const Color reject = AppPalette.deepRed;

  // Text roles
  static const Color primaryText = AppPalette.white;
  static const Color secondaryText = AppPalette.lightGrey;
  static const Color mutedText = AppPalette.grey;
  static const Color accentText = AppPalette.orange;
  static const Color errorText = AppPalette.deepRed;
  static const Color inverseText = AppPalette.black;
  static const Color onAccentText = AppPalette.black;
  static const Color onDangerText = AppPalette.white;
  static const Color approveText = AppPalette.acidGreen;
  static const Color rejectText = AppPalette.deepRed;
  static Color get hintText => secondaryText.withValues(alpha: 0.6);
}

class AppTheme {
  static const String fontFamily = 'NeueMontreal';
  static const List<String> fontFamilyFallback = [
    'sans-serif',
    'Roboto',
    'Arial',
  ];

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

  static InputDecoration defaultInputDecoration({
    String? hintText,
    String? labelText,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: AppSemanticColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppSemanticColors.primaryText.withValues(alpha: 0.08),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppSemanticColors.accent, width: 2),
      ),
      labelStyle: bodyMedium.copyWith(
        color: AppSemanticColors.mutedText,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w700,
      ),
      floatingLabelStyle: bodyMedium.copyWith(
        color: AppSemanticColors.accentText,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w700,
      ),
      hintStyle: bodyMedium.copyWith(
        color: AppSemanticColors.hintText,
        letterSpacing: 0.2,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppSemanticColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppSemanticColors.accent,
        surface: AppSemanticColors.surface,
        onPrimary: AppSemanticColors.onAccentText,
        onSurface: AppSemanticColors.primaryText,
        error: AppSemanticColors.danger,
      ),

      // Typography
      textTheme: TextTheme(
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
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButtonStyle),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppSemanticColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppSemanticColors.primaryText.withValues(alpha: 0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppSemanticColors.accent, width: 2),
        ),
        labelStyle: bodyMedium.copyWith(
          color: AppSemanticColors.mutedText,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: bodyMedium.copyWith(
          color: AppSemanticColors.accentText,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: bodyMedium.copyWith(
          color: AppSemanticColors.hintText,
          letterSpacing: 0.2,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppSemanticColors.background,
        selectedItemColor: AppSemanticColors.accent,
        unselectedItemColor: AppSemanticColors.mutedText,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

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
  static final TextStyle squadCodeInput = size3xlBold.copyWith(letterSpacing: 2);

  // labelSmall: compact labels (chips, tiny headers, status labels).
  static final TextStyle labelSmall = xsBold.copyWith(letterSpacing: 0.6);

  static final SliderThemeData vowSliderTheme = SliderThemeData(
    activeTrackColor: AppSemanticColors.accent,
    inactiveTrackColor: AppSemanticColors.surface,
    thumbColor: AppSemanticColors.accent,
    overlayColor: AppSemanticColors.accent.withValues(alpha: 0.16),
    trackHeight: 4,
    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
    overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
  );

  // Button Styles
  static final ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: AppSemanticColors.accent,
    foregroundColor: AppSemanticColors.onAccentText,
    textStyle: bodyMedium.copyWith(fontWeight: FontWeight.w500),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
    elevation: 0,
  );

  static final ButtonStyle secondaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: AppSemanticColors.surface,
    foregroundColor: AppSemanticColors.primaryText,
    textStyle: bodyMedium.copyWith(fontWeight: FontWeight.w500),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: AppSemanticColors.primaryText.withValues(alpha: 0.1),
        width: 1,
      ),
    ),
    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
    elevation: 0,
  );

  static final ButtonStyle dangerButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: AppSemanticColors.background,
    foregroundColor: AppSemanticColors.errorText,
    textStyle: bodyMedium.copyWith(fontWeight: FontWeight.w500),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: AppSemanticColors.danger, width: 2),
    ),
    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
    elevation: 0,
  );

  static final BoxDecoration avatarBorderStyle = BoxDecoration(
    shape: BoxShape.circle,
    border: Border.all(color: AppSemanticColors.accent, width: 2),
  );

  // Chip decoration
  static BoxDecoration chipDecoration({Color? borderColor, Color? fillColor}) {
    return BoxDecoration(
      color: fillColor ?? AppSemanticColors.accent.withValues(alpha: 0.15),
      border: Border.all(
        color: borderColor ?? AppSemanticColors.accent,
        width: 1.5,
      ),
      borderRadius: BorderRadius.circular(10),
    );
  }

  static BoxDecoration get chatBubbleUserDecoration => BoxDecoration(
    color: AppSemanticColors.accent,
    borderRadius: BorderRadius.circular(16),
  );

  static BoxDecoration get chatBubbleOtherDecoration => BoxDecoration(
    color: AppSemanticColors.surface,
    border: Border.all(
      color: AppSemanticColors.primaryText.withValues(alpha: 0.08),
      width: 1,
    ),
    borderRadius: BorderRadius.circular(16),
  );

  static BoxDecoration get warningBannerDecoration => BoxDecoration(
    color: AppSemanticColors.accent,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: AppSemanticColors.background, width: 2),
    boxShadow: [
      BoxShadow(
        color: AppSemanticColors.accent.withValues(alpha: 0.35),
        blurRadius: 14,
        spreadRadius: 1,
      ),
    ],
  );

  static TextStyle get warningBannerTextStyle => baseBold.copyWith(
    color: AppSemanticColors.onAccentText,
    letterSpacing: 1.2,
  );

  static BoxDecoration get tribunalScoreboardDecoration => BoxDecoration(
    color: AppSemanticColors.background,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppSemanticColors.primaryText, width: 2),
    boxShadow: [
      BoxShadow(
        color: AppSemanticColors.primaryText.withValues(alpha: 0.12),
        blurRadius: 10,
        spreadRadius: 1,
      ),
    ],
  );

  static ButtonStyle tribunalVoteButtonStyle({
    required bool isSelected,
    bool isDanger = false,
  }) {
    final bgColor = isSelected
        ? (isDanger ? AppSemanticColors.reject : AppSemanticColors.accent)
        : AppSemanticColors.background;
    final fgColor = isSelected
        ? AppSemanticColors.primaryText
        : (isDanger
              ? AppSemanticColors.rejectText
              : AppSemanticColors.accentText);
    final borderColor = isSelected
        ? (isDanger ? AppSemanticColors.reject : AppSemanticColors.accent)
        : (isDanger ? AppSemanticColors.reject : AppSemanticColors.accent);

    return ElevatedButton.styleFrom(
      backgroundColor: bgColor,
      foregroundColor: fgColor,
      textStyle: baseMedium.copyWith(letterSpacing: 0.8, fontWeight: FontWeight.w500),
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
