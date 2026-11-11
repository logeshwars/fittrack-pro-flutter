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
10. CI remediation.
11. Android smoke build.
12. iOS simulator CI and native bootstrap.
13. Identity compatibility audit.
14. Local workout drafts.
15. Local food drafts.
16. Local cardio, weight and sleep drafts.
17. Guarded offline sync planner.
18. Read-only gamification and disabled external integration gates.
19. Nine-language navigation labels and explicit feature-parity audit.

## Outstanding release gates
See `docs/FEATURE_PARITY.md` for a complete list. The migration is not yet
production-ready; the remaining work exceeds a fixed two-batch estimate.
