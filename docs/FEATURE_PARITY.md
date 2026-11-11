# React Native to Flutter feature parity — Batch 19

Status values: implemented = user-facing Flutter functionality; partial =
limited or local-only; missing = not migrated.

| Feature | Status | Remaining work |
| --- | --- | --- |
| Five-tab navigation, light/dark theme | Implemented | Visual regression and device accessibility |
| Email login | Partial | Verify deployed auth and account compatibility |
| Google login and onboarding | Missing | Google OAuth identity migration, onboarding |
| Workout history | Partial | Verify read access and full exercise detail |
| Workout logging, presets and splits | Partial | Local drafts only; remote writes, presets and splits missing |
| Nutrition history | Partial | Recent history only, not daily aggregation |
| Food logging | Partial | Manual local drafts only |
| Camera food analysis | Missing | Camera permissions, compression, edge function |
| Cardio history and logging | Partial | Local draft, no live tracking or GPS |
| Sleep and weight history and logging | Partial | Local drafts, no sync |
| Dashboard | Partial | Recent read-only aggregates, not full original dashboard |
| Gamification | Partial | Read-only stats; XP awarding and leaderboard missing |
| Offline operations | Partial | SharedPreferences prototype and guarded planner; no replay |
| RevenueCat subscriptions | Missing | Entitlements, purchases, restore flow |
| Health Connect / HealthKit | Missing | Native integration and permissions |
| Notifications | Missing | Scheduling and permissions |
| Localization | Partial | Nine languages for app chrome; feature text remains English |
| iOS/Android production release | Missing | Native identifiers, signing, privacy review, store validation |

## Critical release blockers
1. Verify deployed Supabase RLS, historical Google identity mapping and ownership.
2. Implement and test safe authenticated writes and server-side idempotency.
3. Replace SharedPreferences prototype with transactional local storage.
4. Complete subscriptions and platform health integrations.
5. Verify both CI platforms, physical-device behavior, and accessibility.
6. Complete missing features and full localization.

**Milestone count is not a production-readiness percentage.**
