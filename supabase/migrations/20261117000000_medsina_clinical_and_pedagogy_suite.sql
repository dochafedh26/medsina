-- Medsina Clinical, Pedagogy & Teacher Workspace Suite (v1.0.96)
-- Includes: Procedure Logbook, Custom Mnemonics, QCM 1v1 Duels, Teacher Publications & Hybrid Exams (QCM + QROC)

-- 1. User Clinical Procedure Logbook
create table if not exists public.user_procedure_logs (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  procedure_id text not null,
  procedure_title text not null,
  hospital_service text not null default 'Urgences / Garde',
  autonomy_level text not null default 'observed', -- 'observed', 'assisted', 'autonomous'
  notes text,
  performed_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists idx_user_procedure_logs_user_id
  on public.user_procedure_logs (user_id, performed_at desc);

alter table public.user_procedure_logs enable row level security;

create policy "Users manage own procedure logs"
  on public.user_procedure_logs
  for all
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- 2. User & Community Mnemonics and Exam Reflex Associations
create table if not exists public.user_custom_mnemonics (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  author_name text not null default 'Confrère Medsina',
  module_name text not null,
  item_type text not null default 'mnemonic', -- 'mnemonic' or 'reflex'
  title_or_keyword text not null,
  content_or_diagnosis text not null,
  explanation_or_trap text,
  is_shared boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists idx_user_custom_mnemonics_module
  on public.user_custom_mnemonics (module_name, created_at desc);

create index if not exists idx_user_custom_mnemonics_user_id
  on public.user_custom_mnemonics (user_id);

alter table public.user_custom_mnemonics enable row level security;

create policy "Anyone authenticated can read shared mnemonics"
  on public.user_custom_mnemonics
  for select
  using (is_shared = true or (select auth.uid()) = user_id);

create policy "Users manage own custom mnemonics"
  on public.user_custom_mnemonics
  for all
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- 3. QCM 1v1 Duels & Fast Challenges
create table if not exists public.qcm_duel_matches (
  id text primary key,
  challenge_code text not null unique,
  module_name text not null,
  creator_id uuid references auth.users(id) on delete set null,
  creator_name text not null,
  creator_score integer not null default 0,
  creator_time_seconds integer not null default 0,
  opponent_id uuid references auth.users(id) on delete set null,
  opponent_name text,
  opponent_score integer,
  opponent_time_seconds integer,
  question_ids jsonb not null default '[]'::jsonb,
  total_questions integer not null default 5,
  status text not null default 'open', -- 'open', 'completed'
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_qcm_duel_matches_code
  on public.qcm_duel_matches (challenge_code);

alter table public.qcm_duel_matches enable row level security;

create policy "Authenticated users can view duels"
  on public.qcm_duel_matches
  for select
  using ((select auth.role()) = 'authenticated');

create policy "Authenticated users can create or join duels"
  on public.qcm_duel_matches
  for insert
  with check ((select auth.role()) = 'authenticated');

create policy "Authenticated users can update duel scores"
  on public.qcm_duel_matches
  for update
  using ((select auth.role()) = 'authenticated');

-- 4. Teacher / Academic Publications (Courses, Summaries, Mindmaps, Flashcards, QCMs)
create table if not exists public.teacher_publications (
  id text primary key,
  author_id uuid references auth.users(id) on delete set null,
  author_name text not null,
  academic_rank text not null, -- 'Résident', 'Assistant', 'Maître-Assistant', 'MCA', 'Professeur'
  specialty text not null,
  faculty text not null default 'Blida',
  target_audience text not null default 'Residanat & Externat',
  content_type text not null, -- 'course', 'summary', 'mindmap', 'flashcards', 'qcmBank'
  title text not null,
  summary_description text not null,
  markdown_body text not null default '',
  attachment_url text,
  structured_payload jsonb not null default '{}'::jsonb,
  views_count integer not null default 0,
  likes_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_teacher_publications_specialty
  on public.teacher_publications (specialty, content_type, created_at desc);

alter table public.teacher_publications enable row level security;

create policy "Anyone can read teacher publications"
  on public.teacher_publications
  for select
  using (true);

create policy "Teachers manage own publications"
  on public.teacher_publications
  for all
  using ((select auth.uid()) = author_id)
  with check ((select auth.uid()) = author_id);

-- 5. Teacher Hybrid Exams (EMD Externat & Concours Résidanat with Medsina QCMs + Custom QCM/QROC)
create table if not exists public.teacher_exams (
  id text primary key,
  access_code text not null unique,
  author_id uuid references auth.users(id) on delete set null,
  author_name text not null,
  academic_rank text not null,
  specialty text not null,
  faculty text not null default 'Blida',
  exam_category text not null default 'emd_externat', -- 'emd_externat', 'concours_residanat', 'stage_evaluation'
  study_year integer,
  title text not null,
  description text not null default '',
  duration_minutes integer not null default 45,
  scoring_mode text not null default 'partial', -- 'allOrNothing', 'partial', 'negative'
  medsina_question_ids jsonb not null default '[]'::jsonb,
  custom_questions jsonb not null default '[]'::jsonb,
  is_published boolean not null default true,
  participants_count integer not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_teacher_exams_specialty
  on public.teacher_exams (specialty, exam_category, created_at desc);

alter table public.teacher_exams enable row level security;

create policy "Anyone can read published teacher exams"
  on public.teacher_exams
  for select
  using (is_published = true or (select auth.uid()) = author_id);

create policy "Teachers manage own exams"
  on public.teacher_exams
  for all
  using ((select auth.uid()) = author_id)
  with check ((select auth.uid()) = author_id);

create table if not exists public.teacher_exam_submissions (
  id text primary key,
  exam_id text not null references public.teacher_exams(id) on delete cascade,
  student_id uuid references auth.users(id) on delete cascade,
  student_name text not null,
  score_out_of_20 numeric(5,2) not null default 0,
  correct_count integer not null default 0,
  total_questions integer not null default 0,
  duration_seconds integer not null default 0,
  answers_payload jsonb not null default '{}'::jsonb,
  submitted_at timestamptz not null default now()
);

create index if not exists idx_teacher_exam_submissions_exam
  on public.teacher_exam_submissions (exam_id, score_out_of_20 desc);

alter table public.teacher_exam_submissions enable row level security;

create policy "Authenticated users can view and submit exam results"
  on public.teacher_exam_submissions
  for all
  using ((select auth.role()) = 'authenticated')
  with check ((select auth.role()) = 'authenticated');
