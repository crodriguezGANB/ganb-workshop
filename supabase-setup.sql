-- GANB FE Workshop Register — Supabase setup
-- Run once: Supabase dashboard → SQL Editor → New query → paste all → Run.
-- Safe to run again (it replaces functions and policies).

-- 1. People who may use the app ------------------------------------------
create table if not exists public.profiles (
  email      text primary key check (email = lower(email)),
  full_name  text not null,
  role       text not null check (role in ('admin','office','tech')),
  active     boolean not null default true,
  created_at timestamptz not null default now()
);

-- 2. App records (extinguishers, clients, delivery notes, settings) -------
create table if not exists public.docs (
  path       text primary key,              -- e.g. units/abc123, clients/c01, meta/settings
  parent     text not null,                 -- e.g. units, clients, notes, meta
  data       jsonb not null default '{}'::jsonb,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_by uuid,
  updated_at timestamptz not null default now()
);
create index if not exists docs_parent_idx on public.docs(parent);

-- 3. Activity log (who did what, cannot be edited or deleted) -------------
create table if not exists public.activity (
  id         bigint generated always as identity primary key,
  at         timestamptz not null default now(),
  user_email text not null default lower(auth.jwt() ->> 'email'),
  user_name  text,
  action     text not null,
  ref        text,
  details    text
);
create index if not exists activity_at_idx on public.activity(at desc);

-- 4. Helper: the signed-in person's role (null = no access) ---------------
create or replace function public.my_role() returns text
language sql stable security definer set search_path = public as $$
  select role from public.profiles
  where email = lower(auth.jwt() ->> 'email') and active
$$;

-- Stamp who changed a record and when
create or replace function public.docs_stamp() returns trigger
language plpgsql as $$
begin
  new.updated_by := auth.uid();
  new.updated_at := now();
  if tg_op = 'UPDATE' then
    new.created_by := old.created_by;
    new.created_at := old.created_at;
    new.parent := old.parent;
  end if;
  return new;
end $$;
drop trigger if exists docs_stamp on public.docs;
create trigger docs_stamp before insert or update on public.docs
for each row execute function public.docs_stamp();

-- Merge a change into a record (respects the security rules below)
create or replace function public.doc_update(p_path text, p_patch jsonb) returns void
language plpgsql security invoker set search_path = public as $$
begin
  update public.docs set data = data || p_patch where path = p_path;
  if not found then
    raise exception 'Not allowed, or the record no longer exists' using errcode = '42501';
  end if;
end $$;

-- Next workshop number / delivery note number (atomic, no duplicates)
create or replace function public.next_seq(p_key text) returns integer
language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  if public.my_role() is null then raise exception 'No access' using errcode = '42501'; end if;
  if p_key !~ '^(tag|dn)[0-9]{4}$' then raise exception 'Bad counter'; end if;
  if public.my_role() = 'tech' and p_key like 'dn%' then raise exception 'No access' using errcode = '42501'; end if;
  insert into public.docs(path, parent, data) values ('meta/counters', 'meta', '{}'::jsonb)
  on conflict (path) do nothing;
  update public.docs
     set data = data || jsonb_build_object(p_key, coalesce((data ->> p_key)::int, 0) + 1)
   where path = 'meta/counters'
  returning (data ->> p_key)::int into n;
  return n;
end $$;

-- After a restore: make sure counters are not below the restored numbers (admin only)
create or replace function public.set_counter_min(p_key text, p_val integer) returns void
language plpgsql security definer set search_path = public as $$
begin
  if public.my_role() is distinct from 'admin' then raise exception 'No access' using errcode = '42501'; end if;
  if p_key !~ '^(tag|dn)[0-9]{4}$' then raise exception 'Bad counter'; end if;
  insert into public.docs(path, parent, data) values ('meta/counters', 'meta', '{}'::jsonb)
  on conflict (path) do nothing;
  update public.docs
     set data = data || jsonb_build_object(p_key, greatest(coalesce((data ->> p_key)::int, 0), p_val))
   where path = 'meta/counters';
end $$;

-- 5. Security rules -------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.docs     enable row level security;
alter table public.activity enable row level security;

drop policy if exists profiles_read  on public.profiles;
drop policy if exists profiles_write on public.profiles;
create policy profiles_read  on public.profiles for select to authenticated
  using (public.my_role() is not null);
create policy profiles_write on public.profiles for all to authenticated
  using (public.my_role() = 'admin') with check (public.my_role() = 'admin');

drop policy if exists docs_read   on public.docs;
drop policy if exists docs_insert on public.docs;
drop policy if exists docs_update on public.docs;
drop policy if exists docs_delete on public.docs;

-- Everyone with access can see all records
create policy docs_read on public.docs for select to authenticated
  using (public.my_role() is not null);

-- Create: everyone can register extinguishers and new clients;
-- delivery notes = office + admin; settings = admin
create policy docs_insert on public.docs for insert to authenticated
  with check (case
    when parent in ('units','clients') then public.my_role() is not null
    when parent = 'notes'              then public.my_role() in ('admin','office')
    else public.my_role() = 'admin' end);

-- Change: office + admin can change anything except settings (admin);
-- technicians can change extinguishers that are not yet delivered
create policy docs_update on public.docs for update to authenticated
  using (case
    when parent = 'units' then public.my_role() in ('admin','office')
         or (public.my_role() = 'tech' and coalesce(data ->> 'status','') <> 'delivered')
    when parent in ('clients','notes') then public.my_role() in ('admin','office')
    else public.my_role() = 'admin' end)
  with check (case
    when parent = 'units' then public.my_role() in ('admin','office')
         or (public.my_role() = 'tech' and coalesce(data ->> 'status','') <> 'delivered')
    when parent in ('clients','notes') then public.my_role() in ('admin','office')
    else public.my_role() = 'admin' end);

-- Delete: administrator only
create policy docs_delete on public.docs for delete to authenticated
  using (public.my_role() = 'admin');

drop policy if exists activity_insert on public.activity;
drop policy if exists activity_read   on public.activity;
create policy activity_insert on public.activity for insert to authenticated
  with check (public.my_role() is not null and user_email = lower(auth.jwt() ->> 'email'));
create policy activity_read on public.activity for select to authenticated
  using (public.my_role() = 'admin');

grant execute on function public.doc_update(text, jsonb)       to authenticated;
grant execute on function public.next_seq(text)                to authenticated;
grant execute on function public.set_counter_min(text, integer) to authenticated;
revoke execute on function public.next_seq(text)                from anon;
revoke execute on function public.set_counter_min(text, integer) from anon;
revoke execute on function public.doc_update(text, jsonb)       from anon;

-- 6. Live updates between screens -----------------------------------------
do $$ begin
  begin alter publication supabase_realtime add table public.docs;     exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.profiles; exception when duplicate_object then null; end;
end $$;

-- 7. First users ----------------------------------------------------------
insert into public.profiles(email, full_name, role) values
  ('crodriguez@ganb.com',    'Carlos Rodriguez', 'admin'),
  ('contact@ganbglobal.com', 'Inemar Lopez',     'office'),
  ('service4aua@ganb.com',   'David Croes',      'tech')
on conflict (email) do nothing;
