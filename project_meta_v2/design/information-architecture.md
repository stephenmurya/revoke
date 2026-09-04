# Revoke 2.0 Mobile Information Architecture

Status: Accepted target mobile information architecture. This is not implemented by this pass.

## Primary navigation

The target bottom navigation is:

1. **Today**
2. **Commitments**
3. **Circle**
4. **Insights**

Settings is not a primary tab. It lives under Profile/account. Notifications and Credits are global app-bar utilities where appropriate.

```mermaid
flowchart LR
    Today[Today] --- Commitments[Commitments]
    Commitments --- Circle[Circle]
    Circle --- Insights[Insights]
    Global[Global app bar: Credits, Notifications, Profile] --> Today
    Global --> Commitments
    Global --> Circle
    Global --> Insights
    Profile[Profile/account] --> Settings[Settings]
```

Current `/home` and `RegimesScreen` are migration locations, not the target product vocabulary. Schedules remain enforcement mechanisms beneath Commitments. Current `/squad` is the migration location for Circle. Current `/insights` maps naturally to Insights but must lose Focus Score framing.

## Global app bar

Conceptual arrangement:

`[page/title context]        [Credits pill] [Notifications] [Profile]`

Exact title behavior may vary by surface, but account actions should remain predictable. The Credits pill is compact, shows a coin/Credit icon and integer Available Credits, uses no currency symbol, and opens the detailed Credits/Wallet experience.

The Today surface must not use a large wallet balance card. Credit context appears only when relevant to the active Commitment, such as monitoring verification, Credits locked to that Commitment, or grace.

## Today

Today is the primary daily-state surface. It answers:

- What matters today?
- Am I within my active Commitments?
- What is restricted now?
- How much usage remains?
- How am I doing this week?

Priority order is current daily state, highest-priority active Commitment, usage remaining, active Protect windows, weekly adherence, override/recovery behavior, grace where relevant, and a concise active Commitment list. Do not create an opaque replacement for Focus Score or an equal-weight card grid.

## Commitments

Commitments is the management surface for Reduce and Protect Commitments, active and upcoming items, and completed/history where useful. Users reason about behavioral contracts. Regimes and schedules are implementation details beneath this surface or migration concepts.

## Circle

Circle is the Accountability Circle surface. It replaces Squad as the long-term product concept while preserving granular permissions, least-privilege projections, and bounded override participation. This pass does not define the entire Circle interaction model or quorum rules.

## Insights

Insights presents understandable behavioral evidence: adherence, usage trends, reduction trajectory, override patterns, recovery, eventually reliable danger periods, and per-app behavior. It should remain interpretive and focused rather than becoming a generic analytics dashboard. Focus Score is retired.

## Secondary surfaces

| Surface | Relationship to IA |
|---|---|
| Profile | Account identity, profile, account controls, and entry to Settings |
| Settings | Appearance, notifications, controls, whitelist, and account settings under Profile |
| Notifications | Global app-bar entry; not a bottom tab |
| Credits/Wallet | Global app-bar entry; available/locked balances, Premium redemption, purchases, and history |
| Commitment detail | Reached from Today or Commitments; shows evidence, current enforcement, progress, overrides, grace, and relevant Credit lock |
| Native blocker | Full-screen enforcement surface outside Flutter navigation, visually mapped to the same system |

## Migration rules

- Do not let `Regime`, `Schedule`, or `Squad` define new top-level labels.
- Migrate existing schedule cards into Commitment summaries without changing native enforcement ownership in the same pass.
- Retire Focus Score from new surface structure; direct interpretable metrics replace it.
- Keep Profile as the account gateway and do not elevate Settings into primary navigation.
