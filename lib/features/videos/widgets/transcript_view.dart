import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../models/video.dart';
import '../../../providers/video_providers.dart';

/// The caption list beside the player.
///
/// Built lazily and driven by [ValueNotifier]s rather than setState: a
/// feature-length video has thousands of cues, and rebuilding the whole list
/// on every position tick made the page crawl. Only the handful of visible
/// rows exist, and only the active one repaints as words are spoken.
class TranscriptView extends ConsumerStatefulWidget {
  const TranscriptView({
    super.key,
    required this.cues,
    required this.positionSeconds,
    required this.autoScroll,
    required this.onWordTap,
    required this.onSeek,
  });

  final List<TranscriptCue> cues;

  /// Live playback position, updated by the player.
  final ValueListenable<double> positionSeconds;

  final bool autoScroll;
  final void Function(String word, TranscriptCue cue) onWordTap;
  final void Function(TranscriptCue cue) onSeek;

  @override
  ConsumerState<TranscriptView> createState() => _TranscriptViewState();
}

class _TranscriptViewState extends ConsumerState<TranscriptView> {
  final ItemScrollController _scrollController = ItemScrollController();
  final ValueNotifier<int> _activeIndex = ValueNotifier<int>(-1);

  int _lastScrolledTo = -1;

  @override
  void initState() {
    super.initState();
    widget.positionSeconds.addListener(_onPosition);
  }

  @override
  void dispose() {
    widget.positionSeconds.removeListener(_onPosition);
    _activeIndex.dispose();
    super.dispose();
  }

  void _onPosition() {
    final index = _indexAt(widget.positionSeconds.value);
    if (index == _activeIndex.value) return;
    _activeIndex.value = index;

    if (!widget.autoScroll || index < 0) return;
    if (index == _lastScrolledTo) return;
    _lastScrolledTo = index;

    if (_scrollController.isAttached) {
      _scrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        alignment: 0.35,
      );
    }
  }

  /// Cues are in order, so a binary search keeps this cheap even on a
  /// three-hour transcript.
  int _indexAt(double seconds) {
    final cues = widget.cues;
    if (cues.isEmpty) return -1;

    int low = 0;
    int high = cues.length - 1;
    int best = -1;

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (cues[mid].start <= seconds) {
        best = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    if (best < 0) return -1;
    // Past the end of the last cue by a wide margin: nothing is active.
    final cue = cues[best];
    if (seconds > cue.end + 5) return best;
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(savedWordsProvider).valueOrNull ?? <String>{};

    return ScrollablePositionedList.builder(
      itemScrollController: _scrollController,
      itemCount: widget.cues.length,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemBuilder: (context, index) {
        return ValueListenableBuilder<int>(
          valueListenable: _activeIndex,
          builder: (context, active, _) {
            return _CueRow(
              cue: widget.cues[index],
              isActive: index == active,
              savedWords: saved,
              onWordTap: widget.onWordTap,
              onSeek: widget.onSeek,
            );
          },
        );
      },
    );
  }
}

class _CueRow extends StatelessWidget {
  const _CueRow({
    required this.cue,
    required this.isActive,
    required this.savedWords,
    required this.onWordTap,
    required this.onSeek,
  });

  final TranscriptCue cue;
  final bool isActive;
  final Set<String> savedWords;
  final void Function(String word, TranscriptCue cue) onWordTap;
  final void Function(TranscriptCue cue) onSeek;

  static String _formatTime(double seconds) {
    final d = Duration(seconds: seconds.floor());
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final words = cue.words;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => onSeek(cue),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.only(right: 10, top: 3),
              child: Text(
                _formatTime(cue.start),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.primary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ),
          ),
          Expanded(
            child: _WordWrap(
              words: words,
              cue: cue,
              savedWords: savedWords,
              isActiveLine: isActive,
              onWordTap: onWordTap,
            ),
          ),
        ],
      ),
    );
  }

}

class _WordWrap extends StatelessWidget {
  const _WordWrap({
    required this.words,
    required this.cue,
    required this.savedWords,
    required this.isActiveLine,
    required this.onWordTap,
  });

  final List<String> words;
  final TranscriptCue cue;
  final Set<String> savedWords;
  final bool isActiveLine;
  final void Function(String word, TranscriptCue cue) onWordTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 2,
      runSpacing: 2,
      children: [
        for (final word in words)
          _WordChip(
            word: word,
            isSaved: savedWords.contains(normaliseWord(word)),
            isActiveLine: isActiveLine,
            scheme: scheme,
            onTap: () => onWordTap(word, cue),
          ),
      ],
    );
  }
}

class _WordChip extends StatefulWidget {
  const _WordChip({
    required this.word,
    required this.isSaved,
    required this.isActiveLine,
    required this.scheme,
    required this.onTap,
  });

  final String word;
  final bool isSaved;
  final bool isActiveLine;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  State<_WordChip> createState() => _WordChipState();
}

class _WordChipState extends State<_WordChip> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final scheme = widget.scheme;
    final tappable = normaliseWord(widget.word).isNotEmpty;

    // Only the current line is highlighted; marking each spoken word as well
    // turned out to be more distracting than helpful when reading along.
    final showHover = _hovering && tappable;
    final Color? background =
        showHover ? scheme.primary.withValues(alpha: 0.18) : null;

    return MouseRegion(
      cursor: tappable ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: tappable ? (_) => setState(() => _hovering = true) : null,
      onExit: tappable ? (_) => setState(() => _hovering = false) : null,
      child: GestureDetector(
        onTap: tappable ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(4),
            border: widget.isSaved
                ? Border(bottom: BorderSide(color: scheme.primary, width: 2))
                : null,
          ),
          child: Text(
            widget.word,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              fontWeight: widget.isActiveLine ? FontWeight.w600 : FontWeight.normal,
              color: widget.isActiveLine ? scheme.onPrimaryContainer : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
