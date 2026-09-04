# PRD: Revoke v1.3

Version: 1.3

Status: Draft

Last Updated: 26th May, 2026

Primary Platform: Android

Primary Architecture Principle: Event-driven native enforcement, local-first schedules and analytics, and social accountability with AI only as a privacy-preserving fallback.

## 1. Problem Statement

Revoke helps users reduce compulsive app use by combining native Android friction, goal-aware analytics, squad accountability, and optional financial stakes. The current v1.2 foundation enforces blocks and supports squad Tribunals, but v1.3 must move the product from basic blocking into a rehabilitation system that helps users taper usage, understand progress, and handle edge cases without creating centralized abuse paths.

The key product gap is trust. Users must trust that schedules work instantly and offline, that enforcement is fair, that money-backed challenges have a support appeal path, and that no human admin can override a Tribunal outcome for personal benefit. The key technical gap is architecture discipline: Accessibility must remain the primary source of truth for foreground events, with UsageStats polling reserved only for users who refuse Accessibility permission.

## 2. Goals

### Functional Goals

1. Revamp the Home screen from a basic score/block list into a deep analytics dashboard showing screen time, progress against goals, streaks, limit consumption, and taper trajectory.
2. Introduce tapered rehab onboarding that creates personalized reduction schedules from user commitments and historical usage.
3. Add three tiers of native reminders for restricted apps:
   - Soft reminder on app open.
   - Mid-session interstitial reminder, initially targeted around 15 minutes.
   - Limit-reached hard block using `GLOBAL_ACTION_HOME`, initially targeted around 30 minutes or the configured user limit.
4. Replace human Tribunal override behavior with an AI Architect fallback that only runs when squad members do not respond within a configured timeout.
5. Add money-backed challenges where users pledge funds, lose funds on verified failure, receive refunds on success, and can appeal tracking bugs, false positives, or emergencies.
6. Store generated schedules locally first, then sync them to Firebase Firestore in the background.
7. Preserve AccessibilityService as the primary event-driven tracker and UsageStats as a degraded fallback only.

### Quality Goals

1. Enforcement decisions should feel immediate when Accessibility is enabled.
2. Schedule creation and display must work with no network dependency.
3. AI evaluation must never block the core Tribunal UI thread or native enforcement path.
4. Payment flows must be auditable, reversible through support when appropriate, and resilient to duplicate events.
5. LLM payloads must exclude direct PII and include only the minimum anonymized context needed for a Tribunal fallback decision.

## 3. Non-Goals

1. Revoke v1.3 does not implement iOS enforcement parity.
2. Revoke v1.3 does not introduce a human Architect role inside Tribunals.
3. Admin or "God Mode" users cannot override Tribunal votes, grant themselves unlimited time, or mutate Tribunal outcomes outside the defined server workflows.
4. Revoke v1.3 does not replace native enforcement with AI judgment.
5. Revoke v1.3 does not make UsageStats polling equivalent to Accessibility tracking.
6. Revoke v1.3 does not create an in-app banking product, stored-value wallet, or lending product.
7. Revoke v1.3 does not remove the existing squad-governed Tribunal model.

## 4. Assumptions

1. Android remains the only platform where enforcement is production-grade.
2. Users are willing to grant Accessibility permission after a prominent disclosure because Revoke's core value depends on reliable foreground app detection.
3. The team accepts the Play Store policy risk associated with Accessibility usage and will keep the disclosure, consent, and user-benefit framing explicit.
4. Users who refuse Accessibility permission receive a degraded experience backed by UsageStats polling, with lower precision clearly communicated.
5. Historical usage data is available from local native tracking, UsageStats fallback data, or prior Revoke analytics.
6. Firebase remains the system of record for authenticated cloud state, while the device remains the first-write location for generated schedules.
7. OpenRouter is available for AI Architect calls, but latency and outage must be treated as normal failure modes.
8. Stripe or an equivalent payment provider will be used for payment authorization, capture, refund, and dispute handling.
9. Tribunal timeout duration `x` is configurable by remote config or server-side constants.
10. Admin features such as broadcast messaging and aggregate app user counts remain allowed, but Tribunal override powers are removed for all admin accounts, including previously privileged personal accounts.

## 5. User Roles

### User

The person being helped by Revoke. A User creates focus goals, accepts tapered schedules, joins or creates squads, starts Tribunals, enters money-backed challenges, and receives reminders or hard blocks.

### Squad Member

A trusted peer in the User's squad. A Squad Member can attend Tribunal sessions, chat, vote on time requests, and provide accountability. A Squad Member cannot edit the User's schedules, payment commitments, or device enforcement state directly.

### AI Architect

A system actor powered through OpenRouter. The AI Architect evaluates a Tribunal only after the User has initiated a Tribunal and squad members remain unresponsive past timeout `x`. It receives a privacy-stripped context payload and returns a recommendation that the backend resolves into an approved or rejected outcome according to policy.

The AI Architect is not a user-facing admin mode, cannot be manually invoked by admins, and cannot grant unlimited time.

### Admin and Support

Admin users may view operational metrics, broadcast announcements, inspect abuse telemetry, and assist with support workflows. Admin users cannot override Tribunal votes or self-grant time. Support users may process challenge appeals through an auditable workflow.

## 6. Core User Journeys

### 6.1 Tapered Rehab Onboarding

1. User grants required permissions or continues with clearly labeled degraded tracking.
2. Revoke imports or estimates historical usage for selected target apps.
3. User states a commitment, such as target daily minutes, quit date, taper speed, allowed windows, or high-risk periods.
4. Revoke generates a taper plan locally, including daily limits, reminder tiers, and schedule windows.
5. The generated schedule is saved on-device first.
6. The app begins enforcement immediately from local state.
7. A background worker syncs the schedule and plan metadata to Firestore when network is available.
8. Home analytics show the user's current usage against the taper plan.

### 6.2 Tiered Reminder Flow

1. User opens a restricted app.
2. AccessibilityService detects the foreground package.
3. If the app is within the allowed taper budget, Revoke shows a gentle non-blocking reminder overlay with current goal context.
4. If the session reaches the mid-session threshold, Revoke pauses use with an interstitial reminder requiring deliberate acknowledgement.
5. If the session reaches the configured limit, Revoke executes `GLOBAL_ACTION_HOME` and shows the native blocker over Home.
6. Session outcomes are logged locally and later synced for analytics.

### 6.3 AI Tribunal Timeout Fallback

1. User initiates a Tribunal for a temporary unlock.
2. Squad members receive notifications and can join chat or vote.
3. If eligible squad members resolve the vote before timeout `x`, the normal squad verdict path applies.
4. If timeout `x` expires without sufficient response, the server builds an anonymized AI context.
5. The AI Architect evaluates the request asynchronously through OpenRouter.
6. The backend records the AI decision, model metadata, latency, and redacted context version.
7. The User receives a resolution. Approved outcomes create a bounded temporary unlock; rejected outcomes keep enforcement active.
8. If AI evaluation fails or times out, the safe default is rejection unless product policy defines a limited emergency path.

### 6.4 Money-Backed Challenge Appeal Flow

1. User creates or joins a challenge and accepts payment terms.
2. Payment provider authorizes or collects the pledged amount according to the selected payment model.
3. Revoke tracks compliance from local enforcement telemetry and synced server state.
4. If the user succeeds, Revoke triggers refund/release according to provider capabilities.
5. If the user exceeds limits, Revoke marks the challenge failed and captures or retains funds.
6. User may submit an appeal for native Android bugs, OEM battery-kill issues, false positives, device clock anomalies, emergency use, or payment errors.
7. Support reviews telemetry, device state, and user explanation.
8. Support may uphold the failure, reverse the capture, issue a refund, or mark the event as non-punitive.
9. All appeal actions are auditable and idempotent.

## 7. Functional Requirements

### Home Analytics

1. The Home screen shall show daily screen time by target app and category.
2. The Home screen shall show progress against user goals and taper schedules.
3. The Home screen shall show remaining allowed time for active limits.
4. The Home screen shall show at least one trend view comparing current usage to baseline usage.
5. The Home screen shall load from local cached analytics when offline.

### Tapered Rehab Onboarding

1. The onboarding flow shall collect target apps, current usage baseline, goal usage, taper speed, and commitment duration.
2. The schedule generator shall produce an initial taper plan before any cloud write is required.
3. The user shall be able to accept, edit, or regenerate the taper plan before activation.
4. Accepted schedules shall be persisted locally before Firestore sync begins.
5. Firestore sync shall not block enforcement activation.

### Tiered Reminders

1. On restricted app open, the native layer shall evaluate the active schedule using Accessibility events when Accessibility is enabled.
2. On app open within remaining budget, Revoke shall show a soft reminder without snapping Home.
3. At the configured mid-session threshold, Revoke shall show an interstitial that interrupts app use and records acknowledgement or abandonment.
4. At the configured limit threshold, Revoke shall execute `GLOBAL_ACTION_HOME` and show the hard blocker overlay.
5. Reminder thresholds shall be configurable per schedule or taper plan.
6. Reminder events shall be logged locally with timestamp, package, schedule id, tier, and outcome.

### AI Architect

1. The AI Architect shall only be invoked for a User-created Tribunal after squad non-response timeout `x`.
2. The AI Architect shall not be invokable from Admin or God Mode controls.
3. The AI context payload shall exclude name, email, avatar URL, FCM token, payment identifiers, and raw chat participant PII.
4. The AI context payload shall include only anonymized usage history, focus goals, requested app/category, requested duration, defector status, recent compliance summary, and reason text after PII scrubbing.
5. The backend shall persist AI evaluation metadata with model, provider, latency, decision, confidence or rationale summary, and redacted context schema version.
6. AI approval shall create only a bounded temporary unlock.
7. AI rejection shall preserve the active enforcement state.

### Tribunal Governance

1. Human Architect Tribunal override mode shall be removed.
2. Admin users shall not be able to override Tribunal votes, directly approve their own pleas, or grant unlimited time.
3. Squad member votes shall remain server-authoritative.
4. Timeout and AI fallback resolution shall be server-authoritative.

### Money-Backed Challenges

1. Users shall explicitly accept the pledged amount, success condition, failure condition, challenge duration, and appeal terms.
2. Revoke shall create a financial commitment record before challenge activation.
3. Payment webhook events shall be processed idempotently.
4. A failed challenge shall not capture funds until enforcement telemetry is resolved into a server-side failure decision.
5. Users shall be able to submit an appeal after a failed challenge.
6. Support shall be able to review, approve, reject, or refund an appeal through an auditable state transition.
7. Refund/release outcomes shall be recorded with payment provider references.

### Local-First Schedule Storage

1. Generated schedules shall be stored locally before remote writes.
2. The native enforcement layer shall consume local schedule state without waiting for Firestore.
3. Background sync shall retry failed Firestore writes with backoff.
4. Conflict resolution shall prefer the newest user-accepted local mutation unless a server-side safety lock is active.
5. The UI shall show sync status without blocking schedule use.

### Tracking Truth

1. AccessibilityService shall be the primary foreground app event source when permission is granted.
2. UsageStats polling shall only be used when Accessibility permission is unavailable or explicitly refused.
3. Analytics shall label UsageStats-derived data as lower-confidence where precision matters.
4. Native enforcement shall not increase high-frequency polling while Accessibility is healthy except during bounded recovery windows.

## 8. Non-Functional Requirements

### Latency

1. Accessibility-driven app-open detection should reach an enforcement decision within 500 ms at p95 on supported devices.
2. Hard block execution should call `GLOBAL_ACTION_HOME` before rendering the blocker overlay.
3. Home analytics should render cached local data within 750 ms at p95.
4. AI Architect evaluation should complete within 30 seconds at p95 after timeout `x` has elapsed. The UI must remain non-blocking while waiting.

### Offline-First Reliability

1. Schedule generation, activation, and native enforcement must work offline.
2. Analytics should continue accumulating locally during network loss.
3. Firestore sync should resume automatically when network returns.
4. Duplicate sync attempts must not create duplicate active schedules, challenges, payment captures, or Tribunal resolutions.

### Battery Usage

1. Accessibility mode should avoid aggressive foreground polling.
2. UsageStats fallback polling should use adaptive intervals and bounded high-frequency windows.
3. Interstitial timers should be native, lifecycle-aware, and resilient to app backgrounding.
4. WorkManager or equivalent background workers should use backoff and avoid continuous wake locks.

### Security and Abuse Resistance

1. Server-side callables and triggers remain the authority for Tribunal resolution, challenge resolution, payment capture, and appeal outcomes.
2. Admin actions must be logged with actor id, timestamp, target id, action, and reason.
3. Privileged accounts must not bypass payment, Tribunal, or enforcement rules without auditable support-state transitions.

## 9. Authorization Matrix

| Capability | User | Squad Member | AI Architect | Admin | Support | Backend/System |
| --- | --- | --- | --- | --- | --- | --- |
| Create personal schedule | Yes, self only | No | No | No | No | Validates/syncs |
| Generate taper schedule | Yes, self only | No | No | No | No | May assist with model/rules |
| View personal analytics | Yes, self only | No, except shared squad summaries if enabled | No | Aggregate only | Limited for support | Computes/syncs |
| Start Tribunal | Yes, self only | No | No | No | No | Creates server record |
| Join Tribunal chat | Requester yes | Yes, same squad | No | No override path | No, except support audit | Enforces permissions |
| Cast Tribunal vote | No on own request | Yes, eligible same-squad | No | No | No | Tallies/finalizes |
| Resolve via AI fallback | No direct control | No direct control | Returns evaluation only | Cannot invoke manually | No | Invokes after timeout and finalizes |
| Override Tribunal verdict | No | No | No | No | No | No manual override |
| Grant unlimited time | No | No | No | No | No | No |
| Broadcast announcement | No | No | No | Yes | No | Delivers |
| View app user count | No | No | No | Yes aggregate | No | Computes aggregate |
| Create money challenge | Yes, self only | Optional if challenge type allows | No | No | No | Validates |
| Capture pledged funds | No | No | No | No | No direct capture | Yes, through payment workflow |
| Submit appeal | Yes, own challenge | No | No | No | No | Records |
| Resolve appeal | No | No | No | Audit only unless assigned | Yes | Applies outcome idempotently |

## 10. Data Model

The following conceptual additions extend the existing Firebase and local storage model. Exact collection names may change during implementation, but ownership and privacy boundaries should remain stable.

### Local Device Storage

`local_schedule_cache`
- `localScheduleId`
- `serverScheduleId`
- `version`
- `source`: `manual | taper_generator | ai_assisted`
- `status`: `draft | active | pendingSync | synced | conflict | disabled`
- `targetApps`
- `blocks`
- `usageLimits`
- `reminderThresholds`
- `createdAt`
- `updatedAt`
- `lastSyncAttemptAt`

`local_usage_sessions`
- `sessionId`
- `packageName`
- `scheduleId`
- `openedAt`
- `closedAt`
- `trackingSource`: `accessibility | usage_stats`
- `confidence`: `high | degraded`
- `reminderEvents`
- `syncedAt`

### Firestore Additions

`/users/{uid}/taperPlans/{planId}`
- `baselineUsage`
- `goalUsage`
- `taperSpeed`
- `startDate`
- `targetDate`
- `generatedScheduleIds`
- `status`: `draft | active | completed | abandoned`
- `createdLocallyAt`
- `syncedAt`

`/users/{uid}/analyticsDaily/{date}`
- `totalScreenTime`
- `targetAppUsage`
- `goalProgress`
- `limitConsumption`
- `trackingSources`
- `confidenceSummary`

`/challenges/{challengeId}`
- `creatorId`
- `participantIds`
- `targetApps`
- `limits`
- `startAt`
- `endAt`
- `stakeAmount`
- `currency`
- `status`: `draft | payment_pending | active | succeeded | failed | appealed | refunded | captured | cancelled`
- `successCriteria`
- `failureCriteria`
- `appealWindowEndsAt`

`/financialCommitments/{commitmentId}`
- `challengeId`
- `uid`
- `provider`: `stripe`
- `providerCustomerId`
- `providerPaymentIntentId`
- `amount`
- `currency`
- `paymentMode`: `authorization_hold | upfront_charge_refund_on_success`
- `status`: `requires_action | authorized | charged | captured | released | refunded | failed | disputed`
- `idempotencyKey`

`/challengeAppeals/{appealId}`
- `challengeId`
- `uid`
- `reason`: `native_bug | false_positive | emergency | oem_battery_kill | payment_error | other`
- `userStatement`
- `evidenceRefs`
- `status`: `submitted | under_review | approved | rejected | refunded | closed`
- `reviewerId`
- `reviewNotes`
- `resolvedAt`

`/pleas/{pleaId}/aiEvaluations/{evaluationId}`
- `trigger`: `squad_timeout`
- `timeoutSeconds`
- `provider`: `openrouter`
- `model`
- `redactedContextSchemaVersion`
- `decision`: `approve | reject`
- `boundedDurationMinutes`
- `rationaleSummary`
- `latencyMs`
- `errorCode`
- `createdAt`

### AI Context Rules

The AI context may include:
- Anonymous user key or one-way hash.
- Requested app package/category and requested duration.
- Recent target-app usage windows.
- Focus goals and taper plan summary.
- Defector status and recent compliance summary.
- Sanitized user reason text.

The AI context must not include:
- Name.
- Email.
- Avatar.
- FCM token.
- Payment identifiers.
- Raw squad member identities.
- Device identifiers beyond coarse platform/version needed for reliability analysis.

## 11. Integration Requirements

### OpenRouter

1. All AI Architect calls shall route through a backend service, not directly from the client.
2. Requests shall use a fixed schema and redaction pipeline before leaving Revoke infrastructure.
3. Responses shall be validated against an expected structured output contract.
4. Provider errors, malformed responses, and timeout failures shall resolve safely without leaving Tribunals active indefinitely.
5. Model choice shall be configurable without client redeploy.

### Stripe or Payment Provider

1. Payment setup shall support authorization/capture for short challenges where provider authorization windows allow it.
2. Longer challenges shall use an upfront charge with success-based refund or another legally reviewed provider-supported pattern.
3. Webhooks shall be verified, idempotent, and server-authoritative.
4. Capture, refund, and release actions shall be traceable from challenge and appeal records.
5. Revoke shall not store raw card data and shall rely on provider-hosted PCI-compliant flows.

### Firebase

1. Firestore remains the cloud sync layer for schedules, analytics summaries, Tribunals, challenges, and appeals.
2. Cloud Functions remain the server authority for Tribunal resolution, payment workflow decisions, challenge outcome calculation, and appeal resolution.
3. FCM remains the notification channel for Tribunal and challenge events.

## 12. Workflow State Machines

### 12.1 Accessibility Tracking and Enforcement

States:

1. `Monitoring`
   - Native service is active and waiting for foreground app events.
2. `RestrictedAppOpened`
   - Accessibility event identifies a target package under an active schedule.
3. `SoftReminder`
   - Non-blocking overlay shows goal, remaining time, and taper context.
4. `SessionActive`
   - User continues using the app while native timer tracks the session.
5. `MidSessionDue`
   - Session duration reaches configured mid-session threshold.
6. `InterstitialPaused`
   - Interstitial interrupts use and requires acknowledgement or exit.
7. `LimitReached`
   - Session or daily limit reaches the configured hard threshold.
8. `SnapToHome`
   - Native layer executes `GLOBAL_ACTION_HOME`.
9. `HardBlockOverlay`
   - Native blocker overlay is shown over Home.
10. `SessionEnded`
   - App leaves foreground or block terminates the session.
11. `Synced`
   - Local event log is uploaded when network is available.

Transitions:

| From | Event | To | Action |
| --- | --- | --- | --- |
| `Monitoring` | Accessibility foreground event for restricted package | `RestrictedAppOpened` | Evaluate local schedule |
| `Monitoring` | UsageStats detects package and Accessibility unavailable | `RestrictedAppOpened` | Evaluate with degraded confidence |
| `RestrictedAppOpened` | Budget remains | `SoftReminder` | Render soft overlay |
| `RestrictedAppOpened` | Limit already exhausted | `LimitReached` | Skip soft reminder |
| `SoftReminder` | Overlay dismissed or times out | `SessionActive` | Start or continue native session timer |
| `SessionActive` | Mid-session threshold reached | `MidSessionDue` | Log tier transition |
| `MidSessionDue` | App still foreground | `InterstitialPaused` | Show interstitial |
| `InterstitialPaused` | User acknowledges and budget remains | `SessionActive` | Resume timer |
| `InterstitialPaused` | User exits app | `SessionEnded` | Close session |
| `SessionActive` | Limit threshold reached | `LimitReached` | Prepare hard block |
| `LimitReached` | Native hard block requested | `SnapToHome` | Execute `GLOBAL_ACTION_HOME` |
| `SnapToHome` | Home action dispatched | `HardBlockOverlay` | Render blocker overlay |
| `HardBlockOverlay` | Block condition expires or approved unlock applies | `SessionEnded` | Remove overlay |
| `SessionEnded` | Local log written | `Synced` | Enqueue sync |
| `Synced` | Sync complete or pending offline | `Monitoring` | Continue monitoring |

### 12.2 Tribunal and AI Fallback

States:

1. `RequestDraft`
2. `RequestSubmitted`
3. `SquadChatActive`
4. `VotingActive`
5. `ResolvedBySquad`
6. `TimeoutReached`
7. `AIContextBuilt`
8. `AIEvaluationPending`
9. `ResolvedByAI`
10. `RejectedSafeDefault`
11. `TemporaryUnlockGranted`
12. `Closed`

Transitions:

| From | Event | To | Action |
| --- | --- | --- | --- |
| `RequestDraft` | User submits plea | `RequestSubmitted` | Backend creates plea |
| `RequestSubmitted` | Notifications sent | `SquadChatActive` | FCM fanout |
| `SquadChatActive` | Eligible member joins or votes | `VotingActive` | Record participant/vote |
| `VotingActive` | Quorum or completion reached | `ResolvedBySquad` | Server finalizes verdict |
| `SquadChatActive` | Timeout `x` expires without sufficient response | `TimeoutReached` | Lock squad vote path if policy requires |
| `VotingActive` | Timeout `x` expires without sufficient response | `TimeoutReached` | Build fallback eligibility |
| `TimeoutReached` | Fallback eligible | `AIContextBuilt` | Strip PII and build schema |
| `AIContextBuilt` | OpenRouter request sent | `AIEvaluationPending` | Async model call |
| `AIEvaluationPending` | Valid AI decision received | `ResolvedByAI` | Persist AI evaluation |
| `AIEvaluationPending` | Provider error, timeout, invalid response | `RejectedSafeDefault` | Reject or route to limited emergency policy |
| `ResolvedBySquad` | Verdict approved | `TemporaryUnlockGranted` | Create bounded unlock |
| `ResolvedByAI` | Verdict approved | `TemporaryUnlockGranted` | Create bounded unlock |
| `ResolvedBySquad` | Verdict rejected | `Closed` | Keep enforcement |
| `ResolvedByAI` | Verdict rejected | `Closed` | Keep enforcement |
| `RejectedSafeDefault` | Safe rejection recorded | `Closed` | Notify requester |
| `TemporaryUnlockGranted` | Unlock expires | `Closed` | Restore enforcement |

## 13. Compliance and Privacy Surface

### Accessibility and Play Store

1. Accessibility permission must be requested only after a clear disclosure that explains why Revoke needs foreground app detection and blocking actions.
2. The app must not claim Accessibility is optional for full enforcement quality.
3. If the Play Store requires changes, the fallback product path is UsageStats-only with documented reduced reliability.

### LLM Privacy

1. PII stripping is mandatory before any OpenRouter request.
2. Names, emails, avatars, payment identifiers, FCM tokens, and raw squad identities must never be sent to the model.
3. Sanitized reason text must pass through a PII scrubber before inclusion.
4. AI logs should store schema version and redacted context summaries rather than full raw prompts whenever possible.
5. Users should be able to understand that AI may resolve unanswered Tribunals, without exposing private squad data to the model.

### Payment and PCI

1. Revoke must use provider-hosted or provider-tokenized payment flows.
2. Revoke must not store raw card numbers, CVC, or equivalent PCI-sensitive data.
3. Webhook signatures must be verified.
4. Captures and refunds must be idempotent.
5. Appeal outcomes involving money must be auditable.

### Financial Fairness

1. Challenge terms must be explicit before payment.
2. Manual appeal must be available for native Android bugs, false positives, OEM battery-saver failures, and actual emergencies.
3. Support decisions must preserve evidence and reviewer accountability.

## 14. Open Questions

1. What is the default Tribunal timeout `x` before AI fallback: 5 minutes, 15 minutes, or squad-configurable?
2. Which OpenRouter model is the default for AI Architect evaluation, and what is the maximum allowed cost per decision?
3. Should AI Architect decisions be binary only, or can they approve a shorter duration than requested?
4. What exact taper algorithm should v1.3 use: linear reduction, adaptive reduction, category-based reduction, or user-selected modes?
5. How much historical usage is required before onboarding can generate a high-confidence taper plan?
6. What challenge durations are compatible with payment authorization holds versus upfront charge/refund?
7. What legal terms are required before money-backed challenges can launch in production?
8. What evidence is sufficient for a successful appeal?
9. Should challenge failures enter an automatic review queue before capture, or only after user appeal?
10. What analytics can be shared with squad members without violating user expectations?

## 15. Out of Scope

1. Human Tribunal Architect mode.
2. Admin Tribunal overrides.
3. Unlimited personal unlock grants.
4. iOS native enforcement.
5. Device Admin, Shizuku, or uninstall-prevention hard mode.
6. Website blocking.
7. Cryptocurrency, wallets, lending, or peer-to-peer money movement.
8. Public leaderboards for financial challenges.
9. Selling or sharing user usage analytics with third parties.
10. Sending direct PII to any LLM provider.
