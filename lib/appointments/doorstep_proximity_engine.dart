import 'dart:math' as math;
import '../database/app_database.dart';

/// Modalidade de deslocamento no território para cálculo de rotas e segurança
enum DoorstepTravelMode {
  walking('A pé', 15, 1500, 4.5),
  driving('Veículo / Moto', 25, 10000, 30.0),
  boat('Embarcação / Barco', 35, 15000, 15.0);

  final String label;
  final int defaultBufferMinutes;
  final double maxRadiusMeters;
  final double averageSpeedKmh;

  const DoorstepTravelMode(
    this.label,
    this.defaultBufferMinutes,
    this.maxRadiusMeters,
    this.averageSpeedKmh,
  );
}

typedef TravelMode = DoorstepTravelMode;

/// Recomendação de horário para retorno / revisita na porta
class DoorstepSlotRecommendation {
  final DateTime startTime;
  final DateTime endTime;
  final String title;
  final String reasonLabel;
  final double? distanceMeters;
  final int travelBufferMinutes;
  final int? estimatedTravelMinutes;
  final DoorstepTravelMode travelMode;
  final bool hasConflict;
  final String? conflictDetails;

  const DoorstepSlotRecommendation({
    required this.startTime,
    required this.endTime,
    required this.title,
    required this.reasonLabel,
    this.distanceMeters,
    this.travelBufferMinutes = 15,
    this.estimatedTravelMinutes,
    this.travelMode = DoorstepTravelMode.walking,
    this.hasConflict = false,
    this.conflictDetails,
  });

  String get formattedDistance {
    if (distanceMeters == null) return '';
    if (distanceMeters! < 1000) {
      return '${distanceMeters!.toStringAsFixed(0)}m de distância';
    }
    return '${(distanceMeters! / 1000.0).toStringAsFixed(1)}km de distância';
  }

  /// Indica se este slot foi sugerido por proximidade física ou geográfica
  bool get isProximitySuggested =>
      distanceMeters != null ||
      reasonLabel.contains('Mesmo setor') ||
      reasonLabel.contains('Próximo');
}

/// Motor de agendamento por proximidade física e detecção de rotas
class DoorstepProximityEngine {
  DoorstepProximityEngine._();

  /// Gera recomendações inteligentes de horários para agendamento de retorno na porta
  static List<DoorstepSlotRecommendation> suggestSlots({
    required PersonEntry targetPerson,
    required List<PersonEntry> allPeople,
    required List<AppointmentEntry> existingAppointments,
    List<ExternalCalendarEventEntry> externalEvents = const [],
    DateTime? referenceNow,
    DoorstepTravelMode travelMode = DoorstepTravelMode.walking,
    int? customBufferMinutes,
  }) {
    final now = referenceNow ?? DateTime.now();
    final recommendations = <DoorstepSlotRecommendation>[];
    final peopleMap = {for (final p in allPeople) p.id: p};
    final bufferMinutes = customBufferMinutes ?? travelMode.defaultBufferMinutes;

    // 1. Procura compromissos nos próximos 7 dias que tenham pessoas geograficamente próximas ou no mesmo endereço
    final upcomingAppts = existingAppointments
        .where((a) =>
            a.deletedAt == null &&
            a.status != 'cancelado' &&
            a.startTime.isAfter(now) &&
            a.startTime.isBefore(now.add(const Duration(days: 7))))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    for (final appt in upcomingAppts) {
      final otherPerson = appt.personId != null ? peopleMap[appt.personId] : null;
      if (otherPerson == null) continue;
      if (otherPerson.id == targetPerson.id) continue;

      double? dist;
      if (targetPerson.latitude != null &&
          targetPerson.longitude != null &&
          otherPerson.latitude != null &&
          otherPerson.longitude != null) {
        dist = _haversineMeters(
          targetPerson.latitude!,
          targetPerson.longitude!,
          otherPerson.latitude!,
          otherPerson.longitude!,
        );
      }

      // Se georreferenciado, respeita estritamente o raio da modalidade de transporte.
      // Se não georreferenciado, sugere apenas quando o endereço/setor/comunidade for coincidente.
      final bool isWithinReach;
      if (dist != null) {
        isWithinReach = dist <= travelMode.maxRadiusMeters;
      } else {
        isWithinReach = _isSameNeighborhood(targetPerson.address, otherPerson.address);
      }

      if (isWithinReach) {
        final int estMinutes = dist != null
            ? ((dist / 1000.0) / travelMode.averageSpeedKmh * 60.0).ceil().clamp(5, 120)
            : bufferMinutes;

        // Sugere o horário após o término do compromisso anterior respeitando o buffer de deslocamento
        final candidateStart = appt.endTime.add(Duration(minutes: bufferMinutes));
        final candidateEnd = candidateStart.add(const Duration(minutes: 30));

        final conflict = _checkConflict(candidateStart, candidateEnd, existingAppointments, externalEvents);

        if (!_hasSlotOverlap(candidateStart, candidateEnd, recommendations)) {
          final String reason;
          if (dist != null) {
            final distStr = dist < 1000
                ? '${dist.toStringAsFixed(0)}m'
                : '${(dist / 1000).toStringAsFixed(1)}km';
            reason = 'Próximo de ${otherPerson.name} ($distStr • ${travelMode.label})';
          } else {
            reason = 'Mesmo setor/endereço que ${otherPerson.name} (${otherPerson.address ?? "conhecido"})';
          }

          recommendations.add(
            DoorstepSlotRecommendation(
              startTime: candidateStart,
              endTime: candidateEnd,
              title: 'Revisita com ${targetPerson.name}',
              reasonLabel: reason,
              distanceMeters: dist,
              travelBufferMinutes: bufferMinutes,
              estimatedTravelMinutes: estMinutes,
              travelMode: travelMode,
              hasConflict: conflict != null,
              conflictDetails: conflict,
            ),
          );
        }
      }

      if (recommendations.length >= 2) break;
    }

    // 2. Recomendação baseada na preferência do morador (preferredSchedule)
    final prefSlot = _suggestFromPreference(targetPerson, now, existingAppointments, externalEvents);
    if (prefSlot != null && !_hasSlotOverlap(prefSlot.startTime, prefSlot.endTime, recommendations)) {
      recommendations.add(prefSlot);
    }

    // 3. Fallbacks canônicos sem duplicações: Sábado 10:00, Terça 15:30, Domingo 10:00, Quinta 18:00, Sábado 14:30
    final fallbackCandidates = [
      (DateTime.saturday, 10, 0, 'Sábado pela manhã (Horário Nobre do Ministério)'),
      (DateTime.tuesday, 15, 30, 'Meio de semana à tarde'),
      (DateTime.sunday, 10, 0, 'Domingo pela manhã'),
      (DateTime.thursday, 18, 0, 'Quinta-feira ao final do dia'),
      (DateTime.saturday, 14, 30, 'Sábado à tarde'),
    ];

    for (final candidate in fallbackCandidates) {
      if (recommendations.length >= 3) break;
      final slot = _suggestNextWeekday(
        targetPerson: targetPerson,
        targetWeekday: candidate.$1,
        hour: candidate.$2,
        minute: candidate.$3,
        now: now,
        existingAppts: existingAppointments,
        externalEvents: externalEvents,
        reason: candidate.$4,
      );
      if (slot != null && !_hasSlotOverlap(slot.startTime, slot.endTime, recommendations)) {
        recommendations.add(slot);
      }
    }

    return recommendations;
  }

  static bool _hasSlotOverlap(
    DateTime start,
    DateTime end,
    List<DoorstepSlotRecommendation> existingRecs,
  ) {
    for (final rec in existingRecs) {
      if (rec.startTime == start) return true;
      if (start.isBefore(rec.endTime) && end.isAfter(rec.startTime)) return true;
    }
    return false;
  }

  static DoorstepSlotRecommendation? _suggestFromPreference(
    PersonEntry person,
    DateTime now,
    List<AppointmentEntry> appts,
    List<ExternalCalendarEventEntry> externalEvents,
  ) {
    final pref = person.preferredSchedule?.toLowerCase() ?? '';
    if (pref.isEmpty) return null;

    int targetDay = DateTime.saturday;
    int hour = 10;

    if (pref.contains('domingo')) {
      targetDay = DateTime.sunday;
    } else if (pref.contains('sabado') || pref.contains('sábado')) {
      targetDay = DateTime.saturday;
    } else if (pref.contains('segunda')) {
      targetDay = DateTime.monday;
    } else if (pref.contains('terca') || pref.contains('terça')) {
      targetDay = DateTime.tuesday;
    } else if (pref.contains('quarta')) {
      targetDay = DateTime.wednesday;
    } else if (pref.contains('quinta')) {
      targetDay = DateTime.thursday;
    } else if (pref.contains('sexta')) {
      targetDay = DateTime.friday;
    }

    if (pref.contains('manha') || pref.contains('manhã') || pref.contains('09') || pref.contains('10')) {
      hour = 10;
    } else if (pref.contains('tarde') || pref.contains('14') || pref.contains('15') || pref.contains('16')) {
      hour = 15;
    } else if (pref.contains('noite') || pref.contains('18') || pref.contains('19')) {
      hour = 18;
    }

    return _suggestNextWeekday(
      targetPerson: person,
      targetWeekday: targetDay,
      hour: hour,
      minute: 0,
      now: now,
      existingAppts: appts,
      externalEvents: externalEvents,
      reason: 'Preferência do morador: "${person.preferredSchedule}"',
    );
  }

  static DoorstepSlotRecommendation? _suggestNextWeekday({
    required PersonEntry targetPerson,
    required int targetWeekday,
    required int hour,
    required int minute,
    required DateTime now,
    required List<AppointmentEntry> existingAppts,
    required List<ExternalCalendarEventEntry> externalEvents,
    required String reason,
  }) {
    int daysToAdd = (targetWeekday - now.weekday) % 7;
    if (daysToAdd <= 0) daysToAdd += 7;

    final candidateDate = now.add(Duration(days: daysToAdd));
    final start = DateTime(candidateDate.year, candidateDate.month, candidateDate.day, hour, minute);
    final end = start.add(const Duration(minutes: 30));

    final conflict = _checkConflict(start, end, existingAppts, externalEvents);

    return DoorstepSlotRecommendation(
      startTime: start,
      endTime: end,
      title: 'Revisita com ${targetPerson.name}',
      reasonLabel: reason,
      hasConflict: conflict != null,
      conflictDetails: conflict,
    );
  }

  static String? _checkConflict(
    DateTime start,
    DateTime end,
    List<AppointmentEntry> existingAppts,
    List<ExternalCalendarEventEntry> externalEvents,
  ) {
    // Checa compromissos locais
    for (final a in existingAppts) {
      if (a.deletedAt != null || a.status == 'cancelado') continue;
      if (a.startTime.isBefore(end) && a.endTime.isAfter(start)) {
        return 'Conflito com compromisso local: "${a.title}"';
      }
    }

    // Checa eventos externos do Google / Apple Calendar
    for (final ext in externalEvents) {
      if (ext.deletedAt != null || ext.isDeletedExternal || ext.externalStatus == 'cancelled') continue;
      if (ext.startTime.isBefore(end) && ext.endTime.isAfter(start)) {
        return 'Conflito com calendário externo: "${ext.title}"';
      }
    }

    return null;
  }

  static bool _isSameNeighborhood(String? addr1, String? addr2) {
    if (addr1 == null || addr2 == null) return false;
    final a1 = addr1.toLowerCase().trim();
    final a2 = addr2.toLowerCase().trim();
    if (a1.isEmpty || a2.isEmpty) return false;
    if (a1 == a2) return true;

    final parts1 = a1.split(RegExp(r'[,-]')).map((p) => p.trim()).where((p) => p.length >= 3);
    for (final p in parts1) {
      if (a2.contains(p)) return true;
    }

    const stopWords = {
      'rua', 'avenida', 'av', 'travessa', 'trav', 'alameda', 'beco', 'bairro',
      'comunidade', 'ramal', 'rio', 'igarapé', 'igarape', 'sitio', 'sítio',
      'vila', 'estrada', 'km', 'nº', 'no', 'casa', 'ap', 'apto'
    };
    final tokens1 = a1
        .split(RegExp(r'[\s,.-]+'))
        .where((t) => t.length >= 3 && !stopWords.contains(t))
        .toSet();
    final tokens2 = a2
        .split(RegExp(r'[\s,.-]+'))
        .where((t) => t.length >= 3 && !stopWords.contains(t))
        .toSet();

    return tokens1.intersection(tokens2).isNotEmpty;
  }

  static double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371000.0;
    final dLat = (lat2 - lat1) * (math.pi / 180.0);
    final dLon = (lon2 - lon1) * (math.pi / 180.0);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180.0)) *
            math.cos(lat2 * (math.pi / 180.0)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }
}
