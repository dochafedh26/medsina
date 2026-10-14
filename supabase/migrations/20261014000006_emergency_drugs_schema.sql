-- =============================================================================
-- MEDSINA PLATFORM : EMERGENCY DRUGS (URGENCES & DCI ALGÉRIE) SCHEMA
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.emergency_drugs (
  id text PRIMARY KEY,
  dci text NOT NULL,
  brand text NOT NULL,
  category text NOT NULL DEFAULT 'Général',
  route text NOT NULL DEFAULT '',
  indication text NOT NULL DEFAULT '',
  dose text NOT NULL DEFAULT '',
  alert text NOT NULL DEFAULT '',
  algerian_availability text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.emergency_drugs ENABLE ROW LEVEL SECURITY;

-- Policies
DROP POLICY IF EXISTS "Public read emergency_drugs" ON public.emergency_drugs;
CREATE POLICY "Public read emergency_drugs"
ON public.emergency_drugs FOR SELECT
USING (true);

DROP POLICY IF EXISTS "Enable insert for emergency_drugs" ON public.emergency_drugs;
CREATE POLICY "Enable insert for emergency_drugs"
ON public.emergency_drugs FOR INSERT
WITH CHECK (true);

DROP POLICY IF EXISTS "Enable update for emergency_drugs" ON public.emergency_drugs;
CREATE POLICY "Enable update for emergency_drugs"
ON public.emergency_drugs FOR UPDATE
USING (true);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_emergency_drugs_dci ON public.emergency_drugs (dci);
CREATE INDEX IF NOT EXISTS idx_emergency_drugs_category ON public.emergency_drugs (category);
