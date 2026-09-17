-- ============================================================================
-- HunLife — migration 003: interactive, step-by-step lessons
--
-- Lessons were a single block of text. Now each lesson is a sequence of small
-- steps a learner moves through one at a time: a phrase to learn, a note to
-- read, or a quick check question. Free-text lessons still work — content_uk
-- stays, and is shown when a lesson has no steps yet.
-- ============================================================================

create table if not exists public.lesson_steps (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid not null references public.lessons (id) on delete cascade,
  order_index int not null default 0,

  -- 'phrase' : Hungarian + Ukrainian pair to learn (with optional example)
  -- 'note'   : short explanation, no answer required
  -- 'quiz'   : multiple choice; options[] + correct_option
  kind text not null default 'phrase' check (kind in ('phrase', 'note', 'quiz')),

  text_hu text,
  text_uk text,
  example_hu text,
  example_uk text,

  question_uk text,
  options jsonb,
  correct_option int,

  created_at timestamptz not null default now()
);

create index if not exists lesson_steps_lesson_idx
  on public.lesson_steps (lesson_id, order_index);

alter table public.lesson_steps enable row level security;

drop policy if exists "lesson_steps_read_active_or_admin" on public.lesson_steps;
create policy "lesson_steps_read_active_or_admin" on public.lesson_steps
  for select using (public.is_active_user() or public.is_admin());

drop policy if exists "lesson_steps_write_admin" on public.lesson_steps;
create policy "lesson_steps_write_admin" on public.lesson_steps
  for all using (public.is_admin()) with check (public.is_admin());
