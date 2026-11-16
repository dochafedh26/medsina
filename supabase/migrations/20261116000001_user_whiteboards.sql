-- User-created study whiteboards and mindmaps with cloud sync
create table if not exists public.user_whiteboards (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  course_id text,
  module_name text,
  title text not null default 'Nouveau Whiteboard',
  board_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_user_whiteboards_user_id
  on public.user_whiteboards (user_id, updated_at desc);

create index if not exists idx_user_whiteboards_course_id
  on public.user_whiteboards (user_id, course_id)
  where course_id is not null;

alter table public.user_whiteboards enable row level security;

create policy "Users can view own whiteboards"
  on public.user_whiteboards
  for select
  using (auth.uid() = user_id);

create policy "Users can insert own whiteboards"
  on public.user_whiteboards
  for insert
  with check (auth.uid() = user_id);

create policy "Users can update own whiteboards"
  on public.user_whiteboards
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can delete own whiteboards"
  on public.user_whiteboards
  for delete
  using (auth.uid() = user_id);
