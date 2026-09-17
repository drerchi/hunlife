// Generates real Hungarian speech audio, the same for every user.
//
// Device speech engines are not good enough here: whether a learner hears
// actual Hungarian depends on what voices their OS happens to have installed,
// and most Windows machines have none — so Hungarian gets read with an English
// voice, which teaches the wrong pronunciation.
//
// Instead we synthesise server-side and cache the MP3 in Supabase Storage.
// The first request for a phrase generates it; everyone afterwards gets the
// identical audio straight from the CDN.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const BUCKET = 'tts';

/// The endpoint accepts roughly 200 characters at a time, so split longer
/// text on sentence/word boundaries and concatenate the MP3 frames.
function chunk(text: string, limit = 180): string[] {
  const words = text.split(/\s+/);
  const out: string[] = [];
  let current = '';

  for (const word of words) {
    if ((current + ' ' + word).trim().length > limit) {
      if (current) out.push(current.trim());
      current = word;
    } else {
      current = (current + ' ' + word).trim();
    }
  }
  if (current) out.push(current.trim());
  return out.length ? out : [text];
}

async function synthesise(text: string, lang: string): Promise<Uint8Array> {
  const parts: Uint8Array[] = [];

  for (const piece of chunk(text)) {
    const url =
      'https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob' +
      `&tl=${encodeURIComponent(lang)}&q=${encodeURIComponent(piece)}`;

    const res = await fetch(url, {
      headers: {
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
        Referer: 'https://translate.google.com/',
      },
    });
    if (!res.ok) throw new Error(`speech service returned ${res.status}`);

    const buf = new Uint8Array(await res.arrayBuffer());
    if (buf.length < 500) throw new Error('speech service returned empty audio');
    parts.push(buf);
  }

  const total = parts.reduce((n, p) => n + p.length, 0);
  const merged = new Uint8Array(total);
  let offset = 0;
  for (const p of parts) {
    merged.set(p, offset);
    offset += p.length;
  }
  return merged;
}

async function keyFor(text: string, lang: string): Promise<string> {
  const data = new TextEncoder().encode(`${lang}:${text}`);
  const digest = await crypto.subtle.digest('SHA-1', data);
  const hex = Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
  return `${lang}/${hex}.mp3`;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const { text, lang = 'hu' } = await req.json();
    if (!text || typeof text !== 'string') throw new Error('text is required');

    const trimmed = text.trim().replace(/\s+/g, ' ');
    if (!trimmed) throw new Error('text is empty');
    if (trimmed.length > 1000) throw new Error('text too long');

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    const path = await keyFor(trimmed, lang);
    const publicUrl = supabase.storage.from(BUCKET).getPublicUrl(path).data.publicUrl;

    // Already generated? Hand back the cached file.
    const head = await fetch(publicUrl, { method: 'HEAD' });
    if (head.ok) {
      return new Response(JSON.stringify({ url: publicUrl, cached: true }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const audio = await synthesise(trimmed, lang);

    const { error } = await supabase.storage.from(BUCKET).upload(path, audio, {
      contentType: 'audio/mpeg',
      upsert: true,
      cacheControl: '31536000',
    });
    if (error) throw new Error(`storage: ${error.message}`);

    return new Response(JSON.stringify({ url: publicUrl, cached: false }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e instanceof Error ? e.message : e) }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
