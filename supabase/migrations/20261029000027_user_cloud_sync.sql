-- =============================================================================
-- MEDSINA PLATFORM : CROSS-DEVICE USER CLOUD SYNC SCHEMA
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.user_cloud_sync (
  id TEXT PRIMARY KEY, -- Format: '${user_id}_${data_type}'
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  data_type TEXT NOT NULL, -- 'custom_sessions', 'course_progress', 'qcm_annotations', 'study_planner', 'fsrs_flashcards', 'user_settings'
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE public.user_cloud_sync ENABLE ROW LEVEL SECURITY;

-- Policies
DROP POLICY IF EXISTS "Users can manage own sync data" ON public.user_cloud_sync;
CREATE POLICY "Users can manage own sync data"
ON public.user_cloud_sync
FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Lookup index
CREATE INDEX IF NOT EXISTS idx_user_cloud_sync_lookup 
ON public.user_cloud_sync (user_id, data_type);

