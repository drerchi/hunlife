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

interface Picture {
  imageUrl: string;
  thumbUrl: string | null;
  attribution: string | null;
  license: string | null;
  sourceUrl: string | null;
  provider: string;
}

/// Abstract words ("thank you", "because") have no sensible picture, and a
/// wrong one is worse than none. Only look up things that can be depicted.
function looksDepictable(term: string): boolean {
  const t = term.trim().toLowerCase();
  if (!t || t.length < 2) return false;
  if (t.split(/\s+/).length > 3) return false;
  return true;
}

async function fromOpenverse(term: string): Promise<Picture | null> {
  // CC0 and public-domain only. Those carry no attribution requirement, which
  // is what lets the app show a clean picture with no credit line underneath.
  // (BY / BY-SA images would legally have to be credited on screen.)
  const url =
    'https://api.openverse.org/v1/images/' +
    `?q=${encodeURIComponent(term)}&page_size=5&license=cc0,pdm&mature=false`;

  const res = await fetch(url, { headers: { 'User-Agent': UA } });
  if (!res.ok) return null;

  const json = await res.json();
  const hit = (json.results ?? [])[0];
  if (!hit) return null;

  const creator = hit.creator ? `${hit.creator}` : null;
  const license = hit.license ? `${hit.license}${hit.license_version ? ' ' + hit.license_version : ''}`.toUpperCase() : null;

  return {
    imageUrl: hit.thumbnail ?? hit.url,
    thumbUrl: hit.thumbnail ?? null,
    attribution: creator,
    license,
    sourceUrl: hit.foreign_landing_url ?? hit.url ?? null,
    provider: 'openverse',
  };
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

    // 2. Pick the best search term. English gives the best image results;
    //    fall back to whatever we were given.
    let searchTerm = english?.trim();
    if (!searchTerm) {
      const { data: translation } = await supabase
        .from('translation_cache')
        .select('english_text')
        .eq('source_text', key)
        .maybeSingle();
      searchTerm = translation?.english_text ?? undefined;
    }
    searchTerm = searchTerm || ukrainian?.trim() || key;

    if (!looksDepictable(searchTerm)) {
      return new Response(JSON.stringify({ imageUrl: null, reason: 'not depictable' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 3. Look it up, widening the search before giving up: the English gloss
    //    finds the most images, but the other forms sometimes rescue a word.
    const terms = [
      searchTerm,
      ...(ukrainian ? [ukrainian.trim()] : []),
      key,
      // Multi-word phrases rarely match; the first word usually does.
      ...(searchTerm.includes(' ') ? [searchTerm.split(' ')[0]] : []),
    ].filter((t, i, all) => t && looksDepictable(t) && all.indexOf(t) === i);

    let picture: Picture | null = null;
    for (const term of terms) {
      picture = await fromOpenverse(term);
      if (picture) break;
    }

    if (!picture) {
      return new Response(JSON.stringify({ imageUrl: null, reason: 'no image found' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 4. Cache for everyone else.
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
