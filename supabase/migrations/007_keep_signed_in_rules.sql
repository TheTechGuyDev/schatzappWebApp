-- SchatzApp Web: fix "Keep me signed in"
--  * Ticked: no idle logout; the 7 days restart every time the browser is used
--  * Not ticked: 4 hours idle or 24 hours in total -> logged out (unchanged)
-- Replaces web_device_heartbeat and sweep_web_devices from 002.

-- 1. Heartbeat from the web app (called on user activity).
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
  if not d.keep_signed_in and now() - d.last_active_at > interval '4 hours' then
    perform public._end_web_device(d.id, 'inactive');
    return 'inactive';
  end if;
  update public.web_devices
     set last_active_at = now(),
         -- Keep me signed in: rolling 7 days from the last use
         expires_at = case
           when d.keep_signed_in then greatest(d.expires_at, now() + interval '7 days')
           else d.expires_at
         end
   where id = d.id;
  return 'active';
end;
$$;
revoke all on function public.web_device_heartbeat(uuid) from public, anon;
grant execute on function public.web_device_heartbeat(uuid) to authenticated;

-- 2. Sweep: the 4-hour idle rule only applies when "Keep me signed in"
--    was not ticked. Expired devices are still ended for everyone.
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
              and (now() > expires_at
                   or (not keep_signed_in
                       and now() - last_active_at > interval '4 hours')) loop
    perform public._end_web_device(r.id, r.why);
    n := n + 1;
  end loop;
  delete from public.web_login_requests where expires_at < now() - interval '1 hour';
  return n;
end;
$$;
revoke all on function public.sweep_web_devices() from public, anon, authenticated;

-- 3. Check: both functions should report true
select
  position('keep_signed_in' in pg_get_functiondef('public.web_device_heartbeat(uuid)'::regprocedure)) > 0
    as heartbeat_updated,
  position('keep_signed_in' in pg_get_functiondef('public.sweep_web_devices()'::regprocedure)) > 0
    as sweep_updated;
