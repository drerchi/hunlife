import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/video.dart';
import 'youtube_caption_service.dart';

class VideoService {
  VideoService(this._client);

  final SupabaseClient _client;

  /// Looks up a video's real title straight from YouTube's oEmbed endpoint,
  /// which — unlike the caption endpoints — is CORS-enabled and works from
  /// the browser. Returns null if the video doesn't exist or is private.
  Future<String?> fetchYoutubeTitle(String youtubeId) async {
    try {
      final uri = Uri.parse(
        'https://www.youtube.com/oembed'
        '?url=https://www.youtube.com/watch?v=$youtubeId&format=json',
      );
      final res = await http.get(uri);
      if (res.statusCode != 200) return null;
      final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return json['title'] as String?;
    } catch (e) {
      debugPrint('oEmbed lookup failed for $youtubeId: $e');
      return null;
    }
  }

  Future<List<Video>> fetchVideos() async {
    final rows = await _client.from('videos').select().order('order_index', ascending: true);
    return rows.map((e) => Video.fromJson(e)).toList();
  }

  Future<Video> createVideo(Video video) async {
    final row = await _client.from('videos').insert(video.toInsertJson()).select().single();
    return Video.fromJson(row);
  }

  Future<Video> updateVideo(String id, Video video) async {
    final row =
        await _client.from('videos').update(video.toInsertJson()).eq('id', id).select().single();
    return Video.fromJson(row);
  }

  Future<void> deleteVideo(String id) async {
    await _client.from('videos').delete().eq('id', id);
  }

  /// Returns the cached transcript for a video, or null if none stored yet.
  Future<List<TranscriptCue>?> fetchCachedTranscript(String videoId) async {
    final row = await _client
        .from('video_transcripts')
        .select('cues')
        .eq('video_id', videoId)
        .maybeSingle();
    if (row == null) return null;
    final cues = row['cues'] as List<dynamic>;
    return cues.map((e) => TranscriptCue.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Asks the edge function to fetch captions from YouTube (and cache them).
  /// YouTube offers no official API for third-party auto-captions and blocks
  /// direct browser calls via CORS, so this has to go through the server.
  Future<List<TranscriptCue>> fetchTranscriptFromYoutube({
    required String youtubeId,
    required String videoId,
  }) async {
    final response = await _client.functions.invoke(
      'youtube-transcript',
      body: {'youtubeId': youtubeId, 'videoId': videoId},
    );

    final data = response.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error']);
    }
    final cues = (data as Map)['cues'] as List<dynamic>;
    return cues.map((e) => TranscriptCue.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Cached transcript if we have one, otherwise fetch it fresh.
  ///
  /// Order matters. On mobile we can fetch straight from YouTube — no CORS,
  /// and a residential IP — so any video works there, and whatever we fetch is
  /// written back to the shared cache so web users get it too. On the web that
  /// path is impossible, so we fall back to the edge function.
  Future<List<TranscriptCue>> fetchTranscript({
    required String videoId,
    required String youtubeId,
  }) async {
    final cached = await fetchCachedTranscript(videoId);
    if (cached != null && cached.isNotEmpty) return cached;

    if (YoutubeCaptionService.isSupported) {
      try {
        final cues = await const YoutubeCaptionService().fetchCaptions(youtubeId);
        // Best effort: a failed upload shouldn't stop the learner watching.
        try {
          await saveTranscript(videoId: videoId, cues: cues);
        } catch (e) {
          debugPrint('Could not cache transcript for $youtubeId: $e');
        }
        return cues;
      } catch (e) {
        debugPrint('On-device caption fetch failed for $youtubeId: $e');
      }
    }

    return fetchTranscriptFromYoutube(youtubeId: youtubeId, videoId: videoId);
  }

  /// Stores a transcript supplied by an admin (pasted from YouTube's own
  /// transcript panel, or an .srt/.vtt file).
  Future<void> saveTranscript({
    required String videoId,
    required List<TranscriptCue> cues,
  }) async {
    await _client.from('video_transcripts').upsert({
      'video_id': videoId,
      'lang': 'hu',
      'is_auto_generated': false,
      'cues': cues
          .map((c) => {'start': c.start, 'dur': c.duration, 'text': c.text})
          .toList(),
      'fetched_at': DateTime.now().toIso8601String(),
    });
  }

  Future<TranslationResult> translate(String text) async {
    final response = await _client.functions.invoke('translate', body: {'text': text});
    final data = response.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error']);
    }
    final map = data as Map;
    return TranslationResult(
      translation: map['translation'] as String,
      english: map['english'] as String?,
    );
  }
}

class TranslationResult {
  final String translation;

  /// An English gloss shown as a second opinion — free Hungarian→Ukrainian
  /// machine translation is unreliable enough that one signal isn't enough.
  final String? english;

  const TranslationResult({required this.translation, required this.english});
}
