import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/contacts/phone_contacts_manager.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/sync/supabase_sync_service.dart';
import 'package:ministerio_pessoal/territory/landmark_manager.dart';
import 'package:ministerio_pessoal/voice_notes/voice_note_models.dart';
import 'package:ministerio_pessoal/voice_notes/voice_notes_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

http.Response _jsonResponse(
  http.Request request,
  Object body, {
  int statusCode = 200,
}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    request: request,
    headers: {
      'content-type': 'application/json',
      'content-range': '*/0',
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('C1 Backoff/Retry & M10 SyncQueue Hydration', () {
    late AppDatabase db;
    late AppRepository repo;
    late Directory tempDir;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = AppRepository(db);
      tempDir = await Directory.systemTemp.createTemp('sync_hydration_test_');
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'C1: Backoff exponencial mantém status pending nas tentativas 1..4, promove a failed na 5ª e retryAllFailedOperations reinicia apenas falhas',
      () async {
        final now = DateTime.now().toUtc();
        final person = await repo.createPerson(name: 'Irmão Backoff');
        final op = (await (db.select(db.syncQueue)
              ..where((t) => t.entityId.equals(person.id)))
            .getSingle());

        // Marca conflito/synced em operações auxiliares para garantir isolamento do retryAllFailedOperations
        await db.into(db.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: 'op_synced_keep',
            entityType: 'people',
            entityId: 'p_synced',
            operation: 'INSERT',
            payload: jsonEncode({'id': 'p_synced', 'name': 'Synced'}),
            createdAt: now,
            status: const drift.Value('synced'),
          ),
        );
        await db.into(db.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: 'op_conflict_keep',
            entityType: 'people',
            entityId: 'p_conflict',
            operation: 'UPDATE',
            payload: jsonEncode({'id': 'p_conflict', 'name': 'Conflict'}),
            createdAt: now,
            status: const drift.Value('conflict'),
          ),
        );

        // Tentativas 1..4 mantêm status = pending
        for (int attempt = 1; attempt <= 4; attempt++) {
          await repo.markSyncOperationFailed(op.id, 'Erro transitório #$attempt');
          final current = await (db.select(db.syncQueue)
                ..where((t) => t.id.equals(op.id)))
              .getSingle();
          expect(current.attempts, equals(attempt));
          expect(current.status, equals('pending'));
        }

        // Backoff ativo: processQueue() não deve sequer tentar enviar se lastAttemptAt acabou de ocorrer
        var networkHits = 0;
        final countingClient = MockClient((request) async {
          networkHits++;
          return http.Response('Server Error', 500, request: request);
        });
        final syncSvc = SupabaseSyncService(
          db: db,
          repository: repo,
          clientOverride: SupabaseClient(
            'https://mock.supabase.co',
            'dummy-key',
            httpClient: countingClient,
          ),
          documentsDirectoryProvider: () async => tempDir.path,
        );
        addTearDown(syncSvc.dispose);

        await syncSvc.processQueue();
        expect(networkHits, equals(0), reason: 'Operação dentro da janela de backoff (2^4 = 16s) deve aguardar');

        // 5ª falha promove para dead-letter ('failed')
        await repo.markSyncOperationFailed(op.id, 'Erro na 5ª tentativa');
        final deadLetter = await (db.select(db.syncQueue)
              ..where((t) => t.id.equals(op.id)))
            .getSingle();
        expect(deadLetter.attempts, equals(AppRepository.maxSyncAttempts));
        expect(deadLetter.status, equals('failed'));

        // Reprocessamento manual restaura 'failed' -> 'pending' com attempts=0
        final resetCount = await repo.retryAllFailedOperations();
        expect(resetCount, equals(1));

        final retried = await (db.select(db.syncQueue)
              ..where((t) => t.id.equals(op.id)))
            .getSingle();
        expect(retried.status, equals('pending'));
        expect(retried.attempts, equals(0));
        expect(retried.lastError, isNull);
        expect(retried.lastAttemptAt, isNull);

        // Operações synced e conflict não são alteradas
        final keepSynced = await (db.select(db.syncQueue)
              ..where((t) => t.id.equals('op_synced_keep')))
            .getSingle();
        final keepConflict = await (db.select(db.syncQueue)
              ..where((t) => t.id.equals('op_conflict_keep')))
            .getSingle();
        expect(keepSynced.status, equals('synced'));
        expect(keepConflict.status, equals('conflict'));
      },
    );

    test(
      'F7/M10: Hidrata payloads mínimos ({id}) do SQLite local antes do envio para as 7 tabelas estratégicas (sem campos NOT NULL ausentes)',
      () async {
        final now = DateTime.now().toUtc();
        final person = await repo.createPerson(name: 'Maria Território');
        final study = await repo.createStudy(
          title: 'Estudo Seja Feliz',
          publicationId: 'lff-book',
          language: 'pt',
          currentLesson: 3,
          currentParagraph: 2,
          participantPersonIds: [person.id],
          primaryParticipantId: person.id,
        );
        final participants = await repo.getParticipantsForStudy(study.id);
        final participant = participants.first;

        final visit = await repo.createVisit(
          personId: person.id,
          dateTime: now,
          contactType: 'revisita',
          result: 'Boa conversa',
          topicsDiscussed: 'Salmos 37:29',
        );

        final appt = await repo.createAppointment(
          personId: person.id,
          studyId: study.id,
          title: 'Retorno Semanal',
          startTime: now.add(const Duration(days: 2)),
          endTime: now.add(const Duration(days: 2, hours: 1)),
          durationMinutes: 60,
          status: 'confirmado',
        );

        final voiceManager = VoiceNotesManager(db, repo);
        final vnItem = VoiceNoteItem(
          id: 'vn_hyd_1',
          personId: person.id,
          visitId: visit.id,
          studyId: study.id,
          transcription: 'Anotação de voz hidratada',
          createdAt: now,
          updatedAt: now,
        );
        await voiceManager.saveVoiceNote(vnItem);

        final landmarkManager = LandmarkManager(db);
        final landmark = await landmarkManager.addLandmark(
          name: 'Porto Central',
          category: 'transporte',
          address: 'Beira Rio, s/n',
          latitude: -3.1022,
          longitude: -67.9397,
        );

        final phoneManager = PhoneContactsManager(db);
        final phoneContact = await phoneManager.addPhoneContact(
          name: 'João Carrinho',
          phone: '(97) 99999-1234',
          origin: 'TPL / Carrinho',
        );

        // Verifica que os managers estratégicos enfileiraram payloads completos no SQLite
        final queuedBeforeStub = await db.select(db.syncQueue).get();
        expect(queuedBeforeStub.length, greaterThanOrEqualTo(8));
        for (final table in const [
          'bible_studies',
          'appointments',
          'visits',
          'study_participants',
          'voice_notes',
          'territory_landmarks',
          'phone_contacts',
        ]) {
          final matching = queuedBeforeStub.where((q) => q.entityType == table).toList();
          expect(matching, isNotEmpty, reason: 'Tabela $table deve enfileirar sync');
          final decoded = jsonDecode(matching.first.payload) as Map<String, dynamic>;
          expect(decoded.keys.length, greaterThan(3),
              reason: 'Manager de $table deve enfileirar payload completo, não stub mínimo');
        }

        // Substitui a fila por stubs mínimos {"id": ...} para exercitar hidratação forçada do SupabaseSyncService
        await db.delete(db.syncQueue).go();
        final stubTargets = <String, String>{
          'people': person.id,
          'bible_studies': study.id,
          'study_participants': participant.id,
          'visits': visit.id,
          'appointments': appt.id,
          'voice_notes': vnItem.id,
          'territory_landmarks': landmark.id,
          'phone_contacts': phoneContact.id,
        };

        var idx = 0;
        for (final entry in stubTargets.entries) {
          await db.into(db.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: 'stub_${idx++}',
              entityType: entry.key,
              entityId: entry.value,
              operation: 'INSERT',
              payload: jsonEncode({'id': entry.value}),
              createdAt: now.add(Duration(milliseconds: idx)),
              status: const drift.Value('pending'),
            ),
          );
        }

        final pushedByTable = <String, Map<String, dynamic>>{};
        final mockClient = MockClient((request) async {
          final path = request.url.path;
          if (request.method == 'POST' && path.endsWith('/rest/v1/rpc/sync_upsert_if_unchanged')) {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final table = body['p_table'] as String;
            final payload = Map<String, dynamic>.from(body['p_payload'] as Map);
            pushedByTable[table] = payload;
            return _jsonResponse(request, {'success': true});
          }
          return _jsonResponse(request, []);
        });

        final syncSvc = SupabaseSyncService(
          db: db,
          repository: repo,
          clientOverride: SupabaseClient(
            'https://mock.supabase.co',
            'dummy-key',
            httpClient: mockClient,
          ),
          documentsDirectoryProvider: () async => tempDir.path,
        );
        addTearDown(syncSvc.dispose);

        final res = await syncSvc.processQueue();
        expect(res.failureCount, equals(0));
        expect(res.successCount, equals(stubTargets.length));

        // Confirma que todas as 7 tabelas estratégicas receberam colunas NOT NULL hidratadas do SQLite local
        expect(pushedByTable['bible_studies']?['title'], equals('Estudo Seja Feliz'));
        expect(pushedByTable['bible_studies']?['publication_id'], equals('lff-book'));
        expect(pushedByTable['bible_studies']?['started_at'], isA<String>());

        expect(pushedByTable['study_participants']?['study_id'], equals(study.id));
        expect(pushedByTable['study_participants']?['person_id'], equals(person.id));
        expect(pushedByTable['study_participants']?['is_primary'], isTrue);

        expect(pushedByTable['visits']?['person_id'], equals(person.id));
        expect(pushedByTable['visits']?['contact_type'], equals('revisita'));
        expect(pushedByTable['visits']?['result'], equals('Boa conversa'));
        expect(pushedByTable['visits']?['date_time_field'], isA<String>());

        expect(pushedByTable['appointments']?['title'], equals('Retorno Semanal'));
        expect(pushedByTable['appointments']?['start_time'], isA<String>());
        expect(pushedByTable['appointments']?['end_time'], isA<String>());

        expect(pushedByTable['voice_notes']?['person_id'], equals(person.id));
        expect(pushedByTable['voice_notes']?['transcription'], equals('Anotação de voz hidratada'));

        expect(pushedByTable['territory_landmarks']?['name'], equals('Porto Central'));
        expect(pushedByTable['territory_landmarks']?['category'], equals('transporte'));

        expect(pushedByTable['phone_contacts']?['name'], equals('João Carrinho'));
        expect(pushedByTable['phone_contacts']?['phone'], equals('(97) 99999-1234'));
      },
    );
  });
}
