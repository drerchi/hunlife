import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/widgets/async_view.dart';
import '../../models/chapter.dart';
import '../../models/topic.dart';
import '../../providers/content_providers.dart';

/// The course, grouped into chapters. Chapters expand in place rather than
/// pushing another screen, so the whole path stays visible at a glance.
class TopicsListScreen extends ConsumerWidget {
  const TopicsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapters = ref.watch(chaptersProvider);
    final topics = ref.watch(topicsProvider);

    // Most topics hold a single lesson, and making the learner tap the topic
    // and then the one lesson inside it is a wasted step — so jump straight in
    // when there is nothing to choose between.
    final lessons = ref.watch(allLessonsProvider).valueOrNull ?? const [];
    final soleLessonByTopic = <String, String>{};
    final lessonCounts = <String, int>{};
    for (final lesson in lessons) {
      lessonCounts[lesson.topicId] = (lessonCounts[lesson.topicId] ?? 0) + 1;
      soleLessonByTopic[lesson.topicId] = lesson.id;
    }
    soleLessonByTopic.removeWhere((topicId, _) => (lessonCounts[topicId] ?? 0) != 1);

    return Scaffold(
      appBar: AppBar(title: const Text('Навчання')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(chaptersProvider);
          ref.invalidate(topicsProvider);
        },
        child: AsyncView(
          value: chapters,
          onRetry: () => ref.invalidate(chaptersProvider),
          data: (context, chapterList) {
            return AsyncView(
              value: topics,
              onRetry: () => ref.invalidate(topicsProvider),
              data: (context, topicList) {
                if (chapterList.isEmpty && topicList.isEmpty) {
                  return const EmptyState(message: 'Матеріалів поки немає.');
                }

                // Topics that belong to no chapter still need somewhere to go.
                final unassigned =
                    topicList.where((t) => t.chapterId == null).toList();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    for (int i = 0; i < chapterList.length; i++)
                      _ChapterCard(
                        chapter: chapterList[i],
                        number: i + 1,
                        topics: topicList
                            .where((t) => t.chapterId == chapterList[i].id)
                            .toList(),
                        initiallyExpanded: i == 0,
                        soleLessonByTopic: soleLessonByTopic,
                      ),
                    if (unassigned.isNotEmpty)
                      _ChapterCard(
                        chapter: null,
                        number: chapterList.length + 1,
                        topics: unassigned,
                        initiallyExpanded: chapterList.isEmpty,
                        soleLessonByTopic: soleLessonByTopic,
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({
    required this.chapter,
    required this.number,
    required this.topics,
    required this.initiallyExpanded,
    required this.soleLessonByTopic,
  });

  final Chapter? chapter;
  final int number;
  final List<Topic> topics;
  final bool initiallyExpanded;

  /// topicId -> its only lesson, for topics that have exactly one.
  final Map<String, String> soleLessonByTopic;

  /// One colour per chapter so the course reads as a sequence of distinct
  /// sections rather than a stack of identical cards.
  static const List<Color> _chapterColors = [
    Color(0xFF1A73E8), // blue
    Color(0xFF2E9E5B), // green
    Color(0xFFE8710A), // orange
    Color(0xFF7B4FBF), // purple
    Color(0xFF00897B), // teal
    Color(0xFFD93025), // red
    Color(0xFF5E7BC4), // indigo
    Color(0xFFB8860B), // gold
  ];

  @override
  Widget build(BuildContext context) {
    final accent = _chapterColors[(number - 1) % _chapterColors.length];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Theme(
        // Hide the divider lines ExpansionTile draws by default.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          collapsedIconColor: accent,
          iconColor: accent,
          leading: CircleAvatar(
            backgroundColor: accent.withValues(alpha: 0.16),
            child: Text(
              '$number',
              style: TextStyle(color: accent, fontWeight: FontWeight.w700),
            ),
          ),
          title: Text(
            chapter?.titleUk ?? 'Інші теми',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            chapter?.descriptionUk ?? '${topics.length} тем',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          children: [
            if (topics.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text('У цьому розділі поки немає тем.'),
              )
            else
              for (final topic in topics)
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 28, right: 12),
                  leading: Icon(Icons.play_circle_fill, color: accent),
                  title: Text(topic.titleUk),
                  subtitle: topic.titleHu == null ? null : Text(topic.titleHu!),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    final soleLesson = soleLessonByTopic[topic.id];
                    context.push(soleLesson != null
                        ? AppRoutes.lessonDetail(soleLesson)
                        : AppRoutes.topicDetail(topic.id));
                  },
                ),
          ],
        ),
      ),
    );
  }
}
