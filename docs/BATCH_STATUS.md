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
11. Verification and Android smoke build: prior CI passed; add Android debug APK compilation.
12. iOS simulator CI and native bootstrap.
13. Identity compatibility: legacy Google vs Supabase UUID classification, read-only profile audit and tests.

## Verification gates
- Confirm Android and iOS CI builds pass.
- Verify deployed Supabase identity/RLS policies before enabling writes.
- Audit historical Google user ID mapping and offline queue transfer.
