# Revoke 2.0 Design Overview

Status: Canonical mobile design direction. This document defines target design intent; the dated audit in `../audits/2026-09-04-design-system-audit.md` records current implementation reality.

## Product feeling

Revoke 2.0 should feel calm, precise, authoritative, refined, and premium.

It should not feel like a finance app, crypto/token wallet, aggressively gamified productivity app, childish habit tracker, excessively soft wellness app, cyberpunk punishment app, or generic Material demo.

## Hierarchy principles

Use typography, whitespace, alignment, scale, and contrast as the primary hierarchy tools. Use surfaces selectively. Avoid card-inside-card layouts and grids of equally weighted dashboard cards. Use restrained radii, borders, shadows, and elevation.

Use one controlled accent system. Semantic state colors are reserved for meaning: success, warning, destructive, monitoring, and enforcement. Credits remain subordinate account context; they must not become a green/gold financial visual system.

## Motion principle

Motion communicates state changes, successful transitions, Commitment activation, enforcement changes, Credit lock/release, and progress. It is not decorative spectacle. Every motion treatment must remain understandable with reduced-motion settings and must not hide a state change.

## Quality bar

Revoke 2.0 is intended to be a product users are willing to pay approximately $10/month to use. This is a quality bar, not marketing copy and not a reason to add visual effects. It requires coherent hierarchy, predictable interaction, deliberate typography, consistent spacing, polished state transitions, high-quality empty/loading/error states, clear copy, reliable enforcement feedback, integrated native surfaces, and no obvious prototype styling.

## Native is first-class

Native enforcement is part of the product surface. The implementation pass must preserve native blocking and reminders while mapping Flutter semantic tokens to Android resources/styles. Flutter is not the authority for foreground enforcement merely to obtain visual consistency.

## Scope

This design area covers mobile Revoke only: Flutter UI, Android-native enforcement UI, shared semantics, mobile navigation, and mobile purchase/Commitment/Circle/Insights surfaces. Browser extensions, desktop blocking, cross-device aggregation, browser Firebase/licensing, and iOS are outside scope.

## Governance

The canonical token and component contract belongs in `design-system.md`. The canonical mobile information architecture belongs in `information-architecture.md`. Current implementation observations belong in the dated audit and must not be presented as already implemented v2 UI.
