enum FlashcardStatus { newCard, learning, known }

FlashcardStatus flashcardStatusFromString(String? value) {
  switch (value) {
    case 'learning':
      return FlashcardStatus.learning;
    case 'known':
      return FlashcardStatus.known;
    default:
      return FlashcardStatus.newCard;
  }
}

String flashcardStatusToString(FlashcardStatus status) {
  switch (status) {
    case FlashcardStatus.learning:
      return 'learning';
    case FlashcardStatus.known:
      return 'known';
    case FlashcardStatus.newCard:
      return 'new';
  }
}

class Flashcard {
  final String id;
  final String topicId;
  final String? lessonId;
  final String frontHu;
  final String backUk;
  final String? exampleHu;
  final String? exampleUk;
  final int orderIndex;
  final FlashcardStatus status;

  const Flashcard({
    required this.id,
    required this.topicId,
    required this.lessonId,
    required this.frontHu,
    required this.backUk,
    required this.exampleHu,
    required this.exampleUk,
    required this.orderIndex,
    this.status = FlashcardStatus.newCard,
  });

  Flashcard copyWith({FlashcardStatus? status}) => Flashcard(
        id: id,
        topicId: topicId,
        lessonId: lessonId,
        frontHu: frontHu,
        backUk: backUk,
        exampleHu: exampleHu,
        exampleUk: exampleUk,
        orderIndex: orderIndex,
        status: status ?? this.status,
      );

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      id: json['id'] as String,
      topicId: json['topic_id'] as String,
      lessonId: json['lesson_id'] as String?,
      frontHu: json['front_hu'] as String,
      backUk: json['back_uk'] as String,
      exampleHu: json['example_hu'] as String?,
      exampleUk: json['example_uk'] as String?,
      orderIndex: json['order_index'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'topic_id': topicId,
        'lesson_id': lessonId,
        'front_hu': frontHu,
        'back_uk': backUk,
        'example_hu': exampleHu,
        'example_uk': exampleUk,
        'order_index': orderIndex,
      };
}
