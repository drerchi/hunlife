import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/video.dart';

/// Fetches YouTube captions directly from the device.
///
/// This only works off the web. YouTube refuses caption requests from
/// datacenter IPs (so the Supabase edge function can't do it) and sends no
/// CORS headers (so a browser can't either). A phone has neither problem: no
/// CORS on iOS/Android, and an ordinary residential IP — so the mobile app can
/// fetch captions for *any* video, then cache them so web users benefit too.
class YoutubeCaptionService {
  const YoutubeCaptionService();

  /// Public key embedded in YouTube's own clients.
  static const String _innertubeKey = 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8';

  /// Whether this platform can fetch captions directly.
  static bool get isSupported => !kIsWeb;

  Future<List<TranscriptCue>> fetchCaptions(String youtubeId) async {
    if (!isSupported) {
      throw UnsupportedError('Direct caption fetching is blocked by CORS on the web.');
    }

    final track = await _bestTrack(youtubeId);
    if (track == null) throw Exception('This video has no captions.');

    final res = await http.get(Uri.parse('${track.baseUrl}&fmt=json3'));
    if (res.statusCode != 200) throw Exception('Caption download failed (${res.statusCode}).');

    final body = utf8.decode(res.bodyBytes);
    final cues = body.trimLeft().startsWith('<') ? _parseTimedTextXml(body) : _parseJson3(body);
    if (cues.isEmpty) throw Exception('Caption track was empty.');
    return cues;
  }

  Future<_CaptionTrack?> _bestTrack(String youtubeId) async {
    // The Android client is the one YouTube still answers; the web client now
    // returns UNPLAYABLE without a proof-of-origin token.
    final res = await http.post(
      Uri.parse('https://www.youtube.com/youtubei/v1/player?key=$_innertubeKey'),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'com.google.android.youtube/20.10.38 (Linux; U; Android 14) gzip',
        'X-YouTube-Client-Name': '3',
        'X-YouTube-Client-Version': '20.10.38',
        'Accept-Language': 'hu,en;q=0.9',
      },
      body: jsonEncode({
        'context': {
          'client': {
            'clientName': 'ANDROID',
            'clientVersion': '20.10.38',
            'androidSdkVersion': 34,
            'osName': 'Android',
            'osVersion': '14',
            'hl': 'hu',
            'gl': 'HU',
          },
        },
        'videoId': youtubeId,
        'contentCheckOk': true,
        'racyCheckOk': true,
      }),
    );
    if (res.statusCode != 200) throw Exception('YouTube refused the request (${res.statusCode}).');

    final player = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final tracks = (player['captions']?['playerCaptionsTracklistRenderer']?['captionTracks']
            as List<dynamic>? ??
        const [])
        .cast<Map<String, dynamic>>()
        .map(_CaptionTrack.fromJson)
        .toList();

    if (tracks.isEmpty) return null;

    // Prefer real Hungarian subtitles, then Hungarian auto-captions, then any.
    for (final t in tracks) {
      if (t.languageCode.startsWith('hu') && !t.isAuto) return t;
    }
    for (final t in tracks) {
      if (t.languageCode.startsWith('hu')) return t;
    }
    return tracks.first;
  }

  /// Collapses the duplicate lines auto-captions emit as they roll.
  List<TranscriptCue> _dedupe(List<TranscriptCue> cues) {
    final out = <TranscriptCue>[];
    for (final cue in cues) {
      if (out.isNotEmpty && out.last.text == cue.text) continue;
      out.add(cue);
    }
    return out;
  }

  List<TranscriptCue> _parseJson3(String body) {
    final data = jsonDecode(body) as Map<String, dynamic>;
    final events = data['events'] as List<dynamic>? ?? const [];
    final cues = <TranscriptCue>[];

    for (final raw in events) {
      final event = raw as Map<String, dynamic>;
      final segs = event['segs'] as List<dynamic>?;
      if (segs == null) continue;

      final text = _clean(segs.map((s) => (s as Map)['utf8'] ?? '').join());
      if (text.isEmpty) continue;

      cues.add(TranscriptCue(
        start: ((event['tStartMs'] as num?) ?? 0) / 1000,
        duration: ((event['dDurationMs'] as num?) ?? 0) / 1000,
        text: text,
      ));
    }
    return _dedupe(cues);
  }

  /// timedtext format="3": <p t="8679" d="3321"><s>word</s></p>, milliseconds.
  List<TranscriptCue> _parseTimedTextXml(String body) {
    final cues = <TranscriptCue>[];
    final paragraph = RegExp(r'<p\s+t="(\d+)"(?:\s+d="(\d+)")?[^>]*>([\s\S]*?)</p>');

    for (final m in paragraph.allMatches(body)) {
      final text = _clean(_stripTags(m.group(3) ?? ''));
      if (text.isEmpty) continue;
      cues.add(TranscriptCue(
        start: int.parse(m.group(1)!) / 1000,
        duration: (int.tryParse(m.group(2) ?? '') ?? 2000) / 1000,
        text: text,
      ));
    }
    if (cues.isNotEmpty) return _dedupe(cues);

    // Legacy shape: <text start="8.6" dur="3.3">words</text>, seconds.
    final legacy = RegExp(r'<text start="([\d.]+)"(?:\s+dur="([\d.]+)")?[^>]*>([\s\S]*?)</text>');
    for (final m in legacy.allMatches(body)) {
      final text = _clean(_stripTags(m.group(3) ?? ''));
      if (text.isEmpty) continue;
      cues.add(TranscriptCue(
        start: double.parse(m.group(1)!),
        duration: double.tryParse(m.group(2) ?? '') ?? 2,
        text: text,
      ));
    }
    return _dedupe(cues);
  }

  String _stripTags(String s) => s.replaceAll(RegExp(r'<[^>]+>'), '');

  String _clean(String s) {
    return s
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&#39;', "'")
        .replaceAll('&quot;', '"')
        .replaceAll('&nbsp;', ' ')
        .replaceAllMapped(
          RegExp(r'&#(\d+);'),
          (m) => String.fromCharCode(int.parse(m.group(1)!)),
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _CaptionTrack {
  final String baseUrl;
  final String languageCode;
  final bool isAuto;

  const _CaptionTrack({
    required this.baseUrl,
    required this.languageCode,
    required this.isAuto,
  });

  factory _CaptionTrack.fromJson(Map<String, dynamic> json) => _CaptionTrack(
        baseUrl: json['baseUrl'] as String,
        languageCode: (json['languageCode'] as String?) ?? '',
        isAuto: json['kind'] == 'asr',
      );
}
