import 'package:flutter/material.dart';

/// Fixed semantic colors shared by the Flutter theme and the native mapping
/// documented under project_meta_v2/design/design-system.md.
abstract final class RevokePalette {
  static const Color backgroundLight = Color(0xFFF2F2F7);
  static const Color backgroundDark = Color(0xFF06070A);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF10131A);
  static const Color elevatedLight = Color(0xFFFFFFFF);
  static const Color elevatedDark = Color(0xFF141923);
  static const Color subtleLight = Color(0xFFF2F2F7);
  static const Color subtleDark = Color(0xFF0D1117);
  static const Color textPrimaryLight = Color(0xFF14171C);
  static const Color textPrimaryDark = Color(0xFFF5F7FA);
  static const Color textSecondaryLight = Color(0xFF4A505A);
  static const Color textSecondaryDark = Color(0xFF96A2B4);
  static const Color textMutedLight = Color(0xFF6B7280);
  static const Color textMutedDark = Color(0xFF6E7888);
  static const Color borderLight = Color(0x1A14171C);
  static const Color borderDark = Color(0xFF273142);
  static const Color success = Color(0xFF238B4B);
  static const Color successDark = Color(0xFF34C759);
  static const Color warning = Color(0xFF9A6700);
  static const Color warningDark = Color(0xFFFFCC00);
  static const Color destructive = Color(0xFFD92D20);
  static const Color destructiveDark = Color(0xFFFF3B30);
  static const Color enforcementLight = Color(0xFFC2410C);
  static const Color enforcementDark = Color(0xFFFF915A);
}

/// Small, semantic layout scale for Revoke surfaces.
abstract final class RevokeSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double hero = 40;
}

abstract final class RevokeRadii {
  static const double control = 8;
  static const double card = 12;
  static const double large = 16;
  static const double pill = 999;

  static const BorderRadius controlRadius = BorderRadius.all(
    Radius.circular(control),
  );
  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(card),
  );
  static const BorderRadius largeRadius = BorderRadius.all(
    Radius.circular(large),
  );
  static const BorderRadius pillRadius = BorderRadius.all(
    Radius.circular(pill),
  );
}

abstract final class RevokeIconSizes {
  static const double compact = 16;
  static const double standard = 20;
  static const double emphasis = 24;
  static const double feature = 32;
  static const double account = 40;
}

abstract final class RevokeTouchTargets {
  static const double minimum = 48;
}

abstract final class RevokeBorders {
  static const double subtle = 1;
  static const double emphasis = 2;
}

abstract final class RevokeElevation {
  static const double none = 0;
  static const double raised = 2;
  static const double hero = 4;
}

abstract final class RevokeMotion {
  static const Duration micro = Duration(milliseconds: 120);
  static const Duration state = Duration(milliseconds: 200);
  static const Duration transition = Duration(milliseconds: 300);

  static const Curve curve = Curves.easeOutCubic;
}
