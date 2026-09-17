-- ============================================================================
-- HunLife — migration 002: video lessons with clickable captions + vocabulary
-- Run after schema.sql. Safe to re-run.
-- ============================================================================

-- VIDEOS ---------------------------------------------------------------------
create table if not exists public.videos (
  id uuid primary key default gen_random_uuid(),
  youtube_id text not null unique,
  title_uk text not null,
  title_hu text,
  description_uk text,
  level text,
  order_index int not null default 0,
  created_at timestamptz not null default now()
);

-- Cached caption cues, fetched by the `youtube-transcript` edge function.
-- cues = [{ "start": 1.23, "dur": 2.0, "text": "..." }, ...]
create table if not exists public.video_transcripts (
  video_id uuid primary key references public.videos (id) on delete cascade,
  lang text not null default 'hu',
  cues jsonb not null,
  is_auto_generated boolean not null default true,
  fetched_at timestamptz not null default now()
);

-- Translation cache so repeat word lookups never re-hit the free API.
create table if not exists public.translation_cache (
  source_text text not null,
  source_lang text not null default 'hu',
  target_lang text not null default 'uk',
  translated_text text not null,
  -- English gloss kept as a second opinion; free hu->uk MT is unreliable
  -- enough that the UI shows both.
  english_text text,
  created_at timestamptz not null default now(),
  primary key (source_text, source_lang, target_lang)
);

alter table public.translation_cache add column if not exists english_text text;

-- Per-user saved vocabulary (also studyable as flashcards).
create table if not exists public.vocabulary (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  word_hu text not null,
  translation_uk text not null,
  context_hu text,
  video_id uuid references public.videos (id) on delete set null,
  status text not null default 'new' check (status in ('new', 'learning', 'known')),
  last_reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, word_hu)
);

create index if not exists vocabulary_user_idx on public.vocabulary (user_id, created_at desc);

-- RLS -------------------------------------------------------------------------
alter table public.videos enable row level security;
alter table public.video_transcripts enable row level security;
alter table public.translation_cache enable row level security;
alter table public.vocabulary enable row level security;

drop policy if exists "videos_read_active_or_admin" on public.videos;
create policy "videos_read_active_or_admin" on public.videos
  for select using (public.is_active_user() or public.is_admin());
drop policy if exists "videos_write_admin" on public.videos;
create policy "videos_write_admin" on public.videos
  for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists "transcripts_read_active_or_admin" on public.video_transcripts;
create policy "transcripts_read_active_or_admin" on public.video_transcripts
  for select using (public.is_active_user() or public.is_admin());
drop policy if exists "transcripts_write_admin" on public.video_transcripts;
create policy "transcripts_write_admin" on public.video_transcripts
  for all using (public.is_admin()) with check (public.is_admin());

-- Read-only to clients; the edge function writes with the service role,
-- which bypasses RLS.
drop policy if exists "translation_cache_read" on public.translation_cache;
create policy "translation_cache_read" on public.translation_cache
  for select using (auth.uid() is not null);

drop policy if exists "vocabulary_own_or_admin" on public.vocabulary;
create policy "vocabulary_own_or_admin" on public.vocabulary
  for all using (auth.uid() = user_id or public.is_admin())
  with check (auth.uid() = user_id or public.is_admin());
