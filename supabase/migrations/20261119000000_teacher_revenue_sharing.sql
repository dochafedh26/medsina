-- ============================================================================
-- Medsina — Partage de revenus « Espace Prof » (65 % auteurs / 35 % plateforme)
-- ----------------------------------------------------------------------------
-- Principe : chaque abonnement payant du mois est réparti sur les ressources
-- réellement consommées (attribution « user-centric »), puis 65 % du pool net
-- revient aux auteurs au prorata de leurs unités d'usage.
--
-- Garde-fous :
--  * auto-consommation exclue (un auteur ne se paie pas lui-même)
--  * 1 vue de publication / utilisateur / 24 h ; 1 passage d'examen / utilisateur
--  * une ressource doit avoir >= min_unique_readers lecteurs distincts pour être
--    éligible
--  * aucun auteur ne peut dépasser max_author_pool_pct du pool mensuel
--  * les demandes de retrait sont plafonnées par le solde disponible
-- ============================================================================

-- 1. Helper admin ------------------------------------------------------------
create or replace function public.is_medsina_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role' = 'service_role',
    false
  ) or exists (
    select 1 from public.profiles p where p.id = auth.uid() and p.is_admin
  );
$$;

-- 2. Paramètres de répartition (ligne unique) --------------------------------
create table if not exists public.teacher_revenue_settings (
  id boolean primary key default true check (id),
  author_share_pct numeric not null default 65 check (author_share_pct between 0 and 100),
  min_unique_readers integer not null default 10,
  max_author_pool_pct numeric not null default 20,
  min_authors_for_cap integer not null default 5,
  min_payout_amount numeric not null default 3000,
  holdback_days integer not null default 30,
  store_fee_pct numeric not null default 15,
  is_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

insert into public.teacher_revenue_settings (id) values (true)
on conflict (id) do nothing;

-- Colonne ajoutée après coup (idempotent)
alter table public.teacher_revenue_settings
  add column if not exists min_authors_for_cap integer not null default 5;

alter table public.teacher_revenue_settings enable row level security;

drop policy if exists "Authenticated users read revenue settings" on public.teacher_revenue_settings;
create policy "Authenticated users read revenue settings"
  on public.teacher_revenue_settings
  for select
  using ((select auth.role()) = 'authenticated');

drop policy if exists "Admins manage revenue settings" on public.teacher_revenue_settings;
create policy "Admins manage revenue settings"
  on public.teacher_revenue_settings
  for all
  using (public.is_medsina_admin())
  with check (public.is_medsina_admin());

-- 3. Événements de consommation ---------------------------------------------
create table if not exists public.teacher_content_events (
  id bigserial primary key,
  content_type text not null check (content_type in ('publication', 'exam')),
  content_id text not null,
  author_id uuid not null references public.profiles(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  units numeric not null default 1 check (units > 0 and units <= 10),
  period_month date not null default (date_trunc('month', now()))::date,
  metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);

create index if not exists idx_teacher_events_period_author
  on public.teacher_content_events (period_month, author_id);

create index if not exists idx_teacher_events_content
  on public.teacher_content_events (content_type, content_id, period_month);

create index if not exists idx_teacher_events_user_content
  on public.teacher_content_events (user_id, content_type, content_id, occurred_at desc);

alter table public.teacher_content_events enable row level security;

drop policy if exists "Authors read own consumption events" on public.teacher_content_events;
create policy "Authors read own consumption events"
  on public.teacher_content_events
  for select
  using (author_id = (select auth.uid()) or public.is_medsina_admin());

-- Aucune policy INSERT : l'écriture passe uniquement par la fonction RPC
-- record_teacher_consumption() (validation + anti-fraude).

create or replace function public.record_teacher_consumption(
  p_content_type text,
  p_content_id text,
  p_units numeric default 1
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_author uuid;
  v_units numeric := least(greatest(coalesce(p_units, 1), 0.25), 10);
  v_already bigint;
begin
  if v_uid is null or p_content_id is null then
    return false;
  end if;

  if p_content_type = 'publication' then
    select author_id into v_author from public.teacher_publications where id = p_content_id;

    select count(*) into v_already
    from public.teacher_content_events
    where user_id = v_uid
      and content_type = 'publication'
      and content_id = p_content_id
      and occurred_at > now() - interval '1 day';

    if v_already > 0 then
      return false;
    end if;

    v_units := least(v_units, 3);
  elsif p_content_type = 'exam' then
    select author_id into v_author from public.teacher_exams where id = p_content_id;

    select count(*) into v_already
    from public.teacher_content_events
    where user_id = v_uid
      and content_type = 'exam'
      and content_id = p_content_id;

    if v_already > 0 then
      return false;
    end if;

    v_units := least(v_units, 5);
  else
    return false;
  end if;

  -- Auto-consommation interdite : un auteur ne peut pas s'attribuer son propre revenu.
  if v_author is null or v_author = v_uid then
    return false;
  end if;

  insert into public.teacher_content_events (
    content_type, content_id, author_id, user_id, units, period_month
  ) values (
    p_content_type, p_content_id, v_author, v_uid, v_units, (date_trunc('month', now()))::date
  );

  return true;
end;
$$;

-- 4. Clôtures mensuelles -----------------------------------------------------
create table if not exists public.teacher_revenue_periods (
  id uuid primary key default gen_random_uuid(),
  period_month date not null unique,
  gross_revenue numeric not null default 0,
  net_revenue numeric not null default 0,
  author_share_pct numeric not null default 65,
  author_pool numeric not null default 0,
  platform_share numeric not null default 0,
  eligible_units numeric not null default 0,
  status text not null default 'closed' check (status in ('draft', 'closed', 'paid')),
  details jsonb not null default '{}'::jsonb,
  computed_at timestamptz not null default now(),
  computed_by uuid
);

alter table public.teacher_revenue_periods enable row level security;

drop policy if exists "Authenticated users read revenue periods" on public.teacher_revenue_periods;
create policy "Authenticated users read revenue periods"
  on public.teacher_revenue_periods
  for select
  using ((select auth.role()) = 'authenticated');

drop policy if exists "Admins manage revenue periods" on public.teacher_revenue_periods;
create policy "Admins manage revenue periods"
  on public.teacher_revenue_periods
  for all
  using (public.is_medsina_admin())
  with check (public.is_medsina_admin());

create table if not exists public.teacher_earnings_ledger (
  id uuid primary key default gen_random_uuid(),
  period_month date not null,
  author_id uuid not null references public.profiles(id) on delete cascade,
  attributed_units numeric not null default 0,
  gross_attributed numeric not null default 0,
  author_earnings numeric not null default 0,
  capped_remainder numeric not null default 0,
  status text not null default 'accrued' check (status in ('accrued', 'available', 'clawed_back')),
  available_at timestamptz,
  created_at timestamptz not null default now(),
  constraint teacher_earnings_period_fk
    foreign key (period_month) references public.teacher_revenue_periods(period_month) on delete cascade,
  unique (period_month, author_id)
);

create index if not exists idx_teacher_ledger_author
  on public.teacher_earnings_ledger (author_id, period_month desc);

alter table public.teacher_earnings_ledger enable row level security;

drop policy if exists "Authors read own earnings" on public.teacher_earnings_ledger;
create policy "Authors read own earnings"
  on public.teacher_earnings_ledger
  for select
  using (author_id = (select auth.uid()) or public.is_medsina_admin());

drop policy if exists "Admins manage earnings" on public.teacher_earnings_ledger;
create policy "Admins manage earnings"
  on public.teacher_earnings_ledger
  for all
  using (public.is_medsina_admin())
  with check (public.is_medsina_admin());

-- 5. Demandes de retrait -----------------------------------------------------
create table if not exists public.teacher_payout_requests (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  amount numeric not null check (amount > 0),
  currency text not null default 'DZD',
  method text not null check (method in ('ccp', 'baridimob', 'virement')),
  account_holder text not null,
  account_details text not null,
  status text not null default 'requested' check (status in ('requested', 'approved', 'paid', 'rejected', 'cancelled')),
  admin_note text,
  reviewed_by uuid references public.profiles(id) on delete set null,
  requested_at timestamptz not null default now(),
  reviewed_at timestamptz,
  paid_at timestamptz,
  proof_url text
);

create index if not exists idx_teacher_payouts_author
  on public.teacher_payout_requests (author_id, requested_at desc);

create index if not exists idx_teacher_payouts_status
  on public.teacher_payout_requests (status);

alter table public.teacher_payout_requests enable row level security;

drop policy if exists "Authors read own payout requests" on public.teacher_payout_requests;
create policy "Authors read own payout requests"
  on public.teacher_payout_requests
  for select
  using (author_id = (select auth.uid()) or public.is_medsina_admin());

drop policy if exists "Admins manage payout requests" on public.teacher_payout_requests;
create policy "Admins manage payout requests"
  on public.teacher_payout_requests
  for update
  using (public.is_medsina_admin())
  with check (public.is_medsina_admin());

-- 6. Solde disponible --------------------------------------------------------
create or replace function public.teacher_available_balance(p_author uuid default null)
returns numeric
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_author uuid := coalesce(p_author, auth.uid());
  v_earned numeric;
  v_reserved numeric;
begin
  if v_author is null then
    return 0;
  end if;

  if p_author is not null and p_author <> auth.uid() and not public.is_medsina_admin() then
    raise exception 'not authorized';
  end if;

  select coalesce(sum(l.author_earnings), 0) into v_earned
  from public.teacher_earnings_ledger l
  where l.author_id = v_author
    and l.status <> 'clawed_back'
    and coalesce(l.available_at, now()) <= now();

  select coalesce(sum(r.amount), 0) into v_reserved
  from public.teacher_payout_requests r
  where r.author_id = v_author
    and r.status in ('requested', 'approved', 'paid');

  return greatest(v_earned - v_reserved, 0);
end;
$$;

-- 7. Demande de retrait (RPC) ------------------------------------------------
create or replace function public.request_teacher_payout(
  p_amount numeric,
  p_method text,
  p_account_holder text,
  p_account_details text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_settings record;
  v_balance numeric;
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'authentication required';
  end if;

  if not exists (
    select 1 from public.profiles p
    where p.id = v_uid and p.teacher_verified
  ) then
    raise exception 'teacher verification required';
  end if;

  select * into v_settings from public.teacher_revenue_settings where id = true;

  if p_amount is null or p_amount < coalesce(v_settings.min_payout_amount, 3000) then
    raise exception 'amount below minimum payout';
  end if;

  if p_method not in ('ccp', 'baridimob', 'virement') then
    raise exception 'invalid payout method';
  end if;

  if coalesce(trim(p_account_holder), '') = '' or coalesce(trim(p_account_details), '') = '' then
    raise exception 'account details required';
  end if;

  v_balance := public.teacher_available_balance(v_uid);

  if p_amount > v_balance then
    raise exception 'insufficient available balance';
  end if;

  insert into public.teacher_payout_requests (
    author_id, amount, method, account_holder, account_details
  ) values (
    v_uid, p_amount, p_method, trim(p_account_holder), trim(p_account_details)
  )
  returning id into v_id;

  return v_id;
end;
$$;

-- 8. Clôture d'un mois (admin / service_role) --------------------------------
create or replace function public.close_teacher_revenue_period(p_month date default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_month date;
  v_settings record;
  v_gross numeric := 0;
  v_net numeric := 0;
  v_pool numeric := 0;
  v_units numeric := 0;
  v_author_count integer := 0;
  v_cap numeric := 0;
  v_period_id uuid;
  v_status text;
begin
  if not public.is_medsina_admin() then
    raise exception 'not authorized';
  end if;

  v_month := (date_trunc('month', coalesce(p_month, (now() - interval '1 month')::date)))::date;

  select * into v_settings from public.teacher_revenue_settings where id = true;
  if v_settings.id is null then
    insert into public.teacher_revenue_settings (id) values (true) on conflict (id) do nothing;
    select * into v_settings from public.teacher_revenue_settings where id = true;
  end if;

  select status into v_status from public.teacher_revenue_periods where period_month = v_month;
  if v_status = 'paid' then
    raise exception 'period % already paid', v_month;
  end if;

  select
    coalesce(sum(amount), 0),
    coalesce(sum(
      case
        when lower(payment_method) in ('google_play', 'play', 'app_store', 'apple')
          then amount * (1 - coalesce(v_settings.store_fee_pct, 15) / 100.0)
        else amount
      end
    ), 0)
  into v_gross, v_net
  from public.payments
  where status = 'approved'
    and (date_trunc('month', coalesce(updated_at, created_at)))::date = v_month;

  v_pool := round(v_net * coalesce(v_settings.author_share_pct, 65) / 100.0, 2);

  with eligible_content as (
    select e.content_type, e.content_id, e.author_id
    from public.teacher_content_events e
    where e.period_month = v_month
    group by e.content_type, e.content_id, e.author_id
    having count(distinct e.user_id) >= coalesce(v_settings.min_unique_readers, 10)
  ),
  author_units as (
    select e.author_id, sum(e.units) as units
    from public.teacher_content_events e
    join eligible_content c
      on c.content_type = e.content_type and c.content_id = e.content_id
    where e.period_month = v_month
    group by e.author_id
  )
  select coalesce(sum(units), 0), count(*) into v_units, v_author_count from author_units;

  -- Le plafond par auteur ne s'applique qu'à partir de min_authors_for_cap
  -- auteurs éligibles : au démarrage, un auteur unique perçoit tout le pool.
  v_cap := case
    when v_author_count >= coalesce(v_settings.min_authors_for_cap, 5)
      then v_pool * coalesce(v_settings.max_author_pool_pct, 20) / 100.0
    else v_pool
  end;

  insert into public.teacher_revenue_periods (
    period_month, gross_revenue, net_revenue, author_share_pct, author_pool,
    platform_share, eligible_units, status, details, computed_at
  ) values (
    v_month, v_gross, v_net, coalesce(v_settings.author_share_pct, 65), v_pool,
    round(v_net - v_pool, 2), v_units, 'closed',
    jsonb_build_object(
      'min_unique_readers', coalesce(v_settings.min_unique_readers, 10),
      'max_author_pool_pct', coalesce(v_settings.max_author_pool_pct, 20),
      'min_authors_for_cap', coalesce(v_settings.min_authors_for_cap, 5),
      'applied_cap', v_cap,
      'author_count', v_author_count,
      'holdback_days', coalesce(v_settings.holdback_days, 30)
    ),
    now()
  )
  on conflict (period_month) do update set
    gross_revenue = excluded.gross_revenue,
    net_revenue = excluded.net_revenue,
    author_share_pct = excluded.author_share_pct,
    author_pool = excluded.author_pool,
    platform_share = excluded.platform_share,
    eligible_units = excluded.eligible_units,
    status = 'closed',
    details = excluded.details,
    computed_at = excluded.computed_at
  returning id into v_period_id;

  delete from public.teacher_earnings_ledger where period_month = v_month;

  with eligible_content as (
    select e.content_type, e.content_id, e.author_id
    from public.teacher_content_events e
    where e.period_month = v_month
    group by e.content_type, e.content_id, e.author_id
    having count(distinct e.user_id) >= coalesce(v_settings.min_unique_readers, 10)
  ),
  author_units as (
    select e.author_id, sum(e.units) as units
    from public.teacher_content_events e
    join eligible_content c
      on c.content_type = e.content_type and c.content_id = e.content_id
    where e.period_month = v_month
    group by e.author_id
  ),
  shares as (
    select
      author_id,
      units,
      case when v_units > 0 then v_pool * units / v_units else 0 end as raw_share
    from author_units
  )
  insert into public.teacher_earnings_ledger (
    period_month, author_id, attributed_units, gross_attributed,
    author_earnings, capped_remainder, status, available_at
  )
  select
    v_month,
    s.author_id,
    round(s.units, 2),
    round(s.raw_share, 2),
    round(least(s.raw_share, v_cap), 2),
    round(greatest(s.raw_share - v_cap, 0), 2),
    'accrued',
    now() + make_interval(days => coalesce(v_settings.holdback_days, 30))
  from shares s;

  return v_period_id;
end;
$$;

-- 9. Droits d'exécution ------------------------------------------------------
grant execute on function public.record_teacher_consumption(text, text, numeric) to authenticated;
grant execute on function public.teacher_available_balance(uuid) to authenticated;
grant execute on function public.request_teacher_payout(numeric, text, text, text) to authenticated;
grant execute on function public.close_teacher_revenue_period(date) to authenticated;
grant execute on function public.is_medsina_admin() to authenticated;
