import 'package:drift/drift.dart';

import '../app_database.dart';
import 'base_repository.dart';

/// Domínio responsável por compromissos, agendamentos e vínculos de calendário externo.
mixin AppointmentsDomainMixin on BaseRepository {
  Stream<List<AppointmentEntry>> watchAppointments() {
    return (db.select(db.appointments)
          ..where((tbl) => tbl.deletedAt.isNull())
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.startTime, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  Future<List<AppointmentEntry>> getAllAppointments() {
    return (db.select(db.appointments)
          ..where((tbl) => tbl.deletedAt.isNull())
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.startTime, mode: OrderingMode.asc),
          ]))
        .get();
  }

  Future<AppointmentEntry?> getAppointmentById(String id) {
    return (db.select(
      db.appointments,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<AppointmentEntry> createAppointment({
    String? id,
    String? personId,
    String? studyId,
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    int durationMinutes = 30,
    String status = 'planejado',
    String? previousAppointmentId,
    String? locationNotes,
    int? reminderMinutesBefore = 60,
    int? secondReminderMinutesBefore,
    bool isProvisional = false,
  }) async {
    final apptId = id ?? uuid.v4();
    final now = DateTime.now();

    final entry = AppointmentEntry(
      id: apptId,
      personId: personId,
      studyId: studyId,
      title: title,
      startTime: startTime,
      endTime: endTime,
      durationMinutes: durationMinutes,
      status: status,
      previousAppointmentId: previousAppointmentId,
      locationNotes: locationNotes,
      reminderMinutesBefore: reminderMinutesBefore,
      secondReminderMinutesBefore: secondReminderMinutesBefore,
      isProvisional: isProvisional,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      revision: 1,
    );

    await db.transaction(() async {
      await db.into(db.appointments).insert(entry);
      await recordSyncOperation(
        entityType: 'appointments',
        entityId: apptId,
        operation: 'INSERT',
        payload: {
          'id': entry.id,
          'personId': entry.personId,
          'studyId': entry.studyId,
          'title': entry.title,
          'startTime': entry.startTime.toIso8601String(),
          'endTime': entry.endTime.toIso8601String(),
          'durationMinutes': entry.durationMinutes,
          'status': entry.status,
          'isProvisional': entry.isProvisional,
          'revision': entry.revision,
        },
      );
    });

    return entry;
  }

  Future<void> updateAppointment(AppointmentEntry appointment) async {
    final existing = await (db.select(
      db.appointments,
    )..where((tbl) => tbl.id.equals(appointment.id))).getSingleOrNull();
    final now = DateTime.now();
    final updated = appointment.copyWith(
      updatedAt: now,
      revision: appointment.revision + 1,
    );

    await db.transaction(() async {
      await db.update(db.appointments).replace(updated);

      // Atualiza Outbox: marca vínculos existentes como pendentes de envio aos calendários externos
      await (db.update(db.calendarEventLinks)..where(
            (tbl) =>
                tbl.appointmentId.equals(updated.id) & tbl.deletedAt.isNull(),
          ))
          .write(
            CalendarEventLinksCompanion(
              syncStatus: const Value('pending_upload'),
              updatedAt: Value(now),
            ),
          );

      await recordSyncOperation(
        entityType: 'appointments',
        entityId: updated.id,
        operation: 'UPDATE',
        payload: {
          'id': updated.id,
          'title': updated.title,
          'startTime': updated.startTime.toIso8601String(),
          'endTime': updated.endTime.toIso8601String(),
          'status': updated.status,
          'revision': updated.revision,
        },
        baseData: existing?.toJson(),
      );
    });
  }

  /// Reagenda um compromisso preservando o histórico do anterior e associando o novo (Seção 5.4)
  Future<AppointmentEntry> rescheduleAppointment({
    required AppointmentEntry oldAppointment,
    required DateTime newStartTime,
    required DateTime newEndTime,
    int? durationMinutes,
    String? locationNotes,
  }) async {
    final now = DateTime.now();
    final newId = uuid.v4();
    final dur = durationMinutes ?? oldAppointment.durationMinutes;

    final updatedOld = oldAppointment.copyWith(
      status: 'reagendado',
      updatedAt: now,
      revision: oldAppointment.revision + 1,
    );

    final newAppt = AppointmentEntry(
      id: newId,
      personId: oldAppointment.personId,
      studyId: oldAppointment.studyId,
      title: oldAppointment.title,
      startTime: newStartTime,
      endTime: newEndTime,
      durationMinutes: dur,
      status: 'confirmado',
      previousAppointmentId: oldAppointment.id,
      locationNotes: locationNotes ?? oldAppointment.locationNotes,
      reminderMinutesBefore: oldAppointment.reminderMinutesBefore,
      secondReminderMinutesBefore: oldAppointment.secondReminderMinutesBefore,
      isProvisional: false,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      revision: 1,
    );

    await db.transaction(() async {
      await db.update(db.appointments).replace(updatedOld);
      await db.into(db.appointments).insert(newAppt);

      // Marca vínculos do compromisso antigo para atualização externa
      await (db.update(db.calendarEventLinks)..where(
            (tbl) =>
                tbl.appointmentId.equals(oldAppointment.id) &
                tbl.deletedAt.isNull(),
          ))
          .write(
            CalendarEventLinksCompanion(
              syncStatus: const Value('pending_upload'),
              updatedAt: Value(now),
            ),
          );

      await recordSyncOperation(
        entityType: 'appointments',
        entityId: oldAppointment.id,
        operation: 'UPDATE',
        payload: {
          'id': oldAppointment.id,
          'status': 'reagendado',
          'revision': updatedOld.revision,
        },
      );

      await recordSyncOperation(
        entityType: 'appointments',
        entityId: newId,
        operation: 'INSERT',
        payload: {
          'id': newAppt.id,
          'personId': newAppt.personId,
          'title': newAppt.title,
          'startTime': newAppt.startTime.toIso8601String(),
          'endTime': newAppt.endTime.toIso8601String(),
          'previousAppointmentId': oldAppointment.id,
          'status': 'confirmado',
          'revision': newAppt.revision,
        },
      );
    });

    return newAppt;
  }

  Future<void> deleteAppointment(String id) async {
    final appt = await (db.select(
      db.appointments,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (appt == null) return;
    final now = DateTime.now();
    final updated = appt.copyWith(
      deletedAt: Value(now),
      updatedAt: now,
      revision: appt.revision + 1,
    );
    await db.transaction(() async {
      await db.update(db.appointments).replace(updated);

      // Marca vínculos externos com pending_upload e soft delete para propagação da remoção
      await (db.update(db.calendarEventLinks)..where(
            (tbl) => tbl.appointmentId.equals(id) & tbl.deletedAt.isNull(),
          ))
          .write(
            CalendarEventLinksCompanion(
              syncStatus: const Value('pending_upload'),
              deletedAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      await recordSyncOperation(
        entityType: 'appointments',
        entityId: id,
        operation: 'DELETE',
        payload: {
          'id': id,
          'deletedAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
          'revision': updated.revision,
        },
      );
    });
  }
}
