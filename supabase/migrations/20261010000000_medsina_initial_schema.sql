-- =============================================================================
-- MEDSINA PLATFORM : INITIAL DATABASE SCHEMA & ROW LEVEL SECURITY (RLS)
-- Multiplatform Medical SaaS (Clinical Practice, Residency 2027, Practical Tools)
-- =============================================================================

-- Enable required extensions
create extension if not exists "uuid-ossp";

-- -----------------------------------------------------------------------------
-- 1. PROFILES & SAAS SUBSCRIPTIONS
-- -----------------------------------------------------------------------------

-- Public user profiles linked to Supabase Auth
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade primary key,
  email text not null,
  full_name text not null,
  medical_role text default 'Candidat Résidanat', -- Ex: Externe, Interne, Résident, Praticien
  faculty text default 'Faculté de Médecine de Blida',
  avatar_url text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- SaaS Subscriptions (Free, Clinical Pro, Resident Elite, All-Access VIP)
create table if not exists public.subscriptions (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade unique,
  tier text not null default 'free', -- 'free', 'clinical_pro', 'resident_elite', 'all_access'
  status text not null default 'active', -- 'active', 'expired', 'canceled'
  starts_at timestamptz default now(),
  expires_at timestamptz default (now() + interval '14 days'),
  max_devices int default 3,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Commercial License Keys (Activation Codes)
create table if not exists public.license_keys (
  key_code text primary key, -- Ex: 'MEDSINA-2027-VIP-XXXX'
  tier text not null default 'all_access',
  duration_days int not null default 365,
  is_redeemed boolean default false,
  redeemed_by uuid references public.profiles(id),
  redeemed_at timestamptz,
  created_at timestamptz default now()
);

-- -----------------------------------------------------------------------------
-- 2. FORMATION & RÉSIDANAT (47 Modules, Courses, Questions)
-- -----------------------------------------------------------------------------

-- Medical Modules (47 modules de spécialités)
create table if not exists public.medical_modules (
  id text primary key, -- Ex: 'cardio', 'pneumo', 'neuro'
  name text not null,
  category text not null, -- 'Médecine', 'Chirurgie', 'Biologie / Fondamental'
  icon_name text default 'medical',
  display_order int default 0,
  is_free_preview boolean default false, -- Modules d'essai gratuit
  created_at timestamptz default now()
);

-- Courses / Subcategories per Module
create table if not exists public.courses (
  id text primary key, -- Ex: 'cardio_hta', 'cardio_sca'
  module_id text references public.medical_modules(id) on delete cascade,
  name text not null,
  has_pdf boolean default false,
  pdf_storage_path text, -- Chemin dans Supabase Storage bucket 'course-documents'
  display_order int default 0,
  created_at timestamptz default now()
);

-- QCM Questions Bank
create table if not exists public.qcm_questions (
  id text primary key, -- Ex: 'q_001'
  course_id text references public.courses(id) on delete cascade,
  type text not null default 'qcm', -- 'qcs', 'qcm', 'cas_clinique', 'qroc'
  clinical_case text,
  question_text text not null,
  correct_answers jsonb not null default '[]'::jsonb, -- Ex: ["A", "C", "D"]
  explanation text not null,
  source text default 'Résidanat Blida',
  year int default 2024,
  created_at timestamptz default now()
);

-- Question Multiple Choices / Options (A, B, C, D, E)
create table if not exists public.qcm_options (
  id uuid default gen_random_uuid() primary key,
  question_id text references public.qcm_questions(id) on delete cascade,
  option_key text not null, -- 'A', 'B', 'C', 'D', 'E'
  option_text text not null,
  display_order int not null,
  unique(question_id, option_key)
);

-- User Revision Performance History
create table if not exists public.user_question_history (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade,
  question_id text references public.qcm_questions(id) on delete cascade,
  selected_answers jsonb not null default '[]'::jsonb,
  is_correct boolean not null,
  is_bookmarked boolean default false,
  notes text,
  answered_at timestamptz default now(),
  unique(user_id, question_id)
);

-- -----------------------------------------------------------------------------
-- 3. PRATIQUE CLINIQUE & PROTOCOLES D'URGENCE
-- -----------------------------------------------------------------------------

create table if not exists public.clinical_protocols (
  id text primary key, -- Ex: 'cat_sca_st_plus'
  title text not null,
  specialty text not null,
  urgency_level text not null, -- 'Urgence Vitale', 'Urgence Relative', 'Prise en charge réglée'
  definition text not null,
  red_flags jsonb not null default '[]'::jsonb,
  steps jsonb not null default '[]'::jsonb,
  treatments jsonb not null default '[]'::jsonb,
  scientific_references text,
  is_free_preview boolean default false,
  created_at timestamptz default now()
);

-- Reference Lab Values
create table if not exists public.lab_reference_values (
  id text primary key,
  name text not null,
  category text not null,
  normal_range text not null,
  unit text not null,
  high_interpretation text not null,
  low_interpretation text not null,
  clinical_notes jsonb not null default '[]'::jsonb
);

-- -----------------------------------------------------------------------------
-- 4. ROW LEVEL SECURITY (RLS) POLICIES
-- -----------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.subscriptions enable row level security;
alter table public.license_keys enable row level security;
alter table public.medical_modules enable row level security;
alter table public.courses enable row level security;
alter table public.qcm_questions enable row level security;
alter table public.qcm_options enable row level security;
alter table public.user_question_history enable row level security;
alter table public.clinical_protocols enable row level security;
alter table public.lab_reference_values enable row level security;

-- Function: Check user active subscription tier
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

  if user_tier = 'all_access' then
    return true;
  elsif user_tier = required_tier then
    return true;
  end if;

  return false;
end;
$$ language plpgsql security definer;

-- Profiles: users read and update their own profile
create policy "Users read own profile" on public.profiles
  for select using (auth.uid() = id);

create policy "Users update own profile" on public.profiles
  for update using (auth.uid() = id);

-- Subscriptions: users read their own subscription
create policy "Users read own subscription" on public.subscriptions
  for select using (auth.uid() = user_id);

-- Medical Modules: publicly readable metadata
create policy "Modules public read" on public.medical_modules
  for select using (true);

-- Courses: publicly readable course list
create policy "Courses public read" on public.courses
  for select using (true);

-- QCM Questions: gated by subscription tier or free preview
create policy "QCM questions tier access" on public.qcm_questions
  for select using (
    exists (
      select 1 from public.courses c
      join public.medical_modules m on m.id = c.module_id
      where c.id = qcm_questions.course_id
      and (m.is_free_preview = true or public.user_has_active_tier('resident_elite'))
    )
  );

-- QCM Options: accessible if question is accessible
create policy "QCM options access" on public.qcm_options
  for select using (
    exists (
      select 1 from public.qcm_questions q
      where q.id = qcm_options.question_id
    )
  );

-- Clinical Protocols: accessible if free preview or clinical_pro tier
create policy "Clinical protocols access" on public.clinical_protocols
  for select using (
    is_free_preview = true or public.user_has_active_tier('clinical_pro')
  );

-- Lab values: public reference
create policy "Lab values public read" on public.lab_reference_values
  for select using (true);

-- User history: user own access
create policy "User manages own history" on public.user_question_history
  for all using (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- 5. RPC FUNCTION: REDEEM LICENSE KEY
-- -----------------------------------------------------------------------------

create or replace function public.redeem_license_key(input_key text)
returns jsonb as $$
declare
  v_key record;
  v_duration int;
begin
  select * into v_key
  from public.license_keys
  where key_code = upper(trim(input_key))
  and is_redeemed = false;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Clé de licence invalide ou déjà utilisée.');
  end if;

  v_duration := v_key.duration_days;

  -- Update license key status
  update public.license_keys
  set is_redeemed = true,
      redeemed_by = auth.uid(),
      redeemed_at = now()
  where key_code = v_key.key_code;

  -- Upsert user subscription
  insert into public.subscriptions (user_id, tier, status, starts_at, expires_at)
  values (auth.uid(), v_key.tier, 'active', now(), now() + (v_duration || ' days')::interval)
  on conflict (user_id) do update
  set tier = v_key.tier,
      status = 'active',
      expires_at = greatest(public.subscriptions.expires_at, now()) + (v_duration || ' days')::interval,
      updated_at = now();

  return jsonb_build_object(
    'success', true,
    'tier', v_key.tier,
    'duration_days', v_duration,
    'message', 'Félicitations ! Votre licence Medsina a été activée avec succès.'
  );
end;
$$ language plpgsql security definer;

-- -----------------------------------------------------------------------------
-- 6. AUTOMATIC PROFILE CREATION TRIGGER
-- -----------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, full_name)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1))
  );

  insert into public.subscriptions (user_id, tier, status, expires_at)
  values (
    new.id,
    'free',
    'active',
    now() + interval '14 days' -- Essai gratuit automatique
  );

  return new;
end;
$$ language plpgsql security definer;

-- Trigger execution on auth.users insert
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
