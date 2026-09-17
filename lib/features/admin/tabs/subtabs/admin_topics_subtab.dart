import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/async_view.dart';
import '../../../../providers/content_providers.dart';
import '../../../../providers/service_providers.dart';
import '../../widgets/confirm_delete_dialog.dart';
import '../../widgets/topic_form_dialog.dart';

class AdminTopicsSubtab extends ConsumerWidget {
  const AdminTopicsSubtab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(topicsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await showTopicFormDialog(context);
          if (created == null) return;
          await ref.read(contentServiceProvider).createTopic(created);
          ref.invalidate(topicsProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Тема'),
      ),
      body: AsyncView(
        value: topics,
        onRetry: () => ref.invalidate(topicsProvider),
        data: (context, list) {
          if (list.isEmpty) return const EmptyState(message: 'Тем ще немає. Додайте першу.');
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final topic = list[index];
              return Card(
                child: ListTile(
                  title: Text(topic.titleUk),
                  subtitle: Text(topic.titleHu ?? ''),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () async {
                          final updated = await showTopicFormDialog(context, existing: topic);
                          if (updated == null) return;
                          await ref.read(contentServiceProvider).updateTopic(topic.id, updated);
                          ref.invalidate(topicsProvider);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          if (!await confirmDelete(context, topic.titleUk)) return;
                          await ref.read(contentServiceProvider).deleteTopic(topic.id);
                          ref.invalidate(topicsProvider);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
