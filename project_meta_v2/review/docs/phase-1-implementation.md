# Revoke 2.0 Phase 1 Implementation Review

Review date: 2026-09-04

This review covers the first implementation phase: the governed Flutter design-system foundation and global mobile shell. It does not claim that the legacy feature screens, Credit backend, native blocker visuals, or v2 domain model are implemented.

## Phase 1 Change Summary

### Source files created

- `lib/core/theme/revoke_tokens.dart`: compact semantic spacing, radius, icon, border, elevation, and motion constants.
- `lib/core/widgets/revoke_components.dart`: shared button, icon-button, surface, section-header, pill, divider, page-scaffold, and loading/empty/error primitives.
- `lib/core/widgets/revoke_credits_pill.dart`: compact zero-valued Credits placeholder with accessible semantics.
- `test/core/theme/revoke_design_system_test.dart`: token, accent-migration, semantic-theme, and Credits-pill coverage.

### Source files modified

- `lib/core/theme/app_colors_extension.dart`: semantic accent, surfaces, text, border, disabled, and enforcement fields.
- `lib/core/theme/app_theme.dart`: semantic theme values, typography role aliases, button/input tokens, and Material 3 NavigationBar theme.
- `lib/core/services/theme_service.dart`: curated accent palette, legacy persisted-value fallback, and normalization.
- `lib/features/navigation/main_shell.dart`: four-destination shell, global page context, Credits/Notifications/Profile actions, and NavigationBar.
- `lib/core/app_router.dart`: `/commitments` compatibility route and shell guard support.
- `lib/features/settings/appearance_screen.dart`: curated palette labels and neutral accent copy.

No Kotlin, Firebase, Firestore rules, Cloud Functions, dependency, asset, or `old_project_meta/` file was changed.

## Token Migration Summary

The existing `AppTheme`, `ColorScheme`, `AppColorsExtension`, `ThemeService`, persisted preferences, NeueMontreal fonts, and Material button/input foundations were retained. Phase 1 adds semantic categories for:

- spacing: `xs` through `xxl`, with a separate hero separation value;
- radii: control, card, large, and pill;
- typography: display, numeric display, page title, section title, card title, body, supporting body, label, caption, numeric stat, and button;
- icon sizes, borders, elevation, restrained shadows, and motion;
- surfaces, text hierarchy, action/accent, fixed state colors, disabled, and enforcement.

Legacy screen-local styling remains intentionally in feature code. It will be migrated as each feature is redesigned; this pass does not attempt a repository-wide hardcoded-value cleanup.

## Component Inventory

| Component | Ownership | Phase 1 use |
|---|---|---|
| `RevokeButton` | `lib/core/widgets/revoke_components.dart` | Primary, secondary, tertiary, destructive, loading/disabled actions |
| `RevokeIconButton` | same | Consistent icon-only tap targets and semantics |
| `RevokeSurface` | same | Restrained reusable grouping surface |
| `RevokeSectionHeader` | same | Section title/action alignment |
| `RevokePill` | same | Status and compact account utility treatment |
| `RevokeCreditsPill` | `lib/core/widgets/revoke_credits_pill.dart` | Global available-Credits placeholder; no fake data source |
| `RevokeDivider` | shared | Subtle divider treatment |
| `RevokeLoadingState`, `RevokeEmptyState`, `RevokeErrorState` | shared | Baseline state primitives |
| `RevokePageScaffold` | shared | Optional standard page padding/safe-area scaffold |

## Navigation Migration

| Previous/current implementation | Phase 1 shell label | Compatibility behavior |
|---|---|---|
| `/home`, `RegimesScreen`, `HomeScreen` content | Today | `/home` remains valid; `/commitments` also points to the existing `RegimesScreen` during migration |
| legacy schedule/regime management | Commitments | Internal class/model names remain unchanged for now |
| `/squad`, `SquadScreen` | Circle | Existing Squad functionality remains reachable; Circle domain/permissions are later work |
| `/insights`, `InsightsScreen` | Insights | Existing Insights content remains; Focus Score migration is later work |

Settings remains outside primary navigation and Profile remains the account entry. Notifications is a global app-bar action. The Credits pill is a compact `0` placeholder and taps to a safe not-yet-available message; no purchase or ledger behavior was introduced.

## Regression Review

Phase 1 verification commands and results:

- `flutter analyze`: PASS - no issues found.
- `flutter test test/core/theme/revoke_design_system_test.dart`: PASS - 3 tests passed.
- `flutter test`: FAIL only in the pre-existing `test/widget_test.dart` smoke test. It mounts `RevokeApp` without initializing Firebase and still expects the obsolete counter UI; the Firebase `[core/no-app]` exception and missing `0` assertion were reproduced. The schedule/model/validator suites and the new design-system suite passed before that legacy failure.
- `flutter --version`: Flutter 3.47.0 stable, Dart 3.13.0.
- `flutter build apk --debug`: PASS — `build/app/outputs/flutter-apk/app-debug.apk` built with the existing Android toolchain. Gradle/AGP/Kotlin deprecation warnings were reported by Flutter, but no source or dependency changes were made.

No native enforcement or Firebase behavior was changed by this phase.

## Deferred UI Debt

The following are intentionally deferred, not forgotten:

- broader Today migration beyond the Phase 2 implementation's current evidence boundary;
- full Commitments migration from Regimes/Schedules;
- Circle terminology and granular-permission UX;
- Insights redesign and category/danger-period evidence;
- Settings/Profile visual migration;
- native blocker/reminder resource mapping and visual alignment;
- feature-wide migration of hardcoded presentation values and duplicate legacy components;
- real Credits, Premium, purchase disclosure, ledger, and billing flows.

## Implementation readiness

The foundation enabled the dedicated Today redesign delivered in Phase 2. The shell remains a migration layer over working legacy routes, not a claim that the complete Revoke 2.0 product is ready for release.
