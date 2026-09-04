# Accountability Circles and Granular Permissions

## Product direction

The existing Squad system evolves into optional Accountability Circles. Revoke must work without joining or creating a Circle. Squad/Plea/Tribunal names may remain internally during migration, but the v2 product language is Circle/override.

Membership alone grants no broad access to the user's profile or behavior. Permissions are least-privilege and may be granted as a member default and overridden for an individual Commitment.

## Granular permissions

The permission vocabulary must independently control at least:

### Visibility

- view_commitment_summary
- view_commitment_progress
- view_relevant_usage_summary
- view_override_history
- view_slip_recovery_history
- view_credit_lock_exists
- view_credit_lock_amount

### Notifications

- receive_override_requests
- receive_progress_notifications
- receive_slip_notifications
- receive_commitment_failure_notifications

### Participation

- participate_in_override_discussion
- vote_on_override_requests

Membership does not imply any permission. The owner controls defaults and Commitment-specific grants in v2.

## Presets

Presets expand into the granular permissions and remain editable:

### Observer

Selected Commitment summary/progress visibility; no voting or override requests by default.

### Accountability Partner

Progress and relevant usage summary, override requests, discussion, and voting where the Commitment policy permits.

### Guardian

Broad Commitment-scoped visibility and override governance, including Credit lock visibility where explicitly granted.

Presets are convenience only; the underlying permission list is authoritative.

## Data minimization

Circle members should not automatically receive email, FCM token, raw device telemetry, the complete installed-app list, unrelated Commitments, precise usage outside granted scope, payment credentials, or processor identifiers. A Circle should receive commitment-scoped projections rather than the full Firestore user profile.

## Override governance

An OverrideRequest contains the Commitment ID, requester, bounded requested duration, sanitized reason, policy snapshot, eligible voter snapshot, deadline, chat, AI fallback policy, verdict source, unlock expiry, and idempotency key. Eligibility is snapshotted when the request opens; the current participant-based quorum is a migration limitation, not the long-term authority model.

Possible policies are self only, AI Warden, Circle vote, AI fallback after Circle timeout, or no override during a protected window. Circle members cannot increase Credits, redefine active criteria, decide financial settlement, or alter grace.

Circle votes may decide a permitted temporary override. Financial settlement follows immutable Commitment criteria and verified evidence, not social opinion.

