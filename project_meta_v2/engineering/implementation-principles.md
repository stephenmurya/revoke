# Implementation Principles

## 1. Revive, do not rebuild by default

The September 2026 audit found the core architecture salvageable. Rewrite only when a specific correctness, security, or maintainability constraint cannot be solved safely in place.

## 2. Preserve native enforcement assets

Treat the current Accessibility fast path, UsageStats fallback, EnforcementEngine, RevokeConfig persistence, native overlays, temporary unlocks, and boot/alarm/watchdog recovery as valuable infrastructure.

## 3. Add a Commitment domain layer over schedules

Do not force native Android to understand every product concept immediately. A Commitment may materialize existing timeBlock and usageLimit rules while Flutter/backend state owns the higher-level contract. Launch Count remains outside v2.

## 4. Make authority explicit

For every important field define one authority: device-native observation, Flutter/local draft, Firestore client-owned metadata, server-owned contract/settlement, or Google Play-owned purchase. Do not allow independent silent rewrites.

## 5. Financial state is server-owned

Native/Flutter supply evidence and display state. Only the backend finalizes evidence outcomes, grace, Credit holds/releases/forfeitures, Premium entitlement, and purchase reversals. Clients never issue or destroy Credits.

## 6. Unknown is a real state

Do not coerce missing telemetry into zero usage or financial failure. Use UNVERIFIABLE with reason codes. It returns Credits and does not consume grace.

## 7. Use the fail-safe evidence architecture

Credit-backed Commitments require an authoritative server UTC lease, durable native append-only journal, monotonic Android elapsed time, health events, chain/signing integrity, opportunistic offline upload, and a configurable resolution window. Device wall clock never independently decides settlement.

## 8. Native sync must become acknowledged and revisioned

Introduce Commitment/schedule revision, mutation source/time, native applied revision, health acknowledgment, conflict policy, and repair behavior around the current raw JSON replacement.

## 9. Permission state is product state

Accessibility, Usage Access, overlay, exact alarm, and relevant battery/OEM conditions must be observable and explainable, especially before Credit-backed activation.

## 10. Keep production and test/admin surfaces distinct

God Mode, mock Tribunals, score adjustment, and operational bypasses must be build-gated, claim-gated, or moved out of ordinary production navigation.

## 11. Migrate compatibility deliberately

Do not delete legacy vote maps, schedule fields, old parsers, or compatibility paths until data/readers have been inventoried and migrated.

## 12. Documentation is part of implementation

Changes to product semantics update product/. Technical contracts update architecture/. Verified implementation changes update engineering/status.md.

