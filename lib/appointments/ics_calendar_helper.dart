import '../database/app_database.dart';

class ParsedIcsEvent {
  final String summary;
  final String? location;
  final String? rawUid;
  final String? apptId;
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;
  final String status;
  final bool isAllDay;
  final String? recurrenceRule;

  ParsedIcsEvent({
    required this.summary,
    this.location,
    this.rawUid,
    this.apptId,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.status,
    this.isAllDay = false,
    this.recurrenceRule,
  });
}

class IcsCalendarHelper {
  /// Converte formato de data iCal (ex: 20261026T140000Z, 20261026T140000, 20261026) para DateTime
  /// Retorna null se a string de data for inválida (nunca retorna DateTime.now() silenciosamente)
  static DateTime? parseIcsDateTime(String raw) {
    final clean = raw.trim();
    if (clean.length < 8) return null;
    try {
      final y = int.parse(clean.substring(0, 4));
      final m = int.parse(clean.substring(4, 6));
      final d = int.parse(clean.substring(6, 8));
      if (y < 1970 || y > 2100 || m < 1 || m > 12 || d < 1 || d > 31) {
        return null;
      }

      if (clean.contains('T')) {
        final tPart = clean.split('T')[1];
        if (tPart.length < 4) return null;
        final h = int.parse(tPart.substring(0, 2));
        final min = int.parse(tPart.substring(2, 4));
        final sec = tPart.length >= 6 ? int.parse(tPart.substring(4, 6)) : 0;

        if (h < 0 || h > 23 || min < 0 || min > 59 || sec < 0 || sec > 60) {
          return null;
        }

        if (clean.endsWith('Z')) {
          return DateTime.utc(y, m, d, h, min, sec).toLocal();
        }
        return DateTime(y, m, d, h, min, sec);
      }
      // Evento de dia inteiro (YYYYMMDD)
      return DateTime(y, m, d);
    } catch (_) {
      return null;
    }
  }

  /// Formata DateTime para o padrão iCal UTC: YYYYMMDDTHHMMSSZ
  static String formatIcsDateTime(DateTime dt) {
    final u = dt.toUtc();
    return '${u.year.toString().padLeft(4, '0')}'
        '${u.month.toString().padLeft(2, '0')}'
        '${u.day.toString().padLeft(2, '0')}T'
        '${u.hour.toString().padLeft(2, '0')}'
        '${u.minute.toString().padLeft(2, '0')}'
        '${u.second.toString().padLeft(2, '0')}Z';
  }

  /// Faz o parse de múltiplos eventos VEVENT em um conteúdo iCalendar (.ics)
  /// Rejeita eventos com datas inválidas ou ausentes (nunca inventa datas fictícias)
  static List<ParsedIcsEvent> parseIcsEvents(String rawIcs) {
    final events = <ParsedIcsEvent>[];
    if (rawIcs.trim().isEmpty) return events;

    // Desdobra linhas dobradas segundo a RFC 5545 (quebras seguidas de espaço ou tab)
    final unfolded = rawIcs
        .replaceAll(RegExp(r'\r?\n[ \t]'), '')
        .replaceAll('\r\n', '\n');

    final eventMatches = RegExp(
      r'BEGIN:VEVENT([\s\S]*?)END:VEVENT',
      caseSensitive: false,
    ).allMatches(unfolded);

    for (final match in eventMatches) {
      final block = match.group(1)!;

      // 1. Extrai e valida DTSTART obrigatório (rejeita evento se ausente ou inválido)
      final startMatch = RegExp(
        r'^DTSTART(?:;[^:\r\n]+)?:([0-9TZ]+)',
        multiLine: true,
        caseSensitive: false,
      ).firstMatch(block);
      if (startMatch == null) {
        // Evento inválido segundo RFC 5545: DTSTART é obrigatório
        continue;
      }
      final rawStart = startMatch.group(1)!;
      final startTime = parseIcsDateTime(rawStart);
      if (startTime == null) {
        // Data inválida: rejeita evento
        continue;
      }

      final isAllDay = !rawStart.contains('T');

      // 2. Extrai DTEND ou calcula por duração
      final endMatch = RegExp(
        r'^DTEND(?:;[^:\r\n]+)?:([0-9TZ]+)',
        multiLine: true,
        caseSensitive: false,
      ).firstMatch(block);
      DateTime? parsedEnd;
      if (endMatch != null) {
        parsedEnd = parseIcsDateTime(endMatch.group(1)!);
      }

      // Se DTEND ausente ou anterior, calcula término coerente
      DateTime endTime;
      if (parsedEnd != null && parsedEnd.isAfter(startTime)) {
        endTime = parsedEnd;
      } else if (isAllDay) {
        endTime = startTime.add(const Duration(days: 1));
      } else {
        endTime = startTime.add(const Duration(minutes: 30));
      }

      int duration = endTime.difference(startTime).inMinutes;
      if (duration <= 0) {
        duration = isAllDay ? 1440 : 30;
      }

      // 3. Extrai Summary
      final summaryMatch = RegExp(
        r'^SUMMARY(?:;[^:\r\n]+)?:(.*)$',
        multiLine: true,
        caseSensitive: false,
      ).firstMatch(block);
      var summary = summaryMatch?.group(1)?.trim() ?? 'Compromisso Importado';
      summary = summary
          .replaceAll(r'\,', ',')
          .replaceAll(r'\;', ';')
          .replaceAll(r'\\', r'\')
          .replaceAll(r'\n', ' ')
          .replaceAll(r'\N', ' ')
          .trim();
      if (summary.isEmpty) summary = 'Compromisso Importado';

      // 4. Extrai Location
      final locMatch = RegExp(
        r'^LOCATION(?:;[^:\r\n]+)?:(.*)$',
        multiLine: true,
        caseSensitive: false,
      ).firstMatch(block);
      var loc = locMatch?.group(1)?.trim();
      if (loc != null) {
        loc = loc
            .replaceAll(r'\,', ',')
            .replaceAll(r'\;', ';')
            .replaceAll(r'\\', r'\')
            .replaceAll(r'\n', ' ')
            .replaceAll(r'\N', ' ')
            .trim();
        if (loc.isEmpty) loc = null;
      }

      // 5. Extrai UID
      final uidMatch = RegExp(
        r'^UID(?:;[^:\r\n]+)?:(.*)$',
        multiLine: true,
        caseSensitive: false,
      ).firstMatch(block);
      final rawUid = uidMatch?.group(1)?.trim();
      String? apptId;
      if (rawUid != null &&
          (rawUid.endsWith('@territorio.app') ||
              rawUid.endsWith('@ministeriopessoal.app'))) {
        apptId = rawUid
            .replaceAll('@territorio.app', '')
            .replaceAll('@ministeriopessoal.app', '')
            .trim();
      }

      // 6. Extrai STATUS
      final statusMatch = RegExp(
        r'^STATUS(?:;[^:\r\n]+)?:(.*)$',
        multiLine: true,
        caseSensitive: false,
      ).firstMatch(block);
      final rawStatus = statusMatch?.group(1)?.trim().toUpperCase();
      final status = rawStatus == 'CANCELLED' ? 'cancelado' : 'confirmado';

      // 7. Extrai RRULE (Regra de Recorrência)
      final rruleMatch = RegExp(
        r'^RRULE(?:;[^:\r\n]+)?:(.*)$',
        multiLine: true,
        caseSensitive: false,
      ).firstMatch(block);
      final rrule = rruleMatch?.group(1)?.trim();

      events.add(
        ParsedIcsEvent(
          summary: summary,
          location: loc,
          rawUid: rawUid,
          apptId: apptId,
          startTime: startTime,
          endTime: endTime,
          durationMinutes: duration,
          status: status,
          isAllDay: isAllDay,
          recurrenceRule: rrule,
        ),
      );
    }

    return events;
  }

  /// Gera representação iCal padrão RFC 5545 para exportação
  static String generateIcsCalendar(List<AppointmentEntry> appointments) {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//Território Ministério Pessoal//Agenda//PT');
    buffer.writeln('CALSCALE:GREGORIAN');
    buffer.writeln('METHOD:PUBLISH');

    for (final a in appointments) {
      if (a.deletedAt != null) continue;
      final startStr = formatIcsDateTime(a.startTime);
      final endStr = formatIcsDateTime(a.endTime);

      buffer.writeln('BEGIN:VEVENT');
      buffer.writeln('UID:${a.id}@territorio.app');
      buffer.writeln('DTSTAMP:${formatIcsDateTime(DateTime.now())}');
      buffer.writeln('DTSTART:$startStr');
      buffer.writeln('DTEND:$endStr');
      buffer.writeln('SUMMARY:${a.title}');
      if (a.locationNotes != null && a.locationNotes!.isNotEmpty) {
        buffer.writeln('LOCATION:${a.locationNotes}');
      }
      buffer.writeln(
        'STATUS:${a.status == "cancelado" ? "CANCELLED" : "CONFIRMED"}',
      );
      buffer.writeln('END:VEVENT');
    }

    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }
}
