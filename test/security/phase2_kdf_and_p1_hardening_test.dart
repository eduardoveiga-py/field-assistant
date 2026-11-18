import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/core/app_theme.dart';
import 'package:ministerio_pessoal/core/biometric_auth_service.dart';
import 'package:ministerio_pessoal/core/feature_registry.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/settings/backup_service.dart';
import 'package:ministerio_pessoal/territory/map_engine_adapter.dart';
import 'package:ministerio_pessoal/ui/main_navigation_shell.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/voice_notes/voice_dictation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('FA-SEC-07: PIN PBKDF2-HMAC-SHA256 & Legacy Transparent Upgrade', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('setPin grava KDF PBKDF2-HMAC-SHA256 com 100.000 iterações calibradas por padrão', () async {
      final auth = BiometricAuthService();
      expect(await auth.setPin('2468'), isTrue);

      const storage = FlutterSecureStorage();
      final kdf = await storage.read(key: 'app_security_pin_kdf');
      final hash = await storage.read(key: 'app_security_pin_hash');
      final salt = await storage.read(key: 'app_security_pin_salt');

      expect(kdf, equals('pbkdf2_hmac_sha256:100000'));
      expect(salt?.length, equals(32));
      expect(hash?.length, equals(64));
      // Deve diferir do antigo SHA-256 de 1 rodada
      final legacySha = sha256.convert(utf8.encode('$salt:2468')).toString();
      expect(hash, isNot(equals(legacySha)));

      auth.lockSession();
      expect(await auth.verifyPin('9999'), isFalse);
      expect(await auth.verifyPin('2468'), isTrue);
    });

    test('verifyPin valida hash legado SHA-256 e faz upgrade transparente para PBKDF2', () async {
      const legacySalt = '00112233445566778899aabbccddeeff';
      final legacyHash = sha256.convert(utf8.encode('$legacySalt:1357')).toString();
      FlutterSecureStorage.setMockInitialValues({
        'app_security_pin_salt': legacySalt,
        'app_security_pin_hash': legacyHash,
      });

      final auth = BiometricAuthService(pbkdf2Iterations: 5000);
      expect(await auth.verifyPin('1357'), isTrue);

      const storage = FlutterSecureStorage();
      expect(
        await storage.read(key: 'app_security_pin_kdf'),
        equals('pbkdf2_hmac_sha256:5000'),
      );
      expect(
        await storage.read(key: 'app_security_pin_hash'),
        isNot(equals(legacyHash)),
      );

      // Valida que o PIN continua funcionando após o upgrade transparente
      auth.lockSession();
      expect(await auth.verifyPin('1357'), isTrue);
    });
  });

  group('FA-SEC-07: Backup v3 em Isolate (>=600.000 iterações)', () {
    late AppDatabase db;
    late AppRepository repo;
    late BackupService backup;
    late Directory docsDir;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      docsDir = await Directory.systemTemp.createTemp('bak_v3_test_');
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = AppRepository(db);
      backup = BackupService(
        repo,
        documentsDirectoryProvider: () async => docsDir,
      );
    });

    tearDown(() async {
      await db.close();
      if (await docsDir.exists()) await docsDir.delete(recursive: true);
    });

    test(
      'exportEncryptedBackupV3 exige >=600k iterações, gera v3 e restaura com integridade',
      timeout: const Timeout(Duration(seconds: 90)),
      () async {
      await expectLater(
        () => backup.exportEncryptedBackupV3('SenhaForte#2026', iterations: 100000),
        throwsArgumentError,
      );

      await repo.createPerson(name: 'Teste Backup V3');
      final exported = await backup.exportEncryptedBackupV3('SenhaForte#2026');
      final decoded = jsonDecode(exported) as Map<String, dynamic>;
      expect(decoded['version'], equals(3));
      expect(decoded['kdf'], equals('PBKDF2-HMAC-SHA256'));
      expect(decoded['iterations'], equals(600000));

      final preview = await backup.previewBackup(
        encryptedDataString: exported,
        password: 'SenhaForte#2026',
      );
      expect(preview.isIntegral, isTrue);

      // Senha incorreta falha com FormatException
      await expectLater(
        () => backup.previewBackup(
          encryptedDataString: exported,
          password: 'SenhaErrada',
        ),
        throwsFormatException,
      );
    });
  });

  group('FA-FUNC-01 & FA-IOS-02 & FA-MAP-02: Coerência de Módulos, Ditado e Manifesto de Mapas', () {
    test('FeatureRegistry governa Inbox, Tarefas/Projetos e Base de Conhecimento sem perder dados', () {
      expect(AppFeature.fromId('inbox'), equals(AppFeature.inbox));
      expect(AppFeature.fromId('tasks_projects'), equals(AppFeature.tasksProjects));
      expect(AppFeature.fromId('knowledge'), equals(AppFeature.knowledge));

      expect(FeatureRegistry.isFeatureEnabled('inbox', const {}), isTrue);
      expect(
        FeatureRegistry.isFeatureEnabled(
          'inbox',
          {FeatureRegistry.settingKey(AppFeature.inbox): 'false'},
        ),
        isFalse,
      );
      expect(
        FeatureRegistry.isFeatureEnabled(
          'tasks_projects',
          {FeatureRegistry.settingKey(AppFeature.tasksProjects): 'false'},
        ),
        isFalse,
      );
      expect(
        FeatureRegistry.isFeatureEnabled(
          'knowledge',
          {FeatureRegistry.settingKey(AppFeature.knowledge): 'false'},
        ),
        isFalse,
      );
    });

    test('VoiceDictationService declara limitação honesta para Ticuna on-device', () async {
      expect(VoiceDictationService.supportsTicunaOnDevice, isFalse);
      final svc = LocalVoiceDictationService();
      String? errorMsg;
      await svc.startListening(
        localeId: 'tca_BR',
        preferOnDevice: true,
        onResult: (_) {},
        onError: (msg) => errorMsg = msg,
      );
      expect(errorMsg, isNotNull);
      expect(errorMsg, contains('Ticuna'));
      expect(svc.isListening, isFalse);
    });

    test('OfflineMapPackageManifest valida SHA-256, ODbL e rejeita URLs mutáveis ou OSM público', () {
      final bytes = Uint8List.fromList(utf8.encode('FAKE_PMTILES_HEADER_DATA'));
      final digest = sha256.convert(bytes).toString();
      final valid = OfflineMapPackageManifest(
        id: 'br_am_solimoes',
        regionName: 'Alto Solimões (AM)',
        downloadUrl: Uri.parse(
          'https://github.com/eduardoveiga-py/field-assistant/releases/download/v1.4.0/br_am_solimoes.pmtiles',
        ),
        sizeBytes: bytes.length,
        sha256: digest,
        bbox: const GeoBoundingBox(
          minLat: -5.0,
          minLon: -70.5,
          maxLat: -3.0,
          maxLon: -68.0,
        ),
        minZoom: 4,
        maxZoom: 15,
        generatedAt: DateTime.utc(2026, 11, 17),
        version: '2026.11',
        license: 'ODbL-1.0',
        attribution: '© OpenStreetMap contributors',
        format: OfflineMapFormat.pmtiles,
      );
      expect(valid.verifyBytesIntegrity(bytes), isTrue);
      expect(valid.verifyBytesIntegrity(Uint8List.fromList([1, 2, 3])), isFalse);

      // Rejeita URL mutável @master
      expect(
        () => OfflineMapPackageManifest(
          id: 'bad_mutable',
          regionName: 'Teste',
          downloadUrl: Uri.parse('https://cdn.jsdelivr.net/gh/org/repo@master/map.pmtiles'),
          sizeBytes: 100,
          sha256: digest,
          bbox: valid.bbox,
          minZoom: 4,
          maxZoom: 12,
          generatedAt: DateTime.utc(2026, 11, 17),
          version: '1.0',
          license: 'ODbL-1.0',
          attribution: '© OpenStreetMap contributors',
          format: OfflineMapFormat.pmtiles,
        ),
        throwsFormatException,
      );

      // Rejeita servidor público OSM
      expect(
        () => OfflineMapPackageManifest(
          id: 'bad_osm',
          regionName: 'Teste',
          downloadUrl: Uri.parse('https://tile.openstreetmap.org/0/0/0.png'),
          sizeBytes: 100,
          sha256: digest,
          bbox: valid.bbox,
          minZoom: 0,
          maxZoom: 12,
          generatedAt: DateTime.utc(2026, 11, 17),
          version: '1.0',
          license: 'ODbL-1.0',
          attribution: '© OpenStreetMap contributors',
          format: OfflineMapFormat.mbtiles,
        ),
        throwsFormatException,
      );
    });
  });

  testWidgets('FA-UX-01: NavigationRail no iPad/Desktop inclui Mapas & Territórios', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final testDb = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(testDb.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(testDb)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('pt', 'BR')],
          home: const MainNavigationShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final mapDestination = find.descendant(
      of: find.byType(NavigationRail),
      matching: find.byIcon(Icons.explore_outlined),
    );
    expect(mapDestination, findsOneWidget);

    await tester.tap(mapDestination);
    await tester.pumpAndSettle();
    expect(find.text('Mapa dos Contatos e Território'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
