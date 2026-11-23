-- SchatzApp Web: "Link with code" (no SMS).
-- The phone asks the web-login Edge Function for a 6-digit code; the web
-- signs in with phone number + code. Only the Edge Function (service role)
-- can read or write this table. Codes are stored hashed.

create table if not exists public.web_link_codes (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  code_hash   text not null,
  attempts    int  not null default 0,
  expires_at  timestamptz not null,
  used_at     timestamptz,
  created_at  timestamptz not null default now()
);

create index if not exists web_link_codes_user_idx
  on public.web_link_codes (user_id, created_at desc);

alter table public.web_link_codes enable row level security;
-- No policies: the web and phone apps can never read or write it directly.

revoke all on public.web_link_codes from anon, authenticated;
grant all on public.web_link_codes to service_role;

-- Old codes are removed by the existing 10-minute sweep job as well.
create or replace function public.sweep_web_link_codes()
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.web_link_codes
  where expires_at < now() - interval '1 day';
$$;

revoke all on function public.sweep_web_link_codes() from public, anon, authenticated;

select cron.unschedule('sweep-web-link-codes')
where exists (select 1 from cron.job where jobname = 'sweep-web-link-codes');

select cron.schedule(
  'sweep-web-link-codes',
  '0 * * * *',
  $$select public.sweep_web_link_codes();$$
);

-- Check
select
  (select count(*) from information_schema.tables
     where table_schema = 'public' and table_name = 'web_link_codes') as table_ok,
  (select relrowsecurity from pg_class where relname = 'web_link_codes') as rls_on,
  (select count(*) from cron.job where jobname = 'sweep-web-link-codes') as cron_ok;
