# Parity roadmap (Batches 21+)

Reference: `logeshwars/fittrack-pro` (React Native, read-only).
Decision log:
- **Identity**: every user is a Supabase Auth identity. Google users sign in with
  `signInWithIdToken`; rows are keyed by `auth.uid()::text` in the legacy-named
  `google_user_id` column. Returning RN Google users are re-keyed once by the
  server-side `claim_legacy_google_profile` RPC (migration 026).
- **Local storage**: `sqflite` (no code generation) — transactional outbox plus a
  read-through JSON cache. The SharedPreferences prototype is superseded.
- **Verification**: GitHub Actions was billing-blocked on 2026-11-12, so Batches
  21+ were written without compiler feedback. Run `flutter pub get`,
  `dart format .`, `flutter analyze` and `flutter test` first and fix anything the
  toolchain reports before building on this branch.

## Done in Batch 21
| Area | Files |
| --- | --- |
| Email sign-up/sign-in, Google sign-in, legacy claim, profile bootstrap | `core/auth/auth_repository.dart`, `login_screen.dart`, `supabase/migrations/026_*.sql` |
| Transactional outbox, idempotent replay, retry/dead-letter | `core/data/{local_database,outbox,sync_engine}.dart` |
| Offline-aware gateway (cache + pending-write merge) | `core/data/data_gateway.dart` |
| Services ported from RN (workout, preset, nutrition+favorites, cardio, sleep, weight, profile, gamification+leaderboard) | `features/*/data/*_service.dart`, `core/data/service_providers.dart` |
| Unit tests for merge, retry, failure classification, XP/streak/rank rules | `test/data_layer_test.dart` |

## Screen status (RN route → Flutter)
Legend: UI = screen exists, DATA = reads/writes the real services,
✅ done, 🟡 UI only (still on drafts/read-only), ❌ missing.

| RN route | RN lines | UI | DATA | Next step |
| --- | ---: | :-: | :-: | --- |
| `auth/login`, `auth/forgot-password` | 759 | ✅ | ✅ | Device test Google (needs `GOOGLE_WEB_CLIENT_ID`) |
| `onboarding` | 158 | ✅ | ✅ | Writes goal, weight and derived protein goal to the profile |
| `(tabs)/index` dashboard | 1109 | 🟡 | 🟡 | Rebuild from services; ring/stat widgets |
| `(tabs)/workout` | 844 | 🟡 | ❌ | Presets, splits, history paging |
| `workout/[id]` active session | 2851 | 🟡 | ❌ | Largest screen: exercise picker, set logger, rest timer, PR toast, finish + XP |
| `workout/history/[id]` | 384 | 🟡 | ❌ | `WorkoutService.byId` |
| `workout/split/[id]`, `workout/preset/[id]` | 1095 | 🟡 | ❌ | Port `constants/workoutSplits.ts` (614 lines), `PresetService` |
| `(tabs)/nutrition` | 800 | 🟡 | ❌ | Day slider, meal groups, macro rings |
| `nutrition/log`, `nutrition/scan` | 1403 | 🟡 | ❌ | Food search (Indian DB → OpenFoodFacts → USDA), barcode (`mobile_scanner`) |
| Photo scan modal | 877 | ❌ | ❌ | `image_picker` + compress + edge function |
| `(tabs)/cardio`, `cardio/index`, `cardio/session` | 1593 | 🟡 | ❌ | Live timer + GPS (`geolocator`) |
| `sleep/index`, `sleep/log` | 700 | 🟡 | ❌ | `SleepService` |
| `(tabs)/progress`, `progress/weight` | 1474 | 🟡 | ❌ | Charts (`fl_chart`), `WeightService` |
| `profile/index` | 348 | 🟡 | ❌ | `ProfileService`, leaderboard modal |
| `settings/*` (personal, goals, alerts, theme, app-settings) | 1991 | 🟡 | 🟡 | Personal and protein goal sync to the profile; alerts still need notifications |
| `paywall`, `subscription` | — | 🟡 | ❌ | `purchases_flutter` (RevenueCat) |
| Gamification / leaderboard | 780 | 🟡 | ❌ | Badges (`constants/badges.ts`), leaderboard |
| Health Connect / HealthKit | 335 | ❌ | ❌ | `health` package, permissions |
| Notifications / reminders | 252 | ❌ | ❌ | `flutter_local_notifications` |
| i18n (9 languages × 7 namespaces) | — | 🟡 | — | Port feature strings from `src/translations/*` |
| Custom icons (926 lines) + splash/app icons | — | ❌ | — | SVG paths → `CustomPainter`/`flutter_svg`, native icon + splash generation |

## Remaining batches (suggested order)
22. Wire onboarding, dashboard, profile and settings to the services (onboarding, personal and goals settings done; dashboard and profile read the profile row directly and already work with the new identity).
23. Workout vertical slice: exercise picker, session screen, history, presets, splits.
24. Nutrition: log, search, barcode, favorites, day view.
25. Cardio (timer/GPS), sleep, weight and progress charts.
26. Gamification: XP on completion, badges, leaderboard.
27. RevenueCat paywall and entitlement refresh on resume.
28. Health Connect/HealthKit, notifications, reminders.
29. Photo scan.
30. Full localization, custom icons, splash/app icons, accessibility pass.
31. Release: signing, bundle IDs, privacy declarations, device testing.

## One-time server steps (you must run these)
1. Back up the database.
2. Apply `supabase/migrations/026_claim_legacy_google_identity.sql`.
3. In Supabase Auth, enable the Google provider with your web client ID and add
   the Android/iOS client IDs under "Authorized Client IDs".
4. Test with a disposable legacy Google account and check
   `select * from identity_migration_audit`.


## Batch 23 — workout history detail, presets, splits
- Splits ported from `workoutSplits.ts` (4 splits) into `workout_splits_data.dart` (generated).
- History detail on `WorkoutService.byId` with rename/delete; presets list/detail/editor on `PresetService`; split screen resolves exercises by name, swap sheet, start session, save as preset; exercise library tab.
- Also generated (used by later tasks): `indian_foods_data.dart` (69 foods), `badges_data.dart` (40 badges).

## Batch 24 – Progress analytics
- `progress_screen.dart` rebuilt on `WorkoutService`, `NutritionService.heatmapData`, `SleepService` and `GamificationService.stats`: stats row, weekly volume/protein bar charts (fl_chart), 26-week consistency heat map (workout/protein/calories/sleep), weekly goal completion, body-metrics shortcuts.
- Pure logic in `progress_aggregates.dart` with tests. The Leaderboard tab currently routes to `/achievements`; the dedicated leaderboard arrives with the gamification batch.
