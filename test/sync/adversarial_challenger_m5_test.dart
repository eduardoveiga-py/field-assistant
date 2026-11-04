import 'dart:convert';
import 'dart:io';
import 'dart:math';

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

  group('Adversarial Challenger M5 - Deep Integrity & Privacy Challenge', () {
    setUpAll(() {
      drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });

    tearDown(() {
      SupabaseInitializer.resetForTesting();
    });

    // =========================================================================
    // 1. Multi-Tenant RLS & Private Media: Proibição de service_role e vazamentos
    // =========================================================================
    group('1. Multi-Tenant RLS & Credential Prohibition', () {
      test('Rejeição estrita de qualquer credencial privilegiada com AppConfigException', () {
        // Gera JWT simulado com role service_role
        String makeJwt(String role) {
          final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})));
          final payload = base64Url.encode(utf8.encode(jsonEncode({'role': role, 'sub': 'test-sub'})));
          return '$header.$payload.fakeSignatureHere1234567890';
        }

        final privilegedCases = [
          ('JWT com role service_role', makeJwt('service_role')),
          ('JWT com role supabase_admin', makeJwt('supabase_admin')),
          ('JWT com role admin', makeJwt('admin')),
          ('JWT com role super_admin', makeJwt('super_admin')),
          ('JWT com role postgres', makeJwt('postgres')),
          ('Chave contendo texto service_role', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9_service_role_token_secret'),
          ('Personal management token sbp_', 'sbp_abcdef0123456789abcdef0123456789'),
        ];

        for (final (desc, key) in privilegedCases) {
          final config = AppConfig.create(
            environment: AppEnvironment.production,
            supabaseUrl: 'https://adversarial-target.supabase.co',
            supabaseAnonKey: key,
          );

          expect(config.isValid, isFalse, reason: 'Deveria ser inválida para: $desc');
          expect(config.isInvalid, isTrue, reason: 'isInvalid deve ser true para: $desc');
          expect(config.validationErrors, isNotEmpty, reason: 'Deve conter mensagens de erro para: $desc');
          expect(
            () => config.validateOrThrow(),
            throwsA(isA<AppConfigException>()),
            reason: 'validateOrThrow deve lançar AppConfigException para: $desc',
          );

          // Mascaramento seguro
          expect(config.maskedAnonKey, isNot(contains('service_role')));
          expect(config.maskedAnonKey, isNot(contains('secret')));
          expect(config.toDiagnosticString(), isNot(contains(key)));
        }
      });

      test('Sanitização absoluta de caminhos locais de áudio no payload (Windows e POSIX)', () {
        final payloads = [
          {
            'desc': 'Windows path com contra-barras',
            'raw': {
              'id': 'vn-win-01',
              'person_id': 'person-01',
              'transcription': 'Áudio gravado no Windows',
              'audio_file_path': r'C:\Users\vanes\AppData\Local\Packages\app\voice_notes\audio.m4a',
              'audioFilePath': r'C:\Users\vanes\AppData\Local\Packages\app\voice_notes\audio.m4a',
              '_base': {'something': 'old'},
              'baseData': {'something': 'old'},
              'audio_duration_seconds': 15,
            },
          },
          {
            'desc': 'iOS / macOS absolute sandbox path',
            'raw': {
              'id': 'vn-ios-01',
              'person_id': 'person-02',
              'transcription': 'Áudio gravado no iPhone',
              'audio_file_path': '/var/mobile/Containers/Data/Application/ABC-123/Documents/voice_notes/audio.m4a',
              'audioFilePath': '/var/mobile/Containers/Data/Application/ABC-123/Documents/voice_notes/audio.m4a',
              'audio_duration_seconds': 22,
            },
          },
          {
            'desc': 'Android internal storage path',
            'raw': {
              'id': 'vn-android-01',
              'person_id': 'person-03',
              'transcription': 'Áudio gravado no Android',
              'audio_file_path': '/data/user/0/com.ministeriopessoal/app_flutter/voice_notes/audio.m4a',
              'audioFilePath': '/data/user/0/com.ministeriopessoal/app_flutter/voice_notes/audio.m4a',
              'audio_duration_seconds': 30,
            },
          },
        ];

        for (final item in payloads) {
          final raw = item['raw'] as Map<String, dynamic>;
          final sanitized = SupabaseSyncService.sanitizePayload('voice_notes', raw);

          expect(sanitized.containsKey('audio_file_path'), isFalse, reason: '${item['desc']}: audio_file_path vazou');
          expect(sanitized.containsKey('audioFilePath'), isFalse, reason: '${item['desc']}: audioFilePath vazou');
          expect(sanitized.containsKey('_base'), isFalse, reason: '${item['desc']}: _base vazou');
          expect(sanitized.containsKey('baseData'), isFalse, reason: '${item['desc']}: baseData vazou');
          expect(sanitized['id'], equals(raw['id']));
          expect(sanitized['transcription'], equals(raw['transcription']));

          final remotePayload = SupabaseSyncService.toRemotePayload('voice_notes', raw);
          expect(remotePayload.containsKey('audio_file_path'), isFalse);
          expect(remotePayload.containsKey('audioFilePath'), isFalse);
          expect(remotePayload['id'], equals(raw['id']));
        }
      });
    });

    // =========================================================================
    // 2. Clean Installation Bootstrap (Scenario 10): 10 Tabelas Sincronizadas
    // =========================================================================
    group('2. Clean Installation Bootstrap (Scenario 10)', () {
      late AppDatabase freshDb;
      late AppRepository freshRepo;
      late Directory tempDir;

      setUp(() async {
        freshDb = AppDatabase.forTesting(NativeDatabase.memory());
        freshRepo = AppRepository(freshDb);
        tempDir = await Directory.systemTemp.createTemp('adv_bootstrap_');
      });

      tearDown(() async {
        await freshDb.close();
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });

      test('Dispositivo limpo puxa e popula integralmente todas as 10 tabelas sincronizadas', () async {
        final nowIso = DateTime.now().toUtc().toIso8601String();

        // 10 tabelas sincronizadas segundo matriz formal:
        final mockRemoteData = {
          'people': [
            {'id': 'p-adv-1', 'name': 'Adversarial Person', 'status': 'interessado', 'tags': '[]', 'created_at': nowIso, 'updated_at': nowIso, 'revision': 1},
          ],
          'visits': [
            {'id': 'v-adv-1', 'person_id': 'p-adv-1', 'date_time_field': nowIso, 'contact_type': 'revisita', 'result': 'feita', 'created_at': nowIso, 'updated_at': nowIso, 'revision': 1},
          ],
          'bible_studies': [
            {'id': 'bs-adv-1', 'title': 'Estudo Bíblico Bootstrap', 'status': 'ativo', 'started_at': nowIso, 'created_at': nowIso, 'updated_at': nowIso, 'revision': 1},
          ],
          'study_participants': [
            {'id': 'sp-adv-1', 'study_id': 'bs-adv-1', 'person_id': 'p-adv-1', 'created_at': nowIso, 'updated_at': nowIso, 'revision': 1},
          ],
          'study_sessions': [
            {'id': 'ss-adv-1', 'study_id': 'bs-adv-1', 'date_time_field': nowIso, 'status': 'realizado', 'created_at': nowIso, 'updated_at': nowIso, 'revision': 1},
          ],
          'appointments': [
            {'id': 'ap-adv-1', 'title': 'Agendamento Bootstrap', 'start_time': nowIso, 'duration_minutes': 45, 'status': 'planejado', 'created_at': nowIso, 'updated_at': nowIso, 'revision': 1},
          ],
          'activity_records': [
            {'id': 'ar-adv-1', 'date': nowIso, 'duration_minutes': 90, 'created_at': nowIso, 'updated_at': nowIso, 'revision': 1},
          ],
          'voice_notes': [
            {'id': 'vn-adv-1', 'person_id': 'p-adv-1', 'transcription': 'Nota de voz bootstrap', 'created_at': nowIso, 'updated_at': nowIso, 'revision': 1},
          ],
          'phone_contacts': [
            {'id': 'pc-adv-1', 'name': 'Contato Telefônico Bootstrap', 'phone': '11988887777', 'created_at': nowIso, 'updated_at': nowIso, 'revision': 1},
          ],
          'territory_landmarks': [
            {'id': 'tl-adv-1', 'name': 'Marco de Território Bootstrap', 'latitude': -22.9, 'longitude': -43.2, 'created_at': nowIso, 'updated_at': nowIso, 'revision': 1},
          ],
        };

        final mockClient = MockClient((request) async {
          final path = request.url.path;
          for (final entry in mockRemoteData.entries) {
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
          httpClient: mockClient,
        );

        final syncService = SupabaseSyncService(
          db: freshDb,
          repository: freshRepo,
          config: testConfig,
          clientOverride: client,
          documentsDirectoryProvider: () async => tempDir.path,
        );
        addTearDown(syncService.dispose);

        // Executa fetchRemoteChanges em base limpa
        final result = await syncService.fetchRemoteChanges();
        if (result.errors.isNotEmpty) {
          // ignore: avoid_print
          print('Group 2 debug errors: ${result.errors}, message: ${result.message}');
        }
        expect(result.errors, isEmpty, reason: 'Errors: ${result.errors}');
        expect(result.success, isTrue);
        expect(result.totalProcessed, equals(10));
        expect(result.successCount, equals(10));

        // Verifica presença física em cada uma das 10 tabelas Drift locais
        final p = await freshRepo.getPersonById('p-adv-1');
        expect(p, isNotNull);

        final v = await (freshDb.select(freshDb.visits)..where((t) => t.id.equals('v-adv-1'))).getSingleOrNull();
        expect(v, isNotNull);

        final bs = await (freshDb.select(freshDb.bibleStudies)..where((t) => t.id.equals('bs-adv-1'))).getSingleOrNull();
        expect(bs, isNotNull);

        final sp = await (freshDb.select(freshDb.studyParticipants)..where((t) => t.id.equals('sp-adv-1'))).getSingleOrNull();
        expect(sp, isNotNull);

        final ss = await (freshDb.select(freshDb.studySessions)..where((t) => t.id.equals('ss-adv-1'))).getSingleOrNull();
        expect(ss, isNotNull);

        final ap = await freshRepo.getAppointmentById('ap-adv-1');
        expect(ap, isNotNull);

        final ar = await (freshDb.select(freshDb.activityRecords)..where((t) => t.id.equals('ar-adv-1'))).getSingleOrNull();
        expect(ar, isNotNull);

        final vn = await (freshDb.select(freshDb.voiceNotes)..where((t) => t.id.equals('vn-adv-1'))).getSingleOrNull();
        expect(vn, isNotNull);

        final pc = await (freshDb.select(freshDb.phoneContacts)..where((t) => t.id.equals('pc-adv-1'))).getSingleOrNull();
        expect(pc, isNotNull);

        final tl = await (freshDb.select(freshDb.territoryLandmarks)..where((t) => t.id.equals('tl-adv-1'))).getSingleOrNull();
        expect(tl, isNotNull);
      });
    });

    // =========================================================================
    // 3. Session Expiration & Failure Recovery (Scenario 9)
    // =========================================================================
    group('3. Backoff Jitter & Session Failure Recovery', () {
      test('Algoritmo de backoff exponencial com jitter é estritamente limitado e matematicamente estável', () {
        // Teste de determinismo com sementes fixas de Random
        final zeroRng = Random(42);

        // attempts <= 0 => 0
        expect(SupabaseSyncService.calculateBackoffSeconds(-5, random: zeroRng), equals(0));
        expect(SupabaseSyncService.calculateBackoffSeconds(0, random: zeroRng), equals(0));

        // attempts = 1: base 2^1 = 2, jitter 0..0.5 (arredondado para 0 ou 1) => 2..3
        final b1 = SupabaseSyncService.calculateBackoffSeconds(1, random: zeroRng);
        expect(b1, inInclusiveRange(2, 3));

        // attempts = 2: base 2^2 = 4, jitter 0..1 => 4..5
        final b2 = SupabaseSyncService.calculateBackoffSeconds(2, random: zeroRng);
        expect(b2, inInclusiveRange(4, 5));

        // attempts = 3: base 2^3 = 8, jitter 0..2 => 8..10
        final b3 = SupabaseSyncService.calculateBackoffSeconds(3, random: zeroRng);
        expect(b3, inInclusiveRange(8, 10));

        // attempts = 5: base 2^5 = 32, jitter 0..8 => 32..40
        final b5 = SupabaseSyncService.calculateBackoffSeconds(5, random: zeroRng);
        expect(b5, inInclusiveRange(32, 40));

        // attempts = 8: base 2^8 = 256, jitter 0..64 => clampado a 300
        final b8 = SupabaseSyncService.calculateBackoffSeconds(8, random: zeroRng);
        expect(b8, inInclusiveRange(256, 300));

        // attempts muito grandes: clamp rígido a 300s
        for (final att in [9, 10, 20, 100, 1000]) {
          final clamped = SupabaseSyncService.calculateBackoffSeconds(att, random: zeroRng);
          expect(clamped, inInclusiveRange(256, 300));
          expect(clamped, lessThanOrEqualTo(300));
        }
      });

      test('Recuperação de falha com retenção de fila e re-execução íntegra', () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final repo = AppRepository(db);
        final tempDir = await Directory.systemTemp.createTemp('adv_recovery_');
        addTearDown(() async {
          await db.close();
          if (await tempDir.exists()) await tempDir.delete(recursive: true);
        });

        bool serverShouldFail = true;
        final serverRows = <String, Map<String, dynamic>>{};

        final mockClient = MockClient((req) async {
          if (serverShouldFail) {
            throw const SocketException('Connection aborted / Network unreachable');
          }
          if (req.method == 'POST') {
            final body = jsonDecode(req.body);
            final items = body is List ? body : [body];
            for (final item in items) {
              final map = Map<String, dynamic>.from(item as Map);
              serverRows[map['id'] as String] = map;
            }
            return http.Response(jsonEncode(items), 200, request: req, headers: {'content-type': 'application/json'});
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
          httpClient: mockClient,
        );

        final sync = SupabaseSyncService(
          db: db,
          repository: repo,
          config: testConfig,
          clientOverride: client,
          documentsDirectoryProvider: () async => tempDir.path,
        );
        addTearDown(sync.dispose);

        // Cria 2 itens na fila
        await repo.createPerson(id: 'p-fail-1', name: 'Item 1');
        await repo.createPerson(id: 'p-fail-2', name: 'Item 2');

        // Primeira tentativa com falha de rede
        serverShouldFail = true;
        final failResult = await sync.processQueue();
        expect(failResult.successCount, equals(0));
        expect(sync.currentStatus, equals(SyncStatus.waitingConnection));

        // Garante que a fila reteve os itens e registrou tentativa
        final pending = await repo.getPendingSyncOperations();
        expect(pending.length, equals(2));
        expect(pending.first.attempts, greaterThanOrEqualTo(1));

        // Rede restabelecida
        serverShouldFail = false;
        SupabaseInitializer.setMockStateForTesting(
          state: SupabaseConnectionState.connected,
          config: testConfig,
        );

        // Processa ignorando backoff
        final recoverResult = await sync.processQueue(ignoreBackoff: true);
        if (recoverResult.errors.isNotEmpty || recoverResult.successCount == 0) {
          // ignore: avoid_print
          print('Group 3 debug: successCount=${recoverResult.successCount}, failureCount=${recoverResult.failureCount}, errors=${recoverResult.errors}, message=${recoverResult.message}');
        }
        expect(recoverResult.successCount, equals(2));
        expect(sync.currentStatus, equals(SyncStatus.synced));

        // Ambos os itens chegaram ao servidor
        expect(serverRows.containsKey('p-fail-1'), isTrue);
        expect(serverRows.containsKey('p-fail-2'), isTrue);

        // Fila esvaziada
        final remaining = await repo.getPendingSyncOperations();
        expect(remaining, isEmpty);
      });
    });
  });
}
