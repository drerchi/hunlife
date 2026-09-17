class Lesson {
  final String id;
  final String topicId;
  final String titleUk;
  final String? titleHu;
  final String contentUk;
  final int orderIndex;

  const Lesson({
    required this.id,
    required this.topicId,
    required this.titleUk,
    required this.titleHu,
    required this.contentUk,
    required this.orderIndex,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as String,
      topicId: json['topic_id'] as String,
      titleUk: json['title_uk'] as String,
      titleHu: json['title_hu'] as String?,
      contentUk: json['content_uk'] as String? ?? '',
      orderIndex: json['order_index'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'topic_id': topicId,
        'title_uk': titleUk,
        'title_hu': titleHu,
        'content_uk': contentUk,
        'order_index': orderIndex,
      };
}
