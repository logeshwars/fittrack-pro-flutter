# Initial 20-batch milestone — release readiness

## CI findings (2026-11-11)
- Batch 16 run 42989276614: iOS simulator build passed.
- Batch 16 Ubuntu analyze/test failed on two curly-braces lint violations
  in cardio and health draft screens. Corrected in Batch 20.
- Batches 17–19 CI runs were queued or running at the time of inspection.
- Batch 20 must pass analyzer, tests, Android debug APK and iOS simulator
  build before this milestone can be called technically validated.
- A debug build is not an App Store / Play Store release.

## Critical blockers
1. Deployed Supabase RLS, existing Google identity migration and account
   ownership have not been verified. Production writes remain disabled.
2. SharedPreferences drafts and operation queue are prototypes, not a
   transactional encrypted offline database or replay engine.
3. RevenueCat entitlements and purchase restoration are missing.
4. Health Connect and HealthKit permissions and native integrations are missing.
5. Google OAuth, onboarding, workout presets/splits, camera food scanning,
   leaderboard, notifications and full translations remain incomplete.
6. Release signing, bundle identifiers, app privacy declarations, physical
   device testing, accessibility and store validation are outstanding.

## Decision
Do not merge this draft PR into main or replace the production React Native
app until the above gates have been verified and tests pass. Continue the
migration in additional batches prioritized by identity/RLS safety, full
feature parity, and native release requirements.
