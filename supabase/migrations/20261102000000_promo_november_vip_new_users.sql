-- =============================================================================
-- Migration: 20261102000000_promo_november_vip_new_users.sql
-- Description: Automatisation Promotion Spéciale "Nouveaux Inscrits"
--              Du 02 Novembre 2026 au 30 Novembre 2026 (inclus).
--              Tout nouvel utilisateur bénéficie de 1 Mois All-Access VIP offert.
-- =============================================================================

-- 1. Table public.subscriptions
CREATE TABLE IF NOT EXISTS public.subscriptions (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE UNIQUE,
  tier text NOT NULL DEFAULT 'free',
  status text NOT NULL DEFAULT 'active',
  starts_at timestamptz DEFAULT now(),
  expires_at timestamptz DEFAULT (now() + interval '14 days'),
  max_devices int DEFAULT 3,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Index pour performance
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON public.subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_tier ON public.subscriptions(tier);

-- Activer RLS
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own subscription" ON public.subscriptions;
CREATE POLICY "Users read own subscription" ON public.subscriptions
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins manage subscriptions" ON public.subscriptions;
CREATE POLICY "Admins manage subscriptions" ON public.subscriptions
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_admin = true)
  );

-- 2. Fonction handle_new_user avec vérification de la Promo Novembre 2026
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
  v_promo_start timestamptz := '2026-11-02 00:00:00+00';
  v_promo_end   timestamptz := '2026-11-30 23:59:59+00';
  v_tier        text := 'free';
  v_duration    interval := interval '14 days';
  v_user_name   text;
  v_is_promo    boolean := false;
BEGIN
  v_user_name := coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1));

  -- Création / Mise à jour profil
  INSERT INTO public.profiles (id, email, full_name, faculty, role)
  VALUES (
    new.id,
    new.email,
    v_user_name,
    coalesce(new.raw_user_meta_data->>'faculty', 'Faculté de Médecine de Blida'),
    coalesce(new.raw_user_meta_data->>'medical_role', 'Médecin')
  )
  ON CONFLICT (id) DO UPDATE SET
    email = excluded.email,
    full_name = coalesce(public.profiles.full_name, excluded.full_name);

  -- Vérification Fenêtre Promotionnelle (02 au 30 Novembre 2026)
  IF now() >= v_promo_start AND now() <= v_promo_end THEN
    v_tier := 'all_access';
    v_duration := interval '30 days';
    v_is_promo := true;
  END IF;

  -- Création / Mise à jour abonnement
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
    expires_at = CASE WHEN v_is_promo THEN greatest(public.subscriptions.expires_at, now() + interval '30 days') ELSE public.subscriptions.expires_at END,
    updated_at = now();

  -- Notification In-App de Bienvenue personnalisée pour les bénéficiaires de la promo
  IF v_is_promo THEN
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
      'promo_nov2026_' || new.id || '_' || extract(epoch from now())::bigint,
      new.id,
      '🎁 Bienvenue VIP : 1 Mois All-Access Offert !',
      'Bienvenue sur Medsina Dr ' || v_user_name || ' ! Dans le cadre de l''Offre Spéciale de Lancement (02 au 30 Novembre 2026), votre Pass All-Access VIP est activé gratuitement pour 1 mois complet. Accédez sans aucune restriction aux 47 modules du Résidanat, aux 6 240+ QCMs, aux CAT d''Urgences et aux tuteurs MedsinaTeacher !',
      'announcement',
      'user',
      false,
      jsonb_build_object(
        'promo', 'novembre_2026_all_access_1_mois',
        'tier', 'all_access',
        'duration_days', 30,
        'expires_at', (now() + interval '30 days')
      ),
      now()
    )
    ON CONFLICT (id) DO NOTHING;
  END IF;

  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Déclencheur sur auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- 3. Rétroactivité : Mise à niveau de tous les utilisateurs inscrits aujourd'hui (02/11/2026)
DO $$
DECLARE
  rec RECORD;
BEGIN
  FOR rec IN 
    SELECT id, email, raw_user_meta_data->>'full_name' as name, created_at
    FROM auth.users
    WHERE created_at >= '2026-11-02 00:00:00+00'
  LOOP
    INSERT INTO public.subscriptions (user_id, tier, status, starts_at, expires_at, updated_at)
    VALUES (
      rec.id,
      'all_access',
      'active',
      rec.created_at,
      rec.created_at + interval '30 days',
      now()
    )
    ON CONFLICT (user_id) DO UPDATE SET
      tier = 'all_access',
      status = 'active',
      expires_at = greatest(public.subscriptions.expires_at, rec.created_at + interval '30 days'),
      updated_at = now();
  END LOOP;
END;
$$;
