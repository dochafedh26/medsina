-- =============================================================================
-- MEDSINA PLATFORM : OFFICIAL COURSE SUMMARIES (FICHES RÉSUMÉS DE COURS)
-- Automated high-yield residency course synthesis generated via Gemini & experts
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.course_summaries (
  course_id text PRIMARY KEY,
  course_name text NOT NULL,
  module_id text NOT NULL,
  module_name text NOT NULL,
  summary_markdown text NOT NULL,
  key_takeaways jsonb NOT NULL DEFAULT '[]'::jsonb,
  exam_traps jsonb NOT NULL DEFAULT '[]'::jsonb,
  diagnostic_criteria text,
  treatment_summary text,
  target_audience text NOT NULL DEFAULT 'Concours Résidanat 2027',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.course_summaries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read course_summaries" ON public.course_summaries;
CREATE POLICY "Public read course_summaries" ON public.course_summaries
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Enable insert for course_summaries" ON public.course_summaries;
CREATE POLICY "Enable insert for course_summaries" ON public.course_summaries
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Enable update for course_summaries" ON public.course_summaries;
CREATE POLICY "Enable update for course_summaries" ON public.course_summaries
  FOR UPDATE USING (true);

CREATE INDEX IF NOT EXISTS idx_course_summaries_module_id ON public.course_summaries (module_id);
CREATE INDEX IF NOT EXISTS idx_course_summaries_course_name ON public.course_summaries (course_name);

