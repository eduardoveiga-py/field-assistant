/// Feriados nacionais do Brasil (fixos e móveis calculados a partir da Páscoa).
///
/// Usado para exibir feriados no calendário do app (somente leitura —
/// não são criados eventos editáveis no banco local).
class HolidayItem {
  final String name;
  final DateTime date; // sempre à meia-noite, horário local

  const HolidayItem({required this.name, required this.date});

  @override
  bool operator ==(Object other) =>
      other is HolidayItem && other.name == name && other.date == date;

  @override
  int get hashCode => name.hashCode ^ date.hashCode;

  @override
  String toString() => 'HolidayItem($name, ${date.toIso8601String()})';
}

class BrazilHolidays {
  BrazilHolidays._();

  /// Algoritmo Gregoriano anônimo (Meeus/Jones/Butcher) para o domingo de Páscoa.
  static DateTime easterSunday(int year) {
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

  /// Todos os feriados nacionais (fixos + móveis) do ano informado.
  static List<HolidayItem> forYear(int year) {
    final easter = easterSunday(year);
    return [
      HolidayItem(name: 'Confraternização Universal', date: DateTime(year, 1, 1)),
      HolidayItem(
        name: 'Terça-feira de Carnaval',
        date: easter.subtract(const Duration(days: 47)),
      ),
      HolidayItem(name: 'Tiradentes', date: DateTime(year, 4, 21)),
      HolidayItem(name: 'Dia do Trabalho', date: DateTime(year, 5, 1)),
      HolidayItem(
        name: 'Sexta-feira Santa',
        date: easter.subtract(const Duration(days: 2)),
      ),
      HolidayItem(name: 'Páscoa', date: easter),
      HolidayItem(name: 'Independência do Brasil', date: DateTime(year, 9, 7)),
      HolidayItem(name: 'Nossa Senhora Aparecida', date: DateTime(year, 10, 12)),
      HolidayItem(name: 'Finados', date: DateTime(year, 11, 2)),
      HolidayItem(
        name: 'Proclamação da República',
        date: DateTime(year, 11, 15),
      ),
      HolidayItem(
        name: 'Corpus Christi',
        date: easter.add(const Duration(days: 60)),
      ),
      HolidayItem(name: 'Natal', date: DateTime(year, 12, 25)),
    ]..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Feriados dentro de um intervalo inclusivo [start, end].
  static List<HolidayItem> inRange(DateTime start, DateTime end) {
    final from = DateTime(start.year, start.month, start.day);
    final to = DateTime(end.year, end.month, end.day).add(const Duration(days: 1));
    final result = <HolidayItem>[];
    for (var y = from.year - 1; y <= to.year + 1; y++) {
      for (final h in forYear(y)) {
        if (!h.date.isBefore(from) && h.date.isBefore(to)) {
          result.add(h);
        }
      }
    }
    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  /// Feriados que caem exatamente no dia informado.
  static List<HolidayItem> onDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    return inRange(start, start);
  }
}
