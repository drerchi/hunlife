// Fetches YouTube captions server-side, fully automatically — no API key,
// no per-video manual work.
//
// The hard part: YouTube blocks datacenter IPs. From Supabase's servers the
// /watch page returns 429 and InnerTube returns 400 ("Precondition check
// failed"), even though the exact same requests succeed from a residential
// IP. Browsers can't paper over it either — they're blocked from calling
// InnerTube by CORS (though they *can* read a signed timedtext URL, which is
// what makes the fallback in the client possible).
//
// So we chain sources, cheapest and most direct first:
//   1. InnerTube        — works if the egress IP isn't blocked.
//   2. Invidious        — open-source YouTube front-ends, permissive CORS,
//                         return clean WebVTT. Public instances come and go,
//                         so we try several.
//   3. Piped            — same idea, different project, returns TTML/VTT.
//   4. /watch scrape    — last resort.
//
// Every success is cached in video_transcripts, so a given video is only ever
// fetched once no matter how many learners open it.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const INNERTUBE_KEY = 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8';

const INVIDIOUS_INSTANCES = [
  'https://inv.nadeko.net',
  'https://invidious.f5.si',
  'https://yewtu.be',
  'https://invidious.nerdvpn.de',
  'https://iv.melmac.space',
];

const PIPED_INSTANCES = [
  'https://api.piped.private.coffee',
  'https://pipedapi.kavin.rocks',
  'https://pipedapi.adminforge.de',
  'https://pipedapi.reallyaweso.me',
];

interface Cue {
  start: number;
  dur: number;
  text: string;
}

// deno-lint-ignore no-explicit-any
type Json = any;

async function withTimeout(url: string, opts: RequestInit = {}, ms = 12000): Promise<Response> {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), ms);
  try {
    return await fetch(url, { ...opts, signal: ctrl.signal });
  } finally {
    clearTimeout(timer);
  }
}

// ---------------------------------------------------------------- parsing --

function cleanText(raw: string): string {
  return raw
    .replace(/<[^>]+>/g, '')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&#39;/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/&nbsp;/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/** Auto-captions repeat lines as they roll; collapse consecutive duplicates. */
function dedupe(cues: Cue[]): Cue[] {
  const out: Cue[] = [];
  for (const cue of cues) {
    const prev = out[out.length - 1];
    if (prev && prev.text === cue.text) {
      prev.dur = Math.max(prev.dur, cue.start + cue.dur - prev.start);
      continue;
    }
    out.push(cue);
  }
  return out;
}

function timeToSeconds(h: string | undefined, m: string, s: string, ms: string): number {
  return (h ? parseInt(h) * 3600 : 0) + parseInt(m) * 60 + parseInt(s) + parseInt(ms) / 1000;
}

function parseVtt(vtt: string): Cue[] {
  const cues: Cue[] = [];
  const blocks = vtt.replace(/\r/g, '').split(/\n{2,}/);
  const timing =
    /(?:(\d+):)?(\d{1,2}):(\d{2})[.,](\d{3})\s*-->\s*(?:(\d+):)?(\d{1,2}):(\d{2})[.,](\d{3})/;

  for (const block of blocks) {
    const m = block.match(timing);
    if (!m) continue;
    const start = timeToSeconds(m[1], m[2], m[3], m[4]);
    const end = timeToSeconds(m[5], m[6], m[7], m[8]);

    const lines = block.split('\n');
    const idx = lines.findIndex((l) => l.includes('-->'));
    const text = cleanText(lines.slice(idx + 1).join(' '));
    if (text) cues.push({ start, dur: Math.max(end - start, 0.3), text });
  }
  return dedupe(cues);
}

function parseTtml(xml: string): Cue[] {
  const cues: Cue[] = [];
  const re = /<p[^>]*begin="([^"]+)"[^>]*end="([^"]+)"[^>]*>([\s\S]*?)<\/p>/g;
  const toSeconds = (v: string): number => {
    const clock = v.match(/(?:(\d+):)?(\d{1,2}):(\d{2})(?:[.,](\d{1,3}))?/);
    if (clock) return timeToSeconds(clock[1], clock[2], clock[3], (clock[4] ?? '0').padEnd(3, '0'));
    return parseFloat(v.replace(/[a-z]/gi, '')) || 0;
  };

  let m: RegExpExecArray | null;
  while ((m = re.exec(xml)) !== null) {
    const start = toSeconds(m[1]);
    const end = toSeconds(m[2]);
    const text = cleanText(m[3].replace(/<br\s*\/?>/g, ' '));
    if (text) cues.push({ start, dur: Math.max(end - start, 0.3), text });
  }
  return dedupe(cues);
}

function parseJson3(body: string): Cue[] {
  const data = JSON.parse(body);
  const cues: Cue[] = (data.events ?? [])
    .filter((e: Json) => Array.isArray(e.segs))
    .map((e: Json) => ({
      start: (e.tStartMs ?? 0) / 1000,
      dur: (e.dDurationMs ?? 0) / 1000,
      text: cleanText(e.segs.map((s: Json) => s.utf8 ?? '').join('')),
    }))
    .filter((c: Cue) => c.text.length > 0);
  return dedupe(cues);
}

/** Hungarian first, then any auto-generated track, then whatever exists. */
function preferHungarian<T>(items: T[], code: (t: T) => string, auto: (t: T) => boolean): T | null {
  if (!items.length) return null;
  return (
    items.find((t) => code(t).toLowerCase().startsWith('hu') && !auto(t)) ??
    items.find((t) => code(t).toLowerCase().startsWith('hu')) ??
    items.find((t) => auto(t)) ??
    items[0]
  );
}

// ------------------------------------------------------------- strategies --

async function viaInnerTube(videoId: string): Promise<{ cues: Cue[]; lang: string; isAuto: boolean }> {
  const res = await withTimeout(`https://www.youtube.com/youtubei/v1/player?key=${INNERTUBE_KEY}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'User-Agent': 'com.google.android.youtube/20.10.38 (Linux; U; Android 14) gzip',
      'X-YouTube-Client-Name': '3',
      'X-YouTube-Client-Version': '20.10.38',
      'Accept-Language': 'hu,en;q=0.9',
    },
    body: JSON.stringify({
      context: {
        client: {
          clientName: 'ANDROID',
          clientVersion: '20.10.38',
          androidSdkVersion: 34,
          osName: 'Android',
          osVersion: '14',
          hl: 'hu',
          gl: 'HU',
        },
      },
      videoId,
      contentCheckOk: true,
      racyCheckOk: true,
    }),
  });
  if (!res.ok) throw new Error(`innertube ${res.status}`);

  const player = await res.json();
  const tracks: Json[] = player?.captions?.playerCaptionsTracklistRenderer?.captionTracks ?? [];
  const track = preferHungarian(tracks, (t) => t.languageCode ?? '', (t) => t.kind === 'asr');
  if (!track) throw new Error('no caption tracks');

  const capRes = await withTimeout(`${track.baseUrl}&fmt=json3`);
  if (!capRes.ok) throw new Error(`timedtext ${capRes.status}`);
  const cues = parseJson3(await capRes.text());
  if (!cues.length) throw new Error('empty track');

  return { cues, lang: track.languageCode ?? 'hu', isAuto: track.kind === 'asr' };
}

async function viaInvidious(
  videoId: string,
  base: string
): Promise<{ cues: Cue[]; lang: string; isAuto: boolean }> {
  const listRes = await withTimeout(`${base}/api/v1/captions/${videoId}`);
  if (!listRes.ok) throw new Error(`list ${listRes.status}`);

  const body = await listRes.text();
  let list: Json;
  try {
    list = JSON.parse(body);
  } catch {
    throw new Error('non-json list');
  }

  const captions: Json[] = list?.captions ?? [];
  const chosen = preferHungarian(
    captions,
    (c) => c.languageCode ?? c.label ?? '',
    (c) => String(c.label ?? '').toLowerCase().includes('auto')
  );
  if (!chosen) throw new Error('no captions');

  // `url` is a path on the same instance; `label` needs encoding.
  const url = chosen.url
    ? `${base}${chosen.url}`
    : `${base}/api/v1/captions/${videoId}?label=${encodeURIComponent(chosen.label)}`;

  const vttRes = await withTimeout(url);
  if (!vttRes.ok) throw new Error(`vtt ${vttRes.status}`);
  const cues = parseVtt(await vttRes.text());
  if (!cues.length) throw new Error('empty vtt');

  return {
    cues,
    lang: chosen.languageCode ?? 'hu',
    isAuto: String(chosen.label ?? '').toLowerCase().includes('auto'),
  };
}

async function viaPiped(
  videoId: string,
  base: string
): Promise<{ cues: Cue[]; lang: string; isAuto: boolean }> {
  const res = await withTimeout(`${base}/streams/${videoId}`);
  if (!res.ok) throw new Error(`streams ${res.status}`);

  const data = await res.json();
  const subs: Json[] = data?.subtitles ?? [];
  const chosen = preferHungarian(subs, (s) => s.code ?? '', (s) => s.autoGenerated === true);
  if (!chosen?.url) throw new Error('no subtitles');

  const subRes = await withTimeout(chosen.url);
  if (!subRes.ok) throw new Error(`sub ${subRes.status}`);

  const text = await subRes.text();
  const cues = text.trimStart().startsWith('WEBVTT') ? parseVtt(text) : parseTtml(text);
  if (!cues.length) throw new Error('empty subtitle');

  return { cues, lang: chosen.code ?? 'hu', isAuto: chosen.autoGenerated === true };
}

async function fetchCaptions(
  videoId: string
): Promise<{ cues: Cue[]; lang: string; isAuto: boolean; via: string }> {
  const attempts: string[] = [];

  const strategies: { name: string; run: () => Promise<{ cues: Cue[]; lang: string; isAuto: boolean }> }[] = [
    { name: 'innertube', run: () => viaInnerTube(videoId) },
    ...INVIDIOUS_INSTANCES.map((base) => ({
      name: `invidious:${new URL(base).hostname}`,
      run: () => viaInvidious(videoId, base),
    })),
    ...PIPED_INSTANCES.map((base) => ({
      name: `piped:${new URL(base).hostname}`,
      run: () => viaPiped(videoId, base),
    })),
  ];

  for (const strategy of strategies) {
    try {
      const result = await strategy.run();
      return { ...result, via: strategy.name };
    } catch (e) {
      attempts.push(`${strategy.name}: ${e instanceof Error ? e.message : e}`);
    }
  }

  throw new Error(`No caption source available. Tried — ${attempts.join(' | ')}`);
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const { youtubeId, videoId } = await req.json();
    if (!youtubeId) throw new Error('youtubeId is required');

    const { cues, isAuto, lang, via } = await fetchCaptions(youtubeId);

    if (videoId) {
      const supabase = createClient(
        Deno.env.get('SUPABASE_URL')!,
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
      );
      await supabase.from('video_transcripts').upsert({
        video_id: videoId,
        lang,
        cues,
        is_auto_generated: isAuto,
        fetched_at: new Date().toISOString(),
      });
    }

    return new Response(JSON.stringify({ cues, lang, isAutoGenerated: isAuto, via }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e instanceof Error ? e.message : e) }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
