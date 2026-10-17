-- =============================================================================
-- Migration: 20261017000018_referral_and_payment_system.sql
-- Description: Viral Doctor Referral System (Gamification, +7d VIP, +50 AI queries),
--              Chargily Pay (CIB/EDAHABIA) integration, and Local Algerian Payment coordinates.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. ADD REFERRAL CODE TO PROFILES
-- -----------------------------------------------------------------------------
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS referral_code text UNIQUE;

-- Backfill referral code for any existing profiles that don't have one
UPDATE public.profiles
SET referral_code = 'DR-' || upper(substring(replace(id::text, '-', '') from 1 for 6))
WHERE referral_code IS NULL;

-- Ensure future profiles automatically get a referral code
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
-- 2. CREATE USER REFERRALS TABLE
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_referrals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  referred_id uuid NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
  referral_code text NOT NULL,
  reward_granted boolean NOT NULL DEFAULT true,
  reward_days integer NOT NULL DEFAULT 7,
  reward_ai_credits integer NOT NULL DEFAULT 50,
  created_at timestamptz DEFAULT now()
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
-- 3. RPC: CLAIM REFERRAL CODE
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.claim_referral_code(p_code text)
RETURNS jsonb AS $$
DECLARE
  v_current_user uuid;
  v_referrer_id uuid;
  v_existing_claim record;
  v_clean_code text;
BEGIN
  v_current_user := auth.uid();
  IF v_current_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Utilisateur non authentifié.');
  END IF;

  v_clean_code := upper(trim(p_code));

  -- Check if already claimed
  SELECT * INTO v_existing_claim
  FROM public.user_referrals
  WHERE referred_id = v_current_user;

  IF FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Vous avez déjà utilisé un code de parrainage.');
  END IF;

  -- Find referrer
  SELECT id INTO v_referrer_id
  FROM public.profiles
  WHERE upper(trim(referral_code)) = v_clean_code;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Code de parrainage introuvable.');
  END IF;

  IF v_referrer_id = v_current_user THEN
    RETURN jsonb_build_object('success', false, 'message', 'Vous ne pouvez pas utiliser votre propre code de parrainage.');
  END IF;

  -- Insert referral record
  INSERT INTO public.user_referrals (referrer_id, referred_id, referral_code, reward_days, reward_ai_credits)
  VALUES (v_referrer_id, v_current_user, v_clean_code, 7, 50);

  -- 1. Grant +7 days VIP to the referee (current user)
  INSERT INTO public.subscriptions (user_id, tier, status, starts_at, expires_at)
  VALUES (v_current_user, 'resident_elite', 'active', now(), now() + interval '7 days')
  ON CONFLICT (user_id) DO UPDATE
  SET status = 'active',
      expires_at = greatest(public.subscriptions.expires_at, now()) + interval '7 days',
      updated_at = now();

  -- 2. Grant +7 days VIP to the referrer
  INSERT INTO public.subscriptions (user_id, tier, status, starts_at, expires_at)
  VALUES (v_referrer_id, 'resident_elite', 'active', now(), now() + interval '7 days')
  ON CONFLICT (user_id) DO UPDATE
  SET status = 'active',
      expires_at = greatest(public.subscriptions.expires_at, now()) + interval '7 days',
      updated_at = now();

  -- 3. Grant +50 AI Credits to referee
  INSERT INTO public.user_ai_quotas (user_id, daily_requests_used, last_request_date, bonus_credits_balance)
  VALUES (v_current_user, 0, CURRENT_DATE, 50)
  ON CONFLICT (user_id) DO UPDATE
  SET bonus_credits_balance = public.user_ai_quotas.bonus_credits_balance + 50,
      updated_at = now();

  -- 4. Grant +50 AI Credits to referrer
  INSERT INTO public.user_ai_quotas (user_id, daily_requests_used, last_request_date, bonus_credits_balance)
  VALUES (v_referrer_id, 0, CURRENT_DATE, 50)
  ON CONFLICT (user_id) DO UPDATE
  SET bonus_credits_balance = public.user_ai_quotas.bonus_credits_balance + 50,
      updated_at = now();

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Félicitations ! 7 jours VIP et 50 requêtes IA ont été offerts à vous et à votre confrère.',
    'bonus_days', 7,
    'bonus_credits', 50
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 4. RPC: GET USER REFERRAL STATS
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_user_referral_stats()
RETURNS jsonb AS $$
DECLARE
  v_user_id uuid;
  v_code text;
  v_total_referred integer := 0;
  v_bonus_days integer := 0;
  v_bonus_credits integer := 0;
  v_has_claimed boolean := false;
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

  SELECT count(*) INTO v_total_referred
  FROM public.user_referrals
  WHERE referrer_id = v_user_id;

  SELECT coalesce(sum(reward_days), 0), coalesce(sum(reward_ai_credits), 0)
  INTO v_bonus_days, v_bonus_credits
  FROM public.user_referrals
  WHERE referrer_id = v_user_id;

  SELECT exists(SELECT 1 FROM public.user_referrals WHERE referred_id = v_user_id)
  INTO v_has_claimed;

  RETURN jsonb_build_object(
    'success', true,
    'referral_code', v_code,
    'total_referred', v_total_referred,
    'bonus_days_earned', v_bonus_days,
    'bonus_credits_earned', v_bonus_credits,
    'has_claimed_code', v_has_claimed
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 5. INITIALIZE DEFAULT SETTINGS FOR CHARGILY PAY & LOCAL PAYMENT COORDINATES
-- -----------------------------------------------------------------------------
INSERT INTO public.admin_system_settings (setting_key, setting_value, description)
VALUES 
  ('chargily_public_key', '', 'Chargily Pay v2 Public Key for EDAHABIA/CIB checkout'),
  ('chargily_secret_key', '', 'Chargily Pay v2 Secret Key for payment webhooks/verification'),
  ('chargily_app_url', 'https://medsina.medevsync.com', 'Base URL for Chargily return/cancel redirects'),
  ('chargily_mode', 'test', 'Chargily mode: test or live'),
  ('baridimob_rip', '007999990025841234 56', 'Official BaridiMob RIP displayed to Algerian doctors'),
  ('ccp_account', '258412 Clé 34', 'Official CCP Postal Account for in-office wire'),
  ('support_whatsapp', '+213770000000', 'Official Support WhatsApp for instant payment receipt submission')
ON CONFLICT (setting_key) DO NOTHING;
