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
- `ThemeService` exposes ten unrestricted accent colors; semantic state meaning is not fully protected.
- The Kotlin overlay uses hardcoded hex colors, dp values, Android system typefaces, and punitive legacy copy instead of shared semantic resources.
- Current top-level structure is Home/Regimes/Squad/Insights with Focus Score, not Today/Commitments/Circle/Insights.

## Readiness

The project is ready to begin a focused implementation pass only after the implementation team treats the new design documents as the contract. Broad screen work should begin with semantic tokens and shared primitives, then the app bar/navigation and Today surface, while preserving native enforcement. No product question blocks the design-system pass itself; free/trial entitlements, the free-versus-Premium capability matrix, and final Circle quorum remain product decisions for later feature implementation.
