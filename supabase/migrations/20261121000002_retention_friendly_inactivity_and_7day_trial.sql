-- =============================================================================
-- Migration: 20261121000002_retention_friendly_inactivity_and_7day_trial.sql
-- Description:
--   1. Neutralize the 7-day inactivity auto-ban that blocked returning users;
--      restore all non-fraud inactivity-suspended accounts immediately;
--      convert check_and_suspend_inactive_users into a friendly win-back nudge.
--   2. Update handle_new_user() to fix medical_role/study_year columns,
--      refresh welcome QCM copy to 19 000+ QCMs, and cut over post-Nov-30
--      trials from 14 days to the 7-day guided trial.
--   3. Add admin_get_cohort_diagnostic_audit() for the 40-user baseline export.
-- =============================================================================

-- 1. IMMEDIATELY RESTORE NON-FRAUD INACTIVITY-SUSPENDED ACCOUNTS
UPDATE public.profiles
SET
  is_inactive_suspended = false,
  is_banned = false,
  ban_reason = null,
  banned_at = null,
  inactive_suspended_at = null,
  updated_at = now()
WHERE (
    is_inactive_suspended IS TRUE
    OR (is_banned IS TRUE AND COALESCE(ban_reason, '') ILIKE '%inactiv%')
  )
  AND COALESCE(rejected_payments_count, 0) < 3;

UPDATE public.subscriptions s
SET
  status = 'active',
  updated_at = now()
FROM public.profiles p
WHERE s.user_id = p.id
  AND s.status = 'suspended'
  AND COALESCE(p.is_banned, false) IS FALSE;

-- 2. REPLACE 7-DAY AUTO-BAN WITH FRIENDLY WIN-BACK NUDGE
CREATE OR REPLACE FUNCTION public.check_and_suspend_inactive_users(p_days_threshold integer DEFAULT 7)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_nudged_count integer := 0;
  v_user record;
  v_days_inactive integer;
  v_threshold_interval interval;
  v_results jsonb := '[]'::jsonb;
  v_notif_id text;
BEGIN
  v_threshold_interval := (GREATEST(1, p_days_threshold) || ' days')::interval;

  FOR v_user IN
    SELECT
      p.id,
      p.email,
      p.full_name,
      p.medical_role,
      COALESCE(p.last_connection_at, p.created_at) AS effective_last_active
    FROM public.profiles p
    WHERE
      COALESCE(p.is_admin, false) IS FALSE
      AND p.email NOT ILIKE '%doc.hafedh26%'
      AND COALESCE(p.is_banned, false) IS FALSE
      AND COALESCE(p.last_connection_at, p.created_at) < (now() - v_threshold_interval)
      AND NOT EXISTS (
        SELECT 1
        FROM public.user_suspension_logs l
        WHERE l.user_id = p.id
          AND l.event_type = 'inactivity_nudge'
          AND l.created_at > (now() - interval '7 days')
      )
  LOOP
    v_days_inactive := GREATEST(
      p_days_threshold,
      EXTRACT(DAY FROM (now() - v_user.effective_last_active))::integer
    );

    -- Log gentle nudge (NEVER lock or ban the user's account)
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
      'inactivity_nudge',
      'Relance bienveillante après ' || v_days_inactive || ' jours sans connexion (compte conservé actif)',
      v_days_inactive,
      v_user.effective_last_active,
      jsonb_build_object('threshold_days', p_days_threshold, 'auto_ban_disabled', true),
      now()
    );

    -- Push an actionable win-back notification into medical_notifications
    v_notif_id := 'nudge_inactive_' || v_user.id || '_' || to_char(now(), 'YYYYMMDD');
    INSERT INTO public.medical_notifications (
      id,
      user_id,
      title,
      message,
      type,
      target_role,
      target_id,
      is_broadcast,
      metadata,
      created_at
    ) VALUES (
      v_notif_id,
      v_user.id,
      '🎯 5 QCM (3 min) pour reprendre votre rythme',
      'Bon retour Dr ' || COALESCE(NULLIF(v_user.full_name, ''), 'Confrère') || ' ! Votre plan de révision vous attend : 5 questions rapides suffisent pour relancer votre série aujourd''hui.',
      'announcement',
      'user',
      'daily_quick_win',
      false,
      jsonb_build_object(
        'target_user_id', v_user.id,
        'days_inactive', v_days_inactive
      ),
      now()
    )
    ON CONFLICT (id) DO NOTHING;

    v_nudged_count := v_nudged_count + 1;
    v_results := v_results || jsonb_build_object(
      'id', v_user.id,
      'email', v_user.email,
      'full_name', v_user.full_name,
      'days_inactive', v_days_inactive
    );
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'mode', 'winback_nudge_only',
    'suspended_count', 0,
    'nudged_count', v_nudged_count,
    'threshold_days', p_days_threshold,
    'users', v_results,
    'timestamp', now()
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.check_and_suspend_inactive_users(integer) TO authenticated, service_role;

-- 3. UPDATE DEFAULT TRIAL TO 7 DAYS (POST-NOV-30) & FIX HANDLE_NEW_USER COLUMNS/COPY
ALTER TABLE public.subscriptions
  ALTER COLUMN expires_at SET DEFAULT (now() + interval '7 days');

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_promo_start timestamptz := '2026-11-02 00:00:00+00';
  v_promo_end   timestamptz := '2026-11-30 23:59:59+00';
  v_tier        text := 'free';
  v_duration    interval := interval '7 days';
  v_user_name   text;
  v_role        text;
  v_faculty     text;
  v_study_year  integer;
  v_is_promo    boolean := false;
BEGIN
  v_user_name := coalesce(nullif(trim(new.raw_user_meta_data->>'full_name'), ''), split_part(new.email, '@', 1));
  v_role := coalesce(nullif(trim(new.raw_user_meta_data->>'medical_role'), ''), 'Candidat Résidanat');
  v_faculty := coalesce(nullif(trim(new.raw_user_meta_data->>'faculty'), ''), 'Faculté de Médecine de Blida');

  BEGIN
    v_study_year := (new.raw_user_meta_data->>'study_year')::integer;
  EXCEPTION WHEN OTHERS THEN
    v_study_year := null;
  END;

  INSERT INTO public.profiles (id, email, full_name, medical_role, faculty, study_year)
  VALUES (
    new.id,
    new.email,
    v_user_name,
    v_role,
    v_faculty,
    v_study_year
  )
  ON CONFLICT (id) DO UPDATE SET
    email = excluded.email,
    full_name = coalesce(nullif(public.profiles.full_name, ''), excluded.full_name),
    medical_role = coalesce(nullif(public.profiles.medical_role, ''), excluded.medical_role),
    faculty = coalesce(nullif(public.profiles.faculty, ''), excluded.faculty),
    study_year = coalesce(public.profiles.study_year, excluded.study_year);

  -- November 2026 launch window preserves 30-day VIP; Dec 1+ uses 7-day guided trial
  IF now() >= v_promo_start AND now() <= v_promo_end THEN
    v_tier := 'all_access';
    v_duration := interval '30 days';
    v_is_promo := true;
  END IF;

  INSERT INTO public.subscriptions (user_id, tier, status, starts_at, expires_at, updated_at)
  VALUES (
    new.id,
    v_tier,
    'active',
    now(),
    now() + v_duration,
    now()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    tier = CASE WHEN v_is_promo THEN 'all_access' ELSE public.subscriptions.tier END,
    status = 'active',
    expires_at = CASE
      WHEN v_is_promo THEN greatest(public.subscriptions.expires_at, now() + interval '30 days')
      ELSE public.subscriptions.expires_at
    END,
    updated_at = now();

  IF v_is_promo THEN
    INSERT INTO public.medical_notifications (
      id,
      user_id,
      title,
      message,
      type,
      target_role,
      target_id,
      is_broadcast,
      metadata,
      created_at
    )
    VALUES (
      'promo_nov2026_' || new.id || '_' || extract(epoch from now())::bigint,
      new.id,
      '🎁 Bienvenue VIP : 1 Mois All-Access Offert !',
      'Bienvenue sur Medsina Dr ' || v_user_name || ' ! Dans le cadre de l''Offre Spéciale de Lancement (02 au 30 Novembre 2026), votre Pass All-Access VIP est activé gratuitement pour 1 mois complet. Accédez sans aucune restriction aux 47 modules du Résidanat, aux 19 000+ QCMs, aux CAT d''Urgences et à l''Assistant ECG / Vidal DZ !',
      'announcement',
      'user',
      'promo_nov2026',
      false,
      jsonb_build_object(
        'target_user_id', new.id,
        'promo', 'novembre_2026_all_access_1_mois',
        'tier', 'all_access',
        'duration_days', 30,
        'expires_at', (now() + interval '30 days')
      ),
      now()
    )
    ON CONFLICT (id) DO NOTHING;
  ELSE
    INSERT INTO public.medical_notifications (
      id,
      user_id,
      title,
      message,
      type,
      target_role,
      target_id,
      is_broadcast,
      metadata,
      created_at
    )
    VALUES (
      'welcome_user_' || new.id,
      new.id,
      '🎉 Bienvenue sur Medsina, ' || v_user_name || ' !',
      'Votre compte est activé avec votre Pass Découverte guidé (7 jours d''accès + QCM du jour). Explorez les 47 modules officiels, +19 000 QCMs, les fiches synthèses et le mode hors-ligne !',
      'announcement',
      'user',
      'daily_quick_win',
      false,
      jsonb_build_object(
        'type', 'welcome',
        'user_id', new.id,
        'full_name', v_user_name,
        'trial_days', 7
      ),
      now()
    )
    ON CONFLICT (id) DO NOTHING;
  END IF;

  INSERT INTO public.medical_notifications (
    id,
    user_id,
    title,
    message,
    type,
    target_role,
    is_broadcast,
    metadata,
    created_at
  )
  VALUES (
    'admin_new_user_' || new.id,
    null,
    '👤 Nouveau Membre Inscrit : ' || v_user_name,
    v_user_name || ' (' || new.email || ') vient de créer un compte Medsina (' || v_role || ' - ' || v_faculty || ').',
    'announcement',
    'admin',
    false,
    jsonb_build_object(
      'is_admin_only', true,
      'target_role', 'admin',
      'user_id', new.id,
      'email', new.email,
      'full_name', v_user_name,
      'medical_role', v_role,
      'faculty', v_faculty,
      'study_year', v_study_year
    ),
    now()
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN new;
END;
$$;

-- 4. FORENSIC 40-USER COHORT DIAGNOSTIC RPC
CREATE OR REPLACE FUNCTION public.admin_get_cohort_diagnostic_audit()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_is_admin boolean := false;
  v_summary jsonb;
  v_by_role jsonb;
  v_by_faculty jsonb;
  v_by_target_year jsonb;
  v_users jsonb;
BEGIN
  IF auth.role() <> 'service_role' THEN
    SELECT (COALESCE(is_admin, false) = true OR medical_role = 'Admin' OR lower(email) = 'doc.hafedh26@gmail.com')
    INTO v_is_admin
    FROM public.profiles
    WHERE id = auth.uid();

    IF v_is_admin IS NOT TRUE THEN
      RAISE EXCEPTION 'Accès refusé : privilèges administrateur requis.';
    END IF;
  END IF;

  WITH base_users AS (
    SELECT
      p.id,
      p.email,
      p.full_name,
      p.phone,
      coalesce(nullif(trim(p.medical_role), ''), 'Non renseigné') AS medical_role,
      coalesce(nullif(trim(p.faculty), ''), 'Non renseignée') AS faculty,
      p.study_year,
      coalesce(nullif(trim(p.residency_target_year), ''), 'Non renseignée') AS residency_target_year,
      p.created_at,
      coalesce(p.last_connection_at, p.created_at) AS last_connection_at,
      coalesce(p.is_inactive_suspended, false) AS is_inactive_suspended,
      coalesce(s.tier, 'free') AS tier,
      coalesce(s.status, 'active') AS sub_status,
      s.expires_at,
      (s.expires_at IS NOT NULL AND s.expires_at < now()) AS is_trial_expired,
      (coalesce(p.last_connection_at, p.created_at) >= now() - interval '7 days') AS is_active_last_7d,
      (coalesce(p.last_connection_at, p.created_at) >= p.created_at + interval '3 days') AS returned_after_day3,
      (
        EXISTS (SELECT 1 FROM public.user_question_history uqh WHERE uqh.user_id = p.id)
        OR EXISTS (SELECT 1 FROM public.user_cloud_sync ucs WHERE ucs.user_id = p.id)
        OR EXISTS (
          SELECT 1 FROM public.user_trial_quotas utq
          WHERE utq.user_id = p.id AND utq.qcm_sessions_used > 0
        )
      ) AS has_study_activity,
      EXISTS (SELECT 1 FROM public.payments pay WHERE pay.user_id = p.id) AS started_checkout,
      EXISTS (SELECT 1 FROM public.payments pay WHERE pay.user_id = p.id AND pay.status = 'approved') AS has_paid
    FROM public.profiles p
    LEFT JOIN public.subscriptions s ON s.user_id = p.id
    WHERE coalesce(p.is_admin, false) IS FALSE
      AND p.email NOT ILIKE '%doc.hafedh26%'
  )
  SELECT
    jsonb_build_object(
      'total_users', count(*),
      'past_trial_expiry', count(*) FILTER (WHERE is_trial_expired),
      'active_last_7d', count(*) FILTER (WHERE is_active_last_7d),
      'returned_after_day3', count(*) FILTER (WHERE returned_after_day3),
      'with_study_activity', count(*) FILTER (WHERE has_study_activity),
      'checkout_started_users', count(*) FILTER (WHERE started_checkout),
      'paid_approved_users', count(*) FILTER (WHERE has_paid),
      'inactive_over_7d', count(*) FILTER (WHERE NOT is_active_last_7d)
    ),
    (
      SELECT coalesce(jsonb_agg(jsonb_build_object('role', medical_role, 'count', c) ORDER BY c DESC), '[]'::jsonb)
      FROM (SELECT medical_role, count(*) AS c FROM base_users GROUP BY medical_role) r
    ),
    (
      SELECT coalesce(jsonb_agg(jsonb_build_object('faculty', faculty, 'count', c) ORDER BY c DESC), '[]'::jsonb)
      FROM (SELECT faculty, count(*) AS c FROM base_users GROUP BY faculty) f
    ),
    (
      SELECT coalesce(jsonb_agg(jsonb_build_object('target_year', residency_target_year, 'count', c) ORDER BY c DESC), '[]'::jsonb)
      FROM (SELECT residency_target_year, count(*) AS c FROM base_users GROUP BY residency_target_year) y
    ),
    (
      SELECT coalesce(
        jsonb_agg(
          jsonb_build_object(
            'id', id,
            'email', email,
            'full_name', full_name,
            'phone', phone,
            'medical_role', medical_role,
            'faculty', faculty,
            'study_year', study_year,
            'residency_target_year', residency_target_year,
            'tier', tier,
            'sub_status', sub_status,
            'expires_at', expires_at,
            'is_trial_expired', is_trial_expired,
            'returned_after_day3', returned_after_day3,
            'has_study_activity', has_study_activity,
            'started_checkout', started_checkout,
            'has_paid', has_paid,
            'created_at', created_at,
            'last_connection_at', last_connection_at
          )
          ORDER BY created_at DESC
        ),
        '[]'::jsonb
      )
      FROM base_users
    )
  INTO v_summary, v_by_role, v_by_faculty, v_by_target_year, v_users
  FROM base_users;

  RETURN jsonb_build_object(
    'generated_at', now(),
    'summary', v_summary,
    'by_role', v_by_role,
    'by_faculty', v_by_faculty,
    'by_target_year', v_by_target_year,
    'users', v_users
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_get_cohort_diagnostic_audit() TO authenticated, service_role;
