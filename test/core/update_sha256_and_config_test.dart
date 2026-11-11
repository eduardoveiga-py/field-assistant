import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/core/demo_data.dart';
import 'package:ministerio_pessoal/core/update_checker_service.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/main.dart';
import 'package:ministerio_pessoal/sync/supabase_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A1 SHA-256 Update Verification, A10 Config, C3 Fatal Screen & M4/M6 Demo Flag', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('update_sha_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('A1: downloadAndVerifyUpdate valida SHA-256 via SHA256SUMS.txt e rejeita divergência ou manifesto ausente (fail-closed)', () async {
      final validApkBytes = utf8.encode('FAKE_SIGNED_APK_PAYLOAD_OK_123456');
      final validSha256 = crypto.sha256.convert(validApkBytes).toString();

      // 1. Sucesso quando hash bate com SHA256SUMS.txt
      final okClient = MockClient((request) async {
        final url = request.url.toString();
        if (url.endsWith('SHA256SUMS.txt')) {
          return http.Response(
            '$validSha256  app-arm64-v8a-release.apk\n',
            200,
            request: request,
          );
        }
        if (url.endsWith('app-arm64-v8a-release.apk')) {
          return http.Response.bytes(validApkBytes, 200, request: request);
        }
        return http.Response('Not found', 404, request: request);
      });

      final serviceOk = UpdateCheckerService(client: okClient);
      final infoNoInlineHash = AppUpdateInfo.updateAvailable(
        currentVersion: '1.3.1',
        latestVersion: '1.3.2',
        releaseDate: '2026-11-10',
        releaseNotes: 'Notas',
        downloadUrl: 'https://github.com/example/releases/download/v1.3.2/app-arm64-v8a-release.apk',
        sourceCatalogUrl: 'https://example.com/apps.json',
      );

      final resOk = await serviceOk.downloadAndVerifyUpdate(
        infoNoInlineHash,
        customSaveDirPath: tempDir.path,
        launchInstaller: false,
      );
      expect(resOk.verified, isTrue);
      expect(resOk.launched, isFalse);
      expect(resOk.filePath, isNotNull);
      expect(File(resOk.filePath!).existsSync(), isTrue);

      // 2. Fail-closed em divergência de hash (arquivo corrompido / adulterado)
      final tamperedDir = Directory('${tempDir.path}/tampered')..createSync();
      final badHashClient = MockClient((request) async {
        if (request.url.toString().endsWith('app-arm64-v8a-release.apk')) {
          return http.Response.bytes(utf8.encode('CORRUPTED_BYTES'), 200, request: request);
        }
        return http.Response('Not found', 404, request: request);
      });

      final serviceMismatch = UpdateCheckerService(client: badHashClient);
      final infoWithExpectedHash = AppUpdateInfo.updateAvailable(
        currentVersion: '1.3.1',
        latestVersion: '1.3.2',
        releaseDate: '2026-11-10',
        releaseNotes: 'Notas',
        downloadUrl: 'https://github.com/example/releases/download/v1.3.2/app-arm64-v8a-release.apk',
        sourceCatalogUrl: 'https://example.com/apps.json',
        sha256: validSha256,
      );

      final resMismatch = await serviceMismatch.downloadAndVerifyUpdate(
        infoWithExpectedHash,
        customSaveDirPath: tamperedDir.path,
        launchInstaller: false,
      );
      expect(resMismatch.verified, isFalse);
      expect(resMismatch.launched, isFalse);
      expect(resMismatch.errorMessage, contains('SHA-256'));
      expect(tamperedDir.listSync(), isEmpty,
          reason: 'Arquivo com SHA-256 divergente não pode ser salvo em disco');

      // 3. Fail-closed quando nem info.sha256 nem SHA256SUMS.txt existem
      final noManifestDir = Directory('${tempDir.path}/no_manifest')..createSync();
      final noManifestClient = MockClient((request) async {
        return http.Response('Not found', 404, request: request);
      });
      final serviceNoManifest = UpdateCheckerService(client: noManifestClient);
      final resNoManifest = await serviceNoManifest.downloadAndVerifyUpdate(
        infoNoInlineHash,
        customSaveDirPath: noManifestDir.path,
        launchInstaller: false,
      );
      expect(resNoManifest.verified, isFalse);
      expect(resNoManifest.launched, isFalse);
      expect(resNoManifest.errorMessage, contains('Manifesto SHA-256'));
      expect(noManifestDir.listSync(), isEmpty);
    });

    test('A10: SupabaseConfig.isConfigured retorna false quando SUPABASE_URL/ANON_KEY estão vazios', () {
      expect(SupabaseConfig.url, isEmpty);
      expect(SupabaseConfig.publishableKey, isEmpty);
      expect(SupabaseConfig.isConfigured, isFalse);
    });

    testWidgets('C3: FatalPersistenceScreen exibe falha crítica de persistência e dispara onRetry', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: FatalPersistenceScreen(
            errorMessage: 'IndexedDB blocked in private browsing',
            onRetry: () => retried = true,
          ),
        ),
      );

      expect(find.text('Armazenamento Local Indisponível'), findsOneWidget);
      expect(find.text('IndexedDB blocked in private browsing'), findsOneWidget);
      final retryButton = find.text('Tentar Reconectar');
      expect(retryButton, findsOneWidget);

      await tester.tap(retryButton);
      await tester.pump();
      expect(retried, isTrue);
    });

    test('M4/M6: DemoDataGenerator persiste flag demo_mode=true na app_kv_store e limpa ao remover dados demo', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = AppRepository(db);
      addTearDown(db.close);

      await DemoDataGenerator.populateDemoData(repo);

      final flagRow = await (db.select(db.appKvStore)
            ..where((t) => t.key.equals(DemoDataGenerator.demoModeKvKey)))
          .getSingleOrNull();
      expect(flagRow, isNotNull);
      expect(flagRow!.value, equals('true'));
      expect(await DemoDataGenerator.hasDemoData(repo), isTrue);

      await DemoDataGenerator.clearDemoData(repo);
      final afterClearFlag = await (db.select(db.appKvStore)
            ..where((t) => t.key.equals(DemoDataGenerator.demoModeKvKey)))
          .getSingleOrNull();
      expect(afterClearFlag, isNull);
      expect(await DemoDataGenerator.hasDemoData(repo), isFalse);
    });
  });
}
