-- Let the web sign-in page list countries before the user is logged in.
grant select on public.supported_countries to anon;

do $$
begin
  if (select relrowsecurity from pg_class
       where oid = 'public.supported_countries'::regclass) then
    drop policy if exists "supported_countries_public_read" on public.supported_countries;
    create policy "supported_countries_public_read" on public.supported_countries
      for select to anon, authenticated
      using (is_active = true);
  end if;
end $$;

-- Check: should return a number above 0
set role anon;
select count(*) as active_countries from public.supported_countries where is_active;
reset role;
