-- =============================================================================
-- MEDSINA PLATFORM : TÉMOIGNAGES & CONSEILS DES MAJORS DU RÉSIDANAT
-- Table dynamique pour stocker et synchroniser les témoignages en temps réel
-- sans nécessiter de mise à jour ou de recompilation de l'application mobile.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.temoignages_conseils (
  id text PRIMARY KEY,
  name text NOT NULL,
  rank_badge text NOT NULL,
  rank_number integer NOT NULL DEFAULT 99,
  year text NOT NULL DEFAULT '2026',
  faculty text NOT NULL DEFAULT 'Faculté de Médecine de Blida',
  is_recent_2026 boolean NOT NULL DEFAULT false,
  document_type text NOT NULL DEFAULT 'pdf_local_and_drive',
  target_url text,
  gdrive_folder_url text,
  telegram_url text,
  gdrive_id text,
  extra_gdrive_id text,
  pdf_file text,
  extra_pdf_file text,
  summary text NOT NULL DEFAULT '',
  key_advices jsonb NOT NULL DEFAULT '[]'::jsonb,
  recommended_sources text NOT NULL DEFAULT '',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Active la sécurité au niveau des lignes (RLS)
ALTER TABLE public.temoignages_conseils ENABLE ROW LEVEL SECURITY;

-- Lecture publique accessible à tous (anonyme et authentifié)
DROP POLICY IF EXISTS "Public read temoignages_conseils" ON public.temoignages_conseils;
CREATE POLICY "Public read temoignages_conseils" ON public.temoignages_conseils
  FOR SELECT USING (true);

-- Insertion autorisée (Admin / Service Role / Automation)
DROP POLICY IF EXISTS "Enable insert for temoignages_conseils" ON public.temoignages_conseils;
CREATE POLICY "Enable insert for temoignages_conseils" ON public.temoignages_conseils
  FOR INSERT WITH CHECK (true);

-- Mise à jour autorisée (Admin / Service Role / Automation)
DROP POLICY IF EXISTS "Enable update for temoignages_conseils" ON public.temoignages_conseils;
CREATE POLICY "Enable update for temoignages_conseils" ON public.temoignages_conseils
  FOR UPDATE USING (true);

-- Index pour la performance des requêtes et filtres
CREATE INDEX IF NOT EXISTS idx_temoignages_rank_number ON public.temoignages_conseils (rank_number);
CREATE INDEX IF NOT EXISTS idx_temoignages_year ON public.temoignages_conseils (year);
CREATE INDEX IF NOT EXISTS idx_temoignages_is_recent ON public.temoignages_conseils (is_recent_2026);
