# Identity compatibility gate

## Current findings from the React Native repository
- `src/services/googleAuth.ts` stores Google identity tokens and checks `profiles.google_user_id` using Google account ID.
- `src/services/emailAuth.ts` uses Supabase Auth UUID as `google_user_id` for email users.
- `src/services/supabase.ts` sets `persistSession: false` and `autoRefreshToken: false`.
- `supabase/migrations/008_rls_policies.sql` compares `google_user_id` to `auth.uid()::text`.

## Safety policy for Flutter migration
1. Flutter email sign-in uses Supabase Auth. Read-only profile access is available for authenticated UUIDs.
2. Do not enable Google sign-in until deployed Supabase Auth, RLS, and historical Google ID mappings are verified.
3. Do not migrate or update existing profile rows automatically.
4. Never bypass RLS with a service-role key on device.
5. Test existing Google and email users in a non-production Supabase environment first.

## Verification required
- Inspect deployed policies, not just migration files.
- Verify actual Google OAuth/Supabase session behavior in the existing app.
- Confirm account linking and identity migration procedure.
- Validate subscriptions and history under each identity provider.
