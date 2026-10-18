-- =============================================================================
-- Migration: 20261018000019_octenium_download_and_license_audit.sql
-- Description: 
--   1. Octenium App Download Counter (Android APK, Windows Setup, Web access).
--   2. Detailed License Keys Audit (Creation Date, Activation Date, User Full Name & Email, Expiry Date & Days Remaining).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. TABLE: APP DOWNLOADS & OCTENIUM TELEMETRY
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.app_downloads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  platform text NOT NULL DEFAULT 'android', -- 'android', 'windows', 'web', 'all'
  source text NOT NULL DEFAULT 'octenium',   -- 'octenium', 'in_app_ota', 'direct_web', 'telegram', 'facebook', 'referral'
  version_name text,                        -- e.g. '1.0.8'
  user_agent text,
  ip_address text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_app_downloads_platform ON public.app_downloads(platform);
CREATE INDEX IF NOT EXISTS idx_app_downloads_created_at ON public.app_downloads(created_at DESC);

ALTER TABLE public.app_downloads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can insert download events" ON public.app_downloads;
CREATE POLICY "Anyone can insert download events"
ON public.app_downloads FOR INSERT
WITH CHECK (true);

DROP POLICY IF EXISTS "Admins can view download stats" ON public.app_downloads;
CREATE POLICY "Admins can view download stats"
ON public.app_downloads FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid() AND (profiles.is_admin = true OR profiles.medical_role = 'Admin')
  ) OR auth.role() = 'service_role'
);

-- Ensure default counter settings exist in admin_system_settings
INSERT INTO public.admin_system_settings (setting_key, setting_value, description)
VALUES 
  ('octenium_total_downloads', '0', 'Nombre total cumulé de téléchargements de Medsina depuis Octenium / MedevSync'),
  ('octenium_apk_downloads', '0', 'Nombre de téléchargements du package APK Android'),
  ('octenium_windows_downloads', '0', 'Nombre de téléchargements de l''installateur PC Windows (.exe)'),
  ('octenium_web_visits', '0', 'Nombre d''accès à la version Web en ligne Octenium'),
  ('octenium_last_download_at', null, 'Date et heure du dernier téléchargement enregistré')
ON CONFLICT (setting_key) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 2. RPC: RECORD OCTENIUM DOWNLOAD
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_octenium_download(
  p_platform text DEFAULT 'android',
  p_source text DEFAULT 'octenium',
  p_version text DEFAULT '1.0.8'
)
RETURNS jsonb AS $$
DECLARE
  v_plat text;
  v_src text;
  v_total int := 0;
  v_apk int := 0;
  v_win int := 0;
  v_web int := 0;
  v_now timestamptz := now();
BEGIN
  v_plat := lower(coalesce(nullif(trim(p_platform), ''), 'android'));
  v_src := lower(coalesce(nullif(trim(p_source), ''), 'octenium'));

  -- 1. Insert download log
  INSERT INTO public.app_downloads (platform, source, version_name, created_at)
  VALUES (v_plat, v_src, p_version, v_now);

  -- 2. Increment counters in admin_system_settings
  UPDATE public.admin_system_settings
  SET setting_value = (coalesce(nullif(setting_value, '')::int, 0) + 1)::text,
      updated_at = v_now
  WHERE setting_key = 'octenium_total_downloads';

  IF v_plat = 'android' THEN
    UPDATE public.admin_system_settings
    SET setting_value = (coalesce(nullif(setting_value, '')::int, 0) + 1)::text,
        updated_at = v_now
    WHERE setting_key = 'octenium_apk_downloads';
  ELSIF v_plat = 'windows' THEN
    UPDATE public.admin_system_settings
    SET setting_value = (coalesce(nullif(setting_value, '')::int, 0) + 1)::text,
        updated_at = v_now
    WHERE setting_key = 'octenium_windows_downloads';
  ELSIF v_plat = 'web' THEN
    UPDATE public.admin_system_settings
    SET setting_value = (coalesce(nullif(setting_value, '')::int, 0) + 1)::text,
        updated_at = v_now
    WHERE setting_key = 'octenium_web_visits';
  END IF;

  UPDATE public.admin_system_settings
  SET setting_value = v_now::text,
      updated_at = v_now
  WHERE setting_key = 'octenium_last_download_at';

  -- Read back current counters
  SELECT coalesce(nullif(setting_value, '')::int, 0) INTO v_total FROM public.admin_system_settings WHERE setting_key = 'octenium_total_downloads';
  SELECT coalesce(nullif(setting_value, '')::int, 0) INTO v_apk FROM public.admin_system_settings WHERE setting_key = 'octenium_apk_downloads';
  SELECT coalesce(nullif(setting_value, '')::int, 0) INTO v_win FROM public.admin_system_settings WHERE setting_key = 'octenium_windows_downloads';
  SELECT coalesce(nullif(setting_value, '')::int, 0) INTO v_web FROM public.admin_system_settings WHERE setting_key = 'octenium_web_visits';

  RETURN jsonb_build_object(
    'success', true,
    'total_downloads', v_total,
    'apk_downloads', v_apk,
    'windows_downloads', v_win,
    'web_visits', v_web,
    'recorded_at', v_now
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.record_octenium_download TO anon, authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 3. RPC: GET OCTENIUM DOWNLOAD STATS
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_octenium_download_stats()
RETURNS jsonb AS $$
DECLARE
  v_total int := 0;
  v_apk int := 0;
  v_win int := 0;
  v_web int := 0;
  v_last text := null;
  v_today int := 0;
  v_recent jsonb := '[]'::jsonb;
BEGIN
  -- Read counters
  SELECT coalesce(nullif(setting_value, '')::int, 0) INTO v_total FROM public.admin_system_settings WHERE setting_key = 'octenium_total_downloads';
  SELECT coalesce(nullif(setting_value, '')::int, 0) INTO v_apk FROM public.admin_system_settings WHERE setting_key = 'octenium_apk_downloads';
  SELECT coalesce(nullif(setting_value, '')::int, 0) INTO v_win FROM public.admin_system_settings WHERE setting_key = 'octenium_windows_downloads';
  SELECT coalesce(nullif(setting_value, '')::int, 0) INTO v_web FROM public.admin_system_settings WHERE setting_key = 'octenium_web_visits';
  SELECT setting_value INTO v_last FROM public.admin_system_settings WHERE setting_key = 'octenium_last_download_at';

  -- Today's count from app_downloads
  SELECT count(*)::int INTO v_today 
  FROM public.app_downloads 
  WHERE created_at >= date_trunc('day', now());

  -- Recent 10 downloads
  SELECT coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb) INTO v_recent
  FROM (
    SELECT platform, source, version_name, created_at
    FROM public.app_downloads
    ORDER BY created_at DESC
    LIMIT 10
  ) r;

  RETURN jsonb_build_object(
    'success', true,
    'total_downloads', v_total,
    'apk_downloads', v_apk,
    'windows_downloads', v_win,
    'web_visits', v_web,
    'last_download_at', v_last,
    'today_downloads', v_today,
    'recent_downloads', v_recent
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_octenium_download_stats TO authenticated, service_role, anon;

-- -----------------------------------------------------------------------------
-- 4. ENHANCED RPC: ADMIN LIST LICENSE KEYS WITH COMPLETE AUDIT TRAIL
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.admin_list_license_keys();
DROP FUNCTION IF EXISTS public.admin_list_license_keys;

CREATE OR REPLACE FUNCTION public.admin_list_license_keys()
RETURNS TABLE (
  key_code text,
  tier text,
  duration_days integer,
  is_redeemed boolean,
  redeemed_by uuid,
  redeemed_at timestamptz,
  created_at timestamptz,
  redeemed_user_name text,
  redeemed_user_email text,
  redeemed_user_role text,
  expires_at timestamptz,
  is_expired boolean,
  days_remaining integer
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    l.key_code,
    l.tier,
    l.duration_days,
    coalesce(l.is_redeemed, false) as is_redeemed,
    l.redeemed_by,
    l.redeemed_at,
    l.created_at,
    p.full_name as redeemed_user_name,
    p.email as redeemed_user_email,
    p.medical_role as redeemed_user_role,
    case
      when l.is_redeemed is true and l.redeemed_at is not null then
        coalesce(s.expires_at, l.redeemed_at + (l.duration_days || ' days')::interval)
      else
        null
    end as expires_at,
    case
      when l.is_redeemed is true and l.redeemed_at is not null then
        (coalesce(s.expires_at, l.redeemed_at + (l.duration_days || ' days')::interval) < now())
      else
        false
    end as is_expired,
    case
      when l.is_redeemed is true and l.redeemed_at is not null then
        greatest(0, extract(day from (coalesce(s.expires_at, l.redeemed_at + (l.duration_days || ' days')::interval) - now()))::integer)
      else
        l.duration_days
    end as days_remaining
  FROM public.license_keys l
  LEFT JOIN public.profiles p ON p.id = l.redeemed_by
  LEFT JOIN public.subscriptions s ON s.user_id = l.redeemed_by
  ORDER BY l.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.admin_list_license_keys TO authenticated, service_role;
