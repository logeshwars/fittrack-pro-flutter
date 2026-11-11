# FitTrack Pro — Flutter Migration

## Source of truth
- Reference (read-only): https://github.com/logeshwars/fittrack-pro
- Flutter implementation: https://github.com/logeshwars/fittrack-pro-flutter
- Preserve existing Supabase schema and user data.

## Batch 1 — Foundation (in progress)
- Flutter Dart application entry point and Riverpod provider scope
- GoRouter five-tab shell and placeholder screens
- Dark/light design tokens ported from src/constants/theme.ts
- Smoke test and analysis configuration
- Platform folders still need generation with Flutter SDK

## Batch 2 — Identity and persistence
- Audit Google ID vs Supabase auth.uid() and deployed RLS
- Implement secure Supabase session handling; do not write production data until verified
- Persist theme and user preferences
- Establish Drift/SQLite offline schema and queued writes

## Batch 3 — Workout vertical slice
- Exercise catalog, workout start, log set, finish, history
- Match existing IDs and progressive overload logic
- Offline and synchronization tests

## Later batches
Nutrition, cardio, sleep, progress, gamification, RevenueCat, health integrations, localization and release.

## Important constraints
- Never commit production credentials, service-role keys, or private signing material.
- Do not alter the React Native repository during migration.
- React Native AsyncStorage unsynced writes cannot be assumed to transfer to Flutter.
- Historical data remains accessible regardless of subscription status.
- Run flutter analyze and flutter test in a Flutter-equipped environment before marking Batch 1 verified.
