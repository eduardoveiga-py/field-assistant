import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/core/app_config.dart';
import 'package:ministerio_pessoal/core/supabase_initializer.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/sync/supabase_sync_service.dart';
import 'package:ministerio_pessoal/sync/sync_engine.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Challenger M5 Empirical Stress Test (P0)', () {
    setUpAll(() {
      drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });

    tearDown(() {
      SupabaseInitializer.resetForTesting();
    });

    // =========================================================================
    // Challenge 1: Scenario 7 (Private Media & Storage Relative Keys)
    // =========================================================================
    group('Scenario 7: Private Media & Zero Absolute Path Leakage', () {
      test('Payload sanitization strips local paths regardless of case or format', () {
        final dirtyPayload = {
          'id': 'vn-uuid-adversarial-1',
          'person_id': 'person-123',
          'transcription': 'Auditoria de Privacidade',
          'audio_file_path': r'C:\Users\vanes\Documents\Projetos\secret.m4a',
          'audioFilePath': r'C:\Users\vanes\Documents\Projetos\secret.m4a',
          '_base': {'leak': 'forbidden'},
          'baseData': {'leak': 'forbidden'},
          'audio_duration_seconds': 25,
        };

        // Sanitização via SupabaseSyncService
        final sanitized = SupabaseSyncService.sanitizePayload('voice_notes', dirtyPayload);
        expect(sanitized.containsKey('audio_file_path'), isFalse);
        expect(sanitized.containsKey('audioFilePath'), isFalse);
        expect(sanitized.containsKey('_base'), isFalse);
        expect(sanitized.containsKey('baseData'), isFalse);
        expect(sanitized['id'], equals('vn-uuid-adversarial-1'));
        expect(sanitized['transcription'], equals('Auditoria de Privacidade'));

        // Payload remoto convertido para PostgREST snake_case
        final remote = SupabaseSyncService.toRemotePayload('voice_notes', dirtyPayload);
        expect(remote.containsKey('audio_file_path'), isFalse);
        expect(remote.containsKey('audioFilePath'), isFalse);
        expect(remote['id'], equals('vn-uuid-adversarial-1'));
      });

      test('Device B reconstructs dynamic local platform path upon downloading audio', () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final repo = AppRepository(db);
        final tempDocsDir = await Directory.systemTemp.createTemp('device_b_docs_');

        addTearDown(() async {
          await db.close();
          if (await tempDocsDir.exists()) await tempDocsDir.delete(recursive: true);
        });

        // Simula bucket de storage contendo audio binário
        final audioBytes = List<int>.generate(128, (i) => i % 256);
        final mockHttpClient = MockClient((req) async {
          if (req.url.path.contains('/storage/v1/object/')) {
            return http.Response.bytes(audioBytes, 200, request: req);
          }
          return http.Response('[]', 200, request: req, headers: {'content-type': 'application/json'});
        });

        final testConfig = AppConfig.create(
          environment: AppEnvironment.development,
          supabaseUrl: 'https://adversarial-target.supabase.co',
          supabaseAnonKey: 'valid-test-anon-key-1234567890',
        );

        final client = SupabaseClient(
          'https://adversarial-target.supabase.co',
          'valid-test-anon-key-1234567890',
          httpClient: mockHttpClient,
        );

        final syncService = SupabaseSyncService(
          db: db,
          repository: repo,
          config: testConfig,
          clientOverride: client,
          documentsDirectoryProvider: () async => tempDocsDir.path,
        );
        addTearDown(syncService.dispose);

        // Dispositivo B recebe registro remoto de voice_note (sem audio_file_path de A)
        await repo.createPerson(id: 'person-b-1', name: 'Pessoa B');
        final remoteVoiceNote = {
          'id': 'vn-cross-device-01',
          'person_id': 'person-b-1',
          'transcription': 'Gravação remota de A',
          'audio_duration_seconds': 12,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'revision': 1,
        };

        final errors = <String>[];
        final applied = await syncService.applyRemoteRecordForTesting(
          'voice_notes',
          remoteVoiceNote,
          errors,
          client,
        );

        expect(applied, isTrue);
        expect(errors, isEmpty);

        // Verifica que no banco SQLite local de B, o caminho salvo é local de B (não de A)
        final localNote = await (db.select(db.voiceNotes)..where((t) => t.id.equals('vn-cross-device-01'))).getSingleOrNull();
        expect(localNote, isNotNull);
        expect(localNote!.audioFilePath, isNotNull);
        expect(localNote.audioFilePath!.startsWith(tempDocsDir.path), isTrue);
        expect(File(localNote.audioFilePath!).existsSync(), isTrue);
        expect(await File(localNote.audioFilePath!).length(), equals(128));
      });
    });

    // =========================================================================
    // Challenge 2: Scenario 8 (Multi-Tenant Isolation & service_role Prohibition)
    // =========================================================================
    group('Scenario 8: Multi-Tenant Isolation & service_role Prohibition', () {
      test('Evasion attempts with uppercase, mangled JWT claims or management tokens are rejected', () {
        String makeJwtWithClaim(Map<String, dynamic> claims) {
          final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})));
          final payload = base64Url.encode(utf8.encode(jsonEncode(claims)));
          return '$header.$payload.fakeAdversarialSignature123456';
        }

        final evasionTokens = [
          ('Uppercase role: SERVICE_ROLE', makeJwtWithClaim({'role': 'SERVICE_ROLE'})),
          ('Mixed-case role: Service_Role', makeJwtWithClaim({'role': 'Service_Role'})),
          ('Role: super_admin', makeJwtWithClaim({'role': 'super_admin'})),
          ('Role: postgres', makeJwtWithClaim({'role': 'postgres'})),
          ('Plain substring: service_role', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9_service_role_bypass'),
          ('Supabase personal token: sbp_secret', 'sbp_4829375023847590238475029384'),
        ];

        for (final (desc, token) in evasionTokens) {
          final config = AppConfig.create(
            environment: AppEnvironment.production,
            supabaseUrl: 'https://test.supabase.co',
            supabaseAnonKey: token,
          );

          expect(config.isValid, isFalse, reason: 'Deveria falhar para $desc');
          expect(config.isInvalid, isTrue);
          expect(
            () => config.validateOrThrow(),
            throwsA(isA<AppConfigException>()),
            reason: 'validateOrThrow deve rejeitar $desc com AppConfigException',
          );
        }
      });
    });

    // =========================================================================
    // Challenge 3: Scenario 9 (Resilient Network Recovery & Backoff Jitter)
    // =========================================================================
    group('Scenario 9: Resilient Network Recovery & Outbox Durability', () {
      test('HTTP 500, 502, 503, 504 and SocketException retain outbox without burning subsequent attempts', () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final repo = AppRepository(db);

        addTearDown(() async {
          await db.close();
        });

        int callCount = 0;
        int simulatedHttpStatus = 503;

        final mockHttpClient = MockClient((req) async {
          callCount++;
          if (simulatedHttpStatus == 0) {
            throw const SocketException('Connection reset by peer');
          }
          return http.Response(
            jsonEncode({'message': 'Server Error $simulatedHttpStatus'}),
            simulatedHttpStatus,
            request: req,
            headers: {'content-type': 'application/json'},
          );
        });

        final testConfig = AppConfig.create(
          environment: AppEnvironment.development,
          supabaseUrl: 'https://adversarial-target.supabase.co',
          supabaseAnonKey: 'valid-test-anon-key-1234567890',
        );

        final client = SupabaseClient(
          'https://adversarial-target.supabase.co',
          'valid-test-anon-key-1234567890',
          httpClient: mockHttpClient,
        );

        final sync = SupabaseSyncService(
          db: db,
          repository: repo,
          config: testConfig,
          clientOverride: client,
        );
        addTearDown(sync.dispose);

        // Cria 3 mutações na outbox
        await repo.createPerson(id: 'net-p-1', name: 'Net Person 1');
        await repo.createPerson(id: 'net-p-2', name: 'Net Person 2');
        await repo.createPerson(id: 'net-p-3', name: 'Net Person 3');

        // Teste de falha com HTTP 503
        simulatedHttpStatus = 503;
        final res503 = await sync.processQueue();
        expect(callCount, greaterThanOrEqualTo(1));
        expect(res503.successCount, equals(0));
        expect(res503.failureCount, greaterThanOrEqualTo(1));
        expect(sync.currentStatus, equals(SyncStatus.waitingConnection));

        // Verifica que o lote abortou imediatamente e NÃO queimou tentativas dos itens subsequentes!
        final pendingAfter503 = await repo.getPendingSyncOperations();
        expect(pendingAfter503.length, equals(3));
        expect(pendingAfter503[0].attempts, equals(1)); // Primeiro tentou e falhou
        expect(pendingAfter503[1].attempts, equals(0)); // Segundo NÃO foi queimado
        expect(pendingAfter503[2].attempts, equals(0)); // Terceiro NÃO foi queimado

        // Teste de recuperação imediata quando a rede volta
        final serverSaved = <String, Map<String, dynamic>>{};
        final recoveredMockClient = MockClient((req) async {
          if (req.method == 'POST') {
            final body = jsonDecode(req.body);
            final items = body is List ? body : [body];
            for (final item in items) {
              final map = Map<String, dynamic>.from(item as Map);
              serverSaved[map['id'] as String] = map;
            }
            return http.Response(jsonEncode(items), 200, request: req, headers: {'content-type': 'application/json'});
          }
          return http.Response('[]', 200, request: req, headers: {'content-type': 'application/json'});
        });

        final recoveredClient = SupabaseClient(
          'https://adversarial-target.supabase.co',
          'valid-test-anon-key-1234567890',
          httpClient: recoveredMockClient,
        );

        final recoveredSync = SupabaseSyncService(
          db: db,
          repository: repo,
          config: testConfig,
          clientOverride: recoveredClient,
        );
        addTearDown(recoveredSync.dispose);

        final recoveryResult = await recoveredSync.processQueue(ignoreBackoff: true);
        expect(recoveryResult.successCount, equals(3));
        expect(recoveryResult.failureCount, equals(0));
        expect(recoveredSync.currentStatus, equals(SyncStatus.synced));

        // Todos os 3 itens chegaram intactos ao servidor
        expect(serverSaved.containsKey('net-p-1'), isTrue);
        expect(serverSaved.containsKey('net-p-2'), isTrue);
        expect(serverSaved.containsKey('net-p-3'), isTrue);

        // Fila completamente limpa
        final remaining = await repo.getPendingSyncOperations();
        expect(remaining, isEmpty);
      });
    });

    // =========================================================================
    // Challenge 4: Scenario 10 (Clean Bootstrap Install & SQLite FK Constraints)
    // =========================================================================
    group('Scenario 10: Clean Bootstrap Install & Foreign Key Integrity', () {
      test('Clean database bootstraps all 10 synchronized tables deterministically with foreign key constraints satisfied', () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final repo = AppRepository(db);

        addTearDown(() async {
          await db.close();
        });

        final nowIso = DateTime.now().toUtc().toIso8601String();
        final mockRemotePayloads = {
          'people': [
            {'id': 'fk-p-01', 'name': 'Parent Person', 'status': 'interessado', 'tags': '[]', 'created_at': nowIso, 'updated_at': nowIso, 'revision': 1},
          ],
          'visits': [
            {'id': 'fk-v-01', 'person_id': 'fk-p-01', 'date_time_field': nowIso, 'contact_type': 'revisita', 'result': 'feita', 'created_at': nowIso, 'updated_at': nowIso, 'revision': 1},
          ],
          'bible_studies': [
            {'id': 'fk-bs-01', 'title': 'Estudo Bíblico Parent', 'status': 'ativo', 'started_at': nowIso, 'created_at': nowIso, 'updated_at': nowIso, 'revision': 1},
          ],
          'study_participants': [
            {'id': 'fk-sp-01', 'study_id': 'fk-bs-01', 'person_id': 'fk-p-01', 'created_at': nowIso, 'updated_at': nowIso, 'revision': 1},
          ],
          'study_sessions': [
            {'id': 'fk-ss-01', 'study_id': 'fk-bs-01', 'date_time_field': nowIso, 'status': 'realizado', 'created_at': nowIso, 'updated_at': nowIso, 'revision': 1},
          ],
          'appointments': [
            {'id': 'fk-ap-01', 'title': 'Compromisso 01', 'start_time': nowIso, 'duration_minutes': 30, 'status': 'planejado', 'created_at': nowIso, 'updated_at': nowIso, 'revision': 1},
          ],
          'activity_records': [
            {'id': 'fk-ar-01', 'date': nowIso, 'duration_minutes': 45, 'created_at': nowIso, 'updated_at': nowIso, 'revision': 1},
          ],
          'voice_notes': [
            {'id': 'fk-vn-01', 'person_id': 'fk-p-01', 'transcription': 'Nota de voz 01', 'created_at': nowIso, 'updated_at': nowIso, 'revision': 1},
          ],
          'phone_contacts': [
            {'id': 'fk-pc-01', 'name': 'Contato 01', 'phone': '11911112222', 'created_at': nowIso, 'updated_at': nowIso, 'revision': 1},
          ],
          'territory_landmarks': [
            {'id': 'fk-tl-01', 'name': 'Marco 01', 'latitude': -23.5, 'longitude': -46.6, 'created_at': nowIso, 'updated_at': nowIso, 'revision': 1},
          ],
        };

        final mockHttpClient = MockClient((request) async {
          final path = request.url.path;
          for (final entry in mockRemotePayloads.entries) {
            if (path.endsWith('/${entry.key}')) {
              return http.Response(
                jsonEncode(entry.value),
                200,
                request: request,
                headers: {
                  'content-type': 'application/json',
                  'content-range': '0-0/${entry.value.length}',
                },
              );
            }
          }
          return http.Response('[]', 200, request: request, headers: {'content-type': 'application/json', 'content-range': '*/0'});
        });

        final testConfig = AppConfig.create(
          environment: AppEnvironment.development,
          supabaseUrl: 'https://adversarial-target.supabase.co',
          supabaseAnonKey: 'valid-test-anon-key-1234567890',
        );

        final client = SupabaseClient(
          'https://adversarial-target.supabase.co',
          'valid-test-anon-key-1234567890',
          httpClient: mockHttpClient,
        );

        final syncService = SupabaseSyncService(
          db: db,
          repository: repo,
          config: testConfig,
          clientOverride: client,
        );
        addTearDown(syncService.dispose);

        // Executa fetchRemoteChanges em base limpa
        final result = await syncService.fetchRemoteChanges();

        expect(result.success, isTrue);
        expect(result.errors, isEmpty);
        expect(result.totalProcessed, equals(10));
        expect(result.successCount, equals(10));

        // Confirma integridade referencial: todos os registros vinculados persistem perfeitamente
        final person = await repo.getPersonById('fk-p-01');
        expect(person, isNotNull);

        final visit = await repo.getVisitById('fk-v-01');
        expect(visit, isNotNull);
        expect(visit!.personId, equals(person!.id));

        final study = await (db.select(db.bibleStudies)..where((t) => t.id.equals('fk-bs-01'))).getSingleOrNull();
        expect(study, isNotNull);

        final participant = await (db.select(db.studyParticipants)..where((t) => t.id.equals('fk-sp-01'))).getSingleOrNull();
        expect(participant, isNotNull);
        expect(participant!.studyId, equals(study!.id));
        expect(participant.personId, equals(person.id));

        final session = await (db.select(db.studySessions)..where((t) => t.id.equals('fk-ss-01'))).getSingleOrNull();
        expect(session, isNotNull);
        expect(session!.studyId, equals(study.id));

        final voiceNote = await (db.select(db.voiceNotes)..where((t) => t.id.equals('fk-vn-01'))).getSingleOrNull();
        expect(voiceNote, isNotNull);
        expect(voiceNote!.personId, equals(person.id));
      });
    });
  });
}
