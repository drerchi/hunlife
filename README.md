# HunLife

Learn Hungarian in Ukrainian — interactive lessons, flashcards, video lessons
with clickable subtitles, and dedicated prep for the Hungarian citizenship
interview. Flutter (web now, Android/iOS from the same codebase) + Supabase.

## Running it

```bash
flutter pub get
flutter run -d chrome --dart-define-from-file=env.json
```

`env.json` (gitignored) holds your Supabase URL and anon key. The Flutter SDK
lives at `C:\flutter` on this machine; add `C:\flutter\bin` to PATH.

Build for deployment:

```bash
flutter build web --dart-define-from-file=env.json   # output: build/web
```

## What's in the app

- **Auth** — email/password sign up, sign in, password reset.
- **Topics & interactive lessons** — each lesson is a sequence of steps:
  a phrase to learn (tap to hear it, tap to reveal the translation), a short
  note, or a multiple-choice check. Progress bar, score summary, and the
  "next" button stays disabled until a question is answered.
- **Flashcards** — flip to reveal, with per-user "still learning / know it".
- **Video lessons** — any YouTube video can be added by pasting its link
  (the title is fetched automatically via oEmbed). Videos play through
  YouTube's own embedded player, with a time-synced transcript beside them.
  Tapping any word pauses the video and shows its translation, which can be
  edited and saved to the learner's vocabulary.
- **Vocabulary** — saved words become a personal list *and* a flashcard deck.
- **Citizenship prep** — likely interview questions grouped by category,
  Hungarian and Ukrainian side by side, each readable aloud.
- **Access control** — per profile `is_blocked` and `access_until`
  (null = unlimited). Blocked/expired users can sign in and see their status
  but can't open content — enforced in the UI *and* in Postgres RLS.
- **Admin panel** (Профіль → Панель адміністратора, `role = 'admin'` only) —
  user stats, block/unblock, grant limited or unlimited access, promote
  admins, and full content management including videos.

## Database

Run once in the Supabase SQL editor, in order:

1. `supabase/schema.sql` — core tables + RLS
2. `supabase/migrations/002_videos_vocabulary.sql` — videos, transcripts,
   translation cache, vocabulary
3. `supabase/migrations/003_lesson_steps.sql` — interactive lesson steps
4. `supabase/seed.sql` — optional starter content

Make yourself admin after signing up once:

```sql
update public.profiles set role = 'admin' where email = 'you@example.com';
```

## Edge Functions

```bash
supabase functions deploy translate          --project-ref <ref>
supabase functions deploy youtube-transcript --project-ref <ref>
```

- **translate** — Hungarian→Ukrainian via MyMemory (no API key), with an
  English gloss as a second opinion, and every result cached in
  `translation_cache` so a word is only ever fetched once.
- **youtube-transcript** — tries InnerTube, then Invidious/Piped mirrors.
  See the caveat below.

## Video subtitles: the one real constraint

**YouTube only serves captions to residential IPs.** From any datacenter
(Supabase Edge Functions, Invidious/Piped public instances, CORS proxies) it
answers `429` or `400` — the identical request succeeds from home internet.
Browsers can't paper over it either: YouTube sends no CORS headers for
InnerTube, and the old unsigned `timedtext` endpoint now returns empty.

Tools like Language Reactor work around this by being **browser extensions
running on youtube.com itself** (same-origin), which a website cannot be.

There are two ways captions get into the cache, and once they're there every
user reads them from Supabase instantly — including on the web.

**On mobile, automatically, for any video.** iOS/Android have no CORS and the
phone has an ordinary residential IP, so the app fetches captions itself
(`lib/services/youtube_caption_service.dart`) and writes them back to the
shared cache. This is why "any video" works on mobile but not on web.

**On web, by running the harvester** from a normal internet connection:

```bash
SUPABASE_URL=https://<ref>.supabase.co \
SUPABASE_SERVICE_KEY=<service_role key> \
node tools/harvest_captions.mjs
```

It fills in every video that's missing captions, skips the rest, handles both
YouTube caption formats and backs off when rate-limited. On Windows there's a
gitignored `tools/harvest.local.cmd` that sets the variables and runs it, so
it can be double-clicked or driven by a scheduled task.

Note that YouTube rate-limits bursts even from residential IPs — if a run
reports "rate limited", wait a while and run it again.

## Pronunciation

Every learner hears the **same real Hungarian voice**, regardless of their
device. The `speak` edge function synthesises the audio server-side and caches
the MP3 in the public `tts` storage bucket, keyed by a hash of the text — so a
phrase is generated once and afterwards served straight from the CDN.

This replaced an earlier approach that used the device's own speech engine.
That turned out to be unusable in practice: most Windows machines have no
Hungarian voice installed at all, so Hungarian was read aloud with an English
voice, teaching learners the wrong pronunciation. The device engine is kept
only as an offline fallback, and if it has no Hungarian voice the app now says
so instead of mispronouncing silently.

Deploy it with:

```bash
supabase functions deploy speak --project-ref <ref>
```

## Security notes

- `env.json` holds only the **anon/publishable** key — safe in client code.
- The **service_role key must never appear in `lib/`**. It bypasses RLS
  entirely. It belongs only in server-side tooling such as
  `tools/harvest_captions.mjs`, passed as an environment variable.

## Project layout

```
lib/
  core/        theme, router, shared widgets, Supabase config
  models/      plain data classes
  services/    Supabase queries, TTS, transcript parsing
  providers/   Riverpod wiring
  features/    auth, home, topics, lessons, flashcards, videos,
               vocabulary, citizenship, account, admin, blocked
supabase/
  schema.sql, migrations/, seed.sql, functions/
tools/
  harvest_captions.mjs
```

## Tests

```bash
flutter test      # transcript parsing, word normalisation, login rendering
flutter analyze
```

## Adding Android/iOS later

No code changes needed — `android/` and `ios/` are already generated:

```bash
flutter run -d <device> --dart-define-from-file=env.json
```
