-- Migration: 20261019000021_admin_facebook_prompts.sql
-- Description: Table pour stocker les prompts IA complets générés par l'agent Facebook Marketing.
-- L'administrateur peut visualiser, inspecter et copier le prompt pour l'exécuter dans Gemini, Claude ou ChatGPT
-- au lieu d'une publication directe automatisée.

CREATE TABLE IF NOT EXISTS public.admin_facebook_prompts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  topic text NOT NULL,
  post_type text NOT NULL DEFAULT 'auto',
  title text NOT NULL,
  summary text NOT NULL,
  full_prompt text NOT NULL,
  suggested_mockup text DEFAULT 'desktop',
  theme text DEFAULT 'blue',
  status text NOT NULL DEFAULT 'pending', -- 'pending', 'copied', 'published', 'archived'
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  metadata jsonb DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_admin_facebook_prompts_created 
  ON public.admin_facebook_prompts (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_admin_facebook_prompts_status 
  ON public.admin_facebook_prompts (status);

-- Activation de RLS
ALTER TABLE public.admin_facebook_prompts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admin read facebook prompts" ON public.admin_facebook_prompts;
CREATE POLICY "Admin read facebook prompts"
  ON public.admin_facebook_prompts FOR SELECT
  USING (
    auth.role() = 'service_role' OR
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid() AND (profiles.is_admin = true OR profiles.medical_role = 'Admin')
    )
  );

DROP POLICY IF EXISTS "Admin manage facebook prompts" ON public.admin_facebook_prompts;
CREATE POLICY "Admin manage facebook prompts"
  ON public.admin_facebook_prompts FOR ALL
  USING (
    auth.role() = 'service_role' OR
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid() AND (profiles.is_admin = true OR profiles.medical_role = 'Admin')
    )
  );

-- Trigger: Notification automatique dans medical_notifications pour alerter l'Admin Dashboard
CREATE OR REPLACE FUNCTION public.notify_admin_on_facebook_prompt()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.medical_notifications (
    id,
    title,
    message,
    type,
    target_id,
    metadata,
    is_broadcast,
    created_at
  ) VALUES (
    'fb_prompt_' || NEW.id::text,
    '📢 Prompt IA Facebook : ' || NEW.title,
    'Nouveau prompt prêt pour Gemini / Claude sur "' || NEW.topic || '". Cliquez pour le copier.',
    'announcement',
    NEW.id::text,
    jsonb_build_object(
      'prompt_id', NEW.id::text,
      'full_prompt', NEW.full_prompt,
      'topic', NEW.topic,
      'post_type', NEW.post_type,
      'suggested_mockup', NEW.suggested_mockup,
      'theme', NEW.theme
    ),
    true,
    now()
  )
  ON CONFLICT (id) DO UPDATE SET
    title = excluded.title,
    message = excluded.message,
    metadata = excluded.metadata;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_notify_admin_on_facebook_prompt ON public.admin_facebook_prompts;
CREATE TRIGGER trg_notify_admin_on_facebook_prompt
  AFTER INSERT ON public.admin_facebook_prompts
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_admin_on_facebook_prompt();

