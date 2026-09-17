-- ============================================================================
-- HunLife — Supabase schema
-- Run this whole file once in the Supabase SQL editor (Project → SQL Editor).
-- Safe to re-run: uses "if not exists" / "or replace" everywhere.
-- ============================================================================

create extension if not exists "pgcrypto";

-- ----------------------------------------------------------------------------
-- PROFILES
-- One row per auth user. Created automatically on sign-up (trigger below).
-- access_until = null  -> unlimited access (as long as not blocked)
-- access_until = date  -> access expires at that timestamp
-- ----------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  full_name text,
  role text not null default 'user' check (role in ('user', 'admin')),
  is_blocked boolean not null default false,
  access_until timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (new.id, new.email, new.raw_user_meta_data ->> 'full_name')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
  before update on public.profiles
  for each row execute procedure public.set_updated_at();

-- Security-definer helpers so RLS policies can check role/status
-- without recursively re-querying profiles under RLS.
create or replace function public.is_admin()
returns boolean
language sql security definer set search_path = public stable
as $$
  select exists (
    select 1 from public.profiles where id = auth.uid() and role = 'admin'
  );
$$;

create or replace function public.is_active_user()
returns boolean
language sql security definer set search_path = public stable
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid()
      and is_blocked = false
      and (access_until is null or access_until > now())
  );
$$;

-- ----------------------------------------------------------------------------
-- CONTENT: topics -> lessons, topics -> flashcards, citizenship Q&A
-- ----------------------------------------------------------------------------
create table if not exists public.topics (
  id uuid primary key default gen_random_uuid(),
  title_uk text not null,
  title_hu text,
  description_uk text,
  icon text,
  order_index int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.lessons (
  id uuid primary key default gen_random_uuid(),
  topic_id uuid not null references public.topics (id) on delete cascade,
  title_uk text not null,
  title_hu text,
  content_uk text not null default '',
  order_index int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.flashcards (
  id uuid primary key default gen_random_uuid(),
  topic_id uuid not null references public.topics (id) on delete cascade,
  lesson_id uuid references public.lessons (id) on delete set null,
  front_hu text not null,
  back_uk text not null,
  example_hu text,
  example_uk text,
  order_index int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.citizenship_questions (
  id uuid primary key default gen_random_uuid(),
  category text not null default 'Загальне',
  question_hu text not null,
  question_uk text not null,
  answer_hu text not null,
  answer_uk text not null,
  order_index int not null default 0,
  created_at timestamptz not null default now()
);

-- Per-user progress
create table if not exists public.flashcard_progress (
  user_id uuid not null references public.profiles (id) on delete cascade,
  flashcard_id uuid not null references public.flashcards (id) on delete cascade,
  status text not null default 'new' check (status in ('new', 'learning', 'known')),
  last_reviewed_at timestamptz,
  primary key (user_id, flashcard_id)
);

create table if not exists public.lesson_progress (
  user_id uuid not null references public.profiles (id) on delete cascade,
  lesson_id uuid not null references public.lessons (id) on delete cascade,
  completed_at timestamptz not null default now(),
  primary key (user_id, lesson_id)
);

-- ----------------------------------------------------------------------------
-- ROW LEVEL SECURITY
-- ----------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.topics enable row level security;
alter table public.lessons enable row level security;
alter table public.flashcards enable row level security;
alter table public.citizenship_questions enable row level security;
alter table public.flashcard_progress enable row level security;
alter table public.lesson_progress enable row level security;

drop policy if exists "profiles_select_own_or_admin" on public.profiles;
create policy "profiles_select_own_or_admin" on public.profiles
  for select using (auth.uid() = id or public.is_admin());

drop policy if exists "profiles_update_own_or_admin" on public.profiles;
create policy "profiles_update_own_or_admin" on public.profiles
  for update using (auth.uid() = id or public.is_admin());

drop policy if exists "topics_read_active_or_admin" on public.topics;
create policy "topics_read_active_or_admin" on public.topics
  for select using (public.is_active_user() or public.is_admin());
drop policy if exists "topics_write_admin" on public.topics;
create policy "topics_write_admin" on public.topics
  for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists "lessons_read_active_or_admin" on public.lessons;
create policy "lessons_read_active_or_admin" on public.lessons
  for select using (public.is_active_user() or public.is_admin());
drop policy if exists "lessons_write_admin" on public.lessons;
create policy "lessons_write_admin" on public.lessons
  for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists "flashcards_read_active_or_admin" on public.flashcards;
create policy "flashcards_read_active_or_admin" on public.flashcards
  for select using (public.is_active_user() or public.is_admin());
drop policy if exists "flashcards_write_admin" on public.flashcards;
create policy "flashcards_write_admin" on public.flashcards
  for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists "citizenship_read_active_or_admin" on public.citizenship_questions;
create policy "citizenship_read_active_or_admin" on public.citizenship_questions
  for select using (public.is_active_user() or public.is_admin());
drop policy if exists "citizenship_write_admin" on public.citizenship_questions;
create policy "citizenship_write_admin" on public.citizenship_questions
  for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists "flashcard_progress_own_or_admin" on public.flashcard_progress;
create policy "flashcard_progress_own_or_admin" on public.flashcard_progress
  for all using (auth.uid() = user_id or public.is_admin())
  with check (auth.uid() = user_id or public.is_admin());

drop policy if exists "lesson_progress_own_or_admin" on public.lesson_progress;
create policy "lesson_progress_own_or_admin" on public.lesson_progress
  for all using (auth.uid() = user_id or public.is_admin())
  with check (auth.uid() = user_id or public.is_admin());

-- ----------------------------------------------------------------------------
-- Make yourself an admin AFTER you sign up once in the app with this email.
-- ----------------------------------------------------------------------------
-- update public.profiles set role = 'admin' where email = 'dr.erchi@gmail.com';
