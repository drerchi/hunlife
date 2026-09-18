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

  /// Shown when a detail hasn't been filled in yet, so the sentence still
  /// reads sensibly and the gap is obvious.
  static const _missingName = '[ваше ім\'я]';
  static const _missingDate = '[ваша дата народження]';
  static const _missingPlace = '[місце народження]';

  static String apply(String text, Profile? profile) {
    if (!text.contains('{{')) return text;

    final first = profile?.firstName?.trim() ?? '';
    final last = profile?.lastName?.trim() ?? '';
    final fullName = profile?.hungarianName ?? '';
    final birth = profile?.dateOfBirth;
    final place = profile?.birthPlace?.trim() ?? '';

    final hungarianDate = birth == null ? _missingDate : HungarianDate.spell(birth);
    final age = birth == null ? null : _ageOn(birth, DateTime.now());

    final replacements = <String, String>{
      // Age is derived from the date of birth rather than stored, so it can
      // never drift out of date — and a birthday updates it on its own.
      '{{age_hu}}': age == null
          ? '[вік]'
          : '${HungarianDate.spellUnder100(age)} éves',
      '{{age_uk}}': age == null ? '[вік]' : UkrainianDate.spellAge(age),
      '{{age_number}}': age?.toString() ?? '[вік]',
      '{{name}}': fullName.isEmpty ? _missingName : fullName,
      '{{first_name}}': first.isEmpty ? _missingName : first,
      '{{last_name}}': last.isEmpty ? _missingName : last,
      '{{name_spelled}}': fullName.isEmpty ? _missingName : _spellOut(fullName),
      '{{birth_date_hu}}': hungarianDate,
      '{{birth_date_hu_capital}}': _capitalise(hungarianDate),
      '{{birth_date_uk}}': birth == null ? _missingDate : UkrainianDate.spell(birth),
      '{{birth_place}}': place.isEmpty ? _missingPlace : place,
      '{{mother_name}}': (profile?.motherName?.trim().isNotEmpty ?? false)
          ? profile!.motherName!.trim()
          : '[ім\'я матері]',
      '{{father_name}}': (profile?.fatherName?.trim().isNotEmpty ?? false)
          ? profile!.fatherName!.trim()
          : '[ім\'я батька]',
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
