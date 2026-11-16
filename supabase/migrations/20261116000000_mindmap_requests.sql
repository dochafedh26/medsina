-- Migration: Add mindmap_requests table for user-requested course Mind Maps
-- Allows users to request Mind Map creation when a course or summary lacks one.

CREATE TABLE IF NOT EXISTS public.mindmap_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id text NOT NULL,
  course_name text NOT NULL DEFAULT '',
  module_name text NOT NULL DEFAULT '',
  user_id text NOT NULL DEFAULT 'anonymous',
  user_email text,
  user_name text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_mindmap_requests_course_user UNIQUE (course_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_mindmap_requests_course_id
  ON public.mindmap_requests (course_id);

CREATE INDEX IF NOT EXISTS idx_mindmap_requests_status
  ON public.mindmap_requests (status, created_at DESC);

ALTER TABLE public.mindmap_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read mindmap requests" ON public.mindmap_requests;
CREATE POLICY "Public read mindmap requests"
  ON public.mindmap_requests
  FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Users can insert mindmap requests" ON public.mindmap_requests;
CREATE POLICY "Users can insert mindmap requests"
  ON public.mindmap_requests
  FOR INSERT
  WITH CHECK (true);

DROP POLICY IF EXISTS "Service role full access on mindmap_requests" ON public.mindmap_requests;
CREATE POLICY "Service role full access on mindmap_requests"
  ON public.mindmap_requests
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);
