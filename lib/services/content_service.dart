import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/citizenship_question.dart';
import '../models/flashcard.dart';
import '../models/lesson.dart';
import '../models/lesson_step.dart';
import '../models/topic.dart';

/// Reads/writes lesson content (topics, lessons, flashcards, citizenship Q&A)
/// plus per-user progress tracking. Row Level Security enforces that only
/// active (non-blocked, non-expired) users or admins can read this content,
/// and only admins can write it.
class ContentService {
  ContentService(this._client);

  final SupabaseClient _client;

  // ---- Topics -------------------------------------------------------------
  Future<List<Topic>> fetchTopics() async {
    final rows = await _client.from('topics').select().order('order_index', ascending: true);
    return rows.map((e) => Topic.fromJson(e)).toList();
  }

  Future<Topic> createTopic(Topic topic) async {
    final row = await _client.from('topics').insert(topic.toInsertJson()).select().single();
    return Topic.fromJson(row);
  }

  Future<Topic> updateTopic(String id, Topic topic) async {
    final row =
        await _client.from('topics').update(topic.toInsertJson()).eq('id', id).select().single();
    return Topic.fromJson(row);
  }

  Future<void> deleteTopic(String id) async {
    await _client.from('topics').delete().eq('id', id);
  }

  // ---- Lessons --------------------------------------------------------------
  Future<List<Lesson>> fetchLessons(String topicId) async {
    final rows = await _client
        .from('lessons')
        .select()
        .eq('topic_id', topicId)
        .order('order_index', ascending: true);
    return rows.map((e) => Lesson.fromJson(e)).toList();
  }

  Future<List<Lesson>> fetchAllLessons() async {
    final rows = await _client.from('lessons').select().order('order_index', ascending: true);
    return rows.map((e) => Lesson.fromJson(e)).toList();
  }

  Future<Lesson> fetchLesson(String id) async {
    final row = await _client.from('lessons').select().eq('id', id).single();
    return Lesson.fromJson(row);
  }

  Future<Lesson> createLesson(Lesson lesson) async {
    final row = await _client.from('lessons').insert(lesson.toInsertJson()).select().single();
    return Lesson.fromJson(row);
  }

  Future<Lesson> updateLesson(String id, Lesson lesson) async {
    final row = await _client
        .from('lessons')
        .update(lesson.toInsertJson())
        .eq('id', id)
        .select()
        .single();
    return Lesson.fromJson(row);
  }

  Future<void> deleteLesson(String id) async {
    await _client.from('lessons').delete().eq('id', id);
  }

  Future<List<LessonStep>> fetchLessonSteps(String lessonId) async {
    final rows = await _client
        .from('lesson_steps')
        .select()
        .eq('lesson_id', lessonId)
        .order('order_index', ascending: true);
    return rows.map((e) => LessonStep.fromJson(e)).toList();
  }

  Future<LessonStep> createLessonStep(LessonStep step) async {
    final row = await _client.from('lesson_steps').insert(step.toInsertJson()).select().single();
    return LessonStep.fromJson(row);
  }

  Future<LessonStep> updateLessonStep(String id, LessonStep step) async {
    final row = await _client
        .from('lesson_steps')
        .update(step.toInsertJson())
        .eq('id', id)
        .select()
        .single();
    return LessonStep.fromJson(row);
  }

  Future<void> deleteLessonStep(String id) async {
    await _client.from('lesson_steps').delete().eq('id', id);
  }

  Future<void> markLessonComplete(String userId, String lessonId) async {
    await _client.from('lesson_progress').upsert({
      'user_id': userId,
      'lesson_id': lessonId,
      'completed_at': DateTime.now().toIso8601String(),
    });
  }

  Future<Set<String>> fetchCompletedLessonIds(String userId) async {
    final rows = await _client.from('lesson_progress').select('lesson_id').eq('user_id', userId);
    return rows.map((e) => e['lesson_id'] as String).toSet();
  }

  // ---- Flashcards -----------------------------------------------------------
  Future<List<Flashcard>> fetchFlashcards(String topicId) async {
    final rows = await _client
        .from('flashcards')
        .select()
        .eq('topic_id', topicId)
        .order('order_index', ascending: true);
    return rows.map((e) => Flashcard.fromJson(e)).toList();
  }

  Future<List<Flashcard>> fetchAllFlashcards() async {
    final rows = await _client.from('flashcards').select().order('order_index', ascending: true);
    return rows.map((e) => Flashcard.fromJson(e)).toList();
  }

  Future<Flashcard> createFlashcard(Flashcard card) async {
    final row = await _client.from('flashcards').insert(card.toInsertJson()).select().single();
    return Flashcard.fromJson(row);
  }

  Future<Flashcard> updateFlashcard(String id, Flashcard card) async {
    final row = await _client
        .from('flashcards')
        .update(card.toInsertJson())
        .eq('id', id)
        .select()
        .single();
    return Flashcard.fromJson(row);
  }

  Future<void> deleteFlashcard(String id) async {
    await _client.from('flashcards').delete().eq('id', id);
  }

  Future<Map<String, FlashcardStatus>> fetchFlashcardProgress(String userId) async {
    final rows = await _client
        .from('flashcard_progress')
        .select('flashcard_id, status')
        .eq('user_id', userId);
    return {
      for (final row in rows)
        row['flashcard_id'] as String: flashcardStatusFromString(row['status'] as String?),
    };
  }

  Future<void> setFlashcardStatus({
    required String userId,
    required String flashcardId,
    required FlashcardStatus status,
  }) async {
    await _client.from('flashcard_progress').upsert({
      'user_id': userId,
      'flashcard_id': flashcardId,
      'status': flashcardStatusToString(status),
      'last_reviewed_at': DateTime.now().toIso8601String(),
    });
  }

  // ---- Citizenship interview Q&A ---------------------------------------------
  Future<List<CitizenshipQuestion>> fetchCitizenshipQuestions() async {
    final rows =
        await _client.from('citizenship_questions').select().order('order_index', ascending: true);
    return rows.map((e) => CitizenshipQuestion.fromJson(e)).toList();
  }

  Future<CitizenshipQuestion> createCitizenshipQuestion(CitizenshipQuestion q) async {
    final row =
        await _client.from('citizenship_questions').insert(q.toInsertJson()).select().single();
    return CitizenshipQuestion.fromJson(row);
  }

  Future<CitizenshipQuestion> updateCitizenshipQuestion(String id, CitizenshipQuestion q) async {
    final row = await _client
        .from('citizenship_questions')
        .update(q.toInsertJson())
        .eq('id', id)
        .select()
        .single();
    return CitizenshipQuestion.fromJson(row);
  }

  Future<void> deleteCitizenshipQuestion(String id) async {
    await _client.from('citizenship_questions').delete().eq('id', id);
  }
}
