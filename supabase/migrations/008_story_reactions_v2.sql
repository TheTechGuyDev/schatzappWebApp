-- 008: For You reactions are now ❤️ favorite, ✌️ peace, 😂 laugh, 😢 sad,
-- 😠 angry. 'thumbs' (👍) is replaced by 'laugh'. Each user may hold at most
-- 2 reactions per post; this is enforced here, not only in the apps.

-- 1) Move old thumbs reactions to laugh (skip if the user already has laugh).
delete from public.status_reactions t
 where t.reaction_type = 'thumbs'
   and exists (select 1 from public.status_reactions l
                where l.status_id = t.status_id and l.user_id = t.user_id
                  and l.reaction_type = 'laugh');
update public.status_reactions set reaction_type = 'laugh'
 where reaction_type = 'thumbs';

-- 2) Drop any old CHECK constraint on reaction_type, then allow the new set.
--    'thumbs' stays allowed only so phones on the old build keep working;
--    the apps show it as laugh.
do $$
declare c record;
begin
  for c in
    select con.conname
      from pg_constraint con
      join pg_class rel on rel.oid = con.conrelid
      join pg_namespace n on n.oid = rel.relnamespace
     where n.nspname = 'public' and rel.relname = 'status_reactions'
       and con.contype = 'c'
       and pg_get_constraintdef(con.oid) ilike '%reaction_type%'
  loop
    execute format('alter table public.status_reactions drop constraint %I', c.conname);
  end loop;
end $$;

alter table public.status_reactions
  add constraint status_reactions_type_check
  check (reaction_type in ('favorite','peace','laugh','sad','angry','thumbs'));

-- 3) Max 2 reactions per user per post.
create or replace function public.status_reactions_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform pg_advisory_xact_lock(hashtext(new.status_id::text || new.user_id::text));
  if (select count(*) from public.status_reactions
       where status_id = new.status_id and user_id = new.user_id) >= 2 then
    raise exception 'You can pick up to 2 reactions on a post'
      using errcode = 'P0001';
  end if;
  return new;
end $$;

drop trigger if exists trg_status_reactions_limit on public.status_reactions;
create trigger trg_status_reactions_limit
  before insert on public.status_reactions
  for each row execute function public.status_reactions_limit();

-- Check: should return 1 row with the trigger name.
select tgname as reaction_limit_trigger
  from pg_trigger where tgname = 'trg_status_reactions_limit';
