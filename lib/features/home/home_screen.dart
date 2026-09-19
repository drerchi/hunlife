import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/content_providers.dart';
import '../../providers/session_provider.dart';
import '../../providers/video_providers.dart';

/// The home screen is a dashboard, not a second copy of the topic list —
/// browsing lives in the Теми tab. Here a learner sees where they stand and
/// jumps to whatever they want to do next.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(sessionProvider).valueOrNull?.profile;
    final completed = ref.watch(completedLessonIdsProvider).valueOrNull ?? <String>{};
    final vocabulary = ref.watch(vocabularyProvider).valueOrNull ?? [];
    final chapters = ref.watch(chaptersProvider).valueOrNull ?? [];
    final topics = ref.watch(topicsProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('HunLife')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(completedLessonIdsProvider);
          ref.invalidate(vocabularyProvider);
          ref.invalidate(chaptersProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Text(
              _greeting(profile?.firstName, profile?.fullName),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Продовжуймо вивчати угорську.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),

            _StreakCard(lessonsDone: completed.length),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.check_circle,
                    value: '${completed.length}',
                    label: 'уроків пройдено',
                    color: AppTheme.progressGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.bookmark,
                    value: '${vocabulary.length}',
                    label: 'слів у словнику',
                    color: AppTheme.vocabularyPurple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _StatCard(
              icon: Icons.menu_book,
              value: '${chapters.length} розділів · ${topics.length} тем',
              label: 'доступно для навчання',
              color: AppTheme.learnBlue,
              wide: true,
            ),

            if (profile != null && !profile.hasInterviewDetails) ...[
              const SizedBox(height: 16),
              Card(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Додайте свої дані'),
                  subtitle: const Text('Щоб відповіді на співбесіді були з вашим іменем'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.personalDetails),
                ),
              ),
            ],

            const SizedBox(height: 24),
            Text('Куди далі?', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),

            _ActionTile(
              icon: Icons.menu_book,
              color: AppTheme.learnBlue,
              title: 'Навчання',
              subtitle: 'Розділи, теми та уроки',
              onTap: () => context.go(AppRoutes.topics),
            ),
            _ActionTile(
              icon: Icons.smart_display,
              color: AppTheme.videoRed,
              title: 'Відео із субтитрами',
              subtitle: 'Натискайте на слова, щоб бачити переклад',
              onTap: () => context.go(AppRoutes.videos),
            ),
            _ActionTile(
              icon: Icons.flag,
              color: AppTheme.citizenshipGreen,
              title: 'Підготовка до співбесіди',
              subtitle: 'Питання та відповіді на громадянство',
              onTap: () => context.go(AppRoutes.citizenship),
            ),
            _ActionTile(
              icon: Icons.style,
              color: AppTheme.vocabularyPurple,
              title: 'Мій словник',
              subtitle: vocabulary.isEmpty
                  ? 'Збережені слова з відео'
                  : 'Повторити ${vocabulary.length} збережених слів',
              onTap: () => context.push(AppRoutes.vocabulary),
            ),
          ],
        ),
      ),
    );
  }

  /// Greet by given name. full_name is stored surname-first (Hungarian
  /// order), so splitting it naively would greet people by their surname.
  static String _greeting(String? firstName, String? fullName) {
    final given = firstName?.trim();
    if (given != null && given.isNotEmpty) return 'Вітаємо, $given!';

    final parts = (fullName ?? '').trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return 'Вітаємо, ${parts.last}!';
    if (parts.isNotEmpty && parts.first.isNotEmpty) return 'Вітаємо, ${parts.first}!';
    return 'Вітаємо!';
  }
}

/// The warm banner at the top. A flame reads as momentum in a way a plain
/// counter does not, so progress gets the one piece of strong colour.
class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.lessonsDone});

  final int lessonsDone;

  @override
  Widget build(BuildContext context) {
    final message = lessonsDone == 0
        ? 'Почніть перший урок сьогодні'
        : 'Так тримати — уже $lessonsDone позаду!';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.flameGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.flameEnd.withValues(alpha: 0.14),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_fire_department,
            color: Colors.white.withValues(alpha: 0.92),
            size: 34,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ваш прогрес',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.wide = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: (wide
                            ? Theme.of(context).textTheme.titleMedium
                            : Theme.of(context).textTheme.headlineSmall)
                        ?.copyWith(color: color, fontWeight: FontWeight.w700),
                  ),
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
