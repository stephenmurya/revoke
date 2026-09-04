# 012 - Revoke 2.0 Mobile Design Direction and Information Architecture

Status: Accepted  
Date: 2026-09-04

## Decision

Revoke 2.0 mobile design is calm, precise, authoritative, refined, and premium. Hierarchy comes primarily from typography, whitespace, alignment, scale, and contrast, with selective surfaces and restrained radii, borders, shadows, and elevation.

The target bottom navigation is:

1. Today;
2. Commitments;
3. Circle; and
4. Insights.

Settings belongs under Profile/account. Notifications and Credits are global app-bar utilities where appropriate. The global arrangement is conceptually `[page/title context] [Credits pill] [Notifications] [Profile]`.

The Credits pill is compact, shows an integer Available Credits amount and coin/Credit icon, avoids currency symbols and finance-style balance coloring, and opens the detailed Credits/Wallet experience. Today does not show a large wallet balance card; Credit context appears only when relevant to an active Commitment.

A governed semantic design system is required before broad v2 UI implementation. It must cover Flutter and native Android surfaces, including typography, color, spacing, surfaces, controls, state communication, motion, and accessibility. The native blocker remains native and first-class; visual consistency is achieved through mapped semantic resources, not by moving enforcement into Flutter.

## Rationale

The current app has a partial Flutter theme but substantial screen-local styling and a separate hardcoded native overlay vocabulary. A small governed contract reduces visual drift while preserving working enforcement architecture.

## Consequences

- New v2 screens use the design-system roles and target IA rather than schedule/regime or Squad-first top-level structure.
- Focus Score is not reintroduced as a dashboard centerpiece.
- Credits remain subordinate account context and do not turn Today into a financial account surface.
- The implementation pass must validate light/dark, accent, native overlay, text scaling, and dynamic-state accessibility before broad rollout.
