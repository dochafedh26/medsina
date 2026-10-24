-- Migration: 20261024000024_universal_subscription_upgrade_trigger.sql
-- Description: Universal PostgreSQL trigger on public.subscriptions
--              Automatically generates celebration notifications for the upgraded user
--              and audit logs for the admin whenever any subscription is activated/upgraded.

CREATE OR REPLACE FUNCTION public.trg_subscription_upgrade_notify()
RETURNS trigger AS $$
DECLARE
  v_user_name text;
  v_user_email text;
  v_tier_label text;
  v_expiry_str text;
BEGIN
  -- Only trigger for non-free subscriptions when tier changes or expiry is extended
  IF NEW.tier = 'free' THEN
    RETURN NEW;
  END IF;

  IF (TG_OP = 'UPDATE' AND OLD.tier = NEW.tier AND NEW.expires_at <= OLD.expires_at) THEN
    RETURN NEW;
  END IF;

  -- 1. Get user profile metadata
  SELECT full_name, email INTO v_user_name, v_user_email
  FROM public.profiles
  WHERE id = NEW.user_id;

  v_user_name := coalesce(v_user_name, 'Docteur');
  v_user_email := coalesce(v_user_email, '');

  -- 2. Format tier label in French
  CASE NEW.tier
    WHEN 'etudiant' THEN v_tier_label := 'Pass Étudiant (Cursus Universitaire)';
    WHEN 'clinical_pro' THEN v_tier_label := 'Pass Clinique Pro (Pratique Médicale)';
    WHEN 'resident_elite' THEN v_tier_label := 'Pass Résident Élite (47 Modules)';
    WHEN 'all_access' THEN v_tier_label := 'Medsina All-Access VIP';
    ELSE v_tier_label := upper(NEW.tier);
  END CASE;

  v_expiry_str := to_char(NEW.expires_at, 'DD/MM/YYYY');

  -- 3. In-App Celebration Notification for the upgraded User
  INSERT INTO public.medical_notifications (
    id,
    user_id,
    title,
    message,
    type,
    target_role,
    is_broadcast,
    metadata,
    created_at
  )
  VALUES (
    'notif_upgrade_' || NEW.user_id || '_' || extract(epoch from now())::bigint,
    NEW.user_id,
    '🎉 Félicitations ! Votre ' || v_tier_label || ' est Actif',
    'Félicitations Docteur ' || v_user_name || ' ! Votre formule ' || v_tier_label || ' est désormais active jusqu''au ' || coalesce(v_expiry_str, 'terme prévu') || '. Tous vos accès illimités sont débloqués, bonnes révisions !',
    'subscription',
    'user',
    false,
    jsonb_build_object(
      'type', 'plan_upgrade',
      'tier', NEW.tier,
      'expires_at', NEW.expires_at,
      'user_id', NEW.user_id,
      'full_name', v_user_name
    ),
    now()
  )
  ON CONFLICT (id) DO NOTHING;

  -- 4. In-App Audit Notification for the Administrator
  INSERT INTO public.medical_notifications (
    id,
    user_id,
    title,
    message,
    type,
    target_role,
    is_broadcast,
    metadata,
    created_at
  )
  VALUES (
    'admin_upgrade_' || NEW.user_id || '_' || extract(epoch from now())::bigint,
    null,
    '⭐ Activation Formule : ' || v_user_name || ' (' || upper(NEW.tier) || ')',
    'Le compte de ' || v_user_name || ' (' || v_user_email || ') a été surclassé vers la formule ' || v_tier_label || ' jusqu''au ' || coalesce(v_expiry_str, '') || '.',
    'announcement',
    'admin',
    false,
    jsonb_build_object(
      'is_admin_only', true,
      'target_role', 'admin',
      'user_id', NEW.user_id,
      'email', v_user_email,
      'full_name', v_user_name,
      'tier', NEW.tier,
      'expires_at', NEW.expires_at
    ),
    now()
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Attach trigger to public.subscriptions
DROP TRIGGER IF EXISTS trg_subscription_upgrade_trigger ON public.subscriptions;
CREATE TRIGGER trg_subscription_upgrade_trigger
  AFTER INSERT OR UPDATE ON public.subscriptions
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_subscription_upgrade_notify();
