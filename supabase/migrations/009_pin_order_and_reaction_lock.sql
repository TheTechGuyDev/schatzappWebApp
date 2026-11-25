-- 009: WhatsApp-style pinned chats + reactions lock after 3 seconds.
-- Shared by the phone app and the web app. Safe to run more than once.

-- ===========================================================================
-- 1) Pinned chats keep their pin order (a new message never moves them).
--    The newest pin goes on top, like WhatsApp.
-- ===========================================================================
alter table public.conversation_participants
  add column if not exists pinned_at timestamptz;

-- Set pinned_at automatically whenever is_pinned changes.
create or replace function public.set_pinned_at()
returns trigger
language plpgsql
as $$
begin
  if new.is_pinned is true then
    if tg_op = 'INSERT' or old.is_pinned is distinct from true
       or new.pinned_at is null then
      new.pinned_at := now();
    end if;
  else
    new.pinned_at := null;
  end if;
  return new;
end $$;

drop trigger if exists trg_set_pinned_at on public.conversation_participants;
create trigger trg_set_pinned_at
  before insert or update of is_pinned on public.conversation_participants
  for each row execute function public.set_pinned_at();

-- Chats that are already pinned: keep the order users see today
-- (latest message = top) by giving them pinned_at values in that order.
with ranked as (
  select cp.id,
         row_number() over (
           partition by cp.user_id
           order by c.last_message_at desc nulls last
         ) as rn
    from public.conversation_participants cp
    join public.conversations c on c.id = cp.conversation_id
   where cp.is_pinned is true and cp.pinned_at is null
)
update public.conversation_participants cp
   set pinned_at = now() - (ranked.rn * interval '1 second')
  from ranked
 where cp.id = ranked.id;

create index if not exists conversation_participants_user_pinned_idx
  on public.conversation_participants (user_id, pinned_at desc)
  where is_pinned is true;

-- ===========================================================================
-- 2) A reaction can't be removed or changed after 3 seconds.
--    Adding another one is still allowed (max 2, from migration 008).
--    Deleting a whole story still removes its reactions.
-- ===========================================================================
create or replace function public.status_reactions_lock()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.user_id = auth.uid()
     and old.created_at < now() - interval '3 seconds'
     and exists (select 1 from public.statuses s where s.id = old.status_id)
  then
    raise exception 'Reactions can''t be changed after 3 seconds'
      using errcode = 'P0001';
  end if;
  return old;
end $$;

drop trigger if exists trg_status_reactions_lock on public.status_reactions;
create trigger trg_status_reactions_lock
  before delete on public.status_reactions
  for each row execute function public.status_reactions_lock();

-- Changing the type of an existing reaction is also blocked.
create or replace function public.status_reactions_no_update()
returns trigger
language plpgsql
as $$
begin
  if new.reaction_type is distinct from old.reaction_type
     and old.created_at < now() - interval '3 seconds' then
    raise exception 'Reactions can''t be changed after 3 seconds'
      using errcode = 'P0001';
  end if;
  return new;
end $$;

drop trigger if exists trg_status_reactions_no_update on public.status_reactions;
create trigger trg_status_reactions_no_update
  before update on public.status_reactions
  for each row execute function public.status_reactions_no_update();

-- Check: should return 3 rows.
select tgname from pg_trigger
 where tgname in ('trg_set_pinned_at',
                  'trg_status_reactions_lock',
                  'trg_status_reactions_no_update')
 order by tgname;
