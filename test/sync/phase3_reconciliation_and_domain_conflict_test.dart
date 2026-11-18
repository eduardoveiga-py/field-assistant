import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/sync/domain_conflict_detector.dart';
import 'package:ministerio_pessoal/sync/supabase_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'FA-SYNC-01: Reconciliação Drift vs Supabase (mapEntityToRemoteTable)',
    () {
      test('mapeia todas as 26 tabelas em snake_case, camelCase, PascalCase, singular e plural', () {
        final expectedTables = SupabaseSyncService.syncTables;
        expect(expectedTables.length, equals(26));

        // 1. people
        expect(SupabaseSyncService.mapEntityToRemoteTable('people'), 'people');
        expect(SupabaseSyncService.mapEntityToRemoteTable('person'), 'people');
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('PersonEntry'),
          'people',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('person_entry'),
          'people',
        );

        // 2. visits
        expect(SupabaseSyncService.mapEntityToRemoteTable('visits'), 'visits');
        expect(SupabaseSyncService.mapEntityToRemoteTable('visit'), 'visits');
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('VisitEntry'),
          'visits',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('visit_entry'),
          'visits',
        );

        // 3. bible_studies
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('bible_studies'),
          'bible_studies',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('biblestudies'),
          'bible_studies',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('bible_study'),
          'bible_studies',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('BibleStudy'),
          'bible_studies',
        );

        // 4. study_participants
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('study_participants'),
          'study_participants',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('studyparticipants'),
          'study_participants',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('StudyParticipant'),
          'study_participants',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable(
            'bible_study_participants',
          ),
          'study_participants',
        );

        // 5. study_sessions
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('study_sessions'),
          'study_sessions',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('studysessions'),
          'study_sessions',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('StudySession'),
          'study_sessions',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('bible_study_session'),
          'study_sessions',
        );

        // 6. appointments
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('appointments'),
          'appointments',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('appointment'),
          'appointments',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('AppointmentEntry'),
          'appointments',
        );

        // 7. activity_records
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('activity_records'),
          'activity_records',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('activityrecords'),
          'activity_records',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('ActivityRecord'),
          'activity_records',
        );

        // 8. voice_notes
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('voice_notes'),
          'voice_notes',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('voicenotes'),
          'voice_notes',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('VoiceNote'),
          'voice_notes',
        );

        // 9. phone_contacts
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('phone_contacts'),
          'phone_contacts',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('phonecontacts'),
          'phone_contacts',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('PhoneContact'),
          'phone_contacts',
        );

        // 10. territory_landmarks
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('territory_landmarks'),
          'territory_landmarks',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('territorylandmarks'),
          'territory_landmarks',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('TerritoryLandmark'),
          'territory_landmarks',
        );

        // 11. family_ties
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('family_ties'),
          'family_ties',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('familyties'),
          'family_ties',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('FamilyTie'),
          'family_ties',
        );

        // 12. ministry_experiences
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('ministry_experiences'),
          'ministry_experiences',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('ministryexperiences'),
          'ministry_experiences',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('MinistryExperience'),
          'ministry_experiences',
        );

        // 13. person_photos
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('person_photos'),
          'person_photos',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('personphotos'),
          'person_photos',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('PersonPhoto'),
          'person_photos',
        );

        // 14. person_publications
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('person_publications'),
          'person_publications',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('personpublications'),
          'person_publications',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('PersonPublication'),
          'person_publications',
        );

        // 15. research_articles
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('research_articles'),
          'research_articles',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('researcharticles'),
          'research_articles',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('ResearchArticle'),
          'research_articles',
        );

        // 16. research_tags
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('research_tags'),
          'research_tags',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('researchtags'),
          'research_tags',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('ResearchTag'),
          'research_tags',
        );

        // 17. territory_sectors
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('territory_sectors'),
          'territory_sectors',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('territorysectors'),
          'territory_sectors',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('TerritorySector'),
          'territory_sectors',
        );

        // 18. inbox_entries
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('inbox_entries'),
          'inbox_entries',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('inboxentries'),
          'inbox_entries',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('InboxEntry'),
          'inbox_entries',
        );

        // 19. projects
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('projects'),
          'projects',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('project'),
          'projects',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('Project'),
          'projects',
        );

        // 20. tasks
        expect(SupabaseSyncService.mapEntityToRemoteTable('tasks'), 'tasks');
        expect(SupabaseSyncService.mapEntityToRemoteTable('task'), 'tasks');
        expect(SupabaseSyncService.mapEntityToRemoteTable('Task'), 'tasks');

        // 21. knowledge_notes
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('knowledge_notes'),
          'knowledge_notes',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('knowledgenotes'),
          'knowledge_notes',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('KnowledgeNote'),
          'knowledge_notes',
        );

        // 22. knowledge_questions
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('knowledge_questions'),
          'knowledge_questions',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('knowledgequestions'),
          'knowledge_questions',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('KnowledgeQuestion'),
          'knowledge_questions',
        );

        // 23. knowledge_documents
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('knowledge_documents'),
          'knowledge_documents',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('knowledgedocuments'),
          'knowledge_documents',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('KnowledgeDocument'),
          'knowledge_documents',
        );

        // 24. knowledge_resources
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('knowledge_resources'),
          'knowledge_resources',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('knowledgeresources'),
          'knowledge_resources',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('KnowledgeResource'),
          'knowledge_resources',
        );

        // 25. ticuna_words
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('ticuna_words'),
          'ticuna_words',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('ticunawords'),
          'ticuna_words',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('TicunaWord'),
          'ticuna_words',
        );

        // 26. ticuna_phrases
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('ticuna_phrases'),
          'ticuna_phrases',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('ticunaphrases'),
          'ticuna_phrases',
        );
        expect(
          SupabaseSyncService.mapEntityToRemoteTable('TicunaPhrase'),
          'ticuna_phrases',
        );

        // Valida que toda tabela do syncTables é mapeada para si mesma quando fornecida em snake_case
        for (final table in expectedTables) {
          expect(
            SupabaseSyncService.mapEntityToRemoteTable(table),
            equals(table),
          );
        }
      });
    },
  );

  group('FA-SYNC-02: Detecção de conflitos de domínio na Agenda', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'intervalsOverlap detecta interseções estritas e ignora adjacências',
      () {
        final t1 = DateTime.utc(2026, 11, 20, 10, 0);
        final t2 = DateTime.utc(2026, 11, 20, 11, 0);
        final t3 = DateTime.utc(2026, 11, 20, 12, 0);

        // Sobreposição real [10:00, 11:30) e [11:00, 12:00)
        expect(
          AppointmentDomainConflictDetector.intervalsOverlap(
            t1,
            DateTime.utc(2026, 11, 20, 11, 30),
            t2,
            t3,
          ),
          isTrue,
        );

        // Adjacência perfeita [10:00, 11:00) e [11:00, 12:00) => NÃO sobrepõe
        expect(
          AppointmentDomainConflictDetector.intervalsOverlap(t1, t2, t2, t3),
          isFalse,
        );

        // Disjuntos [10:00, 11:00) e [11:30, 12:00)
        expect(
          AppointmentDomainConflictDetector.intervalsOverlap(
            t1,
            t2,
            DateTime.utc(2026, 11, 20, 11, 30),
            t3,
          ),
          isFalse,
        );
      },
    );

    test('detectAndRecordOverlaps detecta dois compromissos com UUIDs distintos no mesmo horário', () async {
      final baseStart = DateTime.utc(2026, 11, 20, 14, 0);
      final baseEnd = DateTime.utc(2026, 11, 20, 15, 0);

      // Compromisso preexistente no dispositivo local (UUID local_1)
      await db
          .into(db.appointments)
          .insert(
            AppointmentsCompanion.insert(
              id: 'local_appt_1',
              title: 'Estudo com Família Silva',
              startTime: baseStart,
              endTime: baseEnd,
              status: const drift.Value('agendado'),
              createdAt: baseStart,
              updatedAt: baseStart,
            ),
          );

      // Compromisso sincronizado de outro dispositivo (UUID remote_2) no mesmo horário [14:00, 15:00)
      await db
          .into(db.appointments)
          .insert(
            AppointmentsCompanion.insert(
              id: 'remote_appt_2',
              title: 'Visita de Pastoreio',
              startTime: baseStart,
              endTime: baseEnd,
              status: const drift.Value('agendado'),
              createdAt: baseStart,
              updatedAt: baseStart,
            ),
          );

      final conflicts =
          await AppointmentDomainConflictDetector.detectAndRecordOverlaps(
            db,
            appointmentId: 'remote_appt_2',
          );

      // Conflito registrado sem apagar nenhum dos compromissos
      expect(conflicts.length, equals(1));
      expect(conflicts.first.incomingAppointmentId, equals('remote_appt_2'));
      expect(conflicts.first.conflictingAppointmentId, equals('local_appt_1'));

      // Verifica que o compromisso remoto teve status alterado para 'conflito'
      final updatedRemote = await (db.select(
        db.appointments,
      )..where((t) => t.id.equals('remote_appt_2'))).getSingle();
      expect(updatedRemote.status, equals('conflito'));

      // Verifica que o compromisso local preexistente foi 100% preservado intacto
      final local = await (db.select(
        db.appointments,
      )..where((t) => t.id.equals('local_appt_1'))).getSingle();
      expect(local.status, equals('agendado'));

      // Verifica que o conflito foi persistido auditavelmente em app_kv_store
      final activeList =
          await AppointmentDomainConflictDetector.getActiveConflicts(db);
      expect(activeList.length, equals(1));
      expect(activeList.first.incomingTitle, equals('Visita de Pastoreio'));
      expect(
        activeList.first.conflictingTitle,
        equals('Estudo com Família Silva'),
      );

      // Resolução consciente do conflito limpa registro no KV
      await AppointmentDomainConflictDetector.clearConflict(
        db,
        'remote_appt_2',
      );
      final afterClear =
          await AppointmentDomainConflictDetector.getActiveConflicts(db);
      expect(afterClear, isEmpty);
    });

    test(
      'ignora compromissos cancelados, reagendados ou com deletedAt',
      () async {
        final baseStart = DateTime.utc(2026, 11, 21, 9, 0);
        final baseEnd = DateTime.utc(2026, 11, 21, 10, 0);

        // Compromisso cancelado
        await db
            .into(db.appointments)
            .insert(
              AppointmentsCompanion.insert(
                id: 'cancelled_appt',
                title: 'Revisita Cancelada',
                startTime: baseStart,
                endTime: baseEnd,
                status: const drift.Value('cancelado'),
                createdAt: baseStart,
                updatedAt: baseStart,
              ),
            );

        // Compromisso soft-deleted
        await db
            .into(db.appointments)
            .insert(
              AppointmentsCompanion.insert(
                id: 'deleted_appt',
                title: 'Compromisso Apagado',
                startTime: baseStart,
                endTime: baseEnd,
                status: const drift.Value('agendado'),
                deletedAt: drift.Value(DateTime.utc(2026, 11, 20)),
                createdAt: baseStart,
                updatedAt: baseStart,
              ),
            );

        // Novo compromisso no mesmo horário
        await db
            .into(db.appointments)
            .insert(
              AppointmentsCompanion.insert(
                id: 'new_appt',
                title: 'Novo Estudo Ativo',
                startTime: baseStart,
                endTime: baseEnd,
                status: const drift.Value('agendado'),
                createdAt: baseStart,
                updatedAt: baseStart,
              ),
            );

        final conflicts =
            await AppointmentDomainConflictDetector.detectAndRecordOverlaps(
              db,
              appointmentId: 'new_appt',
            );

        expect(conflicts, isEmpty);
        final item = await (db.select(
          db.appointments,
        )..where((t) => t.id.equals('new_appt'))).getSingle();
        expect(item.status, equals('agendado'));
      },
    );
  });
}
