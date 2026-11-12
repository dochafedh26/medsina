-- Migration: 20261112000000_secure_qcm_access.sql
-- Objectif : Servir les 19 305 QCMs depuis Supabase Cloud avec contrôle d'accès strict (RLS),
--            au lieu de les embarquer dans l'APK Flutter (assets/data/qcms/*.json).
--
-- Règles d'accès implémentées selon les directives de l'administrateur Medsina :
--  1. Administrateurs : Accès complet à l'ensemble des QCMs.
--  2. Abonnés "Résident Élite" et "All Access" : Accès complet (Années 1 à 6 et Résidanat).
--  3. Abonnés "Étudiant" :
--     - Accès exclusif aux QCMs de leur année d'étude actuelle (p.study_year = qcm.study_year).
--     - Si abonnement 2 ans (pass 2 ans / durée >= 700 jours) : accès à l'année actuelle ET à l'année suivante (p.study_year + 1).
--  4. Pass Découverte (Gratuit) :
--     - Échantillon gratuit (is_free_sample = true : 2 premiers cours de chaque module)
--       uniquement sur les 2 modules choisis par l'utilisateur (user_trial_quotas.selected_free_modules).

-- 1) Colonnes : options en jsonb, module_id, course_name, study_year et is_free_sample
alter table public.qcm_questions
  add column if not exists module_id text,
  add column if not exists course_name text,
  add column if not exists study_year smallint default 7,
  add column if not exists options jsonb not null default '[]'::jsonb,
  add column if not exists is_free_sample boolean not null default false;

-- Supprimer la contrainte restrictive de clé étrangère sur courses (permet d'indexer les 19 305 QCMs officiels)
alter table public.qcm_questions
  drop constraint if exists qcm_questions_course_id_fkey;

-- Index de performance critiques pour les requêtes courantes
create index if not exists idx_qcm_questions_course on public.qcm_questions(course_id);
create index if not exists idx_qcm_questions_module on public.qcm_questions(module_id);
create index if not exists idx_qcm_questions_study_year on public.qcm_questions(study_year);
create index if not exists idx_qcm_questions_free_sample on public.qcm_questions(is_free_sample) where is_free_sample = true;

-- 2) Fonction de vérification des droits d'accès QCM (SECURITY DEFINER)
create or replace function public.can_user_access_qcm(
  p_study_year smallint,
  p_module_id text,
  p_is_free_sample boolean
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    -- 1. Admin : accès illimité complet
    coalesce((select p.is_admin from public.profiles p where p.id = auth.uid()), false)
    
    -- 2. Formules "Résident Élite" et "All Access" : accès complet à toutes les années
    or exists (
      select 1
      from public.subscriptions s
      where s.user_id = auth.uid()
        and s.status = 'active'
        and s.expires_at > now()
        and s.tier in ('resident_elite', 'all_access')
    )
    
    -- 3. Formule "Étudiant" : accès à son année d'étude (+ année suivante si abonnement 2 ans)
    or exists (
      select 1
      from public.subscriptions s
      join public.profiles p on p.id = s.user_id
      where s.user_id = auth.uid()
        and s.status = 'active'
        and s.expires_at > now()
        and s.tier = 'etudiant'
        and (
          -- Année d'étude principale de l'étudiant
          (p.study_year is not null and p.study_year = p_study_year)
          -- Si Pass 2 Ans : accès également à l'année n+1 (ex: 3ème + 4ème)
          or (
            (coalesce(s.duration, '') ilike '%two%' or (s.expires_at - s.starts_at) >= interval '700 days')
            and p.study_year is not null
            and (p.study_year + 1) = p_study_year
          )
        )
    )
    
    -- 4. Échantillon gratuit Pass Découverte : les 2 premiers cours des modules choisis
    or (
      p_is_free_sample
      and exists (
        select 1
        from public.user_trial_quotas t
        where t.user_id = auth.uid()
          and p_module_id = any (t.selected_free_modules)
      )
    );
$$;

revoke all on function public.can_user_access_qcm(smallint, text, boolean) from public, anon;
grant execute on function public.can_user_access_qcm(smallint, text, boolean) to authenticated;

-- 3) Mise en place de la politique RLS stricte
alter table public.qcm_questions enable row level security;

drop policy if exists "QCM questions tier access" on public.qcm_questions;
drop policy if exists "qcm_select_entitled" on public.qcm_questions;

create policy "qcm_select_entitled" on public.qcm_questions
  for select
  to authenticated
  using (
    public.can_user_access_qcm(qcm_questions.study_year, qcm_questions.module_id, qcm_questions.is_free_sample)
  );

-- Interdire tout accès anonyme et verrouiller les écritures depuis le client mobile
revoke all on public.qcm_questions from anon;
revoke insert, update, delete on public.qcm_questions from authenticated;
