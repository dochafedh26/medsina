-- =============================================================================
-- Migration: Add Mind Map Support & Google Drive Storage Integration
-- Date: 2026-11-11
-- Description:
-- 1. Adds mindmap fields to public.courses (mindmap_pdf_url, mindmap_drive_id,
--    mindmap_generated_at, has_mindmap).
-- 2. Creates public.course_mindmaps table for rich hierarchical tree data.
-- 3. Configures RLS policies for seamless read access and automated scripts.
-- =============================================================================

-- 1. Add Mindmap columns to public.courses
alter table if exists public.courses 
  add column if not exists mindmap_pdf_url text,
  add column if not exists mindmap_drive_id text,
  add column if not exists mindmap_generated_at timestamptz,
  add column if not exists has_mindmap boolean default false;

create index if not exists idx_courses_has_mindmap on public.courses(has_mindmap);

-- 2. Dedicated Table for Mind Map Data & Interactive Branch Nodes
create table if not exists public.course_mindmaps (
  course_id text primary key references public.courses(id) on delete cascade,
  course_name text not null,
  module_id text references public.medical_modules(id) on delete cascade,
  module_name text,
  diagnostic_criteria text,
  treatment_summary text,
  branches jsonb not null default '[]'::jsonb,
  pdf_file text,
  mindmap_drive_id text,
  mindmap_pdf_url text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Indexes for performance
create index if not exists idx_course_mindmaps_module on public.course_mindmaps(module_id);
create index if not exists idx_course_mindmaps_drive_id on public.course_mindmaps(mindmap_drive_id);

-- Enable RLS
alter table public.course_mindmaps enable row level security;

-- Public read access policy
drop policy if exists "Allow public read access on course_mindmaps" on public.course_mindmaps;
create policy "Allow public read access on course_mindmaps"
  on public.course_mindmaps for select
  using (true);

-- Authenticated and Service Role full access
drop policy if exists "Allow service role management on course_mindmaps" on public.course_mindmaps;
create policy "Allow service role management on course_mindmaps"
  on public.course_mindmaps for all
  using (auth.role() in ('authenticated', 'service_role'));
