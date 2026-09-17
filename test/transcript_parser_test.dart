import 'package:flutter_test/flutter_test.dart';
import 'package:hunlife/models/video.dart';
import 'package:hunlife/services/transcript_parser.dart';

void main() {
  group('TranscriptParser', () {
    test('parses YouTube "Show transcript" copy-paste (time on its own line)', () {
      final cues = TranscriptParser.parse('''
0:05
Sziasztok, hogy vagytok?
0:09
Ma a családról beszélünk.
1:02
Ez az én édesanyám.
''');

      expect(cues.length, 3);
      expect(cues[0].start, 5);
      expect(cues[0].text, 'Sziasztok, hogy vagytok?');
      expect(cues[1].start, 9);
      expect(cues[2].start, 62);
      // A cue should run until the next one begins.
      expect(cues[0].duration, 4);
    });

    test('parses inline "0:05 text" format', () {
      final cues = TranscriptParser.parse('''
0:05 Jó napot kívánok!
0:10 Hogy hívnak téged?
''');

      expect(cues.length, 2);
      expect(cues[0].text, 'Jó napot kívánok!');
      expect(cues[1].start, 10);
    });

    test('parses SRT', () {
      final cues = TranscriptParser.parse('''
1
00:00:05,000 --> 00:00:08,500
Sziasztok!

2
00:00:08,500 --> 00:00:12,000
Ma a számokat tanuljuk.
''');

      expect(cues.length, 2);
      expect(cues[0].start, 5.0);
      expect(cues[0].duration, closeTo(3.5, 0.001));
      expect(cues[1].text, 'Ma a számokat tanuljuk.');
    });

    test('parses WebVTT and strips inline tags', () {
      final cues = TranscriptParser.parse('''
WEBVTT

00:00:01.000 --> 00:00:04.000
<v Speaker>Jó reggelt<i> mindenkinek</i>
''');

      expect(cues.length, 1);
      expect(cues[0].text, 'Jó reggelt mindenkinek');
    });

    test('handles hour-long timestamps', () {
      final cues = TranscriptParser.parse('''
1:02:33
Köszönöm a figyelmet.
''');

      expect(cues.single.start, 3753);
    });

    test('returns empty list for unparseable input', () {
      expect(TranscriptParser.parse(''), isEmpty);
      expect(TranscriptParser.parse('just some text with no timings'), isEmpty);
    });
  });

  group('normaliseWord', () {
    test('strips punctuation but keeps Hungarian accents', () {
      expect(normaliseWord('Magyarországon?'), 'magyarországon');
      expect(normaliseWord('"Szia!"'), 'szia');
      expect(normaliseWord('ünnep,'), 'ünnep');
      expect(normaliseWord('...'), '');
    });
  });
}
