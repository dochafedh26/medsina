-- ============================================================================
-- Migration: 20261024000022_etudiant_track_and_subscription.sql
-- Description: Intégration du Track Étudiant (1ère à 6ème année) et du Pass Étudiant
-- ============================================================================

-- 1. Ajout de la colonne study_year sur profiles
alter table public.profiles 
add column if not exists study_year integer check (study_year between 1 and 6);

comment on column public.profiles.study_year is 'Année d''étude universitaire en médecine de l''étudiant (1: 1ère, ..., 6: 6ème)';

-- 2. Mise à jour de la fonction user_has_active_tier pour supporter le tier 'etudiant'
create or replace function public.user_has_active_tier(required_tier text)
returns boolean as $$
declare
  user_tier text;
  is_active boolean;
begin
  select tier, (expires_at > now() and status = 'active')
  into user_tier, is_active
  from public.subscriptions
  where user_id = auth.uid();

  if not is_active then
    return false;
  end if;

  -- Le pass all_access débloque tout
  if user_tier = 'all_access' then
    return true;
  end if;

  -- Correspondance exacte du tier
  if user_tier = required_tier then
    return true;
  end if;

  -- Le Pass Résident Élite donne également accès aux contenus fondamentaux / étudiants
  if required_tier = 'etudiant' and user_tier in ('resident_elite', 'all_access') then
    return true;
  end if;

  return false;
end;
$$ language plpgsql security definer;

-- 3. Mise à jour du trigger handle_new_user pour enregistrer study_year si fourni dans raw_user_meta_data
create or replace function public.handle_new_user()
returns trigger as $$
declare
  meta_role text;
  meta_faculty text;
  meta_year int;
begin
  meta_role := coalesce(new.raw_user_meta_data->>'medical_role', 'Candidat Résidanat');
  meta_faculty := coalesce(new.raw_user_meta_data->>'faculty', 'Faculté de Médecine de Blida');
  meta_year := (new.raw_user_meta_data->>'study_year')::integer;

  insert into public.profiles (id, email, full_name, medical_role, faculty, study_year)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    meta_role,
    meta_faculty,
    meta_year
  )
  on conflict (id) do update set
    medical_role = excluded.medical_role,
    faculty = excluded.faculty,
    study_year = coalesce(excluded.study_year, profiles.study_year);

  insert into public.subscriptions (user_id, tier, status, expires_at)
  values (
    new.id,
    'free',
    'active',
    now() + interval '14 days'
  )
  on conflict (user_id) do nothing;

  return new;
end;
$$ language plpgsql security definer;
