-- ============================================================================
-- HunLife — migration 007: chapters
--
-- The topic list was getting long and flat. Chapters group topics into a
-- course structure ("Перші кроки", "Щоденне життя", ...), so a learner sees
-- a path rather than a pile.
--
-- chapter_id is nullable so existing topics keep working while they're
-- assigned, and so a topic can deliberately sit outside the main course.
-- ============================================================================

create table if not exists public.chapters (
  id uuid primary key default gen_random_uuid(),
  title_uk text not null,
  title_hu text,
  description_uk text,
  icon text,
  order_index int not null default 0,
  created_at timestamptz not null default now()
);

alter table public.topics add column if not exists chapter_id uuid
  references public.chapters (id) on delete set null;

create index if not exists topics_chapter_idx on public.topics (chapter_id, order_index);

alter table public.chapters enable row level security;

drop policy if exists "chapters_read_active_or_admin" on public.chapters;
create policy "chapters_read_active_or_admin" on public.chapters
  for select using (public.is_active_user() or public.is_admin());

drop policy if exists "chapters_write_admin" on public.chapters;
create policy "chapters_write_admin" on public.chapters
  for all using (public.is_admin()) with check (public.is_admin());
