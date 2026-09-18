-- ============================================================================
-- HunLife — migration 005: pictures for vocabulary
--
-- A picture next to a word is far stickier than a translation alone. Images
-- come from Openverse (Creative Commons search) with a Wikipedia fallback,
-- and are cached here so each word is only ever looked up once.
--
-- Attribution is stored alongside the URL because these are CC-licensed
-- images and the licence requires crediting the creator.
-- ============================================================================

create table if not exists public.word_images (
  word text primary key,
  image_url text not null,
  thumb_url text,
  attribution text,
  license text,
  source_url text,
  provider text not null default 'openverse',
  created_at timestamptz not null default now()
);

alter table public.word_images enable row level security;

-- Readable by any signed-in user; only the edge function (service role,
-- which bypasses RLS) writes to it.
drop policy if exists "word_images_read" on public.word_images;
create policy "word_images_read" on public.word_images
  for select using (auth.uid() is not null);
