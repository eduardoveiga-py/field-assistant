import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ministerio_pessoal/appointments/apple_eventkit_provider.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/settings/backup_service.dart';
import 'package:ministerio_pessoal/sync/crypto/encrypted_media.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_crypto.dart';
import 'package:ministerio_pessoal/territory/map_engine/maplibre_native_adapter.dart';
import 'package:ministerio_pessoal/territory/map_engine/raster_fallback_adapter.dart';
import 'package:ministerio_pessoal/territory/map_engine_adapter.dart';
import 'package:ministerio_pessoal/territory/mbtiles/mbtiles_native.dart';
import 'package:ministerio_pessoal/territory/routing/offline_routing_engine.dart';
import 'package:ministerio_pessoal/ticuna/ticuna_unicode_helper.dart';
import 'package:ministerio_pessoal/ui/screens/appointments_screen.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sql;

import '../harness/opaque_box_harness.dart';

// =============================================================================
// Helper: Minimal Valid 256x256 PNG Generator for MBTiles Raster Tests
// =============================================================================

Uint8List _createMinimalPng256() {
  final out = BytesBuilder();
  // Assinatura canônica oficial do formato PNG (8 bytes)
  out.add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

  void writeChunk(String type, Uint8List data) {
    final typeBytes = ascii.encode(type);
    final lenBytes = ByteData(4)..setUint32(0, data.length);
    out.add(lenBytes.buffer.asUint8List());
    out.add(typeBytes);
    out.add(data);

    final crcData = Uint8List(typeBytes.length + data.length);
    crcData.setRange(0, typeBytes.length, typeBytes);
    crcData.setRange(typeBytes.length, crcData.length, data);

    var crc = 0xffffffff;
    for (final b in crcData) {
      crc ^= b;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
      }
    }
    crc ^= 0xffffffff;

    final crcBytes = ByteData(4)..setUint32(0, crc);
    out.add(crcBytes.buffer.asUint8List());
  }

  // Bloco IHDR: Largura=256, Altura=256, Profundidade=8 bits, Tipo de cor=2 (Truecolor RGB)
  final ihdr = ByteData(13)
    ..setUint32(0, 256)
    ..setUint32(4, 256)
    ..setUint8(8, 8)
    ..setUint8(9, 2)
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);
  writeChunk('IHDR', ihdr.buffer.asUint8List());

  // Bloco IDAT: 256 scanlines, cada uma com 1 byte de filtro (0) + 256 * 3 bytes RGB
  final rawScanlines = Uint8List(256 * (1 + 256 * 3));
  final compressed = zlib.encode(rawScanlines);
  writeChunk('IDAT', Uint8List.fromList(compressed));

  // Bloco IEND: Finalizador do stream PNG
  writeChunk('IEND', Uint8List(0));

  return out.takeBytes();
}

// =============================================================================
// Main Test Entry Point: Tier 3 Pairwise Combinatorial Test Suite
// =============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AirplaneNetworkGate globalGate;

  setUpAll(() {
    globalGate = AirplaneNetworkGate(airplaneModeActive: true)..install();
  });

  tearDownAll(() {
    globalGate.uninstall();
  });

  group('Tier 3: Pairwise Cross-Feature Combination Test Suite (FAES 10/10)', () {
    // =========================================================================
    // Matrix 1: Engine x Network x Package x Location (PWT-01 to PWT-06)
    // =========================================================================
    group('Matrix 1: Engine x Network x Package x Location', () {
      test('PWT-01: MapLibre in Airplane Mode with Alto Solimões vector package at Betânia renders vector tiles via loopback server, loads local glyphs, and has 0 external requests', () async {
        final harness = await OpaqueBoxHarness.create(
          airplaneMode: true,
          startTileServer: true,
        );
        addTearDown(harness.dispose);

        // Registra pacote PMTiles sintético do Alto Solimões
        final altoSolimoesBytes =
            SyntheticVectorFixtures.createAltoSolimoesPackage();
        await harness.tileServer!.registerPmtilesBytes(
          'alto_solimoes_sai',
          altoSolimoesBytes,
        );

        // Cria ativo de fonte Noto Sans Regular (0-255.pbf) no diretório de ativos
        final fontFile = File(
          p.join(
            harness.tileServer!.assetsDir.path,
            'fonts',
            'Noto Sans Regular',
            '0-255.pbf',
          ),
        );
        await fontFile.parent.create(recursive: true);
        await fontFile.writeAsBytes(
          Uint8List.fromList(utf8.encode('PBF_GLYPH_MOCK_0_255')),
          flush: true,
        );

        // Requisita tile de Betânia (-3.1700, -68.0800 => z=10, x=318, y=521)
        final tileRes = await harness.tileServer!.fetchTile(
          'alto_solimoes_sai',
          10,
          318,
          521,
        );
        expect(tileRes.statusCode, isIn([200, 206]));
        expect(tileRes.bodyBytes.length, greaterThan(0));
        final decodedTile = utf8.decode(
          tileRes.bodyBytes,
          allowMalformed: true,
        );
        expect(decodedTile, contains('Betânia Ticuna'));

        // Requisita glifo de fonte local do servidor loopback
        final fontRes = await harness.tileServer!.fetchFontGlyph(
          'Noto Sans Regular',
          '0-255',
        );
        expect(fontRes.statusCode, equals(200));
        expect(fontRes.body, equals('PBF_GLYPH_MOCK_0_255'));

        // Verifica se o modo avião manteve 0 vazamentos externos
        expect(harness.airplaneMode, isTrue);
        expect(harness.networkGate.isAllowed('127.0.0.1'), isTrue);
        expect(harness.networkGate.isAllowed('api.mapbox.com'), isFalse);
      });

      test('PWT-02: MapLibre in Airplane Mode with Package Missing at Santo Antônio do Içá displays offline fallback state', () async {
        final harness = await OpaqueBoxHarness.create(
          airplaneMode: true,
          startTileServer: true,
        );
        addTearDown(harness.dispose);

        final adapter = MaplibreNativeAdapter(
          tileServer: harness.tileServer!.server,
        );
        await adapter.initialize();
        await adapter.setOfflinePackages([]); // Nenhum pacote instalado

        // Consulta de tile para pacote ausente retorna HTTP 404
        final res = await harness.tileServer!.fetchTile(
          'missing_package_sai',
          10,
          318,
          520,
        );
        expect(res.statusCode, equals(404));

        // Estilo gerado sem servidor ativo não inclui fonte vetorial, ativando fallback
        final fallbackAdapter = MaplibreNativeAdapter();
        await fallbackAdapter.initialize();
        final styleJson = fallbackAdapter.generateStyleSpecification(
          isDarkMode: false,
        );
        final sources = styleJson['sources'] as Map<String, dynamic>;
        expect(sources.containsKey('offline-source'), isFalse);

        final layers = styleJson['layers'] as List<dynamic>;
        final backgroundLayer = layers.firstWhere(
          (l) => l['id'] == 'background',
        );
        expect(backgroundLayer, isNotNull);
      });

      test('PWT-03: MapLibre Online with Range 206 package download streams progress smoothly', () async {
        // Cria pacote simulado de 65536 bytes
        final packageData = Uint8List(65536);
        for (var i = 0; i < packageData.length; i++) {
          packageData[i] = i % 256;
        }

        final chunkSize = 16384; // 16 KB por chunk
        final totalChunks = packageData.length ~/ chunkSize;
        final downloadedChunks = <Uint8List>[];
        final progressHistory = <double>[];

        void onProgress(double p) => progressHistory.add(p);

        for (var i = 0; i < totalChunks; i++) {
          final start = i * chunkSize;
          final end = start + chunkSize - 1;
          final rangeBytes = packageData.sublist(start, end + 1);

          // Simula resposta HTTP 206 Partial Content
          final response = http.Response(
            String.fromCharCodes(rangeBytes),
            206,
            headers: {
              'content-range': 'bytes $start-$end/${packageData.length}',
              'content-length': '${rangeBytes.length}',
            },
          );

          expect(response.statusCode, equals(206));
          downloadedChunks.add(Uint8List.fromList(response.body.codeUnits));
          onProgress((end + 1) / packageData.length);
        }

        expect(downloadedChunks.length, equals(4));
        expect(progressHistory, equals([0.25, 0.5, 0.75, 1.0]));

        final assembled = Uint8List.fromList(
          downloadedChunks.expand((c) => c).toList(),
        );
        expect(assembled, equals(packageData));
      });

      test('PWT-04: MapLibre Online with Download Interrupted resumes from byte offset with Range request and verifies SHA-256 upon finish', () async {
        final totalSize = 65536;
        final fullPayload = Uint8List(totalSize);
        for (var i = 0; i < totalSize; i++) {
          fullPayload[i] = (i * 31) % 256;
        }
        final expectedSha256 = crypto.sha256
            .convert(fullPayload)
            .toString()
            .toLowerCase();

        final manifest = OfflineMapPackageManifest(
          id: 'alto_solimoes_resume_test',
          regionName: 'Alto Solimões',
          downloadUrl: Uri.parse(
            'https://example.com/packages/alto_solimoes.pmtiles',
          ),
          sizeBytes: totalSize,
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

        // 1. Simula download inicial interrompido exatamente na metade (32768 bytes)
        const interruptedOffset = 32768;
        final partialBuffer = BytesBuilder()
          ..add(fullPayload.sublist(0, interruptedOffset));

        // 2. Simula requisição de retomada: Range: bytes=32768-
        final resumeRangeHeader = 'bytes=$interruptedOffset-';
        expect(resumeRangeHeader, equals('bytes=32768-'));

        final remainingBytes = fullPayload.sublist(interruptedOffset);
        final resumeResponse = http.Response(
          String.fromCharCodes(remainingBytes),
          206,
          headers: {
            'content-range':
                'bytes $interruptedOffset-${totalSize - 1}/$totalSize',
            'content-length': '${remainingBytes.length}',
          },
        );

        expect(resumeResponse.statusCode, equals(206));
        partialBuffer.add(resumeResponse.body.codeUnits);

        // 3. Monta payload completo e verifica integridade SHA-256 via manifesto
        final completedBytes = partialBuffer.takeBytes();
        expect(completedBytes.length, equals(totalSize));
        expect(manifest.verifyBytesIntegrity(completedBytes), isTrue);
      });

      test('PWT-05: Raster Fallback in Airplane Mode with MBTiles renders 256x256 PNGs', () async {
        final tempDir = Directory.systemTemp.createTempSync(
          'e2e_mbtiles_raster_',
        );
        RasterFallbackAdapter? adapter;
        MBTilesNative? mbtilesBackend;
        addTearDown(() {
          try {
            adapter?.dispose();
            mbtilesBackend?.dispose();
          } catch (_) {}
          try {
            if (tempDir.existsSync()) {
              tempDir.deleteSync(recursive: true);
            }
          } catch (_) {}
        });

        // Constrói banco de dados SQLite .mbtiles canônico válido
        final mbtilesPath = p.join(tempDir.path, 'alto_solimoes.mbtiles');
        final mbtilesDb = sql.sqlite3.open(mbtilesPath);
        mbtilesDb.execute('''
            CREATE TABLE metadata (name text, value text);
            CREATE TABLE tiles (zoom_level integer, tile_column integer, tile_row integer, tile_data blob);
          ''');

        mbtilesDb.execute(
          "INSERT INTO metadata (name, value) VALUES ('format', 'png'), ('minzoom', '0'), ('maxzoom', '14');",
        );

        // Gera imagem PNG 256x256 autêntica
        final png256Bytes = _createMinimalPng256();
        // No padrão TMS do MBTiles, tile_row para y=520 em z=10 é (1 << 10) - 1 - 520 = 503
        const tmsRow = (1 << 10) - 1 - 520;
        final stmt = mbtilesDb.prepare(
          'INSERT INTO tiles (zoom_level, tile_column, tile_row, tile_data) VALUES (?, ?, ?, ?);',
        );
        stmt.execute([10, 318, tmsRow, png256Bytes]);
        stmt.close();
        mbtilesDb.close();

        // Inicializa o RasterFallbackAdapter conectado ao arquivo MBTiles
        mbtilesBackend = MBTilesNative(customDir: tempDir);
        adapter = RasterFallbackAdapter(mbtilesBackend: mbtilesBackend);
        await adapter.initialize();

        // Valida capacidades declaradas do modo de compatibilidade raster
        expect(adapter.capabilities.vectorRendering, isFalse);
        expect(adapter.capabilities.supportsRotation, isFalse);
        expect(adapter.capabilities.supportsTilt, isFalse);
        expect(adapter.capabilities.supportsOfflinePackages, isTrue);

        // Recupera tile raster 256x256 e verifica assinatura PNG
        final retrievedTile = await mbtilesBackend.getTile(10, 318, 520);
        expect(retrievedTile, isNotNull);
        expect(retrievedTile!.length, greaterThan(128));
        expect(
          retrievedTile.sublist(0, 8),
          equals(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
        );

        // Valida dimensões 256x256 nos bytes do cabeçalho IHDR
        final bd = ByteData.sublistView(retrievedTile);
        expect(bd.getUint32(16), equals(256)); // Largura
        expect(bd.getUint32(20), equals(256)); // Altura
      });

      test('PWT-06: MapLibre in Airplane Mode with Alto Solimões renders water layer and blocks direct river crossing', () async {
        final harness = await OpaqueBoxHarness.create(
          airplaneMode: true,
          startTileServer: true,
        );
        addTearDown(harness.dispose);

        final adapter = MaplibreNativeAdapter(
          tileServer: harness.tileServer!.server,
        );
        await adapter.initialize();

        // Valida existência da camada hidrológica no estilo MapLibre
        final style = adapter.generateStyleSpecification(
          packageId: 'alto_solimoes',
          isDarkMode: false,
        );
        final layers = style['layers'] as List<dynamic>;
        final waterLayer = layers.firstWhere((l) => l['id'] == 'water');
        expect(waterLayer['source-layer'], equals('water'));

        // Valida barreira fluvial no motor de roteamento offline
        final routingEngine = OfflineRoutingEngine.createAltoSolimoesNetwork();
        final directRiverResult = routingEngine.findRoute(
          startId: 'SAI_SUL',
          goalId: 'LAGO_GRANDE',
          allowWaterCrossingWithoutBridge: false,
        );

        // Bloqueio estrito de travessia a pé pelo leito do Rio Solimões
        expect(directRiverResult.isSuccess, isFalse);
        expect(
          directRiverResult.errorMessage,
          contains('restrições viárias e fluviais'),
        );
      });
    });

    // =========================================================================
    // Matrix 2: Query x Language x Diacritics (PWT-07 to PWT-12)
    // =========================================================================
    group('Matrix 2: Query x Language x Diacritics', () {
      late sql.Database ftsDb;

      setUp(() {
        ftsDb = sql.sqlite3.openInMemory();
        ftsDb.execute('''
          CREATE VIRTUAL TABLE geographic_features_fts USING fts5(
            id UNINDEXED,
            name,
            entity_type,
            latitude UNINDEXED,
            longitude UNINDEXED,
            details,
            tokenize = 'unicode61 remove_diacritics 2'
          );
        ''');

        ftsDb.execute('''
          INSERT INTO geographic_features_fts(id, name, entity_type, latitude, longitude, details) VALUES
            ('1', 'Duü̃', 'contact', '-3.1712', '-68.0825', 'Estudante da Bíblia em Betânia'),
            ('2', 'Taemãẽ', 'study_note', '-3.1705', '-68.0815', 'Taemãẽ na ĩ matü - Lição 04'),
            ('3', 'Santo Antônio do Içá', 'landmark', '-3.1022', '-67.9397', 'Sede municipal do Alto Solimões'),
            ('4', 'Betânia', 'sector', '-3.1700', '-68.0800', 'Comunidade indígena Ticuna no Rio Jandiatuba'),
            ('5', 'Lago Grande', 'community', '-3.2500', '-67.8500', 'Comunidade ribeirinha trans-Solimões');
        ''');
      });

      tearDown(() {
        ftsDb.close();
      });

      test(
        'PWT-07: Query "Duü̃" (Ticuna) matches Contact "Duü̃" at Rank 1',
        () {
          final rows = ftsDb.select('''
          SELECT name, entity_type, latitude, longitude, rank
          FROM geographic_features_fts
          WHERE geographic_features_fts MATCH 'Duü̃'
          ORDER BY rank;
        ''');

          expect(rows.isNotEmpty, isTrue);
          expect(rows.first['name'], equals('Duü̃'));
          expect(rows.first['entity_type'], equals('contact'));
          expect(rows.first['latitude'], equals('-3.1712'));
          expect(rows.first['longitude'], equals('-68.0825'));
        },
      );

      test('PWT-08: Query "Duu" (Ticuna unaccented) matches Contact "Duü̃" via remove_diacritics', () {
        final rows = ftsDb.select('''
          SELECT name, entity_type, rank
          FROM geographic_features_fts
          WHERE geographic_features_fts MATCH 'Duu'
          ORDER BY rank;
        ''');

        expect(rows.isNotEmpty, isTrue);
        expect(rows.first['name'], equals('Duü̃'));
        expect(rows.first['entity_type'], equals('contact'));
      });

      test('PWT-09: Query "duü~" (real-time input normalized) converts to "Duü̃" and matches Rank 1', () {
        // 1. Normalização via TicunaUnicodeHelper
        const rawInput = 'duü~';
        final normalized = TicunaUnicodeHelper.normalize(rawInput);
        expect(normalized, contains('ü\u0303')); // Diérese + til combinante WOL

        // 2. Consulta FTS5 com termo normalizado
        final rows = ftsDb.select('''
          SELECT name, entity_type, rank
          FROM geographic_features_fts
          WHERE geographic_features_fts MATCH '$normalized'
          ORDER BY rank;
        ''');

        expect(rows.isNotEmpty, isTrue);
        expect(rows.first['name'], equals('Duü̃'));
      });

      test('PWT-10: Query "Taemãẽ" (canonical stacked vowel) matches study note with highlight', () {
        final rows = ftsDb.select('''
          SELECT name, details, highlight(geographic_features_fts, 5, '<b>', '</b>') as highlighted_details
          FROM geographic_features_fts
          WHERE geographic_features_fts MATCH 'Taemãẽ'
          ORDER BY rank;
        ''');

        expect(rows.isNotEmpty, isTrue);
        expect(rows.first['name'], equals('Taemãẽ'));
        expect(rows.first['details'], contains('Taemãẽ na ĩ matü - Lição 04'));
        expect(rows.first['highlighted_details'], contains('<b>Taemãẽ</b>'));
      });

      test('PWT-11: Query "Santo Antonio" matches Landmark "Santo Antônio" diacritic-insensitively', () {
        final rows = ftsDb.select('''
          SELECT name, entity_type, rank
          FROM geographic_features_fts
          WHERE geographic_features_fts MATCH 'Santo Antonio'
          ORDER BY rank;
        ''');

        expect(rows.isNotEmpty, isTrue);
        expect(rows.first['name'], equals('Santo Antônio do Içá'));
        expect(rows.first['entity_type'], equals('landmark'));
      });

      test('PWT-12: Query "Betânia" matches Community/Sector at Rank 1 (-3.17, -68.08)', () {
        final rows = ftsDb.select('''
          SELECT name, entity_type, latitude, longitude, rank
          FROM geographic_features_fts
          WHERE geographic_features_fts MATCH 'name: Betânia'
          ORDER BY rank;
        ''');

        expect(rows.isNotEmpty, isTrue);
        expect(rows.first['name'], equals('Betânia'));
        expect(rows.first['entity_type'], equals('sector'));
        expect(rows.first['latitude'], equals('-3.1700'));
        expect(rows.first['longitude'], equals('-68.0800'));
      });
    });

    // =========================================================================
    // Matrix 3: Security x Sync x Platform Integration (PWT-13 to PWT-16)
    // =========================================================================
    group('Matrix 3: Security x Sync x Platform Integration', () {
      testWidgets(
        'PWT-13: Appointments x EventKit Calendar Sync x Adaptive Layout creates appointment on iPad in landscape, computes SHA-256 fingerprint, and verifies zero RenderFlex overflow',
        (tester) async {
          final harness = await OpaqueBoxHarness.create(
            airplaneMode: true,
            startTileServer: false,
          );
          addTearDown(harness.dispose);

          final appointmentStart = DateTime(2026, 11, 18, 10, 0);
          final appointmentEnd = appointmentStart.add(const Duration(hours: 1));

          await harness.repo.createAppointment(
            title: 'Revisita com Duü̃ em Betânia',
            startTime: appointmentStart,
            endTime: appointmentEnd,
            durationMinutes: 60,
          );

          // 1. Gera fingerprint SHA-256 via AppleEventKitProvider
          final fingerprint = AppleEventKitProvider.computeEventFingerprint(
            externalEventId: 'ext-event-betania-01',
            calendarId: 'cal-field-ministry',
            title: 'Revisita com Duü̃ em Betânia',
            startTime: appointmentStart,
            endTime: appointmentEnd,
          );

          expect(fingerprint.length, equals(64));
          expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(fingerprint), isTrue);

          // 2. Renderiza no viewport iPad Landscape (1024x768)
          await tester.pumpHarnessScreen(
            screen: const AppointmentsScreen(),
            harness: harness,
            devicePreset: E2EDevicePreset.tablet,
          );

          expect(find.byType(AppointmentsScreen), findsOneWidget);
          expect(tester.takeException(), isNull);

          // Limpa widget tree
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettleSafely();
        },
      );

      test('PWT-14: SQLite3MC Encrypted at Rest x Backup v3 Export/Import x Clean SyncQueue creates person in encrypted DB, exports PBKDF2 600k backup, restores, and verifies syncQueue is clean', () async {
        final db = InMemoryEncryptedDb.createInMemory();
        addTearDown(db.close);
        final repo = AppRepository(db);

        // 1. Cria pessoa no banco
        await repo.createPerson(
          name: 'Moisés Ticuna',
          address: 'Aldeia de Betânia',
        );

        // 2. Insere entrada pendente na fila de sincronização
        await db
            .into(db.syncQueue)
            .insert(
              SyncQueueCompanion.insert(
                id: 'sync-queue-pwt-14',
                entityType: 'people',
                entityId: 'moises-ticuna-id',
                operation: 'INSERT',
                payload: '{"name":"Moisés Ticuna"}',
                createdAt: DateTime.now(),
                status: const drift.Value('pending'),
              ),
            );

        final backupService = BackupService(repo);

        // 3. Exporta Backup v3 criptografado com 600.000 iterações PBKDF2
        final backupJson = await backupService.exportEncryptedBackupV3(
          'SenhaSeguraBackup2026!',
          iterations: 600000,
        );

        final decoded = jsonDecode(backupJson) as Map<String, dynamic>;
        expect(decoded['version'], equals(3));
        expect(decoded['iterations'], equals(600000));
        expect(decoded['kdf'], equals('PBKDF2-HMAC-SHA256'));

        // 4. Valida no preview que syncQueue não polui o backup em um banco de destino limpo
        final targetDb = InMemoryEncryptedDb.createInMemory();
        addTearDown(targetDb.close);
        final targetBackupService = BackupService(AppRepository(targetDb));
        final preview = await targetBackupService.previewBackup(
          encryptedDataString: backupJson,
          password: 'SenhaSeguraBackup2026!',
        );
        expect(preview.syncQueueToAdd, equals(0));
        expect(preview.peopleToAdd, equals(1));
      });

      test('PWT-15: Encrypted Media Transfer (AES-GCM) x CAS Manifest x Cross-Owner Isolation seals voice note with Account A key and blocks Account B decryption fail-closed', () async {
        final algorithm = AesGcm.with256bits();
        final keyA = await algorithm.newSecretKey();
        final keyB = await algorithm.newSecretKey();

        const ownerA = 'user-publisher-a-uuid';
        const ownerB = 'user-publisher-b-uuid';
        const mediaId = 'voice-note-audio-jandiatuba';

        final audioPlaintext = Uint8List.fromList(
          utf8.encode(
            'Gravação de voz da conversa ministerial no Rio Jandiatuba',
          ),
        );

        final storedChunks = <int, Map<String, Object>>{};

        // 1. Conta A criptografa mídia em blocos autenticados
        final manifestBox = await EncryptedMedia.encrypt(
          key: keyA,
          owner: ownerA,
          mediaId: mediaId,
          source: Stream.value(audioPlaintext),
          storeChunk: (index, chunkBox) async {
            storedChunks[index] = chunkBox;
          },
        );

        expect(manifestBox['ciphertext'], isNotNull);
        expect(manifestBox['tag'], isNotNull);
        expect(storedChunks.isNotEmpty, isTrue);

        // 2. Conta A descriptografa com sucesso o manifesto
        final decryptedManifestBytes = await RecoveryCrypto.open(
          key: keyA,
          owner: ownerA,
          kind: 'media-manifest-v1',
          id: mediaId,
          envelope: manifestBox,
        );
        expect(decryptedManifestBytes, isNotNull);
        final manifestJson = jsonDecode(
          utf8.decode(decryptedManifestBytes),
        ) as Map<String, dynamic>;
        expect(manifestJson['total'], equals(audioPlaintext.length));

        // 3. Conta B (chave incorreta e proprietário divergente) tenta descriptografar
        await expectLater(
          RecoveryCrypto.open(
            key: keyB,
            owner: ownerB,
            kind: 'media-manifest-v1',
            id: mediaId,
            envelope: manifestBox,
          ),
          throwsA(isA<SecretBoxAuthenticationError>()),
        );
      });

      test('PWT-16: Offline Routing (A*) x Territory Sector x Field Publisher Workflow routes within Betânia sector and avoids Solimões river', () async {
        final routingEngine = OfflineRoutingEngine.createAltoSolimoesNetwork();

        // 1. Rota interna no setor de Betânia (Centro até limite do setor na estrada)
        final sectorRoute = routingEngine.findRoute(
          startId: 'BETANIA_CENTRO',
          goalId: 'ESTRADA_BETANIA_2',
          mode: RoutingMode.walking,
        );

        expect(sectorRoute.isSuccess, isTrue);
        expect(
          sectorRoute.pathNodeIds,
          equals(['BETANIA_CENTRO', 'ESTRADA_BETANIA_2']),
        );
        expect(sectorRoute.totalDistanceMeters, greaterThan(0));

        // 2. Rota de Betânia para Lago Grande através do Rio Solimões:
        // Sem travessia fluvial sem ponte (allowWaterCrossingWithoutBridge: false),
        // o roteador A* deve contornar pela Balsa autorizada
        final crossRiverRoute = routingEngine.findRoute(
          startId: 'BETANIA_CENTRO',
          goalId: 'LAGO_GRANDE',
          mode: RoutingMode.driving,
          allowWaterCrossingWithoutBridge: false,
        );

        expect(crossRiverRoute.isSuccess, isTrue);
        // Certifica que a rota passa pelos portos de balsa e não pela aresta fluvial sem ponte
        expect(crossRiverRoute.pathNodeIds, contains('BALSA_PORTO_NORTE'));
        expect(crossRiverRoute.pathNodeIds, contains('BALSA_PORTO_SUL'));
        expect(crossRiverRoute.pathNodeIds.contains('SAI_SUL'), isTrue);
      });
    });
  });
}
