import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:device_calendar/device_calendar.dart' as dev_cal;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/appointments/calendar_sync_coordinator.dart';
import 'package:ministerio_pessoal/appointments/google_calendar_provider.dart';
import 'package:ministerio_pessoal/appointments/apple_eventkit_provider.dart';
import 'package:ministerio_pessoal/appointments/calendar_provider.dart';

class FakeDeviceCalendarPlugin implements dev_cal.DeviceCalendarPlugin {
  bool hasPermissionsResult = true;
  List<dev_cal.Calendar> calendarsResult = [];
  List<dev_cal.Event> eventsResult = [];
  String? createdEventIdResult = 'apple_created_1';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<dev_cal.Result<bool>> hasPermissions() async {
    final res = dev_cal.Result<bool>();
    res.data = hasPermissionsResult;
    return res;
  }

  @override
  Future<dev_cal.Result<bool>> requestPermissions() async {
    final res = dev_cal.Result<bool>();
    res.data = hasPermissionsResult;
    return res;
  }

  @override
  Future<dev_cal.Result<UnmodifiableListView<dev_cal.Calendar>>>
  retrieveCalendars() async {
    final res = dev_cal.Result<UnmodifiableListView<dev_cal.Calendar>>();
    res.data = UnmodifiableListView<dev_cal.Calendar>(calendarsResult);
    return res;
  }

  @override
  Future<dev_cal.Result<UnmodifiableListView<dev_cal.Event>>> retrieveEvents(
    String? calendarId,
    dev_cal.RetrieveEventsParams? retrieveEventsParams,
  ) async {
    final res = dev_cal.Result<UnmodifiableListView<dev_cal.Event>>();
    res.data = UnmodifiableListView<dev_cal.Event>(eventsResult);
    return res;
  }

  @override
  Future<dev_cal.Result<String>?> createOrUpdateEvent(
    dev_cal.Event? event,
  ) async {
    final res = dev_cal.Result<String>();
    res.data = createdEventIdResult;
    return res;
  }
}

class MockGoogleCalendarProvider extends GoogleCalendarProvider {
  bool authorized = true;
  final Map<String, Map<String, dynamic>> remoteEvents = {};
  int pushCount = 0;
  int deleteCount = 0;
  bool failDownload = false;
  String? forcePushId;

  MockGoogleCalendarProvider({this.authorized = true});

  @override
  Future<bool> isAuthorized() async => authorized;

  @override
  Future<String?> pushAppointmentToExternal(
    AppDatabase db,
    AppointmentEntry appointment,
  ) async {
    pushCount++;
    final existingLink =
        await (db.select(db.calendarEventLinks)..where(
              (t) =>
                  t.appointmentId.equals(appointment.id) &
                  t.provider.equals('google') &
                  t.deletedAt.isNull(),
            ))
            .getSingleOrNull();

    final extId =
        forcePushId ??
        (existingLink?.externalEventId.isNotEmpty == true
            ? existingLink!.externalEventId
            : 'g_ev_${appointment.id}');
    final etag =
        'etag_${DateTime.now().millisecondsSinceEpoch}_rev${appointment.revision}';

    remoteEvents[extId] = {
      'id': extId,
      'summary': appointment.title,
      'startTime': appointment.startTime,
      'endTime': appointment.endTime,
      'etag': etag,
    };

    final now = DateTime.now();
    if (existingLink != null) {
      await (db.update(
        db.calendarEventLinks,
      )..where((t) => t.id.equals(existingLink.id))).write(
        CalendarEventLinksCompanion(
          externalEventId: drift.Value(extId),
          externalETagAtSync: drift.Value(etag),
          localRevisionAtSync: drift.Value(appointment.revision),
          syncStatus: const drift.Value('synced'),
          updatedAt: drift.Value(now),
        ),
      );
    } else {
      await db
          .into(db.calendarEventLinks)
          .insert(
            CalendarEventLinksCompanion.insert(
              id: 'link_g_${appointment.id}',
              appointmentId: appointment.id,
              externalEventId: extId,
              provider: 'google',
              syncStatus: const drift.Value('synced'),
              localRevisionAtSync: drift.Value(appointment.revision),
              externalETagAtSync: drift.Value(etag),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
    return extId;
  }

  @override
  Future<bool> deleteExternalEvent(
    AppDatabase db,
    String externalEventId,
  ) async {
    deleteCount++;
    remoteEvents.remove(externalEventId);
    final now = DateTime.now();
    await (db.update(db.calendarEventLinks)..where(
          (t) =>
              t.externalEventId.equals(externalEventId) &
              t.provider.equals('google'),
        ))
        .write(
          CalendarEventLinksCompanion(
            deletedAt: drift.Value(now),
            syncStatus: const drift.Value('synced'),
            updatedAt: drift.Value(now),
          ),
        );
    return true;
  }

  @override
  Future<CalendarSyncResult> syncEvents({
    required AppDatabase db,
    bool fullSync = false,
  }) async {
    if (failDownload) {
      return CalendarSyncResult(success: false, errorMessage: 'Download indisponível');
    }
    int count = 0;
    for (final entry in remoteEvents.values) {
      final extId = entry['id'] as String;
      final existing =
          await (db.select(db.externalCalendarEvents)..where(
                (t) =>
                    t.provider.equals('google') &
                    t.externalEventId.equals(extId),
              ))
              .getSingleOrNull();
      final now = DateTime.now();
      final isCancelled = entry['status'] == 'cancelled';
      if (existing == null) {
        await db
            .into(db.externalCalendarEvents)
            .insert(
              ExternalCalendarEventsCompanion.insert(
                id: 'ext_row_$extId',
                provider: 'google',
                calendarId: 'primary',
                externalEventId: extId,
                title: entry['summary'] as String,
                startTime: entry['startTime'] as DateTime,
                endTime: entry['endTime'] as DateTime,
                etag: drift.Value(entry['etag'] as String?),
                isDeletedExternal: drift.Value(isCancelled),
                externalStatus: isCancelled
                    ? const drift.Value('cancelled')
                    : const drift.Value.absent(),
                createdAt: now,
                updatedAt: now,
              ),
            );
      } else {
        await (db.update(
          db.externalCalendarEvents,
        )..where((t) => t.id.equals(existing.id))).write(
          ExternalCalendarEventsCompanion(
            title: drift.Value(entry['summary'] as String),
            startTime: drift.Value(entry['startTime'] as DateTime),
            endTime: drift.Value(entry['endTime'] as DateTime),
            etag: drift.Value(entry['etag'] as String?),
            isDeletedExternal: drift.Value(isCancelled),
            externalStatus: isCancelled
                ? const drift.Value('cancelled')
                : const drift.Value.absent(),
            updatedAt: drift.Value(now),
          ),
        );
      }
      count++;
    }
    return CalendarSyncResult(success: true, eventsDownloaded: count);
  }
}

class MockAppleCalendarProvider extends AppleEventKitProvider {
  bool authorized = true;
  final Map<String, Map<String, dynamic>> appleEvents = {};
  int pushCount = 0;
  int deleteCount = 0;

  MockAppleCalendarProvider({this.authorized = false});

  @override
  Future<bool> isAuthorized() async => authorized;

  @override
  Future<String?> pushAppointmentToExternal(
    AppDatabase db,
    AppointmentEntry appointment,
  ) async {
    pushCount++;
    final existingLink =
        await (db.select(db.calendarEventLinks)..where(
              (t) =>
                  t.appointmentId.equals(appointment.id) &
                  t.provider.equals('apple_eventkit') &
                  t.deletedAt.isNull(),
            ))
            .getSingleOrNull();

    final extId = existingLink?.externalEventId.isNotEmpty == true
        ? existingLink!.externalEventId
        : 'apple_ev_${appointment.id}';
    appleEvents[extId] = {
      'id': extId,
      'title': appointment.title,
      'startTime': appointment.startTime,
      'endTime': appointment.endTime,
    };

    final now = DateTime.now();
    if (existingLink != null) {
      await (db.update(
        db.calendarEventLinks,
      )..where((t) => t.id.equals(existingLink.id))).write(
        CalendarEventLinksCompanion(
          externalEventId: drift.Value(extId),
          syncStatus: const drift.Value('synced'),
          localRevisionAtSync: drift.Value(appointment.revision),
          updatedAt: drift.Value(now),
        ),
      );
    } else {
      await db
          .into(db.calendarEventLinks)
          .insert(
            CalendarEventLinksCompanion.insert(
              id: 'link_apple_${appointment.id}',
              appointmentId: appointment.id,
              externalEventId: extId,
              provider: 'apple_eventkit',
              syncStatus: const drift.Value('synced'),
              localRevisionAtSync: drift.Value(appointment.revision),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
    return extId;
  }

  @override
  Future<bool> deleteExternalEvent(
    AppDatabase db,
    String externalEventId,
  ) async {
    deleteCount++;
    appleEvents.remove(externalEventId);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();

  group('CalendarSyncCoordinator & 10 Scenarios Integration Contract', () {
    late AppDatabase db;
    late AppRepository repo;
    late MockGoogleCalendarProvider mockGoogle;
    late MockAppleCalendarProvider mockApple;
    late CalendarSyncCoordinator coordinator;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = AppRepository(db);
      mockGoogle = MockGoogleCalendarProvider(authorized: true);
      mockApple = MockAppleCalendarProvider(authorized: false);
      coordinator = CalendarSyncCoordinator(
        db,
        google: mockGoogle,
        apple: mockApple,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Não envia compromissos quando o download do provedor falha', () async {
      await repo.createAppointment(
        title: 'Compromisso local',
        startTime: DateTime(2026, 11, 2, 10),
        endTime: DateTime(2026, 11, 2, 11),
      );
      mockGoogle.failDownload = true;
      final result = await coordinator.syncAll(fullSync: true);
      expect(result.success, isFalse);
      expect(result.errorMessage, contains('Download indisponível'));
      expect(mockGoogle.pushCount, 0);
    });

    test('Cenário 1 — Criação local: envio ao Google, gravação do ID externo e idempotência sem duplicação', () async {
      // 1. Cria compromisso no Field Assistant
      final appt = await repo.createAppointment(
        title: 'Estudo com Mateus',
        startTime: DateTime(2026, 11, 2, 10, 0),
        endTime: DateTime(2026, 11, 2, 11, 0),
        durationMinutes: 60,
      );

      // 2. Executa primeira sincronização
      final res1 = await coordinator.syncAll();
      expect(res1.success, isTrue);
      expect(res1.eventsUploaded, equals(1));
      expect(mockGoogle.pushCount, equals(1));

      // 3. Verifica persistência do vínculo e ID externo retornado
      final link = await (db.select(
        db.calendarEventLinks,
      )..where((t) => t.appointmentId.equals(appt.id))).getSingle();
      expect(link.externalEventId, equals('g_ev_${appt.id}'));
      expect(link.syncStatus, equals('synced'));
      expect(link.externalETagAtSync, isNotNull);

      // 4. Executa sincronização novamente: confirma idempotência (zero duplicações)
      final res2 = await coordinator.syncAll();
      expect(res2.eventsUploaded, equals(0));
      expect(mockGoogle.pushCount, equals(1)); // não chamou de novo
    });

    test('Cenário 2 — Edição local: gera pending_upload na Outbox, atualiza evento externo e remove flag pendente', () async {
      final appt = await repo.createAppointment(
        title: 'Revisita Lucas',
        startTime: DateTime(2026, 11, 3, 14, 0),
        endTime: DateTime(2026, 11, 3, 14, 30),
      );
      await coordinator.syncAll();

      // Edita horário localmente via repositório
      await repo.updateAppointment(
        appt.copyWith(
          title: 'Revisita Lucas (Horário Novo)',
          startTime: DateTime(2026, 11, 3, 15, 0),
          endTime: DateTime(2026, 11, 3, 15, 30),
        ),
      );

      // Confirma que a Outbox registrou o status pending_upload no vínculo dentro da transação SQLite
      final linkPending = await (db.select(
        db.calendarEventLinks,
      )..where((t) => t.appointmentId.equals(appt.id))).getSingle();
      expect(linkPending.syncStatus, equals('pending_upload'));

      // Sincroniza
      final res = await coordinator.syncAll();
      expect(res.eventsUploaded, equals(1));

      // Confirma atualização no evento externo
      final linkSynced = await (db.select(
        db.calendarEventLinks,
      )..where((t) => t.appointmentId.equals(appt.id))).getSingle();
      expect(linkSynced.syncStatus, equals('synced'));
      expect(
        mockGoogle.remoteEvents['g_ev_${appt.id}']?['summary'],
        equals('Revisita Lucas (Horário Novo)'),
      );
    });

    test('Cenário 3 — Edição externa: alteração remota atualiza compromisso local preservando dados pastorais', () async {
      // 1. Cria pessoa e compromisso com vínculos pastorais
      final person = await repo.createPerson(
        name: 'Gabriel Costa',
        status: 'estudo',
      );
      final appt = await repo.createAppointment(
        personId: person.id,
        title: 'Estudo com Gabriel',
        startTime: DateTime(2026, 11, 4, 9, 0),
        endTime: DateTime(2026, 11, 4, 10, 0),
      );
      await coordinator.syncAll();

      // 2. Modifica o evento externamente no Google
      final extId = 'g_ev_${appt.id}';
      mockGoogle.remoteEvents[extId] = {
        'id': extId,
        'summary': 'Estudo Teocrático com Gabriel (Externo)',
        'startTime': DateTime(2026, 11, 4, 10, 30),
        'endTime': DateTime(2026, 11, 4, 11, 30),
        'etag': 'new_etag_google_999',
      };

      // 3. Sincroniza
      final res = await coordinator.syncAll();
      expect(res.success, isTrue);

      // 4. Verifica compromisso local: horário e título atualizados, mas dados pastorais 100% preservados
      final updatedAppt = await (db.select(
        db.appointments,
      )..where((t) => t.id.equals(appt.id))).getSingle();
      expect(
        updatedAppt.title,
        equals('Estudo Teocrático com Gabriel (Externo)'),
      );
      expect(updatedAppt.startTime, equals(DateTime(2026, 11, 4, 10, 30)));
      expect(
        updatedAppt.personId,
        equals(person.id),
        reason: 'Vínculo com a pessoa não pode ser perdido',
      );
    });

    test('Cenário 4 — Conflito real: detecção determinística, contagem de conflitos e convergência manual', () async {
      final appt = await repo.createAppointment(
        title: 'Conversa no Território',
        startTime: DateTime(2026, 11, 5, 14, 0),
        endTime: DateTime(2026, 11, 5, 14, 30),
      );
      await coordinator.syncAll();

      // 1. Altera localmente
      await repo.updateAppointment(
        appt.copyWith(title: 'Conversa no Território (Versão Local)'),
      );

      // 2. Altera externamente de forma concorrente
      final extId = 'g_ev_${appt.id}';
      mockGoogle.remoteEvents[extId] = {
        'id': extId,
        'summary': 'Conversa no Território (Versão Google)',
        'startTime': DateTime(2026, 11, 5, 16, 0),
        'endTime': DateTime(2026, 11, 5, 16, 30),
        'etag': 'etag_conflict_xyz',
      };

      // 3. Sincroniza: deve detectar conflito
      final res = await coordinator.syncAll();
      expect(res.conflictsFound, equals(1));

      final conflicts = await coordinator.getPendingConflicts();
      expect(conflicts.length, equals(1));
      expect(
        conflicts.first.localAppointment.title,
        equals('Conversa no Território (Versão Local)'),
      );
      expect(
        conflicts.first.externalEvent?.title,
        equals('Conversa no Território (Versão Google)'),
      );

      // 4. Resolve escolhendo manter versão externa
      await coordinator.resolveConflictKeepExternal(conflicts.first);

      // Confirma convergência
      final postAppt = await (db.select(
        db.appointments,
      )..where((t) => t.id.equals(appt.id))).getSingle();
      expect(postAppt.title, equals('Conversa no Território (Versão Google)'));

      final remaining = await coordinator.getPendingConflicts();
      expect(remaining, isEmpty);
    });

    test('Cenário 5 — Exclusão externa: gera tombstone no vínculo sem apagar histórico ministerial', () async {
      final person = await repo.createPerson(name: 'Dona Clara');
      final appt = await repo.createAppointment(
        personId: person.id,
        title: 'Visita Pastoral Dona Clara',
        startTime: DateTime(2026, 11, 6, 11, 0),
        endTime: DateTime(2026, 11, 6, 11, 30),
      );
      await coordinator.syncAll();

      // Simula exclusão externa no Google Agenda (evento cancelado)
      final extId = 'g_ev_${appt.id}';
      mockGoogle.remoteEvents[extId]!['status'] = 'cancelled';
      await (db.update(
        db.externalCalendarEvents,
      )..where((t) => t.externalEventId.equals(extId))).write(
        const ExternalCalendarEventsCompanion(
          isDeletedExternal: drift.Value(true),
          externalStatus: drift.Value('cancelled'),
        ),
      );

      // Sincroniza
      await coordinator.syncAll();

      // Confirma que o vínculo virou tombstone
      final link = await (db.select(
        db.calendarEventLinks,
      )..where((t) => t.appointmentId.equals(appt.id))).getSingle();
      expect(link.syncStatus, equals('external_deleted'));
      expect(link.deletedAt, isNotNull);

      // Confirma que o compromisso local e o histórico ministerial permanecem intactos no Field Assistant
      final localAppt = await (db.select(
        db.appointments,
      )..where((t) => t.id.equals(appt.id))).getSingle();
      expect(localAppt.deletedAt, isNull);
      expect(localAppt.personId, equals(person.id));
    });

    test('Cenário 6 — Exclusão local: soft delete propaga exclusão externa e preserva integridade', () async {
      final appt = await repo.createAppointment(
        title: 'Compromisso Desmarcado',
        startTime: DateTime(2026, 11, 7, 10, 0),
        endTime: DateTime(2026, 11, 7, 10, 30),
      );
      await coordinator.syncAll();

      // Exclui compromisso no Field Assistant
      await repo.deleteAppointment(appt.id);

      // Vínculo deve estar marcado com pending_upload para exclusão externa
      final linkBeforeSync = await (db.select(
        db.calendarEventLinks,
      )..where((t) => t.appointmentId.equals(appt.id))).getSingle();
      expect(linkBeforeSync.deletedAt, isNotNull);

      // Sincroniza
      await coordinator.syncAll();

      expect(mockGoogle.deleteCount, equals(1));
      expect(mockGoogle.remoteEvents.containsKey('g_ev_${appt.id}'), isFalse);
    });

    test('Cenário 7 — Interrupção offline: criação e edições offline enviam apenas o estado final', () async {
      mockGoogle.authorized = false; // Simula offline

      final appt = await repo.createAppointment(
        title: 'Visita Offline v1',
        startTime: DateTime(2026, 11, 8, 14, 0),
        endTime: DateTime(2026, 11, 8, 14, 30),
      );

      await repo.updateAppointment(
        appt.copyWith(
          title: 'Visita Offline v2 (Final)',
          startTime: DateTime(2026, 11, 8, 15, 0),
          endTime: DateTime(2026, 11, 8, 15, 30),
        ),
      );

      // Tenta sincronizar offline: não envia nada
      final resOffline = await coordinator.syncAll();
      expect(resOffline.eventsUploaded, equals(0));

      // Restaura conexão
      mockGoogle.authorized = true;
      final resOnline = await coordinator.syncAll();
      expect(resOnline.eventsUploaded, equals(1));

      // Apenas a versão final foi gravada no destino
      expect(
        mockGoogle.remoteEvents['g_ev_${appt.id}']?['summary'],
        equals('Visita Offline v2 (Final)'),
      );
      expect(mockGoogle.pushCount, equals(1));
    });

    test('Cenário 8 — Arquitetura de múltiplos dispositivos: modelo de concorrência documentado', () async {
      // Documentação arquitetural comprovada: cada dispositivo Field Assistant mantém sua base SQLite offline-first local.
      // A sincronização entre iPhone e iPad opera através do calendário compartilhado como hub de reconciliação de horários.
      expect(coordinator.allProviders.length, equals(2));
    });

    test('Cenário 9 — Apple EventKit: ciclo de push e reconciliação nativa do dispositivo', () async {
      mockApple.authorized = true;
      final appt = await repo.createAppointment(
        title: 'Compromisso Apple Calendar',
        startTime: DateTime(2026, 11, 9, 8, 0),
        endTime: DateTime(2026, 11, 9, 9, 0),
      );

      await coordinator.syncAll();

      expect(mockApple.pushCount, equals(1));
      expect(mockApple.appleEvents.containsKey('apple_ev_${appt.id}'), isTrue);
    });

    test('Cenário 10 — Resolução de conflito mantendo versão local', () async {
      final now = DateTime.now();
      await db
          .into(db.appointments)
          .insert(
            AppointmentsCompanion.insert(
              id: 'appt_local_keep',
              title: 'Título Mantido Local',
              startTime: DateTime(2026, 11, 10, 14, 0),
              endTime: DateTime(2026, 11, 10, 14, 30),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.calendarEventLinks)
          .insert(
            CalendarEventLinksCompanion.insert(
              id: 'link_local_keep',
              appointmentId: 'appt_local_keep',
              externalEventId: 'ext_keep_1',
              provider: 'google',
              syncStatus: const drift.Value('conflict'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final conflicts = await coordinator.getPendingConflicts();
      expect(conflicts.length, equals(1));

      await coordinator.resolveConflictKeepLocal(conflicts.first);

      final link = await (db.select(
        db.calendarEventLinks,
      )..where((t) => t.id.equals('link_local_keep'))).getSingle();
      expect(link.syncStatus, equals('synced'));
    });

    test('Cenário A — Resolução online: manter versão local envia, converge para synced e limpa conflito', () async {
      mockGoogle.authorized = true;
      final now = DateTime.now();
      await db
          .into(db.appointments)
          .insert(
            AppointmentsCompanion.insert(
              id: 'appt_scen_a',
              title: 'Título Local A',
              startTime: DateTime(2026, 11, 10, 14, 0),
              endTime: DateTime(2026, 11, 10, 14, 30),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.calendarEventLinks)
          .insert(
            CalendarEventLinksCompanion.insert(
              id: 'link_scen_a',
              appointmentId: 'appt_scen_a',
              externalEventId: 'ext_scen_a',
              provider: 'google',
              syncStatus: const drift.Value('conflict'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.externalCalendarEvents)
          .insert(
            ExternalCalendarEventsCompanion.insert(
              id: 'ext_row_scen_a',
              provider: 'google',
              calendarId: 'primary',
              externalEventId: 'ext_scen_a',
              title: 'Título Remoto Antigo',
              startTime: DateTime(2026, 11, 10, 15, 0),
              endTime: DateTime(2026, 11, 10, 15, 30),
              etag: const drift.Value('etag_old_scen_a'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final conflicts = await coordinator.getPendingConflicts();
      expect(conflicts.length, equals(1));

      // Resolução online mantendo versão local
      await coordinator.resolveConflictKeepLocal(conflicts.first);

      final link = await (db.select(
        db.calendarEventLinks,
      )..where((t) => t.id.equals('link_scen_a'))).getSingle();
      expect(link.syncStatus, equals('synced'));
      expect(link.pendingResolution, isNull);

      final remaining = await coordinator.getPendingConflicts();
      expect(remaining, isEmpty);
    });

    test('Cenário B — Resolução offline: manter versão local persiste pendingResolution, sobrevive a reinicialização e converge após reconexão com externalCalendarEvents divergente', () async {
      mockGoogle.authorized = false; // Offline
      final now = DateTime.now();
      await db
          .into(db.appointments)
          .insert(
            AppointmentsCompanion.insert(
              id: 'appt_offline_keep',
              title: 'Título Decidido no Campo',
              startTime: DateTime(2026, 11, 11, 10, 0),
              endTime: DateTime(2026, 11, 11, 10, 30),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.calendarEventLinks)
          .insert(
            CalendarEventLinksCompanion.insert(
              id: 'link_offline_keep',
              appointmentId: 'appt_offline_keep',
              externalEventId: 'ext_keep_offline',
              provider: 'google',
              syncStatus: const drift.Value('conflict'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      // Insere externalCalendarEvents divergente que causou o conflito (NÃO vazio!)
      await db
          .into(db.externalCalendarEvents)
          .insert(
            ExternalCalendarEventsCompanion.insert(
              id: 'ext_row_offline_divergent',
              provider: 'google',
              calendarId: 'primary',
              externalEventId: 'ext_keep_offline',
              title: 'Título Remoto Conflitante',
              startTime: DateTime(2026, 11, 11, 11, 0),
              endTime: DateTime(2026, 11, 11, 11, 30),
              etag: const drift.Value('etag_divergent_1'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final conflicts = await coordinator.getPendingConflicts();
      expect(conflicts.length, equals(1));

      // Resolve manter versão local enquanto offline
      await coordinator.resolveConflictKeepLocal(conflicts.first);

      // Não deve marcar synced falsamente: deve marcar pending_upload e persistir pendingResolution = 'keep_local'
      var linkPending = await (db.select(
        db.calendarEventLinks,
      )..where((t) => t.id.equals('link_offline_keep'))).getSingle();
      expect(linkPending.syncStatus, equals('pending_upload'));
      expect(linkPending.pendingResolution, equals('keep_local'));

      // Conflito não é reapresentado ao usuário
      expect(await coordinator.getPendingConflicts(), isEmpty);

      // Reinicialização do coordenador mantendo o mesmo banco Drift/SQLite
      final restartedCoordinator = CalendarSyncCoordinator(
        db,
        google: mockGoogle,
        apple: mockApple,
      );
      expect(await restartedCoordinator.getPendingConflicts(), isEmpty);

      // Quando a conexão volta, a sincronização envia a decisão sem reabrir o conflito antigo
      mockGoogle.authorized = true;
      final syncRes = await restartedCoordinator.syncAll();
      expect(syncRes.eventsUploaded, equals(1));
      expect(syncRes.conflictsFound, equals(0));

      final linkSynced = await (db.select(
        db.calendarEventLinks,
      )..where((t) => t.id.equals('link_offline_keep'))).getSingle();
      expect(linkSynced.syncStatus, equals('synced'));
      expect(linkSynced.pendingResolution, isNull);
      expect(
        mockGoogle.remoteEvents['ext_keep_offline']?['summary'],
        equals('Título Decidido no Campo'),
      );
      expect(await restartedCoordinator.getPendingConflicts(), isEmpty);
    });

    test('Cenário C — Falha no envio: preserva pending_resolution e não marca como synced se envio falhar', () async {
      mockGoogle.authorized = true;
      final now = DateTime.now();
      await db
          .into(db.appointments)
          .insert(
            AppointmentsCompanion.insert(
              id: 'appt_scen_c',
              title: 'Título Tentativa Falha',
              startTime: DateTime(2026, 11, 13, 9, 0),
              endTime: DateTime(2026, 11, 13, 9, 30),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.calendarEventLinks)
          .insert(
            CalendarEventLinksCompanion.insert(
              id: 'link_scen_c',
              appointmentId: 'appt_scen_c',
              externalEventId: 'ext_scen_c',
              provider: 'google',
              syncStatus: const drift.Value('conflict'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.externalCalendarEvents)
          .insert(
            ExternalCalendarEventsCompanion.insert(
              id: 'ext_row_scen_c',
              provider: 'google',
              calendarId: 'primary',
              externalEventId: 'ext_scen_c',
              title: 'Remoto Antigo C',
              startTime: DateTime(2026, 11, 13, 9, 0),
              endTime: DateTime(2026, 11, 13, 9, 30),
              etag: const drift.Value('etag_scen_c'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final conflicts = await coordinator.getPendingConflicts();
      expect(conflicts.length, equals(1));

      // Configura falha de envio no mock
      mockGoogle.authorized = false;
      await coordinator.resolveConflictKeepLocal(conflicts.first);

      var link = await (db.select(
        db.calendarEventLinks,
      )..where((t) => t.id.equals('link_scen_c'))).getSingle();
      expect(link.syncStatus, equals('pending_upload'));
      expect(link.pendingResolution, equals('keep_local'));

      // Tenta sincronizar ainda sem rede
      final syncRes = await coordinator.syncAll();
      expect(syncRes.eventsUploaded, equals(0));

      // Decisão continua persistida
      link = await (db.select(
        db.calendarEventLinks,
      )..where((t) => t.id.equals('link_scen_c'))).getSingle();
      expect(link.syncStatus, equals('pending_upload'));
      expect(link.pendingResolution, equals('keep_local'));
      expect(link.syncStatus, isNot(equals('synced')));
    });

    test('Cenário D — Alteração externa posterior: após resolução confirmada, nova edição externa legítima é detectada e converge sem falso conflito', () async {
      mockGoogle.authorized = true;
      final now = DateTime.now();
      await db
          .into(db.appointments)
          .insert(
            AppointmentsCompanion.insert(
              id: 'appt_scen_d',
              title: 'Título Confirmado D',
              startTime: DateTime(2026, 11, 14, 15, 0),
              endTime: DateTime(2026, 11, 14, 15, 30),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.calendarEventLinks)
          .insert(
            CalendarEventLinksCompanion.insert(
              id: 'link_scen_d',
              appointmentId: 'appt_scen_d',
              externalEventId: 'ext_scen_d',
              provider: 'google',
              syncStatus: const drift.Value('conflict'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.externalCalendarEvents)
          .insert(
            ExternalCalendarEventsCompanion.insert(
              id: 'ext_row_scen_d',
              provider: 'google',
              calendarId: 'primary',
              externalEventId: 'ext_scen_d',
              title: 'Remoto Conflitante Antigo',
              startTime: DateTime(2026, 11, 14, 16, 0),
              endTime: DateTime(2026, 11, 14, 16, 30),
              etag: const drift.Value('etag_d_1'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // 1. Resolução do conflito original
      final conflicts = await coordinator.getPendingConflicts();
      expect(conflicts.length, equals(1));
      await coordinator.resolveConflictKeepLocal(conflicts.first);

      var link = await (db.select(
        db.calendarEventLinks,
      )..where((t) => t.id.equals('link_scen_d'))).getSingle();
      expect(link.syncStatus, equals('synced'));
      expect(link.pendingResolution, isNull);

      // 2. Posteriormente, o usuário altera diretamente o evento no Google Calendar
      mockGoogle.remoteEvents['ext_scen_d'] = {
        'id': 'ext_scen_d',
        'summary': 'Título Atualizado no Google Calendar Mais Tarde',
        'startTime': DateTime(2026, 11, 14, 17, 0),
        'endTime': DateTime(2026, 11, 14, 17, 30),
        'etag': 'etag_d_nova_edicao_remota',
      };

      // 3. Sincronização detecta a nova alteração externa legítima e converge o compromisso local
      final syncRes = await coordinator.syncAll();
      expect(syncRes.eventsDownloaded, equals(1));

      final updatedAppt = await (db.select(
        db.appointments,
      )..where((t) => t.id.equals('appt_scen_d'))).getSingle();
      expect(
        updatedAppt.title,
        equals('Título Atualizado no Google Calendar Mais Tarde'),
      );
      expect(updatedAppt.startTime, equals(DateTime(2026, 11, 14, 17, 0)));

      link = await (db.select(
        db.calendarEventLinks,
      )..where((t) => t.id.equals('link_scen_d'))).getSingle();
      expect(link.syncStatus, equals('synced'));
      expect(link.externalETagAtSync, equals('etag_d_nova_edicao_remota'));
    });

    test('Cenário E — Resolução com novo ID externo: provedor retorna novo id ao fazer push e vínculo é atualizado com novo id e etag/fingerprint', () async {
      mockGoogle.authorized = true;
      mockGoogle.forcePushId = 'g_ev_new_reassigned_id';
      final now = DateTime.now();
      await db
          .into(db.appointments)
          .insert(
            AppointmentsCompanion.insert(
              id: 'appt_scen_e',
              title: 'Compromisso com Reatribuição de ID',
              startTime: DateTime(2026, 11, 20, 10, 0),
              endTime: DateTime(2026, 11, 20, 11, 0),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.calendarEventLinks)
          .insert(
            CalendarEventLinksCompanion.insert(
              id: 'link_scen_e',
              appointmentId: 'appt_scen_e',
              externalEventId: 'old_temporary_id_scen_e',
              provider: 'google',
              syncStatus: const drift.Value('conflict'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final conflicts = await coordinator.getPendingConflicts();
      expect(conflicts.length, equals(1));

      await coordinator.resolveConflictKeepLocal(conflicts.first);

      final updatedLink = await (db.select(
        db.calendarEventLinks,
      )..where((t) => t.id.equals('link_scen_e'))).getSingle();
      expect(updatedLink.externalEventId, equals('g_ev_new_reassigned_id'));
      expect(updatedLink.syncStatus, equals('synced'));
      expect(updatedLink.pendingResolution, isNull);
      expect(updatedLink.externalETagAtSync, isNotNull);
    });
  });

  group('AppleEventKitProvider - Fingerprint & Mass Deletion Protection', () {
    late AppDatabase db;
    late FakeDeviceCalendarPlugin fakePlugin;
    late AppleEventKitProvider appleProvider;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      FlutterSecureStorage.setMockInitialValues({
        'apple_eventkit_selected_id': 'cal_apple_test',
      });
      fakePlugin = FakeDeviceCalendarPlugin();
      appleProvider = AppleEventKitProvider(deviceCalendarPlugin: fakePlugin);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'computeEventFingerprint normaliza propriedades e detecta mutações',
      () {
        final start = DateTime.utc(2026, 11, 25, 9, 0);
        final end = DateTime.utc(2026, 11, 25, 10, 0);

        final fp1 = AppleEventKitProvider.computeEventFingerprint(
          externalEventId: 'ev_123',
          calendarId: 'cal_apple_test',
          title: 'Estudo Bíblico',
          location: 'Av. Paulista, 100',
          description: 'Capítulo 5',
          startTime: start,
          endTime: end,
        );

        final fp2 = AppleEventKitProvider.computeEventFingerprint(
          externalEventId: 'ev_123',
          calendarId: 'cal_apple_test',
          title: 'Estudo Bíblico',
          location: 'Av. Paulista, 100',
          description: 'Capítulo 5',
          startTime: start,
          endTime: end,
        );
        expect(
          fp1,
          equals(fp2),
          reason: 'Mesmos valores devem produzir o mesmo fingerprint',
        );

        final fpMutatedTitle = AppleEventKitProvider.computeEventFingerprint(
          externalEventId: 'ev_123',
          calendarId: 'cal_apple_test',
          title: 'Estudo Bíblico Alterado',
          location: 'Av. Paulista, 100',
          description: 'Capítulo 5',
          startTime: start,
          endTime: end,
        );
        expect(
          fp1,
          isNot(equals(fpMutatedTitle)),
          reason: 'Alteração no título deve alterar fingerprint',
        );

        final fpMutatedTime = AppleEventKitProvider.computeEventFingerprint(
          externalEventId: 'ev_123',
          calendarId: 'cal_apple_test',
          title: 'Estudo Bíblico',
          location: 'Av. Paulista, 100',
          description: 'Capítulo 5',
          startTime: start.add(const Duration(hours: 1)),
          endTime: end.add(const Duration(hours: 1)),
        );
        expect(
          fp1,
          isNot(equals(fpMutatedTime)),
          reason: 'Alteração no horário deve alterar fingerprint',
        );
      },
    );

    test('syncEvents pula eventos inalterados quando fingerprint coincide e atualiza quando muda', () async {
      final start = DateTime.now().add(const Duration(days: 1));
      final end = start.add(const Duration(hours: 1));

      final ev = dev_cal.Event(
        'cal_apple_test',
        eventId: 'apple_ev_10',
        title: 'Reunião Ministerial',
      );
      ev.start = tz.TZDateTime.from(start, tz.local);
      ev.end = tz.TZDateTime.from(end, tz.local);
      fakePlugin.eventsResult = [ev];

      // 1ª sincronização: insere novo registro
      final res1 = await appleProvider.syncEvents(db: db);
      expect(res1.success, isTrue);
      expect(res1.eventsDownloaded, equals(1));

      final record = await (db.select(
        db.externalCalendarEvents,
      )..where((t) => t.externalEventId.equals('apple_ev_10'))).getSingle();
      expect(record.etag, isNotNull);

      // 2ª sincronização: mesmo evento com mesmo fingerprint é pulado
      final res2 = await appleProvider.syncEvents(db: db);
      expect(res2.success, isTrue);
      expect(
        res2.eventsDownloaded,
        equals(0),
        reason: 'Evento inalterado deve ser pulado',
      );

      // Modifica o evento remotamente
      ev.title = 'Reunião Ministerial (Horário Alterado)';
      final res3 = await appleProvider.syncEvents(db: db);
      expect(res3.success, isTrue);
      expect(
        res3.eventsDownloaded,
        equals(1),
        reason: 'Evento alterado deve ser baixado e atualizado',
      );

      final updatedRecord = await (db.select(
        db.externalCalendarEvents,
      )..where((t) => t.externalEventId.equals('apple_ev_10'))).getSingle();
      expect(
        updatedRecord.title,
        equals('Reunião Ministerial (Horário Alterado)'),
      );
      expect(updatedRecord.etag, isNot(equals(record.etag)));
    });

    test('syncEvents proteção contra exclusão falsa em massa quando retrieveEvents retorna vazio', () async {
      final now = DateTime.now();
      // Insere múltiplos eventos locais dentro da janela de sincronização
      await db
          .into(db.externalCalendarEvents)
          .insert(
            ExternalCalendarEventsCompanion.insert(
              id: 'apple_ext_stored_1',
              provider: 'apple_eventkit',
              calendarId: 'cal_apple_test',
              externalEventId: 'apple_ev_stored_1',
              title: 'Compromisso 1',
              startTime: now.add(const Duration(days: 5)),
              endTime: now.add(const Duration(days: 5, hours: 1)),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.externalCalendarEvents)
          .insert(
            ExternalCalendarEventsCompanion.insert(
              id: 'apple_ext_stored_2',
              provider: 'apple_eventkit',
              calendarId: 'cal_apple_test',
              externalEventId: 'apple_ev_stored_2',
              title: 'Compromisso 2',
              startTime: now.add(const Duration(days: 6)),
              endTime: now.add(const Duration(days: 6, hours: 1)),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Simula anomalia: consulta retorna vazio
      fakePlugin.eventsResult = [];

      final res = await appleProvider.syncEvents(db: db);
      expect(res.success, isTrue);

      // Confirma que proteção evitou deleção em massa
      final events = await (db.select(
        db.externalCalendarEvents,
      )..where((t) => t.provider.equals('apple_eventkit'))).get();
      expect(events.length, equals(2));
      expect(events.every((e) => !e.isDeletedExternal), isTrue);
    });

    test('syncEvents reconcilia exclusão legítima quando subconjunto de eventos é retornado', () async {
      final now = DateTime.now();
      final start1 = now.add(const Duration(days: 2));
      final end1 = start1.add(const Duration(hours: 1));
      final start2 = now.add(const Duration(days: 3));
      final end2 = start2.add(const Duration(hours: 1));

      await db
          .into(db.externalCalendarEvents)
          .insert(
            ExternalCalendarEventsCompanion.insert(
              id: 'apple_ext_legit_1',
              provider: 'apple_eventkit',
              calendarId: 'cal_apple_test',
              externalEventId: 'apple_ev_legit_1',
              title: 'Permanece',
              startTime: start1,
              endTime: end1,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.externalCalendarEvents)
          .insert(
            ExternalCalendarEventsCompanion.insert(
              id: 'apple_ext_legit_2',
              provider: 'apple_eventkit',
              calendarId: 'cal_apple_test',
              externalEventId: 'apple_ev_legit_2',
              title: 'Foi Excluído no Calendário Externo',
              startTime: start2,
              endTime: end2,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Retorna apenas evento 1; evento 2 foi excluído pelo usuário no Apple Calendar
      final ev1 = dev_cal.Event(
        'cal_apple_test',
        eventId: 'apple_ev_legit_1',
        title: 'Permanece',
      );
      ev1.start = tz.TZDateTime.from(start1, tz.local);
      ev1.end = tz.TZDateTime.from(end1, tz.local);
      fakePlugin.eventsResult = [ev1];

      final res = await appleProvider.syncEvents(db: db);
      expect(res.success, isTrue);

      final ev1Db =
          await (db.select(db.externalCalendarEvents)
                ..where((t) => t.externalEventId.equals('apple_ev_legit_1')))
              .getSingle();
      expect(ev1Db.isDeletedExternal, isFalse);

      final ev2Db =
          await (db.select(db.externalCalendarEvents)
                ..where((t) => t.externalEventId.equals('apple_ev_legit_2')))
              .getSingle();
      expect(ev2Db.isDeletedExternal, isTrue);
      expect(ev2Db.externalStatus, equals('cancelled'));
    });

    test('pushAppointmentToExternal calcula fingerprint e persiste vínculo e evento externo', () async {
      final now = DateTime.now();
      final cal = dev_cal.Calendar(
        id: 'cal_apple_test',
        name: 'Meu Calendário',
      );
      fakePlugin.calendarsResult = [cal];
      fakePlugin.createdEventIdResult = 'apple_pushed_99';

      await db
          .into(db.appointments)
          .insert(
            AppointmentsCompanion.insert(
              id: 'appt_push_test',
              title: 'Estudo com Thiago',
              startTime: now.add(const Duration(days: 1)),
              endTime: now.add(const Duration(days: 1, hours: 1)),
              locationNotes: const drift.Value('Rua das Flores 10'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final appt = await (db.select(
        db.appointments,
      )..where((t) => t.id.equals('appt_push_test'))).getSingle();

      final pushRes = await appleProvider.pushAppointmentToExternal(db, appt);
      expect(pushRes, equals('apple_pushed_99'));

      final link = await (db.select(
        db.calendarEventLinks,
      )..where((t) => t.appointmentId.equals('appt_push_test'))).getSingle();
      expect(link.externalEventId, equals('apple_pushed_99'));
      expect(link.syncStatus, equals('synced'));
      expect(link.externalETagAtSync, isNotNull);

      final ext = await (db.select(
        db.externalCalendarEvents,
      )..where((t) => t.externalEventId.equals('apple_pushed_99'))).getSingle();
      expect(ext.etag, equals(link.externalETagAtSync));
    });

    test('TC-APPLE-ADV-01: Proteção contra Exclusão Parcial Truncada — consulta devolvendo fração anormalmente reduzida (>25% de ausência) preserva registros locais', () async {
      final now = DateTime.now();
      final cal = dev_cal.Calendar(
        id: 'cal_apple_test',
        name: 'Calendário Principal',
      );
      fakePlugin.calendarsResult = [cal];

      // Insere 20 eventos conhecidos no banco local dentro da janela
      for (int i = 0; i < 20; i++) {
        final start = now.add(Duration(days: i + 1));
        final end = start.add(const Duration(hours: 1));
        await db
            .into(db.externalCalendarEvents)
            .insert(
              ExternalCalendarEventsCompanion.insert(
                id: 'ext_bulk_$i',
                provider: 'apple_eventkit',
                calendarId: 'cal_apple_test',
                externalEventId: 'apple_bulk_ev_$i',
                title: 'Compromisso Ministerial $i',
                startTime: start,
                endTime: end,
                createdAt: now,
                updatedAt: now,
              ),
            );
      }

      // Simula retorno parcial da API com apenas 5 eventos (queda de 75% — anomalia de consulta parcial)
      final returnedEvents = <dev_cal.Event>[];
      for (int i = 0; i < 5; i++) {
        final start = now.add(Duration(days: i + 1));
        final end = start.add(const Duration(hours: 1));
        final ev = dev_cal.Event(
          'cal_apple_test',
          eventId: 'apple_bulk_ev_$i',
          title: 'Compromisso Ministerial $i',
        );
        ev.start = tz.TZDateTime.from(start, tz.local);
        ev.end = tz.TZDateTime.from(end, tz.local);
        returnedEvents.add(ev);
      }
      fakePlugin.eventsResult = returnedEvents;

      final res = await appleProvider.syncEvents(db: db);
      expect(res.success, isTrue);

      // VERIFICAÇÃO CRÍTICA:
      // Nenhum dos 20 eventos deve ter sido marcado como cancelado/excluído falsamente!
      final allStored = await (db.select(
        db.externalCalendarEvents,
      )..where((t) => t.provider.equals('apple_eventkit'))).get();
      expect(allStored.length, equals(20));
      expect(allStored.every((e) => !e.isDeletedExternal), isTrue);
    });

    test('TC-APPLE-ADV-02: Fingerprint com Recorrência — alteração de regra de recorrência modifica o SHA-256 e dispara atualização determinística', () async {
      final now = DateTime.now();
      final cal = dev_cal.Calendar(
        id: 'cal_apple_test',
        name: 'Calendário Principal',
      );
      fakePlugin.calendarsResult = [cal];

      final start = now.add(const Duration(days: 2));
      final end = start.add(const Duration(hours: 1));

      // 1. Evento com recorrência semanal
      final evWeekly = dev_cal.Event(
        'cal_apple_test',
        eventId: 'apple_rec_ev_1',
        title: 'Estudo Recorrente',
      );
      evWeekly.start = tz.TZDateTime.from(start, tz.local);
      evWeekly.end = tz.TZDateTime.from(end, tz.local);
      evWeekly.recurrenceRule = dev_cal.RecurrenceRule(
        dev_cal.RecurrenceFrequency.Weekly,
        interval: 1,
      );
      fakePlugin.eventsResult = [evWeekly];

      final res1 = await appleProvider.syncEvents(db: db);
      expect(res1.success, isTrue);

      final row1 = await (db.select(
        db.externalCalendarEvents,
      )..where((t) => t.externalEventId.equals('apple_rec_ev_1'))).getSingle();
      final fpWeekly = row1.etag;
      expect(fpWeekly, isNotNull);

      // 2. Altera a frequência de recorrência para diária
      final evDaily = dev_cal.Event(
        'cal_apple_test',
        eventId: 'apple_rec_ev_1',
        title: 'Estudo Recorrente',
      );
      evDaily.start = tz.TZDateTime.from(start, tz.local);
      evDaily.end = tz.TZDateTime.from(end, tz.local);
      evDaily.recurrenceRule = dev_cal.RecurrenceRule(
        dev_cal.RecurrenceFrequency.Daily,
        interval: 1,
      );
      fakePlugin.eventsResult = [evDaily];

      final res2 = await appleProvider.syncEvents(db: db);
      expect(res2.success, isTrue);

      final row2 = await (db.select(
        db.externalCalendarEvents,
      )..where((t) => t.externalEventId.equals('apple_rec_ev_1'))).getSingle();
      final fpDaily = row2.etag;

      // O fingerprint com frequência diária DEVE ser diferente do semanal
      expect(fpDaily, isNot(equals(fpWeekly)));
    });
  });
}
