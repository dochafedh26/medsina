-- =============================================================================
-- Migration: 20261031000028_user_loyalty_and_connection_tracker.sql
-- Description: User Loyalty Program, XP Ranks, Daily Streak & Connection Tracker
-- =============================================================================

-- 1. Add loyalty and connection tracking columns to public.profiles if not present
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS connection_count integer DEFAULT 1,
  ADD COLUMN IF NOT EXISTS streak_days integer DEFAULT 1,
  ADD COLUMN IF NOT EXISTS max_streak_days integer DEFAULT 1,
  ADD COLUMN IF NOT EXISTS last_connection_at timestamptz DEFAULT now(),
  ADD COLUMN IF NOT EXISTS loyalty_points integer DEFAULT 10,
  ADD COLUMN IF NOT EXISTS loyalty_level text DEFAULT 'Externe Studieux',
  ADD COLUMN IF NOT EXISTS total_usage_seconds integer DEFAULT 0;

-- 2. Index for active doctors by streak and loyalty points
CREATE INDEX IF NOT EXISTS idx_profiles_loyalty_streak
  ON public.profiles(streak_days DESC, loyalty_points DESC);

CREATE INDEX IF NOT EXISTS idx_profiles_last_connection
  ON public.profiles(last_connection_at DESC);

-- 3. Atomic helper to record a connection & loyalty update
CREATE OR REPLACE FUNCTION public.record_user_connection(
  p_user_id uuid,
  p_connection_count integer,
  p_streak_days integer,
  p_max_streak_days integer,
  p_loyalty_points integer,
  p_loyalty_level text,
  p_session_seconds integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_res jsonb;
BEGIN
  UPDATE public.profiles
  SET
    connection_count = GREATEST(COALESCE(connection_count, 0), p_connection_count),
    streak_days = p_streak_days,
    max_streak_days = GREATEST(COALESCE(max_streak_days, 1), p_max_streak_days),
    last_connection_at = now(),
    loyalty_points = GREATEST(COALESCE(loyalty_points, 0), p_loyalty_points),
    loyalty_level = p_loyalty_level,
    total_usage_seconds = COALESCE(total_usage_seconds, 0) + GREATEST(0, p_session_seconds),
    updated_at = now()
  WHERE id = p_user_id;

  SELECT jsonb_build_object(
    'connection_count', connection_count,
    'streak_days', streak_days,
    'max_streak_days', max_streak_days,
    'loyalty_points', loyalty_points,
    'loyalty_level', loyalty_level,
    'last_connection_at', last_connection_at
  ) INTO v_res
  FROM public.profiles
  WHERE id = p_user_id;

  RETURN COALESCE(v_res, '{}'::jsonb);
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_user_connection TO authenticated, service_role;
