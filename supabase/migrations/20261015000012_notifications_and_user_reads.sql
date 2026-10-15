-- Migration: 20261015000012_notifications_and_user_reads.sql
-- Description: Centralized medical notifications catalog and user read receipts synchronization with RLS

-- 1. MEDICAL NOTIFICATIONS CATALOG
CREATE TABLE IF NOT EXISTS public.medical_notifications (
  id text PRIMARY KEY,
  title text NOT NULL,
  message text NOT NULL,
  type text NOT NULL DEFAULT 'announcement', -- 'pearl', 'cat', 'course', 'qcm', 'announcement'
  target_id text,
  metadata jsonb DEFAULT '{}'::jsonb,
  is_broadcast boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- Index for fast ordering by recency
CREATE INDEX IF NOT EXISTS idx_medical_notifications_created_at 
  ON public.medical_notifications(created_at DESC);

-- Enable RLS
ALTER TABLE public.medical_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can view broadcast notifications" ON public.medical_notifications;
CREATE POLICY "Public can view broadcast notifications"
  ON public.medical_notifications FOR SELECT
  USING (is_broadcast = true);

DROP POLICY IF EXISTS "Admins can manage notifications" ON public.medical_notifications;
CREATE POLICY "Admins can manage notifications"
  ON public.medical_notifications FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid() AND profiles.is_admin = true
    )
  );

-- Seed Initial High-Yield Medical Notifications
INSERT INTO public.medical_notifications (id, title, message, type, target_id, is_broadcast)
VALUES
  (
    'seed_pearl_1',
    '💡 Perle du Jour : Hyponatrémie sévère',
    'Règle vitale : Ne jamais dépasser 8-10 mmol/L de correction en 24h pour prévenir la myélinolyse.',
    'pearl',
    'pearl_seed_hyponatremie',
    true
  ),
  (
    'seed_cat_1',
    '🚨 Nouvelle CAT : Prise en charge SCA ST+ (IDM)',
    'Consensus national UMC & SFMU mis à jour : Dérivations droites V3R-V4R impératives.',
    'cat',
    'cat_sca_stplus',
    true
  ),
  (
    'seed_qcm_1',
    '🎯 Nouvelle Banque QCM : Cardiologie Blida 2024',
    '340 QCMs classés avec corrections détaillées et pièges fréquents ajoutés.',
    'qcm',
    'mod_cardio',
    true
  ),
  (
    'seed_announcement_1',
    '🌟 Bienvenue sur Medsina 2027',
    'Plateforme Médicale Globale pour les internes et candidats au concours de résidanat.',
    'announcement',
    null,
    true
  )
ON CONFLICT (id) DO UPDATE SET
  title = excluded.title,
  message = excluded.message,
  type = excluded.type,
  target_id = excluded.target_id,
  is_broadcast = excluded.is_broadcast;

-- 2. USER NOTIFICATION READS TABLE (Per-User Read Receipts)
CREATE TABLE IF NOT EXISTS public.user_notification_reads (
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  notification_id text NOT NULL,
  read_at timestamptz DEFAULT now(),
  PRIMARY KEY (user_id, notification_id)
);

CREATE INDEX IF NOT EXISTS idx_user_notification_reads_user 
  ON public.user_notification_reads(user_id, read_at DESC);

-- Enable RLS
ALTER TABLE public.user_notification_reads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own read notifications" ON public.user_notification_reads;
CREATE POLICY "Users can view own read notifications"
  ON public.user_notification_reads FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own read notifications" ON public.user_notification_reads;
CREATE POLICY "Users can insert own read notifications"
  ON public.user_notification_reads FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own read notifications" ON public.user_notification_reads;
CREATE POLICY "Users can delete own read notifications"
  ON public.user_notification_reads FOR DELETE
  USING (auth.uid() = user_id);

-- 3. STORED RPC FUNCTIONS FOR HIGH-PERFORMANCE SYNC

-- Fetch read notification IDs for the current user
CREATE OR REPLACE FUNCTION public.get_user_read_notifications()
RETURNS text[]
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
  v_reads text[];
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN ARRAY[]::text[];
  END IF;

  SELECT coalesce(array_agg(notification_id), ARRAY[]::text[])
  INTO v_reads
  FROM public.user_notification_reads
  WHERE user_id = v_user_id;

  RETURN v_reads;
END;
$$;

-- Mark a single notification as read
CREATE OR REPLACE FUNCTION public.mark_notification_as_read(p_notification_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL OR p_notification_id IS NULL OR p_notification_id = '' THEN
    RETURN;
  END IF;

  INSERT INTO public.user_notification_reads (user_id, notification_id, read_at)
  VALUES (v_user_id, p_notification_id, now())
  ON CONFLICT (user_id, notification_id) DO UPDATE SET read_at = now();
END;
$$;

-- Mark multiple notifications as read in a single batch
CREATE OR REPLACE FUNCTION public.mark_all_notifications_as_read(p_notification_ids text[])
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
  v_id text;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL OR p_notification_ids IS NULL OR array_length(p_notification_ids, 1) IS NULL THEN
    RETURN;
  END IF;

  FOREACH v_id IN ARRAY p_notification_ids
  LOOP
    IF v_id IS NOT NULL AND v_id <> '' THEN
      INSERT INTO public.user_notification_reads (user_id, notification_id, read_at)
      VALUES (v_user_id, v_id, now())
      ON CONFLICT (user_id, notification_id) DO UPDATE SET read_at = now();
    END IF;
  END LOOP;
END;
$$;
