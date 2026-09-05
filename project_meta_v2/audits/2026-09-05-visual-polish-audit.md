# Revoke 2.0 Visual Polish Audit

Status: Point-in-time source audit for Phase 10, 2026-09-05.

This audit records implementation reality. The canonical visual direction remains in `design/overview.md`, the token contract remains in `design/design-system.md`, and the Phase 10 implementation review records the changes made after this inventory.

## Conclusion

Revoke has a partial but usable design system. `AppTheme`, `ColorScheme`, `AppColorsExtension`, `ThemeService`, NeueMontreal, the semantic token constants, shared buttons/surfaces/pills, and the four-destination shell provide a credible foundation. The product is not yet centrally governed across every active screen because feature code still contains substantial local styling and legacy copy.

## Existing strengths

- `lib/core/theme/app_theme.dart` centralizes the main Flutter theme, typography, inputs, buttons, navigation, and state colors.
- `lib/core/theme/revoke_tokens.dart` provides compact spacing, radius, border, elevation, icon, touch-target, and motion scales.
- `lib/core/widgets/revoke_components.dart` provides reusable actions, surfaces, pills, dividers, loading, empty, error, setting-row, and status-banner primitives.
- `lib/features/navigation/main_shell.dart` owns the v2 tab labels and global account actions.
- `ThemeService` preserves persisted mode/accent preferences while constraining accent values to a curated palette.
- The native blocker remains Kotlin-owned, which preserves the correct enforcement boundary.

## Inconsistencies found

- Older feature surfaces still use local radii from 10dp through 28dp, raw padding, and one-off borders.
- Older forms use both the governed input decoration and screen-local `InputDecoration` variants.
- Legacy Circle/Tribunal widgets retain punitive or theatrical labels and styling even though the routed Circle entry point uses v2 terminology.
- Several old screens still use Focus Score, Regime, Squad, Plea, or “Beg for time” language. These are compatibility, legacy, or admin paths and are not removed in Phase 10.
- Native enforcement previously kept its complete color vocabulary in Kotlin constants and used several untracked hex colors for glows, surfaces, and strokes.
- Profile and permission repair were visually denser and more container-heavy than the v2 contract.

## Hardcoded-value inventory

The repository contains approximately 83 `Color(...)` uses, 19 `Colors.*` uses, 239 explicit `EdgeInsets` expressions, 118 `BorderRadius.circular` expressions, 19 explicit elevations, and 9 `BoxShadow` expressions in Dart production code. These counts include legitimate layout-specific values and compatibility/admin code; they are not a directive to replace every literal.

The main migration target is semantic repetition: shared app surfaces, controls, dialogs, sheets, page rhythm, and status treatment. Exceptional layouts such as native intervention geometry, app icon tiles, and admin prototypes remain local until their owning phase.

## Component duplication

The main duplicated families are settings/info cards, selection cards, legacy Circle member and Tribunal rows, modal field layouts, and older Home/Regime presentation widgets. Phase 10 adds `RevokeSettingRow` and `RevokeStatusBanner` for future migration, while the current pass avoids a risky rewrite of the active Circle/Tribunal and enforcement logic.

## Native/Flutter divergence

Flutter now derives light/dark neutrals, fixed semantic states, and action colors from `RevokePalette`. Native overlays now resolve the corresponding palette through Android resources under `android/app/src/main/res/values/revoke_colors.xml`, `values-night/revoke_colors.xml`, and `revoke_dimens.xml`. Native still uses controlled Android sans typography rather than copying the OTF assets into Android resources. This is an explicit, low-risk divergence to revisit only if native font rendering becomes a product issue.

## Phase 10 changes reflected by this audit

- Replaced pure-black light-mode text/background assumptions in the active theme with the documented tinted semantic neutrals.
- Added governed Flutter dialog, sheet, snackbar, chip, divider, and progress defaults.
- Added shared setting-row and status-banner primitives.
- Tokenized and quieted Profile, Appearance, permission repair, and notification surfaces where they were directly modified.
- Prevented unchanged permission polling results from triggering a rebuild every two seconds.
- Mapped native blocker colors to Android resources and added content descriptions for native app/logo imagery.
- Replaced the active profile’s punitive account-deletion copy and stale Circle label.

## Deferred visual debt

- Full screen-by-screen migration of legacy Tribunal/Pillory/legacy Home widgets.
- Complete native typography asset integration and device-level overlay review.
- Visual migration of every old form and every legacy modal.
- Physical-device checks for large text, OEM system bars, TalkBack, and native overlay geometry.
- Removal of compatibility Focus Score, Regime, Squad, and Plea code after reference and product migration decisions.

## Review method

Source inventory, reference search, token/style inspection, Flutter analyzer, full Flutter tests, Android debug compilation, and `git diff --check` were run. No screenshot capture was available in the current environment, so device-level visual claims remain unverified.
