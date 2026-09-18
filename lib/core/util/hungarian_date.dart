/// Spells dates and numbers the way they are *said* in Hungarian.
///
/// At the interview the candidate has to say their date of birth out loud —
/// "kétezer december tizenharmadikán", not "2000.12.13." — so the app shows
/// the spoken form rather than digits.
class HungarianDate {
  const HungarianDate._();

  static const List<String> _months = [
    'január', 'február', 'március', 'április', 'május', 'június',
    'július', 'augusztus', 'szeptember', 'október', 'november', 'december',
  ];

  /// Day of month in the superessive case ("on the 13th"). Irregular enough
  /// that a table is clearer and safer than generating the endings.
  static const List<String> _daysOn = [
    '', 'elsején', 'másodikán', 'harmadikán', 'negyedikén', 'ötödikén',
    'hatodikán', 'hetedikén', 'nyolcadikán', 'kilencedikén', 'tizedikén',
    'tizenegyedikén', 'tizenkettedikén', 'tizenharmadikán', 'tizennegyedikén',
    'tizenötödikén', 'tizenhatodikán', 'tizenhetedikén', 'tizennyolcadikán',
    'tizenkilencedikén', 'huszadikán', 'huszonegyedikén', 'huszonkettedikén',
    'huszonharmadikán', 'huszonnegyedikén', 'huszonötödikén', 'huszonhatodikán',
    'huszonhetedikén', 'huszonnyolcadikán', 'huszonkilencedikén',
    'harmincadikán', 'harmincegyedikén',
  ];

  static const List<String> _units = [
    '', 'egy', 'kettő', 'három', 'négy', 'öt', 'hat', 'hét', 'nyolc', 'kilenc',
  ];

  /// Two is "kettő" on its own but "két" as a multiplier — kétezer, kétszáz,
  /// never "kettőezer".
  static const List<String> _multipliers = [
    '', 'egy', 'két', 'három', 'négy', 'öt', 'hat', 'hét', 'nyolc', 'kilenc',
  ];

  static const List<String> _tens = [
    '', 'tíz', 'húsz', 'harminc', 'negyven', 'ötven',
    'hatvan', 'hetven', 'nyolcvan', 'kilencven',
  ];

  /// 0–99 in words. 11–19 use "tizen-" and 21–29 "huszon-" rather than the
  /// plain ten-word.
  static String spellUnder100(int n) {
    if (n < 0 || n > 99) return n.toString();
    if (n < 10) return _units[n];
    if (n == 10) return 'tíz';
    if (n == 20) return 'húsz';

    final tens = n ~/ 10;
    final unit = n % 10;
    if (unit == 0) return _tens[tens];

    final prefix = switch (tens) {
      1 => 'tizen',
      2 => 'huszon',
      _ => _tens[tens],
    };
    return '$prefix${_units[unit]}';
  }

  static String _spellHundreds(int n) {
    if (n == 0) return '';
    final hundreds = n ~/ 100;
    final rest = n % 100;
    final head = hundreds == 1 ? 'száz' : '${_multipliers[hundreds]}száz';
    return rest == 0 ? head : '$head${spellUnder100(rest)}';
  }

  /// Years as spoken: 1978 -> "ezerkilencszázhetvennyolc",
  /// 2000 -> "kétezer", 2018 -> "kétezer-tizennyolc".
  static String spellYear(int year) {
    if (year < 1000 || year > 2999) return year.toString();

    final thousands = year ~/ 1000;
    final rest = year % 1000;
    final head = thousands == 1 ? 'ezer' : '${_multipliers[thousands]}ezer';

    if (rest == 0) return head;

    final tail = rest >= 100 ? _spellHundreds(rest) : spellUnder100(rest);

    // Years past 2000 are hyphenated when a remainder follows; the 1000s
    // are written as a single word.
    return thousands == 1 ? '$head$tail' : '$head-$tail';
  }

  /// Full spoken date: "kétezer december tizenharmadikán".
  static String spell(DateTime date) {
    final day = date.day >= 1 && date.day <= 31 ? _daysOn[date.day] : '${date.day}.';
    return '${spellYear(date.year)} ${_months[date.month - 1]} $day';
  }

  /// Written form as it appears on documents: "2000. december 13."
  static String written(DateTime date) {
    return '${date.year}. ${_months[date.month - 1]} ${date.day}.';
  }
}

/// Ukrainian rendering, for the translation shown beneath the Hungarian.
class UkrainianDate {
  const UkrainianDate._();

  static const List<String> _monthsGenitive = [
    'січня', 'лютого', 'березня', 'квітня', 'травня', 'червня',
    'липня', 'серпня', 'вересня', 'жовтня', 'листопада', 'грудня',
  ];

  static const List<String> _units = [
    '', 'один', 'два', 'три', 'чотири', 'п\'ять',
    'шість', 'сім', 'вісім', 'дев\'ять',
  ];

  static const List<String> _teens = [
    'десять', 'одинадцять', 'дванадцять', 'тринадцять', 'чотирнадцять',
    'п\'ятнадцять', 'шістнадцять', 'сімнадцять', 'вісімнадцять', 'дев\'ятнадцять',
  ];

  static const List<String> _tens = [
    '', '', 'двадцять', 'тридцять', 'сорок', 'п\'ятдесят',
    'шістдесят', 'сімдесят', 'вісімдесят', 'дев\'яносто',
  ];

  static String spell(DateTime date) {
    return '${date.day} ${_monthsGenitive[date.month - 1]} ${date.year} року';
  }

  static String spellNumber(int n) {
    if (n < 0 || n > 99) return n.toString();
    if (n < 10) return _units[n];
    if (n < 20) return _teens[n - 10];
    final unit = n % 10;
    return unit == 0 ? _tens[n ~/ 10] : '${_tens[n ~/ 10]} ${_units[unit]}';
  }

  /// "рік / роки / років" — Ukrainian picks the form from the final digits.
  static String yearsWord(int n) {
    final lastTwo = n % 100;
    if (lastTwo >= 11 && lastTwo <= 14) return 'років';
    switch (n % 10) {
      case 1:
        return 'рік';
      case 2:
      case 3:
      case 4:
        return 'роки';
      default:
        return 'років';
    }
  }

  static String spellAge(int years) => '${spellNumber(years)} ${yearsWord(years)}';
}
