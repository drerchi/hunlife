-- ============================================================================
-- HunLife — migration 004: let the mobile apps fill the caption cache
--
-- YouTube refuses caption requests from datacenter IPs, so the server can't
-- fetch them. Mobile apps can: there is no CORS on iOS/Android and the phone
-- has an ordinary residential IP. So a phone fetches the captions for a video
-- and writes them here, and from then on every user — including on the web —
-- reads them from this cache.
--
-- Writing is therefore opened to active users (previously admin-only).
-- Updating and deleting stay admin-only, so an existing transcript can't be
-- overwritten or removed by a regular user.
-- ============================================================================

drop policy if exists "transcripts_write_admin" on public.video_transcripts;

drop policy if exists "transcripts_insert_active" on public.video_transcripts;
create policy "transcripts_insert_active" on public.video_transcripts
  for insert with check (public.is_active_user() or public.is_admin());

drop policy if exists "transcripts_update_admin" on public.video_transcripts;
create policy "transcripts_update_admin" on public.video_transcripts
  for update using (public.is_admin()) with check (public.is_admin());

drop policy if exists "transcripts_delete_admin" on public.video_transcripts;
create policy "transcripts_delete_admin" on public.video_transcripts
  for delete using (public.is_admin());
