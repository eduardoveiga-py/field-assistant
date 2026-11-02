import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/core/app_config.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/sync/supabase_sync_service.dart';
import 'package:ministerio_pessoal/sync/sync_engine.dart';

void main() {
  // Helper para criar JWTs de teste com payloads específicos
  String createTestJwt(Map<String, dynamic> payload) {
    final header = base64Url
        .encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})))
        .replaceAll('=', '');
    final body = base64Url
        .encode(utf8.encode(jsonEncode(payload)))
        .replaceAll('=', '');
    const sig = 'mock_signature_test_1234567890';
    return '$header.$body.$sig';
  }

  final validAnonJwt = createTestJwt({
    'role': 'anon',
    'iss': 'supabase',
    'exp': 1999999999,
  });

  final serviceRoleJwt = createTestJwt({
    'role': 'service_role',
    'iss': 'supabase',
    'exp': 1999999999,
  });

  group('Unidade U1 — AppConfig e Injeção de Ambiente', () {
    // -------------------------------------------------------------------------
    // 1. Configuração Válida
    // -------------------------------------------------------------------------
    test('1. Configuração válida: URL https e anon key são aprovadas e dados sensíveis mascarados', () {
      final config = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://xyzcompany.supabase.co/',
        supabaseAnonKey: validAnonJwt,
      );

      expect(config.isValid, isTrue);
      expect(config.isConfigured, isTrue);
      expect(config.isOfflineOnly, isFalse);
      expect(config.status, equals(ConfigStatus.valid));
      expect(config.validationErrors, isEmpty);
      expect(config.validationErrorMessage, isNull);

      // Normalização: barra final removida
      expect(config.supabaseUrl, equals('https://xyzcompany.supabase.co'));

      // Verificação de não vazamento de segredos em logs e toString
      expect(config.maskedAnonKey, isNot(equals(validAnonJwt)));
      expect(config.maskedAnonKey, contains('...'));
      expect(config.toString(), isNot(contains(validAnonJwt)));
      expect(config.toDiagnosticString(), contains(config.maskedAnonKey));

      // Não lança exceção em validação
      expect(() => config.validateOrThrow(), returnsNormally);
      expect(
        () => config.validateOrThrow(requireConfigured: true),
        returnsNormally,
      );
    });

    // -------------------------------------------------------------------------
    // 2. URL Vazia
    // -------------------------------------------------------------------------
    test('2. URL vazia: quando chave é fornecida mas URL é vazia, rejeita com erro explícito', () {
      final config = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: '',
        supabaseAnonKey: validAnonJwt,
      );

      expect(config.isValid, isFalse);
      expect(config.isConfigured, isFalse);
      expect(config.isOfflineOnly, isFalse);
      expect(config.status, equals(ConfigStatus.invalid));
      expect(
        config.validationErrors,
        anyElement(contains('SUPABASE_URL não pode ser vazia')),
      );

      expect(
        () => config.validateOrThrow(),
        throwsA(
          isA<AppConfigException>().having(
            (e) => e.message,
            'message',
            contains('SUPABASE_URL não pode ser vazia'),
          ),
        ),
      );

      // Variação com apenas espaços em branco
      final whitespaceConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: '   ',
        supabaseAnonKey: validAnonJwt,
      );
      expect(whitespaceConfig.isValid, isFalse);
      expect(
        whitespaceConfig.validationErrors,
        anyElement(contains('SUPABASE_URL não pode ser vazia')),
      );
    });

    // -------------------------------------------------------------------------
    // 3. Chave Ausente
    // -------------------------------------------------------------------------
    test('3. Chave ausente: quando URL é fornecida mas chave anon é vazia, rejeita com erro explícito', () {
      final config = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://xyzcompany.supabase.co',
        supabaseAnonKey: '',
      );

      expect(config.isValid, isFalse);
      expect(config.isConfigured, isFalse);
      expect(config.isOfflineOnly, isFalse);
      expect(config.status, equals(ConfigStatus.invalid));
      expect(
        config.validationErrors,
        anyElement(contains('SUPABASE_ANON_KEY não pode ser vazia')),
      );

      expect(
        () => config.validateOrThrow(),
        throwsA(
          isA<AppConfigException>().having(
            (e) => e.message,
            'message',
            contains('SUPABASE_ANON_KEY não pode ser vazia'),
          ),
        ),
      );

      // Variação com espaços em branco
      final whitespaceConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://xyzcompany.supabase.co',
        supabaseAnonKey: '   ',
      );
      expect(whitespaceConfig.isValid, isFalse);
      expect(
        whitespaceConfig.validationErrors,
        anyElement(contains('SUPABASE_ANON_KEY não pode ser vazia')),
      );
    });

    // -------------------------------------------------------------------------
    // 4. URL Inválida
    // -------------------------------------------------------------------------
    test('4. URL inválida: rejeita strings malformadas, protocolos inseguros, query params ou userInfo', () {
      // 4.1 URL sem host ou sintaxe corrompida
      final malformedConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'not_a_valid_url',
        supabaseAnonKey: validAnonJwt,
      );
      expect(malformedConfig.isValid, isFalse);
      expect(
        malformedConfig.validationErrors,
        anyElement(contains('SUPABASE_URL inválida')),
      );

      // 4.2 Protocolo não suportado (ex: ftp)
      final ftpConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'ftp://xyzcompany.supabase.co',
        supabaseAnonKey: validAnonJwt,
      );
      expect(ftpConfig.isValid, isFalse);
      expect(
        ftpConfig.validationErrors,
        anyElement(contains('possui protocolo não suportado')),
      );

      // 4.3 Placeholder de exemplo não alterado
      final placeholderConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://your-supabase-url.supabase.co',
        supabaseAnonKey: validAnonJwt,
      );
      expect(placeholderConfig.isValid, isFalse);
      expect(
        placeholderConfig.validationErrors,
        anyElement(contains('contém placeholder de exemplo')),
      );

      // 4.4 Proibição de credenciais Basic Auth / UserInfo na URL (protege contra vazamentos)
      final userInfoConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://admin:supersecretpassword@xyzcompany.supabase.co',
        supabaseAnonKey: validAnonJwt,
      );
      expect(userInfoConfig.isValid, isFalse);
      expect(
        userInfoConfig.validationErrors,
        anyElement(contains('não pode conter credenciais de usuário')),
      );
      // toDiagnosticString() mascara as credenciais de usuário
      expect(
        userInfoConfig.toDiagnosticString(),
        isNot(contains('supersecretpassword')),
      );
      expect(userInfoConfig.toDiagnosticString(), contains('***:***'));

      // 4.5 Proibição de Query Parameters e Fragmentos
      final queryParamConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://xyzcompany.supabase.co?token=secret123#frag',
        supabaseAnonKey: validAnonJwt,
      );
      expect(queryParamConfig.isValid, isFalse);
      expect(
        queryParamConfig.validationErrors,
        anyElement(contains('não deve conter parâmetros de consulta')),
      );
      expect(
        queryParamConfig.validationErrors,
        anyElement(contains('não deve conter fragmentos')),
      );
    });

    // -------------------------------------------------------------------------
    // 5. Configuração de Homologação
    // -------------------------------------------------------------------------
    test('5. Configuração de homologação: valida parsing de staging/homolog, permite localhost e exige HTTPS remoto', () {
      final envHomolog = AppEnvironment.fromString('homolog');
      final envStaging = AppEnvironment.fromString('staging');
      final envStage = AppEnvironment.fromString('stage');

      expect(envHomolog, equals(AppEnvironment.homologation));
      expect(envStaging, equals(AppEnvironment.homologation));
      expect(envStage, equals(AppEnvironment.homologation));
      expect(envHomolog.isHomologation, isTrue);
      expect(envHomolog.isProduction, isFalse);
      expect(envHomolog.isDevelopment, isFalse);

      // Homologação com HTTPS válido é aceita
      final validHomolog = AppConfig.create(
        environment: envHomolog,
        supabaseUrl: 'https://staging-project.supabase.co',
        supabaseAnonKey: validAnonJwt,
      );
      expect(validHomolog.isValid, isTrue);

      // Homologação rejeita HTTP inseguro em endpoints remotos
      final insecureHomolog = AppConfig.create(
        environment: envHomolog,
        supabaseUrl: 'http://staging-project.supabase.co',
        supabaseAnonKey: validAnonJwt,
      );
      expect(insecureHomolog.isValid, isFalse);
      expect(
        insecureHomolog.validationErrors,
        anyElement(contains('deve obrigatoriamente utilizar HTTPS')),
      );

      // Homologação permite localhost para testes locais de QA
      final localhostHomolog = AppConfig.create(
        environment: envHomolog,
        supabaseUrl: 'http://localhost:54321',
        supabaseAnonKey: validAnonJwt,
      );
      expect(localhostHomolog.isValid, isTrue);
    });

    // -------------------------------------------------------------------------
    // 6. Configuração de Produção
    // -------------------------------------------------------------------------
    test('6. Configuração de produção: rejeita HTTP inseguro (inclusive localhost), chaves com espaços e chaves privilegiadas', () {
      final envProd = AppEnvironment.fromString('prod');
      final envProduction = AppEnvironment.fromString('production');

      expect(envProd, equals(AppEnvironment.production));
      expect(envProduction, equals(AppEnvironment.production));
      expect(envProd.isProduction, isTrue);

      // 6.1 Produção com HTTPS válido é aceita
      final validProd = AppConfig.create(
        environment: envProd,
        supabaseUrl: 'https://prod-secure.supabase.co',
        supabaseAnonKey: validAnonJwt,
      );
      expect(validProd.isValid, isTrue);
      expect(validProd.isConfigured, isTrue);

      // 6.2 Produção rejeita HTTP inseguro em endpoints remotos
      final insecureProd = AppConfig.create(
        environment: envProd,
        supabaseUrl: 'http://prod-secure.supabase.co',
        supabaseAnonKey: validAnonJwt,
      );
      expect(insecureProd.isValid, isFalse);
      expect(
        insecureProd.validationErrors,
        anyElement(contains('deve obrigatoriamente utilizar HTTPS')),
      );

      // 6.2.1 Produção ESTRITAMENTE rejeita HTTP mesmo em localhost (garantia de produção real)
      final insecureLocalhostProd = AppConfig.create(
        environment: envProd,
        supabaseUrl: 'http://localhost:54321',
        supabaseAnonKey: validAnonJwt,
      );
      expect(insecureLocalhostProd.isValid, isFalse);
      expect(
        insecureLocalhostProd.validationErrors,
        anyElement(contains('deve obrigatoriamente utilizar HTTPS')),
      );

      // 6.3 Rejeição de chave privilegiada service_role (JWT decodificado)
      final serviceRoleConfig = AppConfig.create(
        environment: envProd,
        supabaseUrl: 'https://prod-secure.supabase.co',
        supabaseAnonKey: serviceRoleJwt,
      );
      expect(serviceRoleConfig.isValid, isFalse);
      expect(
        serviceRoleConfig.validationErrors,
        anyElement(contains('Credencial privilegiada (service_role')),
      );

      // 6.3.1 Rejeição de service_role JWT cujo payload base64url contém '-' ou '_'
      final jsonWithSpecialChars = jsonEncode({
        'role': 'service_role',
        'iss': 'supabase',
        'ref': 'project_ref_test',
        'tag': '\u07ff\uffff\u07be',
      });
      final b64UrlSpecial = base64Url
          .encode(utf8.encode(jsonWithSpecialChars))
          .replaceAll('=', '');
      final jwtWithDashes = 'eyJhbGciOiJIUzI1NiJ9.$b64UrlSpecial.sig1234567890';
      final serviceRoleWithDashesConfig = AppConfig.create(
        environment: envProd,
        supabaseUrl: 'https://prod-secure.supabase.co',
        supabaseAnonKey: jwtWithDashes,
      );
      expect(
        serviceRoleWithDashesConfig.isValid,
        isFalse,
        reason: 'JWT com base64url contendo - ou _ deve ser decodificado e rejeitado se for service_role',
      );
      expect(
        serviceRoleWithDashesConfig.validationErrors,
        anyElement(contains('Credencial privilegiada (service_role')),
      );

      // 6.3.2 Rejeição de roles privilegiadas adicionais (postgres, admin, super_admin, supabase_admin)
      for (final privRole in [
        'postgres',
        'admin',
        'super_admin',
        'supabase_admin',
        'SERVICE_ROLE',
      ]) {
        final privJwt = createTestJwt({'role': privRole, 'iss': 'supabase'});
        final privConfig = AppConfig.create(
          environment: envProd,
          supabaseUrl: 'https://prod-secure.supabase.co',
          supabaseAnonKey: privJwt,
        );
        expect(
          privConfig.isValid,
          isFalse,
          reason: 'Role privilegiada $privRole deve ser rejeitada',
        );
        expect(
          privConfig.validationErrors,
          anyElement(contains('Credencial privilegiada')),
        );
      }

      // 6.4 Rejeição de token de gerenciamento pessoal (sbp_...)
      final sbpTokenConfig = AppConfig.create(
        environment: envProd,
        supabaseUrl: 'https://prod-secure.supabase.co',
        supabaseAnonKey: 'sbp_0123456789abcdef0123456789abcdef',
      );
      expect(sbpTokenConfig.isValid, isFalse);
      expect(
        sbpTokenConfig.validationErrors,
        anyElement(contains('Credencial privilegiada')),
      );

      // 6.5 Rejeição de chave com substring de service_role explícito
      final explicitServiceConfig = AppConfig.create(
        environment: envProd,
        supabaseUrl: 'https://prod-secure.supabase.co',
        supabaseAnonKey: 'eyJhbGciOiJIUzI1NiJ9.service_role_secret_key_prohibited_here_123456',
      );
      expect(explicitServiceConfig.isValid, isFalse);
      expect(
        explicitServiceConfig.validationErrors,
        anyElement(contains('Credencial privilegiada')),
      );

      // 6.6 Rejeição de chave muito curta
      final shortKeyConfig = AppConfig.create(
        environment: envProd,
        supabaseUrl: 'https://prod-secure.supabase.co',
        supabaseAnonKey: 'short_key_123',
      );
      expect(shortKeyConfig.isValid, isFalse);
      expect(
        shortKeyConfig.validationErrors,
        anyElement(contains('muito curta ou incompleta')),
      );

      // 6.7 Rejeição de chave com espaços em branco ou quebras de linha internas
      final keyWithNewlineConfig = AppConfig.create(
        environment: envProd,
        supabaseUrl: 'https://prod-secure.supabase.co',
        supabaseAnonKey:
            'eyJhbGciOiJIUzI1NiJ9.\n eyJyb2xlIjoiYW5vbiJ9.sig_sample_12345',
      );
      expect(keyWithNewlineConfig.isValid, isFalse);
      expect(
        keyWithNewlineConfig.validationErrors,
        anyElement(contains('espaços em branco ou quebras de linha')),
      );

      // 6.8 Diagnóstico de configuração inválida exibe lista de erros
      expect(keyWithNewlineConfig.toDiagnosticString(), contains('errors: ['));
    });

    // -------------------------------------------------------------------------
    // 7. Build Sem Configuração Remota
    // -------------------------------------------------------------------------
    test('7. Build sem configuração remota: inicializa com sucesso em modo puramente offline', () {
      final offlineConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: '',
        supabaseAnonKey: '',
      );

      expect(offlineConfig.status, equals(ConfigStatus.unconfigured));
      expect(offlineConfig.isOfflineOnly, isTrue);
      expect(offlineConfig.isConfigured, isFalse);
      expect(offlineConfig.isValid, isTrue); // Válido para modo offline!
      expect(offlineConfig.isInvalid, isFalse);
      expect(offlineConfig.validationErrors, isEmpty);
      expect(offlineConfig.validationErrorMessage, isNull);
      expect(offlineConfig.maskedAnonKey, equals('(não configurada)'));
      expect(offlineConfig.maskedUrl, equals('(vazio)'));

      // Validação padrão não lança exceção para offline
      expect(() => offlineConfig.validateOrThrow(), returnsNormally);

      // Validação estrita que exige remoto lança exceção com explicação clara
      expect(
        () => offlineConfig.validateOrThrow(requireConfigured: true),
        throwsA(
          isA<AppConfigException>().having(
            (e) => e.message,
            'message',
            contains('Configuração remota ausente'),
          ),
        ),
      );
    });

    // -------------------------------------------------------------------------
    // 8. Garantia de que o Modo Offline Continua Funcionando
    // -------------------------------------------------------------------------
    test('8. Garantia de que o modo offline continua funcionando: SQLite e repositório operam normalmente', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = AppRepository(db);
      final offlineConfig = AppConfig.create(
        environment: AppEnvironment.development,
        supabaseUrl: '',
        supabaseAnonKey: '',
      );

      final syncService = SupabaseSyncService(
        db: db,
        repository: repo,
        config: offlineConfig,
      );

      expect(syncService.isConfigured, isFalse);
      expect(syncService.config.isOfflineOnly, isTrue);
      expect(syncService.supabaseUrl, isEmpty);
      expect(syncService.supabaseAnonKey, isEmpty);

      // 8.1 Criação local de pessoa funciona com 100% de integridade
      final person = await repo.createPerson(
        name: 'Carlos Oliveira',
        phone: '11999998888',
        generalNotes: 'Estudante pontual',
      );
      expect(person.id, isNotEmpty);
      expect(person.name, equals('Carlos Oliveira'));

      // 8.2 Consulta direta ao SQLite Drift confirma persistência local imediata
      final storedPeople = await repo.watchAllPeople().first;
      expect(storedPeople.length, equals(1));
      expect(storedPeople.first.name, equals('Carlos Oliveira'));

      // 8.3 Mutação local gerou entrada na outbox (sync_queue)
      final queueItems = await (db.select(db.syncQueue)).get();
      expect(queueItems.length, equals(1));
      expect(queueItems.first.entityType, equals('people'));
      expect(queueItems.first.entityId, equals(person.id));

      // 8.4 processQueue() em modo offline preserva a fila sem apagar ou corromper dados
      final processResult = await syncService.processQueue();
      expect(processResult.totalProcessed, equals(1));
      expect(processResult.successCount, equals(0));
      expect(processResult.message, contains('não configurado'));
      expect(processResult.message, contains('mantidos salvos localmente'));
      expect(syncService.currentStatus, equals(SyncStatus.savedLocally));

      // Fila permanece intacta no SQLite
      final queueItemsAfter = await (db.select(db.syncQueue)).get();
      expect(queueItemsAfter.length, equals(1));

      // 8.5 fetchRemoteChanges() em modo offline não falha com crash
      final fetchResult = await syncService.fetchRemoteChanges();
      expect(fetchResult.totalProcessed, equals(0));
      expect(fetchResult.message, contains('não configurado'));

      // 8.6 Distinção explícita entre Configuração Ausente e Falha de Conexão
      expect(
        syncService.config.isOfflineOnly,
        isTrue,
        reason: 'Configuração ausente é intencional',
      );
      expect(syncService.config.isConfigured, isFalse);

      syncService.dispose();
      await db.close();
    });

    // -------------------------------------------------------------------------
    // 9. Construtor e Delegação do SupabaseSyncService
    // -------------------------------------------------------------------------
    test('9. SupabaseSyncService delega campos exclusivamente para AppConfig sem divergência', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = AppRepository(db);

      // Construtor com supabaseUrl e supabaseAnonKey legados instancia AppConfig internamente
      final legacySyncService = SupabaseSyncService(
        db: db,
        repository: repo,
        supabaseUrl: '  https://legacy.supabase.co/  ',
        supabaseAnonKey: validAnonJwt,
      );

      // Normalizado sem barra e sem espaços extras
      expect(
        legacySyncService.supabaseUrl,
        equals('https://legacy.supabase.co'),
      );
      expect(
        legacySyncService.config.supabaseUrl,
        equals('https://legacy.supabase.co'),
      );
      expect(legacySyncService.supabaseAnonKey, equals(validAnonJwt));
      expect(legacySyncService.isConfigured, isTrue);

      legacySyncService.dispose();
      await db.close();
    });
  });
}
