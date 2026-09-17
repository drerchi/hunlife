import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/flashcard.dart';
import '../models/vocabulary_entry.dart';

class VocabularyService {
  VocabularyService(this._client);

  final SupabaseClient _client;

  Future<List<VocabularyEntry>> fetchAll(String userId) async {
    final rows = await _client
        .from('vocabulary')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return rows.map((e) => VocabularyEntry.fromJson(e)).toList();
  }

  Future<void> save({
    required String userId,
    required String wordHu,
    required String translationUk,
    String? contextHu,
    String? videoId,
  }) async {
    await _client.from('vocabulary').upsert({
      'user_id': userId,
      'word_hu': wordHu,
      'translation_uk': translationUk,
      'context_hu': contextHu,
      'video_id': videoId,
    }, onConflict: 'user_id,word_hu');
  }

  Future<void> delete(String id) async {
    await _client.from('vocabulary').delete().eq('id', id);
  }

  Future<void> setStatus({required String id, required FlashcardStatus status}) async {
    await _client.from('vocabulary').update({
      'status': flashcardStatusToString(status),
      'last_reviewed_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<Set<String>> fetchSavedWords(String userId) async {
    final rows = await _client.from('vocabulary').select('word_hu').eq('user_id', userId);
    return rows.map((e) => e['word_hu'] as String).toSet();
  }
}
