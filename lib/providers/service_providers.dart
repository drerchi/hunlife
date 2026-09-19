import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/content_service.dart';
import '../services/profile_service.dart';
import '../services/translation_service.dart';
import '../services/tts_service.dart';
import '../services/video_service.dart';
import '../services/vocabulary_service.dart';
import '../services/word_image_service.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseClientProvider));
});

final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService(ref.watch(supabaseClientProvider));
});

final contentServiceProvider = Provider<ContentService>((ref) {
  return ContentService(ref.watch(supabaseClientProvider));
});

final adminServiceProvider = Provider<AdminService>((ref) {
  return AdminService(ref.watch(supabaseClientProvider));
});

final videoServiceProvider = Provider<VideoService>((ref) {
  return VideoService(ref.watch(supabaseClientProvider));
});

final vocabularyServiceProvider = Provider<VocabularyService>((ref) {
  return VocabularyService(ref.watch(supabaseClientProvider));
});

final wordImageServiceProvider = Provider<WordImageService>((ref) {
  return WordImageService(ref.watch(supabaseClientProvider));
});

/// Not autoDispose: it keeps an in-memory map of words already translated, so
/// re-tapping a word during a lesson costs nothing.
final translationServiceProvider = Provider<TranslationService>((ref) {
  return TranslationService(ref.watch(supabaseClientProvider));
});

/// Kept alive app-wide so generated audio URLs stay cached for the session.
final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = TtsService(ref.watch(supabaseClientProvider));
  ref.onDispose(service.stop);
  return service;
});
