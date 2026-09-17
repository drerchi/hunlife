import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/widgets/async_view.dart';
import '../../providers/content_providers.dart';

class TopicsListScreen extends ConsumerWidget {
  const TopicsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(topicsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Теми')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(topicsProvider),
        child: AsyncView(
          value: topics,
          onRetry: () => ref.invalidate(topicsProvider),
          data: (context, list) {
            if (list.isEmpty) {
              return const EmptyState(message: 'Тем поки немає. Перевірте пізніше.');
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final topic = list[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Text('${index + 1}'),
                    ),
                    title: Text(topic.titleUk, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      [if (topic.titleHu != null) topic.titleHu!, if (topic.descriptionUk != null) topic.descriptionUk!]
                          .join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.topicDetail(topic.id)),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
