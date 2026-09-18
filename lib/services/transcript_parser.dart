import '../models/video.dart';

/// Parses pasted caption text into timed cues.
///
/// YouTube blocks server-side caption fetching from datacenter IPs (HTTP
/// 429), so the reliable path is pasting a transcript in. This accepts the
/// three formats a person can actually get hold of:
///
///  * YouTube's own "Show transcript" panel, copied straight out of the
///    browser — `0:05` / text on alternating lines, or `0:05 text` inline.
///  * SRT (`00:00:05,000 --> 00:00:07,000`)
///  * WebVTT (`00:00:05.000 --> 00:00:07.000`)
class TranscriptParser {
  const TranscriptParser._();

  static final _srtVttTime = RegExp(
    r'(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})\s*-->\s*(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})',
  );

  // "0:05", "1:02:33" — optionally followed by the caption text on the same line.
  static final _plainTime = RegExp(r'^\[?(\d{1,2}):(\d{2})(?::(\d{2}))?\]?\s*(.*)$');

  /// Some transcript exports prefix each line with an elapsed-time label
  /// ("9 seconds", "1 minute"). That's duplicated by the timestamp column and
  /// just clutters the caption, so strip it from the spoken text.
  /// Leading punctuation is allowed because merged lines often arrive as
  /// ", 9 secondsnem ..." rather than starting cleanly at the digit.
  static final _elapsedLabel = RegExp(
    r'^[\s,.;:\-–—]*\d+\s*(seconds?|secs?|minutes?|mins?|hours?|годин\w*|хвилин\w*|секунд\w*)\s*',
    caseSensitive: false,
  );

  static String _stripElapsedLabel(String text) {
    var out = text;
    // The label can repeat when several source lines were merged into one cue.
    for (var i = 0; i < 3; i++) {
      final cleaned = out.replaceFirst(_elapsedLabel, '');
      if (cleaned == out) break;
      out = cleaned;
    }
    return out.trim();
  }

  static List<TranscriptCue> parse(String input) {
    final text = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
    if (text.isEmpty) return [];

    final cues = _srtVttTime.hasMatch(text) ? _parseSrtVtt(text) : _parsePlain(text);

    return cues
        .map((c) => TranscriptCue(
              start: c.start,
              duration: c.duration,
              text: _stripElapsedLabel(c.text),
            ))
        .where((c) => c.text.isNotEmpty)
        .toList();
  }

  static List<TranscriptCue> _parseSrtVtt(String text) {
    final cues = <TranscriptCue>[];
    final blocks = text.split(RegExp(r'\n\s*\n'));

    for (final block in blocks) {
      final match = _srtVttTime.firstMatch(block);
      if (match == null) continue;

      final start = _seconds(match.group(1)!, match.group(2)!, match.group(3)!, match.group(4)!);
      final end = _seconds(match.group(5)!, match.group(6)!, match.group(7)!, match.group(8)!);

      // Everything after the timing line is the caption body.
      final lines = block.split('\n');
      final timingIndex = lines.indexWhere((l) => _srtVttTime.hasMatch(l));
      final body = lines
          .skip(timingIndex + 1)
          .join(' ')
          .replaceAll(RegExp(r'<[^>]+>'), '') // strip VTT inline tags
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      if (body.isNotEmpty) {
        cues.add(TranscriptCue(start: start, duration: (end - start).clamp(0, 60), text: body));
      }
    }
    return cues;
  }

  static List<TranscriptCue> _parsePlain(String text) {
    final rawLines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    final starts = <double>[];
    final bodies = <String>[];
    String? pendingTime;

    for (final line in rawLines) {
      final match = _plainTime.firstMatch(line);
      if (match != null) {
        final h = match.group(3) != null ? match.group(1)! : '0';
        final m = match.group(3) != null ? match.group(2)! : match.group(1)!;
        final s = match.group(3) ?? match.group(2)!;
        final start = _seconds(h, m, s, '0');
        final inline = match.group(4)?.trim() ?? '';

        if (inline.isNotEmpty) {
          // "0:05 some text" — timestamp and caption on one line.
          starts.add(start);
          bodies.add(inline);
          pendingTime = null;
        } else {
          // Timestamp alone; the caption is on the following line(s).
          pendingTime = start.toString();
        }
        continue;
      }

      if (pendingTime != null) {
        starts.add(double.parse(pendingTime));
        bodies.add(line);
        pendingTime = null;
      } else if (bodies.isNotEmpty) {
        // Continuation of the previous caption.
        bodies[bodies.length - 1] = '${bodies.last} $line';
      }
    }

    final cues = <TranscriptCue>[];
    for (int i = 0; i < starts.length; i++) {
      // A cue runs until the next one starts; the last gets a sensible default.
      final duration = i + 1 < starts.length ? starts[i + 1] - starts[i] : 4.0;
      cues.add(TranscriptCue(
        start: starts[i],
        duration: duration.clamp(0.5, 30),
        text: bodies[i].replaceAll(RegExp(r'\s+'), ' ').trim(),
      ));
    }
    return cues.where((c) => c.text.isNotEmpty).toList();
  }

  static double _seconds(String h, String m, String s, String ms) {
    return int.parse(h) * 3600 +
        int.parse(m) * 60 +
        int.parse(s) +
        int.parse(ms.padRight(3, '0')) / 1000;
  }
}
