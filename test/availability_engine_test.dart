import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/appointments/availability_engine.dart';

void main() {
  group('Motor de Disponibilidade e Conflitos de Agenda', () {
    final now = DateTime(2026, 10, 26, 10, 0);

    test('TC-SCHED-01: Detecta sobreposição parcial (14h00-14h30 vs 14h20-14h50)', () {
      final existing = [
        AppointmentEntry(
          id: 'appt-1',
          title: 'Visita Carlos',
          startTime: DateTime(2026, 10, 26, 14, 0),
          endTime: DateTime(2026, 10, 26, 14, 30),
          durationMinutes: 30,
          status: 'planejado',
          isProvisional: false,
          createdAt: now,
          updatedAt: now,
          revision: 1,
        ),
      ];

      final result = AvailabilityEngine.checkAvailability(
        startTime: DateTime(2026, 10, 26, 14, 20),
        durationMinutes: 30,
        bufferMinutes: 0,
        existingAppointments: existing,
      );

      expect(result.isAvailable, isFalse);
      expect(result.conflictingAppointments.length, equals(1));
      expect(result.suggestedAlternativeSlots.isNotEmpty, isTrue);
    });

    test('TC-SCHED-02: Detecta compromisso totalmente contido em outro intervalo', () {
      final existing = [
        AppointmentEntry(
          id: 'appt-1',
          title: 'Estudo Longo',
          startTime: DateTime(2026, 10, 26, 14, 0),
          endTime: DateTime(2026, 10, 26, 15, 0),
          durationMinutes: 60,
          status: 'confirmado',
          isProvisional: false,
          createdAt: now,
          updatedAt: now,
          revision: 1,
        ),
      ];

      final result = AvailabilityEngine.checkAvailability(
        startTime: DateTime(2026, 10, 26, 14, 15),
        durationMinutes: 30,
        bufferMinutes: 0,
        existingAppointments: existing,
      );

      expect(result.isAvailable, isFalse);
      expect(result.conflictingAppointments.first.id, equals('appt-1'));
    });

    test('TC-SCHED-03: Permite horários rigorosamente consecutivos quando não houver buffer obrigatório', () {
      final existing = [
        AppointmentEntry(
          id: 'appt-1',
          title: 'Visita 1',
          startTime: DateTime(2026, 10, 26, 14, 0),
          endTime: DateTime(2026, 10, 26, 14, 30),
          durationMinutes: 30,
          status: 'confirmado',
          isProvisional: false,
          createdAt: now,
          updatedAt: now,
          revision: 1,
        ),
      ];

      // Começa exatamente quando o anterior termina (14h30)
      final result = AvailabilityEngine.checkAvailability(
        startTime: DateTime(2026, 10, 26, 14, 30),
        durationMinutes: 30,
        bufferMinutes: 0,
        existingAppointments: existing,
      );

      expect(result.isAvailable, isTrue);
      expect(result.conflictingAppointments, isEmpty);
    });

    test('TC-SCHED-04: Respeita intervalo/buffer de deslocamento configurado', () {
      final existing = [
        AppointmentEntry(
          id: 'appt-1',
          title: 'Visita 1',
          startTime: DateTime(2026, 10, 26, 14, 0),
          endTime: DateTime(2026, 10, 26, 14, 30),
          durationMinutes: 30,
          status: 'confirmado',
          isProvisional: false,
          createdAt: now,
          updatedAt: now,
          revision: 1,
        ),
      ];

      // Buffer de 15 minutos: compromisso das 14h00-14h30 requer janela livre até 14h45
      final resultWithConflict = AvailabilityEngine.checkAvailability(
        startTime: DateTime(2026, 10, 26, 14, 35),
        durationMinutes: 30,
        bufferMinutes: 15,
        existingAppointments: existing,
      );

      expect(resultWithConflict.isAvailable, isFalse);

      // Iniciando às 14h45 (após os 15 min de buffer), deve liberar
      final resultFree = AvailabilityEngine.checkAvailability(
        startTime: DateTime(2026, 10, 26, 14, 45),
        durationMinutes: 30,
        bufferMinutes: 15,
        existingAppointments: existing,
      );

      expect(resultFree.isAvailable, isTrue);
    });

    test('TC-SCHED-05: Ignora compromissos cancelados ou reagendados para fins de colisão', () {
      final existing = [
        AppointmentEntry(
          id: 'appt-cancelled',
          title: 'Visita Cancelada',
          startTime: DateTime(2026, 10, 26, 14, 0),
          endTime: DateTime(2026, 10, 26, 14, 30),
          durationMinutes: 30,
          status: 'cancelado',
          isProvisional: false,
          createdAt: now,
          updatedAt: now,
          revision: 1,
        ),
        AppointmentEntry(
          id: 'appt-rescheduled',
          title: 'Visita Reagendada Anteriormente',
          startTime: DateTime(2026, 10, 26, 14, 0),
          endTime: DateTime(2026, 10, 26, 14, 30),
          durationMinutes: 30,
          status: 'reagendado',
          isProvisional: false,
          createdAt: now,
          updatedAt: now,
          revision: 1,
        ),
      ];

      final result = AvailabilityEngine.checkAvailability(
        startTime: DateTime(2026, 10, 26, 14, 0),
        durationMinutes: 30,
        bufferMinutes: 0,
        existingAppointments: existing,
      );

      expect(result.isAvailable, isTrue);
    });
  });
}
