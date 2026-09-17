import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/widgets/async_view.dart';
import '../../providers/content_providers.dart';
import '../../providers/session_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final topics = ref.watch(topicsProvider);
    final completed = ref.watch(completedLessonIdsProvider);

    final name = session.valueOrNull?.profile?.fullName?.split(' ').first ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('HunLife')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(topicsProvider);
          ref.invalidate(completedLessonIdsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              name.isEmpty ? 'Вітаємо!' : 'Вітаємо, $name!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text('Продовжуймо вивчати угорську мову.', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 20),
            completed.when(
              data: (ids) => _ProgressCard(completedCount: ids.length),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.menu_book,
                    label: 'Теми та уроки',
                    onTap: () => context.go(AppRoutes.topics),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.flag,
                    label: 'Громадянство',
                    onTap: () => context.go(AppRoutes.citizenship),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Теми', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            AsyncView(
              value: topics,
              onRetry: () => ref.invalidate(topicsProvider),
              data: (context, list) {
                if (list.isEmpty) {
                  return const EmptyState(message: 'Тем поки немає.');
                }
                return Column(
                  children: list
                      .take(4)
                      .map((t) => Card(
                            child: ListTile(
                              leading: const CircleAvatar(child: Icon(Icons.book_outlined)),
                              title: Text(t.titleUk),
                              subtitle: t.titleHu != null ? Text(t.titleHu!) : null,
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.push(AppRoutes.topicDetail(t.id)),
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

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.completedCount});

  final int completedCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.local_fire_department, color: Theme.of(context).colorScheme.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Завершено уроків: $completedCount',
                style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
