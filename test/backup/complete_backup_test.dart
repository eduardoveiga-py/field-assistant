import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/settings/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Complete Backup & Multimedia Sanitation Contract (All 22 Tables)', () {
    late AppDatabase db;
    late AppRepository repo;
    late BackupService backupService;
    late Directory testDocsDir;

    setUp(() async {
      testDocsDir = await Directory.systemTemp.createTemp(
        'complete_backup_test_',
      );
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = AppRepository(db);
      backupService = BackupService(
        repo,
        documentsDirectoryProvider: () async => testDocsDir,
      );
    });

    tearDown(() async {
      await db.close();
      if (testDocsDir.existsSync()) {
        try {
          await testDocsDir.delete(recursive: true);
        } catch (_) {}
      }
    });

    test('Exporta e restaura integralmente todas as 22 tabelas Drift com criptografia v2 (salt e IV)', () async {
      final now = DateTime(2026, 11, 1, 10, 0);

      // 1. Popula dados nas tabelas
      final person = await repo.createPerson(
        name: 'Sara Mendes',
        phone: '11988887777',
        address: 'Av. Paulista, 500',
        status: 'interessado',
      );

      await repo.createVisit(
        personId: person.id,
        dateTime: now,
        contactType: 'revisita',
        result: 'Excelente receptividade',
        topicsDiscussed: 'Reino de Deus',
      );

      final study = await repo.createStudy(
        title: 'Estudo de Sara',
        publicationId: 'lff-book',
        language: 'pt',
        currentLesson: 1,
        currentParagraph: 1,
        participantPersonIds: [person.id],
        primaryParticipantId: person.id,
      );

      await repo.createStudySession(
        studyId: study.id,
        dateTime: now,
        publicationCode: 'lff-book',
        lessonCovered: 1,
        paragraphsCovered: '1-4',
        status: 'realizada',
        participantIds: [person.id],
      );

      await repo.createAppointment(
        personId: person.id,
        studyId: study.id,
        title: 'Estudo Bíblico',
        startTime: now.add(const Duration(days: 7)),
        endTime: now.add(const Duration(days: 7, hours: 1)),
        durationMinutes: 60,
        status: 'agendado',
      );

      await repo.createActivityRecord(
        date: now,
        durationSeconds: 9000,
        modality: 'campo',
        notes: '3 publicações, 1 vídeo, 2 revisitas',
      );

      await db
          .into(db.voiceNotes)
          .insert(
            VoiceNotesCompanion.insert(
              id: 'vn_test_1',
              personId: person.id,
              audioDurationSeconds: const drift.Value(15),
              transcription: 'Conversa rápida na padaria',
              createdAt: now,
              updatedAt: now,
              revision: const drift.Value(1),
            ),
          );

      await db
          .into(db.phoneContacts)
          .insert(
            PhoneContactsCompanion.insert(
              id: 'pc_test_1',
              name: 'Contato Telefônico 1',
              phone: '11911112222',
              notes: const drift.Value('Ligar à tarde'),
              createdAt: now,
              updatedAt: now,
              revision: const drift.Value(1),
            ),
          );

      await db
          .into(db.territoryLandmarks)
          .insert(
            TerritoryLandmarksCompanion.insert(
              id: 'lm_test_1',
              name: 'Hospital Regional',
              category: 'hospital',
              latitude: const drift.Value(-23.5),
              longitude: const drift.Value(-46.6),
              createdAt: now,
              updatedAt: now,
              revision: const drift.Value(1),
            ),
          );

      await db
          .into(db.familyTies)
          .insert(
            FamilyTiesCompanion.insert(
              id: 'ft_1',
              personId: person.id,
              relatedPersonName: 'Irmão da Sara',
              relationshipType: 'irmão',
              createdAt: now,
              revision: const drift.Value(1),
            ),
          );

      await db
          .into(db.ministryExperiences)
          .insert(
            MinistryExperiencesCompanion.insert(
              id: 'exp_1',
              title: 'Experiência Marcante',
              content: 'Testemunho no ponto de ônibus',
              dateTimeField: now,
              createdAt: now,
              updatedAt: now,
              revision: const drift.Value(1),
            ),
          );

      await db
          .into(db.personPhotos)
          .insert(
            PersonPhotosCompanion.insert(
              id: 'photo_1',
              personId: person.id,
              photoType: 'person',
              imageData: 'data:image/jpeg;base64,/9j/4AAQSkZJRg==',
              createdAt: now,
              revision: const drift.Value(1),
            ),
          );

      await db
          .into(db.personPublications)
          .insert(
            PersonPublicationsCompanion.insert(
              id: 'pub_1',
              personId: person.id,
              publicationTitle: 'Seja Feliz Para Sempre!',
              itemType: 'livro',
              status: 'entregue',
              date: now.toIso8601String().substring(0, 10),
              createdAt: now,
              revision: const drift.Value(1),
            ),
          );

      await db
          .into(db.researchArticles)
          .insert(
            ResearchArticlesCompanion.insert(
              id: 'art_1',
              title: 'Artigo de Pesquisa Teste',
              summary: 'Resumo bíblico',
              content: 'Conteúdo detalhado',
              createdAt: now,
              updatedAt: now,
              revision: const drift.Value(1),
            ),
          );

      await db
          .into(db.researchTags)
          .insert(
            ResearchTagsCompanion.insert(
              id: 'tag_1',
              name: 'Esperança',
              createdAt: now,
              revision: const drift.Value(1),
            ),
          );

      await db
          .into(db.territorySectors)
          .insert(
            TerritorySectorsCompanion.insert(
              id: 'sec_1',
              name: 'Setor 01 - Centro',
              createdAt: now,
              revision: const drift.Value(1),
            ),
          );

      await db
          .into(db.studentManualOrder)
          .insert(
            StudentManualOrderCompanion.insert(
              studyId: study.id,
              manualIndex: 1,
              revision: const drift.Value(1),
            ),
          );

      await db
          .into(db.externalCalendarEvents)
          .insert(
            ExternalCalendarEventsCompanion.insert(
              id: 'ext_cal_1',
              provider: 'google',
              calendarId: 'primary',
              externalEventId: 'google_event_456',
              title: 'Evento Externo no Google',
              startTime: now.add(const Duration(days: 2)),
              endTime: now.add(const Duration(days: 2, hours: 2)),
              createdAt: now,
              updatedAt: now,
              revision: const drift.Value(1),
            ),
          );

      await db
          .into(db.calendarEventLinks)
          .insert(
            CalendarEventLinksCompanion.insert(
              id: 'link_1',
              appointmentId: 'appt_teste',
              externalEventId: 'google_event_456',
              provider: 'google',
              syncStatus: const drift.Value('synced'),
              createdAt: now,
              updatedAt: now,
              revision: const drift.Value(1),
            ),
          );

      // 2. Exporta backup com senha
      const testPassword = 'senha_forte_segura_123';
      final encryptedJson = await backupService.exportEncryptedBackup(
        testPassword,
        iterations: 1000,
      );

      expect(encryptedJson, contains('"version":2'));
      expect(encryptedJson, contains('"salt":'));
      expect(encryptedJson, contains('"iv":'));
      expect(encryptedJson, contains('"ciphertext":'));

      // 3. Pré-visualiza backup
      final preview = await backupService.previewBackup(
        encryptedDataString: encryptedJson,
        password: testPassword,
      );

      expect(preview.peopleToAdd, equals(0)); // Já estão no banco
      expect(preview.peopleUnchanged, equals(1));
      expect(preview.photosToAdd, equals(0));
      expect(preview.articlesToAdd, equals(0));
      expect(preview.sectorsToAdd, equals(0));

      // 4. Cria banco destino vazio e restaura
      final targetDocsDir = await Directory.systemTemp.createTemp(
        'complete_backup_target_',
      );
      final targetDb = AppDatabase.forTesting(NativeDatabase.memory());
      final targetRepo = AppRepository(targetDb);
      final targetBackupService = BackupService(
        targetRepo,
        documentsDirectoryProvider: () async => targetDocsDir,
      );

      final targetPreview = await targetBackupService.previewBackup(
        encryptedDataString: encryptedJson,
        password: testPassword,
      );

      expect(targetPreview.peopleToAdd, equals(1));
      expect(targetPreview.visitsToAdd, equals(1));
      expect(targetPreview.studiesToAdd, equals(1));
      expect(targetPreview.sessionsToAdd, equals(1));
      expect(targetPreview.appointmentsToAdd, equals(1));
      expect(targetPreview.photosToAdd, equals(1));
      expect(targetPreview.articlesToAdd, equals(1));
      expect(targetPreview.sectorsToAdd, equals(1));
      expect(targetPreview.calendarEventsToAdd, equals(1));

      // Aplica a restauração no banco destino
      await targetBackupService.commitRestore(targetPreview);

      // 5. Valida integridade em todas as tabelas restauradas
      final restoredPeople = await targetRepo.getAllPeople();
      expect(restoredPeople.length, equals(1));
      expect(restoredPeople.first.name, equals('Sara Mendes'));

      final restoredVisits = await targetRepo.getVisitsForPerson(person.id);
      expect(restoredVisits.length, equals(1));
      expect(restoredVisits.first.result, equals('Excelente receptividade'));

      final restoredStudies = await targetRepo.getAllStudies();
      expect(restoredStudies.length, equals(1));
      expect(restoredStudies.first.title, equals('Estudo de Sara'));

      final restoredPhotos = await targetDb.select(targetDb.personPhotos).get();
      expect(restoredPhotos.length, equals(1));
      expect(
        restoredPhotos.first.imageData,
        equals('data:image/jpeg;base64,/9j/4AAQSkZJRg=='),
      );

      final restoredArticles = await targetDb
          .select(targetDb.researchArticles)
          .get();
      expect(restoredArticles.length, equals(1));
      expect(restoredArticles.first.title, equals('Artigo de Pesquisa Teste'));

      final restoredSectors = await targetDb
          .select(targetDb.territorySectors)
          .get();
      expect(restoredSectors.length, equals(1));
      expect(restoredSectors.first.name, equals('Setor 01 - Centro'));

      final restoredCalEvents = await targetDb
          .select(targetDb.externalCalendarEvents)
          .get();
      expect(restoredCalEvents.length, equals(1));
      expect(restoredCalEvents.first.title, equals('Evento Externo no Google'));

      await targetDb.close();
      if (targetDocsDir.existsSync()) {
        try {
          await targetDocsDir.delete(recursive: true);
        } catch (_) {}
      }
    });

    test('Falha ao tentar descriptografar com senha incorreta', () async {
      final encryptedJson = await backupService.exportEncryptedBackup(
        'senha_correta',
        iterations: 1000,
      );

      expect(
        () => backupService.previewBackup(
          encryptedDataString: encryptedJson,
          password: 'senha_completamente_errada',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
