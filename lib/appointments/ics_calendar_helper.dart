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

  ParsedIcsEvent({
    required this.summary,
    this.location,
    this.rawUid,
    this.apptId,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.status,
  });
}

class IcsCalendarHelper {
  /// Converte formato de data iCal (ex: 20261026T140000Z, 20261026T140000, 20261026) para DateTime
  static DateTime? parseIcsDateTime(String raw) {
    final clean = raw.trim();
    if (clean.length < 8) return null;
    try {
      final y = int.parse(clean.substring(0, 4));
      final m = int.parse(clean.substring(4, 6));
      final d = int.parse(clean.substring(6, 8));
      if (clean.contains('T')) {
        final tPart = clean.split('T')[1];
        final h = int.parse(tPart.substring(0, 2));
        final min = int.parse(tPart.substring(2, 4));
        final sec = tPart.length >= 6 ? int.parse(tPart.substring(4, 6)) : 0;
        if (clean.endsWith('Z')) {
          return DateTime.utc(y, m, d, h, min, sec).toLocal();
        }
        return DateTime(y, m, d, h, min, sec);
      }
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
  static List<ParsedIcsEvent> parseIcsEvents(String rawIcs) {
    final events = <ParsedIcsEvent>[];
    if (rawIcs.trim().isEmpty) return events;

    final eventMatches = RegExp(r'BEGIN:VEVENT([\s\S]*?)END:VEVENT').allMatches(rawIcs);

    for (final match in eventMatches) {
      final block = match.group(1)!;

      // Extrai Summary
      final summaryMatch = RegExp(r'SUMMARY:(.*)').firstMatch(block);
      final summary = summaryMatch?.group(1)?.trim() ?? 'Compromisso Importado';

      // Extrai Location
      final locMatch = RegExp(r'LOCATION:(.*)').firstMatch(block);
      final loc = locMatch?.group(1)?.trim();

      // Extrai UID (se originado do app ou externo)
      final uidMatch = RegExp(r'UID:(.*)').firstMatch(block);
      final rawUid = uidMatch?.group(1)?.trim();
      String? apptId;
      if (rawUid != null && rawUid.endsWith('@territorio.app')) {
        apptId = rawUid.replaceAll('@territorio.app', '').trim();
      }

      // Extrai DTSTART (com suporte a parâmetros como ;TZID=...)
      final startMatch = RegExp(r'DTSTART(?:;[^:\r\n]+)?:(\d{8}(?:T\d{6}Z?)?)').firstMatch(block);
      final startTime = (startMatch != null) ? parseIcsDateTime(startMatch.group(1)!) ?? DateTime.now() : DateTime.now();

      // Extrai DTEND (com suporte a parâmetros como ;TZID=...)
      final endMatch = RegExp(r'DTEND(?:;[^:\r\n]+)?:(\d{8}(?:T\d{6}Z?)?)').firstMatch(block);
      DateTime endTime = (endMatch != null)
          ? parseIcsDateTime(endMatch.group(1)!) ?? startTime.add(const Duration(minutes: 30))
          : startTime.add(const Duration(minutes: 30));

      int duration = endTime.difference(startTime).inMinutes;
      if (duration <= 0) {
        duration = 30;
        endTime = startTime.add(const Duration(minutes: 30));
      }

      // Extrai STATUS
      final statusMatch = RegExp(r'STATUS:(.*)').firstMatch(block);
      final rawStatus = statusMatch?.group(1)?.trim().toUpperCase();
      final status = rawStatus == 'CANCELLED' ? 'cancelado' : 'confirmado';

      events.add(ParsedIcsEvent(
        summary: summary,
        location: loc,
        rawUid: rawUid,
        apptId: apptId,
        startTime: startTime,
        endTime: endTime,
        durationMinutes: duration,
        status: status,
      ));
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
      buffer.writeln('STATUS:${a.status == "cancelado" ? "CANCELLED" : "CONFIRMED"}');
      buffer.writeln('END:VEVENT');
    }

    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }
}
