-- =============================================================================
-- Migration: Booklet Admin Human Validation & Mindmap Inclusion
-- Date: 2026-11-12
-- Description:
-- 1. Ensures booklet metadata columns exist on public.courses.
-- 2. Adds human-in-the-loop validation columns:
--    - bundle_validation_status ('pending_review', 'changes_requested', 'approved', 'rejected')
--    - bundle_admin_notes (suggested modifications by Admin)
--    - bundle_reviewed_at / bundle_reviewed_by
--    - bundle_has_mindmap
-- 3. Adds partial index for fast filtering of generated booklets by status.
-- 4. Adds Admin UPDATE RLS policy on public.courses.
-- =============================================================================

alter table if exists public.courses
  add column if not exists bundle_pdf_url text,
  add column if not exists bundle_generated_at timestamptz,
  add column if not exists is_hypertombable boolean default false,
  add column if not exists residanat_years jsonb default '[]'::jsonb,
  add column if not exists qcm_count int default 0,
  add column if not exists bundle_validation_status text not null default 'pending_review',
  add column if not exists bundle_admin_notes text,
  add column if not exists bundle_reviewed_at timestamptz,
  add column if not exists bundle_reviewed_by uuid references auth.users(id) on delete set null,
  add column if not exists bundle_has_mindmap boolean not null default false;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'courses_bundle_validation_status_check'
      and conrelid = 'public.courses'::regclass
  ) then
    alter table public.courses
      add constraint courses_bundle_validation_status_check
      check (bundle_validation_status in ('pending_review', 'changes_requested', 'approved', 'rejected'));
  end if;
end $$;

create index if not exists idx_courses_bundle_validation_status
  on public.courses (bundle_validation_status)
  where bundle_pdf_url is not null;

drop policy if exists "Admins can update courses" on public.courses;
create policy "Admins can update courses"
  on public.courses
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.profiles p
      where p.id = (select auth.uid())
        and p.is_admin = true
    )
  )
  with check (
    exists (
      select 1
      from public.profiles p
      where p.id = (select auth.uid())
        and p.is_admin = true
    )
  );
