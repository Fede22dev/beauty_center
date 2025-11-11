import 'app_constants.dart';

DateTime easterCalculator(final int year) {
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = ((h + l - 7 * m + 114) % 31) + 1;
  return DateTime(year, month, day);
}

List<DateTime> holidayItalyByYear(final int year) {
  final easter = easterCalculator(year);
  final easterMonday = easter.add(const Duration(days: 1));

  return [
    DateTime(year), // Capodanno
    DateTime(year, 1, 6), // Epifania
    easter, // Pasqua
    easterMonday, // Pasquetta
    DateTime(year, 4, 25), // Festa della Liberazione
    DateTime(year, 5), // Festa dei Lavoratori
    DateTime(year, 6, 2), // Festa della Repubblica
    DateTime(year, 8, 15), // Assunzione di Maria
    DateTime(year, 11), // Ognissanti
    DateTime(year, 12, 8), // Immacolata Concezione
    DateTime(year, 12, 25), // Natale
    DateTime(year, 12, 26), // Santo Stefano
  ];
}

List<DateTime> allHolidaysItaly() {
  final days = <DateTime>[];

  for (var year = kMinYearCalendar; year <= kMaxYearCalendar; year++) {
    days.addAll(holidayItalyByYear(year));
  }

  days.sort((final a, final b) => a.compareTo(b));
  return days.toSet().toList();
}
