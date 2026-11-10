import '../database/app_database.dart';

class AvailabilityResult {
  final bool isAvailable;
  final List<AppointmentEntry> conflictingAppointments;
  final List<ExternalCalendarEventEntry> conflictingExternalEvents;
  final List<DateTime> suggestedAlternativeSlots;
  final String message;

  AvailabilityResult({
    required this.isAvailable,
    this.conflictingAppointments = const [],
    this.conflictingExternalEvents = const [],
    this.suggestedAlternativeSlots = const [],
    required this.message,
  });
}

/// Representa um par de compromissos com sobreposição de horários detectada pós-sincronização
class AppointmentConflictPair {
  final AppointmentEntry appointmentA;
  final AppointmentEntry appointmentB;
  final DateTime collisionDate;

  const AppointmentConflictPair({
    required this.appointmentA,
    required this.appointmentB,
    required this.collisionDate,
  });

  String get conflictKey => appointmentA.id.compareTo(appointmentB.id) < 0
      ? '${appointmentA.id}_${appointmentB.id}'
      : '${appointmentB.id}_${appointmentA.id}';
}

class AvailabilityEngine {
  static const int defaultDayStartHour = 8;
  static const int defaultDayEndHour = 20;

  /// Verifica se um determinado intervalo colide com algum compromisso ativo ou evento externo
  static bool hasCollision({
    required DateTime start,
    required DateTime end,
    int bufferMinutes = 0,
    required List<AppointmentEntry> existingAppointments,
    List<ExternalCalendarEventEntry> externalEvents = const [],
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
      // 'realizado' não bloqueia horários futuros
      if (status == 'cancelado' ||
          status == 'nao_realizado' ||
          status == 'reagendado' ||
          status == 'realizado' ||
          status == 'concluido' ||
          status == 'concluído') {
        continue;
      }

      final apptStart = appt.startTime;
      final apptEnd = appt.endTime;

      final bool hasOverlap;
      if (bufferMinutes > 0) {
        hasOverlap =
            effectiveStart.isBefore(apptEnd) && effectiveEnd.isAfter(apptStart);
      } else {
        hasOverlap = start.isBefore(apptEnd) && end.isAfter(apptStart);
      }

      if (hasOverlap) return true;
    }

    // Verifica colisão com eventos de calendários externos (sem convertê-los em compromissos ministeriais)
    for (final ext in externalEvents) {
      if (ext.deletedAt != null || ext.isDeletedExternal) continue;
      if (ext.externalStatus == 'cancelled') continue;

      final extStart = ext.startTime;
      final extEnd = ext.endTime;

      final bool hasOverlap;
      if (bufferMinutes > 0) {
        hasOverlap =
            effectiveStart.isBefore(extEnd) && effectiveEnd.isAfter(extStart);
      } else {
        hasOverlap = start.isBefore(extEnd) && end.isAfter(extStart);
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
    List<ExternalCalendarEventEntry> externalEvents = const [],
    String? excludeAppointmentId,
    int dayStartHour = defaultDayStartHour,
    int dayEndHour = defaultDayEndHour,
  }) {
    final endTime = startTime.add(Duration(minutes: durationMinutes));
    final effectiveStart = startTime.subtract(Duration(minutes: bufferMinutes));
    final effectiveEnd = endTime.add(Duration(minutes: bufferMinutes));

    final conflicts = <AppointmentEntry>[];
    final extConflicts = <ExternalCalendarEventEntry>[];

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
          status == 'reagendado' ||
          status == 'realizado' ||
          status == 'concluido' ||
          status == 'concluído') {
        continue;
      }

      final apptStart = appt.startTime;
      final apptEnd = appt.endTime;

      final bool hasOverlap;
      if (bufferMinutes > 0) {
        hasOverlap =
            effectiveStart.isBefore(apptEnd) && effectiveEnd.isAfter(apptStart);
      } else {
        hasOverlap = startTime.isBefore(apptEnd) && endTime.isAfter(apptStart);
      }

      if (hasOverlap) {
        conflicts.add(appt);
      }
    }

    for (final ext in externalEvents) {
      if (ext.deletedAt != null || ext.isDeletedExternal) continue;
      if (ext.externalStatus == 'cancelled') continue;

      final extStart = ext.startTime;
      final extEnd = ext.endTime;

      final bool hasOverlap;
      if (bufferMinutes > 0) {
        hasOverlap =
            effectiveStart.isBefore(extEnd) && effectiveEnd.isAfter(extStart);
      } else {
        hasOverlap = startTime.isBefore(extEnd) && endTime.isAfter(extStart);
      }

      if (hasOverlap) {
        extConflicts.add(ext);
      }
    }

    if (conflicts.isEmpty && extConflicts.isEmpty) {
      return AvailabilityResult(
        isAvailable: true,
        message: 'Horário disponível.',
      );
    }

    // Gerar sugestões de horários alternativos garantindo disponibilidade e janela útil (08:00 às 20:00)
    final suggestions = <DateTime>[];

    // Candidato 1: Logo após o término do bloco de conflito + buffer
    final allEndTimes = [
      ...conflicts.map((c) => c.endTime),
      ...extConflicts.map((c) => c.endTime),
    ]..sort();

    DateTime candidateAfter = allEndTimes.last.add(
      Duration(minutes: bufferMinutes),
    );
    for (int i = 0; i < 5; i++) {
      candidateAfter = _adjustToWorkingHours(
        candidateAfter,
        durationMinutes,
        dayStartHour,
        dayEndHour,
      );
      final candEnd = candidateAfter.add(Duration(minutes: durationMinutes));
      if (!hasCollision(
        start: candidateAfter,
        end: candEnd,
        bufferMinutes: bufferMinutes,
        existingAppointments: existingAppointments,
        externalEvents: externalEvents,
        excludeAppointmentId: excludeAppointmentId,
      )) {
        suggestions.add(candidateAfter);
        break;
      }
      candidateAfter = candidateAfter.add(
        Duration(minutes: durationMinutes + bufferMinutes),
      );
    }

    // Candidato 2: 1 hora ou 2 horas após o horário proposto
    for (int offsetHours in [1, 2, 3]) {
      var cand = startTime.add(Duration(hours: offsetHours));
      cand = _adjustToWorkingHours(
        cand,
        durationMinutes,
        dayStartHour,
        dayEndHour,
      );
      final candEnd = cand.add(Duration(minutes: durationMinutes));
      if (!hasCollision(
        start: cand,
        end: candEnd,
        bufferMinutes: bufferMinutes,
        existingAppointments: existingAppointments,
        externalEvents: externalEvents,
        excludeAppointmentId: excludeAppointmentId,
      )) {
        if (!suggestions.any((s) => s.isAtSameMomentAs(cand))) {
          suggestions.add(cand);
          break;
        }
      }
    }

    // Candidato 3: Mesmo horário no dia seguinte
    for (int dayOffset in [1, 2, 3]) {
      var nextDay = startTime.add(Duration(days: dayOffset));
      nextDay = _adjustToWorkingHours(
        nextDay,
        durationMinutes,
        dayStartHour,
        dayEndHour,
      );
      final nextDayEnd = nextDay.add(Duration(minutes: durationMinutes));
      if (!hasCollision(
        start: nextDay,
        end: nextDayEnd,
        bufferMinutes: bufferMinutes,
        existingAppointments: existingAppointments,
        externalEvents: externalEvents,
        excludeAppointmentId: excludeAppointmentId,
      )) {
        if (!suggestions.any((s) => s.isAtSameMomentAs(nextDay))) {
          suggestions.add(nextDay);
          break;
        }
      }
    }

    final totalConflicts = conflicts.length + extConflicts.length;
    return AvailabilityResult(
      isAvailable: false,
      conflictingAppointments: conflicts,
      conflictingExternalEvents: extConflicts,
      suggestedAlternativeSlots: suggestions,
      message:
          'Conflito detectado com $totalConflicts compromisso(s) ou evento(s) externo(s).',
    );
  }

  static DateTime _adjustToWorkingHours(
    DateTime dt,
    int durationMinutes,
    int startHour,
    int endHour,
  ) {
    if (dt.hour < startHour) {
      return DateTime(dt.year, dt.month, dt.day, startHour, 0);
    }
    final endDt = dt.add(Duration(minutes: durationMinutes));
    if (endDt.hour > endHour || (endDt.hour == endHour && endDt.minute > 0)) {
      // Passa para o dia seguinte às startHour
      final next = dt.add(const Duration(days: 1));
      return DateTime(next.year, next.month, next.day, startHour, 0);
    }
    return dt;
  }

  /// Detecta pares de compromissos ativos que colidem entre si no mesmo dia
  static List<AppointmentConflictPair> findActiveConflicts(
    List<AppointmentEntry> appointments, {
    int bufferMinutes = 0,
  }) {
    final active = appointments.where((a) {
      if (a.deletedAt != null) return false;
      final st = a.status.toLowerCase();
      return st != 'cancelado' &&
          st != 'nao_realizado' &&
          st != 'reagendado' &&
          st != 'realizado' &&
          st != 'concluido' &&
          st != 'concluído';
    }).toList();

    final pairs = <AppointmentConflictPair>[];
    final seen = <String>{};

    for (int i = 0; i < active.length; i++) {
      for (int j = i + 1; j < active.length; j++) {
        final a = active[i];
        final b = active[j];

        // Se são em dias diferentes, não colidem
        if (a.startTime.year != b.startTime.year ||
            a.startTime.month != b.startTime.month ||
            a.startTime.day != b.startTime.day) {
          continue;
        }

        final effectiveStartA =
            a.startTime.subtract(Duration(minutes: bufferMinutes));
        final effectiveEndA = a.endTime.add(Duration(minutes: bufferMinutes));

        final hasOverlap = effectiveStartA.isBefore(b.endTime) &&
            effectiveEndA.isAfter(b.startTime);
        if (hasOverlap) {
          final pair = AppointmentConflictPair(
            appointmentA: a,
            appointmentB: b,
            collisionDate: a.startTime,
          );
          if (!seen.contains(pair.conflictKey)) {
            seen.add(pair.conflictKey);
            pairs.add(pair);
          }
        }
      }
    }

    return pairs;
  }
}
