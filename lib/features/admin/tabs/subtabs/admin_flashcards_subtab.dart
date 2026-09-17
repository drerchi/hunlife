import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/async_view.dart';
import '../../../../providers/content_providers.dart';
import '../../../../providers/service_providers.dart';
import '../../widgets/confirm_delete_dialog.dart';
import '../../widgets/flashcard_form_dialog.dart';

class AdminFlashcardsSubtab extends ConsumerWidget {
  const AdminFlashcardsSubtab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(topicsProvider);
    final flashcards = ref.watch(allFlashcardsProvider);

    return Scaffold(
      floatingActionButton: topics.valueOrNull == null || topics.valueOrNull!.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                final created = await showFlashcardFormDialog(
                  context,
                  topics: topics.valueOrNull!,
                  defaultTopicId: topics.valueOrNull!.first.id,
                );
                if (created == null) return;
                await ref.read(contentServiceProvider).createFlashcard(created);
                ref.invalidate(allFlashcardsProvider);
              },
              icon: const Icon(Icons.add),
              label: const Text('Картка'),
            ),
      body: AsyncView(
        value: topics,
        onRetry: () => ref.invalidate(topicsProvider),
        data: (context, topicList) {
          if (topicList.isEmpty) {
            return const EmptyState(message: 'Спочатку додайте тему на вкладці "Теми".');
          }
          final topicTitleById = {for (final t in topicList) t.id: t.titleUk};
          return AsyncView(
            value: flashcards,
            onRetry: () => ref.invalidate(allFlashcardsProvider),
            data: (context, list) {
              if (list.isEmpty) return const EmptyState(message: 'Карток ще немає. Додайте першу.');
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final card = list[index];
                  return Card(
                    child: ListTile(
                      title: Text('${card.frontHu}  →  ${card.backUk}'),
                      subtitle: Text(topicTitleById[card.topicId] ?? '—'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () async {
                              final updated = await showFlashcardFormDialog(
                                context,
                                topics: topicList,
                                defaultTopicId: card.topicId,
                                existing: card,
                              );
                              if (updated == null) return;
                              await ref.read(contentServiceProvider).updateFlashcard(card.id, updated);
                              ref.invalidate(allFlashcardsProvider);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              if (!await confirmDelete(context, card.frontHu)) return;
                              await ref.read(contentServiceProvider).deleteFlashcard(card.id);
                              ref.invalidate(allFlashcardsProvider);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
