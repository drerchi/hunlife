import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/async_view.dart';
import '../../core/widgets/speak_button.dart';
import '../../core/widgets/word_image_view.dart';
import '../../models/flashcard.dart';
import '../../providers/content_providers.dart';
import '../../providers/service_providers.dart';
import '../../providers/session_provider.dart';

class FlashcardStudyScreen extends ConsumerStatefulWidget {
  const FlashcardStudyScreen({super.key, required this.topicId});

  final String topicId;

  @override
  ConsumerState<FlashcardStudyScreen> createState() => _FlashcardStudyScreenState();
}

class _FlashcardStudyScreenState extends ConsumerState<FlashcardStudyScreen> {
  int _index = 0;
  bool _showBack = false;

  void _next(List<Flashcard> cards) {
    setState(() {
      _showBack = false;
      if (_index < cards.length - 1) _index++;
    });
  }

  Future<void> _rate(Flashcard card, FlashcardStatus status) async {
    final session = ref.read(sessionProvider).valueOrNull;
    if (session?.profile == null) return;
    await ref.read(contentServiceProvider).setFlashcardStatus(
          userId: session!.profile!.id,
          flashcardId: card.id,
          status: status,
        );
    ref.invalidate(flashcardProgressProvider);
  }

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(flashcardsForTopicProvider(widget.topicId));

    return Scaffold(
      appBar: AppBar(title: const Text('Картки для вивчення')),
      body: AsyncView(
        value: cardsAsync,
        onRetry: () => ref.invalidate(flashcardsForTopicProvider(widget.topicId)),
        data: (context, cards) {
          if (cards.isEmpty) {
            return const EmptyState(message: 'У цій темі поки немає карток.', icon: Icons.style_outlined);
          }
          final index = _index.clamp(0, cards.length - 1);
          final card = cards[index];
          final finished = index == cards.length - 1 && _showBack;

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                LinearProgressIndicator(value: (index + 1) / cards.length),
                const SizedBox(height: 8),
                Text('${index + 1} / ${cards.length}', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 24),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showBack = !_showBack),
                    child: Card(
                      elevation: 2,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              WordImageView(
                                wordHu: card.frontHu,
                                ukrainian: card.backUk,
                                size: 150,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                _showBack ? card.backUk : card.frontHu,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 12),
                              SpeakFab(text: card.frontHu),
                              if (_showBack && card.exampleHu != null) ...[
                                const SizedBox(height: 20),
                                Text(card.exampleHu!,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(fontStyle: FontStyle.italic)),
                                if (card.exampleUk != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(card.exampleUk!,
                                        textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                                  ),
                              ],
                              const SizedBox(height: 16),
                              Text(
                                _showBack ? 'Натисніть, щоб побачити угорською' : 'Натисніть, щоб побачити переклад',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Theme.of(context).colorScheme.outline),
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
                          onPressed: () async {
                            await _rate(card, FlashcardStatus.learning);
                            if (!finished) _next(cards);
                          },
                          child: const Text('Ще вчу'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            await _rate(card, FlashcardStatus.known);
                            if (!finished) _next(cards);
                          },
                          child: const Text('Знаю'),
                        ),
                      ),
                    ],
                  )
                else
                  const SizedBox(height: 48),
                if (finished) ...[
                  const SizedBox(height: 12),
                  Text('Це остання картка в цій темі.', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
