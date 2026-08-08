-- 3 Patti Social V1.4 production-foundation schema (Supabase/Postgres)
-- Run this once in the Supabase SQL editor. Keep SUPABASE_SERVICE_ROLE_KEY server-side only.

create extension if not exists pgcrypto;

create table if not exists public.users (
  id uuid primary key default gen_random_uuid(),
  external_player_id text not null unique,
  display_name text not null default 'Player',
  avatar integer not null default 1 check (avatar between 1 and 8),
  kyc_status text not null default 'unverified',
  age_verified boolean not null default false,
  geo_state text,
  cash_eligible boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.wallets (
  user_id uuid primary key references public.users(id) on delete cascade,
  chip_balance bigint not null default 0 check (chip_balance >= 0),
  usd_cents bigint not null default 0 check (usd_cents >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.ledger_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete set null,
  entry_type text not null,
  chips_delta bigint not null default 0,
  usd_cents_delta bigint not null default 0,
  reference_id text not null unique,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.game_rooms (
  id uuid primary key,
  player_count integer not null check (player_count between 2 and 10),
  status text not null,
  state jsonb not null,
  version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists game_rooms_matchmaking_idx on public.game_rooms(player_count, status, updated_at);

create table if not exists public.hand_history (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null,
  round_no integer not null,
  hand_id text not null,
  commitment text,
  reveal_seed text,
  result jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(room_id, round_no)
);

create table if not exists public.platform_revenue (
  id uuid primary key default gen_random_uuid(),
  revenue_type text not null check (revenue_type in ('rake','dealer_tip')),
  chips bigint not null default 0,
  usd_cents bigint not null default 0,
  room_id uuid,
  hand_id text,
  reference_id text not null unique,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.payment_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete set null,
  direction text not null check (direction in ('deposit','withdrawal')),
  provider text not null,
  amount_usd_cents bigint not null default 0,
  chips bigint not null default 0,
  destination_masked text,
  status text not null default 'queued',
  external_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references public.users(id) on delete set null,
  event_type text not null,
  reference_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.apply_wallet_transaction(
  p_user_id uuid,
  p_chips_delta bigint,
  p_usd_cents_delta bigint,
  p_entry_type text,
  p_reference_id text,
  p_metadata jsonb default '{}'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  w public.wallets%rowtype;
  existing public.ledger_entries%rowtype;
begin
  select * into existing from public.ledger_entries where reference_id = p_reference_id;
  if found then
    select * into w from public.wallets where user_id = p_user_id;
    return jsonb_build_object('idempotent', true, 'chip_balance', w.chip_balance, 'usd_cents', w.usd_cents);
  end if;

  select * into w from public.wallets where user_id = p_user_id for update;
  if not found then raise exception 'WALLET_NOT_FOUND'; end if;
  if w.chip_balance + p_chips_delta < 0 then raise exception 'INSUFFICIENT_CHIPS'; end if;
  if w.usd_cents + p_usd_cents_delta < 0 then raise exception 'INSUFFICIENT_USD'; end if;

  update public.wallets
     set chip_balance = chip_balance + p_chips_delta,
         usd_cents = usd_cents + p_usd_cents_delta,
         updated_at = now()
   where user_id = p_user_id
   returning * into w;

  insert into public.ledger_entries(user_id, entry_type, chips_delta, usd_cents_delta, reference_id, metadata)
  values(p_user_id, p_entry_type, p_chips_delta, p_usd_cents_delta, p_reference_id, coalesce(p_metadata, '{}'::jsonb));

  return jsonb_build_object('idempotent', false, 'chip_balance', w.chip_balance, 'usd_cents', w.usd_cents);
end;
$$;

create or replace function public.save_game_room(
  p_id uuid,
  p_player_count integer,
  p_status text,
  p_state jsonb,
  p_expected_version bigint
) returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  next_version bigint;
begin
  if p_expected_version = 0 then
    insert into public.game_rooms(id, player_count, status, state, version)
    values(p_id, p_player_count, p_status, p_state, 1)
    on conflict (id) do nothing
    returning version into next_version;
    if next_version is null then raise exception 'ROOM_VERSION_CONFLICT'; end if;
    return next_version;
  end if;

  update public.game_rooms
     set player_count = p_player_count,
         status = p_status,
         state = p_state,
         version = version + 1,
         updated_at = now()
   where id = p_id and version = p_expected_version
   returning version into next_version;

  if next_version is null then raise exception 'ROOM_VERSION_CONFLICT'; end if;
  return next_version;
end;
$$;

create or replace function public.lobby_summary()
returns table(player_count integer, waiting_players bigint, active_rooms bigint)
language sql
security definer
set search_path = public
as $$
  select x.player_count,
         coalesce(sum(case when x.status = 'waiting' then jsonb_array_length(x.state->'players') else 0 end),0)::bigint as waiting_players,
         coalesce(sum(case when x.status = 'playing' then 1 else 0 end),0)::bigint as active_rooms
    from public.game_rooms x
   group by x.player_count
   order by x.player_count;
$$;
