-- =============================================================================
-- Migration: 20261026000026_discovered_blida_resources_queue.sql
-- Description: Admin Validation Queue for Telegram & Google Drive Blida Scanner
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.admin_system_settings (
  setting_key text PRIMARY KEY,
  setting_value text NOT NULL,
  description text,
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid REFERENCES auth.users(id) ON DELETE SET NULL
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.admin_system_settings TO authenticated;
ALTER TABLE public.admin_system_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage system settings" ON public.admin_system_settings;
CREATE POLICY "Admins can manage system settings"
ON public.admin_system_settings
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = (select auth.uid()) AND profiles.is_admin = true
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = (select auth.uid()) AND profiles.is_admin = true
  )
);

CREATE TABLE IF NOT EXISTS public.discovered_blida_resources (
  id text PRIMARY KEY,
  title text NOT NULL,
  resource_type text NOT NULL DEFAULT 'pdf_course', -- 'pdf_course', 'qcm_exam', 'gdrive_folder', 'telegram_post'
  source_type text NOT NULL DEFAULT 'telegram', -- 'telegram', 'google_drive'
  source_origin text NOT NULL,
  source_url text NOT NULL,
  gdrive_file_id text,
  suggested_module_id text,
  suggested_course_id text,
  study_year smallint,
  ai_summary text,
  status text NOT NULL DEFAULT 'pending', -- 'pending', 'approved', 'rejected'
  discovered_at timestamptz NOT NULL DEFAULT now(),
  reviewed_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_discovered_blida_status_date
  ON public.discovered_blida_resources(status, discovered_at DESC);

CREATE INDEX IF NOT EXISTS idx_discovered_blida_source_type
  ON public.discovered_blida_resources(source_type);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.discovered_blida_resources TO authenticated;

ALTER TABLE public.discovered_blida_resources ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage discovered blida resources" ON public.discovered_blida_resources;
CREATE POLICY "Admins can manage discovered blida resources"
ON public.discovered_blida_resources
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = (select auth.uid()) AND profiles.is_admin = true
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = (select auth.uid()) AND profiles.is_admin = true
  )
);

-- Seed default watched Telegram channels and Drive folders in admin_system_settings
INSERT INTO public.admin_system_settings (setting_key, setting_value, description)
VALUES (
  'blida_scanner_sources',
  '@medsina_officiel, @residanat_blida, @medecine_blida, https://drive.google.com/drive/folders/1___jg3oAyaBm-REwGb68q_XTN5dKWX2E',
  'Liste des canaux publics Telegram (@username) et dossiers Google Drive surveillés par le scanner Blida'
)
ON CONFLICT (setting_key) DO NOTHING;
