import 'dart:convert';

import 'package:drift/drift.dart' as drift;

import '../database/app_database.dart';

/// Representa um conflito de domínio na Agenda detectado após pull:
/// dois compromissos ativos com UUIDs distintos sobrepostos no tempo.
class AppointmentDomainConflict {
  final String incomingAppointmentId;
  final String incomingTitle;
  final String conflictingAppointmentId;
  final String conflictingTitle;
  final DateTime overlapStart;
  final DateTime overlapEnd;
  final DateTime detectedAt;

  const AppointmentDomainConflict({
    required this.incomingAppointmentId,
    required this.incomingTitle,
    required this.conflictingAppointmentId,
    required this.conflictingTitle,
    required this.overlapStart,
    required this.overlapEnd,
    required this.detectedAt,
  });

  Map<String, dynamic> toJson() => {
    'incomingAppointmentId': incomingAppointmentId,
    'incomingTitle': incomingTitle,
    'conflictingAppointmentId': conflictingAppointmentId,
    'conflictingTitle': conflictingTitle,
    'overlapStart': overlapStart.toUtc().toIso8601String(),
    'overlapEnd': overlapEnd.toUtc().toIso8601String(),
    'detectedAt': detectedAt.toUtc().toIso8601String(),
  };

  factory AppointmentDomainConflict.fromJson(Map<String, dynamic> json) {
    return AppointmentDomainConflict(
      incomingAppointmentId: json['incomingAppointmentId'] as String,
      incomingTitle: json['incomingTitle'] as String? ?? '',
      conflictingAppointmentId: json['conflictingAppointmentId'] as String,
      conflictingTitle: json['conflictingTitle'] as String? ?? '',
      overlapStart: DateTime.parse(json['overlapStart'] as String).toUtc(),
      overlapEnd: DateTime.parse(json['overlapEnd'] as String).toUtc(),
      detectedAt: DateTime.parse(json['detectedAt'] as String).toUtc(),
    );
  }
}

/// Detector de conflitos de domínio na Agenda após sincronização (FA-SYNC-02).
/// Garante que dois compromissos ativos com UUIDs distintos e intervalos
/// sobrepostos jamais se sobrescrevam silenciosamente: ambos são preservados,
/// o registro sincronizado é marcado com `status = 'conflito'` e o conflito é
/// auditavelmente registrado em `app_kv_store`.
class AppointmentDomainConflictDetector {
  AppointmentDomainConflictDetector._();

  static const String kvKeyPrefix = 'domain_conflict_appointment_';

  static const Set<String> inactiveStatuses = {
    'cancelado',
    'nao_realizado',
    'reagendado',
  };

  /// Retorna `true` quando os intervalos `[aStart, aEnd)` e `[bStart, bEnd)` se
  /// sobrepõem estritamente. Intervalos apenas adjacentes (`aEnd == bStart`) não conflitam.
  static bool intervalsOverlap(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) {
    final aS = aStart.toUtc();
    final aE = aEnd.toUtc();
    final bS = bStart.toUtc();
    final bE = bEnd.toUtc();
    return aS.isBefore(bE) && bS.isBefore(aE);
  }

  /// Verifica se o compromisso recém-aplicado [appointmentId] sobrepõe algum outro
  /// compromisso local ativo com UUID distinto. Se houver sobreposição, sinaliza
  /// `status = 'conflito'` no compromisso recebido sem apagar nem sobrescrever o
  /// compromisso local preexistente, e persiste o detalhe do conflito em `app_kv_store`.
  static Future<List<AppointmentDomainConflict>> detectAndRecordOverlaps(
    AppDatabase db, {
    required String appointmentId,
    DateTime? now,
  }) async {
    final incoming = await (db.select(
      db.appointments,
    )..where((t) => t.id.equals(appointmentId))).getSingleOrNull();
    if (incoming == null || incoming.deletedAt != null) {
      return const [];
    }
    if (inactiveStatuses.contains(incoming.status.trim().toLowerCase())) {
      return const [];
    }

    final others =
        await (db.select(db.appointments)..where(
              (t) => t.deletedAt.isNull() & t.id.isNotValue(appointmentId),
            ))
            .get();

    final detectedAt = (now ?? DateTime.now()).toUtc();
    final conflicts = <AppointmentDomainConflict>[];

    for (final other in others) {
      if (inactiveStatuses.contains(other.status.trim().toLowerCase())) {
        continue;
      }
      if (intervalsOverlap(
        incoming.startTime,
        incoming.endTime,
        other.startTime,
        other.endTime,
      )) {
        final overlapStart =
            incoming.startTime.toUtc().isAfter(other.startTime.toUtc())
            ? incoming.startTime.toUtc()
            : other.startTime.toUtc();
        final overlapEnd =
            incoming.endTime.toUtc().isBefore(other.endTime.toUtc())
            ? incoming.endTime.toUtc()
            : other.endTime.toUtc();

        conflicts.add(
          AppointmentDomainConflict(
            incomingAppointmentId: incoming.id,
            incomingTitle: incoming.title,
            conflictingAppointmentId: other.id,
            conflictingTitle: other.title,
            overlapStart: overlapStart,
            overlapEnd: overlapEnd,
            detectedAt: detectedAt,
          ),
        );
      }
    }

    if (conflicts.isEmpty) {
      return const [];
    }

    await (db.update(db.appointments)..where((t) => t.id.equals(appointmentId)))
        .write(const AppointmentsCompanion(status: drift.Value('conflito')));

    await db
        .into(db.appKvStore)
        .insertOnConflictUpdate(
          AppKvStoreCompanion.insert(
            key: '$kvKeyPrefix$appointmentId',
            value: jsonEncode({
              'appointmentId': appointmentId,
              'detectedAt': detectedAt.toIso8601String(),
              'conflicts': conflicts.map((c) => c.toJson()).toList(),
            }),
            updatedAt: drift.Value(detectedAt),
          ),
        );

    return conflicts;
  }

  /// Lista todos os conflitos de domínio de agenda ativos registrados localmente.
  static Future<List<AppointmentDomainConflict>> getActiveConflicts(
    AppDatabase db,
  ) async {
    final rows = await (db.select(
      db.appKvStore,
    )..where((t) => t.key.like('$kvKeyPrefix%'))).get();

    final result = <AppointmentDomainConflict>[];
    for (final row in rows) {
      try {
        final decoded = jsonDecode(row.value) as Map<String, dynamic>;
        final list = (decoded['conflicts'] as List<dynamic>? ?? const []);
        for (final item in list) {
          if (item is Map) {
            result.add(
              AppointmentDomainConflict.fromJson(
                Map<String, dynamic>.from(item),
              ),
            );
          }
        }
      } catch (_) {}
    }
    return result;
  }

  /// Remove o registro de conflito de domínio após resolução consciente pelo usuário.
  static Future<void> clearConflict(
    AppDatabase db,
    String appointmentId,
  ) async {
    await (db.delete(
      db.appKvStore,
    )..where((t) => t.key.equals('$kvKeyPrefix$appointmentId'))).go();
  }
}

/// Representa um conflito de domínio em Estudos Bíblicos detectado após pull:
/// mesmo estudante primário alocado a dois estudos ativos ou sobreposição de sessão agendada.
class BibleStudyDomainConflict {
  final String incomingStudyId;
  final String incomingTitle;
  final String conflictingStudyId;
  final String conflictingTitle;
  final String reason;
  final String? studentPersonId;
  final DateTime detectedAt;

  const BibleStudyDomainConflict({
    required this.incomingStudyId,
    required this.incomingTitle,
    required this.conflictingStudyId,
    required this.conflictingTitle,
    required this.reason,
    this.studentPersonId,
    required this.detectedAt,
  });

  Map<String, dynamic> toJson() => {
    'incomingStudyId': incomingStudyId,
    'incomingTitle': incomingTitle,
    'conflictingStudyId': conflictingStudyId,
    'conflictingTitle': conflictingTitle,
    'reason': reason,
    'studentPersonId': studentPersonId,
    'detectedAt': detectedAt.toUtc().toIso8601String(),
  };

  factory BibleStudyDomainConflict.fromJson(Map<String, dynamic> json) {
    return BibleStudyDomainConflict(
      incomingStudyId: json['incomingStudyId'] as String,
      incomingTitle: json['incomingTitle'] as String? ?? '',
      conflictingStudyId: json['conflictingStudyId'] as String,
      conflictingTitle: json['conflictingTitle'] as String? ?? '',
      reason: json['reason'] as String? ?? 'duplicate_primary_student',
      studentPersonId: json['studentPersonId'] as String?,
      detectedAt: DateTime.parse(json['detectedAt'] as String).toUtc(),
    );
  }
}

/// Detector de conflitos de domínio em Estudos Bíblicos após sincronização (FA-SYNC-02 / P1-03).
class BibleStudyDomainConflictDetector {
  BibleStudyDomainConflictDetector._();

  static const String kvKeyPrefix = 'domain_conflict_biblestudy_';

  static const Set<String> inactiveStatuses = {'concluido', 'encerrado'};

  static Future<List<BibleStudyDomainConflict>> detectAndRecordConflicts(
    AppDatabase db, {
    required String studyId,
    DateTime? now,
  }) async {
    final incoming = await (db.select(
      db.bibleStudies,
    )..where((t) => t.id.equals(studyId))).getSingleOrNull();
    if (incoming == null || incoming.deletedAt != null) {
      return const [];
    }
    if (inactiveStatuses.contains(incoming.status.trim().toLowerCase())) {
      return const [];
    }

    final detectedAt = (now ?? DateTime.now()).toUtc();
    final conflicts = <BibleStudyDomainConflict>[];

    // 1. Obtém participantes do estudo recebido
    final incomingParticipants = await (db.select(
      db.studyParticipants,
    )..where((t) => t.studyId.equals(studyId) & t.deletedAt.isNull())).get();

    final primaryParticipant =
        incomingParticipants.where((p) => p.isPrimary).firstOrNull ??
        incomingParticipants.firstOrNull;

    if (primaryParticipant != null) {
      final otherParticipations =
          await (db.select(db.studyParticipants)..where(
                (t) =>
                    t.personId.equals(primaryParticipant.personId) &
                    t.studyId.isNotValue(studyId) &
                    t.deletedAt.isNull() &
                    t.isPrimary.equals(true),
              ))
              .get();

      for (final otherPart in otherParticipations) {
        final otherStudy =
            await (db.select(db.bibleStudies)..where(
                  (t) => t.id.equals(otherPart.studyId) & t.deletedAt.isNull(),
                ))
                .getSingleOrNull();

        if (otherStudy != null &&
            !inactiveStatuses.contains(
              otherStudy.status.trim().toLowerCase(),
            )) {
          conflicts.add(
            BibleStudyDomainConflict(
              incomingStudyId: incoming.id,
              incomingTitle: incoming.title,
              conflictingStudyId: otherStudy.id,
              conflictingTitle: otherStudy.title,
              reason: 'duplicate_primary_student',
              studentPersonId: primaryParticipant.personId,
              detectedAt: detectedAt,
            ),
          );
        }
      }
    }

    // 2. Se houver sobreposição em nextPlannedAt com outro estudo ativo
    if (incoming.nextPlannedAt != null) {
      final othersWithSameNextDate =
          await (db.select(db.bibleStudies)..where(
                (t) =>
                    t.id.isNotValue(studyId) &
                    t.deletedAt.isNull() &
                    t.nextPlannedAt.equals(incoming.nextPlannedAt!),
              ))
              .get();

      for (final other in othersWithSameNextDate) {
        if (inactiveStatuses.contains(other.status.trim().toLowerCase())) {
          continue;
        }
        if (!conflicts.any((c) => c.conflictingStudyId == other.id)) {
          conflicts.add(
            BibleStudyDomainConflict(
              incomingStudyId: incoming.id,
              incomingTitle: incoming.title,
              conflictingStudyId: other.id,
              conflictingTitle: other.title,
              reason: 'overlapping_planned_session',
              studentPersonId: primaryParticipant?.personId,
              detectedAt: detectedAt,
            ),
          );
        }
      }
    }

    if (conflicts.isEmpty) {
      return const [];
    }

    await (db.update(db.bibleStudies)..where((t) => t.id.equals(studyId)))
        .write(const BibleStudiesCompanion(status: drift.Value('conflito')));

    await db
        .into(db.appKvStore)
        .insertOnConflictUpdate(
          AppKvStoreCompanion.insert(
            key: '$kvKeyPrefix$studyId',
            value: jsonEncode({
              'studyId': studyId,
              'detectedAt': detectedAt.toIso8601String(),
              'conflicts': conflicts.map((c) => c.toJson()).toList(),
            }),
            updatedAt: drift.Value(detectedAt),
          ),
        );

    return conflicts;
  }

  static Future<List<BibleStudyDomainConflict>> getActiveConflicts(
    AppDatabase db,
  ) async {
    final rows = await (db.select(
      db.appKvStore,
    )..where((t) => t.key.like('$kvKeyPrefix%'))).get();

    final result = <BibleStudyDomainConflict>[];
    for (final row in rows) {
      try {
        final decoded = jsonDecode(row.value) as Map<String, dynamic>;
        final list = (decoded['conflicts'] as List<dynamic>? ?? const []);
        for (final item in list) {
          if (item is Map) {
            result.add(
              BibleStudyDomainConflict.fromJson(
                Map<String, dynamic>.from(item),
              ),
            );
          }
        }
      } catch (_) {}
    }
    return result;
  }

  static Future<void> clearConflict(AppDatabase db, String studyId) async {
    await (db.delete(
      db.appKvStore,
    )..where((t) => t.key.equals('$kvKeyPrefix$studyId'))).go();
  }
}

/// Representa um conflito de domínio em Tarefas detectado após pull.
class TaskDomainConflict {
  final String incomingTaskId;
  final String incomingTitle;
  final String conflictingTaskId;
  final String conflictingTitle;
  final String reason;
  final DateTime detectedAt;

  const TaskDomainConflict({
    required this.incomingTaskId,
    required this.incomingTitle,
    required this.conflictingTaskId,
    required this.conflictingTitle,
    required this.reason,
    required this.detectedAt,
  });

  Map<String, dynamic> toJson() => {
    'incomingTaskId': incomingTaskId,
    'incomingTitle': incomingTitle,
    'conflictingTaskId': conflictingTaskId,
    'conflictingTitle': conflictingTitle,
    'reason': reason,
    'detectedAt': detectedAt.toUtc().toIso8601String(),
  };

  factory TaskDomainConflict.fromJson(Map<String, dynamic> json) {
    return TaskDomainConflict(
      incomingTaskId: json['incomingTaskId'] as String,
      incomingTitle: json['incomingTitle'] as String? ?? '',
      conflictingTaskId: json['conflictingTaskId'] as String,
      conflictingTitle: json['conflictingTitle'] as String? ?? '',
      reason: json['reason'] as String? ?? 'duplicate_active_task',
      detectedAt: DateTime.parse(json['detectedAt'] as String).toUtc(),
    );
  }
}

/// Detector de conflitos de domínio em Tarefas após sincronização (FA-SYNC-02 / P1-03).
class TaskDomainConflictDetector {
  TaskDomainConflictDetector._();

  static const String kvKeyPrefix = 'domain_conflict_task_';

  static const Set<String> inactiveStatuses = {
    'completed',
    'cancelled',
    'archived',
  };

  static Future<List<TaskDomainConflict>> detectAndRecordConflicts(
    AppDatabase db, {
    required String taskId,
    DateTime? now,
  }) async {
    final incoming = await (db.select(
      db.tasks,
    )..where((t) => t.id.equals(taskId))).getSingleOrNull();
    if (incoming == null || incoming.deletedAt != null) {
      return const [];
    }
    if (inactiveStatuses.contains(incoming.status.trim().toLowerCase())) {
      return const [];
    }

    final detectedAt = (now ?? DateTime.now()).toUtc();
    final conflicts = <TaskDomainConflict>[];

    final others =
        await (db.select(db.tasks)..where(
              (t) =>
                  t.id.isNotValue(taskId) &
                  t.deletedAt.isNull() &
                  t.title.equals(incoming.title),
            ))
            .get();

    for (final other in others) {
      if (inactiveStatuses.contains(other.status.trim().toLowerCase())) {
        continue;
      }

      final samePerson =
          incoming.personId != null &&
          other.personId != null &&
          incoming.personId == other.personId;
      final sameProject =
          incoming.projectId != null &&
          other.projectId != null &&
          incoming.projectId == other.projectId;
      final bothStandAlone =
          incoming.personId == null &&
          incoming.projectId == null &&
          other.personId == null &&
          other.projectId == null;

      if (samePerson || sameProject || bothStandAlone) {
        conflicts.add(
          TaskDomainConflict(
            incomingTaskId: incoming.id,
            incomingTitle: incoming.title,
            conflictingTaskId: other.id,
            conflictingTitle: other.title,
            reason: 'duplicate_active_task',
            detectedAt: detectedAt,
          ),
        );
      }
    }

    if (conflicts.isEmpty) {
      return const [];
    }

    await (db.update(db.tasks)..where((t) => t.id.equals(taskId))).write(
      const TasksCompanion(status: drift.Value('conflito')),
    );

    await db
        .into(db.appKvStore)
        .insertOnConflictUpdate(
          AppKvStoreCompanion.insert(
            key: '$kvKeyPrefix$taskId',
            value: jsonEncode({
              'taskId': taskId,
              'detectedAt': detectedAt.toIso8601String(),
              'conflicts': conflicts.map((c) => c.toJson()).toList(),
            }),
            updatedAt: drift.Value(detectedAt),
          ),
        );

    return conflicts;
  }

  static Future<List<TaskDomainConflict>> getActiveConflicts(
    AppDatabase db,
  ) async {
    final rows = await (db.select(
      db.appKvStore,
    )..where((t) => t.key.like('$kvKeyPrefix%'))).get();

    final result = <TaskDomainConflict>[];
    for (final row in rows) {
      try {
        final decoded = jsonDecode(row.value) as Map<String, dynamic>;
        final list = (decoded['conflicts'] as List<dynamic>? ?? const []);
        for (final item in list) {
          if (item is Map) {
            result.add(
              TaskDomainConflict.fromJson(Map<String, dynamic>.from(item)),
            );
          }
        }
      } catch (_) {}
    }
    return result;
  }

  static Future<void> clearConflict(AppDatabase db, String taskId) async {
    await (db.delete(
      db.appKvStore,
    )..where((t) => t.key.equals('$kvKeyPrefix$taskId'))).go();
  }
}
