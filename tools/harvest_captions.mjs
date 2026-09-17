#!/usr/bin/env node
// Harvests YouTube captions for every video in the catalogue and stores them
// in Supabase, where the web app reads them from cache.
//
// Why this exists: YouTube blocks caption fetching from datacenter IPs, so the
// Supabase Edge Function gets 429/400 no matter how the request is shaped.
// A normal home internet connection is not blocked. This script therefore runs
// on YOUR machine, fetches the captions, and uploads them — after which every
// web visitor gets them instantly from the cache, with no further work.
//
// Run it after adding new videos in the admin panel:
//
//   node tools/harvest_captions.mjs
//
// Needs two environment variables (never commit them):
//   SUPABASE_URL              https://<ref>.supabase.co
//   SUPABASE_SERVICE_KEY      service_role key (server-side only!)

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;

if (!SUPABASE_URL || !SERVICE_KEY) {
  console.error('Set SUPABASE_URL and SUPABASE_SERVICE_KEY first.');
  process.exit(1);
}

const INNERTUBE_KEY = 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const rest = (path, init = {}) =>
  fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    ...init,
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      'Content-Type': 'application/json',
      ...(init.headers ?? {}),
    },
  });

async function playerResponse(videoId) {
  const res = await fetch(`https://www.youtube.com/youtubei/v1/player?key=${INNERTUBE_KEY}`, {
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
  if (!res.ok) throw new Error(`player ${res.status}`);
  return res.json();
}

const clean = (s) => String(s).replace(/\s+/g, ' ').trim();

const decodeEntities = (s) =>
  s
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&#39;/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/&#(\d+);/g, (_, d) => String.fromCharCode(Number(d)));

function push(out, cue) {
  const prev = out[out.length - 1];
  if (prev && prev.text === cue.text) return; // rolling auto-caption duplicates
  out.push(cue);
}

function parseCaptions(body) {
  const out = [];

  if (!body.trimStart().startsWith('<')) {
    for (const e of JSON.parse(body).events ?? []) {
      if (!Array.isArray(e.segs)) continue;
      const text = clean(e.segs.map((s) => s.utf8 ?? '').join(''));
      if (text) push(out, { start: (e.tStartMs ?? 0) / 1000, dur: (e.dDurationMs ?? 0) / 1000, text });
    }
    return out;
  }

  // timedtext format="3": <p t="8679" d="3321"><s>word</s></p>, milliseconds.
  const pRe = /<p\s+t="(\d+)"(?:\s+d="(\d+)")?[^>]*>([\s\S]*?)<\/p>/g;
  let m;
  while ((m = pRe.exec(body)) !== null) {
    const text = clean(decodeEntities(m[3].replace(/<[^>]+>/g, '')));
    if (text) {
      push(out, {
        start: parseInt(m[1]) / 1000,
        dur: (m[2] ? parseInt(m[2]) : 2000) / 1000,
        text,
      });
    }
  }
  if (out.length) return out;

  // Legacy: <text start="8.6" dur="3.3">words</text>, seconds.
  const legacyRe = /<text start="([\d.]+)"(?:\s+dur="([\d.]+)")?[^>]*>([\s\S]*?)<\/text>/g;
  while ((m = legacyRe.exec(body)) !== null) {
    const text = clean(decodeEntities(m[3]).replace(/<[^>]+>/g, ''));
    if (text) push(out, { start: parseFloat(m[1]), dur: parseFloat(m[2] ?? '2'), text });
  }
  return out;
}

async function fetchTrackBody(baseUrl) {
  for (let attempt = 0; attempt < 5; attempt++) {
    const res = await fetch(`${baseUrl}&fmt=json3`);
    if (res.ok) return res.text();
    if (res.status !== 429) throw new Error(`timedtext ${res.status}`);
    await sleep(15000 * (attempt + 1)); // YouTube throttles bursts
  }
  throw new Error('rate limited');
}

const main = async () => {
  const listRes = await rest('videos?select=id,youtube_id,title_uk&order=order_index');
  if (!listRes.ok) throw new Error(`Supabase ${listRes.status}: ${await listRes.text()}`);
  const videos = await listRes.json();

  const existingRes = await rest('video_transcripts?select=video_id');
  const existing = new Set((await existingRes.json()).map((r) => r.video_id));

  console.log(`${videos.length} videos, ${existing.size} already have captions\n`);

  let added = 0;
  for (const v of videos) {
    if (existing.has(v.id)) {
      console.log(`- ${v.title_uk} — already cached`);
      continue;
    }
    process.stdout.write(`* ${v.title_uk} ... `);
    try {
      const player = await playerResponse(v.youtube_id);
      const tracks = player?.captions?.playerCaptionsTracklistRenderer?.captionTracks ?? [];
      if (!tracks.length) {
        console.log('no captions on YouTube');
        continue;
      }

      const track =
        tracks.find((t) => t.languageCode?.startsWith('hu') && t.kind !== 'asr') ??
        tracks.find((t) => t.languageCode?.startsWith('hu')) ??
        tracks[0];

      const cues = parseCaptions(await fetchTrackBody(track.baseUrl));
      if (!cues.length) {
        console.log('empty track');
        continue;
      }

      const up = await rest('video_transcripts', {
        method: 'POST',
        headers: { Prefer: 'resolution=merge-duplicates' },
        body: JSON.stringify({
          video_id: v.id,
          lang: track.languageCode ?? 'hu',
          cues,
          is_auto_generated: track.kind === 'asr',
          fetched_at: new Date().toISOString(),
        }),
      });
      if (!up.ok) throw new Error(`upload ${up.status}: ${await up.text()}`);

      console.log(`OK — ${track.languageCode}${track.kind === 'asr' ? ' (auto)' : ''}, ${cues.length} lines`);
      added++;
      await sleep(6000); // stay well under YouTube's rate limit
    } catch (e) {
      console.log(`failed: ${e.message}`);
    }
  }

  console.log(`\nDone. Added captions for ${added} video(s).`);
};

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
