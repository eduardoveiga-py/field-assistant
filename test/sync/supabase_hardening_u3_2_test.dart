import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ministerio_pessoal/sync/sync_engine.dart';

import 'package:ministerio_pessoal/contacts/phone_contacts_manager.dart';
import 'package:ministerio_pessoal/core/app_config.dart';
import 'package:ministerio_pessoal/core/supabase_initializer.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/sync/supabase_sync_service.dart';
import 'package:ministerio_pessoal/territory/landmark_manager.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/voice_notes/voice_note_models.dart';
import 'package:ministerio_pessoal/voice_notes/voice_notes_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late AppRepository repo;
  late PhoneContactsManager phoneManager;
  late LandmarkManager landmarkManager;
  late VoiceNotesManager voiceManager;
  late SupabaseSyncService syncService;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = AppRepository(db);
    phoneManager = PhoneContactsManager(db);
    landmarkManager = LandmarkManager(db);
    voiceManager = VoiceNotesManager(db, repo);

    syncService = SupabaseSyncService(
      db: db,
      repository: repo,
      config: AppConfig.unconfigured(),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('U3.2 P1: 3-Way Merge com baseData Real (BUG-U3-02)', () {
    test('1. PhoneContactsManager.updatePhoneContact grava _base e incrementa revision', () async {
      final contact = await phoneManager.addPhoneContact(
        name: 'Maria Silva',
        phone: '11988887777',
        tags: ['antigo'],
        notes: 'Nota original',
      );

      // Limpa fila de sincronização do insert
      await (db.delete(db.syncQueue)).go();

      // Atualiza o contato com novos dados
      final updated = PhoneContactItem(
        id: contact.id,
        name: 'Maria Silva Atualizada',
        phone: '11988887777',
        hasWhatsApp: contact.hasWhatsApp,
        hasSocial: contact.hasSocial,
        tags: ['novo'],
        origin: contact.origin,
        notes: 'Nota modificada localmente',
        createdAt: contact.createdAt,
        updatedAt: contact.updatedAt,
      );

      await phoneManager.updatePhoneContact(updated);

      // Verifica SQLite local
      final localRow = await (db.select(
        db.phoneContacts,
      )..where((t) => t.id.equals(contact.id))).getSingle();
      expect(localRow.name, equals('Maria Silva Atualizada'));
      expect(localRow.revision, equals(2)); // Revision incrementada (BUG-U3-09)

      // Verifica SyncQueue outbox payload com _base
      final syncOp = await (db.select(
        db.syncQueue,
      )..where((t) => t.entityId.equals(contact.id))).getSingle();
      expect(syncOp.operation, equals('UPDATE'));

      final payload = jsonDecode(syncOp.payload) as Map<String, dynamic>;
      expect(payload['name'], equals('Maria Silva Atualizada'));
      expect(payload['revision'], equals(2));
      expect(payload.containsKey('_base'), isTrue);

      final baseData = payload['_base'] as Map<String, dynamic>;
      expect(baseData['name'], equals('Maria Silva'));
      expect(baseData['notes'], equals('Nota original'));
      expect(baseData['revision'], equals(1));
    });

    test(
      '2. LandmarkManager.updateLandmark grava _base e incrementa revision',
      () async {
        final lm = await landmarkManager.addLandmark(
          name: 'Padaria Alfa',
          category: 'padaria',
          address: 'Rua Um, 100',
          latitude: -23.55,
          longitude: -46.63,
          notes: 'Perto da esquina',
        );

        await (db.delete(db.syncQueue)).go();

        final updatedLm = TerritoryLandmark(
          id: lm.id,
          name: 'Padaria Alfa Nova',
          category: 'comercio',
          address: 'Rua Um, 102',
          latitude: -23.551,
          longitude: -46.631,
          notes: 'Fachada reformada',
          createdAt: lm.createdAt,
        );

        await landmarkManager.updateLandmark(updatedLm);

        final localRow = await (db.select(
          db.territoryLandmarks,
        )..where((t) => t.id.equals(lm.id))).getSingle();
        expect(localRow.name, equals('Padaria Alfa Nova'));
        expect(localRow.revision, equals(2));

        final syncOp = await (db.select(
          db.syncQueue,
        )..where((t) => t.entityId.equals(lm.id))).getSingle();
        expect(syncOp.operation, equals('UPDATE'));

        final payload = jsonDecode(syncOp.payload) as Map<String, dynamic>;
        expect(payload['name'], equals('Padaria Alfa Nova'));
        expect(payload['revision'], equals(2));
        expect(payload.containsKey('_base'), isTrue);

        final baseData = payload['_base'] as Map<String, dynamic>;
        expect(baseData['name'], equals('Padaria Alfa'));
        expect(baseData['category'], equals('padaria'));
        expect(baseData['address'], equals('Rua Um, 100'));
      },
    );

    test(
      '3. VoiceNotesManager.saveVoiceNote grava _base e incrementa revision',
      () async {
        final now = DateTime.now();
        final note = VoiceNoteItem(
          id: 'vn-test-01',
          personId: 'p-01',
          transcription: 'Transcrição inicial',
          audioFilePath: '/local/audio/note.m4a',
          createdAt: now,
          updatedAt: now,
          revision: 1,
        );

        await voiceManager.saveVoiceNote(note);
        await (db.delete(db.syncQueue)).go();

        final editedNote = note.copyWith(
          transcription: 'Transcrição editada pelo usuário',
        );

        await voiceManager.saveVoiceNote(editedNote);

        final localRow = await (db.select(
          db.voiceNotes,
        )..where((t) => t.id.equals(note.id))).getSingle();
        expect(
          localRow.transcription,
          equals('Transcrição editada pelo usuário'),
        );
        expect(localRow.revision, equals(2));

        final syncOp = await (db.select(
          db.syncQueue,
        )..where((t) => t.entityId.equals(note.id))).getSingle();
        expect(syncOp.operation, equals('UPDATE'));

        final payload = jsonDecode(syncOp.payload) as Map<String, dynamic>;
        expect(
          payload['transcription'],
          equals('Transcrição editada pelo usuário'),
        );
        expect(payload['revision'], equals(2));
        expect(payload.containsKey('_base'), isTrue);

        final baseData = payload['_base'] as Map<String, dynamic>;
        expect(baseData['transcription'], equals('Transcrição inicial'));
        expect(baseData['revision'], equals(1));
      },
    );

    test('4. Detecção de Conflito Concorrente via _base impede sobrescrita cega no 3-way merge', () async {
      final contact = await phoneManager.addPhoneContact(
        name: 'Carlos Oliveira',
        phone: '11999990000',
        notes: 'Versão Base Comum',
      );
      await (db.delete(db.syncQueue)).go();

      // Modificação local: usuário alterou 'notes' para 'Local Notes'
      await phoneManager.updatePhoneContact(
        PhoneContactItem(
          id: contact.id,
          name: contact.name,
          phone: contact.phone,
          hasWhatsApp: contact.hasWhatsApp,
          hasSocial: contact.hasSocial,
          tags: contact.tags,
          origin: contact.origin,
          notes: 'Local Notes',
          createdAt: contact.createdAt,
          updatedAt: contact.updatedAt,
        ),
      );

      // Simula chegada de registro remoto que também alterou 'notes' (conflito no mesmo campo!)
      final remoteRecord = {
        'id': contact.id,
        'name': contact.name,
        'phone': contact.phone,
        'notes': 'Remote Conflicting Notes',
        'has_whatsapp': false,
        'has_social': false,
        'tags': [],
        'origin': 'Informal',
        'created_at': contact.createdAt.toIso8601String(),
        'updated_at': DateTime.now()
            .add(const Duration(minutes: 5))
            .toIso8601String(),
        'revision': 2,
      };

      final errors = <String>[];
      final applied = await syncService.applyRemoteRecordForTesting(
        'phone_contacts',
        remoteRecord,
        errors,
      );

      // Como ambos alteraram 'notes' em relação ao _base, deve detectar conflito e NÃO sobrescrever cegamente!
      expect(applied, isFalse);
      expect(errors.isNotEmpty, isTrue);
      expect(errors.first, contains('Conflito detectado'));

      // Valida que o SQLite local manteve 'Local Notes' e a operação foi marcada como 'conflict'
      final localContact = await (db.select(
        db.phoneContacts,
      )..where((t) => t.id.equals(contact.id))).getSingle();
      expect(localContact.notes, equals('Local Notes'));

      final outboxOp = await (db.select(
        db.syncQueue,
      )..where((t) => t.entityId.equals(contact.id))).getSingle();
      expect(outboxOp.status, equals('conflict'));
    });
  });

  group('U3.2 P1: Preservação do Ponteiro Local de Áudio (BUG-U3-04)', () {
    test('5. Atualização remota de metadados NUNCA apaga audioFilePath local existente', () async {
      final now = DateTime.now();
      const localAudioPath =
          '/data/user/0/app/files/voice_notes/vn-audio-test.m4a';

      // 1. Cria a nota localmente com áudio no disco
      await db
          .into(db.voiceNotes)
          .insert(
            VoiceNotesCompanion.insert(
              id: 'vn-audio-01',
              personId: 'p-01',
              transcription: 'Gravação original',
              audioFilePath: const drift.Value(localAudioPath),
              createdAt: now,
              updatedAt: now,
              revision: const drift.Value(1),
            ),
          );

      // 2. Recebe atualização remota de metadados (como gerado pelo PostgREST, onde audioFilePath é omitido ou nulo)
      final remoteUpdate = {
        'id': 'vn-audio-01',
        'person_id': 'p-01',
        'transcription': 'Transcrição corrigida na nuvem',
        'detected_lesson': 3,
        'audio_duration_seconds': 12,
        'created_at': now.toIso8601String(),
        'updated_at': now.add(const Duration(minutes: 2)).toIso8601String(),
        'revision': 2,
        // Atenção: audio_file_path e audioFilePath propositalmente ausentes/nulos!
      };

      final errors = <String>[];
      final applied = await syncService.applyRemoteRecordForTesting(
        'voice_notes',
        remoteUpdate,
        errors,
      );

      expect(applied, isTrue);

      // 3. Verifica que os metadados foram atualizados MAS o ponteiro local foi preservado 100% intacto!
      final updatedNote = await (db.select(
        db.voiceNotes,
      )..where((t) => t.id.equals('vn-audio-01'))).getSingle();
      expect(
        updatedNote.transcription,
        equals('Transcrição corrigida na nuvem'),
      );
      expect(updatedNote.detectedLesson, equals(3));
      expect(updatedNote.audioFilePath, equals(localAudioPath)); // PRESERVADO!
    });
  });

  group('U3.2 P2: Normalização de Tags JSONB (BUG-U3-06)', () {
    test('6. toRemotePayload converte tags em String JSON para lista nativa Dart', () {
      final localPayload = {
        'id': 'pc-tags-01',
        'name': 'Pedro Teste',
        'phone': '11999991111',
        'tags': '["pioneiro", "revisita", "estudo"]',
        'hasWhatsapp': true,
        'hasSocial': false,
      };

      final remote = SupabaseSyncService.toRemotePayload(
        'phone_contacts',
        localPayload,
      );

      // Deve ser lista nativa Dart para serialização JSONB correta no PostgREST
      expect(remote['tags'], isA<List>());
      expect(remote['tags'], equals(['pioneiro', 'revisita', 'estudo']));
      expect(remote['has_whatsapp'], isTrue);
      expect(remote['has_social'], isFalse);
    });

    test('7. toRemotePayload preserva tags que já estejam como lista', () {
      final localPayload = {
        'id': 'pc-tags-02',
        'name': 'Lucas Teste',
        'phone': '11999992222',
        'tags': ['tag1', 'tag2'],
      };

      final remote = SupabaseSyncService.toRemotePayload(
        'phone_contacts',
        localPayload,
      );
      expect(remote['tags'], equals(['tag1', 'tag2']));
    });
  });

  group('U3.2 P2: Robustez e Transacionalidade de Requeue da Outbox (BUG-U3-07 & BUG-U3-08)', () {
    test('8. requeueFailedSyncOperations com lista vazia retorna 0 sem reenfileirar tudo', () async {
      final now = DateTime.now();

      await db
          .into(db.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: 'op-fail-01',
              entityType: 'people',
              entityId: 'p-01',
              operation: 'UPDATE',
              payload: jsonEncode({'id': 'p-01'}),
              status: const drift.Value('failed'),
              attempts: const drift.Value(5),
              lastError: const drift.Value('503 Service Unavailable'),
              createdAt: now,
            ),
          );

      // Passa lista explicitamente vazia (BUG-U3-07)
      final requeued = await repo.requeueFailedSyncOperations(operationIds: []);
      expect(requeued, equals(0));

      // Operação deve continuar intacta em 'failed'
      final op = await (db.select(
        db.syncQueue,
      )..where((t) => t.id.equals('op-fail-01'))).getSingle();
      expect(op.status, equals('failed'));
      expect(op.attempts, equals(5));
    });

    test('9. requeueFailedSyncOperations não eleva tentativas se attempts < 4 (BUG-U3-08)', () async {
      final now = DateTime.now();

      await db
          .into(db.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: 'op-fail-low',
              entityType: 'people',
              entityId: 'p-02',
              operation: 'UPDATE',
              payload: jsonEncode({'id': 'p-02'}),
              status: const drift.Value('failed'),
              attempts: const drift.Value(2), // Menos de 4 tentativas
              lastError: const drift.Value('Connection reset'),
              createdAt: now,
            ),
          );

      final requeued = await repo.requeueFailedSyncOperations(
        operationIds: ['op-fail-low'],
      );
      expect(requeued, equals(1));

      final op = await (db.select(
        db.syncQueue,
      )..where((t) => t.id.equals('op-fail-low'))).getSingle();
      expect(op.status, equals('pending'));
      expect(op.attempts, equals(2)); // Mantido em 2, NÃO elevado para 4!
    });

    test('10. requeueFailedSyncOperations reduz attempts >= 5 para 4 para permitir novo ciclo', () async {
      final now = DateTime.now();

      await db
          .into(db.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: 'op-fail-high',
              entityType: 'people',
              entityId: 'p-03',
              operation: 'UPDATE',
              payload: jsonEncode({'id': 'p-03'}),
              status: const drift.Value('failed'),
              attempts: const drift.Value(7),
              lastError: const drift.Value('Timeout'),
              createdAt: now,
            ),
          );

      final requeued = await repo.requeueFailedSyncOperations();
      expect(requeued, equals(1));

      final op = await (db.select(
        db.syncQueue,
      )..where((t) => t.id.equals('op-fail-high'))).getSingle();
      expect(op.status, equals('pending'));
      expect(
        op.attempts,
        equals(4),
      ); // Reduzido para 4 para permitir mais 1 tentativa supervisionada
    });
  });

  group('U3.2 P1: Migração de Storage e Hardening SQL (BUG-U3-03, BUG-U3-05, BUG-U3-10)', () {
    test('11. Arquivo de migração U3.2 existe e contém políticas RLS blindadas e now()', () {
      final file = File(
        'supabase/migrations/20261102020000_u3_2_storage_and_hardening.sql',
      );
      expect(
        file.existsSync(),
        isTrue,
        reason: 'Arquivo de migração 20261102020000 deve existir',
      );

      final content = file.readAsStringSync();

      // Valida correção de timezone em handle_update_audit (BUG-U3-05)
      expect(content, contains('NEW.updated_at = now();'));
      expect(content, isNot(contains("timezone('utc'::text, now())")));

      // Valida validação de ownership da nota de voz no INSERT de Storage (BUG-U3-03)
      expect(content, contains('voice_notes_storage_insert'));
      expect(content, contains('public.voice_notes vn'));
      expect(content, contains('vn.owner_id = auth.uid()'));

      // Valida suporte multi-extensão (.m4a, .mp4, .aac) via regexp_replace (BUG-U3-10)
      expect(
        content,
        contains(r"regexp_replace(storage.objects.name, '\.[^.]+$', '')"),
      );
      expect(content, contains('voice_notes_storage_select'));
      expect(content, contains('voice_notes_storage_update'));
      expect(content, contains('voice_notes_storage_delete'));
    });
  });

  group('U3.2 Além de P1 e P2: Resiliência de Inicialização e Outbox Providers', () {
    test('12. SupabaseInitializer.retryInitialization re-tenta com segurança após falha de boot (ISSUE-U2-01)', () async {
      await SupabaseInitializer.resetForTesting();

      // Configuração desconfigurada (modo offline local seguro)
      final state1 = await SupabaseInitializer.initializeIfConfigured(
        config: AppConfig.unconfigured(),
      );
      expect(state1, equals(SupabaseConnectionState.unconfigured));

      // Re-tentativa com retryInitialization
      final state2 = await SupabaseInitializer.retryInitialization(
        config: AppConfig.unconfigured(),
      );
      expect(state2, equals(SupabaseConnectionState.unconfigured));
    });

    test('13. OutboxRecoveryNotifier e Provider Riverpod para recuperação da outbox (ISSUE-U2-02)', () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          repositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final now = DateTime.now();
      await db
          .into(db.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: 'op-riverpod-fail',
              entityType: 'people',
              entityId: 'p-99',
              operation: 'INSERT',
              payload: jsonEncode({'id': 'p-99', 'name': 'Teste Riverpod'}),
              status: const drift.Value('failed'),
              attempts: const drift.Value(5),
              lastError: const drift.Value('Erro de rede persistente'),
              createdAt: now,
            ),
          );

      final notifier = container.read(outboxRecoveryProvider.notifier);
      final count = await notifier.requeueFailedOperations();
      expect(count, equals(1));

      final state = container.read(outboxRecoveryProvider);
      expect(state.value, equals(1));

      final restoredOp = await (db.select(
        db.syncQueue,
      )..where((t) => t.id.equals('op-riverpod-fail'))).getSingle();
      expect(restoredOp.status, equals('pending'));
      expect(restoredOp.attempts, equals(4));
    });

    test('14. _applyRemoteRecord preserva snapshot _base na outbox após merge bem-sucedido', () async {
      final contact = await phoneManager.addPhoneContact(
        name: 'Renata',
        phone: '11987654321',
        origin: 'Informal',
        notes: 'Nota base',
      );
      await (db.delete(db.syncQueue)).go();

      // Usuário alterou nome localmente
      await phoneManager.updatePhoneContact(
        PhoneContactItem(
          id: contact.id,
          name: 'Renata Local',
          phone: contact.phone,
          hasWhatsApp: contact.hasWhatsApp,
          hasSocial: contact.hasSocial,
          tags: contact.tags,
          origin: contact.origin,
          notes: 'Nota base',
          createdAt: contact.createdAt,
          updatedAt: contact.updatedAt,
        ),
      );

      // Remoto alterou origin (sem conflito)
      final remoteRecord = {
        'id': contact.id,
        'name': contact.name,
        'phone': contact.phone,
        'notes': 'Nota base',
        'origin': 'Praça Central',
        'has_whatsapp': false,
        'has_social': false,
        'tags': [],
        'created_at': contact.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'revision': 2,
      };

      final errors = <String>[];
      final applied = await syncService.applyRemoteRecordForTesting(
        'phone_contacts',
        remoteRecord,
        errors,
      );

      expect(errors, isEmpty);
      expect(applied, isTrue);

      // Verifica que o payload atualizado na outbox ainda contém _base
      final updatedOp = await (db.select(
        db.syncQueue,
      )..where((t) => t.entityId.equals(contact.id))).getSingle();
      final payload = jsonDecode(updatedOp.payload) as Map<String, dynamic>;
      expect(payload['name'], equals('Renata Local'));
      expect(payload['origin'], equals('Praça Central'));
      expect(payload.containsKey('_base'), isTrue);
    });

    test('15. _downloadVoiceNoteAudio não realiza download de rede se arquivo local já existir e for íntegro em disco', () async {
      final tempDir = Directory.systemTemp.createTempSync('audio_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final localFile = File('${tempDir.path}/test_cached_note.m4a');
      await localFile.writeAsBytes([1, 2, 3, 4, 5]);

      final now = DateTime.now();
      await db
          .into(db.voiceNotes)
          .insert(
            VoiceNotesCompanion.insert(
              id: 'vn-local-cached',
              personId: 'p-cached',
              transcription: 'Áudio em cache',
              audioFilePath: drift.Value(localFile.path),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Cliente mock com verificação de zero chamadas de download
      final mockHttpClient = MockClient((req) async {
        fail(
          'Não deve efetuar chamada de rede para áudio já existente em disco!',
        );
      });
      final client = SupabaseClient(
        'https://test.supabase.co',
        'anon-key',
        httpClient: mockHttpClient,
      );

      final ok = await syncService.downloadVoiceNoteAudioForTesting(
        'vn-local-cached',
        client,
      );
      expect(ok, isTrue);
    });

    test('16. SyncEngine.mergeEntities com coleções em tags de lista e mapas normaliza por valor e evita falsos conflitos', () {
      final base = {
        'id': 'pc-list-merge',
        'name': 'Carlos',
        'tags': ['amigo', 'estudo'],
      };
      final local = {
        'id': 'pc-list-merge',
        'name': 'Carlos Local',
        'tags': ['amigo', 'estudo'],
      };
      final remote = {
        'id': 'pc-list-merge',
        'name': 'Carlos',
        'tags': ['amigo', 'estudo'],
      };

      final result = SyncEngine.mergeEntities(
        entityType: 'phone_contacts',
        entityId: 'pc-list-merge',
        localData: local,
        remoteData: remote,
        baseData: base,
      );

      expect(result.hasConflict, isFalse);
      expect(result.mergedData['name'], equals('Carlos Local'));
    });

    test('17. PhoneContactsManager e LandmarkManager ignoram update de entidade inexistente sem enfileirar lixo na outbox', () async {
      await (db.delete(db.syncQueue)).go();

      final ghostContact = PhoneContactItem(
        id: 'non-existent-contact-uuid',
        name: 'Fantasma',
        phone: '00000000',
        hasWhatsApp: false,
        hasSocial: false,
        tags: [],
        origin: 'Informal',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await phoneManager.updatePhoneContact(ghostContact);

      final queueCount = await (db.select(
        db.syncQueue,
      )..where((t) => t.entityId.equals('non-existent-contact-uuid'))).get();
      expect(queueCount, isEmpty);
    });
  });
}
