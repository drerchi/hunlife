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

    final replacements = <String, String>{
      '{{name}}': fullName.isEmpty ? _missingName : fullName,
      '{{first_name}}': first.isEmpty ? _missingName : first,
      '{{last_name}}': last.isEmpty ? _missingName : last,
      '{{name_spelled}}': fullName.isEmpty ? _missingName : _spellOut(fullName),
      '{{birth_date_hu}}': hungarianDate,
      '{{birth_date_hu_capital}}': _capitalise(hungarianDate),
      '{{birth_date_uk}}': birth == null ? _missingDate : UkrainianDate.spell(birth),
      '{{birth_place}}': place.isEmpty ? _missingPlace : place,
    };

    var result = text;
    replacements.forEach((token, value) {
      result = result.replaceAll(token, value);
    });
    return result;
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
