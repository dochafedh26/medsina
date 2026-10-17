-- =============================================================================
-- Migration: 20261017000018_referral_and_payment_system.sql
-- Description: Strict & Anti-Fraud Medical Referral System:
--              - Cas 01: 5 paid referrals >= 1 year = 1 year FREE (Resident Elite or Clinical Pro) + 250 AI
--              - Cas 02: 10 paid referrals >= 6 months = 1 year FREE (Resident Elite or Clinical Pro) + 150 AI
--              - Capped Free Onboarding (+10 AI, max 5 referrals per doctor = 50 AI max)
--              - Chargily Pay v2 (CIB / EDAHABIA) & Official Payment Coordinates (CHIKH TOUHAMI HAFED)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. ADD REFERRAL CODE TO PROFILES
-- -----------------------------------------------------------------------------
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS referral_code text UNIQUE;

UPDATE public.profiles
SET referral_code = 'DR-' || upper(substring(replace(id::text, '-', '') from 1 for 6))
WHERE referral_code IS NULL;

CREATE OR REPLACE FUNCTION public.set_default_referral_code()
RETURNS trigger AS $$
BEGIN
  IF NEW.referral_code IS NULL THEN
    NEW.referral_code := 'DR-' || upper(substring(replace(NEW.id::text, '-', '') from 1 for 6));
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_set_default_referral_code ON public.profiles;
CREATE TRIGGER trg_set_default_referral_code
BEFORE INSERT ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.set_default_referral_code();

-- -----------------------------------------------------------------------------
-- 2. CREATE USER REFERRALS TABLE (STRICT & ANTI-FRAUD SCHEMA)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_referrals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  referred_id uuid NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
  referral_code text NOT NULL,
  
  -- Free onboarding reward: +10 AI queries to each (strictly capped at 5 per referrer)
  initial_credits_granted boolean NOT NULL DEFAULT false,
  
  -- Paid conversion tracking (strictly verified from payments table)
  paid_duration_days integer NOT NULL DEFAULT 0,
  paid_subscription_tier text,
  is_annual_paid boolean NOT NULL DEFAULT false,
  is_six_months_paid boolean NOT NULL DEFAULT false,
  paid_unit_reward_granted boolean NOT NULL DEFAULT false,
  
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.user_referrals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own referrals" ON public.user_referrals;
CREATE POLICY "Users can read own referrals"
ON public.user_referrals FOR SELECT
USING (auth.uid() = referrer_id OR auth.uid() = referred_id);

DROP POLICY IF EXISTS "Admins can manage all referrals" ON public.user_referrals;
CREATE POLICY "Admins can manage all referrals"
ON public.user_referrals FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid() AND profiles.is_admin = true
  )
);

-- -----------------------------------------------------------------------------
-- 3. RPC: CLAIM REFERRAL CODE (STRICT CAPPED ONBOARDING)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.claim_referral_code(p_code text)
RETURNS jsonb AS $$
DECLARE
  v_current_user uuid;
  v_referrer_id uuid;
  v_existing_claim record;
  v_clean_code text;
  v_free_count integer := 0;
  v_grant_referrer boolean := false;
BEGIN
  v_current_user := auth.uid();
  IF v_current_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Utilisateur non authentifié.');
  END IF;

  v_clean_code := upper(trim(p_code));

  -- 1. Anti-abuse: Check if current user already claimed any referral
  SELECT * INTO v_existing_claim
  FROM public.user_referrals
  WHERE referred_id = v_current_user;

  IF FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Vous avez déjà utilisé un code de parrainage sur ce compte.');
  END IF;

  -- 2. Find referrer
  SELECT id INTO v_referrer_id
  FROM public.profiles
  WHERE upper(trim(referral_code)) = v_clean_code;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Code de parrainage introuvable ou invalide.');
  END IF;

  -- 3. Anti-abuse: Self-referral prohibited
  IF v_referrer_id = v_current_user THEN
    RETURN jsonb_build_object('success', false, 'message', 'Action interdite : vous ne pouvez pas parrainer votre propre compte.');
  END IF;

  -- 4. Check referrer free referrals cap (Strict limit: max 5 free bonuses = 50 AI max)
  SELECT count(*) INTO v_free_count
  FROM public.user_referrals
  WHERE referrer_id = v_referrer_id AND initial_credits_granted = true;

  IF v_free_count < 5 THEN
    v_grant_referrer := true;
  END IF;

  -- 5. Insert referral link
  INSERT INTO public.user_referrals (
    referrer_id,
    referred_id,
    referral_code,
    initial_credits_granted
  ) VALUES (
    v_referrer_id,
    v_current_user,
    v_clean_code,
    v_grant_referrer
  );

  -- 6. Grant +10 AI queries to the referee (joining resident)
  INSERT INTO public.user_ai_quotas (user_id, daily_requests_used, last_request_date, bonus_credits_balance)
  VALUES (v_current_user, 0, CURRENT_DATE, 10)
  ON CONFLICT (user_id) DO UPDATE
  SET bonus_credits_balance = public.user_ai_quotas.bonus_credits_balance + 10,
      updated_at = now();

  -- 7. Grant +10 AI queries to referrer ONLY if under cap
  IF v_grant_referrer THEN
    INSERT INTO public.user_ai_quotas (user_id, daily_requests_used, last_request_date, bonus_credits_balance)
    VALUES (v_referrer_id, 0, CURRENT_DATE, 10)
    ON CONFLICT (user_id) DO UPDATE
    SET bonus_credits_balance = public.user_ai_quotas.bonus_credits_balance + 10,
        updated_at = now();

    RETURN jsonb_build_object(
      'success', true,
      'bonus_credits', 10,
      'message', 'Code validé avec succès ! +10 requêtes IA offertes à vous et à votre confrère.'
    );
  ELSE
    RETURN jsonb_build_object(
      'success', true,
      'bonus_credits', 10,
      'message', 'Code validé avec succès ! +10 requêtes IA offertes pour votre compte.'
    );
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 4. TRIGGER: PROCESS REFERRAL REWARDS UPON APPROVED PAYMENT
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_referral_payment_reward()
RETURNS trigger AS $$
DECLARE
  v_ref_record record;
  v_duration integer;
  v_tier text;
BEGIN
  -- Only trigger when payment transitions to 'approved'
  IF NEW.status = 'approved' AND (OLD.status IS NULL OR OLD.status != 'approved') THEN
    v_duration := coalesce(NEW.duration_days, 30);
    v_tier := coalesce(NEW.tier, 'resident_elite');

    -- Check if paying user was referred by someone
    SELECT * INTO v_ref_record
    FROM public.user_referrals
    WHERE referred_id = NEW.user_id;

    IF FOUND THEN
      -- Update referral record with paid stats
      UPDATE public.user_referrals
      SET paid_duration_days = greatest(paid_duration_days, v_duration),
          paid_subscription_tier = v_tier,
          is_annual_paid = (greatest(paid_duration_days, v_duration) >= 365),
          is_six_months_paid = (greatest(paid_duration_days, v_duration) >= 180),
          updated_at = now()
      WHERE id = v_ref_record.id;

      -- If this is their first paid purchase (>= 30 days), award unit booster to referrer (+40 AI & +7 days VIP)
      IF NOT v_ref_record.paid_unit_reward_granted AND v_duration >= 30 THEN
        UPDATE public.user_referrals
        SET paid_unit_reward_granted = true
        WHERE id = v_ref_record.id;

        -- Referrer +40 AI bonus credits
        INSERT INTO public.user_ai_quotas (user_id, daily_requests_used, last_request_date, bonus_credits_balance)
        VALUES (v_ref_record.referrer_id, 0, CURRENT_DATE, 40)
        ON CONFLICT (user_id) DO UPDATE
        SET bonus_credits_balance = public.user_ai_quotas.bonus_credits_balance + 40,
            updated_at = now();

        -- Referrer +7 days VIP extension
        UPDATE public.subscriptions
        SET expires_at = greatest(expires_at, now()) + interval '7 days',
            updated_at = now()
        WHERE user_id = v_ref_record.referrer_id;
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_handle_referral_payment_reward ON public.payments;
CREATE TRIGGER trg_handle_referral_payment_reward
AFTER UPDATE ON public.payments
FOR EACH ROW
EXECUTE FUNCTION public.handle_referral_payment_reward();

-- -----------------------------------------------------------------------------
-- 5. RPC: GET STRICT USER REFERRAL STATS
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_user_referral_stats()
RETURNS jsonb AS $$
DECLARE
  v_user_id uuid;
  v_code text;
  v_free_count integer := 0;
  v_annual_paid_count integer := 0;
  v_six_months_paid_count integer := 0;
  v_total_paid_count integer := 0;
  v_has_claimed boolean := false;
  v_annual_unlocked boolean := false;
  v_six_months_unlocked boolean := false;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Non connecté.');
  END IF;

  SELECT referral_code INTO v_code
  FROM public.profiles
  WHERE id = v_user_id;

  IF v_code IS NULL THEN
    v_code := 'DR-' || upper(substring(replace(v_user_id::text, '-', '') from 1 for 6));
    UPDATE public.profiles SET referral_code = v_code WHERE id = v_user_id;
  END IF;

  -- Free micro-onboarding count (capped at 5)
  SELECT count(*) INTO v_free_count
  FROM public.user_referrals
  WHERE referrer_id = v_user_id AND initial_credits_granted = true;

  -- Cas 01: Count of referrals who paid >= 1 year (>= 365 days)
  SELECT count(*) INTO v_annual_paid_count
  FROM public.user_referrals
  WHERE referrer_id = v_user_id AND is_annual_paid = true;

  -- Cas 02: Count of referrals who paid >= 6 months (>= 180 days)
  SELECT count(*) INTO v_six_months_paid_count
  FROM public.user_referrals
  WHERE referrer_id = v_user_id AND is_six_months_paid = true;

  -- Total paid
  SELECT count(*) INTO v_total_paid_count
  FROM public.user_referrals
  WHERE referrer_id = v_user_id AND paid_duration_days >= 30;

  SELECT exists(SELECT 1 FROM public.user_referrals WHERE referred_id = v_user_id)
  INTO v_has_claimed;

  v_annual_unlocked := (v_annual_paid_count >= 5);
  v_six_months_unlocked := (v_six_months_paid_count >= 10);

  RETURN jsonb_build_object(
    'success', true,
    'referral_code', v_code,
    'free_count', v_free_count,
    'free_cap', 5,
    'free_ai_credits_earned', v_free_count * 10,
    'annual_paid_count', v_annual_paid_count,
    'annual_target', 5,
    'annual_unlocked', v_annual_unlocked,
    'six_months_paid_count', v_six_months_paid_count,
    'six_months_target', 10,
    'six_months_unlocked', v_six_months_unlocked,
    'total_paid_count', v_total_paid_count,
    'has_claimed_code', v_has_claimed
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 6. RPC: CLAIM EARNED 1-YEAR FREE SUBSCRIPTION (CAS 01 & CAS 02)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.claim_referral_free_year(p_choice_tier text)
RETURNS jsonb AS $$
DECLARE
  v_user_id uuid;
  v_annual_count integer := 0;
  v_six_months_count integer := 0;
  v_tier text;
  v_bonus_ai integer := 0;
  v_already_claimed boolean := false;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Non authentifié.');
  END IF;

  v_tier := lower(trim(p_choice_tier));
  IF v_tier NOT IN ('resident_elite', 'clinical_pro') THEN
    RETURN jsonb_build_object('success', false, 'message', 'Veuillez choisir soit Résident Élite (resident_elite), soit Médecin Pro (clinical_pro).');
  END IF;

  -- Check annual count (Cas 01: >= 5)
  SELECT count(*) INTO v_annual_count
  FROM public.user_referrals
  WHERE referrer_id = v_user_id AND is_annual_paid = true;

  -- Check six-months count (Cas 02: >= 10)
  SELECT count(*) INTO v_six_months_count
  FROM public.user_referrals
  WHERE referrer_id = v_user_id AND is_six_months_paid = true;

  IF v_annual_count < 5 AND v_six_months_count < 10 THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', format('Paliers non atteints. Il vous faut soit 5 filleuls avec abonnement annuel (actuel: %s/5), soit 10 filleuls avec abonnement semestriel (actuel: %s/10).', v_annual_count, v_six_months_count)
    );
  END IF;

  IF v_annual_count >= 5 THEN
    v_bonus_ai := 250;
  ELSE
    v_bonus_ai := 150;
  END IF;

  -- 1. Upgrade user subscription for 365 days
  INSERT INTO public.subscriptions (user_id, tier, status, starts_at, expires_at)
  VALUES (v_user_id, v_tier, 'active', now(), now() + interval '365 days')
  ON CONFLICT (user_id) DO UPDATE
  SET tier = v_tier,
      status = 'active',
      expires_at = greatest(public.subscriptions.expires_at, now()) + interval '365 days',
      updated_at = now();

  -- 2. Grant bonus AI credits
  INSERT INTO public.user_ai_quotas (user_id, daily_requests_used, last_request_date, bonus_credits_balance)
  VALUES (v_user_id, 0, CURRENT_DATE, v_bonus_ai)
  ON CONFLICT (user_id) DO UPDATE
  SET bonus_credits_balance = public.user_ai_quotas.bonus_credits_balance + v_bonus_ai,
      updated_at = now();

  -- 3. Log in payments table for audit
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
    status,
    admin_notes
  ) VALUES (
    v_user_id,
    coalesce((SELECT email FROM public.profiles WHERE id = v_user_id), 'resident@medsina.com'),
    coalesce((SELECT full_name FROM public.profiles WHERE id = v_user_id), 'Dr. Ambassadeur'),
    v_tier,
    365,
    0,
    'DZD',
    'referral_reward',
    'AMBASSADOR-1YEAR-AWARD',
    'approved',
    format('Récompense parrainage strict validée : %s annuel(s) / %s semestriel(s). +%s IA', v_annual_count, v_six_months_count, v_bonus_ai)
  );

  RETURN jsonb_build_object(
    'success', true,
    'tier', v_tier,
    'bonus_ai', v_bonus_ai,
    'message', format('Félicitations Confrère ! Votre abonnement 1 an offert (%s) et +%s requêtes IA ont été activés avec succès !', v_tier, v_bonus_ai)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 7. INITIALIZE DEFAULT SETTINGS
-- -----------------------------------------------------------------------------
INSERT INTO public.admin_system_settings (setting_key, setting_value, description)
VALUES 
  ('chargily_public_key', 'test_pk_rqlUVsQu2nc0l1aUf5sHAI4A9yJuK7sucTZOe8eD', 'Chargily Pay v2 Public Key for EDAHABIA/CIB checkout'),
  ('chargily_secret_key', 'test_sk_6p4nWfgUpfDa01BqQZQafxyFHMbKVHLZfJbKNQ1X', 'Chargily Pay v2 Secret Key for payment webhooks/verification'),
  ('chargily_app_url', 'https://medsina.medevsync.com', 'Base URL for Chargily return/cancel redirects'),
  ('chargily_mode', 'test', 'Chargily mode: test or live'),
  ('baridimob_rip', '007999990009171614 93', 'Official BaridiMob RIP displayed to Algerian doctors (CHIKH TOUHAMI HAFED)'),
  ('ccp_account', '9171614 Clé 19', 'Official CCP Postal Account for in-office wire'),
  ('ccp_holder', 'CHIKH TOUHAMI HAFED', 'Official CCP Account Holder Name'),
  ('support_whatsapp', '+213770000000', 'Official Support WhatsApp for instant payment receipt submission')
ON CONFLICT (setting_key) DO UPDATE
SET setting_value = EXCLUDED.setting_value,
    description = EXCLUDED.description;
