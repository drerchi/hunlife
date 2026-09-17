import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/widgets/async_view.dart';
import '../../providers/content_providers.dart';

class TopicDetailScreen extends ConsumerWidget {
  const TopicDetailScreen({super.key, required this.topicId});

  final String topicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(topicsProvider);
    final lessons = ref.watch(lessonsForTopicProvider(topicId));
    final completed = ref.watch(completedLessonIdsProvider);

    final topicList = topics.valueOrNull;
    final topic = topicList == null
        ? null
        : (topicList.where((t) => t.id == topicId).isEmpty
            ? null
            : topicList.firstWhere((t) => t.id == topicId));

    return Scaffold(
      appBar: AppBar(title: Text(topic?.titleUk ?? 'Тема')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(lessonsForTopicProvider(topicId)),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (topic?.descriptionUk != null) ...[
              Text(topic!.descriptionUk!, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
            ],
            FilledButton.icon(
              onPressed: () => context.push(AppRoutes.topicFlashcards(topicId)),
              icon: const Icon(Icons.style_outlined),
              label: const Text('Вчити картки'),
            ),
            const SizedBox(height: 20),
            Text('Уроки', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            AsyncView(
              value: lessons,
              onRetry: () => ref.invalidate(lessonsForTopicProvider(topicId)),
              data: (context, list) {
                if (list.isEmpty) {
                  return const EmptyState(message: 'Уроків у цій темі поки немає.');
                }
                final completedIds = completed.valueOrNull ?? <String>{};
                return Column(
                  children: list
                      .map((lesson) => Card(
                            child: ListTile(
                              leading: Icon(
                                completedIds.contains(lesson.id)
                                    ? Icons.check_circle
                                    : Icons.play_circle_outline,
                                color: completedIds.contains(lesson.id) ? Colors.green : null,
                              ),
                              title: Text(lesson.titleUk),
                              subtitle: lesson.titleHu != null ? Text(lesson.titleHu!) : null,
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.push(AppRoutes.lessonDetail(lesson.id)),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
