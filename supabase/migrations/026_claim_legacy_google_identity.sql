-- 026_claim_legacy_google_identity.sql
--
-- PURPOSE
--   The React Native app keyed Google users by their Google subject ID
--   (profiles.google_user_id = '1087...'), while RLS (migration 008) compares
--   google_user_id to auth.uid()::text. The Flutter app signs in to Supabase
--   with the Google ID token (signInWithIdToken), so every user - email or
--   Google - gets a real auth.uid(). This function lets a returning Google user
--   claim their historical rows and re-key them to auth.uid().
--
-- SECURITY MODEL
--   * Ownership is proven by auth.identities: Supabase verified the Google ID
--     token, so a Google identity row whose provider_id/sub equals the legacy ID
--     belongs to the caller. Email addresses are never used to link accounts.
--   * SECURITY DEFINER so it can re-key rows that RLS would otherwise hide, but
--     it only ever touches rows for the single legacy ID the caller proved.
--   * Atomic: runs in one transaction; any error rolls everything back.
--   * Idempotent: a second call is a no-op.
--   * Every call is written to identity_migration_audit.
--
-- RUN ORDER
--   Apply this file manually (Supabase SQL editor or `supabase db push`) AFTER
--   taking a database backup, and test with a disposable account first.

CREATE TABLE IF NOT EXISTS public.identity_migration_audit (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_user_id  uuid        NOT NULL,
  legacy_id     text        NOT NULL,
  status        text        NOT NULL,
  rows_moved    jsonb       NOT NULL DEFAULT '{}'::jsonb,
  created_at    timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.identity_migration_audit ENABLE ROW LEVEL SECURITY;
-- No policies: nobody can read or write the audit table through the API.

CREATE OR REPLACE FUNCTION public.claim_legacy_google_profile(p_legacy_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_uid      text := auth.uid()::text;
  v_old      public.profiles%ROWTYPE;
  v_new      public.profiles%ROWTYPE;
  v_table    text;
  v_count    bigint;
  v_moved    jsonb := '{}'::jsonb;
  v_tables   text[] := ARRAY[
    'workouts', 'workout_sets', 'exercises', 'foods', 'nutrition_logs',
    'user_gamification', 'user_badges', 'leaderboard_monthly', 'photo_scans',
    'workout_presets', 'weight_logs', 'favorite_foods', 'cardio_sessions',
    'sleep_logs'
  ];
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
  END IF;

  IF p_legacy_id IS NULL OR btrim(p_legacy_id) = '' OR p_legacy_id = v_uid THEN
    RETURN jsonb_build_object('status', 'noop');
  END IF;

  -- Ownership proof: the caller's verified Google identity carries this subject.
  IF NOT EXISTS (
    SELECT 1
    FROM auth.identities i
    WHERE i.user_id = auth.uid()
      AND i.provider = 'google'
      AND (i.provider_id = p_legacy_id OR i.identity_data ->> 'sub' = p_legacy_id)
  ) THEN
    INSERT INTO public.identity_migration_audit (auth_user_id, legacy_id, status)
    VALUES (auth.uid(), p_legacy_id, 'rejected_not_owner');
    RAISE EXCEPTION 'legacy id is not owned by the caller' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_old FROM public.profiles WHERE google_user_id = p_legacy_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'no_legacy_profile');
  END IF;

  -- A profile for the new identity already exists (for example it was created
  -- before the claim ran). Never merge automatically: report and stop.
  IF EXISTS (SELECT 1 FROM public.profiles WHERE google_user_id = v_uid) THEN
    INSERT INTO public.identity_migration_audit (auth_user_id, legacy_id, status)
    VALUES (auth.uid(), p_legacy_id, 'conflict_existing_profile');
    RETURN jsonb_build_object('status', 'conflict');
  END IF;

  -- profiles.email and email_user_id are UNIQUE: free them on the old row,
  -- create the new row, move children, then delete the old row.
  UPDATE public.profiles
     SET email = NULL, email_user_id = NULL
   WHERE google_user_id = p_legacy_id;

  v_new := v_old;
  v_new.google_user_id := v_uid;
  v_new.auth_provider  := 'google';
  v_new.email_user_id  := NULL;
  v_new.updated_at     := now();
  INSERT INTO public.profiles SELECT (v_new).*;

  FOREACH v_table IN ARRAY v_tables LOOP
    IF to_regclass('public.' || v_table) IS NOT NULL THEN
      EXECUTE format(
        'UPDATE public.%I SET google_user_id = $1 WHERE google_user_id = $2',
        v_table
      ) USING v_uid, p_legacy_id;
      GET DIAGNOSTICS v_count = ROW_COUNT;
      v_moved := v_moved || jsonb_build_object(v_table, v_count);
    END IF;
  END LOOP;

  IF to_regclass('public.user_follows') IS NOT NULL THEN
    UPDATE public.user_follows SET follower_id = v_uid WHERE follower_id = p_legacy_id;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    v_moved := v_moved || jsonb_build_object('user_follows_follower', v_count);
    UPDATE public.user_follows SET following_id = v_uid WHERE following_id = p_legacy_id;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    v_moved := v_moved || jsonb_build_object('user_follows_following', v_count);
  END IF;

  DELETE FROM public.profiles WHERE google_user_id = p_legacy_id;

  INSERT INTO public.identity_migration_audit (auth_user_id, legacy_id, status, rows_moved)
  VALUES (auth.uid(), p_legacy_id, 'migrated', v_moved);

  RETURN jsonb_build_object('status', 'migrated', 'rows_moved', v_moved);
END;
$$;

REVOKE ALL ON FUNCTION public.claim_legacy_google_profile(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.claim_legacy_google_profile(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.claim_legacy_google_profile(text) TO authenticated;

-- Repair RLS so every table the app writes is owned-row only. Idempotent:
-- policies are created only when missing. Older RN policies that used
-- current_setting('app.user_id') (photo_scans) are replaced.
DO $$
DECLARE
  t text;
  tables text[] := ARRAY[
    'workout_presets', 'weight_logs', 'cardio_sessions', 'sleep_logs', 'photo_scans'
  ];
BEGIN
  FOREACH t IN ARRAY tables LOOP
    IF to_regclass('public.' || t) IS NULL THEN CONTINUE; END IF;
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_own', t);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR ALL
         USING (google_user_id = auth.uid()::text)
         WITH CHECK (google_user_id = auth.uid()::text)',
      t || '_own', t
    );
  END LOOP;
END $$;
