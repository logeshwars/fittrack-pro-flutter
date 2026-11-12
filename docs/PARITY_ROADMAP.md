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

## Batch 25 – Gamification and leaderboard
- Achievements screen rebuilt on `GamificationService` (level/XP bar, rank tier, stats, all 40 badges with progress, earned from `user_badges` or provably met by stats).
- New `/leaderboard` screen: publishes this month's stats (best effort), then lists the ranked board with the current user highlighted. Progress tab's Leaderboard segment opens it.
- Badges tied to server-side events (early morning, comeback, food logs, ...) are only shown as earned when present in `user_badges`; automatic badge awarding is not ported because the RN app never awarded them either.
- Known gap: `analyze-food-photo` edge function trusts a client-supplied user id; it should derive the user from the JWT.

## Batch 26 – Dashboard on services
- `dashboardProvider` now reads only through the service layer (workouts, today's food and cardio, latest sleep and weight, profile, gamification) so it works offline from the on-device cache and shows *today's* protein/calories/cardio instead of a recent-logs sum. Every source is isolated: one failure no longer blanks the dashboard.
- Protein and calorie goals come from `goalTargetsProvider` (Goals settings) instead of a hard-coded 2000 kcal.
- Removed the five obsolete direct-Supabase repositories (`workout`, `nutrition`, `cardio`, `progress`, `gamification`); nothing referenced them any more.

## Batch 27 – RevenueCat subscriptions
- Store billing sits behind `PurchaseGateway`; `RevenueCatGateway` (purchases_flutter 8) is only built when a platform key is supplied (`REVENUECAT_ANDROID_KEY` / `REVENUECAT_IOS_KEY`). The customer id is `auth.uid()`.
- Entitlement id is `pro` (`proEntitlementId`); it must match the RevenueCat dashboard. Configure a current offering with monthly and annual packages and a 14-day free-trial intro offer.
- `SubscriptionController` logs in/out with the Supabase user and re-reads the entitlement on every app foreground (`SubscriptionLifecycle` in `app.dart`). `isProProvider` is the single gate; logged data is never gated.
- Paywall (plan picker, trial CTA, savings badge, restore) and Subscription screen (status, renewal date, manage in store via `url_launcher`).
- Needs real-store verification with sandbox testers; client state is a cache of the entitlement, and the server-side webhook (`revenuecat-webhook`) remains the authority for server-enforced limits.

## Batch 28 – Health Connect / HealthKit steps
- `HealthStepsGateway` port with a `health`-package implementation; `stepsProvider` refreshes on start, every 5 minutes and on app resume, and awards +20 XP once per day when the step goal is reached.
- Dashboard step ring shows live steps against the Goals-screen target and offers a Connect action (system permission sheet, or Health Connect install).
- `tool/patch_native.py` now also switches `MainActivity` to `FlutterFragmentActivity` and sets `minSdk = 26` (Health Connect requirements). Idempotent.
- Manual iOS step: enable the HealthKit capability for the Runner target in Xcode (adds the `com.apple.developer.healthkit` entitlement); it cannot be patched reliably from a script. HealthKit never reveals read access, so iOS treats "permission asked" as ready.
- Removed `IntegrationGates` (all integrations were hard-disabled flags that nothing read).

## Batch 29 – Notifications and reminders
- 17 reminders (morning, nutrition, hydration, fitness, sleep) and 8 supplement alerts ported from the RN stores. Each has a toggle and a time picker; reminders repeat daily at a wall-clock time, so DST shifts are handled by the OS match on local time.
- Preferences (`fittrack_reminders_v1`) are the source of truth. `RemindersController` rebuilds the OS pending set from them through one `replaceAll` call on launch and after every change, using stable notification ids (1-17, 101-108) so nothing needs to be stored per notification.
- Everything OS-facing is behind `NotificationGateway` (flutter_local_notifications + timezone); the scheduling rules (`buildSchedule`, `firstFireDate`) are pure and unit tested. Enabling a reminder requests permission first and stays off when denied.
- `tool/patch_native.py` adds the plugin receivers to the manifest (boot re-arm) and enables core-library desugaring. Scheduling is inexact (no `SCHEDULE_EXACT_ALARM`), so delivery can drift a few minutes on Android.
- The old four-switch alerts screen and its `fittrack_alert_*` keys were dropped; they never scheduled anything.

## Batch 30 – Translations (9 languages)
- The RN translation JSON (`en hi ta ar es de ja pt fr` × `common home workout nutrition profile settings progress`) is bundled unchanged under `assets/translations/`, so future string edits can be copied across verbatim.
- `core/l10n/translations.dart` provides `Translations.t('ns:key', args:, count:)` with i18next-style `{{name}}` interpolation, `_one/_other/...` plurals (CLDR rules for the shipped languages incl. Arabic) and English fallback; 61 keys per non-English language are not translated in the RN source and fall back to English. `context.t(...)` reads it from `TranslationsScope`.
- `languageProvider` persists the choice (`fittrack_language`, defaults to the device language) and drives `MaterialApp.locale` with `flutter_localizations`, so Material widgets, date/time pickers and RTL layout (Arabic) switch with it. The Language section of App Settings is now a working picker.
- Converted screens so far: App Settings, Notifications header, Progress, Leaderboard, Profile headers/stat labels and Dashboard greeting/recent-workouts. **Remaining screens still contain inline English** (workout session, nutrition, cardio, sleep, weight, goals, paywall, auth); migrate them by swapping literals for `context.t('ns:key')` using the existing keys.
- Tests check every language parses, placeholders match the English source, fallback, interpolation and plural rules.
