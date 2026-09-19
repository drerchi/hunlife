// Temporary diagnostic: which free translation engines actually answer from
// Supabase's datacenter IP? Testing this locally is misleading because a
// residential IP is treated very differently (Google's translate endpoint
// answers at home but returns nothing here).
//
// Delete once an engine has been chosen.

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const WORD = 'család'; // "family" — MyMemory infamously renders this "headset"

async function probe(
  name: string,
  run: () => Promise<string>
): Promise<{ name: string; result: string }> {
  try {
    const result = await run();
    return { name, result: result.slice(0, 80) };
  } catch (e) {
    return { name, result: 'ERR ' + String(e instanceof Error ? e.message : e).slice(0, 70) };
  }
}

async function json(url: string, init?: RequestInit) {
  const res = await fetch(url, init);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  const results = await Promise.all([
    probe('google gtx', async () => {
      const j = await json(
        `https://translate.googleapis.com/translate_a/single?client=gtx&sl=hu&tl=uk&dt=t&q=${encodeURIComponent(WORD)}`,
        { headers: { 'User-Agent': 'Mozilla/5.0' } }
      );
      return (j?.[0] ?? []).map((c: unknown[]) => c?.[0] ?? '').join('') || '(empty)';
    }),

    probe('google dict-chrome-ex', async () => {
      const j = await json(
        `https://clients5.google.com/translate_a/t?client=dict-chrome-ex&sl=hu&tl=uk&q=${encodeURIComponent(WORD)}`,
        { headers: { 'User-Agent': 'Mozilla/5.0' } }
      );
      return JSON.stringify(j).slice(0, 80);
    }),

    probe('lingva.ml', async () => {
      const j = await json(`https://lingva.ml/api/v1/hu/uk/${encodeURIComponent(WORD)}`);
      return j?.translation ?? '(empty)';
    }),

    probe('lingva.lunar.icu', async () => {
      const j = await json(`https://lingva.lunar.icu/api/v1/hu/uk/${encodeURIComponent(WORD)}`);
      return j?.translation ?? '(empty)';
    }),

    probe('libretranslate.de', async () => {
      const j = await json('https://libretranslate.de/translate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ q: WORD, source: 'hu', target: 'uk', format: 'text' }),
      });
      return j?.translatedText ?? '(empty)';
    }),

    probe('mymemory', async () => {
      const j = await json(
        `https://api.mymemory.translated.net/get?q=${encodeURIComponent(WORD)}&langpair=hu|uk`
      );
      return j?.responseData?.translatedText ?? '(empty)';
    }),
  ]);

  return new Response(JSON.stringify({ word: WORD, results }, null, 1), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
});
