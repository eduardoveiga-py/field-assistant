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
  ///   Ex: [14:00, 14:30] e [14:30, 15:00] NÃO colidem.
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

    // Gerar horários alternativos sugeridos próximos
    final suggestions = <DateTime>[];

    // Alternativa 1: Logo após o último conflito do bloco
    conflicts.sort((a, b) => a.endTime.compareTo(b.endTime));
    final latestConflict = conflicts.last;
    final slotAfter = latestConflict.endTime.add(Duration(minutes: bufferMinutes));
    suggestions.add(slotAfter);

    // Alternativa 2: 30 minutos após o slot proposto
    final slotPlus30 = startTime.add(const Duration(minutes: 30));
    if (!suggestions.any((d) => d.isAtSameMomentAs(slotPlus30))) {
      suggestions.add(slotPlus30);
    }

    // Alternativa 3: Mesmo horário no dia seguinte
    final nextDay = startTime.add(const Duration(days: 1));
    suggestions.add(nextDay);

    return AvailabilityResult(
      isAvailable: false,
      conflictingAppointments: conflicts,
      suggestedAlternativeSlots: suggestions,
      message: 'Conflito detectado com ${conflicts.length} compromisso(s) existente(s).',
    );
  }
}
