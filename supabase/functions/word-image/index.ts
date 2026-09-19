// Finds a picture for a vocabulary word.
//
// Searching by the English gloss gives far better results than by Hungarian,
// so we reuse the English translation already cached by the `translate`
// function when it's available.
//
// Sources are Openverse (Creative Commons image search) with a Wikipedia
// fallback. Both are free and need no API key. Results — including the
// attribution the licence requires — are cached, so a word costs one lookup
// ever, no matter how many learners see it.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const UA = 'HunLife/1.0 (Hungarian learning app)';
const IMAGE_BUCKET = 'word-images';

/// Copies the picture into our own storage and returns that URL.
///
/// Openverse serves images without an Access-Control-Allow-Origin header, and
/// Flutter web loads images over XHR — so every picture failed in the browser
/// and fell back to a placeholder tile, even though the URLs worked fine
/// server-side. Re-hosting sidesteps CORS entirely and loads faster too.
///
/// `errors` is passed in per-request rather than kept at module scope: Deno
/// reuses a warm isolate across requests, so a module-level array would keep
/// accumulating messages from earlier, unrelated lookups.
async function mirrorToStorage(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  sourceUrl: string,
  key: string,
  errors: string[]
): Promise<string | null> {
  try {
    const res = await fetch(sourceUrl, { headers: { 'User-Agent': UA } });
    if (!res.ok) {
      errors.push(`fetch ${res.status}`);
      return null;
    }

    const contentType = res.headers.get('content-type') ?? 'image/jpeg';
    if (!contentType.startsWith('image/')) {
      errors.push(`type ${contentType}`);
      return null;
    }

    const bytes = new Uint8Array(await res.arrayBuffer());
    if (bytes.length < 500 || bytes.length > 5_000_000) {
      errors.push(`size ${bytes.length}`);
      return null;
    }

    const extension = contentType.includes('png')
      ? 'png'
      : contentType.includes('webp')
        ? 'webp'
        : contentType.includes('gif')
          ? 'gif'
          : 'jpg';

    // Storage keys must be ASCII. Hungarian words are full of á/ö/ű, which is
    // why words like "ház" silently failed to upload while "alma" worked — so
    // hash the word instead of using it as the filename.
    const path = `${await hashKey(key)}.${extension}`;

    const { error } = await supabase.storage.from(IMAGE_BUCKET).upload(path, bytes, {
      contentType,
      upsert: true,
      cacheControl: '31536000',
    });
    if (error) {
      errors.push(`upload ${error.message ?? error}`);
      return null;
    }

    return supabase.storage.from(IMAGE_BUCKET).getPublicUrl(path).data.publicUrl;
  } catch (e) {
    errors.push(`threw ${e instanceof Error ? e.message : e}`);
    return null;
  }
}

async function hashKey(value: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-1', new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

interface Picture {
  imageUrl: string;
  thumbUrl: string | null;
  attribution: string | null;
  license: string | null;
  sourceUrl: string | null;
  provider: string;
}

// Words that recur constantly across lesson content but reliably produce
// junk pictures from a CC0/public-domain pool this small, in both Hungarian
// and English (whichever the check happens to run against):
//  - interrogatives: "how much?", "when?", "which?" have no picture at all.
//  - weekdays/months: there is no photo *of* Tuesday; whatever Openverse
//    returns for it is a coincidence, not a depiction.
//  - abstract quality adjectives ("low", "expensive", "important"): these
//    describe a relationship, not a thing, so there's nothing to photograph
//    that means the word in general rather than one arbitrary example of it.
const NOT_DEPICTABLE = new Set([
  'mennyi', 'hány', 'milyen', 'milyenek', 'hol', 'mikor', 'miért', 'hogyan',
  'ki', 'kicsoda', 'mi', 'melyik', 'hányszor', 'mennyire',
  'hétfő', 'kedd', 'szerda', 'csütörtök', 'péntek', 'szombat', 'vasárnap',
  'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday',
  // Dictionary APIs often gloss days/months as abbreviations ("kedd" -> "Tue"),
  // which slip straight past the full-word blocklist above.
  'mon', 'tue', 'tues', 'wed', 'weds', 'thu', 'thur', 'thurs', 'fri', 'sat', 'sun',
  'január', 'február', 'március', 'április', 'május', 'június', 'július',
  'augusztus', 'szeptember', 'október', 'november', 'december',
  'january', 'february', 'march', 'april', 'june', 'july', 'august',
  'september', 'october',
  'jan', 'feb', 'mar', 'apr', 'jun', 'jul', 'aug', 'sep', 'sept', 'oct', 'nov', 'dec',
  'alacsony', 'magas', 'kicsi', 'kis', 'nagy', 'jó', 'rossz', 'gyors', 'lassú',
  'drága', 'olcsó', 'öreg', 'fiatal', 'szép', 'csúnya', 'nehéz', 'könnyű',
  'erős', 'gyenge', 'közel', 'távol', 'korai', 'késői', 'halk', 'hangos',
  'gazdag', 'szegény', 'tiszta', 'piszkos', 'tele', 'üres', 'helyes',
  'helytelen', 'fontos', 'érdekes', 'unalmas', 'fáradt', 'boldog', 'szomorú',
  'dühös', 'félénk', 'éhes', 'szomjas',
  'low', 'high', 'small', 'big', 'large', 'good', 'bad', 'fast', 'slow',
  'expensive', 'cheap', 'old', 'young', 'beautiful', 'ugly', 'heavy', 'light',
  'strong', 'weak', 'near', 'far', 'early', 'late', 'quiet', 'loud', 'rich',
  'poor', 'clean', 'dirty', 'full', 'empty', 'correct', 'wrong', 'important',
  'interesting', 'boring', 'tired', 'happy', 'sad', 'angry', 'afraid',
  'hungry', 'thirsty', 'difficult', 'easy', 'similar', 'different',
]);

/// Abstract words ("thank you", "because") have no sensible picture, and a
/// wrong one is worse than none. Only look up things that can be depicted.
function looksDepictable(term: string): boolean {
  const t = term.trim().toLowerCase();
  if (!t || t.length < 2) return false;
  if (t.split(/\s+/).length > 3) return false;
  if (t.endsWith('?')) return false;
  if (NOT_DEPICTABLE.has(t)) return false;
  return true;
}

/// Openverse's CC0/public-domain pool is small enough that its own relevance
/// ranking regularly surfaces something only coincidentally related — a
/// photo whose *title* happens to contain the query as a word fragment
/// ("Lowe" matching "low"), not one that depicts it. Matching on whole words
/// only (not bare substrings) in the image's own title or tags is a cheap
/// but effective sanity check that catches most of those before a learner
/// ever sees them.
function matchesQuery(term: string, title: string, tags: string[]): boolean {
  const t = term.trim().toLowerCase();
  if (t.length < 3) return true; // too short to check meaningfully
  const pattern = new RegExp(`\\b${t.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}s?\\b`, 'i');
  return pattern.test(title) || tags.some((tag) => pattern.test(tag));
}

/// Dictionary glosses come dressed up in ways that make terrible search
/// queries: "to eat" (infinitive marker), "bank (river)" (a disambiguation
/// note), "big; large" (alternatives). Searching Openverse for the raw gloss
/// instead of the actual word is a large part of why pictures didn't match —
/// a search for "to eat" finds far less, and far worse, than "eat".
function cleanGloss(term: string): string {
  return term
    .split(/[,;]/)[0]
    .replace(/\([^)]*\)/g, '')
    .replace(/^\s*to\s+/i, '')
    .replace(/^\s*(a|an|the)\s+/i, '')
    // Machine-translation gloss artefacts: a trailing ellipsis ("Working...")
    // or a bare full stop, neither of which belongs in a search query.
    .replace(/\.{2,}\s*$/, '')
    .replace(/\.\s*$/, '')
    .trim();
}

/// Returns several candidates, ranked, instead of just the top hit: the
/// single best-ranked result sometimes fails to download or mirror (dead
/// link, hotlink protection, an SVG masquerading as an image), and giving up
/// at that point is why so many words fell back to a placeholder letter even
/// though Openverse did have a usable picture further down the list.
async function fromOpenverse(term: string, photoOnly: boolean): Promise<Picture[]> {
  // CC0 and public-domain only. Those carry no attribution requirement, which
  // is what lets the app show a clean picture with no credit line underneath.
  // (BY / BY-SA images would legally have to be credited on screen.)
  const url =
    'https://api.openverse.org/v1/images/' +
    `?q=${encodeURIComponent(term)}&page_size=20&license=cc0,pdm&mature=false` +
    (photoOnly ? '&category=photograph' : '');

  const res = await fetch(url, { headers: { 'User-Agent': UA } });
  if (!res.ok) return [];

  const json = await res.json();
  // deno-lint-ignore no-explicit-any
  const hits: any[] = json.results ?? [];

  return hits
    // SVGs are diagrams/icons/logos (a UML class diagram for "bank account",
    // a pictogram for "work"), never a photo of the actual thing.
    .filter((hit) => hit.filetype !== 'svg')
    // Tiny images are almost always icons, logos or clipart rather than an
    // actual photo/illustration of the word — a frequent source of pictures
    // that technically loaded but plainly didn't match.
    .filter((hit) => {
      const w = hit.width ?? 0;
      const h = hit.height ?? 0;
      return (w === 0 && h === 0) || (w >= 200 && h >= 150);
    })
    // The CC0/PD pool is thin enough that Openverse's own relevance ranking
    // regularly surfaces images that share nothing with the query but a
    // coincidental filename fragment. Requiring the query to actually show
    // up in the picture's own title or tags is what catches those before a
    // learner sees a bank-account word illustrated with a random screenshot.
    .filter((hit) => {
      // deno-lint-ignore no-explicit-any
      const tags = ((hit.tags ?? []) as any[]).map((t) => t?.name ?? '').filter(Boolean);
      return matchesQuery(term, hit.title ?? '', tags);
    })
    .map((hit) => {
      const creator = hit.creator ? `${hit.creator}` : null;
      const license = hit.license
        ? `${hit.license}${hit.license_version ? ' ' + hit.license_version : ''}`.toUpperCase()
        : null;
      return {
        imageUrl: hit.thumbnail ?? hit.url,
        thumbUrl: hit.thumbnail ?? null,
        attribution: creator,
        license,
        sourceUrl: hit.foreign_landing_url ?? hit.url ?? null,
        provider: 'openverse',
      };
    });
}

/// A free, keyless gloss, used purely to build a better Openverse query. Word
/// content authored for lessons/flashcards never runs through the on-device
/// translator, so `translation_cache.english_text` is usually empty for it —
/// leaving Openverse to be searched with a Ukrainian or raw Hungarian query,
/// which is why pictures for that content in particular so rarely matched.
async function fetchGloss(word: string, from: string): Promise<string | null> {
  try {
    const url = new URL('https://api.mymemory.translated.net/get');
    url.searchParams.set('q', word);
    url.searchParams.set('langpair', `${from}|en`);
    const email = Deno.env.get('MYMEMORY_EMAIL');
    if (email) url.searchParams.set('de', email);

    const res = await fetch(url.toString());
    if (!res.ok) return null;
    const json = await res.json();
    const text = json?.responseData?.translatedText as string | undefined;
    if (!text || text.toUpperCase().includes('MYMEMORY WARNING')) return null;
    return text.trim() || null;
  } catch {
    return null;
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const { word, english, ukrainian } = await req.json();
    if (!word || typeof word !== 'string') throw new Error('word is required');

    const key = word.trim().toLowerCase();
    if (!key) throw new Error('word is empty');

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    // 1. Cached already?
    const { data: cached } = await supabase
      .from('word_images')
      .select('image_url, thumb_url, attribution, license, source_url, provider')
      .eq('word', key)
      .maybeSingle();

    if (cached) {
      return new Response(
        JSON.stringify({
          imageUrl: cached.image_url,
          thumbUrl: cached.thumb_url,
          attribution: cached.attribution,
          license: cached.license,
          sourceUrl: cached.source_url,
          provider: cached.provider,
          cached: true,
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 2. Pick the best search term. English gives by far the best image
    //    results; a raw Hungarian or Ukrainian query against an English-
    //    dominated CC0/PD photo library rarely matches the actual word,
    //    which was the single biggest cause of wrong or missing pictures.
    let searchTerm: string | undefined = english?.trim();
    let englishForCache: string | null = null;
    if (!searchTerm) {
      const { data: translation } = await supabase
        .from('translation_cache')
        .select('english_text')
        .eq('source_text', key)
        .maybeSingle();
      searchTerm = translation?.english_text ?? undefined;
    }
    if (!searchTerm) {
      // Lesson/flashcard content never passes through the on-device
      // translator, so it usually has no cached gloss at all — fetch one
      // instead of falling straight back to a Hungarian/Ukrainian query.
      //
      // Gloss the already-known-correct Ukrainian sense when we have it,
      // rather than the ambiguous Hungarian word: Hungarian "villa" means
      // both "fork" and "villa" (a house), and asking a dictionary to gloss
      // it cold picked the house — the app already knows this particular
      // one means "виделка" (fork), so translating *that* resolves the
      // ambiguity instead of guessing the wrong sense.
      searchTerm = ukrainian?.trim()
        ? (await fetchGloss(ukrainian.trim(), 'uk')) ?? undefined
        : undefined;
      searchTerm ??= (await fetchGloss(key, 'hu')) ?? undefined;
      if (searchTerm) englishForCache = searchTerm;
    }
    searchTerm = cleanGloss(searchTerm || ukrainian?.trim() || key);

    // A freshly-fetched gloss is worth keeping for next time — both for this
    // function and for the translator, which shows it as a second opinion.
    if (englishForCache && ukrainian?.trim()) {
      await supabase.from('translation_cache').upsert({
        source_text: key,
        source_lang: 'hu',
        target_lang: 'uk',
        translated_text: ukrainian.trim(),
        english_text: englishForCache,
      });
    }

    if (!looksDepictable(searchTerm)) {
      return new Response(JSON.stringify({ imageUrl: null, reason: 'not depictable' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 3. Look it up, widening the search before giving up: the English gloss
    //    finds the most images, but the other forms sometimes rescue a word.
    const terms = [
      searchTerm,
      ...(ukrainian ? [cleanGloss(ukrainian.trim())] : []),
      key,
      // Multi-word phrases rarely match; the first word usually does.
      ...(searchTerm.includes(' ') ? [searchTerm.split(' ')[0]] : []),
    ].filter((t, i, all) => t && looksDepictable(t) && all.indexOf(t) === i);

    // 4. Re-host the first candidate that actually downloads and uploads.
    //
    // We must NOT fall back to Openverse's own URL: it sends no CORS header,
    // so the browser would fail to load it and show a placeholder anyway.
    // Trying several ranked candidates (not just the single top hit) before
    // giving up is what fixes most of the "just shows a letter" cases —
    // the best-ranked picture quite often turns out to be a dead link, a
    // hotlink-protected host, or an SVG mislabelled as a photo.
    const errors: string[] = [];
    let picture: Picture | null = null;
    let hostedUrl: string | null = null;
    let tried = 0;

    // Real photographs first; illustrations/vector art (UML diagrams, memes,
    // clip art) only as a last resort, since they're the other big source of
    // pictures that technically matched the query but taught nothing useful.
    outer: for (const photoOnly of [true, false]) {
      for (const term of terms) {
        const candidates = await fromOpenverse(term, photoOnly);
        for (const candidate of candidates) {
          for (const url of [candidate.thumbUrl, candidate.imageUrl]) {
            if (!url) continue;
            tried++;
            hostedUrl = await mirrorToStorage(supabase, url, key, errors);
            if (hostedUrl) {
              picture = candidate;
              break outer;
            }
          }
        }
      }
    }

    if (!picture || !hostedUrl) {
      return new Response(
        JSON.stringify({
          imageUrl: null,
          reason: tried > 0 ? 'could not host image' : 'no image found',
          detail: errors.join('; '),
          tried,
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }
    picture = { ...picture, imageUrl: hostedUrl, thumbUrl: hostedUrl };

    await supabase.from('word_images').upsert({
      word: key,
      image_url: picture.imageUrl,
      thumb_url: picture.thumbUrl,
      attribution: picture.attribution,
      license: picture.license,
      source_url: picture.sourceUrl,
      provider: picture.provider,
    });

    return new Response(JSON.stringify({ ...picture, cached: false }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e instanceof Error ? e.message : e) }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
