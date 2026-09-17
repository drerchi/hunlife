import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/async_view.dart';
import '../../../../providers/content_providers.dart';
import '../../../../providers/service_providers.dart';
import '../../widgets/citizenship_form_dialog.dart';
import '../../widgets/confirm_delete_dialog.dart';

class AdminCitizenshipSubtab extends ConsumerWidget {
  const AdminCitizenshipSubtab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questions = ref.watch(citizenshipQuestionsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await showCitizenshipFormDialog(context);
          if (created == null) return;
          await ref.read(contentServiceProvider).createCitizenshipQuestion(created);
          ref.invalidate(citizenshipQuestionsProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Питання'),
      ),
      body: AsyncView(
        value: questions,
        onRetry: () => ref.invalidate(citizenshipQuestionsProvider),
        data: (context, list) {
          if (list.isEmpty) return const EmptyState(message: 'Питань ще немає. Додайте перше.');
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final q = list[index];
              return Card(
                child: ListTile(
                  title: Text(q.questionHu),
                  subtitle: Text('${q.category} · ${q.questionUk}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () async {
                          final updated = await showCitizenshipFormDialog(context, existing: q);
                          if (updated == null) return;
                          await ref.read(contentServiceProvider).updateCitizenshipQuestion(q.id, updated);
                          ref.invalidate(citizenshipQuestionsProvider);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          if (!await confirmDelete(context, q.questionHu)) return;
                          await ref.read(contentServiceProvider).deleteCitizenshipQuestion(q.id);
                          ref.invalidate(citizenshipQuestionsProvider);
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
