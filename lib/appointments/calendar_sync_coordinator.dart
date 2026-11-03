import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../database/app_database.dart';
import '../ui/providers.dart';
import 'calendar_provider.dart';
import 'google_calendar_provider.dart';
import 'apple_eventkit_provider.dart';

enum SyncCoordinationStatus { idle, syncing, success, conflict, error }

class CalendarConflictItem {
  final CalendarEventLinkEntry link;
  final AppointmentEntry localAppointment;
  final ExternalCalendarEventEntry? externalEvent;

  CalendarConflictItem({
    required this.link,
    required this.localAppointment,
    this.externalEvent,
  });

  List<String> get divergentFields {
    final fields = <String>[];
    if (externalEvent == null) return fields;
    if (localAppointment.title != externalEvent!.title) {
      fields.add('title');
    }
    if (localAppointment.startTime != externalEvent!.startTime) {
      fields.add('startTime');
    }
    if (localAppointment.endTime != externalEvent!.endTime) {
      fields.add('endTime');
    }
    if ((localAppointment.locationNotes ?? '') !=
        (externalEvent!.location ?? '')) {
      fields.add('location');
    }
    return fields;
  }
}

class CalendarSyncCoordinator {
  final AppDatabase db;
  final GoogleCalendarProvider googleProvider;
  final AppleEventKitProvider appleProvider;
  final bool _isWebPlatform;

  CalendarSyncCoordinator(
    this.db, {
    GoogleCalendarProvider? google,
    AppleEventKitProvider? apple,
    bool? isWebPlatform,
  }) : _isWebPlatform = isWebPlatform ?? kIsWeb,
       googleProvider = google ?? GoogleCalendarProvider(),
       appleProvider =
           apple ?? AppleEventKitProvider(isWebPlatform: isWebPlatform);

  List<CalendarProvider> get allProviders =>
      _isWebPlatform ? [googleProvider] : [googleProvider, appleProvider];

  CalendarProvider? getProviderByName(String providerName) {
    if (providerName == 'google') return googleProvider;
    if (providerName == 'apple_eventkit') return appleProvider;
    return null;
  }

  /// Sincroniza todos os provedores autorizados executando:
  /// 1. Download de eventos externos com paginação e syncToken
  /// 2. Reconciliação em 3 vias (3-way merge) entre estado local, externo e última versão sincronizada
  /// 3. Detecção determinística de conflitos
  /// 4. Processamento da Outbox (pending_upload e propagação de exclusões)
  /// 5. Prevenção absoluta de loops de sincronização
  Future<CalendarSyncResult> syncAll({bool fullSync = false}) async {
    int totalDownloaded = 0;
    int totalUploaded = 0;
    int totalConflicts = 0;
    final errors = <String>[];

    // 1. Download de alterações externas
    for (final provider in allProviders) {
      final authorized = await provider.isAuthorized();
      if (!authorized) continue;

      final res = await provider.syncEvents(db: db, fullSync: fullSync);
      totalDownloaded += res.eventsDownloaded;
      totalUploaded += res.eventsUploaded;
      if (!res.success && res.errorMessage != null) {
        errors.add('${provider.providerType.displayName}: ${res.errorMessage}');
      }
    }

    // 2. Reconciliação Bidirecional em 3 vias dos vínculos existentes
    final allLinks = await (db.select(db.calendarEventLinks)).get();

    for (final link in allLinks) {
      final provider = getProviderByName(link.provider);
      final isProvAuth = provider != null && await provider.isAuthorized();

      // Caso 1: Vínculo já marcado como deletado no banco (tombstone) e pendente de exclusão externa
      if (link.deletedAt != null) {
        if (link.syncStatus == 'pending_upload' &&
            link.externalEventId.isNotEmpty &&
            isProvAuth) {
          final ok = await provider.deleteExternalEvent(
            db,
            link.externalEventId,
          );
          if (ok) {
            totalUploaded++;
            await (db.update(
              db.calendarEventLinks,
            )..where((t) => t.id.equals(link.id))).write(
              CalendarEventLinksCompanion(
                syncStatus: const drift.Value('synced'),
                updatedAt: drift.Value(DateTime.now()),
              ),
            );
          } else {
            errors.add(
              'Falha ao excluir evento externo ${link.externalEventId} no provedor ${provider.providerType.displayName}',
            );
          }
        }
        continue;
      }

      // Busca compromisso local associado
      final appt = await (db.select(
        db.appointments,
      )..where((t) => t.id.equals(link.appointmentId))).getSingleOrNull();

      // Caso 2: Compromisso local foi excluído no SQLite (soft delete)
      if (appt == null || appt.deletedAt != null) {
        bool ok = true;
        if (link.externalEventId.isNotEmpty && isProvAuth) {
          ok = await provider.deleteExternalEvent(db, link.externalEventId);
          if (ok) {
            totalUploaded++;
          } else {
            errors.add(
              'Falha ao excluir evento externo ${link.externalEventId} no provedor ${provider.providerType.displayName}',
            );
          }
        }
        if (ok) {
          await (db.update(
            db.calendarEventLinks,
          )..where((t) => t.id.equals(link.id))).write(
            CalendarEventLinksCompanion(
              deletedAt: drift.Value(DateTime.now()),
              syncStatus: const drift.Value('synced'),
              updatedAt: drift.Value(DateTime.now()),
            ),
          );
        }
        continue;
      }

      // Busca evento externo associado
      final ext =
          await (db.select(db.externalCalendarEvents)..where(
                (t) =>
                    t.externalEventId.equals(link.externalEventId) &
                    t.provider.equals(link.provider),
              ))
              .getSingleOrNull();

      // Caso 3: Evento externo foi excluído ou cancelado remotamente
      if (ext != null &&
          (ext.isDeletedExternal || ext.externalStatus == 'cancelled')) {
        // Marca tombstone no vínculo sem apagar o compromisso ministerial local
        await (db.update(
          db.calendarEventLinks,
        )..where((t) => t.id.equals(link.id))).write(
          CalendarEventLinksCompanion(
            syncStatus: const drift.Value('external_deleted'),
            deletedAt: drift.Value(DateTime.now()),
            updatedAt: drift.Value(DateTime.now()),
          ),
        );
        continue;
      }

      // Avaliação de alterações:
      final isPendingKeepLocal = link.pendingResolution == 'keep_local';

      if (isPendingKeepLocal) {
        // O usuário já resolveu explicitamente o conflito mantendo a versão local.
        // Processa o envio pendente com segurança sem reabrir o conflito resolvido.
        if (isProvAuth) {
          final resId = await provider.pushAppointmentToExternal(db, appt);
          if (resId != null) {
            totalUploaded++;
            final effectiveExternalId = resId;
            final updatedExt =
                await (db.select(db.externalCalendarEvents)..where(
                      (t) =>
                          t.externalEventId.equals(effectiveExternalId) &
                          t.provider.equals(link.provider),
                    ))
                    .getSingleOrNull();
            final currentLink = await (db.select(
              db.calendarEventLinks,
            )..where((t) => t.id.equals(link.id))).getSingleOrNull();
            final now = DateTime.now();
            final newEtag =
                currentLink?.externalETagAtSync ??
                updatedExt?.etag ??
                (link.provider == 'apple_eventkit'
                    ? AppleEventKitProvider.computeEventFingerprint(
                        externalEventId: effectiveExternalId,
                        calendarId: updatedExt?.calendarId ?? '',
                        title: appt.title,
                        location: appt.locationNotes,
                        startTime: appt.startTime,
                        endTime: appt.endTime,
                      )
                    : ext?.etag);
            await (db.update(
              db.calendarEventLinks,
            )..where((t) => t.id.equals(link.id))).write(
              CalendarEventLinksCompanion(
                externalEventId: drift.Value(effectiveExternalId),
                syncStatus: const drift.Value('synced'),
                pendingResolution: const drift.Value(null),
                localRevisionAtSync: drift.Value(appt.revision),
                externalETagAtSync: drift.Value(newEtag),
                updatedAt: drift.Value(now),
              ),
            );
          } else {
            // Falha ao enviar para o provedor: preserva a decisão persistida e mantém pending_upload
            errors.add(
              'Falha ao enviar resolução de conflito local para ${provider.providerType.displayName}',
            );
          }
        }
        continue;
      }

      final localChanged =
          (appt.revision > link.localRevisionAtSync) ||
          (link.syncStatus == 'pending_upload');
      final externalChanged =
          ext != null &&
          ((link.externalETagAtSync != null &&
                  ext.etag != null &&
                  ext.etag != link.externalETagAtSync) ||
              (ext.lastModifiedExternal != null &&
                  ext.lastModifiedExternal!.isAfter(link.updatedAt)));

      if (localChanged && externalChanged) {
        // CONFLITO REAL: Ambos os lados sofreram alterações concorrentes
        totalConflicts++;
        await (db.update(
          db.calendarEventLinks,
        )..where((t) => t.id.equals(link.id))).write(
          CalendarEventLinksCompanion(
            syncStatus: const drift.Value('conflict'),
            updatedAt: drift.Value(DateTime.now()),
          ),
        );
      } else if (localChanged && !externalChanged) {
        // Apenas local mudou: Envia para o provedor externo
        if (isProvAuth) {
          final resId = await provider.pushAppointmentToExternal(db, appt);
          if (resId != null) {
            totalUploaded++;
          } else {
            errors.add(
              'Falha ao enviar compromisso local ${appt.id} para ${provider.providerType.displayName}',
            );
          }
        }
      } else if (!localChanged && externalChanged) {
        // Apenas externo mudou: Atualiza dados de agenda no compromisso local preservando dados pastorais
        final now = DateTime.now();
        await (db.update(
          db.appointments,
        )..where((t) => t.id.equals(appt.id))).write(
          AppointmentsCompanion(
            title: drift.Value(ext.title),
            startTime: drift.Value(ext.startTime),
            endTime: drift.Value(ext.endTime),
            durationMinutes: drift.Value(
              ext.endTime.difference(ext.startTime).inMinutes,
            ),
            locationNotes: ext.location != null
                ? drift.Value(ext.location)
                : const drift.Value.absent(),
            revision: drift.Value(appt.revision + 1),
            updatedAt: drift.Value(now),
          ),
        );

        // Atualiza vínculo para que não seja interpretado como nova modificação local (anti sync-loop)
        await (db.update(
          db.calendarEventLinks,
        )..where((t) => t.id.equals(link.id))).write(
          CalendarEventLinksCompanion(
            syncStatus: const drift.Value('synced'),
            localRevisionAtSync: drift.Value(appt.revision + 1),
            externalETagAtSync: drift.Value(ext.etag),
            updatedAt: drift.Value(now),
          ),
        );
      }
    }

    // 3. Processamento de Novos Compromissos Locais sem vínculos para provedores autorizados
    final activeAppointments = await (db.select(
      db.appointments,
    )..where((t) => t.deletedAt.isNull())).get();

    for (final appt in activeAppointments) {
      for (final provider in allProviders) {
        if (!await provider.isAuthorized()) continue;
        final providerName =
            provider.providerType == CalendarProviderType.google
            ? 'google'
            : 'apple_eventkit';

        final existingLink =
            await (db.select(db.calendarEventLinks)..where(
                  (t) =>
                      t.appointmentId.equals(appt.id) &
                      t.provider.equals(providerName),
                ))
                .getSingleOrNull();

        if (existingLink == null) {
          final resId = await provider.pushAppointmentToExternal(db, appt);
          if (resId != null) {
            totalUploaded++;
          } else {
            errors.add(
              'Falha ao criar evento externo para compromisso ${appt.id} em ${provider.providerType.displayName}',
            );
          }
        }
      }
    }

    // Recontagem precisa de conflitos existentes
    final remainingConflicts = await getPendingConflicts();
    totalConflicts = remainingConflicts.length;

    return CalendarSyncResult(
      success: errors.isEmpty,
      eventsDownloaded: totalDownloaded,
      eventsUploaded: totalUploaded,
      conflictsFound: totalConflicts,
      errorMessage: errors.isNotEmpty ? errors.join('; ') : null,
    );
  }

  /// Propaga criação ou alteração de um compromisso local para os calendários externos conectados
  Future<void> pushLocalAppointment(AppointmentEntry appointment) async {
    for (final provider in allProviders) {
      if (await provider.isAuthorized()) {
        await provider.pushAppointmentToExternal(db, appointment);
      }
    }
  }

  /// Trata exclusão lógica de compromisso: propaga ao calendário externo e marca tombstone no vínculo
  Future<void> handleLocalAppointmentDeleted(String appointmentId) async {
    final links =
        await (db.select(db.calendarEventLinks)..where(
              (t) =>
                  t.appointmentId.equals(appointmentId) & t.deletedAt.isNull(),
            ))
            .get();

    for (final link in links) {
      final provider = getProviderByName(link.provider);
      if (provider != null && await provider.isAuthorized()) {
        await provider.deleteExternalEvent(db, link.externalEventId);
      }
      await (db.update(
        db.calendarEventLinks,
      )..where((t) => t.id.equals(link.id))).write(
        CalendarEventLinksCompanion(
          deletedAt: drift.Value(DateTime.now()),
          syncStatus: const drift.Value('synced'),
          updatedAt: drift.Value(DateTime.now()),
        ),
      );
    }
  }

  /// Retorna lista de conflitos pendentes de resolução manual
  Future<List<CalendarConflictItem>> getPendingConflicts() async {
    final conflictLinks =
        await (db.select(db.calendarEventLinks)..where(
              (t) =>
                  t.syncStatus.equals('conflict') &
                  t.deletedAt.isNull() &
                  t.pendingResolution.isNull(),
            ))
            .get();

    final result = <CalendarConflictItem>[];
    for (final link in conflictLinks) {
      final appt = await (db.select(
        db.appointments,
      )..where((t) => t.id.equals(link.appointmentId))).getSingleOrNull();
      if (appt == null) continue;

      final extEvent =
          await (db.select(db.externalCalendarEvents)..where(
                (t) =>
                    t.externalEventId.equals(link.externalEventId) &
                    t.provider.equals(link.provider),
              ))
              .getSingleOrNull();

      result.add(
        CalendarConflictItem(
          link: link,
          localAppointment: appt,
          externalEvent: extEvent,
        ),
      );
    }
    return result;
  }

  /// Resolução: Manter versão local (sobrescreve evento externo e converge)
  Future<void> resolveConflictKeepLocal(CalendarConflictItem conflict) async {
    final provider = getProviderByName(conflict.link.provider);
    String? resId;
    if (provider != null && await provider.isAuthorized()) {
      resId = await provider.pushAppointmentToExternal(
        db,
        conflict.localAppointment,
      );
    }

    final effectiveExternalId = resId ?? conflict.link.externalEventId;

    // Busca o registro externo atualizado para resgatar o etag / fingerprint mais recente
    final updatedExt =
        await (db.select(db.externalCalendarEvents)..where(
              (t) =>
                  t.externalEventId.equals(effectiveExternalId) &
                  t.provider.equals(conflict.link.provider),
            ))
            .getSingleOrNull();

    // Também verifica se o vínculo já possui o etag gravado pelo push do provedor
    final currentLink = await (db.select(
      db.calendarEventLinks,
    )..where((t) => t.id.equals(conflict.link.id))).getSingleOrNull();

    final newFingerprintOrEtag =
        currentLink?.externalETagAtSync ??
        updatedExt?.etag ??
        (conflict.link.provider == 'apple_eventkit'
            ? AppleEventKitProvider.computeEventFingerprint(
                externalEventId: effectiveExternalId,
                calendarId: updatedExt?.calendarId ?? '',
                title: conflict.localAppointment.title,
                location: conflict.localAppointment.locationNotes,
                startTime: conflict.localAppointment.startTime,
                endTime: conflict.localAppointment.endTime,
              )
            : conflict.externalEvent?.etag);

    final now = DateTime.now();
    await (db.update(
      db.calendarEventLinks,
    )..where((t) => t.id.equals(conflict.link.id))).write(
      CalendarEventLinksCompanion(
        externalEventId: drift.Value(effectiveExternalId),
        syncStatus: drift.Value(resId != null ? 'synced' : 'pending_upload'),
        pendingResolution: drift.Value(resId != null ? null : 'keep_local'),
        localRevisionAtSync: drift.Value(conflict.localAppointment.revision),
        externalETagAtSync: resId != null
            ? drift.Value(newFingerprintOrEtag)
            : const drift.Value.absent(),
        updatedAt: drift.Value(now),
      ),
    );
  }

  /// Resolução: Manter versão externa (atualiza compromisso local preservando vínculos pastorais e converge)
  Future<void> resolveConflictKeepExternal(
    CalendarConflictItem conflict,
  ) async {
    if (conflict.externalEvent == null) return;
    final ext = conflict.externalEvent!;
    final now = DateTime.now();

    await (db.update(
      db.appointments,
    )..where((t) => t.id.equals(conflict.localAppointment.id))).write(
      AppointmentsCompanion(
        title: drift.Value(ext.title),
        startTime: drift.Value(ext.startTime),
        endTime: drift.Value(ext.endTime),
        durationMinutes: drift.Value(
          ext.endTime.difference(ext.startTime).inMinutes,
        ),
        locationNotes: ext.location != null
            ? drift.Value(ext.location)
            : const drift.Value.absent(),
        revision: drift.Value(conflict.localAppointment.revision + 1),
        updatedAt: drift.Value(now),
      ),
    );

    await (db.update(
      db.calendarEventLinks,
    )..where((t) => t.id.equals(conflict.link.id))).write(
      CalendarEventLinksCompanion(
        syncStatus: const drift.Value('synced'),
        pendingResolution: const drift.Value(null),
        localRevisionAtSync: drift.Value(
          conflict.localAppointment.revision + 1,
        ),
        externalETagAtSync: drift.Value(ext.etag),
        updatedAt: drift.Value(now),
      ),
    );
  }
}

final calendarSyncCoordinatorProvider = Provider<CalendarSyncCoordinator>((
  ref,
) {
  final db = ref.watch(databaseProvider);
  return CalendarSyncCoordinator(db);
});
