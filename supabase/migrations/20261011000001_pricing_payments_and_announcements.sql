-- Migration: 20261011000001_pricing_payments_and_announcements.sql
-- Description: Dynamic subscription plans pricing, payment transactions tracking, and system announcements

-- 1. SUBSCRIPTION PLANS TABLE
CREATE TABLE IF NOT EXISTS public.subscription_plans (
  id text PRIMARY KEY, -- 'free', 'clinical_pro', 'resident_elite', 'all_access'
  name text NOT NULL,
  badge text NOT NULL,
  price_yearly numeric NOT NULL DEFAULT 0,
  price_monthly numeric NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'DZD',
  discount_percent integer DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  features jsonb NOT NULL DEFAULT '[]'::jsonb,
  updated_at timestamptz DEFAULT now()
);

-- Seed Default Medsina Plans
INSERT INTO public.subscription_plans (id, name, badge, price_yearly, price_monthly, discount_percent, features)
VALUES 
  ('free', 'Pass Découverte', 'GRATUIT', 0, 0, 0, '["2 modules d''initiation au résidanat (50 QCMs)", "Scores médicaux de base", "Consultation des cours PDF en ligne"]'::jsonb),
  ('clinical_pro', 'Pass Clinique Pro', 'INTERNES & PRATICIENS', 10000, 1200, 15, '["Toutes les Conduites à Tenir (CAT) par spécialité", "Arbres décisionnels et protocoles d''urgence vitale", "Tous les scores et calculateurs médicaux", "Mémento de garde hospitalière et fiches réflexes", "Normes de laboratoire complètes"]'::jsonb),
  ('resident_elite', 'Pass Résident Élite', 'SPÉCIAL CONCOURS', 15000, 1800, 20, '["Les 47 modules officiels du Résidanat", "Simulateur d''examens blancs chronométrés", "Supports officiels de cours PDF", "Exports Anki et PDF", "CAT d''urgences essentielles"]'::jsonb),
  ('all_access', 'Medsina All-Access (VIP)', 'RECOMMANDÉ • SUITE COMPLÈTE', 20000, 2500, 30, '["Accès illimité aux 47 modules du Résidanat Blida & National", "Banque complète de 6 240+ QCMs avec corrigés détaillés", "Téléchargement de TOUS les cours en PDF", "Accès complet Pratique Clinique & Garde", "Calculateurs & scores avancés", "Mode hors-ligne multi-appareils"]'::jsonb)
ON CONFLICT (id) DO UPDATE SET
  name = excluded.name,
  badge = excluded.badge,
  price_yearly = excluded.price_yearly,
  price_monthly = excluded.price_monthly,
  discount_percent = excluded.discount_percent,
  features = excluded.features;

ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view subscription plans" ON public.subscription_plans;
CREATE POLICY "Anyone can view subscription plans"
ON public.subscription_plans FOR SELECT
USING (true);

DROP POLICY IF EXISTS "Admins can update subscription plans" ON public.subscription_plans;
CREATE POLICY "Admins can update subscription plans"
ON public.subscription_plans FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid() AND profiles.is_admin = true
  )
);

-- 2. PAYMENTS & TRANSACTIONS TABLE
CREATE TABLE IF NOT EXISTS public.payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  user_email text NOT NULL,
  user_name text NOT NULL,
  tier text NOT NULL,
  duration_days integer NOT NULL DEFAULT 365,
  amount numeric NOT NULL,
  currency text NOT NULL DEFAULT 'DZD',
  payment_method text NOT NULL DEFAULT 'baridimob', -- 'baridimob', 'ccp', 'virement', 'cash'
  receipt_reference text,
  status text NOT NULL DEFAULT 'pending', -- 'pending', 'approved', 'rejected'
  admin_notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payments_user_id ON public.payments(user_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON public.payments(status);

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own payments" ON public.payments;
CREATE POLICY "Users can view own payments"
ON public.payments FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert payment requests" ON public.payments;
CREATE POLICY "Users can insert payment requests"
ON public.payments FOR INSERT
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins can manage all payments" ON public.payments;
CREATE POLICY "Admins can manage all payments"
ON public.payments FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid() AND profiles.is_admin = true
  )
);

-- 3. SYSTEM ANNOUNCEMENTS TABLE
CREATE TABLE IF NOT EXISTS public.system_announcements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  message text NOT NULL,
  type text NOT NULL DEFAULT 'info', -- 'info', 'warning', 'urgent', 'success'
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.system_announcements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read active announcements" ON public.system_announcements;
CREATE POLICY "Anyone can read active announcements"
ON public.system_announcements FOR SELECT
USING (is_active = true);

DROP POLICY IF EXISTS "Admins can manage announcements" ON public.system_announcements;
CREATE POLICY "Admins can manage announcements"
ON public.system_announcements FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid() AND profiles.is_admin = true
  )
);
