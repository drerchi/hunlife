import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/video.dart';
import '../models/vocabulary_entry.dart';
import 'service_providers.dart';
import 'session_provider.dart';

final videosProvider = FutureProvider.autoDispose<List<Video>>((ref) async {
  return ref.watch(videoServiceProvider).fetchVideos();
});

/// (videoId, youtubeId) -> caption cues. Uses the cached transcript when one
/// exists, otherwise asks the edge function to fetch it from YouTube.
///
/// A failure here means "no captions available for this video", which is a
/// normal state rather than an error — YouTube blocks caption fetching from
/// datacenter IPs, so the fetch legitimately can't always succeed. Returning
/// an empty list lets the video still play with a clear message instead of
/// showing the learner a raw exception.
final transcriptProvider =
    FutureProvider.autoDispose.family<List<TranscriptCue>, ({String videoId, String youtubeId})>(
        (ref, args) async {
  try {
    return await ref
        .watch(videoServiceProvider)
        .fetchTranscript(videoId: args.videoId, youtubeId: args.youtubeId);
  } catch (e) {
    debugPrint('Transcript unavailable for ${args.youtubeId}: $e');
    return <TranscriptCue>[];
  }
});

final vocabularyProvider = FutureProvider.autoDispose<List<VocabularyEntry>>((ref) async {
  final session = await ref.watch(sessionProvider.future);
  if (!session.isAuthenticated) return <VocabularyEntry>[];
  return ref.watch(vocabularyServiceProvider).fetchAll(session.profile!.id);
});

final savedWordsProvider = FutureProvider.autoDispose<Set<String>>((ref) async {
  final session = await ref.watch(sessionProvider.future);
  if (!session.isAuthenticated) return <String>{};
  return ref.watch(vocabularyServiceProvider).fetchSavedWords(session.profile!.id);
});
