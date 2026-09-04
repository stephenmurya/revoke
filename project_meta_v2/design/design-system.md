# Revoke 2.0 Mobile Design-System Contract

Status: Proposed implementation contract based on the current source audit and accepted v2 direction. It is documentation only; no tokens or components are implemented by this pass.

## Token philosophy

Use a small semantic vocabulary. Feature code should request meaning (`surface`, `textPrimary`, `warning`, `commitmentActive`) rather than choose arbitrary palette values. Platform-specific values may differ slightly while preserving semantic relationships.

## Color tokens

The existing Flutter and native values provide the starting palette. The implementation pass should expose these as semantic tokens and validate contrast for every light/dark and accent combination.

| Token | Light starting value | Dark starting value | Meaning |
|---|---|---|---|
| `background` | `#F2F2F7` | `#06070A` | App/page background |
| `surface` | `#FFFFFF` | `#10131A` | Standard grouped surface |
| `surfaceElevated` | `#FFFFFF` | `#141923` | Deliberately elevated surface |
| `textPrimary` | `#000000` | `#F5F7FA` | Main readable content |
| `textSecondary` | existing high-contrast neutral | `#96A2B4` | Supporting content |
| `textMuted` | derived accessible neutral | `#6E7888` | Metadata only, never essential meaning |
| `borderSubtle` | low-alpha primary text | `#273142` | Dividers and low-emphasis grouping |
| `actionPrimary` | controlled accent | `#FF4500` starting accent | Main action |
| `actionSecondary` | surface + subtle border | `#171B24` | Secondary action |
| `success` | `#34C759` | `#34C759` | Verified success / healthy state |
| `warning` | `#FFCC00` | `#FFCC00` | Attention / incomplete setup |
| `destructive` | `#FF3B30` | `#FF3B30` | Destructive action or confirmed failure |
| `enforcement` | semantic accent/error mapping | orange/amber semantic mapping | Blocked, protected, or intervention state |

Success, warning, destructive, and enforcement meaning must not be replaced by a user accent. Credits use the accent or a restrained neutral coin treatment, never a finance-style positive/negative balance palette.

## Typography roles

Use `NeueMontreal` with the existing 400, 500, and 700 weights. The following is the target semantic scale; line height should be set per role and remain compatible with text scaling.

| Role | Starting size | Weight | Use |
|---|---:|---:|---|
| `display` | 40 | 700 | Rare hero or enforcement statement |
| `numericDisplay` | 32 | 500/700 | Usage remaining or meaningful numeric emphasis |
| `pageTitle` | 24 | 500/700 | Top-level screen title |
| `sectionTitle` | 20 | 500/700 | Major section |
| `cardTitle` | 16 | 500/700 | Commitment, row, or grouped surface title |
| `body` | 16 | 400 | Primary reading copy |
| `bodyEmphasis` | 16 | 500 | Emphasized body/control text |
| `supporting` | 14 | 400/500 | Secondary explanation and row detail |
| `label` | 12 | 500/700 | Compact labels and status pills |
| `caption` | 10 | 400/500 | Metadata only |

Do not introduce feature-local numeric sizes without a documented exception. A native enforcement headline may use a display role, but should not create a second brand hierarchy.

## Spacing tokens

Use `space1=4`, `space2=8`, `space3=12`, `space4=16`, `space5=24`, and `space6=32`. Use 40 only for intentional hero/page separation. Default mobile page inset is 16; use 24 for a deliberately spacious entry or enforcement surface. Prefer vertical rhythm over arbitrary `SizedBox` values.

## Radius tokens

Use `radiusControl=8`, `radiusCard=12`, `radiusLarge=16`, and `radiusPill=999`. A native full-screen intervention may use `radiusLarge`; 24 or more is an explicit hero treatment, not the default card radius.

## Borders and elevation

- `borderDefault`: 1dp, subtle semantic border.
- `borderEmphasis`: 2dp, selected or critical state only.
- `elevationNone`: default grouping through whitespace and surface contrast.
- `elevationRaised`: one restrained shadow level for a floating sheet, dialog, or primary overlay.
- `elevationHero`: reserved for native blocker/intervention emphasis; avoid stacking multiple shadows.

Do not combine a heavy border, bright fill, large radius, and strong shadow unless the state genuinely requires intervention emphasis.

## Icon sizes and tap targets

Use semantic icon sizes 16 (inline), 20 (row/control), 24 (standard action), 32 (feature), and 40 (account utility/coin icon when appropriate). Interactive targets should be at least 48dp even when the glyph is smaller. Icon meaning must be paired with text or accessible labels when color/status alone is insufficient.

## Motion tokens

- `micro`: 120ms, decelerated, for pressed/selected feedback;
- `state`: 180–220ms, ease-out/decelerate, for status and progress changes;
- `transition`: 280–320ms, ease-out, for screen/sheet transitions;
- native overlay entry may use the existing 120–140ms fade/scale family if it remains legible.

Motion must communicate a product state and respect reduced-motion preferences.

## Component contract

The implementation pass should centralize these production families:

- global app bar with title context, Credits pill, notifications, and profile;
- Today/Commitment/Circle/Insights navigation;
- primary, secondary, quiet, destructive, and icon actions;
- text fields/selectors with consistent error and focus treatment;
- Commitment card and enforcement-state summary;
- settings/list rows;
- status pill, progress, usage bar, and compact stat group;
- empty, loading, error, permission, and offline states;
- modal/bottom-sheet shell;
- avatar and app-icon treatment.

Semantically identical families should not be reimplemented inside Insights, Squad/Circle, Tribunal, Profile, and schedule creation.

## Flutter to native mapping

The native overlay remains Kotlin-owned. The implementation pass should map semantic names to Android resources, for example `revoke_background`, `revoke_surface`, `revoke_surface_elevated`, `revoke_text_primary`, `revoke_text_secondary`, `revoke_border_subtle`, `revoke_action_primary`, `revoke_success`, `revoke_warning`, and `revoke_destructive`, with matching dimension and text-appearance resources.

`BlockerOverlayController` should consume the Android mapping rather than inventing new hex values per view. Native action labels should use calm, precise Revoke copy while preserving the enforcement action hierarchy. Do not replace native blocking with Flutter.

## Accessibility minimums

- Validate normal text and state text against the chosen background; do not claim formal certification from this document.
- Preserve meaning in text, icon, and structure; never communicate success, failure, progress, or enforcement only by color.
- Keep interactive targets at least 48dp and provide content descriptions for icon-only controls.
- Ensure text scaling does not clip disclosure, Commitment, Credit, or enforcement copy.
- Keep disabled controls legible enough to understand why they are unavailable.
- Announce validation errors and dynamic state changes through accessible semantics.
- Test native overlays with TalkBack, large text, and gesture navigation; full-screen interception must not make the intervention unreadable or impossible to dismiss when dismissal is permitted.

## Accent customization

Recommendation: **constrain and redesign**, not remove outright. Retain user choice only through a small set of contrast-tested accent themes. The selected accent may affect action emphasis, selection, and decorative identity, but never success, warning, destructive, disabled, or enforcement meaning. Do not expose unrestricted arbitrary colors or allow an accent to become the entire semantic palette.

Each candidate accent must be tested for light/dark contrast, primary button legibility, focus indicators, charts/progress, native overlay readability, and color-vision ambiguity. Existing `ThemeService.accentPalette` and the `AppearanceScreen` picker are evidence of the current feature, not the v2 contract.
