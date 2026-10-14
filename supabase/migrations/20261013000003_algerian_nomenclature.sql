-- =============================================================================
-- MEDSINA PLATFORM : ALGERIAN OFFICIAL NOMENCLATURE PHARMACOPOEIA (MSPRH)
-- =============================================================================

create table if not exists public.algerian_nomenclature (
  id bigint primary key,
  num int,
  reg_num text,
  code text not null,
  dci text not null,
  brand_name text not null,
  form text,
  dosage text,
  packaging text,
  liste text,
  laboratory text,
  country text,
  type text,
  status text,
  is_hospital_only boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Row Level Security
alter table public.algerian_nomenclature enable row level security;

-- Policy: Everyone can read the official nomenclature
drop policy if exists "Public read algerian_nomenclature" on public.algerian_nomenclature;
create policy "Public read algerian_nomenclature" on public.algerian_nomenclature
  for select using (true);

-- Policy: Service role & admin can manage nomenclature
drop policy if exists "Admin manage algerian_nomenclature" on public.algerian_nomenclature;
create policy "Admin manage algerian_nomenclature" on public.algerian_nomenclature
  for all using (
    auth.jwt() ->> 'role' = 'service_role' 
    or exists (select 1 from public.profiles where id = auth.uid() and is_admin = true)
  );

-- Indexes for rapid search
create index if not exists idx_nomenclature_brand on public.algerian_nomenclature (brand_name);
create index if not exists idx_nomenclature_dci on public.algerian_nomenclature (dci);
create index if not exists idx_nomenclature_code on public.algerian_nomenclature (code);

