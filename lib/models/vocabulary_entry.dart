import 'flashcard.dart';

class VocabularyEntry {
  final String id;
  final String userId;
  final String wordHu;
  final String translationUk;
  final String? contextHu;
  final String? videoId;
  final FlashcardStatus status;
  final DateTime createdAt;

  const VocabularyEntry({
    required this.id,
    required this.userId,
    required this.wordHu,
    required this.translationUk,
    required this.contextHu,
    required this.videoId,
    required this.status,
    required this.createdAt,
  });

  factory VocabularyEntry.fromJson(Map<String, dynamic> json) {
    return VocabularyEntry(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      wordHu: json['word_hu'] as String,
      translationUk: json['translation_uk'] as String,
      contextHu: json['context_hu'] as String?,
      videoId: json['video_id'] as String?,
      status: flashcardStatusFromString(json['status'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Lets saved words be studied with the existing flashcard screen.
  Flashcard toFlashcard() => Flashcard(
        id: id,
        topicId: '',
        lessonId: null,
        frontHu: wordHu,
        backUk: translationUk,
        exampleHu: contextHu,
        exampleUk: null,
        orderIndex: 0,
        status: status,
      );
}
