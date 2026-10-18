-- =============================================================================
-- Migration: 20261018000020_license_key_revocation.sql
-- Description:
--   1. Add revocation columns to license_keys (is_revoked, revoked_at, revocation_reason, revoked_by).
--   2. RPC admin_revoke_license_key (marks key revoked & disables redeemed user subscription immediately).
--   3. RPC admin_unrevoke_license_key (restores key if revoked by mistake).
--   4. Update redeem_license_key to reject revoked license keys.
--   5. Update admin_list_license_keys to expose revocation details.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. SCHEMA UPGRADE: LICENSE_KEYS REVOCATION COLUMNS
-- -----------------------------------------------------------------------------
ALTER TABLE public.license_keys 
ADD COLUMN IF NOT EXISTS is_revoked boolean NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS revoked_at timestamptz,
ADD COLUMN IF NOT EXISTS revocation_reason text,
ADD COLUMN IF NOT EXISTS revoked_by uuid REFERENCES auth.users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_license_keys_is_revoked ON public.license_keys(is_revoked);

-- -----------------------------------------------------------------------------
-- 2. RPC: ADMIN REVOKE LICENSE KEY
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_revoke_license_key(
  p_key_code text,
  p_reason text DEFAULT 'Révoquée par l''administration'
)
RETURNS jsonb AS $$
DECLARE
  v_key record;
  v_now timestamptz := now();
  v_reason text;
  v_caller_id uuid;
  v_user_email text;
BEGIN
  -- Verify caller admin status
  v_caller_id := auth.uid();
  IF auth.role() <> 'service_role' THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = v_caller_id AND (is_admin = true OR medical_role = 'Admin')
    ) THEN
      RETURN jsonb_build_object(
        'success', false,
        'message', 'Accès refusé. Privilèges administrateur requis.'
      );
    END IF;
  END IF;

  v_reason := coalesce(nullif(trim(p_reason), ''), 'Révoquée par l''administrateur');

  -- Find the key
  SELECT * INTO v_key
  FROM public.license_keys
  WHERE upper(trim(key_code)) = upper(trim(p_key_code))
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Clé de licence introuvable.'
    );
  END IF;

  IF coalesce(v_key.is_revoked, false) = true THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Cette clé de licence est déjà révoquée.'
    );
  END IF;

  -- 1. Mark license key as revoked
  UPDATE public.license_keys
  SET is_revoked = true,
      revoked_at = v_now,
      revocation_reason = v_reason,
      revoked_by = v_caller_id
  WHERE key_code = v_key.key_code;

  -- 2. If already redeemed, cancel the user's active subscription immediately
  IF v_key.is_redeemed = true AND v_key.redeemed_by IS NOT NULL THEN
    UPDATE public.subscriptions
    SET status = 'revoked',
        expires_at = v_now,
        updated_at = v_now
    WHERE user_id = v_key.redeemed_by;

    SELECT email INTO v_user_email FROM public.profiles WHERE id = v_key.redeemed_by;
  END IF;

  -- 3. Log into admin_audit_logs if the table exists
  BEGIN
    INSERT INTO public.admin_audit_logs (
      admin_id, action, target_type, target_id, details, created_at
    ) VALUES (
      v_caller_id,
      'REVOKE_LICENSE_KEY',
      'license_keys',
      v_key.key_code,
      jsonb_build_object(
        'key_code', v_key.key_code,
        'tier', v_key.tier,
        'was_redeemed', v_key.is_redeemed,
        'redeemed_by', v_key.redeemed_by,
        'reason', v_reason
      ),
      v_now
    );
  EXCEPTION WHEN undefined_table THEN
    -- Table does not exist, ignore audit log
    NULL;
  END;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Clé ' || v_key.key_code || ' révoquée avec succès.',
    'key_code', v_key.key_code,
    'was_redeemed', v_key.is_redeemed,
    'redeemed_by', v_key.redeemed_by,
    'redeemed_user_email', v_user_email,
    'revocation_reason', v_reason,
    'revoked_at', v_now
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.admin_revoke_license_key TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 3. RPC: ADMIN UNREVOKE / RESTORE LICENSE KEY
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_unrevoke_license_key(
  p_key_code text
)
RETURNS jsonb AS $$
DECLARE
  v_key record;
  v_now timestamptz := now();
  v_caller_id uuid;
BEGIN
  -- Verify caller admin status
  v_caller_id := auth.uid();
  IF auth.role() <> 'service_role' THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = v_caller_id AND (is_admin = true OR medical_role = 'Admin')
    ) THEN
      RETURN jsonb_build_object(
        'success', false,
        'message', 'Accès refusé. Privilèges administrateur requis.'
      );
    END IF;
  END IF;

  -- Find the key
  SELECT * INTO v_key
  FROM public.license_keys
  WHERE upper(trim(key_code)) = upper(trim(p_key_code))
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Clé de licence introuvable.'
    );
  END IF;

  IF coalesce(v_key.is_revoked, false) = false THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Cette clé n''est pas révoquée.'
    );
  END IF;

  -- Restore license key
  UPDATE public.license_keys
  SET is_revoked = false,
      revoked_at = null,
      revocation_reason = null,
      revoked_by = null
  WHERE key_code = v_key.key_code;

  -- If it was redeemed, restore the user's subscription
  IF v_key.is_redeemed = true AND v_key.redeemed_by IS NOT NULL THEN
    UPDATE public.subscriptions
    SET status = 'active',
        expires_at = coalesce(v_key.redeemed_at, v_now) + (v_key.duration_days || ' days')::interval,
        updated_at = v_now
    WHERE user_id = v_key.redeemed_by;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Clé ' || v_key.key_code || ' rétablie avec succès.',
    'key_code', v_key.key_code
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.admin_unrevoke_license_key TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 4. UPDATE REDEEM_LICENSE_KEY: REJECT REVOKED KEYS
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.redeem_license_key(input_key text)
RETURNS jsonb AS $$
DECLARE
  v_key record;
  v_duration int;
BEGIN
  SELECT * INTO v_key
  FROM public.license_keys
  WHERE upper(trim(key_code)) = upper(trim(input_key));

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Clé de licence invalide ou inexistante.');
  END IF;

  -- Check if revoked
  IF coalesce(v_key.is_revoked, false) = true THEN
    RETURN jsonb_build_object(
      'success', false, 
      'message', 'Cette clé de licence a été révoquée par l''administration (' || coalesce(v_key.revocation_reason, 'Usage non autorisé') || ').'
    );
  END IF;

  -- Check if already redeemed
  IF coalesce(v_key.is_redeemed, false) = true THEN
    RETURN jsonb_build_object('success', false, 'message', 'Cette clé de licence a déjà été activée.');
  END IF;

  v_duration := coalesce(v_key.duration_days, 365);

  -- Update license key status
  UPDATE public.license_keys
  SET is_redeemed = true,
      redeemed_by = auth.uid(),
      redeemed_at = now()
  WHERE key_code = v_key.key_code;

  -- Upsert user subscription
  INSERT INTO public.subscriptions (user_id, tier, status, starts_at, expires_at)
  VALUES (auth.uid(), v_key.tier, 'active', now(), now() + (v_duration || ' days')::interval)
  ON CONFLICT (user_id) DO UPDATE
  SET tier = v_key.tier,
      status = 'active',
      expires_at = greatest(public.subscriptions.expires_at, now()) + (v_duration || ' days')::interval,
      updated_at = now();

  RETURN jsonb_build_object(
    'success', true,
    'tier', v_key.tier,
    'duration_days', v_duration,
    'message', 'Félicitations ! Votre licence Medsina a été activée avec succès.'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.redeem_license_key TO anon, authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 5. UPDATE ADMIN_LIST_LICENSE_KEYS: INCLUDE REVOCATION DETAILS
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
  days_remaining integer,
  is_revoked boolean,
  revoked_at timestamptz,
  revocation_reason text
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
      when coalesce(l.is_revoked, false) = true then
        true
      when l.is_redeemed is true and l.redeemed_at is not null then
        (coalesce(s.expires_at, l.redeemed_at + (l.duration_days || ' days')::interval) < now())
      else
        false
    end as is_expired,
    case
      when coalesce(l.is_revoked, false) = true then
        0
      when l.is_redeemed is true and l.redeemed_at is not null then
        greatest(0, extract(day from (coalesce(s.expires_at, l.redeemed_at + (l.duration_days || ' days')::interval) - now()))::integer)
      else
        l.duration_days
    end as days_remaining,
    coalesce(l.is_revoked, false) as is_revoked,
    l.revoked_at,
    l.revocation_reason
  FROM public.license_keys l
  LEFT JOIN public.profiles p ON p.id = l.redeemed_by
  LEFT JOIN LATERAL (
    SELECT sub.expires_at 
    FROM public.subscriptions sub 
    WHERE sub.user_id = l.redeemed_by 
    ORDER BY sub.expires_at DESC NULLS LAST 
    LIMIT 1
  ) s ON true
  ORDER BY l.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.admin_list_license_keys TO authenticated, service_role;
