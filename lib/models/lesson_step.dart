enum LessonStepKind { phrase, note, quiz }

LessonStepKind lessonStepKindFromString(String? value) {
  switch (value) {
    case 'note':
      return LessonStepKind.note;
    case 'quiz':
      return LessonStepKind.quiz;
    default:
      return LessonStepKind.phrase;
  }
}

String lessonStepKindToString(LessonStepKind kind) {
  switch (kind) {
    case LessonStepKind.note:
      return 'note';
    case LessonStepKind.quiz:
      return 'quiz';
    case LessonStepKind.phrase:
      return 'phrase';
  }
}

/// One screen of a lesson: a phrase to learn, a note to read, or a quick
/// check. Lessons play these back one at a time instead of dumping a wall of
/// text at the learner.
class LessonStep {
  final String id;
  final String lessonId;
  final int orderIndex;
  final LessonStepKind kind;

  final String? textHu;
  final String? textUk;
  final String? exampleHu;
  final String? exampleUk;

  final String? questionUk;
  final List<String> options;
  final int? correctOption;

  const LessonStep({
    required this.id,
    required this.lessonId,
    required this.orderIndex,
    required this.kind,
    required this.textHu,
    required this.textUk,
    required this.exampleHu,
    required this.exampleUk,
    required this.questionUk,
    required this.options,
    required this.correctOption,
  });

  factory LessonStep.fromJson(Map<String, dynamic> json) {
    return LessonStep(
      id: json['id'] as String,
      lessonId: json['lesson_id'] as String,
      orderIndex: json['order_index'] as int? ?? 0,
      kind: lessonStepKindFromString(json['kind'] as String?),
      textHu: json['text_hu'] as String?,
      textUk: json['text_uk'] as String?,
      exampleHu: json['example_hu'] as String?,
      exampleUk: json['example_uk'] as String?,
      questionUk: json['question_uk'] as String?,
      options: (json['options'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      correctOption: json['correct_option'] as int?,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'lesson_id': lessonId,
        'order_index': orderIndex,
        'kind': lessonStepKindToString(kind),
        'text_hu': textHu,
        'text_uk': textUk,
        'example_hu': exampleHu,
        'example_uk': exampleUk,
        'question_uk': questionUk,
        'options': options.isEmpty ? null : options,
        'correct_option': correctOption,
      };
}
