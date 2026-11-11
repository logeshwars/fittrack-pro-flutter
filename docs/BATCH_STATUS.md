# Migration batches

1. Foundation: Riverpod, GoRouter, theme and CI.
2. Authentication: guarded email auth and identity/RLS audit.
3. Workout domain: models, read-only history and metrics.
4. Workout UI: history and exercise catalog.
5. Nutrition: history and macro summaries.
6. Cardio: session history.
7. Progress: weight and sleep history.
8. Dashboard: aggregate read-only metrics and navigation shortcuts.
9. Offline: user-scoped persistent queue prototype, replay disabled.
10. CI remediation: corrected analyzer errors and generated test issue.
11. Verification and Android smoke build.
12. iOS simulator CI and native bootstrap.
13. Identity compatibility audit and tests.
14. Local-only workout draft editor.
15. Local-only food draft editor.
16. Local-only cardio, weight and sleep drafts.
17. Offline sync planner, account isolation and retry quarantine tests.

## Outstanding release gates
- Confirm Android/iOS CI builds pass.
- Implement transactional local database and server idempotency.
- Verify deployed Supabase identity/RLS policies before enabling writes.
- Audit historical Google user ID mapping and offline queue transfer.
