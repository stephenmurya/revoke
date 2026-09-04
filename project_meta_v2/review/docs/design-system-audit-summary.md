# Design-System Audit Summary

Review date: 2026-09-04

## Finding

Revoke currently has a **PARTIAL** design system: a real Flutter theme foundation exists, but screen-local styling and an independently hardcoded native overlay prevent central governance.

Detailed evidence is in [`audits/2026-09-04-design-system-audit.md`](../../audits/2026-09-04-design-system-audit.md). The target contract is [`design/design-system.md`](../../design/design-system.md), and target mobile IA is [`design/information-architecture.md`](../../design/information-architecture.md).

## Strongest foundations

- `AppTheme.create`, `AppColorsExtension`, and `ThemeContextExtensions` provide central theme access.
- `NeueMontreal` regular/medium/bold assets are declared in `pubspec.yaml`.
- Shared button/input styles, typography aliases, light/dark mode, `RevokeLogo`, and `RevokeProgressBar` already exist.
- Native blocker ownership and overlay structure are deliberate and should be preserved.

## Main fragmentation sources

- 74 Dart files contain roughly 68 `Color(...)`, 322 named `Colors.*`, 201 `EdgeInsets`, 359 `SizedBox`, 147 radius, 17 elevation, and 10 shadow occurrences.
- Feature screens create private card, row, sheet, and state treatments.
- The pre-Phase 1 audit found ten unrestricted accent colors; Phase 1 now constrains persisted and selectable values to five curated accents while preserving fixed semantic state colors.
- The Kotlin overlay uses hardcoded hex colors, dp values, Android system typefaces, and punitive legacy copy instead of shared semantic resources.
- Legacy content still uses Home/Regimes/Squad concepts and Focus Score, although the Phase 1 shell now presents the accepted Today/Commitments/Circle/Insights labels.

## Phase 1 implementation update

The audit's recommended foundation now exists in Flutter. The shell exposes the accepted Today / Commitments / Circle / Insights labels, shared primitives use semantic tokens, persisted accent values are constrained through a curated palette, and the app bar contains the compact zero-valued Credits placeholder plus Notifications and Profile. Legacy feature styling remains by design and native overlay styling is unchanged.

## Readiness

The project is ready for the focused Today redesign phase. Broad screen work must continue using the semantic tokens and shared primitives, while preserving native enforcement. No product question blocks the next UI phase itself; free/trial entitlements, the free-versus-Premium capability matrix, and final Circle quorum remain product decisions for later feature implementation.
