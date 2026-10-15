-- =============================================================================
-- Migration: 20261015000011_trial_quotas_and_receipts.sql
-- Description: Free tier quotas (2 chosen modules, 2 courses each, 1 QCM session,
--              1 Vidal analysis, 1 lab analysis, 1 Copilot prompt) & Payment receipts.
-- =============================================================================

-- 1. ADD RECEIPT URL AND FILE NAME TO PAYMENTS
ALTER TABLE public.payments
ADD COLUMN IF NOT EXISTS receipt_url text,
ADD COLUMN IF NOT EXISTS receipt_file_name text;

-- 2. USER TRIAL QUOTAS TABLE
CREATE TABLE IF NOT EXISTS public.user_trial_quotas (
  user_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  selected_free_modules text[] NOT NULL DEFAULT '{}',
  qcm_sessions_used integer NOT NULL DEFAULT 0,
  prescription_analyses_used integer NOT NULL DEFAULT 0,
  lab_analyses_used integer NOT NULL DEFAULT 0,
  copilot_queries_used integer NOT NULL DEFAULT 0,
  has_used_trial boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.user_trial_quotas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own trial quotas" ON public.user_trial_quotas;
CREATE POLICY "Users can view own trial quotas"
ON public.user_trial_quotas FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own trial quotas" ON public.user_trial_quotas;
CREATE POLICY "Users can update own trial quotas"
ON public.user_trial_quotas FOR ALL
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins can manage all trial quotas" ON public.user_trial_quotas;
CREATE POLICY "Admins can manage all trial quotas"
ON public.user_trial_quotas FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid() AND profiles.is_admin = true
  )
);

-- 3. RPC: GET OR INITIALIZE USER TRIAL QUOTAS
CREATE OR REPLACE FUNCTION public.get_or_create_user_trial_quotas(p_user_id uuid)
RETURNS jsonb AS $$
DECLARE
  v_rec record;
BEGIN
  SELECT * INTO v_rec FROM public.user_trial_quotas WHERE user_id = p_user_id;
  
  IF NOT FOUND THEN
    INSERT INTO public.user_trial_quotas (user_id)
    VALUES (p_user_id)
    RETURNING * INTO v_rec;
  END IF;

  RETURN jsonb_build_object(
    'user_id', v_rec.user_id,
    'selected_free_modules', v_rec.selected_free_modules,
    'qcm_sessions_used', v_rec.qcm_sessions_used,
    'prescription_analyses_used', v_rec.prescription_analyses_used,
    'lab_analyses_used', v_rec.lab_analyses_used,
    'copilot_queries_used', v_rec.copilot_queries_used,
    'has_used_trial', v_rec.has_used_trial
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. RPC: SAVE SELECTED FREE MODULES (MAX 2)
CREATE OR REPLACE FUNCTION public.save_selected_free_modules(p_user_id uuid, p_modules text[])
RETURNS jsonb AS $$
DECLARE
  v_existing text[];
BEGIN
  SELECT selected_free_modules INTO v_existing FROM public.user_trial_quotas WHERE user_id = p_user_id;
  
  -- If user doesn't exist, create it
  IF NOT FOUND THEN
    INSERT INTO public.user_trial_quotas (user_id, selected_free_modules)
    VALUES (p_user_id, p_modules[1:2]);
    RETURN jsonb_build_object('success', true, 'selected_free_modules', p_modules[1:2]);
  END IF;

  -- If already selected 2 modules, keep them unless forced
  IF array_length(v_existing, 1) >= 2 THEN
    RETURN jsonb_build_object('success', true, 'selected_free_modules', v_existing, 'message', 'Modules d''essai déjà sélectionnés');
  END IF;

  UPDATE public.user_trial_quotas
  SET selected_free_modules = p_modules[1:2],
      updated_at = now()
  WHERE user_id = p_user_id;

  RETURN jsonb_build_object('success', true, 'selected_free_modules', p_modules[1:2]);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. RPC: CONSUME TRIAL QUOTA
CREATE OR REPLACE FUNCTION public.consume_trial_quota(p_user_id uuid, p_quota_type text)
RETURNS jsonb AS $$
DECLARE
  v_new_val integer := 0;
BEGIN
  -- Ensure row exists
  INSERT INTO public.user_trial_quotas (user_id)
  VALUES (p_user_id)
  ON CONFLICT (user_id) DO NOTHING;

  IF p_quota_type = 'qcm_session' THEN
    UPDATE public.user_trial_quotas
    SET qcm_sessions_used = qcm_sessions_used + 1, updated_at = now()
    WHERE user_id = p_user_id
    RETURNING qcm_sessions_used INTO v_new_val;
  ELSIF p_quota_type = 'prescription_analysis' THEN
    UPDATE public.user_trial_quotas
    SET prescription_analyses_used = prescription_analyses_used + 1, updated_at = now()
    WHERE user_id = p_user_id
    RETURNING prescription_analyses_used INTO v_new_val;
  ELSIF p_quota_type = 'lab_analysis' THEN
    UPDATE public.user_trial_quotas
    SET lab_analyses_used = lab_analyses_used + 1, updated_at = now()
    WHERE user_id = p_user_id
    RETURNING lab_analyses_used INTO v_new_val;
  ELSIF p_quota_type = 'copilot_query' THEN
    UPDATE public.user_trial_quotas
    SET copilot_queries_used = copilot_queries_used + 1, updated_at = now()
    WHERE user_id = p_user_id
    RETURNING copilot_queries_used INTO v_new_val;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'quota_type', p_quota_type,
    'new_count', v_new_val
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

