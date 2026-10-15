-- =============================================================================
-- Migration: 20261016000015_ai_daily_quotas_and_topups.sql
-- Description: Daily AI quotas per subscription tier, automatic midnight reset,
--              concurrency pacing support, bonus credit balance, and complete
--              quota recharge payment & admin validation workflow.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. ADD PAYMENT TYPE & BONUS CREDITS COLUMNS TO PAYMENTS
-- -----------------------------------------------------------------------------
ALTER TABLE public.payments
ADD COLUMN IF NOT EXISTS payment_type text NOT NULL DEFAULT 'subscription',
ADD COLUMN IF NOT EXISTS bonus_credits integer NOT NULL DEFAULT 0;

-- -----------------------------------------------------------------------------
-- 2. USER AI QUOTAS TABLE
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_ai_quotas (
  user_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  daily_requests_used integer NOT NULL DEFAULT 0,
  last_request_date date NOT NULL DEFAULT CURRENT_DATE,
  bonus_credits_balance integer NOT NULL DEFAULT 0,
  total_queries_lifetime integer NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.user_ai_quotas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own ai quotas" ON public.user_ai_quotas;
CREATE POLICY "Users can view own ai quotas"
ON public.user_ai_quotas FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own ai quotas" ON public.user_ai_quotas;
CREATE POLICY "Users can update own ai quotas"
ON public.user_ai_quotas FOR ALL
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins can manage all ai quotas" ON public.user_ai_quotas;
CREATE POLICY "Admins can manage all ai quotas"
ON public.user_ai_quotas FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid() AND profiles.is_admin = true
  )
);

-- -----------------------------------------------------------------------------
-- 3. RPC: GET OR INITIALIZE USER AI QUOTAS
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.get_user_ai_quotas(uuid);
CREATE OR REPLACE FUNCTION public.get_user_ai_quotas(p_user_id uuid)
RETURNS jsonb AS $$
DECLARE
  v_rec record;
  v_tier text := 'free';
  v_is_admin boolean := false;
  v_daily_limit integer := 1;
  v_daily_used integer := 0;
BEGIN
  -- 1. Check admin status and subscription tier
  SELECT is_admin, subscription_tier INTO v_is_admin, v_tier
  FROM public.profiles
  WHERE id = p_user_id;

  IF v_is_admin IS TRUE THEN
    v_daily_limit := 999999;
  ELSE
    -- Check active subscription table if available
    SELECT tier INTO v_tier
    FROM public.subscriptions
    WHERE user_id = p_user_id AND status = 'active' AND expires_at > now()
    ORDER BY expires_at DESC
    LIMIT 1;

    IF v_tier IS NULL THEN
      SELECT subscription_tier INTO v_tier FROM public.profiles WHERE id = p_user_id;
    END IF;

    IF v_tier = 'all_access' THEN
      v_daily_limit := 70;
    ELSIF v_tier = 'resident_elite' THEN
      v_daily_limit := 35;
    ELSIF v_tier = 'clinical_pro' THEN
      v_daily_limit := 20;
    ELSE
      v_daily_limit := 1;
    END IF;
  END IF;

  -- 2. Fetch or create user quota record
  SELECT * INTO v_rec FROM public.user_ai_quotas WHERE user_id = p_user_id;

  IF NOT FOUND THEN
    INSERT INTO public.user_ai_quotas (user_id, daily_requests_used, last_request_date, bonus_credits_balance)
    VALUES (p_user_id, 0, CURRENT_DATE, 0)
    RETURNING * INTO v_rec;
  ELSIF v_rec.last_request_date < CURRENT_DATE THEN
    -- Automatic midnight reset
    UPDATE public.user_ai_quotas
    SET daily_requests_used = 0,
        last_request_date = CURRENT_DATE,
        updated_at = now()
    WHERE user_id = p_user_id
    RETURNING * INTO v_rec;
  END IF;

  v_daily_used := v_rec.daily_requests_used;

  RETURN jsonb_build_object(
    'user_id', p_user_id,
    'tier', coalesce(v_tier, 'free'),
    'is_admin', v_is_admin,
    'daily_limit', v_daily_limit,
    'daily_used', v_daily_used,
    'daily_remaining', GREATEST(0, v_daily_limit - v_daily_used),
    'bonus_credits_balance', v_rec.bonus_credits_balance,
    'total_queries_lifetime', v_rec.total_queries_lifetime,
    'last_request_date', v_rec.last_request_date
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- -----------------------------------------------------------------------------
-- 4. RPC: CONSUME AI QUERY (WITH DAILY + BONUS PRIORITIZATION)
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.consume_user_ai_query(uuid);
CREATE OR REPLACE FUNCTION public.consume_user_ai_query(p_user_id uuid)
RETURNS jsonb AS $$
DECLARE
  v_rec record;
  v_is_banned boolean := false;
  v_is_admin boolean := false;
  v_tier text := 'free';
  v_daily_limit integer := 1;
BEGIN
  -- 1. Check banned and admin status
  SELECT is_banned, is_admin, subscription_tier INTO v_is_banned, v_is_admin, v_tier
  FROM public.profiles
  WHERE id = p_user_id;

  IF v_is_banned IS TRUE THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'reason', 'user_banned',
      'error', 'Votre compte est suspendu. Veuillez contacter le support.'
    );
  END IF;

  -- Admin has zero limits
  IF v_is_admin IS TRUE THEN
    RETURN jsonb_build_object(
      'allowed', true,
      'consumed_from', 'admin',
      'daily_remaining', 999999,
      'bonus_remaining', 999999
    );
  END IF;

  -- 2. Determine daily quota limit from tier
  SELECT tier INTO v_tier
  FROM public.subscriptions
  WHERE user_id = p_user_id AND status = 'active' AND expires_at > now()
  ORDER BY expires_at DESC
  LIMIT 1;

  IF v_tier IS NULL THEN
    SELECT subscription_tier INTO v_tier FROM public.profiles WHERE id = p_user_id;
  END IF;

  IF v_tier = 'all_access' THEN
    v_daily_limit := 70;
  ELSIF v_tier = 'resident_elite' THEN
    v_daily_limit := 35;
  ELSIF v_tier = 'clinical_pro' THEN
    v_daily_limit := 20;
  ELSE
    v_daily_limit := 1;
  END IF;

  -- 3. Fetch or insert record
  SELECT * INTO v_rec FROM public.user_ai_quotas WHERE user_id = p_user_id FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO public.user_ai_quotas (user_id, daily_requests_used, last_request_date, bonus_credits_balance, total_queries_lifetime)
    VALUES (p_user_id, 0, CURRENT_DATE, 0, 0)
    RETURNING * INTO v_rec;
  ELSIF v_rec.last_request_date < CURRENT_DATE THEN
    -- Midnight reset
    v_rec.daily_requests_used := 0;
    v_rec.last_request_date := CURRENT_DATE;
  END IF;

  -- 4. Check daily quota first
  IF v_rec.daily_requests_used < v_daily_limit THEN
    UPDATE public.user_ai_quotas
    SET daily_requests_used = v_rec.daily_requests_used + 1,
        total_queries_lifetime = v_rec.total_queries_lifetime + 1,
        last_request_date = v_rec.last_request_date,
        updated_at = now()
    WHERE user_id = p_user_id;

    RETURN jsonb_build_object(
      'allowed', true,
      'consumed_from', 'daily',
      'daily_used', v_rec.daily_requests_used + 1,
      'daily_limit', v_daily_limit,
      'daily_remaining', GREATEST(0, v_daily_limit - (v_rec.daily_requests_used + 1)),
      'bonus_remaining', v_rec.bonus_credits_balance
    );
  END IF;

  -- 5. Daily quota is exhausted: check bonus credits balance
  IF v_rec.bonus_credits_balance > 0 THEN
    UPDATE public.user_ai_quotas
    SET bonus_credits_balance = v_rec.bonus_credits_balance - 1,
        total_queries_lifetime = v_rec.total_queries_lifetime + 1,
        last_request_date = v_rec.last_request_date,
        updated_at = now()
    WHERE user_id = p_user_id;

    RETURN jsonb_build_object(
      'allowed', true,
      'consumed_from', 'bonus',
      'daily_used', v_rec.daily_requests_used,
      'daily_limit', v_daily_limit,
      'daily_remaining', 0,
      'bonus_remaining', v_rec.bonus_credits_balance - 1
    );
  END IF;

  -- 6. Both daily and bonus quotas exhausted
  UPDATE public.user_ai_quotas
  SET last_request_date = v_rec.last_request_date,
      updated_at = now()
  WHERE user_id = p_user_id;

  RETURN jsonb_build_object(
    'allowed', false,
    'reason', 'daily_quota_exhausted',
    'daily_used', v_rec.daily_requests_used,
    'daily_limit', v_daily_limit,
    'daily_remaining', 0,
    'bonus_remaining', 0,
    'message', 'Votre quota quotidien de ' || v_daily_limit::text || ' requêtes est atteint. Revenez demain à minuit ou rechargez un pack de requêtes bonus.'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- -----------------------------------------------------------------------------
-- 5. RPC: SUBMIT PAYMENT WITH ADMIN ALERT (SUPPORTING SUBSCRIPTIONS & QUOTA BOOSTS)
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.submit_payment_with_admin_alert(uuid, text, text, text, integer, numeric, text, text, text, text, text, integer);
DROP FUNCTION IF EXISTS public.submit_payment_with_admin_alert(uuid, text, text, text, integer, numeric, text, text, text, text);
DROP FUNCTION IF EXISTS public.submit_payment_with_admin_alert;

CREATE OR REPLACE FUNCTION public.submit_payment_with_admin_alert(
  p_user_id uuid,
  p_user_email text,
  p_user_name text,
  p_tier text,
  p_duration_days integer,
  p_amount numeric,
  p_payment_method text,
  p_receipt_reference text,
  p_receipt_url text DEFAULT NULL,
  p_receipt_file_name text DEFAULT NULL,
  p_payment_type text DEFAULT 'subscription',
  p_bonus_credits integer DEFAULT 0
)
RETURNS jsonb AS $$
DECLARE
  v_payment_id uuid;
  v_is_banned boolean := false;
  v_notif_title text;
  v_notif_message text;
BEGIN
  -- Verify if user is currently banned
  SELECT is_banned INTO v_is_banned
  FROM public.profiles
  WHERE id = p_user_id;

  IF v_is_banned IS TRUE THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Votre compte est suspendu suite à des rejets répétés. Veuillez contacter le support administratif.'
    );
  END IF;

  -- 1. Insert payment record
  INSERT INTO public.payments (
    user_id,
    user_email,
    user_name,
    tier,
    duration_days,
    amount,
    currency,
    payment_method,
    receipt_reference,
    receipt_url,
    receipt_file_name,
    status,
    payment_type,
    bonus_credits
  )
  VALUES (
    p_user_id,
    p_user_email,
    p_user_name,
    p_tier,
    p_duration_days,
    p_amount,
    'DZD',
    p_payment_method,
    p_receipt_reference,
    p_receipt_url,
    p_receipt_file_name,
    'pending',
    p_payment_type,
    p_bonus_credits
  )
  RETURNING id INTO v_payment_id;

  -- 2. Format admin notification based on payment type
  IF p_payment_type = 'quota_topup' THEN
    v_notif_title := '⚡ Recharge Quota IA : ' || p_user_name;
    v_notif_message := 'Une commande de recharge de ' || p_bonus_credits::text || ' requêtes IA (' || p_amount::text || ' DZD) a été soumise via ' || upper(p_payment_method) || ' et attend votre validation.';
  ELSE
    v_notif_title := '💳 Nouveau Règlement Reçu : ' || p_user_name;
    v_notif_message := 'Un paiement de ' || p_amount::text || ' DZD (' || upper(p_tier) || ' - ' || p_duration_days::text || ' jours) a été soumis via ' || upper(p_payment_method) || ' et attend votre validation.';
  END IF;

  -- 3. Insert admin notification
  INSERT INTO public.medical_notifications (
    id,
    title,
    message,
    type,
    target_role,
    is_broadcast,
    metadata
  )
  VALUES (
    'notif_admin_' || gen_random_uuid()::text,
    v_notif_title,
    v_notif_message,
    'announcement',
    'admin',
    false,
    jsonb_build_object(
      'payment_id', v_payment_id,
      'user_id', p_user_id,
      'user_email', p_user_email,
      'amount', p_amount,
      'tier', p_tier,
      'duration_days', p_duration_days,
      'payment_type', p_payment_type,
      'bonus_credits', p_bonus_credits
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'payment_id', v_payment_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- -----------------------------------------------------------------------------
-- 6. RPC: APPROVE PAYMENT (SUPPORTING SUBSCRIPTION ACTIVATION & QUOTA RECHARGES)
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.approve_payment_with_user_notif(uuid, uuid, text, integer, text);
DROP FUNCTION IF EXISTS public.approve_payment_with_user_notif;

CREATE OR REPLACE FUNCTION public.approve_payment_with_user_notif(
  p_payment_id uuid,
  p_user_id uuid,
  p_tier text,
  p_duration_days integer,
  p_admin_notes text DEFAULT 'Validé par l''administrateur'
)
RETURNS jsonb AS $$
DECLARE
  v_user_email text;
  v_user_name text;
  v_payment_type text := 'subscription';
  v_bonus_credits integer := 0;
  v_expiry timestamptz;
BEGIN
  -- 1. Fetch payment details
  SELECT user_email, user_name, payment_type, bonus_credits
  INTO v_user_email, v_user_name, v_payment_type, v_bonus_credits
  FROM public.payments
  WHERE id = p_payment_id;

  -- Fallback detection if payment_type is null
  IF v_payment_type IS NULL THEN
    IF p_tier LIKE 'quota_%' THEN
      v_payment_type := 'quota_topup';
    ELSE
      v_payment_type := 'subscription';
    END IF;
  END IF;

  -- 2. Update payment record to approved
  UPDATE public.payments
  SET status = 'approved',
      admin_notes = p_admin_notes,
      updated_at = now()
  WHERE id = p_payment_id;

  -- 3. Reset any prior rejection count on validated payment
  UPDATE public.profiles
  SET rejected_payments_count = 0
  WHERE id = p_user_id;

  -- 4. Branch based on payment type
  IF v_payment_type = 'quota_topup' THEN
    -- A. QUOTA TOP-UP: Credit bonus queries to user_ai_quotas
    IF v_bonus_credits <= 0 THEN
      -- Infer credits from tier name if bonus_credits was 0
      IF p_tier = 'pack_50' OR p_tier = 'quota_50' THEN
        v_bonus_credits := 50;
      ELSIF p_tier = 'pack_150' OR p_tier = 'quota_150' THEN
        v_bonus_credits := 150;
      ELSIF p_tier = 'pack_500' OR p_tier = 'quota_500' THEN
        v_bonus_credits := 500;
      ELSE
        v_bonus_credits := 50;
      END IF;
    END IF;

    -- Update or insert user_ai_quotas
    INSERT INTO public.user_ai_quotas (user_id, daily_requests_used, last_request_date, bonus_credits_balance)
    VALUES (p_user_id, 0, CURRENT_DATE, v_bonus_credits)
    ON CONFLICT (user_id) DO UPDATE SET
      bonus_credits_balance = user_ai_quotas.bonus_credits_balance + v_bonus_credits,
      updated_at = now();

    -- Notify user
    IF p_user_id IS NOT NULL THEN
      INSERT INTO public.medical_notifications (
        id,
        title,
        message,
        type,
        user_id,
        target_role,
        is_broadcast,
        metadata
      )
      VALUES (
        'notif_quota_' || gen_random_uuid()::text,
        '⚡ Vos +' || v_bonus_credits::text || ' requêtes IA sont disponibles !',
        'Votre recharge de ' || v_bonus_credits::text || ' requêtes MedsinaPilot a été validée avec succès par l''administration. Vous pouvez les utiliser à tout moment.',
        'announcement',
        p_user_id,
        'user',
        false,
        jsonb_build_object('payment_id', p_payment_id, 'bonus_credits', v_bonus_credits)
      );
    END IF;

    RETURN jsonb_build_object(
      'success', true,
      'type', 'quota_topup',
      'credited_bonus', v_bonus_credits,
      'message', 'Recharge de ' || v_bonus_credits::text || ' requêtes validée avec succès.'
    );

  ELSE
    -- B. SUBSCRIPTION: Activate or extend subscription
    v_expiry := now() + (p_duration_days || ' days')::interval;

    INSERT INTO public.subscriptions (user_id, tier, status, starts_at, expires_at, updated_at)
    VALUES (p_user_id, p_tier, 'active', now(), v_expiry, now())
    ON CONFLICT (user_id) DO UPDATE SET
      tier = excluded.tier,
      status = 'active',
      expires_at = GREATEST(subscriptions.expires_at, now()) + (p_duration_days || ' days')::interval,
      updated_at = now();

    -- Notify user
    IF p_user_id IS NOT NULL THEN
      INSERT INTO public.medical_notifications (
        id,
        title,
        message,
        type,
        user_id,
        target_role,
        is_broadcast,
        metadata
      )
      VALUES (
        'notif_welcome_' || gen_random_uuid()::text,
        '🎉 Félicitations ! Votre abonnement est activé',
        'Votre paiement pour la formule ' || upper(p_tier) || ' (' || p_duration_days::text || ' jours) a été validé avec succès par l''administration. Profitez de l''ensemble des fonctionnalités débloquées !',
        'announcement',
        p_user_id,
        'user',
        false,
        jsonb_build_object('payment_id', p_payment_id, 'tier', p_tier, 'duration_days', p_duration_days)
      );
    END IF;

    RETURN jsonb_build_object(
      'success', true,
      'type', 'subscription',
      'tier', p_tier,
      'expires_at', v_expiry
    );
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
