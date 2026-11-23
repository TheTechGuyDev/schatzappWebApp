-- Web sessions are now opened with a one-time sign-in link instead of a
-- temporary password (changing a password signs the user out everywhere).
-- Phone-only accounts get a private placeholder email for a moment; this
-- removes it again. Only the web-login Edge Function can call it.
create or replace function public.web_clear_link_email(p_user uuid, p_email text)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if p_email is null or p_email not like 'web-%@link.schatzapp.invalid' then
    return;
  end if;
  update auth.users
     set email = null,
         email_confirmed_at = null,
         email_change = '',
         email_change_token_new = '',
         email_change_token_current = ''
   where id = p_user and email = p_email;
  delete from auth.identities
   where user_id = p_user
     and provider = 'email'
     and identity_data->>'email' = p_email;
end;
$$;

revoke all on function public.web_clear_link_email(uuid, text) from public, anon, authenticated;
grant execute on function public.web_clear_link_email(uuid, text) to service_role;

-- Check
select count(*) as function_ok
from pg_proc where proname = 'web_clear_link_email';
