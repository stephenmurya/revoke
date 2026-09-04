# Commitment Verification and Fail-Safe Evidence Architecture

Status: Canonical Revoke 2.0 target architecture. This document describes the required v2 contract; the current repository does not yet implement the full model. See `../engineering/status.md` and `../audits/2026-09-04-revival-audit.md` for implementation reality.

## Authority boundary

The server creates an authoritative Commitment lease before activation. The lease contains at minimum:

- Commitment ID and user ID;
- server-side UTC `startAt` and `endAt`;
- immutable Commitment rule snapshot;
- locked Credit amount, if any;
- proof-policy version;
- grace-policy snapshot;
- unique lease nonce/identity.

The lease is the contract to evaluate. A later client edit, stale schedule, or device wall-clock change cannot redefine it.

Native Android remains responsible for observation and local enforcement. Reuse the existing `RevokeAccessibilityService` live foreground path, `UsageStats`/existing calculators for retrospective measurement, native service-health infrastructure, and boot/recovery infrastructure. Do not introduce a second unrelated foreground-monitoring architecture.

## Evidence outcomes and settlement outcomes

Evidence resolution and financial settlement are separate state machines.

Evidence outcome values:

- `SUCCESS_VERIFIED`: sufficient trustworthy evidence that the Commitment was kept.
- `FAILURE_VERIFIED`: positive trustworthy evidence of a violation.
- `UNVERIFIABLE`: required evidence was unavailable, incomplete, or integrity was compromised; success and failure cannot be established confidently.
- `CANCELLED_PRE_START`: cancelled before the authoritative server start.

Financial settlement values are separate, for example:

- `CREDIT_RELEASE`;
- `CREDIT_RELEASE_GRACE`;
- `CREDIT_FORFEITURE`;
- `CREDIT_RELEASE_UNVERIFIABLE`;
- `CREDIT_RELEASE_CANCELLED`.

Only `FAILURE_VERIFIED` after applicable grace is exhausted may produce `CREDIT_FORFEITURE`. `UNVERIFIABLE` never forfeits Credits and never consumes grace. `CANCELLED_PRE_START` releases any hold according to the explicit cancellation policy.

Positive evidence remains valid if monitoring later disappears. For example, verified prohibited TikTok usage at 14:32 followed by service loss at 14:33 remains `FAILURE_VERIFIED`; service loss cannot erase established evidence. Force-close, uninstall, service death, permission loss, OEM battery management, crash, or unexplained gaps cannot independently create a financial failure. They can make the affected period `UNVERIFIABLE`.

## Native append-only evidence journal

Every Credit-backed Commitment requires a durable append-only native evidence journal. Room/SQLite or an equivalent durable event store is preferred; SharedPreferences is not an adequate financial evidence journal.

Conceptual journal fields:

- Commitment ID;
- monotonic sequence number;
- event type;
- boot-session identity;
- Android monotonic elapsed time from `SystemClock.elapsedRealtime()`;
- observed wall-clock timestamp;
- package/app observation where relevant;
- monitoring/service health;
- required permission health;
- clock/timezone-change events;
- reboot events;
- previous-event hash or equivalent chain information.

Use Android monotonic elapsed time for elapsed-duration evidence. Use server UTC for the authoritative Commitment lease boundaries. Device wall-clock time is an observation and diagnostic signal only; it must never independently decide financial success or failure.

Android Keystore-backed device signing of evidence batches is the preferred integrity hardening. Play Integrity is an additional signal for high-value actions such as activating a Credit-backed Commitment, suspicious restoration/recovery, and final resolution when the proof policy requires it. Play Integrity strengthens the evidence model; it does not replace Accessibility or UsageStats behavioral evidence.

## Monitoring health and sabotage response

Health is recorded independently from behavior. Required signals may include Accessibility binding, Usage Access, overlay capability, service heartbeat, native schedule revision, boot identity, clock integrity, and upload status.

An unverifiable Credit-backed Commitment returns locked Credits. To mitigate deliberate monitoring sabotage without financially punishing uncertainty:

- disable new Credit-backed Commitment creation until required health is restored;
- allow stronger integrity checks or temporary eligibility restriction after repeated unexplained unverifiable outcomes;
- keep ordinary non-financial Revoke functionality available where technically possible.

## Offline provisional settlement

If positive failure evidence is verified while the device is offline, the native/client layer immediately reflects the consequence locally. It updates the local available/locked Credit projections, enters `FAILURE_VERIFIED_LOCAL`, and appends a durable pending-forfeiture reconciliation event. Example: available Credits 30 and locked Credits 20 become available Credits 30 and locked Credits 0, with 20 Credits marked for pending server reconciliation.

This is a local provisional settlement, not the global ledger. When connectivity returns, the pending event is uploaded and reconciled idempotently into the server-authoritative Credit ledger. If app data is wiped or the app is uninstalled/reinstalled before synchronization, the pending event may be lost. This is an explicitly accepted v2 risk. Revoke resists ordinary avoidance without becoming an adversarial anti-fraud system; no continuous network or invasive monitoring is required solely to close this case.

## Offline operation and resolution window

Connectivity and monitoring integrity are different concepts. A user may remain offline while completing a Commitment. Native journaling continues locally and evidence uploads opportunistically when connectivity returns.

The backend evaluates after the authoritative Commitment end plus a server-configurable resolution window. The accepted initial default is 24 hours. The canonical flow is authoritative end -> local result where evidence permits -> up to 24 hours for evidence reconciliation -> final server settlement. During this period, delayed native evidence, offline journal uploads, pending local forfeitures, service-health history, success evidence, and failure evidence may arrive.

Continuous server heartbeats are not proof of compliance. Complete trustworthy local evidence uploaded after a temporary outage may resolve normally. At the end of the 24-hour initial window, sufficient success evidence resolves `SUCCESS_VERIFIED`, sufficient failure evidence resolves `FAILURE_VERIFIED`, and insufficient trustworthy evidence resolves `UNVERIFIABLE`.

For `UNVERIFIABLE`, locked Credits are released, no Credits are forfeited, no grace is consumed, and future Credit-backed eligibility may remain disabled until monitoring integrity is restored.

The resolution-window duration is server-configurable; it is not a permanent product-specification magic number.

## Grace and retry policy

Grace is settlement policy, not an evidence state.

For a short one-off Commitment, the preferred initial recovery retry is:

1. `FAILURE_VERIFIED` occurs.
2. If a retry remains, Credits stay locked and are not immediately forfeited.
3. The user receives a short server-defined opportunity to start a fresh full Commitment.
4. A successful retry releases the original Credits; declining, expiry, or failure after grace exhaustion permits forfeiture.

Long Reduce programs must not restart the entire program for one miss. They use checkpoint grace, such as a configurable number of failed daily checkpoints in a taper. Exact defaults remain open. An `UNVERIFIABLE` checkpoint never consumes grace.

## Required server behavior

Final evidence resolution, grace consumption, Credit movement, and settlement are server-authoritative and idempotent. Native/Flutter submit evidence and health; neither client decides a financial outcome. Every `UNVERIFIABLE` result must retain an auditable reason code and the proof-policy/revision used.
