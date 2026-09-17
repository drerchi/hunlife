import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../core/widgets/async_view.dart';
import '../../models/video.dart';
import '../../providers/video_providers.dart';
import 'widgets/word_lookup_sheet.dart';

class VideoDetailScreen extends ConsumerStatefulWidget {
  const VideoDetailScreen({super.key, required this.videoId});

  final String videoId;

  @override
  ConsumerState<VideoDetailScreen> createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends ConsumerState<VideoDetailScreen> {
  YoutubePlayerController? _controller;
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _cueKeys = {};
  int _activeCueIndex = -1;
  bool _autoScroll = true;

  @override
  void dispose() {
    _controller?.close();
    _scrollController.dispose();
    super.dispose();
  }

  void _ensureController(String youtubeId) {
    if (_controller != null) return;
    _controller = YoutubePlayerController.fromVideoId(
      videoId: youtubeId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        strictRelatedVideos: true,
      ),
    );
  }

  void _syncActiveCue(List<TranscriptCue> cues, double seconds) {
    final index = cues.indexWhere((c) => c.containsTime(seconds));
    if (index == -1 || index == _activeCueIndex) return;

    setState(() => _activeCueIndex = index);

    if (!_autoScroll) return;
    final key = _cueKeys[index];
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        alignment: 0.3,
      );
    }
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
          // Cap the player height so the captions — the actual point of this
          // screen — always stay on screen. A full-width 16:9 player fills a
          // desktop window entirely and pushes them below the fold.
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
                if (cues.isEmpty) {
                  return const EmptyState(
                    message: 'Субтитри для цього відео поки недоступні.\n'
                        'Відео можна дивитися, але натискання на слова недоступне.',
                    icon: Icons.subtitles_off_outlined,
                  );
                }
                return StreamBuilder<YoutubeVideoState>(
                  stream: _controller!.videoStateStream,
                  builder: (context, snapshot) {
                    final seconds = snapshot.data?.position.inMilliseconds ?? 0;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _syncActiveCue(cues, seconds / 1000);
                    });
                    return _TranscriptView(
                      cues: cues,
                      activeIndex: _activeCueIndex,
                      cueKeys: _cueKeys,
                      scrollController: _scrollController,
                      onWordTap: _onWordTapped,
                      onCueTap: (cue) => _controller?.seekTo(seconds: cue.start, allowSeekAhead: true),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TranscriptView extends ConsumerWidget {
  const _TranscriptView({
    required this.cues,
    required this.activeIndex,
    required this.cueKeys,
    required this.scrollController,
    required this.onWordTap,
    required this.onCueTap,
  });

  final List<TranscriptCue> cues;
  final int activeIndex;
  final Map<int, GlobalKey> cueKeys;
  final ScrollController scrollController;
  final void Function(String word, TranscriptCue cue) onWordTap;
  final void Function(TranscriptCue cue) onCueTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedWordsProvider).valueOrNull ?? <String>{};
    final scheme = Theme.of(context).colorScheme;

    // A non-lazy list keeps every cue's GlobalKey mounted, so auto-scrolling
    // to the active line stays reliable.
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < cues.length; i++)
            Container(
              key: cueKeys.putIfAbsent(i, () => GlobalKey()),
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: i == activeIndex ? scheme.primaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => onCueTap(cues[i]),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8, top: 2),
                      child: Text(
                        _formatTime(cues[i].start),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.primary,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 2,
                      runSpacing: 2,
                      children: [
                        for (final word in cues[i].words)
                          _WordChip(
                            word: word,
                            isSaved: saved.contains(normaliseWord(word)),
                            isActiveLine: i == activeIndex,
                            onTap: () => onWordTap(word, cues[i]),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _formatTime(double seconds) {
    final d = Duration(seconds: seconds.floor());
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _WordChip extends StatelessWidget {
  const _WordChip({
    required this.word,
    required this.isSaved,
    required this.isActiveLine,
    required this.onTap,
  });

  final String word;
  final bool isSaved;
  final bool isActiveLine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tappable = normaliseWord(word).isNotEmpty;

    return InkWell(
      onTap: tappable ? onTap : null,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        decoration: isSaved
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border(bottom: BorderSide(color: scheme.primary, width: 2)),
              )
            : null,
        child: Text(
          word,
          style: TextStyle(
            fontSize: 16,
            height: 1.5,
            fontWeight: isActiveLine ? FontWeight.w600 : FontWeight.normal,
            color: isActiveLine ? scheme.onPrimaryContainer : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}
