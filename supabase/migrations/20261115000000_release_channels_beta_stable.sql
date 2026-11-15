-- Migration: Beta & Stable Release Channels
-- Description: Adds release channel ('stable' | 'beta') to app_releases and is_beta_tester flag to profiles.

ALTER TABLE public.app_releases
  ADD COLUMN IF NOT EXISTS channel TEXT NOT NULL DEFAULT 'stable'
  CHECK (channel IN ('stable', 'beta'));

CREATE INDEX IF NOT EXISTS idx_app_releases_app_platform_channel_active
  ON public.app_releases (app_id, platform, channel, is_active, build_number DESC);

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_beta_tester BOOLEAN NOT NULL DEFAULT FALSE;
