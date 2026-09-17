class CitizenshipQuestion {
  final String id;
  final String category;
  final String questionHu;
  final String questionUk;
  final String answerHu;
  final String answerUk;
  final int orderIndex;

  const CitizenshipQuestion({
    required this.id,
    required this.category,
    required this.questionHu,
    required this.questionUk,
    required this.answerHu,
    required this.answerUk,
    required this.orderIndex,
  });

  factory CitizenshipQuestion.fromJson(Map<String, dynamic> json) {
    return CitizenshipQuestion(
      id: json['id'] as String,
      category: json['category'] as String? ?? 'Загальне',
      questionHu: json['question_hu'] as String,
      questionUk: json['question_uk'] as String,
      answerHu: json['answer_hu'] as String,
      answerUk: json['answer_uk'] as String,
      orderIndex: json['order_index'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'category': category,
        'question_hu': questionHu,
        'question_uk': questionUk,
        'answer_hu': answerHu,
        'answer_uk': answerUk,
        'order_index': orderIndex,
      };
}
