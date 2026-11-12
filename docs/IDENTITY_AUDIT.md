# Identity compatibility and RLS audit — release gate

## Verified from React Native source
- Direct Google Sign-In stores the Google subject ID locally and queries
  `profiles.google_user_id` using that ID.
- Email sign-up stores the Supabase Auth UUID as `profiles.google_user_id`
  and `email_user_id`.
- Migration 008 RLS compares `google_user_id = auth.uid()::text`.
- The Google login implementation does not call Supabase
  `signInWithIdToken`, despite the comment in migration 008.
- These are conflicting identity schemes. Source migrations alone cannot
  establish which policies are deployed or whether older Google accounts can
  be read under current RLS.

## Flutter behavior
- Email/password Supabase sign-in is available.
- A read-only profile inspection helper checks for an exact UUID match.
- No email-based automatic account linking, Google OAuth, profile upserts,
  cross-account data reads or production writes are enabled.
- The ID format classifier is only a diagnostic; it is NOT proof of identity.

## Required manual production audit
1. Inspect actual Supabase auth provider settings and deployed RLS policies.
2. Test a disposable existing Google account and email account, read-only.
3. Determine how old Google subject IDs map to Supabase auth identities.
4. Design a server-side migration with audit log, verified identity ownership,
   transactional foreign-key updates and rollback.
5. Check RevenueCat identity mapping and pending offline operations.
6. Do not enable write APIs until the migration is tested and approved.

## Resolution (Batch 21)
Decision: redesign auth so every user has a real Supabase Auth identity.
- Google sign-in uses `signInWithIdToken`; rows are keyed by `auth.uid()::text`.
- Returning React Native Google users are re-keyed by the server-side
  `claim_legacy_google_profile` function (migration 026). Ownership is proven by
  `auth.identities` (Supabase verified the Google token), never by email.
- The claim runs in one transaction, is idempotent, and is audited in
  `identity_migration_audit`. If a profile for the new identity already exists the
  function returns `conflict` and changes nothing.
- RLS for presets, weights, cardio, sleep and photo scans is repaired to
  `google_user_id = auth.uid()::text`.
- Still required: apply the migration, enable the Google provider, and test with
  a disposable legacy account before releasing.
