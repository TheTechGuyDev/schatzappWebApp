-- SchatzApp Web: session rules
--  * 4 hours with no activity  -> logged out
--  * Keep me signed in ticked  -> max 7 days, unticked -> max 24 hours
--  * Max 7 linked web devices per account (enforced by the Edge Function)

-- 1. Link each web device to its Supabase auth session
alter table public.web_devices
  add column if not exists session_id uuid;

create index if not exists web_devices_active_idx
  on public.web_devices (user_id)
  where revoked_at is null;

-- 2. Internal helper: end a device and kill its auth session (refresh token)
create or replace function public._end_web_device(p_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare v_session uuid;
begin
  update public.web_devices
     set revoked_at = coalesce(revoked_at, now()),
         revoked_reason = coalesce(revoked_reason, p_reason)
   where id = p_id
   returning session_id into v_session;
  if v_session is not null then
    delete from auth.sessions where id = v_session;
  end if;
end;
$$;
revoke all on function public._end_web_device(uuid, text) from public, anon, authenticated;

-- 3. Heartbeat from the web app (called on user activity).
--    Returns: active | inactive | expired | revoked
create or replace function public.web_device_heartbeat(p_device_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare d public.web_devices;
begin
  select * into d from public.web_devices
   where id = p_device_id and user_id = auth.uid();
  if not found or d.revoked_at is not null then
    return 'revoked';
  end if;
  if now() > d.expires_at then
    perform public._end_web_device(d.id, 'expired');
    return 'expired';
  end if;
  if now() - d.last_active_at > interval '4 hours' then
    perform public._end_web_device(d.id, 'inactive');
    return 'inactive';
  end if;
  update public.web_devices set last_active_at = now() where id = d.id;
  return 'active';
end;
$$;
revoke all on function public.web_device_heartbeat(uuid) from public, anon;
grant execute on function public.web_device_heartbeat(uuid) to authenticated;

-- 4. Log out one / all web devices (phone Linked Devices screen or web
--    Log out). Replaces the Phase 2 versions so the session is killed too.
create or replace function public.revoke_web_device(p_device_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.web_devices
     where id = p_device_id and user_id = auth.uid() and revoked_at is null
  ) then
    return false;
  end if;
  perform public._end_web_device(p_device_id, 'logged_out');
  return true;
end;
$$;

create or replace function public.revoke_all_web_devices()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare r record; n integer := 0;
begin
  for r in select id from public.web_devices
            where user_id = auth.uid() and revoked_at is null loop
    perform public._end_web_device(r.id, 'logged_out_all');
    n := n + 1;
  end loop;
  return n;
end;
$$;

-- 5. Sweep: ends idle (4h) and expired devices even if the tab was closed
create or replace function public.sweep_web_devices()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare r record; n integer := 0;
begin
  for r in select id,
                  case when now() > expires_at then 'expired' else 'inactive' end as why
             from public.web_devices
            where revoked_at is null
              and (now() > expires_at or now() - last_active_at > interval '4 hours') loop
    perform public._end_web_device(r.id, r.why);
    n := n + 1;
  end loop;
  -- Old QR requests are useless after a few minutes
  delete from public.web_login_requests where expires_at < now() - interval '1 hour';
  return n;
end;
$$;
revoke all on function public.sweep_web_devices() from public, anon, authenticated;

-- 6. Run the sweep every 10 minutes
create extension if not exists pg_cron;
select cron.unschedule('sweep-web-devices')
 where exists (select 1 from cron.job where jobname = 'sweep-web-devices');
select cron.schedule('sweep-web-devices', '*/10 * * * *',
                     'select public.sweep_web_devices();');

-- 7. Check: should return session_id_column true, functions 5, cron_job true
select
  exists (select 1 from information_schema.columns
           where table_name = 'web_devices' and column_name = 'session_id')
    as session_id_column,
  (select count(*) from pg_proc
    where proname in ('_end_web_device','web_device_heartbeat','revoke_web_device',
                      'revoke_all_web_devices','sweep_web_devices')) as functions,
  exists (select 1 from cron.job where jobname = 'sweep-web-devices') as cron_job;
