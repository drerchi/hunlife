-- Words the word-image function decided have no sensible picture (an
-- interrogative, a weekday, an abstract adjective) never got a row here, so
-- every learner who opened that word re-ran the same gloss lookup and
-- Openverse search from scratch. Allowing image_url to be null lets the
-- function cache that "no picture" outcome too, the same way it caches a
-- real one.
alter table public.word_images alter column image_url drop not null;
