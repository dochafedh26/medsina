-- =============================================================================
-- Migration: 20261110000000_inactivity_suspension_and_reactivation.sql
-- Description: Automatic 7-day Inactivity Account Suspension, Instant Auto-Reactivation
--              upon Reconnection, and Admin Dashboard Real-time Monitoring & Audit Logs.
-- =============================================================================

-- 1. ENHANCE PUBLIC.PROFILES WITH INACTIVITY SUSPENSION & REACTIVATION TRACKING
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_inactive_suspended boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS inactive_suspended_at timestamptz,
  ADD COLUMN IF NOT EXISTS last_reactivated_at timestamptz,
  ADD COLUMN IF NOT EXISTS reactivation_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_connection_at timestamptz DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_profiles_is_inactive_suspended
  ON public.profiles(is_inactive_suspended)
  WHERE is_inactive_suspended IS TRUE;

CREATE INDEX IF NOT EXISTS idx_profiles_last_connection_at
  ON public.profiles(last_connection_at);

-- 2. CREATE AUDIT & MONITORING TABLE FOR SUSPENSIONS AND REACTIVATIONS
CREATE TABLE IF NOT EXISTS public.user_suspension_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  email text,
  full_name text,
  medical_role text,
  event_type text NOT NULL, -- 'inactivity_suspended', 'reactivation_requested', 'reactivation_validated', 'admin_override'
  reason text,
  days_inactive integer,
  last_connection_at timestamptz,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_suspension_logs_user_id
  ON public.user_suspension_logs(user_id);

CREATE INDEX IF NOT EXISTS idx_user_suspension_logs_created_at
  ON public.user_suspension_logs(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_suspension_logs_event_type
  ON public.user_suspension_logs(event_type);

-- Enable RLS
ALTER TABLE public.user_suspension_logs ENABLE ROW LEVEL SECURITY;

-- Admins can view all suspension logs
DROP POLICY IF EXISTS "Admins can view all suspension logs" ON public.user_suspension_logs;
CREATE POLICY "Admins can view all suspension logs" ON public.user_suspension_logs
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles admin_p 
      WHERE admin_p.id = (SELECT auth.uid()) AND admin_p.is_admin IS TRUE
    )
  );

-- Users can view their own suspension logs
DROP POLICY IF EXISTS "Users can view their own suspension logs" ON public.user_suspension_logs;
CREATE POLICY "Users can view their own suspension logs" ON public.user_suspension_logs
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

-- System/service role and security definer functions can insert
DROP POLICY IF EXISTS "Service role and definer can insert suspension logs" ON public.user_suspension_logs;
CREATE POLICY "Service role and definer can insert suspension logs" ON public.user_suspension_logs
  FOR INSERT
  TO authenticated
  WITH CHECK (
    (SELECT auth.uid()) = user_id 
    OR EXISTS (
      SELECT 1 FROM public.profiles admin_p 
      WHERE admin_p.id = (SELECT auth.uid()) AND admin_p.is_admin IS TRUE
    )
  );

-- 3. FUNCTION TO CHECK AND SUSPEND INACTIVE USERS (DEFAULT: 7 DAYS)
CREATE OR REPLACE FUNCTION public.check_and_suspend_inactive_users(p_days_threshold integer DEFAULT 7)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_suspended_count integer := 0;
  v_user record;
  v_days_inactive integer;
  v_threshold_interval interval;
  v_results jsonb := '[]'::jsonb;
BEGIN
  v_threshold_interval := (p_days_threshold || ' days')::interval;

  FOR v_user IN
    SELECT 
      p.id,
      p.email,
      p.full_name,
      p.medical_role,
      COALESCE(p.last_connection_at, p.created_at) as effective_last_active
    FROM public.profiles p
    WHERE 
      COALESCE(p.is_admin, false) IS FALSE
      AND p.email NOT ILIKE '%doc.hafedh26%'
      AND COALESCE(p.is_inactive_suspended, false) IS FALSE
      AND COALESCE(p.is_banned, false) IS FALSE
      AND COALESCE(p.last_connection_at, p.created_at) < (now() - v_threshold_interval)
  LOOP
    v_days_inactive := GREATEST(p_days_threshold, EXTRACT(DAY FROM (now() - v_user.effective_last_active))::integer);

    -- Flag user as inactive suspended
    UPDATE public.profiles
    SET 
      is_inactive_suspended = true,
      is_banned = true,
      ban_reason = 'Compte suspendu pour inactivité (' || v_days_inactive || ' jours sans connexion)',
      inactive_suspended_at = now(),
      banned_at = now(),
      updated_at = now()
    WHERE id = v_user.id;

    -- Update subscription status to suspended if active
    UPDATE public.subscriptions
    SET 
      status = 'suspended',
      updated_at = now()
    WHERE user_id = v_user.id AND status = 'active';

    -- Insert log entry
    INSERT INTO public.user_suspension_logs (
      user_id,
      email,
      full_name,
      medical_role,
      event_type,
      reason,
      days_inactive,
      last_connection_at,
      metadata,
      created_at
    ) VALUES (
      v_user.id,
      v_user.email,
      v_user.full_name,
      v_user.medical_role,
      'inactivity_suspended',
      'Suspension automatique pour inactivité de ' || v_days_inactive || ' jours',
      v_days_inactive,
      v_user.effective_last_active,
      jsonb_build_object('threshold_days', p_days_threshold),
      now()
    );

    v_suspended_count := v_suspended_count + 1;
    v_results := v_results || jsonb_build_object(
      'id', v_user.id,
      'email', v_user.email,
      'full_name', v_user.full_name,
      'days_inactive', v_days_inactive
    );
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'suspended_count', v_suspended_count,
    'threshold_days', p_days_threshold,
    'users', v_results,
    'timestamp', now()
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.check_and_suspend_inactive_users(integer) TO authenticated, service_role;

-- 4. FUNCTION TO REQUEST AND AUTO-VALIDATE ACCOUNT REACTIVATION
CREATE OR REPLACE FUNCTION public.request_and_reactivate_account(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_profile public.profiles%ROWTYPE;
  v_caller_id uuid;
  v_is_caller_admin boolean := false;
BEGIN
  v_caller_id := auth.uid();

  -- Verify permissions: caller must be the user themselves or an admin
  IF v_caller_id IS NOT NULL THEN
    SELECT COALESCE(is_admin, false) INTO v_is_caller_admin
    FROM public.profiles
    WHERE id = v_caller_id;

    IF v_caller_id <> p_user_id AND NOT v_is_caller_admin THEN
      RETURN jsonb_build_object(
        'success', false,
        'message', 'Action non autorisée.'
      );
    END IF;
  END IF;

  -- Fetch user profile
  SELECT * INTO v_profile
  FROM public.profiles
  WHERE id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Utilisateur introuvable.'
    );
  END IF;

  -- If user is permanently banned for payment rejection/fraud (>= 3 rejections), prevent auto-reactivation
  IF COALESCE(v_profile.rejected_payments_count, 0) >= 3 
     OR (COALESCE(v_profile.is_banned, false) = true AND COALESCE(v_profile.is_inactive_suspended, false) = false AND COALESCE(v_profile.ban_reason, '') NOT ILIKE '%inactiv%') THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Ce compte a été suspendu par l''administration pour motif de paiement ou de sécurité. Veuillez contacter doc.hafedh26@gmail.com.'
    );
  END IF;

  -- Lift suspension & auto-validate reactivation
  UPDATE public.profiles
  SET 
    is_inactive_suspended = false,
    is_banned = false,
    ban_reason = null,
    banned_at = null,
    inactive_suspended_at = null,
    last_reactivated_at = now(),
    reactivation_count = COALESCE(reactivation_count, 0) + 1,
    last_connection_at = now(),
    updated_at = now()
  WHERE id = p_user_id;

  -- Restore subscription status to active if it was suspended
  UPDATE public.subscriptions
  SET 
    status = 'active',
    updated_at = now()
  WHERE user_id = p_user_id AND status = 'suspended';

  -- Record audit log
  INSERT INTO public.user_suspension_logs (
    user_id,
    email,
    full_name,
    medical_role,
    event_type,
    reason,
    days_inactive,
    last_connection_at,
    metadata,
    created_at
  ) VALUES (
    v_profile.id,
    v_profile.email,
    v_profile.full_name,
    v_profile.medical_role,
    'reactivation_validated',
    'Réactivation automatique validée avec succès lors de la reconnexion du praticien',
    0,
    now(),
    jsonb_build_object(
      'reactivation_number', COALESCE(v_profile.reactivation_count, 0) + 1,
      'reactivated_by', CASE WHEN v_is_caller_admin AND v_caller_id <> p_user_id THEN 'admin' ELSE 'doctor_self' END
    ),
    now()
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Compte réactivé avec succès ! Bon retour sur Medsina, Docteur.',
    'reactivated_at', now(),
    'reactivation_count', COALESCE(v_profile.reactivation_count, 0) + 1
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.request_and_reactivate_account(uuid) TO authenticated, service_role;

-- 5. RPC FOR ADMIN DASHBOARD MONITORING STATS & AUDIT LOGS
CREATE OR REPLACE FUNCTION public.admin_get_suspension_stats_and_logs()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_suspended_inactivity_count integer := 0;
  v_warning_count integer := 0;
  v_total_reactivations integer := 0;
  v_fraud_banned_count integer := 0;
  v_logs jsonb := '[]'::jsonb;
BEGIN
  -- Count currently suspended for inactivity
  SELECT count(*) INTO v_suspended_inactivity_count
  FROM public.profiles
  WHERE is_inactive_suspended IS TRUE
     OR (is_banned IS TRUE AND ban_reason ILIKE '%inactiv%');

  -- Count at risk (inactive 5 to 6 days)
  SELECT count(*) INTO v_warning_count
  FROM public.profiles
  WHERE COALESCE(is_admin, false) IS FALSE
    AND email NOT ILIKE '%doc.hafedh26%'
    AND COALESCE(is_banned, false) IS FALSE
    AND COALESCE(last_connection_at, created_at) < (now() - interval '5 days')
    AND COALESCE(last_connection_at, created_at) >= (now() - interval '7 days');

  -- Count total auto-reactivations recorded
  SELECT COALESCE(SUM(reactivation_count), 0) INTO v_total_reactivations
  FROM public.profiles;

  -- Count permanent fraud bans
  SELECT count(*) INTO v_fraud_banned_count
  FROM public.profiles
  WHERE is_banned IS TRUE
    AND (is_inactive_suspended IS FALSE OR is_inactive_suspended IS NULL)
    AND (ban_reason IS NULL OR ban_reason NOT ILIKE '%inactiv%');

  -- Fetch 50 most recent audit logs
  SELECT COALESCE(jsonb_agg(log_item), '[]'::jsonb) INTO v_logs
  FROM (
    SELECT 
      l.id,
      l.user_id,
      l.email,
      l.full_name,
      l.medical_role,
      l.event_type,
      l.reason,
      l.days_inactive,
      l.last_connection_at,
      l.metadata,
      l.created_at
    FROM public.user_suspension_logs l
    ORDER BY l.created_at DESC
    LIMIT 50
  ) log_item;

  RETURN jsonb_build_object(
    'suspended_inactivity_count', v_suspended_inactivity_count,
    'warning_count', v_warning_count,
    'total_reactivations', v_total_reactivations,
    'fraud_banned_count', v_fraud_banned_count,
    'recent_logs', v_logs
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_get_suspension_stats_and_logs() TO authenticated, service_role;

-- 6. UPDATE ADMIN_LIST_USERS TO INCLUDE INACTIVITY SUSPENSION COLUMNS
DROP FUNCTION IF EXISTS public.admin_list_users();

CREATE OR REPLACE FUNCTION public.admin_list_users()
RETURNS TABLE (
  id uuid,
  email text,
  full_name text,
  medical_role text,
  faculty text,
  tier text,
  status text,
  expires_at timestamptz,
  is_admin boolean,
  is_banned boolean,
  ban_reason text,
  rejected_payments_count integer,
  created_at timestamptz,
  study_year integer,
  bio text,
  phone text,
  wilaya text,
  residency_target_year text,
  avatar_url text,
  updated_at timestamptz,
  is_inactive_suspended boolean,
  inactive_suspended_at timestamptz,
  last_reactivated_at timestamptz,
  reactivation_count integer,
  last_connection_at timestamptz
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.email,
    p.full_name,
    p.medical_role,
    p.faculty,
    coalesce(s.tier, 'free') as tier,
    case 
      when p.is_banned is true then 'suspended'
      when s.status is not null then s.status
      else 'active'
    end as status,
    s.expires_at,
    coalesce(p.is_admin, false) as is_admin,
    coalesce(p.is_banned, false) as is_banned,
    p.ban_reason,
    coalesce(p.rejected_payments_count, 0) as rejected_payments_count,
    p.created_at,
    p.study_year,
    p.bio,
    p.phone,
    p.wilaya,
    p.residency_target_year,
    p.avatar_url,
    p.updated_at,
    coalesce(p.is_inactive_suspended, false) as is_inactive_suspended,
    p.inactive_suspended_at,
    p.last_reactivated_at,
    coalesce(p.reactivation_count, 0) as reactivation_count,
    p.last_connection_at
  FROM public.profiles p
  LEFT JOIN public.subscriptions s ON s.user_id = p.id
  ORDER BY p.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.admin_list_users() TO authenticated, service_role;
