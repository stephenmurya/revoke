# Revoke 2.0 Current Design-System Audit

Review date: 2026-09-04  
Scope: current Flutter mobile UI, native Android enforcement UI, assets, theme/configuration, and tests. Browser, desktop, iOS, and implementation changes are out of scope.

## Conclusion

**PARTIAL — foundational theme exists but significant screen-local styling remains.**

Revoke has a real theme foundation in `lib/core/theme/app_theme.dart`, `lib/core/theme/app_colors_extension.dart`, `lib/core/utils/theme_extensions.dart`, and `lib/core/services/theme_service.dart`. The foundation includes Material 3, `ThemeData`, a custom `ThemeExtension`, shared typography aliases, global button/input styles, light/dark mode, and persisted accent selection.

It is not a coherent centrally governed design system yet. Production screens still construct their own cards, spacing, radii, borders, shadows, buttons, sheets, and typography. Native enforcement is a separate programmatic Android surface with its own palette, typefaces, dimensions, and action language.

## Existing strengths

- `AppTheme.create()` centralizes the app entry theme and uses `ThemeData`/`ColorScheme` rather than styling every screen from scratch.
- `AppColorsExtension` and `ThemeContextExtensions` provide a usable path for semantic colors through `context.colors`, `context.text`, and `context.scheme`.
- `NeueMontreal` is a deliberate brand asset with regular, medium, and bold OTF weights declared in `pubspec.yaml`.
- `AppTheme` already exposes a size scale from 10 to 48 and semantic-ish aliases such as `h1`, `h2`, `h3`, `bodyLarge`, `bodyMedium`, and `bodySmall`.
- Global elevated/outlined button and input styles exist and should be the starting point for consolidation.
- `RevokeLogo` and `RevokeProgressBar` are small reusable primitives.
- The native overlay has a deliberate dark surface, readable text hierarchy, app identity, structured stats, and explicit action zone rather than being a default platform dialog.
- Loading, empty, permission, and error paths exist across the major screens, even though their treatments are not yet governed consistently.

## Inconsistencies

The current app uses the shared theme opportunistically, then overrides it locally. `HomeScreen` renders a large Focus Score card, uppercase section labels, hitlist imagery, and 24dp schedule cards. `MainShell` still labels the primary tab `Regimes`, uses a logo wordmark, and provides notifications/profile but no Credits utility; its avatar currently routes to `/controls` while `/profile` is a separate route. `AppearanceScreen` previews retired Focus Score language and offers ten unrestricted accent colors. Onboarding uses large hero numbers, uppercase command copy, 4/8/12/16/20/24/32dp radii, and several local button treatments.

`InsightsScreen`, `SquadScreen`, `TribunalScreen`, `ProfileScreen`, and `CreateScheduleScreen` each contain private card and row families. Similar concepts therefore vary in padding, corner radius, border opacity, elevation, and action hierarchy. The target v2 Commitment/Circle model also conflicts structurally with the current schedule/regime and Squad-first surfaces.

## Hardcoded-value inventory

The following counts are raw source occurrences from 74 Dart files, including shared theme code and admin/prototype code; they show scale, not a claim that every occurrence is wrong:

| Pattern | Raw occurrences | Observed range/pattern |
|---|---:|---|
| `Color(...)` | 68 | Repeated literal colors, especially in theme and feature screens |
| `Colors.*` | 322 | Named Material colors and screen-local state treatments |
| `EdgeInsets.*` | 201 | Common values include 8, 12, 14, 16, 20, 24, 28, and 32 |
| `SizedBox(...)` | 359 | Many one-off vertical and horizontal gaps |
| `Radius.circular(...)` | 147 | Common radii include 4, 8, 10, 12, 14, 16, 18, 20, 24, 28, and 999 |
| `elevation:` | 17 | Mostly zero or small local values |
| `BoxShadow(...)` | 10 | Several screen-specific blur/opacity treatments |
| border width/opacity literals | 151 / 151 | Repeated local 1, 1.5, 2, and 2.5 treatments plus alpha values |
| direct `fontSize:` literals outside token definitions | 5 | Home 64, schedule creation 92, pillory hero 13 repeated three times |

The strongest repeated spacing convention is an informal 8dp rhythm with frequent 12/14/16dp exceptions. The strongest radius convention is not a single scale: 12/14/16 appear in ordinary Flutter grouping, 18/20/24 appear in prominent cards/sheets, and 999 is used for pills and avatars. This is enough evidence for consolidation, not enough evidence to preserve every value as a token.

## Typography audit

The declared font is `NeueMontreal` with weights 400, 500, and 700. `AppTheme` defines 10, 12, 14, 16, 20, 24, 32, 40, and 48 sizes. This is a useful foundation, but semantic intent is mixed: `size5xlMedium` still describes Focus Score/dashboard metrics, `h1`/`h2` aliases coexist with Material names, and feature code directly uses 64, 92, and 13.

The next system should preserve the font and weights, but expose semantic roles such as display, page title, section title, card title, body, supporting, label, caption, and numeric emphasis. Feature code should select a role, not a numeric size. Native overlays currently use Android `sans-serif-medium`, `sans-serif-black`, and `Typeface.DEFAULT_BOLD` in `BlockerOverlayController.kt`, so the native mapping must be explicit.

## Color audit

Flutter defines light background `#F2F2F7`, light surface `#FFFFFF`, dark background `#000000`, dark surface `#1C1C1E`, primary from the user accent, danger `#FF3B30`, success `#34C759`, and warning `#FFCC00`. `AppColorsExtension` exposes only accent, danger, success, warning, surface, background, primary text, and secondary text. It does not expose elevated surface, muted text, subtle border, disabled content, or enforcement-specific semantics.

`ColorScheme.fromSeed()` is created for each accent, then only selected fields are overridden. The accent palette in `ThemeService` has ten very different colors (`Blaze`, `Crimson`, `Biohazard`, `Protocol`, `Voltage`, `Sovereign`, `Plasma`, `Cobalt`, `Stealth`, and `Mint`). This makes the accent carry arbitrary emotional meaning and can produce weak contrast or make the primary action resemble a status color. Error/success/warning are fixed in the theme, which is a good starting constraint.

Native `BlockerOverlayController.kt` independently defines dark colors from `#06070A` through `#F5F7FA`, with orange `#FF4500`, soft orange `#FF915A`, and multiple hand-authored translucent gradients. These are visually intentional but not connected to Android resources or Flutter semantic names.

## Asset and icon audit

`pubspec.yaml` exposes broad `assets/branding/` and `assets/fonts/` directories. `RevokeLogo` directly loads `assets/branding/icon_source.png`; native code uses Android launcher assets plus `ic_lock_premium.xml`. Most feature icons come from `phosphoricons_flutter`, which is a useful consistent icon source, but there is no documented semantic icon set or shared icon-size contract in feature code. App icons are also rendered by local feature/native helpers such as `SingleAppIcon` and the native overlay hero.

## Layout, surfaces, and component audit

- Page insets most often start at 8 or 16dp, but forms and hero screens use 20, 24, 28, or 32dp without a shared page contract.
- `HomeScreen` uses multiple nested containers, schedule cards with 24dp corners and shadows, pill labels, a large emoji hero, and a floating action button.
- `InsightsScreen` has multiple private metric/chart/card components and a segmented control, while `SquadScreen` and `TribunalScreen` use separate private cards and sheets.
- `ProfileScreen`, `AppearanceScreen`, and permission surfaces use card-inside-card structures and 14/16/24/28dp corners.
- `CreateScheduleScreen` is especially dense and contains local type option cards, condition cards, tag pills, lists, selectors, and multiple sheet treatments.
- `AppTheme` has reusable styles, but also duplicates button factories, input decoration, chat bubbles, warning banners, tribunal scoreboard, and chip decoration rather than exposing a small governed component contract.
- There is no shared production app-bar widget, Credit pill, empty-state primitive, error-state primitive, settings row, or Commitment card primitive.

## Current screen hierarchy audit

| Surface | Current implementation evidence | Audit finding |
|---|---|---|
| Onboarding | `features/auth/onboarding_screen.dart`, a stateful multi-step screen with sliders, permission/recruitment steps, local buttons, and `AnimatedSwitcher` | Strong willingness to guide the user, but large hero numbers, command-style uppercase copy, mixed radii, and dense step-local layouts do not yet express calm v2 Commitment onboarding |
| Permission setup | `features/permissions/permission_screen.dart`, permission disclosure cards and status pills | Functional status hierarchy exists, but 28dp outer cards, 18dp inner callouts, 999 pills, and screen-local padding create another surface language |
| Current Home / target Today | `/home` -> `RegimesScreen` -> `HomeScreen`; `FocusScoreCard`, `_buildPermissionAlertCard`, `_buildTaperCtaCard`, `_buildScheduleCard` | The current screen is a schedule dashboard with Focus Score, hitlist, large emoji schedule cards, and floating add action. It lacks target Today prioritization and the global Credits utility |
| Schedule creation/detail | `/regime/new`, `/regime/edit` -> `CreateScheduleScreen` | A substantial form works as current implementation, but its local type cards, condition cards, tag pills, sheets, and 92px numeric hero are dense and schedule-centric rather than Commitment-centric |
| Taper plan | `HomeScreen._showTaperSetupSheet()` and `_buildTaperCtaCard()` | Useful baseline-to-plan path exists, but it is an opt-in Home sheet rather than a first-class Reduce Commitment flow |
| Insights | `features/insights/insights_screen.dart`, private metric/chart/app cards, segmented period control, app detail route | Evidence is useful, but the repeated card hierarchy and legacy Focus Score area encourage a dashboard aesthetic. Direct adherence, trends, recovery, and per-app evidence should be prioritized |
| Squad / target Circle | `features/squad/squad_screen.dart`, `_BarracksHeader`, `_LiveTribunalBanner`, roster and plea cards | Social interaction is present, but “barracks”/tribunal styling and multiple nested containers are visually noisy and structurally tied to Squad rather than optional Circle |
| Tribunal and Plea | `features/squad/tribunal_screen.dart`, `features/plea/plea_compose_screen.dart` | Chat/voting/action flows are separate local implementations with their own bubbles, cards, and sheets; they need Circle permission/state semantics and shared dialog/action primitives |
| Notifications | `features/notifications/notifications_screen.dart` | Has loading/error/empty/tile states, but notification tiles use local 16dp cards, shadows, and type-color mapping rather than a shared state-row contract |
| Profile and settings | `features/profile/profile_screen.dart`, `features/settings/controls_hub_screen.dart`, `appearance_screen.dart`, settings notification/whitelist screens | Account and settings are separate routed surfaces with repeated info cards and rows. Appearance previews retired Focus Score and offers unrestricted accents; Settings should remain under Profile in v2 |
| Focus Score legacy | `features/home/focus_score_detail_screen.dart`, `features/monitor/widgets/focus_score_card.dart`, appearance preview | Existing code is visually prominent but explicitly retired from v2; it should not anchor the replacement Today hierarchy |
| Native intervention | `BlockerOverlayController`, `BlockPresentation`, `RevokeAccessibilityService`, `EnforcementEngine` | Enforcement hierarchy is deliberate and first-class, but its native visual system diverges from Flutter and uses punitive legacy copy; preserve ownership and map visual semantics |

## Component duplication classification

| Family | Classification | Evidence and direction |
|---|---|---|
| Theme/color/typography foundation | KEEP / REFINE | `AppTheme`, `AppColorsExtension`, `ThemeContextExtensions`; add semantic coverage and remove ambiguous aliases over time |
| Logo and progress primitive | KEEP / REFINE | `RevokeLogo`, `RevokeProgressBar`; preserve and align sizes/semantics |
| Global buttons and inputs | KEEP / CONSOLIDATE | `AppTheme` styles exist, but screens override them; make the shared contract the default |
| App bars and navigation | REPLACE at v2 surface level | `MainShell` owns a legacy HUD header and `BottomNavigationBar`; target IA requires Today/Commitments/Circle/Insights and consistent global actions |
| Cards, stat cards, rows, sheets | CONSOLIDATE | Private implementations recur in Home, Insights, Squad, Tribunal, Profile, settings, and schedule creation |
| Focus Score card/detail/preview | REMOVE from v2 product UX | `focus_score_card.dart`, `focus_score_detail_screen.dart`, and appearance preview are legacy paths; retain only as migration evidence |
| Current schedule/regime cards | REFINE / REPLACE structurally | `HomeScreen._buildScheduleCard()` is a useful enforcement summary but must become Commitment-oriented |
| Native blocker and reminders | KEEP / REFINE | Preserve `BlockerOverlayController` and native authority; map it to shared semantics/resources |
| Squad-specific visual language | REPLACE gradually | `pillory_hero.dart`, barracks/tribunal treatments, and punitive copy conflict with Circle direction |

## Native/Flutter divergence

`BlockerOverlayController.kt` builds overlays entirely in Kotlin with hardcoded hex colors, dp dimensions, rounded `GradientDrawable`s, and Android system typefaces. It uses a 244dp hero, 104dp app tile, 42dp badge, 18/24/32dp corners, 10–28sp text, orange glows, and actions such as `ACCEPT FATE`, `BEG FOR TIME`, and `OPEN SQUAD SETUP`.

Flutter uses NeueMontreal, Material `ColorScheme`, light/dark surfaces, 12–24dp card corners, and feature-local overrides. The native overlay is therefore a first-class but visually separate product. Its enforcement status is authoritative and must remain native; visual integration should happen through shared semantic design concepts and mirrored Android resources, not by moving blocking into Flutter.

## Migration recommendation

Centralize, in order:

1. semantic colors and typography roles;
2. page inset, spacing, radius, border, and elevation tokens;
3. global app bar, bottom navigation, button, input, row, empty/error/loading, and progress primitives;
4. Commitment and enforcement-state components;
5. native Android colors, dimensions, type, and action styles using the same semantic names;
6. screen migration, beginning with Today/Home, Commitment management, and the blocker experience.

Consolidation should be incremental. Working enforcement behavior and the useful theme foundation should not be discarded for aesthetic purity.

## Do-not-rewrite list

- `AppTheme.create()` and the existing `AppColorsExtension` are a viable base.
- `ThemeService` persistence and system/light/dark mode behavior are viable, subject to accent constraints.
- `RevokeLogo` and the progress bar are small enough to keep.
- Native overlay ownership, accessibility-triggered presentation, and native reminder timing are product-critical and should not be replaced with Flutter.
- Existing loading/error/empty branches should be retained while their visuals are standardized.
- `NeueMontreal` assets and the existing weight declarations should remain the brand typography base.
