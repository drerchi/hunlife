import 'package:flutter_test/flutter_test.dart';
import 'package:hunlife/core/util/hungarian_date.dart';

void main() {
  group('spellUnder100', () {
    test('units and exact tens', () {
      expect(HungarianDate.spellUnder100(1), 'egy');
      expect(HungarianDate.spellUnder100(5), 'öt');
      expect(HungarianDate.spellUnder100(10), 'tíz');
      expect(HungarianDate.spellUnder100(20), 'húsz');
      expect(HungarianDate.spellUnder100(30), 'harminc');
      expect(HungarianDate.spellUnder100(90), 'kilencven');
    });

    test('teens use tizen-, twenties use huszon-', () {
      expect(HungarianDate.spellUnder100(11), 'tizenegy');
      expect(HungarianDate.spellUnder100(18), 'tizennyolc');
      expect(HungarianDate.spellUnder100(21), 'huszonegy');
      expect(HungarianDate.spellUnder100(25), 'huszonöt');
    });

    test('other compounds join the ten and the unit', () {
      expect(HungarianDate.spellUnder100(35), 'harmincöt');
      expect(HungarianDate.spellUnder100(78), 'hetvennyolc');
      expect(HungarianDate.spellUnder100(99), 'kilencvenkilenc');
    });
  });

  group('spellYear', () {
    test('1900s are written as one word', () {
      expect(HungarianDate.spellYear(1978), 'ezerkilencszázhetvennyolc');
      expect(HungarianDate.spellYear(1995), 'ezerkilencszázkilencvenöt');
    });

    test('round thousands', () {
      expect(HungarianDate.spellYear(2000), 'kétezer');
    });

    test('past 2000 the remainder is hyphenated', () {
      expect(HungarianDate.spellYear(2001), 'kétezer-egy');
      expect(HungarianDate.spellYear(2018), 'kétezer-tizennyolc');
      expect(HungarianDate.spellYear(2024), 'kétezer-huszonnégy');
    });
  });

  group('spell (full date)', () {
    test('matches how the date is said aloud', () {
      expect(
        HungarianDate.spell(DateTime(2000, 12, 13)),
        'kétezer december tizenharmadikán',
      );
      expect(
        HungarianDate.spell(DateTime(1978, 7, 11)),
        'ezerkilencszázhetvennyolc július tizenegyedikén',
      );
      expect(
        HungarianDate.spell(DateTime(1990, 1, 1)),
        'ezerkilencszázkilencven január elsején',
      );
      expect(
        HungarianDate.spell(DateTime(2005, 3, 31)),
        'kétezer-öt március harmincegyedikén',
      );
    });

    test('written form for documents', () {
      expect(HungarianDate.written(DateTime(2000, 12, 13)), '2000. december 13.');
    });
  });

  group('UkrainianDate', () {
    test('uses the genitive month', () {
      expect(UkrainianDate.spell(DateTime(2000, 12, 13)), '13 грудня 2000 року');
      expect(UkrainianDate.spell(DateTime(1978, 7, 11)), '11 липня 1978 року');
    });
  });
}
