/// A group of topics — the course is organised into chapters so learners see
/// a path rather than a long flat list.
class Chapter {
  final String id;
  final String titleUk;
  final String? titleHu;
  final String? descriptionUk;
  final String? icon;
  final int orderIndex;

  const Chapter({
    required this.id,
    required this.titleUk,
    required this.titleHu,
    required this.descriptionUk,
    required this.icon,
    required this.orderIndex,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'] as String,
      titleUk: json['title_uk'] as String,
      titleHu: json['title_hu'] as String?,
      descriptionUk: json['description_uk'] as String?,
      icon: json['icon'] as String?,
      orderIndex: json['order_index'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'title_uk': titleUk,
        'title_hu': titleHu,
        'description_uk': descriptionUk,
        'icon': icon,
        'order_index': orderIndex,
      };
}
