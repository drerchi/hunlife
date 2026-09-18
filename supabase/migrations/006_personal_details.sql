-- ============================================================================
-- HunLife — migration 006: personal details for interview answers
--
-- At the citizenship interview the candidate answers with their OWN name and
-- date of birth, so practising with a placeholder name is only half useful.
-- These fields let the app substitute the learner's real details into every
-- answer, including the spelled-out Hungarian date they'll have to say aloud.
--
-- Names are stored in Latin script so the learner reads a pronounceable form
-- rather than transliterating Cyrillic on the spot.
-- ============================================================================

alter table public.profiles add column if not exists first_name text;
alter table public.profiles add column if not exists last_name text;
alter table public.profiles add column if not exists date_of_birth date;
alter table public.profiles add column if not exists birth_place text;
alter table public.profiles add column if not exists mother_name text;

comment on column public.profiles.first_name is 'Given name in Latin script, e.g. Péter';
comment on column public.profiles.last_name is 'Family name in Latin script, e.g. Kovács';
comment on column public.profiles.birth_place is 'Place of birth as said in the interview';
comment on column public.profiles.mother_name is 'Mother''s maiden name — a standard interview question';
