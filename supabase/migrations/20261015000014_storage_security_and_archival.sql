-- =============================================================================
-- Migration: 20261015000014_storage_security_and_archival.sql
-- Description:
--   1. Fix Storage RLS warning: remove overly broad public SELECT policy on storage.objects.
--   2. Add user ban and fraud tracking fields on profiles.
--   3. Add Google Drive archival tracking fields on payments.
--   4. Add targeted & admin notifications support on medical_notifications.
--   5. Provide RPC functions for:
--      - submit_payment_with_admin_alert
--      - approve_payment_with_user_notif
--      - reject_payment_with_fraud_check (auto-ban on 3 rejected payments)
--      - unban_user
--      - mark_receipt_archived
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. FIX STORAGE RLS POLICY WARNING (storage.objects)
-- -----------------------------------------------------------------------------

-- Drop broad public SELECT policy that triggered:
-- "Clients can list all files in this bucket: A broad SELECT policy on storage.objects allows clients to retrieve a full list of files."
DROP POLICY IF EXISTS "Allow public read on receipts" ON storage.objects;

-- Strict SELECT policy: Admins can list and inspect all receipts
DROP POLICY IF EXISTS "Allow admins to list and select receipts" ON storage.objects;
CREATE POLICY "Allow admins to list and select receipts"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'receipts' AND
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid() AND profiles.is_admin = true
  )
);

-- Strict SELECT policy: Users can only list and select receipts they uploaded (their own folder)
DROP POLICY IF EXISTS "Allow users to select own receipts" ON storage.objects;
CREATE POLICY "Allow users to select own receipts"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'receipts' AND
  (auth.uid()::text = (storage.foldername(name))[1])
);


-- -----------------------------------------------------------------------------
-- 2. ENHANCE PROFILES FOR FRAUD TRACKING & BANNING
-- -----------------------------------------------------------------------------
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS is_banned boolean NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS ban_reason text,
ADD COLUMN IF NOT EXISTS banned_at timestamptz,
ADD COLUMN IF NOT EXISTS rejected_payments_count integer NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_profiles_is_banned ON public.profiles(is_banned);


-- -----------------------------------------------------------------------------
-- 3. ENHANCE PAYMENTS FOR GOOGLE DRIVE ARCHIVAL
-- -----------------------------------------------------------------------------
ALTER TABLE public.payments
ADD COLUMN IF NOT EXISTS is_archived boolean NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS archive_drive_url text,
ADD COLUMN IF NOT EXISTS archive_drive_folder text,
ADD COLUMN IF NOT EXISTS archived_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_payments_is_archived ON public.payments(is_archived);


-- -----------------------------------------------------------------------------
-- 4. ENHANCE MEDICAL NOTIFICATIONS FOR TARGETED USER & ADMIN NOTIFICATIONS
-- -----------------------------------------------------------------------------
ALTER TABLE public.medical_notifications
ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS target_role text NOT NULL DEFAULT 'all'; -- 'all', 'admin', 'user'

CREATE INDEX IF NOT EXISTS idx_medical_notifications_user_id ON public.medical_notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_medical_notifications_target_role ON public.medical_notifications(target_role);

-- Allow authenticated users to view notifications addressed to them or broadcasts
DROP POLICY IF EXISTS "Users view own and broadcast notifications" ON public.medical_notifications;
CREATE POLICY "Users view own and broadcast notifications"
ON public.medical_notifications FOR SELECT
TO authenticated
USING (
  is_broadcast = true OR
  user_id = auth.uid() OR
  (
    target_role = 'admin' AND
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid() AND profiles.is_admin = true
    )
  )
);


-- -----------------------------------------------------------------------------
-- 5. RPC: SUBMIT PAYMENT WITH AUTOMATIC ADMIN ALERT
-- -----------------------------------------------------------------------------
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
  p_receipt_file_name text DEFAULT NULL
)
RETURNS jsonb AS $$
DECLARE
  v_payment_id uuid;
  v_is_banned boolean := false;
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
    status
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
    'pending'
  )
  RETURNING id INTO v_payment_id;

  -- 2. Insert admin notification
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
    '💳 Nouveau Règlement Reçu : ' || p_user_name,
    'Un paiement de ' || p_amount::text || ' DZD (' || upper(p_tier) || ' - ' || p_duration_days::text || ' jours) a été soumis via ' || upper(p_payment_method) || ' et attend votre validation.',
    'announcement',
    'admin',
    false,
    jsonb_build_object(
      'payment_id', v_payment_id,
      'user_id', p_user_id,
      'user_email', p_user_email,
      'amount', p_amount,
      'tier', p_tier,
      'duration_days', p_duration_days
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'payment_id', v_payment_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- -----------------------------------------------------------------------------
-- 6. RPC: APPROVE PAYMENT WITH USER CELEBRATION NOTIFICATION
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
  v_expiry timestamptz;
BEGIN
  v_expiry := now() + (p_duration_days || ' days')::interval;

  -- 1. Update payment status
  UPDATE public.payments
  SET status = 'approved',
      admin_notes = p_admin_notes,
      updated_at = now()
  WHERE id = p_payment_id
  RETURNING user_email, user_name INTO v_user_email, v_user_name;

  -- 2. Activate or extend subscription
  INSERT INTO public.subscriptions (user_id, tier, status, starts_at, expires_at, updated_at)
  VALUES (p_user_id, p_tier, 'active', now(), v_expiry, now())
  ON CONFLICT (user_id) DO UPDATE SET
    tier = excluded.tier,
    status = 'active',
    expires_at = GREATEST(subscriptions.expires_at, now()) + (p_duration_days || ' days')::interval,
    updated_at = now();

  -- 3. Reset any prior rejection count on successful validated payment
  UPDATE public.profiles
  SET rejected_payments_count = 0
  WHERE id = p_user_id;

  -- 4. Insert In-App celebration notification for the user
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
      'notif_user_' || gen_random_uuid()::text,
      '🎉 Formule Activée avec Succès !',
      'Félicitations Docteur ! Votre abonnement ' || upper(p_tier) || ' (' || p_duration_days::text || ' jours) est désormais actif jusqu''au ' || to_char(v_expiry, 'DD/MM/YYYY') || '. Bonnes révisions !',
      'announcement',
      p_user_id,
      'user',
      false,
      jsonb_build_object(
        'payment_id', p_payment_id,
        'tier', p_tier,
        'duration_days', p_duration_days,
        'expires_at', v_expiry
      )
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'user_email', v_user_email,
    'user_name', v_user_name,
    'expires_at', v_expiry
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- -----------------------------------------------------------------------------
-- 7. RPC: REJECT PAYMENT WITH FRAUD CHECK & AUTOMATIC 3-STRIKE BAN
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.reject_payment_with_fraud_check(uuid, text);
DROP FUNCTION IF EXISTS public.reject_payment_with_fraud_check;
CREATE OR REPLACE FUNCTION public.reject_payment_with_fraud_check(
  p_payment_id uuid,
  p_admin_notes text DEFAULT 'Reçu de paiement non conforme ou illisible'
)
RETURNS jsonb AS $$
DECLARE
  v_user_id uuid;
  v_user_email text;
  v_user_name text;
  v_rejected_count integer := 1;
  v_is_banned boolean := false;
  v_receipt_url text;
  v_receipt_file_name text;
BEGIN
  -- 1. Mark payment as rejected
  UPDATE public.payments
  SET status = 'rejected',
      admin_notes = p_admin_notes,
      updated_at = now()
  WHERE id = p_payment_id
  RETURNING user_id, user_email, user_name, receipt_url, receipt_file_name
  INTO v_user_id, v_user_email, v_user_name, v_receipt_url, v_receipt_file_name;

  IF v_user_id IS NOT NULL THEN
    -- 2. Count total rejected payments for this user
    SELECT count(*) INTO v_rejected_count
    FROM public.payments
    WHERE user_id = v_user_id AND status = 'rejected';

    -- 3. Update count in profiles
    UPDATE public.profiles
    SET rejected_payments_count = v_rejected_count
    WHERE id = v_user_id;

    -- 4. IF 3 REJECTS REACHED: AUTOMATICALLY BAN USER
    IF v_rejected_count >= 3 THEN
      UPDATE public.profiles
      SET is_banned = true,
          ban_reason = 'Suspension automatique : 3 tentatives de paiement avec reçus rejetés pour non-conformité.',
          banned_at = now()
      WHERE id = v_user_id;

      -- Revoke subscription
      UPDATE public.subscriptions
      SET status = 'suspended',
          tier = 'free',
          updated_at = now()
      WHERE user_id = v_user_id;

      v_is_banned := true;

      -- Admin alert notification: User banned
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
        '🚨 Utilisateur Banni pour Fraude (3 Rejets) : ' || v_user_name,
        'Le compte de ' || v_user_name || ' (' || v_user_email || ') a été automatiquement suspendu après 3 reçus rejetés consécutivement.',
        'announcement',
        'admin',
        false,
        jsonb_build_object('user_id', v_user_id, 'user_email', v_user_email, 'rejected_count', v_rejected_count)
      );

      -- User suspension notification
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
        'notif_user_' || gen_random_uuid()::text,
        '⛔ Compte Medsina Suspendu',
        'Votre compte a été suspendu suite au rejet de 3 preuves de paiement non conformes. Veuillez contacter le support administratif pour régulariser votre dossier.',
        'announcement',
        v_user_id,
        'user',
        false,
        jsonb_build_object('rejected_count', v_rejected_count, 'reason', p_admin_notes)
      );

    ELSE
      -- Warning notification for user (Strike 1/3 or 2/3)
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
        'notif_user_' || gen_random_uuid()::text,
        '⚠️ Preuve de Paiement Rejetée (Avertissement ' || v_rejected_count::text || '/3)',
        'Votre reçu a été refusé par l''administration : "' || p_admin_notes || '". Attention : à 3 rejets, votre compte sera automatiquement suspendu. Veuillez soumettre une preuve valide.',
        'announcement',
        v_user_id,
        'user',
        false,
        jsonb_build_object('rejected_count', v_rejected_count, 'reason', p_admin_notes)
      );
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'payment_id', p_payment_id,
    'user_id', v_user_id,
    'user_email', v_user_email,
    'user_name', v_user_name,
    'receipt_url', v_receipt_url,
    'receipt_file_name', v_receipt_file_name,
    'rejected_count', v_rejected_count,
    'is_banned', v_is_banned,
    'admin_notes', p_admin_notes
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- -----------------------------------------------------------------------------
-- 8. RPC: UNBAN USER
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.unban_user(uuid, text);
DROP FUNCTION IF EXISTS public.unban_user;
CREATE OR REPLACE FUNCTION public.unban_user(
  p_user_id uuid,
  p_admin_notes text DEFAULT 'Réactivé par l''administrateur'
)
RETURNS jsonb AS $$
BEGIN
  -- Reset ban and rejection counter
  UPDATE public.profiles
  SET is_banned = false,
      ban_reason = NULL,
      banned_at = NULL,
      rejected_payments_count = 0
  WHERE id = p_user_id;

  -- Restore subscription to active free or default
  UPDATE public.subscriptions
  SET status = 'active',
      updated_at = now()
  WHERE user_id = p_user_id;

  -- Send notification to user
  INSERT INTO public.medical_notifications (
    id,
    title,
    message,
    type,
    user_id,
    target_role,
    is_broadcast
  )
  VALUES (
    'notif_user_' || gen_random_uuid()::text,
    '✅ Compte Réactivé',
    'Votre compte Medsina a été débloqué par l''administrateur. Vous pouvez à nouveau naviguer et renouveler votre formule.',
    'announcement',
    p_user_id,
    'user',
    false
  );

  RETURN jsonb_build_object('success', true, 'user_id', p_user_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- -----------------------------------------------------------------------------
-- 9. RPC: MARK RECEIPT AS ARCHIVED TO GOOGLE DRIVE
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.mark_receipt_archived(uuid, text, text);
DROP FUNCTION IF EXISTS public.mark_receipt_archived;
CREATE OR REPLACE FUNCTION public.mark_receipt_archived(
  p_payment_id uuid,
  p_drive_url text,
  p_folder text
)
RETURNS jsonb AS $$
BEGIN
  UPDATE public.payments
  SET is_archived = true,
      archive_drive_url = p_drive_url,
      archive_drive_folder = p_folder,
      archived_at = now()
  WHERE id = p_payment_id;

  RETURN jsonb_build_object('success', true, 'payment_id', p_payment_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- -----------------------------------------------------------------------------
-- 10. RPC: GET APPROVED RECEIPTS ELIGIBLE FOR ARCHIVAL (OLDER THAN N DAYS)
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.get_receipts_eligible_for_archival(integer);
DROP FUNCTION IF EXISTS public.get_receipts_eligible_for_archival;
CREATE OR REPLACE FUNCTION public.get_receipts_eligible_for_archival(
  p_retention_days integer DEFAULT 30
)
RETURNS TABLE (
  id uuid,
  user_id uuid,
  user_email text,
  user_name text,
  tier text,
  amount numeric,
  receipt_url text,
  receipt_file_name text,
  created_at timestamptz
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.user_id,
    p.user_email,
    p.user_name,
    p.tier,
    p.amount,
    p.receipt_url,
    p.receipt_file_name,
    p.created_at
  FROM public.payments p
  WHERE p.status = 'approved'
    AND p.is_archived = false
    AND p.receipt_url IS NOT NULL
    AND p.receipt_url <> ''
    AND p.created_at <= (now() - (p_retention_days || ' days')::interval)
  ORDER BY p.created_at ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- -----------------------------------------------------------------------------
-- 11. RPC: ADMIN LIST USERS WITH BAN & FRAUD FIELDS
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.admin_list_users();
DROP FUNCTION IF EXISTS public.admin_list_users;
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
  created_at timestamptz
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
    p.created_at
  FROM public.profiles p
  LEFT JOIN public.subscriptions s ON s.user_id = p.id
  ORDER BY p.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

