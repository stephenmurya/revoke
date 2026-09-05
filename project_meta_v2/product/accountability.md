# Accountability Circles and Granular Permissions

Status: Phase 5 user-facing Circle and Override Authority surfaces are implemented over retained `squads`/`pleas` infrastructure. The backend Commitment-native domain remains deferred.

## Product direction

An Accountability Circle is optional. Revoke remains useful without joining or creating one. `Squad`, `Plea`, and existing Tribunal names remain internal compatibility terms where renaming would create risk; ordinary v2 surfaces use Circle, Override Request, Request Access, and Override History.

Circle membership is not blanket access. The owner assigns supported permissions, and Commitment sharing is explicit. Circle participation never gates local enforcement.

## Supported permissions

The current server-enforced permission vocabulary is:

| Permission | Current effect |
|---|---|
| `viewCommitmentSummary` | Allows a sanitized shared Commitment summary projection when the owner assigns that Commitment to the member. |
| `viewOverrideHistory` | Allows a member-authorized callable to return sanitized Override History for a shared member. |
| `receiveOverrideRequests` | Allows in-app/push delivery of requests assigned to that member. |
| `participateInOverrideDiscussion` | Allows discussion access for an eligible Override Request. |
| `voteOnOverrideRequests` | Allows voting when the member is in the request's fixed voter snapshot. |
| `receiveAccountabilityNotifications` | Allows accountability notification delivery. |

The supported permission set is sanitized on the server. Membership alone grants none of these capabilities.

Reserved, not currently exposed or delivered, are `viewCommitmentProgress`, `viewUsageSummary`, `viewSlipRecoveryHistory`, `receiveProgressNotifications`, `receiveSlipNotifications`, `viewCreditBackingPresence`, and `viewCreditBackingAmount`.

## Presets

Presets are editable templates, not immutable roles:

### Observer

Default: shared Commitment summary and relevant Override History visibility. No request receipt, discussion, or voting.

### Accountability Partner

Default: all currently supported Circle permissions, including request receipt, discussion, voting, history, summary visibility, and accountability notifications.

### Guardian

Default: all currently supported Circle permissions. Future capabilities are not implied by the name.

### Custom

Explicitly selected supported permissions.

## Membership administration

The owner changes another member's supported permissions through `setCircleMemberPermissions`. Members cannot escalate themselves. A member may leave through `leaveCircle`; an owner with remaining members must transfer ownership first. Existing membership is projected by `syncCircleMemberSummaries`/`ensureCircleMemberSummaries` into sanitized `squads/{circleId}/members/{uid}` documents.

## Data minimization

Circle clients receive sanitized member summaries only: display name, avatar URL, Circle role/preset, supported permissions, and projection timestamp. Peer clients cannot read another user's full `users/{uid}` document, email, FCM token, raw telemetry, unrelated Commitments, or payment data. Server Functions may read private documents to construct a deliberately reduced response; that server access is not peer access.

## Explicit Commitment sharing

`users/{uid}/commitmentPolicies/{commitmentId}` stores `sharedMemberIds` separately from `selectedMemberIds` used for Circle voting. A member must have `viewCommitmentSummary` before the owner can assign the Commitment. `getSharedCommitmentSummaries` returns only active, sanitized summaries for explicitly assigned Commitments. No broad same-Circle schedule read is used.

## Override Policy

Each Commitment can store one explicit authority: `SELF`, `AI`, or `CIRCLE`. The companion policy is keyed by the existing schedule/Commitment ID because the full server Commitment object is not yet implemented. `selectedMemberIds` identifies Circle voters and is validated for current membership and voting permission at request creation. A missing policy defaults to Self in the v2 request path. Legacy ambiguous state is not allowed to silently grant authority.

Authority types do not silently fall back into one another:

- Self uses a local deliberate flow and can work offline while native enforcement is healthy;
- AI uses the existing sanitized OpenRouter path and rejects safely on failure;
- Circle uses only the selected voter snapshot and rejects on its five-minute Tribunal timeout.

## Self access

Request Access requires a reason, approximately 30 seconds of reflection, and a bounded duration of 5, 10, or 15 minutes. Native temporary-unlock storage grants the access locally. A local history event is queued for best-effort server recording; the remote history is not the local ledger.

## Circle resolution

At request creation the backend snapshots eligible voters, excludes the requester, and calculates strict majority as `floor(n / 2) + 1`. Attendance, chat participation, and late joins do not change the authority set. Either majority resolves the request; Circle timeout rejects and never invokes AI. Vote and resolution side effects are server-authoritative and idempotent.

## Durable approval delivery

Server approval writes the request outcome and sends a targeted FCM data message. `AmnestyPushReceiver`, protected by `com.google.android.c2dm.permission.SEND`, validates the bound user, package, bounded expiry, and idempotency key before persisting native temporary access. The Flutter listener remains a compatibility path; Flutter being inactive is no longer the only delivery path.
