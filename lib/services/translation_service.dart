import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class TranslationResult {
  final String translation;

  /// An English gloss shown as a second opinion, since a single machine
  /// translation of a short word is easy to get wrong.
  final String? english;

  const TranslationResult({required this.translation, this.english});
}

/// Translates Hungarian words for the learner.
///
/// The translation happens **on the device** rather than on the server. The
/// quality difference is stark — from Supabase's datacenter IP Google replies
/// 429 and the remaining free engines are unusable, leaving a dictionary that
/// rendered "család" (family) as "гарнітура" (headset). From an ordinary
/// connection the same endpoint answers correctly, and it permits
/// cross-origin reads, so the app can call it directly.
///
/// Every result is written back to the shared cache, so a word is only ever
/// looked up once across all learners, and the server-side function remains
/// as a fallback.
class TranslationService {
  TranslationService(this._client);

  final SupabaseClient _client;
  final Map<String, TranslationResult> _memory = {};

  Future<TranslationResult> translate(String text) async {
    final key = text.trim().toLowerCase();
    if (key.isEmpty) throw ArgumentError('text is empty');

    final remembered = _memory[key];
    if (remembered != null) return remembered;

    final cached = await _fromCache(key);
    if (cached != null) {
      _memory[key] = cached;
      return cached;
    }

    TranslationResult? result;
    try {
      final uk = await _google(key, 'uk');
      if (uk != null) {
        final en = await _google(key, 'en');
        result = TranslationResult(translation: uk, english: en);
        unawaited(_saveToCache(key, result));
      }
    } catch (e) {
      debugPrint('On-device translation failed for "$key": $e');
    }

    result ??= await _fromEdgeFunction(key);

    _memory[key] = result;
    return result;
  }

  Future<TranslationResult?> _fromCache(String key) async {
    try {
      final row = await _client
          .from('translation_cache')
          .select('translated_text, english_text')
          .eq('source_text', key)
          .eq('source_lang', 'hu')
          .eq('target_lang', 'uk')
          .maybeSingle();

      if (row == null) return null;
      return TranslationResult(
        translation: row['translated_text'] as String,
        english: row['english_text'] as String?,
      );
    } catch (e) {
      debugPrint('Translation cache lookup failed: $e');
      return null;
    }
  }

  /// The dict-chrome-ex endpoint returns a plain ["translation"] array, which
  /// is far easier to parse than the nested gtx response.
  Future<String?> _google(String text, String targetLang) async {
    final uri = Uri.parse(
      'https://clients5.google.com/translate_a/t'
      '?client=dict-chrome-ex&sl=hu&tl=$targetLang&q=${Uri.encodeComponent(text)}',
    );

    final res = await http.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;

    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    final value = _firstString(decoded);
    if (value == null) return null;

    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// The response is sometimes ["text"] and sometimes [[["text", ...]]].
  static String? _firstString(dynamic node) {
    if (node is String) return node;
    if (node is List) {
      for (final child in node) {
        final found = _firstString(child);
        if (found != null) return found;
      }
    }
    return null;
  }

  Future<void> _saveToCache(String key, TranslationResult result) async {
    try {
      await _client.from('translation_cache').upsert({
        'source_text': key,
        'source_lang': 'hu',
        'target_lang': 'uk',
        'translated_text': result.translation,
        'english_text': result.english,
      });
    } catch (e) {
      // A learner failing to fill the shared cache must not break their lookup.
      debugPrint('Could not cache translation for "$key": $e');
    }
  }

  Future<TranslationResult> _fromEdgeFunction(String text) async {
    final response = await _client.functions.invoke('translate', body: {'text': text});
    final data = response.data;
    if (data is Map && data['error'] != null) throw Exception(data['error']);

    final map = data as Map;
    return TranslationResult(
      translation: map['translation'] as String,
      english: map['english'] as String?,
    );
  }
}
