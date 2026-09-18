import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/word_image.dart';

class WordImageService {
  WordImageService(this._client);

  final SupabaseClient _client;

  /// Returns a picture for [wordHu], or null when the word has no sensible
  /// illustration. Results are cached server-side, so repeat lookups are free.
  Future<WordImage?> fetchImage({
    required String wordHu,
    String? ukrainian,
    String? english,
  }) async {
    final response = await _client.functions.invoke('word-image', body: {
      'word': wordHu,
      if (ukrainian != null) 'ukrainian': ukrainian,
      if (english != null) 'english': english,
    });

    final data = response.data;
    if (data is! Map) return null;
    if (data['error'] != null) throw Exception(data['error']);

    return WordImage.fromJson(Map<String, dynamic>.from(data));
  }
}
