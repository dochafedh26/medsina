-- =============================================================================
-- MEDSINA PLATFORM : VIDAL PATIENT TERRAIN & ORGAN CONTRAINDICATIONS
-- Auto-learning pharmacopoeia table for organ risks & physiological states
-- (Hépatologie, Néphrologie, Cardiologie, Pneumologie, Obstétrique, etc.)
-- =============================================================================

create table if not exists public.vidal_terrain_contraindications (
  id uuid primary key default gen_random_uuid(),
  terrain text not null,
  terrain_normalized text not null,
  drug_class text not null,
  drug_patterns jsonb not null default '[]'::jsonb,
  severity text not null, -- 'contraindicated', 'disadvised', 'precaution', 'info'
  severity_level int not null default 1,
  title text not null,
  warning text not null,
  recommendation text not null default '',
  source text default 'Vidal / ANSM / MSPRH',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Row Level Security
alter table public.vidal_terrain_contraindications enable row level security;

-- Policy 1: Everyone (authenticated & anon) can read terrain rules
drop policy if exists "Public read vidal_terrain_contraindications" on public.vidal_terrain_contraindications;
create policy "Public read vidal_terrain_contraindications" on public.vidal_terrain_contraindications
  for select using (true);

-- Policy 2: Allow inserts (auto-enrichment from app / service / backend)
drop policy if exists "Enable insert for vidal_terrain_contraindications" on public.vidal_terrain_contraindications;
create policy "Enable insert for vidal_terrain_contraindications" on public.vidal_terrain_contraindications
  for insert with check (true);

-- Policy 3: Updates by admin / service
drop policy if exists "Enable update for vidal_terrain_contraindications" on public.vidal_terrain_contraindications;
create policy "Enable update for vidal_terrain_contraindications" on public.vidal_terrain_contraindications
  for update using (true);

-- Indexes for lightning fast queries
create index if not exists idx_vidal_terrain_name on public.vidal_terrain_contraindications (terrain);
create index if not exists idx_vidal_terrain_norm on public.vidal_terrain_contraindications (terrain_normalized);
create index if not exists idx_vidal_terrain_severity on public.vidal_terrain_contraindications (severity);
create index if not exists idx_vidal_terrain_patterns on public.vidal_terrain_contraindications using gin (drug_patterns);

