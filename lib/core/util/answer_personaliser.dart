import '../../models/profile.dart';
import 'hungarian_date.dart';

/// Fills a learner's own details into interview answers.
///
/// Answers are stored with tokens ("{{name}} vagyok.") rather than a fixed
/// example name, because at the real interview the candidate answers with
/// their own details — so that is what they should be rehearsing.
///
/// Names stay in Latin script deliberately: a Ukrainian learner reading
/// "Ковач Петер" would have to transliterate it under pressure, whereas the
/// Latin form is what they'll actually have to pronounce.
class AnswerPersonaliser {
  const AnswerPersonaliser._();

  /// Details the learner hasn't filled in yet fall back to a plausible
  /// example rather than a bracketed gap, so the answer still reads as a
  /// complete Hungarian sentence they can practise saying. The account screen
  /// prompts them to replace these with their own details.
  static const _exampleName = 'Kovács Péter';
  static const _examplePlace = 'Ungváron';
  static const _exampleResidence = 'Budapesten';
  static const _exampleSince = 2018;
  static final DateTime _exampleBirth = DateTime(1995, 6, 15);
  static final DateTime _exampleMotherBirth = DateTime(1970, 4, 9);
  static const _exampleMother = 'Szabó Mária';
  static const _exampleFather = 'Kovács István';

  static String apply(String text, Profile? profile) {
    if (!text.contains('{{')) return text;

    String orExample(String? value, String example) {
      final trimmed = value?.trim() ?? '';
      return trimmed.isEmpty ? example : trimmed;
    }

    final fullName = orExample(profile?.hungarianName, _exampleName);
    final first = orExample(profile?.firstName, _exampleName.split(' ').last);
    final last = orExample(profile?.lastName, _exampleName.split(' ').first);

    final birth = profile?.dateOfBirth ?? _exampleBirth;
    final motherBirth = profile?.motherDateOfBirth ?? _exampleMotherBirth;
    final since = profile?.inHungarySince ?? _exampleSince;

    final hungarianDate = HungarianDate.spell(birth);
    final age = _ageOn(birth, DateTime.now());

    final replacements = <String, String>{
      // Age is derived from the date of birth rather than stored, so it can
      // never drift out of date — and a birthday updates it on its own.
      '{{age_hu}}': '${HungarianDate.spellUnder100(age)} éves',
      '{{age_uk}}': UkrainianDate.spellAge(age),
      '{{age_number}}': age.toString(),
      '{{name}}': fullName,
      '{{first_name}}': first,
      '{{last_name}}': last,
      '{{name_spelled}}': _spellOut(fullName),
      '{{birth_date_hu}}': hungarianDate,
      '{{birth_date_hu_capital}}': _capitalise(hungarianDate),
      '{{birth_date_uk}}': UkrainianDate.spell(birth),
      '{{birth_place}}': orExample(profile?.birthPlace, _examplePlace),
      '{{mother_name}}': orExample(profile?.motherName, _exampleMother),
      '{{father_name}}': orExample(profile?.fatherName, _exampleFather),
      '{{residence}}': orExample(profile?.residence, _exampleResidence),
      '{{in_hungary_since}}': since.toString(),
      '{{in_hungary_since_hu}}': HungarianDate.spellYear(since),
      '{{mother_birth_hu}}': HungarianDate.spell(motherBirth),
      '{{mother_birth_uk}}': UkrainianDate.spell(motherBirth),
    };

    var result = text;
    replacements.forEach((token, value) {
      result = result.replaceAll(token, value);
    });
    return result;
  }

  /// Whole years completed, counting the birthday correctly rather than just
  /// subtracting years.
  static int _ageOn(DateTime birth, DateTime today) {
    var years = today.year - birth.year;
    final hadBirthday = today.month > birth.month ||
        (today.month == birth.month && today.day >= birth.day);
    if (!hadBirthday) years--;
    return years < 0 ? 0 : years;
  }

  /// "Kovács Péter" -> "K-o-v-á-c-s P-é-t-e-r", for the "how do you spell
  /// your name?" question.
  static String _spellOut(String name) {
    return name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((word) => word.split('').join('-'))
        .join(' ');
  }

  static String _capitalise(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
