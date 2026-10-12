-- =============================================================================
-- MEDSINA PLATFORM : DAILY PEARLS & CLINICAL PROTOCOLS AUTOMATION SCHEMA
-- =============================================================================

-- 1. Ensure clinical_protocols has course_id linkage and guidelines_year
do $$
begin
  if not exists (
    select 1 from information_schema.columns 
    where table_schema = 'public' and table_name = 'clinical_protocols' and column_name = 'course_id'
  ) then
    alter table public.clinical_protocols add column course_id text references public.courses(id) on delete set null;
  end if;

  if not exists (
    select 1 from information_schema.columns 
    where table_schema = 'public' and table_name = 'clinical_protocols' and column_name = 'guidelines_year'
  ) then
    alter table public.clinical_protocols add column guidelines_year int default 2024;
  end if;
end $$;

-- 2. Daily Clinical Pearls & Residency Traps table
create table if not exists public.daily_pearls (
  id uuid default gen_random_uuid() primary key,
  course_id text references public.courses(id) on delete set null,
  module_id text references public.medical_modules(id) on delete set null,
  module_name text not null,
  course_name text not null,
  title text not null,
  pearl_text text not null,
  vital_rule text,
  exam_trap text,
  scientific_sources text,
  is_active boolean default true,
  created_at timestamptz default now()
);

-- Enable RLS on daily_pearls
alter table public.daily_pearls enable row level security;

-- Policy: Everyone can read active daily pearls
create policy "Daily pearls public read" on public.daily_pearls
  for select using (true);

-- Index on created_at for fast retrieval of latest daily pearl
create index if not exists idx_daily_pearls_created_at on public.daily_pearls (created_at desc);
create index if not exists idx_clinical_protocols_course_id on public.clinical_protocols (course_id);

