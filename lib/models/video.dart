class Video {
  final String id;
  final String youtubeId;
  final String titleUk;
  final String? titleHu;
  final String? descriptionUk;
  final String? level;
  final int orderIndex;

  const Video({
    required this.id,
    required this.youtubeId,
    required this.titleUk,
    required this.titleHu,
    required this.descriptionUk,
    required this.level,
    required this.orderIndex,
  });

  String get thumbnailUrl => 'https://img.youtube.com/vi/$youtubeId/mqdefault.jpg';

  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      id: json['id'] as String,
      youtubeId: json['youtube_id'] as String,
      titleUk: json['title_uk'] as String,
      titleHu: json['title_hu'] as String?,
      descriptionUk: json['description_uk'] as String?,
      level: json['level'] as String?,
      orderIndex: json['order_index'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'youtube_id': youtubeId,
        'title_uk': titleUk,
        'title_hu': titleHu,
        'description_uk': descriptionUk,
        'level': level,
        'order_index': orderIndex,
      };
}

/// One caption line with its position in the video.
class TranscriptCue {
  final double start;
  final double duration;
  final String text;

  const TranscriptCue({required this.start, required this.duration, required this.text});

  double get end => start + duration;

  bool containsTime(double seconds) => seconds >= start && seconds < end;

  /// Splits the line into tappable words, keeping punctuation out of the
  /// word itself so lookups aren't polluted by commas/question marks.
  List<String> get words =>
      text.split(RegExp(r'\s+')).where((w) => w.trim().isNotEmpty).toList();

  factory TranscriptCue.fromJson(Map<String, dynamic> json) {
    return TranscriptCue(
      start: (json['start'] as num?)?.toDouble() ?? 0,
      duration: (json['dur'] as num?)?.toDouble() ?? 0,
      text: json['text'] as String? ?? '',
    );
  }
}

/// Strips punctuation so "Magyarországon?" looks up as "magyarországon".
String normaliseWord(String raw) {
  return raw
      .replaceAll(RegExp(r'''^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$''', unicode: true), '')
      .toLowerCase()
      .trim();
}
