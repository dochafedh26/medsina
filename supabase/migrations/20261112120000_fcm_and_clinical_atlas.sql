-- Migration: FCM push tokens & Clinical Image Atlas
-- Created for Medsina v1.0.80+

CREATE TABLE IF NOT EXISTS public.fcm_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  token text NOT NULL,
  platform text NOT NULL DEFAULT 'android',
  topics text[] NOT NULL DEFAULT ARRAY['medsina_all'],
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, token)
);

ALTER TABLE public.fcm_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own fcm tokens" ON public.fcm_tokens;
CREATE POLICY "Users manage own fcm tokens"
  ON public.fcm_tokens
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE TABLE IF NOT EXISTS public.clinical_atlas_cases (
  id text PRIMARY KEY,
  title text NOT NULL,
  specialty text NOT NULL,
  modality text NOT NULL,
  image_url text,
  clinical_context text NOT NULL,
  key_findings text[] NOT NULL DEFAULT '{}',
  diagnosis text NOT NULL,
  differential_diagnosis text[] NOT NULL DEFAULT '{}',
  high_yield_pearl text NOT NULL DEFAULT '',
  tags text[] NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.clinical_atlas_cases ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users read clinical atlas" ON public.clinical_atlas_cases;
CREATE POLICY "Authenticated users read clinical atlas"
  ON public.clinical_atlas_cases
  FOR SELECT
  USING (true);
