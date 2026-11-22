-- SchatzApp Web: QR login requests and linked web devices
create extension if not exists pgcrypto;

-- 1. Short-lived QR login requests (server-only, accessed by the Edge Function)
create table if not exists public.web_login_requests (
  id               uuid primary key default gen_random_uuid(),
  qr_code_hash     text not null unique,
  poll_secret_hash text not null,
  status           text not null default 'pending'
                   check (status in ('pending','approved','rejected','consumed')),
  user_id          uuid references auth.users(id) on delete cascade,
  device_name      text,
  browser          text,
  os               text,
  ip_address       text,
  location         text,
  keep_signed_in   boolean not null default true,
  created_at       timestamptz not null default now(),
  expires_at       timestamptz not null default (now() + interval '60 seconds'),
  approved_at      timestamptz,
  consumed_at      timestamptz
);
alter table public.web_login_requests enable row level security;
-- No policies: only the Edge Function (service role) can read or write.

create index if not exists web_login_requests_expires_idx
  on public.web_login_requests (expires_at);

-- 2. Linked web devices (one row per signed-in browser)
create table if not exists public.web_devices (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references auth.users(id) on delete cascade,
  device_token_hash text not null unique,
  device_name       text,
  browser           text,
  os                text,
  ip_address        text,
  location          text,
  login_method      text not null default 'qr' check (login_method in ('qr','phone')),
  keep_signed_in    boolean not null default true,
  created_at        timestamptz not null default now(),
  last_active_at    timestamptz not null default now(),
  expires_at        timestamptz not null,
  revoked_at        timestamptz,
  revoked_reason    text
);
alter table public.web_devices enable row level security;

create index if not exists web_devices_user_idx on public.web_devices (user_id);

-- Owners can see their own devices (phone list + web realtime logout signal).
drop policy if exists "web_devices_select_own" on public.web_devices;
create policy "web_devices_select_own" on public.web_devices
  for select to authenticated
  using (user_id = auth.uid());
-- No insert/update/delete from clients: changes go through the functions
-- below or the Edge Function. Only a SHA-256 hash of the device token is
-- stored, so the raw token never exists in the database.
revoke insert, update, delete on public.web_devices from anon, authenticated;
revoke all on public.web_login_requests from anon, authenticated;

-- 3. Log out one web device (called by the phone or the web itself)
create or replace function public.revoke_web_device(p_device_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.web_devices
     set revoked_at = now(), revoked_reason = 'logged_out'
   where id = p_device_id
     and user_id = auth.uid()
     and revoked_at is null;
  return found;
end;
$$;

-- 4. Log out all web devices for the current user
create or replace function public.revoke_all_web_devices()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare n integer;
begin
  update public.web_devices
     set revoked_at = now(), revoked_reason = 'logged_out_all'
   where user_id = auth.uid()
     and revoked_at is null;
  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.revoke_web_device(uuid) from public, anon;
revoke all on function public.revoke_all_web_devices() from public, anon;
grant execute on function public.revoke_web_device(uuid) to authenticated;
grant execute on function public.revoke_all_web_devices() to authenticated;

-- 5. Realtime: lets an open web tab sign out the moment the phone logs it out
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public' and tablename = 'web_devices'
  ) then
    alter publication supabase_realtime add table public.web_devices;
  end if;
end $$;

-- 6. Check: should return 2 tables, 1 policy, 2 functions, realtime = true
select
  (select count(*) from information_schema.tables
    where table_schema = 'public'
      and table_name in ('web_login_requests','web_devices')) as tables,
  (select count(*) from pg_policies
    where schemaname = 'public' and tablename = 'web_devices') as policies,
  (select count(*) from pg_proc
    where proname in ('revoke_web_device','revoke_all_web_devices')) as functions,
  exists (select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'web_devices') as realtime;
