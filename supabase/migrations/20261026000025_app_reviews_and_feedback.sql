-- =============================================================================
-- Migration: 20261026000025_app_reviews_and_feedback.sql
-- Description: Community Reviews, Star Ratings (1-5), Quick Tags & Admin Replies
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.app_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  user_name text NOT NULL,
  user_role text NOT NULL DEFAULT 'Candidat Résidanat',
  user_faculty text NOT NULL DEFAULT 'Faculté de Médecine de Blida',
  user_tier text NOT NULL DEFAULT 'free',
  rating smallint NOT NULL CHECK (rating >= 1 AND rating <= 5),
  category text NOT NULL DEFAULT 'general', -- 'general', 'qcm_residanat', 'clinique_cat', 'vidal_ordonnance', 'ia_omnisearch', 'suggestion'
  quick_tags jsonb NOT NULL DEFAULT '[]'::jsonb,
  title text,
  comment text NOT NULL,
  helpful_count integer NOT NULL DEFAULT 0,
  is_approved boolean NOT NULL DEFAULT true,
  is_featured boolean NOT NULL DEFAULT false,
  admin_reply text,
  admin_replied_at timestamptz,
  app_version text DEFAULT '1.0.19',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Indexes for fast queries and filtering
CREATE INDEX IF NOT EXISTS idx_app_reviews_user_id
  ON public.app_reviews(user_id);

CREATE INDEX IF NOT EXISTS idx_app_reviews_public_feed
  ON public.app_reviews(is_approved, is_featured DESC, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_app_reviews_category
  ON public.app_reviews(category);

-- Grant table permissions to Data API roles
GRANT SELECT ON public.app_reviews TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.app_reviews TO authenticated;

-- Enable Row Level Security
ALTER TABLE public.app_reviews ENABLE ROW LEVEL SECURITY;

-- 1. Anyone (authenticated or anon) can read approved reviews, and authors can read their own
DROP POLICY IF EXISTS "Public can view approved app reviews" ON public.app_reviews;
CREATE POLICY "Public can view approved app reviews"
ON public.app_reviews
FOR SELECT
TO authenticated, anon
USING (
  is_approved = true
  OR (select auth.uid()) = user_id
  OR EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = (select auth.uid()) AND profiles.is_admin = true
  )
);

-- 2. Authenticated users can insert their own review
DROP POLICY IF EXISTS "Users can insert own app review" ON public.app_reviews;
CREATE POLICY "Users can insert own app review"
ON public.app_reviews
FOR INSERT
TO authenticated
WITH CHECK (
  (select auth.uid()) = user_id
);

-- 3. Authenticated users can update their own review (or helpful_count)
DROP POLICY IF EXISTS "Users can update own app review" ON public.app_reviews;
CREATE POLICY "Users can update own app review"
ON public.app_reviews
FOR UPDATE
TO authenticated
USING (
  (select auth.uid()) = user_id
  OR is_approved = true
)
WITH CHECK (
  (select auth.uid()) = user_id
  OR is_approved = true
);

-- 4. Admins have full control over all reviews (approve, feature, reply, delete)
DROP POLICY IF EXISTS "Admins can manage all app reviews" ON public.app_reviews;
CREATE POLICY "Admins can manage all app reviews"
ON public.app_reviews
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = (select auth.uid()) AND profiles.is_admin = true
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = (select auth.uid()) AND profiles.is_admin = true
  )
);

-- Seed verified initial community reviews (idempotent)
INSERT INTO public.app_reviews (
  id, user_name, user_role, user_faculty, user_tier, rating, category, quick_tags, title, comment, helpful_count, is_approved, is_featured, admin_reply, admin_replied_at, app_version, created_at
)
VALUES
  (
    'a1111111-1111-4111-8111-111111111101',
    'Dr. Amine K.',
    'Candidat Résidanat',
    'Faculté de Médecine de Blida',
    'resident_elite',
    5,
    'qcm_residanat',
    '["Explications QCM claires", "Recherche Ctrl+K ultra-rapide", "Mode hors-ligne fluide"]'::jsonb,
    'La meilleure plateforme pour préparer le concours de Blida !',
    'Les 47 modules sont parfaitement structurés avec les cours officiels et une banque de QCMs ultra complète. Les corrigés détaillés font gagner un temps précieux pendant les révisions.',
    24,
    true,
    true,
    'Merci beaucoup Dr. Amine ! Toute l''équipe Medsina vous souhaite une excellente réussite au concours du Résidanat 2027.',
    now() - interval '4 days',
    '1.0.18',
    now() - interval '5 days'
  ),
  (
    'a1111111-1111-4111-8111-111111111102',
    'Dr. Yasmine B.',
    'Médecin Interne',
    'Faculté de Médecine d''Alger',
    'all_access',
    5,
    'clinique_cat',
    '["Indispensable en garde", "Vidal & Interactions top", "Gain de temps énorme"]'::jsonb,
    'Mon compagnon indispensable pendant les gardes aux urgences',
    'Les protocoles CAT d''urgence, les posologies d''urgence et le vérificateur d''ordonnance Vidal Algérie m''ont sauvé la mise plusieurs fois en garde de nuit. Le mode hors-ligne fonctionne sans aucune latence.',
    19,
    true,
    true,
    NULL,
    NULL,
    '1.0.18',
    now() - interval '3 days'
  ),
  (
    'a1111111-1111-4111-8111-111111111103',
    'Rayan M.',
    'Externe (6ème année)',
    'Faculté de Médecine de Blida',
    'etudiant',
    5,
    'ia_omnisearch',
    '["Recherche Ctrl+K ultra-rapide", "Interface moderne", "Fiches synthétiques"]'::jsonb,
    'Omnisearch et les résumés de cours sont incroyables',
    'Avec Ctrl+K sur PC ou la barre Omnisearch sur Android, je retrouve n''importe quelle valeur biologique, triade clinique ou cours PDF en une seconde.',
    14,
    true,
    false,
    NULL,
    NULL,
    '1.0.18',
    now() - interval '2 days'
  ),
  (
    'a1111111-1111-4111-8111-111111111104',
    'Dr. Mehdi S.',
    'Médecin Généraliste',
    'Faculté de Médecine d''Oran',
    'clinical_pro',
    5,
    'vidal_ordonnance',
    '["Vidal & Interactions top", "Indispensable en garde"]'::jsonb,
    'Analyseur d''ordonnance et nomenclature MSPRH au top',
    'Très pratique en consultation quotidienne pour vérifier rapidement les contre-indications liées au terrain (insuffisance rénale, grossesse) et les équivalents commerciaux algériens.',
    11,
    true,
    false,
    NULL,
    NULL,
    '1.0.18',
    now() - interval '1 day'
  )
ON CONFLICT (id) DO NOTHING;
