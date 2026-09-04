import 'package:flutter/material.dart';

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
