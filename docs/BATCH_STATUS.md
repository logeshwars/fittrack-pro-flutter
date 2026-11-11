# Implementation status

## Batch 1 — App foundation
Committed: Riverpod entry point, GoRouter five-tab shell, theme tokens, smoke test, CI workflow.
Pending: Flutter analysis/tests, native platform generation.

## Batch 2 — Authentication groundwork
Committed: build-time Supabase configuration, guarded email sign-in/out, read-only profile query, identity compatibility audit.
Pending: deployed RLS and Google account identity mapping. No production writes.

## Batch 3 — Workout domain
Committed: workout/set models, read-only history repository, calculation tests.
Pending: device/integration tests and offline writes.

## Batch 4 — Workout browsing
Committed: workout history screen, read-only exercise repository, nullable legacy workout names, tests.
Pending: live Supabase verification and pagination UI.

## Blocking gates
Flutter SDK analysis/test run and Android/iOS scaffolding. Google account migration requires deployed auth/RLS verification.
