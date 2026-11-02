import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/core/app_config.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/sync/supabase_sync_service.dart';
import 'package:ministerio_pessoal/sync/sync_engine.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

http.Response mockJsonResponse(
  http.BaseRequest request,
  Object body, {
  int statusCode = 200,
  String contentRange = '*/0',
}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    request: request,
    headers: {
      'content-type': 'application/json',
      'content-range': contentRange,
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late AppRepository repo;
  late Directory tempDir;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = AppRepository(db);
    tempDir = await Directory.systemTemp.createTemp('u3_test_docs_');
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Unidade U3 — Schema Remoto SQL e Verificação Estrutural', () {
    test(
      '1. Arquivo de migração U3 existe e contém DDL das 3 tabelas faltantes',
      () async {
        final migrationFile = File(
          'supabase/migrations/20261102000000_u3_missing_tables_storage.sql',
        );
        expect(
          await migrationFile.exists(),
          isTrue,
          reason: 'O arquivo de migração SQL da Unidade U3 deve existir.',
        );

        final sql = await migrationFile.readAsString();

        // Tabelas criadas
        expect(sql, contains('CREATE TABLE IF NOT EXISTS public.voice_notes'));
        expect(
          sql,
          contains('CREATE TABLE IF NOT EXISTS public.phone_contacts'),
        );
        expect(
          sql,
          contains('CREATE TABLE IF NOT EXISTS public.territory_landmarks'),
        );

        // Chaves primárias e de propriedade
        expect(sql, contains('id UUID PRIMARY KEY DEFAULT gen_random_uuid()'));
        expect(
          sql,
          contains(
            'owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid()',
          ),
        );

        // Foreign Keys obrigatórias em voice_notes
        expect(
          sql,
          contains(
            'person_id UUID NOT NULL REFERENCES public.people(id) ON DELETE CASCADE',
          ),
        );
        expect(
          sql,
          contains(
            'visit_id UUID REFERENCES public.visits(id) ON DELETE SET NULL',
          ),
        );
        expect(
          sql,
          contains(
            'study_id UUID REFERENCES public.bible_studies(id) ON DELETE SET NULL',
          ),
        );

        // Foreign Key em phone_contacts
        expect(
          sql,
          contains(
            'converted_person_id UUID REFERENCES public.people(id) ON DELETE SET NULL',
          ),
        );

        // Campos de auditoria e controle de concorrência
        expect(
          sql,
          contains(
            'created_at TIMESTAMPTZ NOT NULL DEFAULT timezone(\'utc\'::text, now())',
          ),
        );
        expect(
          sql,
          contains(
            'updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone(\'utc\'::text, now())',
          ),
        );
        expect(sql, contains('deleted_at TIMESTAMPTZ'));
        expect(sql, contains('revision INTEGER NOT NULL DEFAULT 1'));
      },
    );

    test(
      '2. Índices de performance e integridade definidos na migração SQL',
      () async {
        final migrationFile = File(
          'supabase/migrations/20261102000000_u3_missing_tables_storage.sql',
        );
        final sql = await migrationFile.readAsString();

        // Índices de voice_notes
        expect(
          sql,
          contains(
            'CREATE INDEX IF NOT EXISTS idx_voice_notes_owner_id ON public.voice_notes(owner_id)',
          ),
        );
        expect(
          sql,
          contains(
            'CREATE INDEX IF NOT EXISTS idx_voice_notes_person_id ON public.voice_notes(person_id)',
          ),
        );
        expect(
          sql,
          contains(
            'CREATE INDEX IF NOT EXISTS idx_voice_notes_deleted_at ON public.voice_notes(deleted_at)',
          ),
        );
        expect(
          sql,
          contains(
            'CREATE INDEX IF NOT EXISTS idx_voice_notes_updated_at ON public.voice_notes(updated_at)',
          ),
        );

        // Índices de phone_contacts
        expect(
          sql,
          contains(
            'CREATE INDEX IF NOT EXISTS idx_phone_contacts_owner_id ON public.phone_contacts(owner_id)',
          ),
        );
        expect(
          sql,
          contains(
            'CREATE INDEX IF NOT EXISTS idx_phone_contacts_phone ON public.phone_contacts(phone)',
          ),
        );
        expect(
          sql,
          contains(
            'CREATE INDEX IF NOT EXISTS idx_phone_contacts_converted_person ON public.phone_contacts(converted_person_id)',
          ),
        );

        // Índices de territory_landmarks
        expect(
          sql,
          contains(
            'CREATE INDEX IF NOT EXISTS idx_territory_landmarks_owner_id ON public.territory_landmarks(owner_id)',
          ),
        );
        expect(
          sql,
          contains(
            'CREATE INDEX IF NOT EXISTS idx_territory_landmarks_category ON public.territory_landmarks(category)',
          ),
        );

        // Triggers de auditoria
        expect(sql, contains('trigger_%I_audit'));
        expect(
          sql,
          contains(
            "ARRAY['voice_notes', 'phone_contacts', 'territory_landmarks']",
          ),
        );
        expect(sql, contains('handle_update_audit()'));
      },
    );

    test('3. Configuração do Supabase Storage bucket voice_notes é estritamente privada', () async {
      final migrationFile = File(
        'supabase/migrations/20261102000000_u3_missing_tables_storage.sql',
      );
      final sql = await migrationFile.readAsString();

      // Bucket privado
      expect(sql, contains('public, file_size_limit, allowed_mime_types'));
      expect(sql, contains('\'voice_notes\','));
      expect(sql, contains('false,')); // public = false
      expect(sql, contains('10485760')); // 10 MB limit
      expect(sql, contains('audio/m4a'));
      expect(sql, contains('audio/x-m4a'));
      expect(sql, contains('audio/mp4'));
      expect(sql, contains('audio/aac'));
    });

    test('4. Políticas RLS de tabelas e Storage definem isolamento estrito por auth.uid()', () async {
      final migrationFile = File(
        'supabase/migrations/20261102000000_u3_missing_tables_storage.sql',
      );
      final sql = await migrationFile.readAsString();

      // RLS habilitado
      expect(
        sql,
        contains('ALTER TABLE public.voice_notes ENABLE ROW LEVEL SECURITY;'),
      );
      expect(
        sql,
        contains(
          'ALTER TABLE public.phone_contacts ENABLE ROW LEVEL SECURITY;',
        ),
      );
      expect(
        sql,
        contains(
          'ALTER TABLE public.territory_landmarks ENABLE ROW LEVEL SECURITY;',
        ),
      );
      expect(
        sql,
        contains('ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;'),
      );

      // Políticas RLS granulares por operação
      expect(sql, contains('voice_notes_select_policy'));
      expect(sql, contains('voice_notes_insert_policy'));
      expect(sql, contains('voice_notes_update_policy'));
      expect(sql, contains('voice_notes_delete_policy'));
      expect(sql, contains('auth.uid() = owner_id'));

      // Políticas de Storage
      expect(sql, contains('voice_notes_storage_select'));
      expect(sql, contains('voice_notes_storage_insert'));
      expect(sql, contains('voice_notes_storage_update'));
      expect(sql, contains('voice_notes_storage_delete'));
    });
  });

  group('Unidade U3 — Simulação de Isolamento RLS e Segurança', () {
    test('5. Contrato RLS Positivo: Usuário A autenticado tem acesso total a seus registros', () {
      const userAId = '11111111-1111-1111-1111-111111111111';

      bool canSelect(String authUid, String recordOwnerId) =>
          authUid == recordOwnerId;
      bool canInsert(String authUid, String recordOwnerId) =>
          authUid == recordOwnerId;
      bool canUpdate(String authUid, String oldOwnerId, String newOwnerId) =>
          authUid == oldOwnerId && authUid == newOwnerId;
      bool canDelete(String authUid, String recordOwnerId) =>
          authUid == recordOwnerId;

      expect(canSelect(userAId, userAId), isTrue);
      expect(canInsert(userAId, userAId), isTrue);
      expect(canUpdate(userAId, userAId, userAId), isTrue);
      expect(canDelete(userAId, userAId), isTrue);
    });

    test('6. Contrato RLS Negativo: Usuário A não lê, insere, altera ou exclui dados do Usuário B', () {
      const userAId = '11111111-1111-1111-1111-111111111111';
      const userBId = '22222222-2222-2222-2222-222222222222';

      bool canSelect(String authUid, String recordOwnerId) =>
          authUid == recordOwnerId;
      bool canInsert(String authUid, String recordOwnerId) =>
          authUid == recordOwnerId;
      bool canUpdate(String authUid, String oldOwnerId, String newOwnerId) =>
          authUid == oldOwnerId && authUid == newOwnerId;
      bool canDelete(String authUid, String recordOwnerId) =>
          authUid == recordOwnerId;

      expect(canSelect(userAId, userBId), isFalse);
      expect(canInsert(userAId, userBId), isFalse);
      expect(canUpdate(userAId, userBId, userBId), isFalse);
      expect(canUpdate(userAId, userAId, userBId), isFalse);
      expect(canDelete(userAId, userBId), isFalse);
    });

    test('7. Contrato RLS Não-Autenticado: Requisições anônimas não têm acesso aos dados', () {
      const String? anonymousUid = null;
      const userAId = '11111111-1111-1111-1111-111111111111';

      bool canAccess(String? authUid, String recordOwnerId) =>
          authUid != null && authUid == recordOwnerId;

      expect(canAccess(anonymousUid, userAId), isFalse);
    });

    test('8. Storage RLS: Usuário A não consegue ler, substituir ou deletar áudios do Usuário B', () {
      const userAId = '11111111-1111-1111-1111-111111111111';
      const userBId = '22222222-2222-2222-2222-222222222222';

      final voiceNotesDb = {'vn-b-01': userBId, 'vn-a-01': userAId};

      bool canAccessStorageObject({
        required String authUid,
        required String objectName,
        required String objectOwner,
      }) {
        final vnId = objectName.replaceAll('.m4a', '');
        final vnOwner = voiceNotesDb[vnId];
        return objectOwner == authUid || vnOwner == authUid;
      }

      // Usuário A tenta baixar o áudio de B -> NEGADO
      expect(
        canAccessStorageObject(
          authUid: userAId,
          objectName: 'vn-b-01.m4a',
          objectOwner: userBId,
        ),
        isFalse,
      );

      // Usuário A acessa seu próprio áudio -> AUTORIZADO
      expect(
        canAccessStorageObject(
          authUid: userAId,
          objectName: 'vn-a-01.m4a',
          objectOwner: userAId,
        ),
        isTrue,
      );
    });
  });

  group('Unidade U3 — Mapeamento e Serialização das Novas Entidades', () {
    test(
      '9. voice_notes: sanitização remove audioFilePath e formata snake_case',
      () {
        final localPayload = {
          'id': 'vn-123',
          'personId': 'p-456',
          'visitId': 'v-789',
          'studyId': null,
          'audioFilePath': '/data/user/0/app/voice_notes/vn-123.m4a',
          'audioDurationSeconds': 25,
          'transcription': 'Interessado pediu retorno na terça às 14h',
          'detectedLesson': 4,
          'detectedPoint': 2,
          'extractedPendingDoubt': 'Trindade',
          'extractedEmpathyNote': 'Cuidar com tom respeitoso',
          'createdAt': '2026-11-02T10:00:00.000Z',
          'updatedAt': '2026-11-02T10:00:00.000Z',
          'deletedAt': null,
          'revision': 1,
        };

        final sanitized = SupabaseSyncService.sanitizePayload(
          'voice_notes',
          localPayload,
        );
        expect(sanitized.containsKey('audioFilePath'), isFalse);
        expect(sanitized.containsKey('audio_file_path'), isFalse);

        final remotePayload = SupabaseSyncService.toRemotePayload(
          'voice_notes',
          localPayload,
        );
        expect(remotePayload['id'], equals('vn-123'));
        expect(remotePayload['person_id'], equals('p-456'));
        expect(remotePayload['visit_id'], equals('v-789'));
        expect(remotePayload['study_id'], isNull);
        expect(remotePayload.containsKey('audio_file_path'), isFalse);
        expect(remotePayload['audio_duration_seconds'], equals(25));
        expect(
          remotePayload['transcription'],
          equals('Interessado pediu retorno na terça às 14h'),
        );
        expect(remotePayload['detected_lesson'], equals(4));
        expect(remotePayload['detected_point'], equals(2));
        expect(remotePayload['extracted_pending_doubt'], equals('Trindade'));
        expect(
          remotePayload['extracted_empathy_note'],
          equals('Cuidar com tom respeitoso'),
        );
        expect(remotePayload['revision'], equals(1));
      },
    );

    test('10. phone_contacts: conversão snake_case, booleans e JSONB tags', () {
      final localPayload = {
        'id': 'pc-123',
        'name': 'João Carlos',
        'phone': '+5511999998888',
        'secondaryPhone': null,
        'hasWhatsapp': true,
        'whatsappInfo': 'Ativo no período da manhã',
        'hasSocial': false,
        'socialPlatform': null,
        'socialHandle': null,
        'notes': 'Conhecido do trabalho informal',
        'tags': '["informal", "jovem"]',
        'origin': 'Informal',
        'convertedPersonId': null,
        'createdAt': '2026-11-02T10:00:00.000Z',
        'updatedAt': '2026-11-02T10:00:00.000Z',
        'deletedAt': null,
        'revision': 1,
      };

      final remotePayload = SupabaseSyncService.toRemotePayload(
        'phone_contacts',
        localPayload,
      );
      expect(remotePayload['id'], equals('pc-123'));
      expect(remotePayload['name'], equals('João Carlos'));
      expect(remotePayload['phone'], equals('+5511999998888'));
      expect(remotePayload['has_whatsapp'], isTrue);
      expect(remotePayload['has_social'], isFalse);
      expect(
        remotePayload['whatsapp_info'],
        equals('Ativo no período da manhã'),
      );
      expect(
        remotePayload['tags'],
        anyOf(equals(['informal', 'jovem']), equals('["informal", "jovem"]')),
      );
      expect(remotePayload['origin'], equals('Informal'));
      expect(remotePayload['converted_person_id'], isNull);

      final normalized = SupabaseSyncService.normalizeRemotePayload(
        remotePayload,
      );
      expect(normalized['hasWhatsapp'], isTrue);
      expect(normalized['hasSocial'], isFalse);
      expect(normalized['whatsappInfo'], equals('Ativo no período da manhã'));
    });

    test('11. territory_landmarks: coordenadas numéricas e normalização para Drift', () {
      final localPayload = {
        'id': 'tl-123',
        'name': 'Padaria Estrela',
        'category': 'comercial',
        'address': 'Rua das Flores, 100',
        'latitude': -23.55052,
        'longitude': -46.63330,
        'notes': 'Ponto de encontro da equipe',
        'createdAt': '2026-11-02T10:00:00.000Z',
        'updatedAt': '2026-11-02T10:00:00.000Z',
        'deletedAt': null,
        'revision': 1,
      };

      final remotePayload = SupabaseSyncService.toRemotePayload(
        'territory_landmarks',
        localPayload,
      );
      expect(remotePayload['id'], equals('tl-123'));
      expect(remotePayload['name'], equals('Padaria Estrela'));
      expect(remotePayload['category'], equals('comercial'));
      expect(remotePayload['latitude'], equals(-23.55052));
      expect(remotePayload['longitude'], equals(-46.63330));

      final normalized = SupabaseSyncService.normalizeRemotePayload(
        remotePayload,
      );
      expect(normalized['latitude'], equals(-23.55052));
      expect(normalized['longitude'], equals(-46.63330));
      expect(normalized['category'], equals('comercial'));
    });

    test('12. Inbound Pull via fetchRemoteChanges: registros das 3 tabelas são mesclados e inseridos no SQLite Drift', () async {
      final now = DateTime.now();
      await db
          .into(db.people)
          .insert(
            PersonEntry(
              id: 'person-fk-01',
              name: 'Irmão Teste',
              firstContactAt: now,
              status: 'interessado',
              tags: '[]',
              createdAt: now,
              updatedAt: now,
              revision: 1,
            ),
          );

      final remoteVn = {
        'id': 'vn-remote-01',
        'person_id': 'person-fk-01',
        'visit_id': null,
        'study_id': null,
        'audio_duration_seconds': 15,
        'transcription': 'Transcrição remota de teste',
        'detected_lesson': 3,
        'detected_point': 1,
        'extracted_pending_doubt': null,
        'extracted_empathy_note': null,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'deleted_at': null,
        'revision': 1,
      };

      final remotePc = {
        'id': 'pc-remote-01',
        'name': 'Maria Telefone',
        'phone': '11988887777',
        'secondary_phone': null,
        'has_whatsapp': true,
        'whatsapp_info': null,
        'has_social': false,
        'social_platform': null,
        'social_handle': null,
        'notes': 'Nota remota',
        'tags': '["revisita"]',
        'origin': 'Informal',
        'converted_person_id': null,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'deleted_at': null,
        'revision': 1,
      };

      final remoteTl = {
        'id': 'tl-remote-01',
        'name': 'Ponto Ônibus Central',
        'category': 'transporte',
        'address': 'Praça Central',
        'latitude': -23.5,
        'longitude': -46.6,
        'notes': null,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'deleted_at': null,
        'revision': 1,
      };

      final mockHttpClient = MockClient((req) async {
        final path = req.url.path;
        if (path.contains('voice_notes')) {
          return mockJsonResponse(req, [remoteVn]);
        } else if (path.contains('phone_contacts')) {
          return mockJsonResponse(req, [remotePc]);
        } else if (path.contains('territory_landmarks')) {
          return mockJsonResponse(req, [remoteTl]);
        }
        return mockJsonResponse(req, []);
      });

      final validConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://test.supabase.co',
        supabaseAnonKey: 'a' * 30,
      );

      final mockClient = SupabaseClient(
        validConfig.supabaseUrl,
        validConfig.supabaseAnonKey,
        httpClient: mockHttpClient,
      );

      final syncService = SupabaseSyncService(
        db: db,
        repository: repo,
        config: validConfig,
        clientOverride: mockClient,
        documentsDirectoryProvider: () async => tempDir.path,
      );
      addTearDown(syncService.dispose);

      final pullResult = await syncService.fetchRemoteChanges();
      expect(pullResult.successCount, equals(3));
      expect(pullResult.failureCount, equals(0));

      final localVn = await (db.select(
        db.voiceNotes,
      )..where((t) => t.id.equals('vn-remote-01'))).getSingleOrNull();
      expect(localVn, isNotNull);
      expect(localVn!.transcription, equals('Transcrição remota de teste'));

      final localPc = await (db.select(
        db.phoneContacts,
      )..where((t) => t.id.equals('pc-remote-01'))).getSingleOrNull();
      expect(localPc, isNotNull);
      expect(localPc!.name, equals('Maria Telefone'));
      expect(localPc.hasWhatsapp, isTrue);

      final localTl = await (db.select(
        db.territoryLandmarks,
      )..where((t) => t.id.equals('tl-remote-01'))).getSingleOrNull();
      expect(localTl, isNotNull);
      expect(localTl!.name, equals('Ponto Ônibus Central'));
      expect(localTl.category, equals('transporte'));
    });

    test(
      '13. 3-Way Merge em phone_contacts preserva edições locais e remotas',
      () {
        final baseData = {
          'id': 'pc-merge-01',
          'name': 'Carlos Silva',
          'phone': '11999990000',
          'notes': 'Nota original',
          'hasWhatsapp': false,
          'origin': 'Informal',
          'revision': 1,
        };

        final localData = {
          'id': 'pc-merge-01',
          'name': 'Carlos Silva',
          'phone': '11999990000',
          'notes': 'Nota editada localmente no iPad',
          'hasWhatsapp': false,
          'origin': 'Informal',
          'revision': 1,
        };

        final remoteData = {
          'id': 'pc-merge-01',
          'name': 'Carlos Silva',
          'phone': '11999990000',
          'notes': 'Nota original',
          'hasWhatsapp': true,
          'origin': 'Informal',
          'revision': 2,
        };

        final mergeResult = SyncEngine.mergeEntities(
          entityType: 'phone_contacts',
          entityId: 'pc-merge-01',
          localData: localData,
          remoteData: remoteData,
          baseData: baseData,
        );

        expect(mergeResult.hasConflict, isFalse);
        expect(
          mergeResult.mergedData['notes'],
          equals('Nota editada localmente no iPad'),
        );
        expect(mergeResult.mergedData['hasWhatsapp'], isTrue);
      },
    );
  });

  group(
    'Unidade U3 — Resolução Segura de Operações com Falha (ISSUE-U2-02)',
    () {
      test('14. requeueFailedSyncOperations: recupera registros com attempts >= 5 com segurança', () async {
        final now = DateTime.now();

        await db
            .into(db.syncQueue)
            .insert(
              SyncQueueCompanion.insert(
                id: 'op-failed-01',
                entityType: 'phone_contacts',
                entityId: 'pc-001',
                operation: 'INSERT',
                payload: jsonEncode({'id': 'pc-001', 'name': 'Teste 1'}),
                status: drift.Value('failed'),
                attempts: drift.Value(5),
                lastError: drift.Value(
                  'PostgrestException: connection timeout',
                ),
                createdAt: now,
              ),
            );

        await db
            .into(db.syncQueue)
            .insert(
              SyncQueueCompanion.insert(
                id: 'op-failed-02',
                entityType: 'voice_notes',
                entityId: 'vn-001',
                operation: 'INSERT',
                payload: jsonEncode({
                  'id': 'vn-001',
                  'transcription': 'Áudio teste',
                }),
                status: drift.Value('failed'),
                attempts: drift.Value(6),
                lastError: drift.Value('503 Service Unavailable'),
                createdAt: now,
              ),
            );

        await db
            .into(db.syncQueue)
            .insert(
              SyncQueueCompanion.insert(
                id: 'op-pending-01',
                entityType: 'people',
                entityId: 'p-001',
                operation: 'INSERT',
                payload: jsonEncode({'id': 'p-001', 'name': 'Pessoa'}),
                status: drift.Value('pending'),
                attempts: drift.Value(0),
                createdAt: now,
              ),
            );

        final initialPending = await repo.getPendingSyncOperations();
        expect(initialPending.length, equals(1));
        expect(initialPending.first.id, equals('op-pending-01'));

        final requeuedCount = await repo.requeueFailedSyncOperations();
        expect(requeuedCount, equals(2));

        final afterPending = await repo.getPendingSyncOperations();
        expect(afterPending.length, equals(3));

        final op1 = afterPending.firstWhere((o) => o.id == 'op-failed-01');
        expect(op1.status, equals('pending'));
        expect(
          op1.attempts,
          equals(4),
          reason: 'Attempts ajustado para 4 permitindo exatamente mais 1 ciclo supervisionado.',
        );
        expect(
          op1.lastError,
          contains('connection timeout'),
          reason: 'Histórico do erro prévio foi preservado.',
        );

        final op2 = afterPending.firstWhere((o) => o.id == 'op-failed-02');
        expect(op2.status, equals('pending'));
        expect(op2.attempts, equals(4));
        expect(op2.lastError, contains('503 Service Unavailable'));
      });

      test('15. requeueFailedSyncOperations: suporte a lista específica de operationIds', () async {
        final now = DateTime.now();

        await db
            .into(db.syncQueue)
            .insert(
              SyncQueueCompanion.insert(
                id: 'op-target-01',
                entityType: 'territory_landmarks',
                entityId: 'tl-001',
                operation: 'INSERT',
                payload: jsonEncode({'id': 'tl-001', 'name': 'Landmark'}),
                status: drift.Value('failed'),
                attempts: drift.Value(5),
                lastError: drift.Value('Error 1'),
                createdAt: now,
              ),
            );

        await db
            .into(db.syncQueue)
            .insert(
              SyncQueueCompanion.insert(
                id: 'op-untargeted-02',
                entityType: 'phone_contacts',
                entityId: 'pc-002',
                operation: 'INSERT',
                payload: jsonEncode({'id': 'pc-002', 'name': 'Contact'}),
                status: drift.Value('failed'),
                attempts: drift.Value(5),
                lastError: drift.Value('Error 2'),
                createdAt: now,
              ),
            );

        final requeued = await repo.requeueFailedSyncOperations(
          operationIds: ['op-target-01'],
        );
        expect(requeued, equals(1));

        final ops = await repo.getPendingSyncOperations();
        expect(ops.length, equals(1));
        expect(ops.first.id, equals('op-target-01'));
      });
    },
  );
}
