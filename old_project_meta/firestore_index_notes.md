# Firestore Index Notes

Last updated: Feb 16, 2026

This document tracks the composite indexes required by current query patterns.
Source of truth for deployment remains `firestore.indexes.json`.

## Pleas

- `squadId + status`
  - Used by squad active tribunal stream.
- `userId + status`
  - Used by user-approved plea stream and resolved-plea filters.
- `status + createdAt`
  - Used by stale plea auto-finalization job.
- `status + resolvedAt`
  - Used by resolved plea cleanup job.
- `markedForDeletion + deletionMarkedAt`
  - Used by soft-delete cleanup job.
- `squadId + userId`
  - Used by member rap-sheet plea stats.
- `squadId + userId + status`
  - Used by aggregate counts grouped by verdict status.

## Notes

- Vote documents live at `/pleas/{pleaId}/votes/{uid}` and are read by document path.
- Score telemetry reads (`/users/{uid}/focusStats/{day}` and `/users/{uid}/scoreEvents`) use direct doc/subcollection reads and do not currently require composite indexes.
