# External integration parity — Batch 18

## Gamification
- React Native uses `user_gamification` and awards 50 XP per completed workout,
  100 XP per PR, and 10 XP when all sets include RPE.
- Streak milestone bonuses are 200 XP at 7 days, 500 XP at 30 days,
  and 2,000 XP at 90 days.
- Level is `(total_xp ~/ 500) + 1`.
- Flutter now reads the current authenticated user's gamification record.
- XP awards and leaderboard writes remain disabled to avoid duplicate or
  unauthorized rewards during the identity migration.

## RevenueCat
- Must audit existing entitlement identifiers, app user IDs, store product
  identifiers, restore purchases, and sandbox/production environments.
- Do not infer Pro access from local flags or copy production API secrets.
- Subscription purchases and restore flows are not implemented in Flutter.

## Health integrations
- Android Health Connect requires verified runtime permissions, manifest
  declarations, Play Console declarations and user consent.
- iOS HealthKit requires entitlements, Info.plist usage descriptions, and
  user consent. Simulator behavior does not establish real-device support.
- Neither integration is active. Never write to health stores silently.

## Verification
- Confirm deployed Supabase RLS and account identity mapping.
- Verify XP formula against the original app and prevent duplicate awards
  using server-side idempotency.
- Validate RevenueCat entitlements with test accounts before production use.
- Validate health permissions and data handling on physical devices.
