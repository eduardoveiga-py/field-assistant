import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_logger.dart';
import '../database/app_database.dart';
import '../database/repository.dart';
import '../notifications/local_reminder_service.dart';
import '../ui/providers.dart';
import 'calendar_sync_coordinator.dart';

/// Resumo completo de relacionamentos de uma Pessoa para a confirmação de exclusão
class PersonRelationshipsSummary {
  final String personId;
  final String personName;
  final int visitsCount;
  final List<BibleStudyEntry> exclusiveStudies;
  final List<BibleStudyEntry> sharedStudies;
  final Map<String, List<String>> sharedStudyOtherParticipants;
  final List<AppointmentEntry> futureAppointments;
  final int pastAppointmentsCount;
  final String? linkedPhoneContactName;
  final String? linkedPhoneContactPhone;
  final int photosCount;
  final int publicationsCount;
  final int familyTiesCount;
  final int voiceNotesCount;
  final int tasksCount;
  final int knowledgeNotesCount;

  const PersonRelationshipsSummary({
    required this.personId,
    required this.personName,
    required this.visitsCount,
    required this.exclusiveStudies,
    required this.sharedStudies,
    required this.sharedStudyOtherParticipants,
    required this.futureAppointments,
    required this.pastAppointmentsCount,
    this.linkedPhoneContactName,
    this.linkedPhoneContactPhone,
    required this.photosCount,
    required this.publicationsCount,
    required this.familyTiesCount,
    required this.voiceNotesCount,
    required this.tasksCount,
    required this.knowledgeNotesCount,
  });

  bool get hasExclusiveStudies => exclusiveStudies.isNotEmpty;
  bool get hasSharedStudies => sharedStudies.isNotEmpty;
  bool get hasFutureAppointments => futureAppointments.isNotEmpty;
  bool get hasLinkedPhoneContact => linkedPhoneContactName != null;
}

/// Intervalo de data/hora liberado na agenda
class FreedTimeSlot {
  final String appointmentId;
  final String title;
  final DateTime startTime;
  final DateTime endTime;

  const FreedTimeSlot({
    required this.appointmentId,
    required this.title,
    required this.startTime,
    required this.endTime,
  });
}

/// Resultado da operação de liberação de agenda e encerramento/exclusão
class ScheduleReleaseResult {
  final bool success;
  final int releasedAppointmentsCount;
  final List<FreedTimeSlot> freedSlots;
  final int cancelledRemindersCount;
  final int externalCalendarDeletedCount;
  final int externalCalendarPendingCount;
  final List<String> externalErrors;
  final String message;

  const ScheduleReleaseResult({
    required this.success,
    this.releasedAppointmentsCount = 0,
    this.freedSlots = const [],
    this.cancelledRemindersCount = 0,
    this.externalCalendarDeletedCount = 0,
    this.externalCalendarPendingCount = 0,
    this.externalErrors = const [],
    required this.message,
  });

  bool get hasExternalPending => externalCalendarPendingCount > 0;
  bool get hasExternalErrors => externalErrors.isNotEmpty;
}

/// Coordenador centralizado para liberação da agenda, cancelamento de compromissos futuros,
/// cancelamento de lembretes e exclusão segura de pessoas, estudos e revisitas.
class ScheduleReleaseCoordinator {
  final AppDatabase db;
  final AppRepository repo;
  final CalendarSyncCoordinator? calendarCoordinator;
  final LocalReminderService? reminderService;

  ScheduleReleaseCoordinator({
    required this.db,
    required this.repo,
    this.calendarCoordinator,
    this.reminderService,
  });

  /// Busca compromissos futuros vinculados a um estudo específico pelo studyId
  Future<List<AppointmentEntry>> getFutureAppointmentsForStudy(
    String studyId, {
    DateTime? now,
  }) async {
    final effectiveNow = (now ?? DateTime.now());
    final rows =
        await (db.select(db.appointments)
              ..where(
                (t) =>
                    t.studyId.equals(studyId) &
                    t.deletedAt.isNull() &
                    t.endTime.isBiggerOrEqualValue(effectiveNow),
              )
              ..orderBy([
                (t) => drift.OrderingTerm(
                  expression: t.startTime,
                  mode: drift.OrderingMode.asc,
                ),
              ]))
            .get();

    // Filtra compromissos ativos que bloqueiam agenda (ignora cancelados, realizados e reagendados já superados)
    return rows
        .where(
          (a) =>
              a.status != 'cancelado' &&
              a.status != 'nao_realizado' &&
              a.status != 'reagendado' &&
              a.status != 'realizado' &&
              a.status != 'concluido' &&
              a.status != 'concluído',
        )
        .toList();
  }

  /// Busca compromissos futuros vinculados a uma revisita (personId com studyId nulo)
  Future<List<AppointmentEntry>> getFutureAppointmentsForRevisit(
    String personId, {
    DateTime? now,
  }) async {
    final effectiveNow = (now ?? DateTime.now());
    final rows =
        await (db.select(db.appointments)
              ..where(
                (t) =>
                    t.personId.equals(personId) &
                    t.studyId.isNull() &
                    t.deletedAt.isNull() &
                    t.endTime.isBiggerOrEqualValue(effectiveNow),
              )
              ..orderBy([
                (t) => drift.OrderingTerm(
                  expression: t.startTime,
                  mode: drift.OrderingMode.asc,
                ),
              ]))
            .get();

    return rows
        .where(
          (a) =>
              a.status != 'cancelado' &&
              a.status != 'nao_realizado' &&
              a.status != 'reagendado' &&
              a.status != 'realizado' &&
              a.status != 'concluido' &&
              a.status != 'concluído',
        )
        .toList();
  }

  /// Busca compromissos futuros vinculados a uma pessoa (opcionalmente incluindo estudos)
  Future<List<AppointmentEntry>> getFutureAppointmentsForPerson(
    String personId, {
    bool includeStudyAppointments = true,
    DateTime? now,
  }) async {
    final effectiveNow = (now ?? DateTime.now());
    final query = db.select(db.appointments)
      ..where((t) {
        final base =
            t.personId.equals(personId) &
            t.deletedAt.isNull() &
            t.endTime.isBiggerOrEqualValue(effectiveNow);
        return includeStudyAppointments ? base : (base & t.studyId.isNull());
      })
      ..orderBy([
        (t) => drift.OrderingTerm(
          expression: t.startTime,
          mode: drift.OrderingMode.asc,
        ),
      ]);

    final rows = await query.get();
    return rows
        .where(
          (a) =>
              a.status != 'cancelado' &&
              a.status != 'nao_realizado' &&
              a.status != 'reagendado' &&
              a.status != 'realizado' &&
              a.status != 'concluido' &&
              a.status != 'concluído',
        )
        .toList();
  }

  /// Obtém o resumo de relacionamentos de uma pessoa para a janela de confirmação de exclusão
  Future<PersonRelationshipsSummary> getPersonRelationshipsSummary(
    String personId,
  ) async {
    final person = await repo.getPersonById(personId, includeDeleted: true);
    final personName = person?.name ?? 'Contato';

    final visits = await (db.select(
      db.visits,
    )..where((t) => t.personId.equals(personId) & t.deletedAt.isNull())).get();

    // Busca participantes da pessoa (inclusive se ela foi movida para a lixeira)
    final myParticipants = await (db.select(
      db.studyParticipants,
    )..where((t) => t.personId.equals(personId))).get();
    final personStudyIds = myParticipants.map((p) => p.studyId).toSet();

    final exclusiveStudies = <BibleStudyEntry>[];
    final sharedStudies = <BibleStudyEntry>[];
    final sharedStudyOtherParticipants = <String, List<String>>{};

    for (final studyId in personStudyIds) {
      final study = await repo.getStudyById(studyId, includeDeleted: true);
      if (study == null) continue;

      final studyParts = await (db.select(
        db.studyParticipants,
      )..where((t) => t.studyId.equals(studyId) & t.deletedAt.isNull())).get();
      final otherPartPersonIds = studyParts
          .map((p) => p.personId)
          .where((id) => id != personId)
          .toList();

      if (otherPartPersonIds.isEmpty) {
        exclusiveStudies.add(study);
      } else {
        sharedStudies.add(study);
        final otherNames = <String>[];
        for (final otherId in otherPartPersonIds) {
          final otherPerson = await repo.getPersonById(
            otherId,
            includeDeleted: true,
          );
          if (otherPerson != null) {
            otherNames.add(otherPerson.name);
          }
        }
        sharedStudyOtherParticipants[studyId] = otherNames;
      }
    }

    final now = DateTime.now();
    // Compromissos futuros que serão efetivamente cancelados na exclusão desta pessoa:
    // 1) Revisitas/compromissos pessoais (studyId nulo)
    // 2) Compromissos de estudos exclusivos da pessoa (que serão excluídos)
    // Compromissos de estudos compartilhados com outros participantes NÃO são cancelados,
    // pois continuam ativos na agenda para os outros estudantes.
    final revisitAppts = await getFutureAppointmentsForRevisit(
      personId,
      now: now,
    );
    final exclusiveStudyAppts = <AppointmentEntry>[];
    for (final study in exclusiveStudies) {
      final appts = await getFutureAppointmentsForStudy(study.id, now: now);
      exclusiveStudyAppts.addAll(appts);
    }
    final futureApptsMap = <String, AppointmentEntry>{};
    for (final a in revisitAppts) {
      futureApptsMap[a.id] = a;
    }
    for (final a in exclusiveStudyAppts) {
      futureApptsMap[a.id] = a;
    }
    final futureAppts = futureApptsMap.values.toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final pastAppts =
        await (db.select(db.appointments)..where(
              (t) =>
                  t.personId.equals(personId) &
                  t.deletedAt.isNull() &
                  t.endTime.isSmallerThanValue(now),
            ))
            .get();

    final linkedPhoneContact =
        await (db.select(db.phoneContacts)..where(
              (t) =>
                  t.convertedPersonId.equals(personId) & t.deletedAt.isNull(),
            ))
            .getSingleOrNull();

    final photos = await (db.select(
      db.personPhotos,
    )..where((t) => t.personId.equals(personId) & t.deletedAt.isNull())).get();

    final publications = await (db.select(
      db.personPublications,
    )..where((t) => t.personId.equals(personId) & t.deletedAt.isNull())).get();

    final familyTies =
        await (db.select(db.familyTies)..where(
              (t) =>
                  (t.personId.equals(personId) |
                      t.relatedPersonId.equals(personId)) &
                  t.deletedAt.isNull(),
            ))
            .get();

    final voiceNotes = await (db.select(
      db.voiceNotes,
    )..where((t) => t.personId.equals(personId) & t.deletedAt.isNull())).get();

    final tasks = await (db.select(
      db.tasks,
    )..where((t) => t.personId.equals(personId) & t.deletedAt.isNull())).get();

    final notes = await (db.select(
      db.knowledgeNotes,
    )..where((t) => t.personId.equals(personId) & t.deletedAt.isNull())).get();

    return PersonRelationshipsSummary(
      personId: personId,
      personName: personName,
      visitsCount: visits.length,
      exclusiveStudies: exclusiveStudies,
      sharedStudies: sharedStudies,
      sharedStudyOtherParticipants: sharedStudyOtherParticipants,
      futureAppointments: futureAppts,
      pastAppointmentsCount: pastAppts.length,
      linkedPhoneContactName: linkedPhoneContact?.name,
      linkedPhoneContactPhone: linkedPhoneContact?.phone,
      photosCount: photos.length,
      publicationsCount: publications.length,
      familyTiesCount: familyTies.length,
      voiceNotesCount: voiceNotes.length,
      tasksCount: tasks.length,
      knowledgeNotesCount: notes.length,
    );
  }

  /// Cancela uma lista de compromissos de forma atômica e libera a agenda
  Future<ScheduleReleaseResult> releaseAppointments({
    required List<AppointmentEntry> appointments,
    required String reason,
  }) async {
    if (appointments.isEmpty) {
      return const ScheduleReleaseResult(
        success: true,
        releasedAppointmentsCount: 0,
        message: 'Nenhum compromisso pendente para liberar.',
      );
    }

    final now = DateTime.now();
    final freedSlots = <FreedTimeSlot>[];
    final apptIds = appointments.map((a) => a.id).toList();

    await db.transaction(() async {
      for (final appt in appointments) {
        final updated = appt.copyWith(
          status: 'cancelado',
          deletedAt: drift.Value(now),
          updatedAt: now,
          revision: appt.revision + 1,
        );

        await db.update(db.appointments).replace(updated);

        // Marca vínculos de calendário externo com pending_upload e deletedAt
        await (db.update(db.calendarEventLinks)..where(
              (tbl) =>
                  tbl.appointmentId.equals(appt.id) & tbl.deletedAt.isNull(),
            ))
            .write(
              CalendarEventLinksCompanion(
                syncStatus: const drift.Value('pending_upload'),
                deletedAt: drift.Value(now),
                updatedAt: drift.Value(now),
              ),
            );

        // Fila de sincronização do Drift
        await repo.recordSyncOperation(
          entityType: 'appointments',
          entityId: appt.id,
          operation: 'DELETE',
          payload: updated.toJson(),
          baseData: appt.toJson(),
        );

        freedSlots.add(
          FreedTimeSlot(
            appointmentId: appt.id,
            title: appt.title,
            startTime: appt.startTime,
            endTime: appt.endTime,
          ),
        );
      }
    });

    // 2. Cancela lembretes locais associados
    int cancelledReminders = 0;
    if (reminderService != null) {
      try {
        cancelledReminders = await reminderService!
            .cancelRemindersForAppointments(apptIds);
      } catch (e, st) {
        AppLogger.warning('Falha ao cancelar lembretes locais', e, st);
      }
    }

    // 3. Propagação da remoção para calendários externos (Google Calendar / Apple EventKit)
    int extDeleted = 0;
    int extPending = 0;
    final extErrors = <String>[];

    if (calendarCoordinator != null) {
      for (final apptId in apptIds) {
        final links = await (db.select(
          db.calendarEventLinks,
        )..where((t) => t.appointmentId.equals(apptId))).get();

        for (final link in links) {
          final provider = calendarCoordinator!.getProviderByName(
            link.provider,
          );
          if (provider != null && provider.isSupportedOnCurrentPlatform) {
            try {
              final isAuth = await provider.isAuthorized();
              if (isAuth) {
                final ok = await provider.deleteExternalEvent(
                  db,
                  link.externalEventId,
                );
                if (ok) {
                  extDeleted++;
                  await (db.update(
                    db.calendarEventLinks,
                  )..where((t) => t.id.equals(link.id))).write(
                    CalendarEventLinksCompanion(
                      syncStatus: const drift.Value('synced'),
                      lastError: const drift.Value(null),
                      updatedAt: drift.Value(DateTime.now()),
                    ),
                  );
                  continue;
                } else {
                  await (db.update(
                    db.calendarEventLinks,
                  )..where((t) => t.id.equals(link.id))).write(
                    CalendarEventLinksCompanion(
                      lastError: const drift.Value(
                        'Exclusão remota rejeitada ou calendário somente leitura',
                      ),
                      updatedAt: drift.Value(DateTime.now()),
                    ),
                  );
                }
              } else {
                await (db.update(
                  db.calendarEventLinks,
                )..where((t) => t.id.equals(link.id))).write(
                  CalendarEventLinksCompanion(
                    lastError: const drift.Value(
                      'Provedor de calendário não autorizado ou desconectado',
                    ),
                    updatedAt: drift.Value(DateTime.now()),
                  ),
                );
              }
            } catch (e) {
              extErrors.add('${link.provider}: $e');
              await (db.update(
                db.calendarEventLinks,
              )..where((t) => t.id.equals(link.id))).write(
                CalendarEventLinksCompanion(
                  lastError: drift.Value('$e'),
                  updatedAt: drift.Value(DateTime.now()),
                ),
              );
            }
          }
          // Se não excluiu remotamente com sucesso, preserva como pending_upload
          extPending++;
        }
      }
    }

    final buffer = StringBuffer(
      '${freedSlots.length} horário(s) liberado(s) na agenda local.',
    );
    if (extDeleted > 0) {
      buffer.write(' $extDeleted evento(s) removido(s) do calendário externo.');
    }
    if (extPending > 0) {
      buffer.write(
        ' $extPending remoção(ões) externa(s) pendente(s) de sincronização.',
      );
    }

    return ScheduleReleaseResult(
      success: true,
      releasedAppointmentsCount: freedSlots.length,
      freedSlots: freedSlots,
      cancelledRemindersCount: cancelledReminders,
      externalCalendarDeletedCount: extDeleted,
      externalCalendarPendingCount: extPending,
      externalErrors: extErrors,
      message: buffer.toString(),
    );
  }

  /// Encerra um estudo bíblico liberando os compromissos futuros vinculados
  Future<ScheduleReleaseResult> endStudyWithScheduleRelease({
    required BibleStudyEntry study,
    required String endReason,
    String? notes,
    bool releaseFutureAppointments = true,
  }) async {
    final now = DateTime.now();
    final reasonPayload = jsonEncode({
      'endReason': endReason,
      'notes': notes?.trim() ?? '',
      'endedAt': now.toIso8601String(),
    });

    final newStatus = endReason == 'Estudo concluído / Batizado'
        ? 'concluido'
        : 'encerrado';

    final updatedStudy = study.copyWith(
      status: newStatus,
      pauseOrCloseReason: drift.Value(reasonPayload),
      updatedAt: now,
      revision: study.revision + 1,
    );

    // 1. Atualiza estudo e participantes dentro de transação
    await db.transaction(() async {
      await db.update(db.bibleStudies).replace(updatedStudy);
      await repo.recordSyncOperation(
        entityType: 'bible_studies',
        entityId: study.id,
        operation: 'UPDATE',
        payload: updatedStudy.toJson(),
        baseData: study.toJson(),
      );

      final participants = await (db.select(
        db.studyParticipants,
      )..where((t) => t.studyId.equals(study.id) & t.deletedAt.isNull())).get();

      for (final part in participants) {
        final p = await repo.getPersonById(part.personId);
        if (p != null) {
          final updatedP = p.copyWith(
            status: 'revisita',
            updatedAt: now,
            revision: p.revision + 1,
          );
          await db.update(db.people).replace(updatedP);
          await repo.recordSyncOperation(
            entityType: 'people',
            entityId: p.id,
            operation: 'UPDATE',
            payload: updatedP.toJson(),
            baseData: p.toJson(),
          );
        }
      }
    });

    // 2. Libera compromissos futuros vinculados se solicitado
    if (releaseFutureAppointments) {
      final futureAppts = await getFutureAppointmentsForStudy(
        study.id,
        now: now,
      );
      return releaseAppointments(
        appointments: futureAppts,
        reason: 'Estudo encerrado: $endReason',
      );
    }

    return const ScheduleReleaseResult(
      success: true,
      releasedAppointmentsCount: 0,
      message: 'Estudo encerrado com sucesso.',
    );
  }

  /// Encerra uma revisita liberando os compromissos futuros vinculados
  Future<ScheduleReleaseResult> endRevisitWithScheduleRelease({
    required PersonEntry person,
    required String endReason,
    String? notes,
    bool releaseFutureAppointments = true,
  }) async {
    final now = DateTime.now();
    final extraNotes = notes?.trim() ?? '';
    final reasonPayload = jsonEncode({
      'endReason': endReason,
      'notes': extraNotes,
      'endedAt': now.toIso8601String(),
    });

    final updatedPerson = person.copyWith(
      status: 'revisita_encerrada',
      nextActionNote: drift.Value(
        'Revisita encerrada: $endReason${extraNotes.isNotEmpty ? " - $extraNotes" : ""}',
      ),
      contactRestrictions: drift.Value(
        person.contactRestrictions == null ||
                person.contactRestrictions!.isEmpty
            ? reasonPayload
            : person.contactRestrictions,
      ),
      updatedAt: now,
      revision: person.revision + 1,
    );

    // 1. Atualiza pessoa
    await db.transaction(() async {
      await db.update(db.people).replace(updatedPerson);
      await repo.recordSyncOperation(
        entityType: 'people',
        entityId: person.id,
        operation: 'UPDATE',
        payload: updatedPerson.toJson(),
        baseData: person.toJson(),
      );
    });

    // 2. Libera compromissos futuros vinculados à revisita (studyId nulo)
    if (releaseFutureAppointments) {
      final futureAppts = await getFutureAppointmentsForRevisit(
        person.id,
        now: now,
      );
      return releaseAppointments(
        appointments: futureAppts,
        reason: 'Revisita encerrada: $endReason',
      );
    }

    return const ScheduleReleaseResult(
      success: true,
      releasedAppointmentsCount: 0,
      message: 'Revisita encerrada com sucesso.',
    );
  }

  /// Exclui definitivamente uma pessoa do banco local com liberação de agenda e desvinculação segura
  Future<ScheduleReleaseResult> permanentlyDeletePersonWithScheduleRelease({
    required String personId,
  }) async {
    final summary = await getPersonRelationshipsSummary(personId);
    final now = DateTime.now();

    // 1. Cancela compromissos futuros vinculados para liberar agenda
    ScheduleReleaseResult? releaseResult;
    if (summary.futureAppointments.isNotEmpty) {
      releaseResult = await releaseAppointments(
        appointments: summary.futureAppointments,
        reason: 'Pessoa excluída definitivamente',
      );
    }

    // 2. Realiza a exclusão definitiva em transação
    await db.transaction(() async {
      // a. Remove notas de áudio da pessoa e de visitas
      final visits = await (db.select(
        db.visits,
      )..where((t) => t.personId.equals(personId))).get();
      final visitIds = visits.map((v) => v.id).toList();

      await (db.delete(db.voiceNotes)..where(
            (t) => t.personId.equals(personId) | t.visitId.isIn(visitIds),
          ))
          .go();

      // b. Desvincula contato telefônico promovido (não apaga o contato telefônico)
      await (db.update(
        db.phoneContacts,
      )..where((t) => t.convertedPersonId.equals(personId))).write(
        const PhoneContactsCompanion(convertedPersonId: drift.Value(null)),
      );

      // c. Desvincula tarefas e conhecimento (preserva tarefas e artigos desvinculando personId)
      await (db.update(db.tasks)..where((t) => t.personId.equals(personId)))
          .write(const TasksCompanion(personId: drift.Value(null)));

      await (db.update(db.knowledgeNotes)
            ..where((t) => t.personId.equals(personId)))
          .write(const KnowledgeNotesCompanion(personId: drift.Value(null)));

      await (db.update(
        db.knowledgeQuestions,
      )..where((t) => t.personId.equals(personId))).write(
        const KnowledgeQuestionsCompanion(personId: drift.Value(null)),
      );

      await (db.update(
        db.knowledgeDocuments,
      )..where((t) => t.personId.equals(personId))).write(
        const KnowledgeDocumentsCompanion(personId: drift.Value(null)),
      );

      await (db.update(
        db.knowledgeResources,
      )..where((t) => t.personId.equals(personId))).write(
        const KnowledgeResourcesCompanion(personId: drift.Value(null)),
      );

      // d. Remove visitas da pessoa
      await (db.delete(
        db.visits,
      )..where((t) => t.personId.equals(personId))).go();

      // e. Trata estudos: estudos exclusivos são excluídos; estudos compartilhados preservam o estudo e a agenda dos demais
      for (final study in summary.sharedStudies) {
        final studyParts =
            await (db.select(db.studyParticipants)..where(
                  (t) =>
                      t.studyId.equals(study.id) &
                      t.personId.isNotValue(personId) &
                      t.deletedAt.isNull(),
                ))
                .get();
        if (studyParts.isNotEmpty) {
          final nextOwnerId = studyParts.first.personId;
          await (db.update(db.appointments)..where(
                (t) => t.studyId.equals(study.id) & t.personId.equals(personId),
              ))
              .write(
                AppointmentsCompanion(
                  personId: drift.Value(nextOwnerId),
                  updatedAt: drift.Value(now),
                ),
              );
        }
      }

      for (final study in summary.exclusiveStudies) {
        // Exclui sessões do estudo exclusivo
        await (db.delete(
          db.studySessions,
        )..where((t) => t.studyId.equals(study.id))).go();

        // Cancela lembretes e exclui compromissos remanescentes do estudo exclusivo
        final studyAppts = await (db.select(
          db.appointments,
        )..where((t) => t.studyId.equals(study.id))).get();
        final studyApptIds = studyAppts.map((a) => a.id).toList();
        if (studyApptIds.isNotEmpty && reminderService != null) {
          await reminderService!.cancelRemindersForAppointments(studyApptIds);
        }
        await (db.delete(
          db.appointments,
        )..where((t) => t.studyId.equals(study.id))).go();
        // Exclui estudo exclusivo
        await (db.delete(
          db.bibleStudies,
        )..where((t) => t.id.equals(study.id))).go();
        await repo.recordSyncOperation(
          entityType: 'bible_studies',
          entityId: study.id,
          operation: 'HARD_DELETE',
          payload: {'id': study.id, 'hardDelete': true},
        );
      }

      // Remove participante de todos os estudos
      await (db.delete(
        db.studyParticipants,
      )..where((t) => t.personId.equals(personId))).go();

      // f. Limpa todos os compromissos restantes exclusivos da pessoa
      final remainingAppts = await (db.select(
        db.appointments,
      )..where((t) => t.personId.equals(personId))).get();
      final remainingApptIds = remainingAppts.map((a) => a.id).toList();

      if (remainingApptIds.isNotEmpty) {
        if (reminderService != null) {
          await reminderService!.cancelRemindersForAppointments(
            remainingApptIds,
          );
        }
        // Cancela vínculos externos
        await (db.update(
          db.calendarEventLinks,
        )..where((t) => t.appointmentId.isIn(remainingApptIds))).write(
          CalendarEventLinksCompanion(
            syncStatus: const drift.Value('pending_upload'),
            deletedAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
        );

        await (db.delete(
          db.appointments,
        )..where((t) => t.personId.equals(personId))).go();
      }

      // g. Remove laços familiares, fotos e publicações
      await (db.delete(db.familyTies)..where(
            (t) =>
                t.personId.equals(personId) |
                t.relatedPersonId.equals(personId),
          ))
          .go();

      await (db.delete(
        db.personPhotos,
      )..where((t) => t.personId.equals(personId))).go();

      await (db.delete(
        db.personPublications,
      )..where((t) => t.personId.equals(personId))).go();

      // h. Exclui o registro da pessoa
      await (db.delete(db.people)..where((t) => t.id.equals(personId))).go();

      // i. Registra operação de sincronização HARD_DELETE
      await repo.recordSyncOperation(
        entityType: 'people',
        entityId: personId,
        operation: 'HARD_DELETE',
        payload: {'id': personId, 'hardDelete': true},
      );
    });

    return ScheduleReleaseResult(
      success: true,
      releasedAppointmentsCount: releaseResult?.releasedAppointmentsCount ?? 0,
      freedSlots: releaseResult?.freedSlots ?? [],
      cancelledRemindersCount: releaseResult?.cancelledRemindersCount ?? 0,
      externalCalendarDeletedCount:
          releaseResult?.externalCalendarDeletedCount ?? 0,
      externalCalendarPendingCount:
          releaseResult?.externalCalendarPendingCount ?? 0,
      externalErrors: releaseResult?.externalErrors ?? [],
      message:
          '"${summary.personName}" excluído definitivamente. Horários liberados na agenda local.',
    );
  }
}

/// Provider do ScheduleReleaseCoordinator
final scheduleReleaseCoordinatorProvider = Provider<ScheduleReleaseCoordinator>(
  (ref) {
    final repo = ref.watch(repositoryProvider);
    final reminderService = ref.watch(localReminderServiceProvider);
    final calendarCoordinator = ref.watch(calendarSyncCoordinatorProvider);

    return ScheduleReleaseCoordinator(
      db: repo.db,
      repo: repo,
      calendarCoordinator: calendarCoordinator,
      reminderService: reminderService,
    );
  },
);
