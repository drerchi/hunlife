import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/async_view.dart';
import '../../core/widgets/speak_button.dart';
import '../../models/flashcard.dart';
import '../../models/vocabulary_entry.dart';
import '../../providers/service_providers.dart';
import '../../providers/video_providers.dart';

/// Studies saved vocabulary with the same flip-card flow as topic flashcards.
class VocabularyStudyScreen extends ConsumerStatefulWidget {
  const VocabularyStudyScreen({super.key});

  @override
  ConsumerState<VocabularyStudyScreen> createState() => _VocabularyStudyScreenState();
}

class _VocabularyStudyScreenState extends ConsumerState<VocabularyStudyScreen> {
  int _index = 0;
  bool _showBack = false;

  Future<void> _rate(VocabularyEntry entry, FlashcardStatus status, int total) async {
    await ref.read(vocabularyServiceProvider).setStatus(id: entry.id, status: status);
    ref.invalidate(vocabularyProvider);
    if (!mounted) return;
    setState(() {
      _showBack = false;
      if (_index < total - 1) _index++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final vocabulary = ref.watch(vocabularyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Картки зі словника')),
      body: AsyncView(
        value: vocabulary,
        onRetry: () => ref.invalidate(vocabularyProvider),
        data: (context, entries) {
          if (entries.isEmpty) {
            return const EmptyState(
              message: 'У словнику ще немає слів.',
              icon: Icons.style_outlined,
            );
          }
          final index = _index.clamp(0, entries.length - 1);
          final entry = entries[index];
          final isLast = index == entries.length - 1;

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                LinearProgressIndicator(value: (index + 1) / entries.length),
                const SizedBox(height: 8),
                Text('${index + 1} / ${entries.length}',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 24),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showBack = !_showBack),
                    child: Card(
                      elevation: 2,
                      child: SizedBox(
                        width: double.infinity,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _showBack ? entry.translationUk : entry.wordHu,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 12),
                              SpeakFab(text: entry.wordHu),
                              if (_showBack && entry.contextHu != null) ...[
                                const SizedBox(height: 20),
                                Text(
                                  entry.contextHu!,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(fontStyle: FontStyle.italic),
                                ),
                              ],
                              const SizedBox(height: 16),
                              Text(
                                _showBack
                                    ? 'Натисніть, щоб побачити угорською'
                                    : 'Натисніть, щоб побачити переклад',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.outline,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_showBack)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              _rate(entry, FlashcardStatus.learning, entries.length),
                          child: const Text('Ще вчу'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _rate(entry, FlashcardStatus.known, entries.length),
                          child: const Text('Знаю'),
                        ),
                      ),
                    ],
                  )
                else
                  const SizedBox(height: 48),
                if (isLast && _showBack) ...[
                  const SizedBox(height: 12),
                  Text('Це останнє слово у словнику.',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
