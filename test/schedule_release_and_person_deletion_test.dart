import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/appointments/availability_engine.dart';
import 'package:ministerio_pessoal/appointments/calendar_provider.dart';
import 'package:ministerio_pessoal/appointments/calendar_sync_coordinator.dart';
import 'package:ministerio_pessoal/appointments/google_calendar_provider.dart';
import 'package:ministerio_pessoal/appointments/apple_eventkit_provider.dart';
import 'package:ministerio_pessoal/appointments/schedule_release_coordinator.dart';
import 'package:ministerio_pessoal/contacts/phone_contacts_manager.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/notifications/local_reminder_service.dart';

/// Provedor mock de Google Calendar para simulação de cenários de sucesso, erro, offline e readonly
class MockGoogleCalendarProvider extends GoogleCalendarProvider {
  bool isAuthorizedResult;
  bool deleteExternalEventResult;
  bool throwOnDelete;
  final Set<String> deletedEventIds = {};
  final Set<String> mockReadOnlyCalendarIds = {};

  MockGoogleCalendarProvider({
    this.isAuthorizedResult = true,
    this.deleteExternalEventResult = true,
    this.throwOnDelete = false,
  });

  @override
  bool get isSupportedOnCurrentPlatform => true;

  @override
  Future<bool> isAuthorized() async => isAuthorizedResult;

  @override
  Future<bool> requestAuthorization() async => true;

  @override
  Future<String?> getConnectedAccountName() async => 'mock@gmail.com';

  @override
  Future<List<ExternalCalendarItem>> getAvailableCalendars() async => [
    ExternalCalendarItem(
      id: 'mock_cal_1',
      name: 'Mock Calendar',
      isPrimary: true,
      isReadOnly: mockReadOnlyCalendarIds.contains('mock_cal_1'),
    ),
  ];

  @override
  Future<String?> getSelectedCalendarId() async => 'mock_cal_1';

  @override
  Future<void> setSelectedCalendarId(String calendarId) async {}

  @override
  Future<CalendarSyncResult> syncEvents({
    required AppDatabase db,
    bool fullSync = false,
  }) async {
    return CalendarSyncResult(
      success: true,
      eventsDownloaded: 0,
      eventsUploaded: 0,
    );
  }

  @override
  Future<String?> pushAppointmentToExternal(
    AppDatabase db,
    AppointmentEntry appointment,
  ) async => 'ext_${appointment.id}';

  @override
  Future<bool> deleteExternalEvent(
    AppDatabase db,
    String externalEventId,
  ) async {
    if (mockReadOnlyCalendarIds.contains('mock_cal_1')) {
      return false; // Modo somente leitura
    }
    if (throwOnDelete) {
      throw Exception('Simulação de falha de conexão de rede');
    }
    if (!deleteExternalEventResult) {
      return false;
    }
    deletedEventIds.add(externalEventId);
    return true;
  }

  @override
  Future<void> disconnect() async {
    isAuthorizedResult = false;
  }
}

/// Provedor mock de Apple EventKit para simulação
class MockAppleCalendarProvider extends AppleEventKitProvider {
  bool isAuthorizedResult;
  bool deleteExternalEventResult;
  bool throwOnDelete;
  final Set<String> deletedEventIds = {};

  MockAppleCalendarProvider({
    this.isAuthorizedResult = true,
    this.deleteExternalEventResult = true,
    this.throwOnDelete = false,
  });

  @override
  bool get isSupportedOnCurrentPlatform => true;

  @override
  Future<bool> isAuthorized() async => isAuthorizedResult;

  @override
  Future<bool> requestAuthorization() async => true;

  @override
  Future<String?> getConnectedAccountName() async => 'Mock Apple Account';

  @override
  Future<List<ExternalCalendarItem>> getAvailableCalendars() async => [];

  @override
  Future<String?> getSelectedCalendarId() async => 'apple_cal_1';

  @override
  Future<void> setSelectedCalendarId(String calendarId) async {}

  @override
  Future<CalendarSyncResult> syncEvents({
    required AppDatabase db,
    bool fullSync = false,
  }) async =>
      CalendarSyncResult(success: true, eventsDownloaded: 0, eventsUploaded: 0);

  @override
  Future<String?> pushAppointmentToExternal(
    AppDatabase db,
    AppointmentEntry appointment,
  ) async => 'ext_apple_${appointment.id}';

  @override
  Future<bool> deleteExternalEvent(
    AppDatabase db,
    String externalEventId,
  ) async {
    if (throwOnDelete) {
      throw Exception('Simulação de falha Apple EventKit');
    }
    if (!deleteExternalEventResult) {
      return false;
    }
    deletedEventIds.add(externalEventId);
    return true;
  }

  @override
  Future<void> disconnect() async {
    isAuthorizedResult = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late AppRepository repo;
  late LocalReminderService reminderService;
  late MockGoogleCalendarProvider mockGoogleProvider;
  late MockAppleCalendarProvider mockAppleProvider;
  late CalendarSyncCoordinator calendarCoordinator;
  late ScheduleReleaseCoordinator releaseCoordinator;
  late PhoneContactsManager phoneManager;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = AppRepository(db);
    reminderService = LocalReminderService(db: db);
    mockGoogleProvider = MockGoogleCalendarProvider();
    mockAppleProvider = MockAppleCalendarProvider();
    calendarCoordinator = CalendarSyncCoordinator(
      db,
      google: mockGoogleProvider,
      apple: mockAppleProvider,
    );
    releaseCoordinator = ScheduleReleaseCoordinator(
      db: db,
      repo: repo,
      reminderService: reminderService,
      calendarCoordinator: calendarCoordinator,
    );
    phoneManager = PhoneContactsManager(db);
  });

  tearDown(() async {
    reminderService.dispose();
    await db.close();
  });

  group('OBJETIVO 1: Exclusão Definitiva de Pessoa e Relacionamentos', () {
    test('Cancelar confirmação não altera nenhum dado', () async {
      final person = await repo.createPerson(name: 'Pedro Alvares');
      final futureStart = DateTime.now().add(const Duration(days: 2));
      final appt = await repo.createAppointment(
        personId: person.id,
        title: 'Revisita Pedro',
        startTime: futureStart,
        endTime: futureStart.add(const Duration(minutes: 30)),
      );

      // Simulação: usuário abre resumo mas cancela sem chamar delete
      final summary = await releaseCoordinator.getPersonRelationshipsSummary(
        person.id,
      );
      expect(summary.personName, equals('Pedro Alvares'));
      expect(summary.futureAppointments.length, equals(1));

      // Verificação pós-cancelamento: dados inalterados
      final pCheck = await repo.getPersonById(person.id);
      expect(pCheck, isNotNull);
      expect(pCheck!.deletedAt, isNull);

      final apptCheck = await (db.select(
        db.appointments,
      )..where((t) => t.id.equals(appt.id))).getSingle();
      expect(apptCheck.status, equals('planejado'));
      expect(apptCheck.deletedAt, isNull);
    });

    test('Confirmar exclusão de pessoa remove dependentes, desvincula tarefas/conhecimento e libera horários', () async {
      final person = await repo.createPerson(name: 'Ana Carolina');
      final now = DateTime.now();

      // 1. Cria visita passada
      await repo.createVisit(
        personId: person.id,
        dateTime: now.subtract(const Duration(days: 10)),
        contactType: 'conversa_inicial',
        result: 'interessada',
      );

      // 2. Cria compromisso futuro
      final futureStart = now.add(const Duration(days: 3, hours: 2));
      final futureAppt = await repo.createAppointment(
        personId: person.id,
        title: 'Revisita Bíblica - Ana',
        startTime: futureStart,
        endTime: futureStart.add(const Duration(minutes: 40)),
      );

      // 3. Cria lembrete local para o compromisso
      await reminderService.scheduleReminder(
        ScheduledReminder(
          id: 'appt_${futureAppt.id}',
          title: futureAppt.title,
          description: 'Lembrete de revisita',
          scheduledFor: futureAppt.startTime,
          type: ReminderType.appointment,
          relatedEntityId: futureAppt.id,
        ),
      );

      // 4. Cria tarefa e nota associadas à pessoa
      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              id: 'task_1',
              title: 'Levar publicação para Ana',
              personId: drift.Value(person.id),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db
          .into(db.knowledgeNotes)
          .insert(
            KnowledgeNotesCompanion.insert(
              id: 'note_1',
              title: 'Dúvidas levantadas por Ana',
              content: 'Pergunta sobre profecias',
              personId: drift.Value(person.id),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Verifica colisão ANTES da exclusão (horário deve estar ocupado)
      final hasCollisionBefore = AvailabilityEngine.hasCollision(
        start: futureStart,
        end: futureStart.add(const Duration(minutes: 40)),
        existingAppointments: await repo.getAllAppointments(),
      );
      expect(hasCollisionBefore, isTrue);

      // Executa exclusão definitiva via coordinator
      final result = await releaseCoordinator
          .permanentlyDeletePersonWithScheduleRelease(personId: person.id);

      expect(result.success, isTrue);
      expect(result.releasedAppointmentsCount, equals(1));

      // Verificação 1: Pessoa foi removida do banco
      final pCheck = await repo.getPersonById(person.id);
      expect(pCheck, isNull);

      // Verificação 2: Visitas da pessoa foram removidas
      final visits = await repo.getVisitsForPerson(person.id);
      expect(visits, isEmpty);

      // Verificação 3: Compromisso futuro foi cancelado/deletado
      final apptCheck = await (db.select(
        db.appointments,
      )..where((t) => t.id.equals(futureAppt.id))).getSingleOrNull();
      expect(apptCheck == null || apptCheck.deletedAt != null, isTrue);

      // Verificação 4: Lembrete local foi cancelado
      final reminders = await reminderService.getAllReminders();
      expect(reminders.any((r) => r.relatedEntityId == futureAppt.id), isFalse);

      // Verificação 5: Tarefa e nota foram preservadas, com personId desvinculado (null)
      final task = await (db.select(
        db.tasks,
      )..where((t) => t.id.equals('task_1'))).getSingle();
      expect(task.personId, isNull);
      expect(task.title, equals('Levar publicação para Ana'));

      final note = await (db.select(
        db.knowledgeNotes,
      )..where((t) => t.id.equals('note_1'))).getSingle();
      expect(note.personId, isNull);
      expect(note.content, equals('Pergunta sobre profecias'));

      // Verificação 6: Disponibilidade agora indica o horário como LIVRE
      final hasCollisionAfter = AvailabilityEngine.hasCollision(
        start: futureStart,
        end: futureStart.add(const Duration(minutes: 40)),
        existingAppointments: await repo.getAllAppointments(),
      );
      expect(hasCollisionAfter, isFalse);

      final availResult = AvailabilityEngine.checkAvailability(
        startTime: futureStart,
        durationMinutes: 40,
        existingAppointments: await repo.getAllAppointments(),
      );
      expect(availResult.isAvailable, isTrue);
    });

    test('Exclusão de contato telefônico avulso e contato promovido não apagam outro registro indevidamente', () async {
      // 1. Cria contato telefônico
      await db
          .into(db.phoneContacts)
          .insert(
            PhoneContactsCompanion.insert(
              id: 'pc_1',
              name: 'Marcos Telefone',
              phone: '92981112233',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      // 2. Promove contato telefônico para Pessoa
      final contactItem = (await phoneManager.getAllPhoneContacts()).first;
      final person = await phoneManager.convertToPerson(
        contact: contactItem,
        repo: repo,
        address: 'Rua das Flores 123',
      );

      expect(person.name, equals('Marcos Telefone'));

      // Verifica vínculo no contato telefônico
      final pcLinked = await (db.select(
        db.phoneContacts,
      )..where((t) => t.id.equals('pc_1'))).getSingle();
      expect(pcLinked.convertedPersonId, equals(person.id));

      // CENÁRIO A: Excluir definitivamente o contato telefônico NÃO deve apagar a Pessoa
      await phoneManager.permanentlyDeletePhoneContact('pc_1');

      final pcCheck = await (db.select(
        db.phoneContacts,
      )..where((t) => t.id.equals('pc_1'))).getSingleOrNull();
      expect(pcCheck, isNull); // Contato telefônico excluído

      final personStillActive = await repo.getPersonById(person.id);
      expect(personStillActive, isNotNull); // Pessoa permanece intacta!
      expect(personStillActive!.deletedAt, isNull);

      // CENÁRIO B: Recria contato e promove de novo; agora exclui a Pessoa definitivamente.
      // O contato telefônico deve permanecer vivo, apenas desvinculado!
      await db
          .into(db.phoneContacts)
          .insert(
            PhoneContactsCompanion.insert(
              id: 'pc_2',
              name: 'Lucia Telefone',
              phone: '92984445566',
              convertedPersonId: drift.Value(person.id),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      await releaseCoordinator.permanentlyDeletePersonWithScheduleRelease(
        personId: person.id,
      );

      final personDeleted = await repo.getPersonById(person.id);
      expect(personDeleted, isNull); // Pessoa foi excluída

      final pc2 = await (db.select(
        db.phoneContacts,
      )..where((t) => t.id.equals('pc_2'))).getSingle();
      expect(pc2, isNotNull); // Contato telefônico PRESERVADO!
      expect(pc2.convertedPersonId, isNull); // Desvinculado com segurança
    });

    test('Lixeira e exclusão lógica de contatos telefônicos com restauração e exclusão permanente', () async {
      await db
          .into(db.phoneContacts)
          .insert(
            PhoneContactsCompanion.insert(
              id: 'pc_trash_1',
              name: 'Contato Lixeira Teste',
              phone: '92999998888',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      // 1. Soft-delete para lixeira
      await phoneManager.deletePhoneContact('pc_trash_1');

      // 2. Deve aparecer em getDeletedItems
      final deletedItems = await repo.getDeletedItems();
      final inTrash = deletedItems.firstWhere(
        (i) => i['id'] == 'pc_trash_1' && i['type'] == 'phone_contacts',
      );
      expect(inTrash['title'], equals('Contato Lixeira Teste'));

      // 3. Restaura da lixeira
      await repo.restoreDeletedItem('phone_contacts', 'pc_trash_1');
      final activeList = await phoneManager.getAllPhoneContacts();
      expect(activeList.any((c) => c.id == 'pc_trash_1'), isTrue);

      // 4. Soft-delete novamente e exclusão definitiva na lixeira
      await phoneManager.deletePhoneContact('pc_trash_1');
      await repo.permanentlyDeleteItem('phone_contacts', 'pc_trash_1');

      final deletedAfter = await repo.getDeletedItems();
      expect(deletedAfter.any((i) => i['id'] == 'pc_trash_1'), isFalse);
    });
  });

  group('OBJETIVO 2: Liberar a Agenda ao Encerrar Estudo ou Revisita', () {
    test('Encerrar estudo remove compromissos futuros vinculados, preserva passados e libera horários', () async {
      final person = await repo.createPerson(name: 'Lucas Estudante');
      final otherPerson = await repo.createPerson(name: 'Outro Contato');
      final now = DateTime.now();

      final study = await repo.createStudy(
        title: 'Estudo LFF - Lucas',
        publicationId: 'lff-book',
        participantPersonIds: [person.id],
      );

      // 1. Compromisso passado (preservado)
      final pastStart = now.subtract(const Duration(days: 7));
      final pastAppt = await repo.createAppointment(
        personId: person.id,
        studyId: study.id,
        title: 'Sessão 1 Estudo',
        startTime: pastStart,
        endTime: pastStart.add(const Duration(minutes: 45)),
        status: 'realizado',
      );

      // 2. Compromisso futuro vinculado (deve ser liberado)
      final futureStart = now.add(const Duration(days: 4, hours: 3));
      final futureAppt = await repo.createAppointment(
        personId: person.id,
        studyId: study.id,
        title: 'Sessão 2 Estudo (Futura)',
        startTime: futureStart,
        endTime: futureStart.add(const Duration(minutes: 45)),
      );

      // 3. Compromisso de outra pessoa no mesmo dia futuro (deve permanecer intacto)
      final otherAppt = await repo.createAppointment(
        personId: otherPerson.id,
        title: 'Visita Outro Contato',
        startTime: futureStart.add(const Duration(hours: 2)),
        endTime: futureStart.add(const Duration(hours: 2, minutes: 30)),
      );

      // 4. Lembrete local para o compromisso futuro do estudo
      await reminderService.scheduleReminder(
        ScheduledReminder(
          id: 'appt_${futureAppt.id}',
          title: futureAppt.title,
          description: 'Lembrete de estudo bíblico',
          scheduledFor: futureAppt.startTime,
          type: ReminderType.bibleStudy,
          relatedEntityId: futureAppt.id,
        ),
      );

      // Verifica bloqueio de horário antes
      expect(
        AvailabilityEngine.hasCollision(
          start: futureStart,
          end: futureStart.add(const Duration(minutes: 45)),
          existingAppointments: await repo.getAllAppointments(),
        ),
        isTrue,
      );

      // Executa encerramento do estudo com liberação de agenda
      final result = await releaseCoordinator.endStudyWithScheduleRelease(
        study: study,
        endReason: 'Mudou-se de território',
        notes: 'Foi para outra congregação',
        releaseFutureAppointments: true,
      );

      expect(result.success, isTrue);
      expect(result.releasedAppointmentsCount, equals(1));

      // Verificação: Estudo encerrado
      final studyCheck = await repo.getStudyById(study.id);
      expect(studyCheck!.status, equals('encerrado'));

      // Verificação: Participante alterado para revisita
      final pCheck = await repo.getPersonById(person.id);
      expect(pCheck!.status, equals('revisita'));

      // Verificação: Compromisso futuro foi cancelado
      final futureCheck = await (db.select(
        db.appointments,
      )..where((t) => t.id.equals(futureAppt.id))).getSingle();
      expect(futureCheck.status, equals('cancelado'));
      expect(futureCheck.deletedAt, isNotNull);

      // Verificação: Compromisso passado estritamente PRESERVADO
      final pastCheck = await (db.select(
        db.appointments,
      )..where((t) => t.id.equals(pastAppt.id))).getSingle();
      expect(pastCheck.status, equals('realizado'));
      expect(pastCheck.deletedAt, isNull);

      // Verificação: Compromisso da outra pessoa INTACTO
      final otherCheck = await (db.select(
        db.appointments,
      )..where((t) => t.id.equals(otherAppt.id))).getSingle();
      expect(otherCheck.status, equals('planejado'));
      expect(otherCheck.deletedAt, isNull);

      // Verificação: Lembrete local foi cancelado
      final activeReminders = await reminderService.getAllReminders();
      expect(
        activeReminders.any((r) => r.relatedEntityId == futureAppt.id),
        isFalse,
      );

      // Verificação: Horário do estudo agora está 100% livre no AvailabilityEngine
      expect(
        AvailabilityEngine.hasCollision(
          start: futureStart,
          end: futureStart.add(const Duration(minutes: 45)),
          existingAppointments: await repo.getAllAppointments(),
        ),
        isFalse,
      );
    });

    test('Encerrar revisita remove compromissos futuros vinculados e preserva histórico de visitas', () async {
      final person = await repo.createPerson(name: 'Beatriz Revisita');
      final now = DateTime.now();

      // 1. Visita anterior no histórico
      await repo.createVisit(
        personId: person.id,
        dateTime: now.subtract(const Duration(days: 5)),
        contactType: 'revisita',
        result: 'conversou',
        topicsDiscussed: 'Reino de Deus',
      );

      // 2. Compromisso futuro de revisita (studyId nulo)
      final futureStart = now.add(const Duration(days: 2, hours: 1));
      final futureRevisitAppt = await repo.createAppointment(
        personId: person.id,
        studyId: null,
        title: 'Retorno Beatriz',
        startTime: futureStart,
        endTime: futureStart.add(const Duration(minutes: 30)),
      );

      // 3. Lembrete associado
      await reminderService.scheduleReminder(
        ScheduledReminder(
          id: 'appt_${futureRevisitAppt.id}',
          title: futureRevisitAppt.title,
          description: 'Lembrete de revisita',
          scheduledFor: futureRevisitAppt.startTime,
          type: ReminderType.revisit,
          relatedEntityId: futureRevisitAppt.id,
        ),
      );

      // Executa encerramento da revisita
      final result = await releaseCoordinator.endRevisitWithScheduleRelease(
        person: person,
        endReason: 'Pediu para não ser visitado',
        notes: 'Respeitar pedido',
        releaseFutureAppointments: true,
      );

      expect(result.success, isTrue);
      expect(result.releasedAppointmentsCount, equals(1));

      // Verificação: Pessoa com status revisita_encerrada
      final pCheck = await repo.getPersonById(person.id);
      expect(pCheck!.status, equals('revisita_encerrada'));

      // Verificação: Compromisso futuro cancelado e deletedAt preenchido
      final apptCheck = await (db.select(
        db.appointments,
      )..where((t) => t.id.equals(futureRevisitAppt.id))).getSingle();
      expect(apptCheck.status, equals('cancelado'));
      expect(apptCheck.deletedAt, isNotNull);

      // Verificação: Histórico de visitas PRESERVADO
      final visits = await repo.getVisitsForPerson(person.id);
      expect(visits.length, equals(1));
      expect(visits.first.topicsDiscussed, equals('Reino de Deus'));

      // Verificação: Lembrete cancelado
      final reminders = await reminderService.getAllReminders();
      expect(
        reminders.any((r) => r.relatedEntityId == futureRevisitAppt.id),
        isFalse,
      );

      // Verificação: Disponibilidade liberada
      expect(
        AvailabilityEngine.hasCollision(
          start: futureStart,
          end: futureStart.add(const Duration(minutes: 30)),
          existingAppointments: await repo.getAllAppointments(),
        ),
        isFalse,
      );
    });

    test('Estudos com múltiplos participantes: exclusão de um estudante não apaga estudo compartilhado nem compromissos de terceiros', () async {
      final p1 = await repo.createPerson(name: 'Estudante A');
      final p2 = await repo.createPerson(name: 'Estudante B');
      final now = DateTime.now();

      final sharedStudy = await repo.createStudy(
        title: 'Estudo em Família (A e B)',
        publicationId: 'lff-book',
        participantPersonIds: [p1.id, p2.id],
      );

      // Compromisso futuro do estudo
      final futureStart = now.add(const Duration(days: 5));
      await repo.createAppointment(
        personId: p1.id,
        studyId: sharedStudy.id,
        title: 'Estudo Compartilhado A e B',
        startTime: futureStart,
        endTime: futureStart.add(const Duration(minutes: 60)),
      );

      // Exclui Estudante A definitivamente
      final result = await releaseCoordinator
          .permanentlyDeletePersonWithScheduleRelease(personId: p1.id);
      expect(result.success, isTrue);

      // Verificação 1: Estudante A foi excluído
      expect(await repo.getPersonById(p1.id), isNull);

      // Verificação 2: Estudante B continua ativo
      final p2Check = await repo.getPersonById(p2.id);
      expect(p2Check, isNotNull);

      // Verificação 3: O estudo compartilhado NÃO foi apagado
      final studyCheck = await repo.getStudyById(sharedStudy.id);
      expect(studyCheck, isNotNull);
      expect(studyCheck!.deletedAt, isNull);

      // Verificação 4: Apenas a participação de p1 foi removida; p2 continua associado
      final parts = await repo.getParticipantsForStudy(sharedStudy.id);
      expect(parts.length, equals(1));
      expect(parts.first.personId, equals(p2.id));

      // Verificação 5: O compromisso do estudo compartilhado NÃO foi apagado nem cancelado,
      // e foi reatribuído para o Estudante B (p2), preservando a agenda dos outros participantes
      final appts = await (db.select(
        db.appointments,
      )..where((t) => t.studyId.equals(sharedStudy.id))).get();
      expect(appts.length, equals(1));
      expect(appts.first.deletedAt, isNull);
      expect(appts.first.status, isNot('cancelado'));
      expect(appts.first.personId, equals(p2.id));

      // Verificação 6: O horário na agenda do Estudante B continua ocupado (não foi liberado indevidamente)
      expect(
        AvailabilityEngine.hasCollision(
          start: futureStart,
          end: futureStart.add(const Duration(minutes: 60)),
          existingAppointments: await repo.getAllAppointments(),
        ),
        isTrue,
      );
    });

    test('Pessoa na lixeira: getPersonRelationshipsSummary e exclusão definitiva preservam nome, identificam estudos exclusivos e purgam sem deixar órfãos', () async {
      final person = await repo.createPerson(name: 'Estudante Na Lixeira');
      final exclusiveStudy = await repo.createStudy(
        title: 'Estudo Exclusivo Lixeira',
        publicationId: 'lff-book',
        participantPersonIds: [person.id],
      );

      // Move pessoa para a lixeira (soft-delete)
      await repo.deletePerson(person.id);

      // Verifica que na lixeira o resumo ainda recupera o nome real e identifica o estudo exclusivo
      final summary = await releaseCoordinator.getPersonRelationshipsSummary(
        person.id,
      );
      expect(summary.personName, equals('Estudante Na Lixeira'));
      expect(summary.exclusiveStudies.length, equals(1));
      expect(summary.exclusiveStudies.first.id, equals(exclusiveStudy.id));

      // Executa exclusão definitiva da pessoa que estava na lixeira
      final result = await releaseCoordinator
          .permanentlyDeletePersonWithScheduleRelease(personId: person.id);
      expect(result.success, isTrue);

      // Verificação: Pessoa foi removida
      expect(await repo.getPersonById(person.id, includeDeleted: true), isNull);

      // Verificação: Estudo exclusivo foi purgado e não ficou órfão no banco
      final studyCheck = await (db.select(
        db.bibleStudies,
      )..where((t) => t.id.equals(exclusiveStudy.id))).getSingleOrNull();
      expect(studyCheck, isNull);
    });

    test('Compromissos reagendados (superseded) não duplicam listagem de liberação nem contagem de horários', () async {
      final person = await repo.createPerson(name: 'Reagendado Teste');
      final now = DateTime.now();
      final oldStart = now.add(const Duration(days: 2));
      final newStart = now.add(const Duration(days: 4));

      // Cria compromisso original
      final oldAppt = await repo.createAppointment(
        personId: person.id,
        title: 'Visita Original',
        startTime: oldStart,
        endTime: oldStart.add(const Duration(minutes: 30)),
      );

      // Reagenda para nova data
      final newAppt = await repo.rescheduleAppointment(
        oldAppointment: oldAppt,
        newStartTime: newStart,
        newEndTime: newStart.add(const Duration(minutes: 30)),
      );

      // getFutureAppointmentsForPerson deve retornar APENAS o compromisso ativo (novo),
      // ignorando o superseded ('reagendado') para evitar duplicação
      final activeAppts = await releaseCoordinator
          .getFutureAppointmentsForPerson(person.id);
      expect(activeAppts.length, equals(1));
      expect(activeAppts.first.id, equals(newAppt.id));
      expect(activeAppts.first.status, equals('confirmado'));

      // Resumo de relacionamentos deve computar exatamente 1 compromisso futuro ativo
      final summary = await releaseCoordinator.getPersonRelationshipsSummary(
        person.id,
      );
      expect(summary.futureAppointments.length, equals(1));
      expect(summary.futureAppointments.first.id, equals(newAppt.id));
    });

    test('Exclusão definitiva via repository limpa lembretes locais pendentes do LocalReminderService', () async {
      final person = await repo.createPerson(name: 'Lembrete Limpeza Teste');
      final now = DateTime.now();
      final apptStart = now.add(const Duration(days: 3));

      final appt = await repo.createAppointment(
        personId: person.id,
        title: 'Compromisso com Alarme',
        startTime: apptStart,
        endTime: apptStart.add(const Duration(minutes: 30)),
      );

      await reminderService.scheduleReminder(
        ScheduledReminder(
          id: 'appt_${appt.id}',
          title: appt.title,
          description: 'Notificação teste',
          scheduledFor: apptStart,
          type: ReminderType.revisit,
          relatedEntityId: appt.id,
        ),
      );

      // Confirma que o lembrete foi registrado
      final remindersBefore = await reminderService.getAllReminders();
      expect(remindersBefore.any((r) => r.relatedEntityId == appt.id), isTrue);

      // Exclusão definitiva via repo
      await repo.permanentlyDeleteItem('people', person.id);

      // Confirma que o lembrete foi cancelado e não ficou órfão no appKvStore
      final remindersAfter = await reminderService.getAllReminders();
      expect(remindersAfter.any((r) => r.relatedEntityId == appt.id), isFalse);
    });
  });

  group('Integração com Calendários Externos e Sincronização', () {
    test(
      'Sucesso na exclusão externa propaga e marca link como synced',
      () async {
        final person = await repo.createPerson(name: 'Mariana Agenda');
        final futureStart = DateTime.now().add(const Duration(days: 2));
        final appt = await repo.createAppointment(
          personId: person.id,
          title: 'Revisita Mariana',
          startTime: futureStart,
          endTime: futureStart.add(const Duration(minutes: 30)),
        );

        // Cria vínculo de calendário externo mock
        await db
            .into(db.calendarEventLinks)
            .insert(
              CalendarEventLinksCompanion.insert(
                id: 'link_1',
                appointmentId: appt.id,
                externalEventId: 'ext_event_123',
                provider: 'google',
                syncStatus: const drift.Value('synced'),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );

        // Provedor mock configurado para sucesso
        final mockProv = MockGoogleCalendarProvider(
          deleteExternalEventResult: true,
        );
        final customCalCoordinator = CalendarSyncCoordinator(
          db,
          google: mockProv,
        );

        final customRelease = ScheduleReleaseCoordinator(
          db: db,
          repo: repo,
          calendarCoordinator: customCalCoordinator,
          reminderService: reminderService,
        );

        final result = await customRelease.releaseAppointments(
          appointments: [appt],
          reason: 'Teste exclusão externa',
        );

        expect(result.success, isTrue);
        expect(mockProv.deletedEventIds.contains('ext_event_123'), isTrue);

        // Vínculo no banco deve ter deletedAt e status de propagação
        final link = await (db.select(
          db.calendarEventLinks,
        )..where((t) => t.id.equals('link_1'))).getSingle();
        expect(link.deletedAt, isNotNull);
        expect(link.syncStatus, equals('synced'));
      },
    );

    test('Calendário offline ou com erro preserva pending_upload sem perder tombstone', () async {
      final person = await repo.createPerson(name: 'Carlos Offline');
      final futureStart = DateTime.now().add(const Duration(days: 2));
      final appt = await repo.createAppointment(
        personId: person.id,
        title: 'Estudo Carlos',
        startTime: futureStart,
        endTime: futureStart.add(const Duration(minutes: 30)),
      );

      await db
          .into(db.calendarEventLinks)
          .insert(
            CalendarEventLinksCompanion.insert(
              id: 'link_offline_1',
              appointmentId: appt.id,
              externalEventId: 'ext_event_offline',
              provider: 'google',
              syncStatus: const drift.Value('synced'),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      // Mock configurado com falha de rede/offline
      final mockProvError = MockGoogleCalendarProvider(throwOnDelete: true);
      final errorCalCoordinator = CalendarSyncCoordinator(
        db,
        google: mockProvError,
      );
      final errorRelease = ScheduleReleaseCoordinator(
        db: db,
        repo: repo,
        calendarCoordinator: errorCalCoordinator,
        reminderService: reminderService,
      );

      // Executa liberação
      await errorRelease.releaseAppointments(
        appointments: [appt],
        reason: 'Teste offline',
      );

      final link = await (db.select(
        db.calendarEventLinks,
      )..where((t) => t.id.equals('link_offline_1'))).getSingle();

      expect(link.deletedAt, isNotNull);
      // Preservado como pending_upload para não fingir sucesso falso
      expect(link.syncStatus, equals('pending_upload'));
      expect(link.lastError, contains('falha de conexão de rede'));
    });

    test(
      'Calendário somente leitura não apaga evento e preserva pending_upload',
      () async {
        final person = await repo.createPerson(name: 'Beatriz ReadOnly');
        final futureStart = DateTime.now().add(const Duration(days: 2));
        final appt = await repo.createAppointment(
          personId: person.id,
          title: 'Estudo ReadOnly',
          startTime: futureStart,
          endTime: futureStart.add(const Duration(minutes: 30)),
        );

        await db
            .into(db.calendarEventLinks)
            .insert(
              CalendarEventLinksCompanion.insert(
                id: 'link_ro_1',
                appointmentId: appt.id,
                externalEventId: 'ext_event_ro',
                provider: 'google',
                syncStatus: const drift.Value('synced'),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );

        final mockProvRO = MockGoogleCalendarProvider(
          deleteExternalEventResult: false,
        )..mockReadOnlyCalendarIds.add('mock_cal_1');

        final roCalCoordinator = CalendarSyncCoordinator(
          db,
          google: mockProvRO,
        );
        final roRelease = ScheduleReleaseCoordinator(
          db: db,
          repo: repo,
          calendarCoordinator: roCalCoordinator,
          reminderService: reminderService,
        );

        await roRelease.releaseAppointments(
          appointments: [appt],
          reason: 'Teste ReadOnly',
        );

        final link = await (db.select(
          db.calendarEventLinks,
        )..where((t) => t.id.equals('link_ro_1'))).getSingle();

        expect(link.deletedAt, isNotNull);
        expect(link.syncStatus, equals('pending_upload'));
      },
    );

    test(
      'Eventos externos sem vínculo ministerial nunca são excluídos',
      () async {
        // Evento externo avulso (ex.: compromisso médico pessoal do usuário no Google Agenda)
        await db
            .into(db.externalCalendarEvents)
            .insert(
              ExternalCalendarEventsCompanion.insert(
                id: 'ext_event_independent',
                provider: 'google',
                calendarId: 'mock_cal_1',
                externalEventId: 'google_doctor_appt_789',
                title: 'Consulta Médica Particular',
                startTime: DateTime.now().add(const Duration(days: 1)),
                endTime: DateTime.now().add(const Duration(days: 1, hours: 1)),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );

        // Exclui uma pessoa com compromissos ministeriais
        final person = await repo.createPerson(name: 'Outra Pessoa');
        await releaseCoordinator.permanentlyDeletePersonWithScheduleRelease(
          personId: person.id,
        );

        // Evento médico externo INDEPENDENTE permanece 100% intacto!
        final extEvent =
            await (db.select(db.externalCalendarEvents)
                  ..where((t) => t.id.equals('ext_event_independent')))
                .getSingleOrNull();
        expect(extEvent, isNotNull);
        expect(extEvent!.title, equals('Consulta Médica Particular'));
        expect(extEvent.deletedAt, isNull);
      },
    );
  });
}
