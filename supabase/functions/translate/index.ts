// Hungarian -> Ukrainian word/phrase translation with caching.
//
// Uses MyMemory (no API key, rate-limited). Every result is cached in
// translation_cache, so a word is only ever fetched from the API once no
// matter how many learners click it.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const { text, sourceLang = 'hu', targetLang = 'uk' } = await req.json();
    if (!text || typeof text !== 'string') throw new Error('text is required');

    const source = text.trim().toLowerCase();
    if (!source) throw new Error('text is empty');

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    // 1. Cache hit?
    const { data: cached } = await supabase
      .from('translation_cache')
      .select('translated_text, english_text')
      .eq('source_text', source)
      .eq('source_lang', sourceLang)
      .eq('target_lang', targetLang)
      .maybeSingle();

    if (cached?.translated_text) {
      return new Response(
        JSON.stringify({
          translation: cached.translated_text,
          english: cached.english_text ?? null,
          cached: true,
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 2. Translate.
    //
    // Google's endpoint is used first because its Hungarian→Ukrainian quality
    // is markedly better: MyMemory returned "гарнітура" (headset) for "család"
    // (family), "важкий" (heavy) for "erős" (strong) and "легкий" (light) for
    // "gyenge" (weak) — wrong enough to teach the wrong word. MyMemory stays
    // as a fallback so a lookup still works if Google is unreachable.
    async function google(q: string, from: string, to: string): Promise<string | null> {
      const url =
        'https://translate.googleapis.com/translate_a/single?client=gtx' +
        `&sl=${from}&tl=${to}&dt=t&q=${encodeURIComponent(q)}`;

      const res = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
      if (!res.ok) return null;

      // Shape: [[["translated","source",...], ...], ...]
      const json = await res.json();
      const chunks = json?.[0];
      if (!Array.isArray(chunks)) return null;

      const text = chunks.map((c: Json) => c?.[0] ?? '').join('').trim();
      return text.length ? text : null;
    }

    const email = Deno.env.get('MYMEMORY_EMAIL');

    async function myMemory(q: string, pair: string): Promise<string | null> {
      const url = new URL('https://api.mymemory.translated.net/get');
      url.searchParams.set('q', q);
      url.searchParams.set('langpair', pair);
      if (email) url.searchParams.set('de', email);

      const res = await fetch(url.toString());
      if (!res.ok) return null;
      const json = await res.json();
      const out: string | undefined = json?.responseData?.translatedText;
      if (!out) return null;
      // MyMemory echoes warnings like "MYMEMORY WARNING: ..." when rate limited.
      if (out.toUpperCase().includes('MYMEMORY WARNING')) {
        throw new Error('Daily translation quota reached. Try again tomorrow.');
      }
      return out;
    }

    let via = 'google';
    let googleError: string | null = null;

    let translation = await google(source, sourceLang, targetLang).catch((e) => {
      googleError = String(e instanceof Error ? e.message : e);
      return null;
    });

    if (!translation) {
      via = googleError == null ? 'mymemory (google empty)' : `mymemory (${googleError})`;
      translation = await myMemory(source, `${sourceLang}|${targetLang}`);
    }
    if (!translation) throw new Error('No translation returned');

    // Free hu->uk data is patchy, so we also return an English gloss as a
    // second opinion. The two disagree often enough that showing both (and
    // letting the learner edit before saving) beats trusting either alone.
    let english: string | null = null;
    if (sourceLang === 'hu') {
      try {
        english = (await google(source, 'hu', 'en').catch(() => null)) ??
            (await myMemory(source, 'hu|en'));
      } catch (_) {
        english = null;
      }
    }

    // 3. Cache for next time.
    await supabase.from('translation_cache').upsert({
      source_text: source,
      source_lang: sourceLang,
      target_lang: targetLang,
      translated_text: translation,
      english_text: english,
    });

    return new Response(JSON.stringify({ translation, english, via, cached: false }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e instanceof Error ? e.message : e) }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
