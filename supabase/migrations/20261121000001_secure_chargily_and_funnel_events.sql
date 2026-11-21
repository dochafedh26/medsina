-- =============================================================================
-- Migration: 20261121000001_secure_chargily_and_funnel_events.sql
-- Description:
--   1. Move Chargily Pay v2 secret keys strictly out of client-accessible settings
--      and provide a safe public RPC for non-secret payment/support metadata.
--   2. Add Chargily checkout correlation + acquisition attribution on public.payments.
--   3. Create offline-first deduplicated public.funnel_events table + batch RPC.
--   4. Update stale QCM counts and Guide v1.0.102 official prices/support number.
-- =============================================================================

-- 1. PAYMENT TABLE ENHANCEMENTS
ALTER TABLE public.payments
  ADD COLUMN IF NOT EXISTS chargily_checkout_id text,
  ADD COLUMN IF NOT EXISTS acquisition_source text;

CREATE UNIQUE INDEX IF NOT EXISTS idx_payments_chargily_checkout_id
  ON public.payments(chargily_checkout_id)
  WHERE chargily_checkout_id IS NOT NULL;

-- 2. SECURE ADMIN_SYSTEM_SETTINGS & CLEAN PLACEHOLDERS
-- Scrub any hardcoded test secret key from DB settings and configure official WhatsApp
UPDATE public.admin_system_settings
SET setting_value = 'MOVED_TO_SUPABASE_EDGE_SECRETS',
    description = 'Chargily secret key moved strictly to Supabase Edge Function secrets (CHARGILY_SECRET_KEY)',
    updated_at = now()
WHERE setting_key = 'chargily_secret_key'
  AND setting_value LIKE 'test_sk_%';

INSERT INTO public.admin_system_settings (setting_key, setting_value, description, updated_at)
VALUES
  ('support_whatsapp', '+213660675279', 'Support WhatsApp officiel MedevSync / Medsina', now()),
  ('chargily_app_url', 'https://medsina.medevsync.com', 'URL de redirection Chargily Pay v2', now())
ON CONFLICT (setting_key) DO UPDATE SET
  setting_value = CASE
    WHEN public.admin_system_settings.setting_key = 'support_whatsapp'
      AND (public.admin_system_settings.setting_value = '+213770000000' OR public.admin_system_settings.setting_value = '')
    THEN excluded.setting_value
    ELSE public.admin_system_settings.setting_value
  END,
  updated_at = now();

-- Safe public RPC returning ONLY non-secret payment/support coordinates (never *secret* or *token*)
CREATE OR REPLACE FUNCTION public.get_public_payment_info()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_result jsonb := '{}'::jsonb;
  v_rec record;
BEGIN
  FOR v_rec IN
    SELECT setting_key, setting_value
    FROM public.admin_system_settings
    WHERE setting_key IN (
      'baridimob_rip',
      'ccp_account',
      'ccp_holder',
      'support_whatsapp',
      'chargily_app_url',
      'chargily_mode',
      'chargily_public_key'
    )
    AND setting_key NOT ILIKE '%secret%'
    AND setting_key NOT ILIKE '%token%'
  LOOP
    v_result := v_result || jsonb_build_object(v_rec.setting_key, v_rec.setting_value);
  END LOOP;

  IF NOT (v_result ? 'support_whatsapp') THEN
    v_result := v_result || jsonb_build_object('support_whatsapp', '+213660675279');
  END IF;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_public_payment_info() TO authenticated;

-- 3. REFRESH STALE QCM COUNT COPY IN SUBSCRIPTION_PLANS WITHOUT ALTERING CUSTOM ADMIN PRICES
UPDATE public.subscription_plans
SET features = replace(features::text, '6 240+', '19 000+')::jsonb,
    updated_at = now()
WHERE features::text LIKE '%6 240+%';

-- 4. OFFLINE-FIRST DEDUPLICATED FUNNEL EVENTS TABLE
CREATE TABLE IF NOT EXISTS public.funnel_events (
  event_id uuid PRIMARY KEY,
  user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  event_name text NOT NULL,
  properties jsonb NOT NULL DEFAULT '{}'::jsonb,
  device_timestamp timestamptz NOT NULL,
  server_timestamp timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_funnel_events_user_time
  ON public.funnel_events(user_id, device_timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_funnel_events_name_time
  ON public.funnel_events(event_name, device_timestamp DESC);

ALTER TABLE public.funnel_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can insert own funnel events" ON public.funnel_events;
CREATE POLICY "Users can insert own funnel events"
  ON public.funnel_events FOR INSERT
  TO authenticated
  WITH CHECK (user_id IS NULL OR user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Admins can read all funnel events" ON public.funnel_events;
CREATE POLICY "Admins can read all funnel events"
  ON public.funnel_events FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = (SELECT auth.uid())
        AND (p.is_admin IS TRUE OR p.medical_role = 'Admin')
    )
  );

-- Batch deduplicated ingestion RPC for offline sync
CREATE OR REPLACE FUNCTION public.insert_funnel_events_batch(p_events jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid;
  v_elem jsonb;
  v_inserted integer := 0;
  v_rows integer := 0;
  v_event_id uuid;
  v_event_name text;
  v_props jsonb;
  v_device_ts timestamptz;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Authentication required');
  END IF;

  IF p_events IS NULL OR jsonb_typeof(p_events) <> 'array' THEN
    RETURN jsonb_build_object('success', false, 'message', 'p_events must be a JSON array');
  END IF;

  FOR v_elem IN SELECT * FROM jsonb_array_elements(p_events)
  LOOP
    BEGIN
      v_event_id := (v_elem->>'event_id')::uuid;
      v_event_name := nullif(trim(v_elem->>'event_name'), '');
      v_props := COALESCE(v_elem->'properties', '{}'::jsonb);
      v_device_ts := COALESCE((v_elem->>'device_timestamp')::timestamptz, now());

      IF v_event_id IS NOT NULL AND v_event_name IS NOT NULL THEN
        INSERT INTO public.funnel_events (event_id, user_id, event_name, properties, device_timestamp)
        VALUES (v_event_id, v_uid, v_event_name, v_props, v_device_ts)
        ON CONFLICT (event_id) DO NOTHING;

        GET DIAGNOSTICS v_rows = ROW_COUNT;
        v_inserted := v_inserted + v_rows;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      -- Skip malformed single event without breaking entire offline flush batch
      CONTINUE;
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'inserted', v_inserted
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.insert_funnel_events_batch(jsonb) TO authenticated;
