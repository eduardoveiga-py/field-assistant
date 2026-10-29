import '../database/app_database.dart';

class AvailabilityResult {
  final bool isAvailable;
  final List<AppointmentEntry> conflictingAppointments;
  final List<DateTime> suggestedAlternativeSlots;
  final String message;

  AvailabilityResult({
    required this.isAvailable,
    this.conflictingAppointments = const [],
    this.suggestedAlternativeSlots = const [],
    required this.message,
  });
}

class AvailabilityEngine {
  /// Verifica se o intervalo [startTime, startTime + durationMinutes] colide com compromissos existentes.
  ///
  /// Regras formais:
  /// - Status ativos considerados para conflito: 'planejado', 'confirmado', 'provisorio'.
  /// - Status ignorados: 'cancelado', 'nao_realizado', 'reagendado', 'realizado'.
  /// - Sobreposição parcial e total constituem conflito.
  /// - Compromissos estritamente consecutivos são permitidos quando bufferMinutes == 0.
  /// Verifica se um determinado intervalo colide com algum compromisso ativo existente.
  static bool hasCollision({
    required DateTime start,
    required DateTime end,
    int bufferMinutes = 0,
    required List<AppointmentEntry> existingAppointments,
    String? excludeAppointmentId,
  }) {
    final effectiveStart = start.subtract(Duration(minutes: bufferMinutes));
    final effectiveEnd = end.add(Duration(minutes: bufferMinutes));

    for (final appt in existingAppointments) {
      if (excludeAppointmentId != null && appt.id == excludeAppointmentId) {
        continue;
      }
      if (appt.deletedAt != null) {
        continue;
      }

      final status = appt.status.toLowerCase();
      if (status == 'cancelado' ||
          status == 'nao_realizado' ||
          status == 'reagendado') {
        continue;
      }

      final apptStart = appt.startTime;
      final apptEnd = appt.endTime;

      final bool hasOverlap;
      if (bufferMinutes > 0) {
        hasOverlap = effectiveStart.isBefore(apptEnd) && effectiveEnd.isAfter(apptStart);
      } else {
        hasOverlap = start.isBefore(apptEnd) && end.isAfter(apptStart);
      }

      if (hasOverlap) return true;
    }
    return false;
  }

  static AvailabilityResult checkAvailability({
    required DateTime startTime,
    required int durationMinutes,
    int bufferMinutes = 0,
    required List<AppointmentEntry> existingAppointments,
    String? excludeAppointmentId,
  }) {
    final endTime = startTime.add(Duration(minutes: durationMinutes));
    final effectiveStart = startTime.subtract(Duration(minutes: bufferMinutes));
    final effectiveEnd = endTime.add(Duration(minutes: bufferMinutes));

    final conflicts = <AppointmentEntry>[];

    for (final appt in existingAppointments) {
      if (excludeAppointmentId != null && appt.id == excludeAppointmentId) {
        continue;
      }
      // Ignora registros excluídos logicamente
      if (appt.deletedAt != null) {
        continue;
      }

      // Filtra estados que não ocupam mais o horário na prática
      final status = appt.status.toLowerCase();
      if (status == 'cancelado' ||
          status == 'nao_realizado' ||
          status == 'reagendado') {
        continue;
      }

      // Intervalo do compromisso existente
      final apptStart = appt.startTime;
      final apptEnd = appt.endTime;

      // Condição rigorosa de sobreposição:
      // Dois intervalos [A, B) e [C, D) sobrepõem-se se e somente se: A < D && B > C
      // Com buffer: se buffer > 0, o intervalo é expandido
      final bool hasOverlap;
      if (bufferMinutes > 0) {
        hasOverlap = effectiveStart.isBefore(apptEnd) && effectiveEnd.isAfter(apptStart);
      } else {
        // Estritamente consecutivos permitidos: startTime < apptEnd && endTime > apptStart
        hasOverlap = startTime.isBefore(apptEnd) && endTime.isAfter(apptStart);
      }

      if (hasOverlap) {
        conflicts.add(appt);
      }
    }

    if (conflicts.isEmpty) {
      return AvailabilityResult(
        isAvailable: true,
        message: 'Horário disponível.',
      );
    }

    // Gerar horários alternativos sugeridos próximos, com garantia de disponibilidade real
    final suggestions = <DateTime>[];

    // Candidato 1: Logo após o término do bloco de conflito + buffer, avançando se houver colisão
    conflicts.sort((a, b) => a.endTime.compareTo(b.endTime));
    DateTime candidateAfter = conflicts.last.endTime.add(Duration(minutes: bufferMinutes));
    for (int i = 0; i < 5; i++) {
      final candEnd = candidateAfter.add(Duration(minutes: durationMinutes));
      if (!hasCollision(
        start: candidateAfter,
        end: candEnd,
        bufferMinutes: bufferMinutes,
        existingAppointments: existingAppointments,
        excludeAppointmentId: excludeAppointmentId,
      )) {
        suggestions.add(candidateAfter);
        break;
      }
      candidateAfter = candidateAfter.add(Duration(minutes: durationMinutes + bufferMinutes));
    }

    // Candidato 2: 1 hora ou 2 horas após o horário proposto
    for (int offsetHours in [1, 2, 3]) {
      final cand = startTime.add(Duration(hours: offsetHours));
      final candEnd = cand.add(Duration(minutes: durationMinutes));
      if (!hasCollision(
        start: cand,
        end: candEnd,
        bufferMinutes: bufferMinutes,
        existingAppointments: existingAppointments,
        excludeAppointmentId: excludeAppointmentId,
      )) {
        if (!suggestions.any((s) => s.isAtSameMomentAs(cand))) {
          suggestions.add(cand);
          break;
        }
      }
    }

    // Candidato 3: Mesmo horário no dia seguinte (ou dias subsequentes até achar livre)
    for (int dayOffset in [1, 2, 3]) {
      final nextDay = startTime.add(Duration(days: dayOffset));
      final nextDayEnd = nextDay.add(Duration(minutes: durationMinutes));
      if (!hasCollision(
        start: nextDay,
        end: nextDayEnd,
        bufferMinutes: bufferMinutes,
        existingAppointments: existingAppointments,
        excludeAppointmentId: excludeAppointmentId,
      )) {
        if (!suggestions.any((s) => s.isAtSameMomentAs(nextDay))) {
          suggestions.add(nextDay);
          break;
        }
      }
    }

    return AvailabilityResult(
      isAvailable: false,
      conflictingAppointments: conflicts,
      suggestedAlternativeSlots: suggestions,
      message: 'Conflito detectado com ${conflicts.length} compromisso(s) existente(s).',
    );
  }
}
