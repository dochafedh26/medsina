-- ============================================================================
-- Medsina — Verrou de publication « Espace Prof / Enseignant HU »
-- ----------------------------------------------------------------------------
-- Objectif : la lecture des ressources enseignantes reste ouverte à tous,
-- mais la publication (cours, fiches, mindmaps, flashcards, QCM/QROC, examens)
-- est réservée aux enseignants dont le grade a été VÉRIFIÉ par l'administration.
--
-- Grades autorisés : Professeur, Maître de Conférences (MCA), Maître-Assistant,
-- Assistant HU et Résident (tous publient, cf. décision produit).
--
-- La vérification n'est pas auto-déclarée : `teacher_rank` / `teacher_verified`
-- ne peuvent être modifiés que par un administrateur (ou le service_role).
-- ============================================================================

-- 1. Grade académique vérifié sur le profil -----------------------------------
alter table public.profiles
  add column if not exists teacher_rank text;

alter table public.profiles
  add column if not exists teacher_verified boolean not null default false;

alter table public.profiles
  add column if not exists teacher_verified_at timestamptz;

alter table public.profiles
  add column if not exists teacher_verified_by uuid references auth.users(id) on delete set null;

do $$
begin
  alter table public.profiles
    add constraint profiles_teacher_rank_check
    check (teacher_rank is null or teacher_rank in ('resident', 'assistant', 'maitreAssistant', 'mca', 'professeur'));
exception
  when duplicate_object then null;
end $$;

-- 2. Helpers d'autorisation --------------------------------------------------
create or replace function public.current_teacher_rank()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select case
           when p.teacher_verified and p.teacher_rank is not null then p.teacher_rank
           else null
         end
  from public.profiles p
  where p.id = auth.uid();
$$;

create or replace function public.can_publish_teacher_content()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    public.current_teacher_rank() in ('resident', 'assistant', 'maitreAssistant', 'mca', 'professeur'),
    false
  );
$$;

-- 3. Empêche l'auto-promotion depuis le profil -------------------------------
--    (le client peut modifier son propre profil ; ce trigger neutralise toute
--    tentative de changement de grade/vérification par un non-administrateur).
create or replace function public.guard_teacher_verification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  jwt_role text;
  caller_is_admin boolean := false;
begin
  jwt_role := coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role', '');

  if jwt_role = 'service_role' then
    return new;
  end if;

  select coalesce(p.is_admin, false) into caller_is_admin
  from public.profiles p
  where p.id = auth.uid();

  if coalesce(caller_is_admin, false) then
    return new;
  end if;

  new.teacher_rank := old.teacher_rank;
  new.teacher_verified := old.teacher_verified;
  new.teacher_verified_at := old.teacher_verified_at;
  new.teacher_verified_by := old.teacher_verified_by;
  return new;
end;
$$;

drop trigger if exists trg_guard_teacher_verification on public.profiles;
create trigger trg_guard_teacher_verification
  before update on public.profiles
  for each row
  execute function public.guard_teacher_verification();

-- 4. Estampillage de l'auteur (grade + nom issus du profil vérifié) ---------
create or replace function public.stamp_teacher_authorship()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  p record;
begin
  select full_name, teacher_rank into p
  from public.profiles
  where id = auth.uid();

  new.author_id := auth.uid();
  if p.full_name is not null then
    new.author_name := p.full_name;
  end if;
  if p.teacher_rank is not null then
    new.academic_rank := p.teacher_rank;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_stamp_publication_author on public.teacher_publications;
create trigger trg_stamp_publication_author
  before insert or update on public.teacher_publications
  for each row
  execute function public.stamp_teacher_authorship();

drop trigger if exists trg_stamp_exam_author on public.teacher_exams;
create trigger trg_stamp_exam_author
  before insert or update on public.teacher_exams
  for each row
  execute function public.stamp_teacher_authorship();

-- 5. Politiques RLS : écriture réservée aux enseignants vérifiés -------------
-- Publications
drop policy if exists "Teachers manage own publications" on public.teacher_publications;

drop policy if exists "Verified teachers insert own publications" on public.teacher_publications;
create policy "Verified teachers insert own publications"
  on public.teacher_publications
  for insert
  with check (author_id = (select auth.uid()) and public.can_publish_teacher_content());

drop policy if exists "Authors update own publications" on public.teacher_publications;
create policy "Authors update own publications"
  on public.teacher_publications
  for update
  using (author_id = (select auth.uid()) and public.can_publish_teacher_content())
  with check (author_id = (select auth.uid()) and public.can_publish_teacher_content());

drop policy if exists "Authors delete own publications" on public.teacher_publications;
create policy "Authors delete own publications"
  on public.teacher_publications
  for delete
  using (author_id = (select auth.uid()) and public.can_publish_teacher_content());

-- Examens
drop policy if exists "Teachers manage own exams" on public.teacher_exams;

drop policy if exists "Verified teachers insert own exams" on public.teacher_exams;
create policy "Verified teachers insert own exams"
  on public.teacher_exams
  for insert
  with check (author_id = (select auth.uid()) and public.can_publish_teacher_content());

drop policy if exists "Authors update own exams" on public.teacher_exams;
create policy "Authors update own exams"
  on public.teacher_exams
  for update
  using (author_id = (select auth.uid()) and public.can_publish_teacher_content())
  with check (author_id = (select auth.uid()) and public.can_publish_teacher_content());

drop policy if exists "Authors delete own exams" on public.teacher_exams;
create policy "Authors delete own exams"
  on public.teacher_exams
  for delete
  using (author_id = (select auth.uid()) and public.can_publish_teacher_content());

-- 6. Lecture : inchangée (feed + examens publiés accessibles à tous) ----------

-- 7. Expose le grade vérifié dans la console d'administration ----------------
DROP FUNCTION IF EXISTS public.admin_list_users();

CREATE OR REPLACE FUNCTION public.admin_list_users()
RETURNS TABLE (
  id uuid,
  email text,
  full_name text,
  medical_role text,
  faculty text,
  tier text,
  status text,
  expires_at timestamptz,
  is_admin boolean,
  is_banned boolean,
  ban_reason text,
  rejected_payments_count integer,
  created_at timestamptz,
  study_year integer,
  bio text,
  phone text,
  wilaya text,
  residency_target_year text,
  avatar_url text,
  updated_at timestamptz,
  teacher_rank text,
  teacher_verified boolean
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id,
    p.email,
    p.full_name,
    p.medical_role,
    p.faculty,
    coalesce(s.tier, 'free') as tier,
    case
      when p.is_banned is true then 'suspended'
      when s.status is not null then s.status
      else 'active'
    end as status,
    s.expires_at,
    coalesce(p.is_admin, false) as is_admin,
    coalesce(p.is_banned, false) as is_banned,
    p.ban_reason,
    coalesce(p.rejected_payments_count, 0) as rejected_payments_count,
    p.created_at,
    p.study_year,
    p.bio,
    p.phone,
    p.wilaya,
    p.residency_target_year,
    p.avatar_url,
    p.updated_at,
    p.teacher_rank,
    coalesce(p.teacher_verified, false) as teacher_verified
  FROM public.profiles p
  LEFT JOIN public.subscriptions s ON s.user_id = p.id
  ORDER BY p.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

