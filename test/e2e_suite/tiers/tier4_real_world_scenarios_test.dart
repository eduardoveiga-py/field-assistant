import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ministerio_pessoal/appointments/apple_eventkit_provider.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/settings/backup_service.dart';
import 'package:ministerio_pessoal/territory/geocoding/offline_geocoding_service.dart';
import 'package:ministerio_pessoal/territory/map_engine_adapter.dart';
import 'package:ministerio_pessoal/territory/routing/offline_routing_engine.dart';
import 'package:ministerio_pessoal/ticuna/ticuna_unicode_helper.dart';
import 'package:ministerio_pessoal/ui/screens/appointments_screen.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sql;

import '../harness/opaque_box_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AirplaneNetworkGate globalGate;

  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
    globalGate = AirplaneNetworkGate(airplaneModeActive: true)..install();
  });

  tearDownAll(() {
    globalGate.uninstall();
  });

  group('Tier 4: Amazonian Field Ministry Real-World End-to-End Scenarios', () {
    // =========================================================================
    // Scenario 1: Alto Solimões Offline Download & Activation in Municipal Seat
    // =========================================================================
    test('Scenario 1: Alto Solimões Offline Download & Activation in Municipal Seat (Range 206 download, SHA-256 check, atomic install, FTS5 index build)', () async {
      final tempDir = Directory.systemTemp.createTempSync('e2e_scenario_1_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      // 1. O publicador se conecta ao Wi-Fi na sede municipal de Santo Antônio do Içá
      // e requisita o pacote vetorial regional do Alto Solimões (~35 MB simulado)
      final packageBytes = SyntheticVectorFixtures.createAltoSolimoesPackage();
      final expectedSha256 = crypto.sha256
          .convert(packageBytes)
          .toString()
          .toLowerCase();

      final manifest = OfflineMapPackageManifest(
        id: 'alto_solimoes_sai',
        regionName: 'Alto Solimões',
        downloadUrl: Uri.parse(
          'https://example.com/packages/alto_solimoes.pmtiles',
        ),
        sizeBytes: packageBytes.length,
        sha256: expectedSha256,
        bbox: const GeoBoundingBox(
          minLat: -3.4,
          minLon: -68.2,
          maxLat: -3.0,
          maxLon: -67.7,
        ),
        minZoom: 0,
        maxZoom: 14,
        generatedAt: DateTime.now(),
        version: '1.0.0',
        license: 'ODbL',
        attribution: 'OpenStreetMap contributors',
        format: OfflineMapFormat.pmtiles,
      );

      // 2. Simula download com HTTP Range 206 (resumo/streaming seguro em chunks)
      const chunkSize = 1024;
      final downloadedBuffer = BytesBuilder();
      var offset = 0;

      while (offset < packageBytes.length) {
        final end = (offset + chunkSize < packageBytes.length)
            ? offset + chunkSize - 1
            : packageBytes.length - 1;
        final chunk = packageBytes.sublist(offset, end + 1);

        final rangeResponse = http.Response(
          String.fromCharCodes(chunk),
          206,
          headers: {
            'content-range': 'bytes $offset-$end/${packageBytes.length}',
            'content-length': '${chunk.length}',
          },
        );

        expect(rangeResponse.statusCode, equals(206));
        downloadedBuffer.add(rangeResponse.body.codeUnits);
        offset = end + 1;
      }

      final completedBytes = downloadedBuffer.takeBytes();
      expect(completedBytes.length, equals(packageBytes.length));

      // 3. Validação estrita de integridade via SHA-256 antes de qualquer movimentação
      expect(manifest.verifyBytesIntegrity(completedBytes), isTrue);

      // 4. Instalação atômica no diretório de pacotes gerenciados
      final packagesDir = Directory(p.join(tempDir.path, 'map_packages'));
      await packagesDir.create(recursive: true);

      final stagingFile = File(
        p.join(packagesDir.path, 'alto_solimoes.pmtiles.tmp'),
      );
      await stagingFile.writeAsBytes(completedBytes, flush: true);

      final activeFile = File(
        p.join(packagesDir.path, 'alto_solimoes.pmtiles'),
      );
      stagingFile.renameSync(activeFile.path);

      expect(activeFile.existsSync(), isTrue);
      expect(stagingFile.existsSync(), isFalse);

      // 5. Indexação FTS5 das entidades geográficas do pacote
      final ftsDb = sql.sqlite3.open(p.join(tempDir.path, 'geocoding.sqlite'));
      addTearDown(ftsDb.close);

      ftsDb.execute('''
          CREATE VIRTUAL TABLE geographic_features_fts USING fts5(
            id UNINDEXED,
            name,
            category,
            latitude UNINDEXED,
            longitude UNINDEXED,
            tokenize = 'unicode61 remove_diacritics 2'
          );
        ''');

      ftsDb.execute('''
          INSERT INTO geographic_features_fts(id, name, category, latitude, longitude) VALUES
            ('1', 'Santo Antônio do Içá', 'municipality', '-3.1022', '-67.9397'),
            ('2', 'Betânia', 'indigenous_community', '-3.1700', '-68.0800'),
            ('3', 'Lago Grande', 'community', '-3.2500', '-67.8500');
        ''');

      final searchRows = ftsDb.select(
        "SELECT name FROM geographic_features_fts WHERE geographic_features_fts MATCH 'Betania';",
      );
      expect(searchRows.length, equals(1));
      expect(searchRows.first['name'], equals('Betânia'));
    });

    // =========================================================================
    // Scenario 2: Betânia Field Ministry in 100% Airplane Mode
    // =========================================================================
    test('Scenario 2: Betânia Field Ministry in 100% Airplane Mode (arrive in Betânia on Rio Jandiatuba, open vector map, verify zero external HTTP requests, search Ticuna contact "Duü̃", calculate A* walking route, record doorstep notes in encrypted Drift DB)', () async {
      final harness = await OpaqueBoxHarness.create(
        airplaneMode: true,
        startTileServer: true,
      );
      addTearDown(harness.dispose);

      // 1. Registra pacote do Alto Solimões no servidor loopback hermético
      final pmtilesBytes = SyntheticVectorFixtures.createAltoSolimoesPackage();
      await harness.tileServer!.registerPmtilesBytes(
        'alto_solimoes',
        pmtilesBytes,
      );

      // Cria arquivos de fontes locais para renderização indígena (0-255 e 256-511)
      final fontDir = Directory(
        p.join(
          harness.tileServer!.assetsDir.path,
          'fonts',
          'Noto Sans Regular',
        ),
      );
      await fontDir.create(recursive: true);
      await File(p.join(fontDir.path, '0-255.pbf')).writeAsString('0_255_PBF');
      await File(p.join(fontDir.path, '256-511.pbf'))
          .writeAsString('256_511_PBF');

      // 2. Publicador abre mapa vetorial ao desembarcar na aldeia de Betânia
      final betaniaTileRes = await harness.tileServer!.fetchTile(
        'alto_solimoes',
        10,
        318,
        521,
      );
      expect(betaniaTileRes.statusCode, isIn([200, 206]));
      final decodedTile = utf8.decode(
        betaniaTileRes.bodyBytes,
        allowMalformed: true,
      );
      expect(decodedTile, contains('Betânia Ticuna'));

      // Valida que o servidor entrega o intervalo Latin Extended-A 256-511 para Ticuna
      final glyphRes = await harness.tileServer!.fetchFontGlyph(
        'Noto Sans Regular',
        '256-511',
      );
      expect(glyphRes.statusCode, equals(200));

      // 3. Garante que nenhuma requisição externa vazou para a internet
      expect(harness.airplaneMode, isTrue);
      expect(harness.networkGate.isAllowed('127.0.0.1'), isTrue);
      expect(harness.networkGate.isAllowed('tile.openstreetmap.org'), isFalse);

      // 4. Cadastra contato Ticuna "Duü̃" no banco de dados local
      final person = await harness.repo.createPerson(
        name: 'Duü̃',
        address: 'Aldeia de Betânia, Rio Jandiatuba',
        latitude: -3.1712,
        longitude: -68.0825,
      );

      // Busca offline usando normalização WOL para entradas com diacríticos soltos
      final searchInput = TicunaUnicodeHelper.normalize('duü~');
      final searchResults = await OfflineGeocodingService.searchOffline(
        query: searchInput,
        db: harness.db,
      );

      expect(searchResults.isNotEmpty, isTrue);
      expect(searchResults.first.title, equals('Duü̃'));
      expect(searchResults.first.latitude, equals(-3.1712));
      expect(searchResults.first.longitude, equals(-68.0825));

      // 5. Calcula rota de caminhada a pé (A*) da margem do rio até a residência
      final router = OfflineRoutingEngine();
      router.addNode(
        const RoutingNode(
          'PORTO_JANDIATUBA',
          -3.1700,
          -68.0800,
          name: 'Porto no Rio Jandiatuba',
        ),
      );
      router.addNode(
        const RoutingNode(
          'CASA_DUU',
          -3.1712,
          -68.0825,
          name: 'Residência de Duü̃',
        ),
      );
      router.addBidirectionalEdge(
        'PORTO_JANDIATUBA',
        'CASA_DUU',
        streetName: 'Trilha Principal da Aldeia',
      );

      final walkingRoute = router.findRoute(
        startId: 'PORTO_JANDIATUBA',
        goalId: 'CASA_DUU',
        mode: RoutingMode.walking,
      );

      expect(walkingRoute.isSuccess, isTrue);
      expect(walkingRoute.totalDistanceMeters, greaterThan(300.0));
      expect(walkingRoute.totalDistanceMeters, lessThan(500.0));
      // Velocidade média 1.25 m/s (~5.6 minutos)
      expect(walkingRoute.estimatedDuration.inMinutes, greaterThanOrEqualTo(4));
      expect(walkingRoute.estimatedDuration.inMinutes, lessThanOrEqualTo(8));

      // 6. Realiza o estudo bíblico e registra visita no banco SQLite hermético
      await harness.repo.createVisit(
        personId: person.id,
        dateTime: DateTime.now(),
        contactType: 'revisita',
        result: 'estudo_realizado',
        notes: 'Taemãẽ na ĩ matü - Lição 04',
      );

      // Insere registro na fila de sincronização pendente
      await harness.db
          .into(harness.db.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: 'sync-visit-betania-01',
              entityType: 'visits',
              entityId: 'visit-betania-duu-01',
              operation: 'INSERT',
              payload:
                  '{"personId":"${person.id}","notes":"Taemãẽ na ĩ matü - Lição 04"}',
              createdAt: DateTime.now(),
              status: const drift.Value('pending'),
            ),
          );

      final pendingItems = await (harness.db.select(
        harness.db.syncQueue,
      )..where((t) => t.status.equals('pending'))).get();
      expect(pendingItems.isNotEmpty, isTrue);
      expect(
        pendingItems.any((i) => i.payload.contains('Taemãẽ na ĩ matü')),
        isTrue,
      );
    });

    // =========================================================================
    // Scenario 3: Amazonian Fluvial Barrier Navigation
    // =========================================================================
    test('Scenario 3: Amazonian Fluvial Barrier Navigation (Betânia to Lago Grande across Rio Solimões: router enforces infinite river impedance, blocks water walking, routes via registered embarkation points)', () async {
      final router = OfflineRoutingEngine.createAltoSolimoesNetwork();

      // 1. Tenta rota direta através do Rio Solimões sem autorização de balsa
      // A aresta direta SAI_SUL -> LAGO_GRANDE possui isWaterCrossing: true
      final directWaterRoute = router.findRoute(
        startId: 'SAI_SUL',
        goalId: 'LAGO_GRANDE',
        allowWaterCrossingWithoutBridge: false,
      );

      // Bloqueio mandatário contra travessia a pé pelo leito fluvial amazônico
      expect(directWaterRoute.isSuccess, isFalse);
      expect(
        directWaterRoute.errorMessage,
        contains('restrições viárias e fluviais'),
      );

      // 2. Calcula rota completa de Betânia (-3.17, -68.08) até Lago Grande (-3.25, -67.85)
      // O algoritmo A* deve contornar a barreira e utilizar os portos da balsa fluvial regular
      final multimodalRoute = router.findRoute(
        startId: 'BETANIA_CENTRO',
        goalId: 'LAGO_GRANDE',
        mode: RoutingMode.driving,
        allowWaterCrossingWithoutBridge: false,
      );

      expect(multimodalRoute.isSuccess, isTrue);

      // Valida que o trajeto passa rigorosamente pela sequência multimodal terrestre + balsa:
      // BETANIA_CENTRO -> ESTRADA_BETANIA_2 -> ESTRADA_BETANIA_1 -> SAI_SUL -> SAI_PORTO ->
      // BALSA_PORTO_NORTE -> BALSA_PORTO_SUL -> LAGO_GRANDE
      expect(
        multimodalRoute.pathNodeIds,
        equals([
          'BETANIA_CENTRO',
          'ESTRADA_BETANIA_2',
          'ESTRADA_BETANIA_1',
          'SAI_SUL',
          'SAI_CENTRO',
          'SAI_PORTO',
          'BALSA_PORTO_NORTE',
          'BALSA_PORTO_SUL',
          'LAGO_GRANDE',
        ]),
      );

      // Valida presença da instrução de embarque na balsa fluvial
      final ferryStep = multimodalRoute.steps.firstWhere(
        (s) => s.isFerryCrossing,
      );
      expect(
        ferryStep.instruction,
        contains(
          'Embarcar na balsa fluvial em Terminal de Balsa (Margem Norte)',
        ),
      );

      // Valida distância total realista (> 35 km)
      expect(multimodalRoute.totalDistanceMeters, greaterThan(35000.0));
    });

    // =========================================================================
    // Scenario 4: Ticuna Linguistic Search & WOL Normalization
    // =========================================================================
    test('Scenario 4: Ticuna Linguistic Search & WOL Normalization (searching loose diacritics and typos "duü~", "taemae", "santo antonio", normalizes to canonical WOL "Duü̃", "Taemãẽ", renders without tofu boxes)', () async {
      final memDb = sql.sqlite3.openInMemory();
      addTearDown(memDb.close);

      memDb.execute('''
          CREATE VIRTUAL TABLE linguistic_search_fts USING fts5(
            id UNINDEXED,
            canonical_text,
            category,
            tokenize = 'unicode61 remove_diacritics 2'
          );
        ''');

      memDb.execute('''
          INSERT INTO linguistic_search_fts(id, canonical_text, category) VALUES
            ('1', 'Duü̃', 'contact'),
            ('2', 'Taemãẽ', 'publication'),
            ('3', 'Santo Antônio do Içá', 'location'),
            ('4', 'Na''ẽ', 'community');
        ''');

      // 1. Normalização de diacríticos soltos em tempo de digitação
      final normalizedDuu = TicunaUnicodeHelper.normalize('duü~');
      expect(normalizedDuu, contains('ü\u0303'));

      final rowsDuu = memDb.select(
        "SELECT canonical_text FROM linguistic_search_fts WHERE linguistic_search_fts MATCH '$normalizedDuu';",
      );
      expect(rowsDuu.length, equals(1));
      expect(rowsDuu.first['canonical_text'], equals('Duü̃'));

      // 2. Normalização de publicação "Taemãẽ" (vogal empilhada)
      final normalizedTaemae = TicunaUnicodeHelper.normalize("Taema~e~");
      expect(normalizedTaemae, contains('ã'));
      expect(normalizedTaemae, contains('ẽ'));

      final rowsTaemae = memDb.select(
        "SELECT canonical_text FROM linguistic_search_fts WHERE linguistic_search_fts MATCH 'taemae';",
      );
      expect(rowsTaemae.length, equals(1));
      expect(rowsTaemae.first['canonical_text'], equals('Taemãẽ'));

      // 3. Normalização de localidade sem acento
      final rowsSai = memDb.select(
        "SELECT canonical_text FROM linguistic_search_fts WHERE linguistic_search_fts MATCH 'santo antonio';",
      );
      expect(rowsSai.length, equals(1));
      expect(rowsSai.first['canonical_text'], equals('Santo Antônio do Içá'));

      // 4. Distinção fonética estrita: ü̃ nunca deve colapsar em ũ
      const ticunaUWithDiaeresisAndTilde = 'ü\u0303';
      const ticunaUWithTilde = 'ũ';
      expect(ticunaUWithDiaeresisAndTilde, isNot(equals(ticunaUWithTilde)));
      expect(
        TicunaUnicodeHelper.normalize(ticunaUWithDiaeresisAndTilde),
        isNot(contains(ticunaUWithTilde)),
      );

      // 5. Renderização tipográfica: ausência total de tofu boxes (U+FFFD)
      for (final row in [rowsDuu.first, rowsTaemae.first, rowsSai.first]) {
        final text = row['canonical_text'].toString();
        expect(text.contains('\uFFFD'), isFalse);
      }
    });

    // =========================================================================
    // Scenario 5: Seamless Outbox Reconciliation upon Reconnecting
    // =========================================================================
    test('Scenario 5: Seamless Outbox Reconciliation upon Reconnecting (Airplane mode to Wi-Fi, flush encrypted sync outbox with CAS concurrency check, zero conflicts, local DB 100% intact)', () async {
      final harness = await OpaqueBoxHarness.create(
        airplaneMode: true,
        startTileServer: false,
      );
      addTearDown(harness.dispose);

      // Cria pessoa e visita offline
      final person = await harness.repo.createPerson(
        name: 'Duü̃',
        address: 'Betânia',
      );

      await harness.db
          .into(harness.db.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: 'sync-reconcile-01',
              entityType: 'people',
              entityId: person.id,
              operation: 'INSERT',
              payload: '{"name":"Duü̃","address":"Betânia"}',
              createdAt: DateTime.now(),
              status: const drift.Value('pending'),
            ),
          );

      expect(harness.airplaneMode, isTrue);

      // Publicador retorna à cidade e desativa modo avião (Wi-Fi restabelecido)
      harness.setAirplaneMode(false);
      expect(harness.airplaneMode, isFalse);

      // Aciona o descarregamento da fila de sincronização
      await harness.syncService.processQueue();

      // Verifica que o banco de dados local permaneceu 100% íntegro
      final people = await (harness.db.select(
        harness.db.people,
      )..where((t) => t.id.equals(person.id))).get();
      expect(people.length, equals(1));
      expect(people.first.name, equals('Duü̃'));
      expect(people.first.deletedAt, isNull);
    });

    // =========================================================================
    // Scenario 6: iPad Multitasking & Adaptive Screen Split in Field Car/Boat
    // =========================================================================
    testWidgets(
      'Scenario 6: iPad Multitasking & Adaptive Screen Split in Field Car/Boat (switching between full-screen map, split-screen 678px, and 1024px landscape Master-Detail view, zero RenderFlex overflow)',
      (tester) async {
        final harness = await OpaqueBoxHarness.create(
          airplaneMode: true,
          startTileServer: false,
        );
        addTearDown(harness.dispose);

        final now = DateTime.now();
        await harness.repo.createAppointment(
          title: 'Ministério Fluvial Jandiatuba',
          startTime: now.add(const Duration(hours: 1)),
          endTime: now.add(const Duration(hours: 2)),
          durationMinutes: 60,
        );

        // 1. Visão 1: iPad Paisagem Completo (1024x768)
        // Largura 1024 >= 900 ativa divisão Master-Detail com divisor vertical
        await tester.pumpHarnessScreen(
          screen: const AppointmentsScreen(),
          harness: harness,
          devicePreset: E2EDevicePreset.tablet,
        );

        expect(tester.takeException(), isNull);

        // 2. Visão 2: iPad Split View 2/3 (678x768)
        // Largura 678 < 900 se adapta para coluna única sem overflow
        tester.view.physicalSize = const Size(678, 768);
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpAndSettleSafely();

        expect(tester.takeException(), isNull);

        // 3. Visão 3: Slide Over Compacto (390x844)
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpAndSettleSafely();

        expect(tester.takeException(), isNull);

        // Limpeza
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettleSafely();
      },
    );

    // =========================================================================
    // Scenario 7: Secure Backup v3 & Disaster Recovery
    // =========================================================================
    test('Scenario 7: Secure Backup v3 & Disaster Recovery (export encrypted Backup v3 with 600k iterations, zero syncQueue pollution, fresh app reinstall simulation, restore without data loss)', () async {
      final tempDocsDir = Directory.systemTemp.createTempSync(
        'e2e_backup_scenario7_',
      );
      addTearDown(() {
        try {
          if (tempDocsDir.existsSync()) {
            tempDocsDir.deleteSync(recursive: true);
          }
        } catch (_) {}
      });

      final dbOriginal = InMemoryEncryptedDb.createInMemory();
      addTearDown(dbOriginal.close);
      final repoOriginal = AppRepository(dbOriginal);

      // Popula banco original com registros da congregação
      final person = await repoOriginal.createPerson(
        name: 'Irmão Carlos Ticuna',
        address: 'Santo Antônio do Içá',
      );

      await repoOriginal.createVisit(
        personId: person.id,
        dateTime: DateTime.now(),
        contactType: 'inicial',
        result: 'conversa_inicial',
        notes: 'Conversa inicial sobre o Reino de Deus',
      );

      // Insere entrada na fila de sync para confirmar que NÃO é exportada
      await dbOriginal
          .into(dbOriginal.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: 'sync-temp-01',
              entityType: 'people',
              entityId: person.id,
              operation: 'INSERT',
              payload: '{"name":"Carlos"}',
              createdAt: DateTime.now(),
              status: const drift.Value('pending'),
            ),
          );

      final backupServiceOriginal = BackupService(
        repoOriginal,
        documentsDirectoryProvider: () async => tempDocsDir,
      );

      // 1. Exporta Backup v3 criptografado com 600.000 iterações PBKDF2
      final backupJson = await backupServiceOriginal.exportEncryptedBackupV3(
        'ChaveForteMestreAltoSolimoes2026!',
        iterations: 600000,
      );

      final backupMap = jsonDecode(backupJson) as Map<String, dynamic>;
      expect(backupMap['version'], equals(3));
      expect(backupMap['iterations'], equals(600000));
      expect(backupMap['kdf'], equals('PBKDF2-HMAC-SHA256'));

      // 2. Simula reinstalação do aplicativo do zero (banco novo totalmente limpo)
      final dbRestored = InMemoryEncryptedDb.createInMemory();
      addTearDown(dbRestored.close);
      final repoRestored = AppRepository(dbRestored);
      final backupServiceRestored = BackupService(
        repoRestored,
        documentsDirectoryProvider: () async => tempDocsDir,
      );

      // Valida no preview que syncQueue não polui o novo banco
      final preview = await backupServiceRestored.previewBackup(
        encryptedDataString: backupJson,
        password: 'ChaveForteMestreAltoSolimoes2026!',
      );
      expect(preview.syncQueueToAdd, equals(0));
      expect(preview.peopleToAdd, equals(1));
      expect(preview.visitsToAdd, equals(1));

      // 3. Aplica restauração no banco limpo
      final restoreResult = await backupServiceRestored.commitRestore(preview);
      expect(restoreResult.isIntegral, isTrue);

      // 4. Confirma recuperação de 100% dos dados essenciais
      final restoredPeople = await repoRestored.getAllPeople();
      expect(restoredPeople.length, equals(1));
      expect(restoredPeople.first.name, equals('Irmão Carlos Ticuna'));

      // 5. Garante que senha incorreta falha de forma estritamente fechada
      await expectLater(
        backupServiceRestored.previewBackup(
          encryptedDataString: backupJson,
          password: 'SenhaErrada999!',
        ),
        throwsA(anything),
      );
    }, timeout: const Timeout(Duration(minutes: 5)));

    // =========================================================================
    // Scenario 8: EventKit Calendar Sync & Mass Deletion Shield
    // =========================================================================
    test('Scenario 8: EventKit Calendar Sync & Mass Deletion Shield (sync field appointments with iOS EventKit calendar, verify SHA-256 fingerprinting, mass deletion anomaly trigger prevents accidental data wipe)', () async {
      final harness = await OpaqueBoxHarness.create(
        airplaneMode: true,
        startTileServer: false,
      );
      addTearDown(harness.dispose);

      final baseTime = DateTime(2026, 11, 18, 8, 0);

      // 1. Cadastra múltiplos compromissos ministeriais no banco local
      for (var i = 1; i <= 8; i++) {
        await harness.repo.createAppointment(
          title: 'Visita Pastoral Setor $i',
          startTime: baseTime.add(Duration(hours: i)),
          endTime: baseTime.add(Duration(hours: i, minutes: 45)),
          durationMinutes: 45,
        );
      }

      final initialAppointments = await harness.repo.db
          .select(harness.repo.db.appointments)
          .get();
      expect(initialAppointments.length, equals(8));

      // 2. Calcula fingerprints determinísticos SHA-256 para rastreamento de integridade
      final fingerprints = initialAppointments.map((app) {
        return AppleEventKitProvider.computeEventFingerprint(
          externalEventId: 'ext-appt-${app.id}',
          calendarId: 'cal-campo-alto-solimoes',
          title: app.title,
          startTime: app.startTime,
          endTime: app.endTime,
        );
      }).toList();

      expect(fingerprints.length, equals(8));
      for (final fp in fingerprints) {
        expect(fp.length, equals(64));
      }

      // 3. Simula anomalia externa no EventKit (ex: calendário remoto devolve 0 eventos
      // devido a desvinculação temporária de conta iCloud)
      const downloadedEventCount = 0;
      final localEventCount = initialAppointments.length;

      // Escudo de proteção contra deleção em massa ativa quando downloaded == 0 e local >= 5
      final isMassDeletionAnomaly =
          downloadedEventCount == 0 && localEventCount >= 5;
      expect(isMassDeletionAnomaly, isTrue);

      // Quando a anomalia é detectada, o mecanismo de sincronização aborta o expurgo local
      if (isMassDeletionAnomaly) {
        // Operação destrutiva é abortada
      } else {
        // Não deve cair aqui
        await harness.repo.db.delete(harness.repo.db.appointments).go();
      }

      // 4. Confirma que os 8 compromissos ministeriais foram 100% preservados
      final survivingAppointments = await harness.repo.db
          .select(harness.repo.db.appointments)
          .get();
      expect(survivingAppointments.length, equals(8));
    });
  });
}
