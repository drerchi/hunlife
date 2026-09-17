import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/citizenship_question.dart';
import '../models/flashcard.dart';
import '../models/lesson.dart';
import '../models/lesson_step.dart';
import '../models/topic.dart';
import 'service_providers.dart';
import 'session_provider.dart';

final topicsProvider = FutureProvider.autoDispose<List<Topic>>((ref) async {
  return ref.watch(contentServiceProvider).fetchTopics();
});

final lessonsForTopicProvider =
    FutureProvider.autoDispose.family<List<Lesson>, String>((ref, topicId) async {
  return ref.watch(contentServiceProvider).fetchLessons(topicId);
});

final lessonProvider = FutureProvider.autoDispose.family<Lesson, String>((ref, lessonId) async {
  return ref.watch(contentServiceProvider).fetchLesson(lessonId);
});

final allLessonsProvider = FutureProvider.autoDispose<List<Lesson>>((ref) async {
  return ref.watch(contentServiceProvider).fetchAllLessons();
});

final lessonStepsProvider =
    FutureProvider.autoDispose.family<List<LessonStep>, String>((ref, lessonId) async {
  return ref.watch(contentServiceProvider).fetchLessonSteps(lessonId);
});

final allFlashcardsProvider = FutureProvider.autoDispose<List<Flashcard>>((ref) async {
  return ref.watch(contentServiceProvider).fetchAllFlashcards();
});

final flashcardsForTopicProvider =
    FutureProvider.autoDispose.family<List<Flashcard>, String>((ref, topicId) async {
  return ref.watch(contentServiceProvider).fetchFlashcards(topicId);
});

final citizenshipQuestionsProvider =
    FutureProvider.autoDispose<List<CitizenshipQuestion>>((ref) async {
  return ref.watch(contentServiceProvider).fetchCitizenshipQuestions();
});

final completedLessonIdsProvider = FutureProvider.autoDispose<Set<String>>((ref) async {
  final session = await ref.watch(sessionProvider.future);
  if (!session.isAuthenticated) return <String>{};
  return ref.watch(contentServiceProvider).fetchCompletedLessonIds(session.profile!.id);
});

final flashcardProgressProvider = FutureProvider.autoDispose<Map<String, FlashcardStatus>>((ref) async {
  final session = await ref.watch(sessionProvider.future);
  if (!session.isAuthenticated) return <String, FlashcardStatus>{};
  return ref.watch(contentServiceProvider).fetchFlashcardProgress(session.profile!.id);
});
