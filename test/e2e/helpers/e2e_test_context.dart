import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/settings/app_settings_manager.dart';
import 'package:ministerio_pessoal/sync/supabase_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Contexto de teste isolado e hermético para testes E2E.
///
/// Encapsula:
/// - Banco de dados Drift em memória com chave estrangeira ativada (`PRAGMA foreign_keys = ON;`).
/// - Supressão de avisos de múltiplos bancos Drift em execução concorrente.
/// - Instâncias atômicas de [AppRepository] e [AppSettingsManager].
/// - [SupabaseSyncService] desacoplado com [MockClient] em memória para PostgREST, Storage e RPC.
/// - Diretório temporário dedicado por teste com limpeza garantida no [dispose].
class E2ETestContext {
  final AppDatabase db;
  final AppRepository repo;
  final AppSettingsManager settings;
  final SupabaseSyncService syncService;
  final Directory tempDir;
  final MockClient mockHttpClient;
  final SupabaseClient supabaseClient;

  E2ETestContext({
    required this.db,
    required this.repo,
    required this.settings,
    required this.syncService,
    required this.tempDir,
    required this.mockHttpClient,
    required this.supabaseClient,
  });

  /// Cria uma nova instância isolada de [E2ETestContext].
  ///
  /// Opcionalmente recebe [mockHttpHandler] para customizar as respostas HTTP da simulação
  /// do Supabase PostgREST / Storage / RPC.
  static Future<E2ETestContext> create({
    Future<http.Response> Function(http.Request request)? mockHttpHandler,
    String? supabaseUrl,
    String? supabaseAnonKey,
  }) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

    final db = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON;');
        },
      ),
    );

    final repo = AppRepository(db);
    final settings = AppSettingsManager(db);
    final tempDir = await Directory.systemTemp.createTemp('e2e_test_');

    final handler = mockHttpHandler ??
        (http.Request request) async {
          final path = request.url.path;
          if (path.contains('/storage/v1/object')) {
            return http.Response(
              '{"Key":"mock_storage_object"}',
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (path.contains('/rest/v1/rpc/sync_upsert')) {
            return http.Response(
              '{"success": true, "processed_count": 1, "errors": []}',
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            '[]',
            200,
            headers: {
              'content-type': 'application/json',
              'content-range': '*/0',
            },
          );
        };

    final mockClient = MockClient(handler);
    final effectiveUrl = supabaseUrl ?? 'https://mock.supabase.co';
    final effectiveKey = supabaseAnonKey ?? 'dummy-anon-key-e2e';

    final supabaseClient = SupabaseClient(
      effectiveUrl,
      effectiveKey,
      httpClient: mockClient,
    );

    final syncService = SupabaseSyncService(
      db: db,
      repository: repo,
      supabaseUrl: effectiveUrl,
      supabaseAnonKey: effectiveKey,
      clientOverride: supabaseClient,
      documentsDirectoryProvider: () async => tempDir.path,
    );

    return E2ETestContext(
      db: db,
      repo: repo,
      settings: settings,
      syncService: syncService,
      tempDir: tempDir,
      mockHttpClient: mockClient,
      supabaseClient: supabaseClient,
    );
  }

  /// Cria um arquivo temporário com os [bytes] especificados dentro do [tempDir].
  Future<File> createTempFile(String relativePath, List<int> bytes) async {
    final file = File('${tempDir.path}/$relativePath');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Encerra todos os serviços, fecha as conexões com o banco SQLite em memória
  /// e remove o diretório temporário isolado.
  Future<void> dispose() async {
    syncService.dispose();
    await db.close();
    if (await tempDir.exists()) {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {
        // Tratamento silencioso caso o sistema operacional retenha o arquivo temporariamente.
      }
    }
  }
}
