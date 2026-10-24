-- Migration: 20261024000023_welcome_and_admin_subscriber_notifications.sql
-- Description: Automated in-app welcome notification for newly registered subscribers
--              and real-time admin alert notification in medical_notifications.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
  v_name text;
  v_role text;
  v_faculty text;
  v_study_year int;
BEGIN
  v_name := coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1));
  v_role := coalesce(new.raw_user_meta_data->>'medical_role', 'Candidat Résidanat');
  v_faculty := coalesce(new.raw_user_meta_data->>'faculty', 'Faculté de Médecine de Blida');
  IF new.raw_user_meta_data->>'study_year' IS NOT NULL THEN
    v_study_year := (new.raw_user_meta_data->>'study_year')::int;
  END IF;

  -- 1. Insert or update profile
  INSERT INTO public.profiles (
    id,
    email,
    full_name,
    medical_role,
    faculty,
    study_year,
    created_at,
    updated_at
  )
  VALUES (
    new.id,
    new.email,
    v_name,
    v_role,
    v_faculty,
    v_study_year,
    now(),
    now()
  )
  ON CONFLICT (id) DO UPDATE SET
    email = excluded.email,
    full_name = excluded.full_name,
    medical_role = excluded.medical_role,
    faculty = excluded.faculty,
    study_year = excluded.study_year,
    updated_at = now();

  -- 2. Insert Free Trial Subscription (14 days)
  INSERT INTO public.subscriptions (
    user_id,
    tier,
    status,
    expires_at,
    created_at,
    updated_at
  )
  VALUES (
    new.id,
    'free',
    'active',
    now() + interval '14 days',
    now(),
    now()
  )
  ON CONFLICT (user_id) DO NOTHING;

  -- 3. In-App Welcome Notification for the new subscriber
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
    'welcome_user_' || new.id,
    new.id,
    '🎉 Bienvenue sur Medsina, ' || v_name || ' !',
    'Votre compte est activé avec votre Pass Découverte offert (14 jours d''accès gratuit). Explorez les 47 modules officiels, les fiches synthèses de révision, les banques de QCM et le mode hors-ligne !',
    'announcement',
    'user',
    false,
    jsonb_build_object(
      'type', 'welcome',
      'user_id', new.id,
      'full_name', v_name
    ),
    now()
  )
  ON CONFLICT (id) DO NOTHING;

  -- 4. Realtime Notification for Administrator
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
    'admin_new_user_' || new.id,
    null,
    '👤 Nouveau Membre Inscrit : ' || v_name,
    v_name || ' (' || new.email || ') vient de créer un compte Medsina (' || v_role || ' - ' || v_faculty || ').',
    'announcement',
    'admin',
    false,
    jsonb_build_object(
      'is_admin_only', true,
      'target_role', 'admin',
      'user_id', new.id,
      'email', new.email,
      'full_name', v_name,
      'medical_role', v_role,
      'faculty', v_faculty,
      'study_year', v_study_year
    ),
    now()
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ensure trigger exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
