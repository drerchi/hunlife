/// A picture for a vocabulary word, with the credit its licence requires.
class WordImage {
  final String imageUrl;
  final String? thumbUrl;
  final String? attribution;
  final String? license;
  final String? sourceUrl;

  const WordImage({
    required this.imageUrl,
    required this.thumbUrl,
    required this.attribution,
    required this.license,
    required this.sourceUrl,
  });

  String get displayUrl => thumbUrl ?? imageUrl;

  /// Short credit line shown under the picture. Openverse and Wikipedia serve
  /// Creative Commons images, which may only be used with attribution.
  String? get creditLine {
    final parts = [
      if (attribution != null && attribution!.isNotEmpty) attribution,
      if (license != null && license!.isNotEmpty) license,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  static WordImage? fromJson(Map<String, dynamic> json) {
    final url = json['imageUrl'] as String?;
    if (url == null || url.isEmpty) return null;
    return WordImage(
      imageUrl: url,
      thumbUrl: json['thumbUrl'] as String?,
      attribution: json['attribution'] as String?,
      license: json['license'] as String?,
      sourceUrl: json['sourceUrl'] as String?,
    );
  }
}
