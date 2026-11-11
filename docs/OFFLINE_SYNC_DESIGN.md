# Offline sync design — Batch 17

## Current implementation
- SharedPreferences persists a prototype FIFO operation queue.
- Operations have stable IDs, user IDs, timestamps and retry counts.
- `SyncPlanner` is a pure read-only planner: replay is disabled by default.
- It rejects mixed-user batches and signed-out replay, and quarantines
  operations that exceed the retry threshold.
- `SyncStatus` exposes only the current authenticated user's pending count.
- No Supabase mutation adapter or automatic replay is connected.

## Release architecture (not implemented)
1. Replace SharedPreferences with encrypted, transactional SQLite storage.
2. Store a schema version, immutable operation ID, authenticated account ID,
   dependency IDs, attempts, next retry time, and dead-letter status.
3. Write drafts and outbox records in one local transaction.
4. Add a server-side idempotency key enforced by a unique constraint or RPC.
5. Verify deployed RLS and historical Google identity mapping before enabling
   writes; do not infer account ownership from email or a Google subject alone.
6. Replay in dependency order (workout before sets, sets before finish).
7. Use exponential backoff with jitter; retry transient failures only.
8. Require server acknowledgement before deleting an outbox operation.
9. Protect queue storage across logout/account switching; never replay
   another account's records under the active session.
10. Test duplicate delivery, interrupted transactions, revoked sessions,
    schema upgrades, conflict resolution and offline-to-online transitions.

## Known limitations
The current planner does not execute writes or provide a production-ready
SQLite database. The existing local workout, nutrition, cardio, sleep and
weight draft editors are not yet connected to the outbox.
