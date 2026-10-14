-- =============================================================================
-- MEDSINA PLATFORM : VIDAL DRUG-DRUG INTERACTIONS KNOWLEDGEBASE (IAM)
-- Auto-learning pharmacopoeia table enriched on-the-fly from Vidal API audits.
-- =============================================================================

create table if not exists public.vidal_drug_interactions (
  id uuid primary key default gen_random_uuid(),
  drug_a jsonb not null default '[]'::jsonb,
  drug_b jsonb not null default '[]'::jsonb,
  severity text not null, -- 'contraindicated', 'disadvised', 'precaution', 'info'
  severity_level int not null default 1,
  title text not null,
  description text,
  recommendation text,
  source text default 'vidal_official',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Row Level Security
alter table public.vidal_drug_interactions enable row level security;

-- Policy 1: Everyone (authenticated & anon) can read interaction rules
drop policy if exists "Public read vidal_drug_interactions" on public.vidal_drug_interactions;
create policy "Public read vidal_drug_interactions" on public.vidal_drug_interactions
  for select using (true);

-- Policy 2: Allow inserts (auto-enrichment from app / service / backend)
drop policy if exists "Enable insert for vidal_drug_interactions" on public.vidal_drug_interactions;
create policy "Enable insert for vidal_drug_interactions" on public.vidal_drug_interactions
  for insert with check (true);

-- Policy 3: Updates by admin / service
drop policy if exists "Enable update for vidal_drug_interactions" on public.vidal_drug_interactions;
create policy "Enable update for vidal_drug_interactions" on public.vidal_drug_interactions
  for update using (true);

-- Indexes for performance
create index if not exists idx_vidal_title on public.vidal_drug_interactions (title);
create index if not exists idx_vidal_severity on public.vidal_drug_interactions (severity);
create index if not exists idx_vidal_drug_a on public.vidal_drug_interactions using gin (drug_a);
create index if not exists idx_vidal_drug_b on public.vidal_drug_interactions using gin (drug_b);

