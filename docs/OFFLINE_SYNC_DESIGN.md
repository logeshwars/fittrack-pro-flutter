# Offline sync design (prototype, not active)

The original React Native queue handles seven operations: startWorkout, logSet,
finishWorkout, logFood, logCardioSession, logSleep and logWeight.

The Flutter queue currently serializes the same seven operation categories with
stable IDs, per-user scoping and attempt counters. It does not replay operations
or write to Supabase. SharedPreferences is a prototype persistence layer only;
migrate to a transactional Drift/SQLite queue before release.

## Release blockers
1. Resolve Supabase Auth UUID versus historical Google ID and deployed RLS.
2. Guarantee backend idempotency for replayed writes (stable operation IDs).
3. Preserve causal order (start workout -> log sets -> finish workout).
4. Separate permanent authorization failures from transient network failures.
5. Add bounded retries, dead-letter visibility, and crash/restart tests.
6. Plan transfer of any unsynced React Native AsyncStorage queue data.
7. Never replay another user's queued operations after account switching.
