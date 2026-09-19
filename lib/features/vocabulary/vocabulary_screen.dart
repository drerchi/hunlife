import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/speak_button.dart';
import '../../core/widgets/word_image_view.dart';
import '../../providers/service_providers.dart';
import '../../providers/video_providers.dart';

class VocabularyScreen extends ConsumerWidget {
  const VocabularyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vocabulary = ref.watch(vocabularyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Мій словник')),
      body: AsyncView(
        value: vocabulary,
        onRetry: () => ref.invalidate(vocabularyProvider),
        data: (context, entries) {
          if (entries.isEmpty) {
            return const EmptyState(
              message:
                  'Тут з\'являться слова, які ви збережете.\nНатисніть на слово в субтитрах відео, щоб додати його.',
              icon: Icons.bookmark_outline,
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: () => context.push(AppRoutes.vocabularyStudy),
                  icon: const Icon(Icons.style_outlined),
                  label: Text('Вчити картки (${entries.length})'),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return Card(
                      child: ListTile(
                        leading: WordImageView(
                          wordHu: entry.wordHu,
                          ukrainian: entry.translationUk,
                          size: 44,
                        ),
                        title: Text(entry.wordHu,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.translationUk),
                            if (entry.contextHu != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  entry.contextHu!,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        fontStyle: FontStyle.italic,
                                      ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                        isThreeLine: entry.contextHu != null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SpeakButton(
                              // Read the saved answer/example too, not just the
                              // word — for a saved citizenship question this is
                              // the whole point: hearing the question and the
                              // rehearsed answer together.
                              text: entry.contextHu == null
                                  ? entry.wordHu
                                  : '${entry.wordHu} ${entry.contextHu}',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Видалити',
                              onPressed: () async {
                                await ref.read(vocabularyServiceProvider).delete(entry.id);
                                ref.invalidate(vocabularyProvider);
                                ref.invalidate(savedWordsProvider);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
