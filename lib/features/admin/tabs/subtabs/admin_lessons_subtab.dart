import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/async_view.dart';
import '../../../../providers/content_providers.dart';
import '../../../../providers/service_providers.dart';
import '../../widgets/confirm_delete_dialog.dart';
import '../../widgets/lesson_form_dialog.dart';

class AdminLessonsSubtab extends ConsumerWidget {
  const AdminLessonsSubtab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(topicsProvider);
    final lessons = ref.watch(allLessonsProvider);

    return Scaffold(
      floatingActionButton: topics.valueOrNull == null || topics.valueOrNull!.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                final created = await showLessonFormDialog(
                  context,
                  topics: topics.valueOrNull!,
                  defaultTopicId: topics.valueOrNull!.first.id,
                );
                if (created == null) return;
                await ref.read(contentServiceProvider).createLesson(created);
                ref.invalidate(allLessonsProvider);
              },
              icon: const Icon(Icons.add),
              label: const Text('Урок'),
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
            value: lessons,
            onRetry: () => ref.invalidate(allLessonsProvider),
            data: (context, list) {
              if (list.isEmpty) return const EmptyState(message: 'Уроків ще немає. Додайте перший.');
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final lesson = list[index];
                  return Card(
                    child: ListTile(
                      title: Text(lesson.titleUk),
                      subtitle: Text(topicTitleById[lesson.topicId] ?? '—'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () async {
                              final updated = await showLessonFormDialog(
                                context,
                                topics: topicList,
                                defaultTopicId: lesson.topicId,
                                existing: lesson,
                              );
                              if (updated == null) return;
                              await ref.read(contentServiceProvider).updateLesson(lesson.id, updated);
                              ref.invalidate(allLessonsProvider);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              if (!await confirmDelete(context, lesson.titleUk)) return;
                              await ref.read(contentServiceProvider).deleteLesson(lesson.id);
                              ref.invalidate(allLessonsProvider);
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
