import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Speaks Hungarian with a real Hungarian voice for every learner.
///
/// The audio is synthesised server-side and cached, so pronunciation does not
/// depend on what voices a learner's device happens to have. That matters:
/// most Windows machines ship no Hungarian voice at all, so relying on the
/// browser's speech engine meant Hungarian was read aloud with an English
/// voice — actively teaching the wrong pronunciation.
///
/// The device engine is kept only as a fallback for when the audio service
/// can't be reached (offline, or the function is down).
class TtsService {
  TtsService(this._client);

  final SupabaseClient _client;
  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _deviceTts = FlutterTts();

  /// text -> cached audio URL, so repeats don't re-hit the function.
  final Map<String, String> _urlCache = {};

  bool _deviceTtsReady = false;
  bool _hasHungarianVoice = false;

  /// True when the last utterance had to fall back to the device voice, which
  /// may not be Hungarian at all.
  bool usedFallback = false;

  /// Set once the UI has warned about a missing Hungarian voice, so the
  /// message doesn't reappear on every tap.
  bool warnedAboutMissingVoice = false;

  bool get hasHungarianVoice => _hasHungarianVoice;

  Future<void> speak(String text) async {
    final trimmed = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) return;

    try {
      final url = await _audioUrl(trimmed);
      await _player.stop();
      await _player.play(UrlSource(url));
      usedFallback = false;
      return;
    } catch (e) {
      debugPrint('Hungarian audio unavailable, falling back to device TTS: $e');
    }

    usedFallback = true;
    await _speakWithDevice(trimmed);
  }

  Future<String> _audioUrl(String text) async {
    final cached = _urlCache[text];
    if (cached != null) return cached;

    final response = await _client.functions.invoke('speak', body: {'text': text});
    final data = response.data;
    if (data is Map && data['error'] != null) throw Exception(data['error']);

    final url = (data as Map)['url'] as String?;
    if (url == null || url.isEmpty) throw Exception('no audio url returned');

    _urlCache[text] = url;
    return url;
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {
      // Nothing playing.
    }
    try {
      await _deviceTts.stop();
    } catch (_) {
      // Nothing playing.
    }
  }

  // ---- Fallback: the device's own speech engine ---------------------------

  Future<void> _speakWithDevice(String text) async {
    await _ensureDeviceTts();
    try {
      await _deviceTts.stop();
      await _deviceTts.setLanguage('hu-HU');
      await _deviceTts.speak(text);
    } catch (e) {
      debugPrint('Device TTS failed: $e');
    }
  }

  Future<void> _ensureDeviceTts() async {
    if (_deviceTtsReady) return;
    _deviceTtsReady = true;
    try {
      await _deviceTts.setVolume(1.0);
      await _deviceTts.setPitch(1.0);
      await _deviceTts.setSpeechRate(kIsWeb ? 0.9 : 0.45);
      await _deviceTts.setLanguage('hu-HU');

      // Setting the language alone leaves browsers on their default (usually
      // English) voice, so pick a Hungarian one explicitly if one exists.
      final raw = await _deviceTts.getVoices;
      if (raw is! List) return;

      final voices = raw.whereType<Object>().map((v) {
        final map = Map<String, dynamic>.from(v as Map);
        return {
          'name': (map['name'] ?? '').toString(),
          'locale': (map['locale'] ?? map['language'] ?? '').toString(),
        };
      });

      final hungarian = voices.where((v) {
        final locale = v['locale']!.toLowerCase().replaceAll('_', '-');
        final name = v['name']!.toLowerCase();
        return locale.startsWith('hu') || name.contains('magyar') || name.contains('hungarian');
      }).toList();

      if (hungarian.isEmpty) {
        _hasHungarianVoice = false;
        return;
      }
      await _deviceTts.setVoice({
        'name': hungarian.first['name']!,
        'locale': hungarian.first['locale']!,
      });
      _hasHungarianVoice = true;
    } catch (e) {
      debugPrint('Device TTS init failed: $e');
    }
  }
}
