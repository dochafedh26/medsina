-- Multi-App Support Migration
-- Adds app_id scoping to app_releases and user_fcm_tokens so
-- medsina_residanat, medsina_clinique, medsina_externat, and medsina_all
-- receive isolated OTA updates and targeted push notifications while sharing
-- a single Supabase Auth, Profile, Subscription, and Sync backend.

ALTER TABLE public.app_releases
  ADD COLUMN IF NOT EXISTS app_id TEXT NOT NULL DEFAULT 'medsina_all';

CREATE INDEX IF NOT EXISTS idx_app_releases_app_platform_active
  ON public.app_releases (app_id, platform, is_active, build_number DESC);

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'user_fcm_tokens'
  ) THEN
    ALTER TABLE public.user_fcm_tokens
      ADD COLUMN IF NOT EXISTS app_id TEXT NOT NULL DEFAULT 'medsina_all';
    CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_app_id
      ON public.user_fcm_tokens (user_id, app_id);
  END IF;
END $$;
