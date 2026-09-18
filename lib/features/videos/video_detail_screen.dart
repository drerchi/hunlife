import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../core/widgets/async_view.dart';
import '../../models/video.dart';
import '../../providers/session_provider.dart';
import '../../providers/video_providers.dart';
import '../admin/widgets/transcript_import_dialog.dart';
import 'widgets/transcript_view.dart';
import 'widgets/word_lookup_sheet.dart';

class VideoDetailScreen extends ConsumerStatefulWidget {
  const VideoDetailScreen({super.key, required this.videoId});

  final String videoId;

  @override
  ConsumerState<VideoDetailScreen> createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends ConsumerState<VideoDetailScreen> {
  YoutubePlayerController? _controller;
  Timer? _positionTimer;

  /// Playback position, published as a listenable so the transcript can follow
  /// along without rebuilding the whole screen on every tick.
  final ValueNotifier<double> _position = ValueNotifier<double>(0);

  bool _autoScroll = true;

  @override
  void dispose() {
    _positionTimer?.cancel();
    _controller?.close();
    _position.dispose();
    super.dispose();
  }

  void _ensureController(String youtubeId) {
    if (_controller != null) return;

    final controller = YoutubePlayerController.fromVideoId(
      videoId: youtubeId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        strictRelatedVideos: true,
      ),
    );

    // videoStateStream only fires when the player *state* changes (play,
    // pause, buffering) — it does not tick while a video plays, which left
    // the transcript stuck on whichever line was showing when playback began.
    // Polling the player clock is what actually keeps the captions in step.
    _positionTimer = Timer.periodic(const Duration(milliseconds: 200), (_) async {
      try {
        final seconds = await controller.currentTime;
        if (mounted) _position.value = seconds;
      } catch (_) {
        // Player not ready yet; the next tick will pick it up.
      }
    });

    _controller = controller;
  }

  Future<void> _onWordTapped(String rawWord, TranscriptCue cue) async {
    final word = normaliseWord(rawWord);
    if (word.isEmpty) return;

    await _controller?.pauseVideo();
    if (!mounted) return;

    await showWordLookupSheet(
      context: context,
      ref: ref,
      word: word,
      context_: cue.text,
      videoId: widget.videoId,
      onResume: () => _controller?.playVideo(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final videos = ref.watch(videosProvider);
    final videoList = videos.valueOrNull;
    final video = videoList == null
        ? null
        : (videoList.where((v) => v.id == widget.videoId).isEmpty
            ? null
            : videoList.firstWhere((v) => v.id == widget.videoId));

    if (video == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Відео')),
        body: videos.hasError
            ? Center(child: Text('Не вдалося завантажити відео.\n${videos.error}'))
            : const Center(child: CircularProgressIndicator()),
      );
    }

    _ensureController(video.youtubeId);
    final transcript = ref.watch(
      transcriptProvider((videoId: video.id, youtubeId: video.youtubeId)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(video.titleUk, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: Icon(_autoScroll ? Icons.vertical_align_center : Icons.swipe_vertical),
            tooltip: _autoScroll ? 'Автопрокрутка увімкнена' : 'Автопрокрутка вимкнена',
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
        ],
      ),
      body: Column(
        children: [
          // Cap the player height so the captions stay on screen; a full-width
          // 16:9 player fills a desktop window on its own.
          LayoutBuilder(
            builder: (context, constraints) {
              final maxPlayerHeight = MediaQuery.of(context).size.height * 0.42;
              final width = constraints.maxWidth.clamp(0.0, maxPlayerHeight * 16 / 9);
              return Center(
                child: SizedBox(
                  width: width,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: YoutubePlayer(controller: _controller!),
                  ),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                Icon(Icons.touch_app_outlined,
                    size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Натисніть на будь-яке слово — відео зупиниться і покаже переклад.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: AsyncView(
              value: transcript,
              onRetry: () => ref.invalidate(
                transcriptProvider((videoId: video.id, youtubeId: video.youtubeId)),
              ),
              data: (context, cues) {
                if (cues.isEmpty) return _MissingSubtitles(video: video);

                return TranscriptView(
                  cues: cues,
                  positionSeconds: _position,
                  autoScroll: _autoScroll,
                  onWordTap: _onWordTapped,
                  onSeek: (cue) =>
                      _controller?.seekTo(seconds: cue.start, allowSeekAhead: true),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingSubtitles extends ConsumerWidget {
  const _MissingSubtitles({required this.video});

  final Video video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(sessionProvider).valueOrNull?.profile?.isAdmin ?? false;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.subtitles_off_outlined,
                size: 40, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              'Субтитри для цього відео ще не додані.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (isAdmin) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () async {
                  final saved = await showTranscriptImportDialog(context, video);
                  if (saved == true) ref.invalidate(transcriptProvider);
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('Додати субтитри'),
              ),
              const SizedBox(height: 8),
              Text(
                'Завантажте файл .srt/.vtt або вставте текст із YouTube',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
