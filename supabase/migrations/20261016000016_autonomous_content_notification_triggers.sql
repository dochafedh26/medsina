-- =============================================================================
-- Migration: 20261016000016_autonomous_content_notification_triggers.sql
-- Description: Automatic PostgreSQL triggers to generate broadcast notifications
--              in medical_notifications whenever automated content is created
--              (Course Summaries from GitHub Actions, Daily Pearls, Urgent CATs).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. TRIGGER: COURSE SUMMARIES AUTO NOTIFICATION
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_course_summary_created_notify()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.medical_notifications (
    id,
    title,
    message,
    type,
    target_id,
    target_role,
    is_broadcast,
    metadata,
    created_at
  )
  VALUES (
    'notif_summary_' || NEW.course_id,
    '📖 Nouvelle Fiche Synthèse : ' || NEW.course_name,
    'La fiche de révision officielle du cours "' || NEW.course_name || '" (Module ' || NEW.module_name || ') vient d''être publiée avec points clés et pièges de concours !',
    'course',
    NEW.course_id,
    'user',
    true,
    jsonb_build_object(
      'course_id', NEW.course_id,
      'course_name', NEW.course_name,
      'module_id', NEW.module_id,
      'module_name', NEW.module_name
    ),
    now()
  )
  ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    message = EXCLUDED.message,
    created_at = now();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_course_summary_notify_trigger ON public.course_summaries;
CREATE TRIGGER trg_course_summary_notify_trigger
AFTER INSERT OR UPDATE ON public.course_summaries
FOR EACH ROW
EXECUTE FUNCTION public.trg_course_summary_created_notify();


-- -----------------------------------------------------------------------------
-- 2. TRIGGER: DAILY PEARLS AUTO NOTIFICATION
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_daily_pearl_created_notify()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.medical_notifications (
    id,
    title,
    message,
    type,
    target_id,
    target_role,
    is_broadcast,
    metadata,
    created_at
  )
  VALUES (
    'notif_pearl_' || NEW.id::text,
    '💡 Nouvelle Perle Clinique & Piège Concours',
    NEW.title || ' (' || NEW.course_name || ' • ' || NEW.module_name || ')',
    'pearl',
    NEW.id::text,
    'user',
    true,
    jsonb_build_object(
      'pearl_id', NEW.id,
      'course_name', NEW.course_name,
      'module_name', NEW.module_name
    ),
    now()
  )
  ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    message = EXCLUDED.message,
    created_at = now();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_daily_pearl_notify_trigger ON public.daily_pearls;
CREATE TRIGGER trg_daily_pearl_notify_trigger
AFTER INSERT ON public.daily_pearls
FOR EACH ROW
EXECUTE FUNCTION public.trg_daily_pearl_created_notify();


-- -----------------------------------------------------------------------------
-- 3. TRIGGER: CLINICAL PROTOCOLS (CAT) AUTO NOTIFICATION
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_clinical_protocol_created_notify()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.medical_notifications (
    id,
    title,
    message,
    type,
    target_id,
    target_role,
    is_broadcast,
    metadata,
    created_at
  )
  VALUES (
    'notif_cat_' || NEW.id,
    '🚨 Nouveau Protocole d''Urgence : ' || NEW.title,
    'Arbre décisionnel et conduite à tenir (CAT) validés selon les consensus actuels ajoutés à la section Pratique Clinique.',
    'cat',
    NEW.id,
    'user',
    true,
    jsonb_build_object(
      'protocol_id', NEW.id,
      'title', NEW.title,
      'urgency_level', NEW.urgency_level
    ),
    now()
  )
  ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    message = EXCLUDED.message,
    created_at = now();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_clinical_protocol_notify_trigger ON public.clinical_protocols;
CREATE TRIGGER trg_clinical_protocol_notify_trigger
AFTER INSERT ON public.clinical_protocols
FOR EACH ROW
EXECUTE FUNCTION public.trg_clinical_protocol_created_notify();


-- -----------------------------------------------------------------------------
-- 4. BACKFILL: RETROACTIVELY BROADCAST EXISTING COURSE SUMMARIES & PEARLS
-- -----------------------------------------------------------------------------
INSERT INTO public.medical_notifications (
  id,
  title,
  message,
  type,
  target_id,
  target_role,
  is_broadcast,
  metadata,
  created_at
)
SELECT
  'notif_summary_' || s.course_id,
  '📖 Fiche Synthèse Disponible : ' || s.course_name,
  'La fiche de révision officielle pour "' || s.course_name || '" (Module ' || s.module_name || ') est disponible avec points clés et pièges de concours !',
  'course',
  s.course_id,
  'user',
  true,
  jsonb_build_object(
    'course_id', s.course_id,
    'course_name', s.course_name,
    'module_id', s.module_id,
    'module_name', s.module_name
  ),
  s.updated_at
FROM public.course_summaries s
ON CONFLICT (id) DO NOTHING;
