-- Finds the account for a phone number typed on the web, using the
-- sign-in phone stored on the account (auth.users.phone, digits only).
-- Only the web-login Edge Function (service role) can call it.
create or replace function public.web_user_id_for_phone(p_digits text)
returns uuid
language sql
stable
security definer
set search_path = public, auth
as $$
  select id from auth.users
  where regexp_replace(coalesce(phone, ''), '\D', '', 'g') = p_digits
  limit 1;
$$;

revoke all on function public.web_user_id_for_phone(text) from public, anon, authenticated;
grant execute on function public.web_user_id_for_phone(text) to service_role;

-- Check
select count(*) as function_ok
from pg_proc where proname = 'web_user_id_for_phone';
