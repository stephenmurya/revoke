# STATUS: Revoke

## Current Phase

PRD

## Last Updated

May 26, 2026

## Phase History

- Brainstorm: Complete
- Discovery: Complete (Architectural boundaries set for offline-sync, AI fallback, and tiered native tracking).
- PRD: Complete
- Prompt Generation: Pending
- Implementation: Pending

## Key Architectural Decisions Made

1. AI acts strictly as an asynchronous fallback in Tribunals, avoiding synchronous UI blocking.
2. Analytics and schedules are local-first, syncing to Firebase via background workers.
3. Enforcement states map to three distinct Accessibility-driven UI interventions: soft reminder, interstitial reminder, and hard block.
4. Financial stakes require an out-of-band appeal mechanism to mitigate OEM-specific tracking bugs, false positives, and emergencies.
5. AccessibilityService remains the primary event-driven tracker; UsageStats polling is only a degraded fallback for users who refuse Accessibility permission.
6. Human Architect/God Mode Tribunal overrides are removed. Admin capabilities remain limited to non-verdict operations such as broadcasts, aggregate user counts, and support workflows.

## Risks

- OpenRouter latency or outage could leave fallback Tribunal users waiting after squad timeout; safe default and timeout handling must be explicit.
- LLM privacy risk exists if reason text or context builders fail to strip PII before OpenRouter calls.
- Stripe chargebacks, refund disputes, or authorization-window limits could complicate long-running money-backed challenges.
- Capturing funds after native tracking bugs could damage trust unless appeal review is clear, fast, and auditable.
- OEM battery savers may kill native timers, foreground services, overlays, or background sync workers, weakening interstitial and limit tracking reliability.
- Play Store review may challenge Accessibility usage despite prominent disclosure and user-benefit framing.
- UsageStats fallback users will receive lower-confidence tracking, which is risky for financial challenges unless challenge eligibility requires Accessibility.

## Next Actions

1. Generate the implementation prompt set for v1.3 from `project_,meta/prd.md`.
2. Define the taper schedule algorithm and default thresholds for soft, mid-session, and hard-block interventions.
3. Specify the AI Architect prompt contract, redaction schema, timeout `x`, and OpenRouter model policy.
4. Decide the payment model for short and long challenges: authorization/capture, upfront charge/refund, or phased rollout.
5. Define the support appeal workflow, required evidence, and refund/capture authority boundaries.
6. Create implementation tasks for local-first analytics, schedule caching, Firestore sync, native reminder state machines, Tribunal AI fallback, and challenge payments.

## Implementation Pass - June 9, 2026

- [x] Whitelist Firebase persistence: whitelisted app changes remain local-first, sync to native enforcement immediately, and are saved under the signed-in user's Firestore app preferences.
- [x] Soft reminder trigger behavior: Accessibility session tracking now keeps a restricted-app session alive through transient foreground changes and only starts a new reminder session after a genuine leave grace window.
- [x] Soft reminder toggle: added a Soft Reminders switch beside the existing frequency setting, persisted locally, synced to native config, and mirrored to Firestore.
- [x] Theme Firebase persistence: theme mode and accent changes still apply locally immediately and now sync to Firestore in the background.

### Observations

- Android Gradle compile fails under the machine default JDK 26 before project code compiles; rerunning with `JAVA_HOME=C:\Program Files\Java\jdk-17` succeeds.
- `flutter test` still fails at the existing widget smoke test because it pumps `RevokeApp` without `Firebase.initializeApp()`; `flutter test test/core` passes.
