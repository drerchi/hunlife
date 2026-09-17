import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/service_providers.dart';
import '../../../providers/session_provider.dart';
import '../../../providers/video_providers.dart';

/// Pauses-and-explains sheet: shows the tapped word's translation, reads it
/// aloud on demand, and saves it to the learner's vocabulary.
Future<void> showWordLookupSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String word,
  required String context_,
  required String videoId,
  required VoidCallback onResume,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _WordLookupSheet(
      word: word,
      contextLine: context_,
      videoId: videoId,
      onResume: onResume,
    ),
  );
}

class _WordLookupSheet extends ConsumerStatefulWidget {
  const _WordLookupSheet({
    required this.word,
    required this.contextLine,
    required this.videoId,
    required this.onResume,
  });

  final String word;
  final String contextLine;
  final String videoId;
  final VoidCallback onResume;

  @override
  ConsumerState<_WordLookupSheet> createState() => _WordLookupSheetState();
}

class _WordLookupSheetState extends ConsumerState<_WordLookupSheet> {
  final _translationController = TextEditingController();
  String? _english;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _lookup();
    // Speak the word straight away — hearing it is half the point.
    ref.read(ttsServiceProvider).speak(widget.word);
  }

  @override
  void dispose() {
    _translationController.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    try {
      final result = await ref.read(videoServiceProvider).translate(widget.word);
      if (!mounted) return;
      setState(() {
        _translationController.text = result.translation;
        _english = result.english;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не вдалося отримати переклад.';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final session = ref.read(sessionProvider).valueOrNull;
    final profile = session?.profile;
    final translation = _translationController.text.trim();
    if (profile == null || translation.isEmpty) return;

    setState(() => _saving = true);
    try {
      await ref.read(vocabularyServiceProvider).save(
            userId: profile.id,
            wordHu: widget.word,
            translationUk: translation,
            contextHu: widget.contextLine,
            videoId: widget.videoId,
          );
      ref.invalidate(savedWordsProvider);
      ref.invalidate(vocabularyProvider);
      if (!mounted) return;
      setState(() {
        _saved = true;
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не вдалося зберегти слово.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(widget.word, style: theme.textTheme.headlineSmall),
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.volume_up),
                tooltip: 'Прослухати',
                onPressed: () => ref.read(ttsServiceProvider).speak(widget.word),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 12),
                  Text('Перекладаємо...'),
                ],
              ),
            )
          else if (_error != null)
            Text(_error!, style: TextStyle(color: theme.colorScheme.error))
          else ...[
            TextField(
              controller: _translationController,
              style: theme.textTheme.titleLarge,
              decoration: const InputDecoration(
                labelText: 'Переклад',
                helperText: 'Машинний переклад — за потреби виправте перед збереженням',
              ),
              onChanged: (_) => setState(() => _saved = false),
            ),
            if (_english != null && _english!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Icon(Icons.translate, size: 16, color: theme.colorScheme.outline),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'English: ${_english!}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 16),
          Text('У реченні:', style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(widget.contextLine, style: theme.textTheme.bodyMedium),
              ),
              IconButton(
                icon: const Icon(Icons.volume_up_outlined, size: 20),
                tooltip: 'Прослухати речення',
                onPressed: () => ref.read(ttsServiceProvider).speak(widget.contextLine),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: (_loading || _saving || _saved) ? null : _save,
                  icon: Icon(_saved ? Icons.bookmark_added : Icons.bookmark_add_outlined),
                  label: Text(_saved ? 'Збережено' : 'Зберегти у словник'),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onResume();
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Далі'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
