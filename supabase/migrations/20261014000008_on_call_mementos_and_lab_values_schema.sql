-- =============================================================================
-- MEDSINA PLATFORM : ON-CALL MEMENTOS & LAB REFERENCE VALUES AUTOMATION SCHEMA
-- =============================================================================

-- 1. Ensure lab_reference_values has full RLS policies and timestamp columns
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'lab_reference_values' AND column_name = 'created_at'
  ) THEN
    ALTER TABLE public.lab_reference_values ADD COLUMN created_at timestamptz DEFAULT now();
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'lab_reference_values' AND column_name = 'updated_at'
  ) THEN
    ALTER TABLE public.lab_reference_values ADD COLUMN updated_at timestamptz DEFAULT now();
  END IF;
END $$;

ALTER TABLE public.lab_reference_values ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Lab values public read" ON public.lab_reference_values;
CREATE POLICY "Lab values public read" ON public.lab_reference_values
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Enable insert for lab_reference_values" ON public.lab_reference_values;
CREATE POLICY "Enable insert for lab_reference_values" ON public.lab_reference_values
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Enable update for lab_reference_values" ON public.lab_reference_values;
CREATE POLICY "Enable update for lab_reference_values" ON public.lab_reference_values
  FOR UPDATE USING (true);

CREATE INDEX IF NOT EXISTS idx_lab_reference_values_category ON public.lab_reference_values (category);
CREATE INDEX IF NOT EXISTS idx_lab_reference_values_name ON public.lab_reference_values (name);


-- 2. ON-CALL MEMENTOS (MÉMENTO DE GARDE HOSPITALIÈRE)
CREATE TABLE IF NOT EXISTS public.on_call_mementos (
  id text PRIMARY KEY,
  title text NOT NULL,
  category text NOT NULL DEFAULT 'Urgences & Garde',
  icon_name text NOT NULL DEFAULT 'warning_rounded',
  color_hex text NOT NULL DEFAULT '#EF4444',
  priority_level integer NOT NULL DEFAULT 1, -- 1: Urgence Vitale, 2: Vigilance / Protocole, 3: Bonne pratique
  points jsonb NOT NULL DEFAULT '[]'::jsonb,
  scientific_references text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.on_call_mementos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read on_call_mementos" ON public.on_call_mementos;
CREATE POLICY "Public read on_call_mementos" ON public.on_call_mementos
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Enable insert for on_call_mementos" ON public.on_call_mementos;
CREATE POLICY "Enable insert for on_call_mementos" ON public.on_call_mementos
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Enable update for on_call_mementos" ON public.on_call_mementos;
CREATE POLICY "Enable update for on_call_mementos" ON public.on_call_mementos
  FOR UPDATE USING (true);

CREATE INDEX IF NOT EXISTS idx_on_call_mementos_category ON public.on_call_mementos (category);
CREATE INDEX IF NOT EXISTS idx_on_call_mementos_priority ON public.on_call_mementos (priority_level);
CREATE INDEX IF NOT EXISTS idx_on_call_mementos_created ON public.on_call_mementos (created_at DESC);

