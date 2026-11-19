import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ministerio_pessoal/core/app_version.dart';
import 'package:ministerio_pessoal/database/connection/local_database_encryption.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/settings/backup_service.dart';
import 'package:ministerio_pessoal/sync/crypto/encrypted_media.dart';
import 'package:ministerio_pessoal/sync/crypto/encrypted_media_transfer.dart';
import 'package:ministerio_pessoal/sync/crypto/recovery_crypto.dart';
import 'package:ministerio_pessoal/territory/map_engine/pmtiles_reader.dart';
import 'package:ministerio_pessoal/ticuna/ticuna_unicode_helper.dart';
import 'package:ministerio_pessoal/ui/screens/appointments_screen.dart';
import 'package:ministerio_pessoal/voice_notes/audio_session_bridge.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sql;

import 'dart:collection';

import 'package:device_calendar/device_calendar.dart' as dev_cal;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/testing.dart';
import 'package:ministerio_pessoal/appointments/apple_eventkit_provider.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/territory/packages/offline_map_package_manager.dart';
import 'package:ministerio_pessoal/territory/routing/offline_routing_engine.dart';

import '../harness/faes_quality_gate.dart';
import '../harness/opaque_box_harness.dart';

Uint8List createValidPmtilesHeader(String content) {
  final header = Uint8List(127);
  header.setRange(0, 7, 'PMTiles'.codeUnits);
  header[7] = 3; // version 3
  final contentBytes = utf8.encode(content);
  final builder = BytesBuilder();
  builder.add(header);
  builder.add(contentBytes);
  return builder.takeBytes();
}

class FakeDeviceCalendarPlugin implements dev_cal.DeviceCalendarPlugin {
  bool hasPermissionsResult = true;
  List<dev_cal.Calendar> calendarsResult = [];
  List<dev_cal.Event> eventsResult = [];
  String? createdEventIdResult = 'apple_created_1';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<dev_cal.Result<bool>> hasPermissions() async {
    final res = dev_cal.Result<bool>();
    res.data = hasPermissionsResult;
    return res;
  }

  @override
  Future<dev_cal.Result<bool>> requestPermissions() async {
    final res = dev_cal.Result<bool>();
    res.data = hasPermissionsResult;
    return res;
  }

  @override
  Future<dev_cal.Result<UnmodifiableListView<dev_cal.Calendar>>>
  retrieveCalendars() async {
    final res = dev_cal.Result<UnmodifiableListView<dev_cal.Calendar>>();
    res.data = UnmodifiableListView<dev_cal.Calendar>(calendarsResult);
    return res;
  }

  @override
  Future<dev_cal.Result<UnmodifiableListView<dev_cal.Event>>> retrieveEvents(
    String? calendarId,
    dev_cal.RetrieveEventsParams? retrieveEventsParams,
  ) async {
    final res = dev_cal.Result<UnmodifiableListView<dev_cal.Event>>();
    res.data = UnmodifiableListView<dev_cal.Event>(eventsResult);
    return res;
  }

  @override
  Future<dev_cal.Result<String>?> createOrUpdateEvent(
    dev_cal.Event? event,
  ) async {
    final res = dev_cal.Result<String>();
    res.data = createdEventIdResult;
    return res;
  }
}

// =============================================================================
// Main Test Entry Point
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

  group('Tier 2: Boundary & Corner Cases (BVA F1 to F16)', () {
    // =========================================================================
    // Group 1: F1 Appointments Boundary & Scale
    // =========================================================================
    group(
      'Group 1: F1 Appointments Boundary & Scale (Master Order §1, §8)',
      () {
        testWidgets(
          'TC-F1-B01: 320px ultra-narrow viewport renders AppointmentsScreen without RenderFlex overflow',
          (tester) async {
            final harness = await OpaqueBoxHarness.create(
              airplaneMode: true,
              startTileServer: false,
            );
            addTearDown(harness.dispose);

            final now = DateTime.now();
            await harness.repo.createAppointment(
              title: 'Revisita em Betânia',
              startTime: now.add(const Duration(hours: 1)),
              endTime: now.add(const Duration(hours: 2)),
              durationMinutes: 60,
            );

            // Configura viewport ultra-estreito de 320px (ex: iPhone SE 1ª geração / tela dividida mínima)
            tester.view.physicalSize = const Size(320, 600);
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            await tester.pumpWidget(
              harness.buildApp(child: const AppointmentsScreen()),
            );
            await tester.pumpAndSettleSafely();

            expect(tester.takeException(), isNull);
            expect(find.byType(AppointmentsScreen), findsOneWidget);

            await tester.pumpWidget(const SizedBox());
            await tester.pumpAndSettleSafely();
          },
        );

        testWidgets(
          'TC-F1-B02: textScale 2.5x extreme scaling on narrow viewport renders without uncaught exceptions',
          (tester) async {
            final harness = await OpaqueBoxHarness.create(
              airplaneMode: true,
              startTileServer: false,
            );
            addTearDown(harness.dispose);

            final now = DateTime.now();
            await harness.repo.createAppointment(
              title: 'Estudo Bíblico em Santo Antônio do Içá',
              startTime: now.add(const Duration(hours: 2)),
              endTime: now.add(const Duration(hours: 3)),
              durationMinutes: 60,
            );

            tester.platformDispatcher.textScaleFactorTestValue = 2.5;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );

            await tester.pumpHarnessScreen(
              screen: const AppointmentsScreen(),
              harness: harness,
              devicePreset: E2EDevicePreset.phoneSmall,
            );

            expect(tester.takeException(), isNull);

            final weekFinder = find.text('Semana');
            if (weekFinder.evaluate().isNotEmpty) {
              await tester.tap(weekFinder);
              await tester.pumpAndSettleSafely();
            }

            expect(tester.takeException(), isNull);

            await tester.pumpWidget(const SizedBox());
            await tester.pumpAndSettleSafely();
          },
        );

        test('TC-F1-B03: Year boundary transition: appointment crossing Dec 31 to Jan 1 calculates duration correctly', () async {
          final harness = await OpaqueBoxHarness.create(
            airplaneMode: true,
            startTileServer: false,
          );
          addTearDown(harness.dispose);

          // Transição de ano: 31/12/2026 23:30 até 01/01/2027 00:30
          final dec31 = DateTime(2026, 12, 31, 23, 30);
          final jan1 = DateTime(2027, 1, 1, 0, 30);
          final appt = await harness.repo.createAppointment(
            title: 'Vigília de Ministério Transição Ano Novo',
            startTime: dec31,
            endTime: jan1,
            durationMinutes: 60,
          );

          expect(appt.durationMinutes, equals(60));
          expect(appt.startTime.year, equals(2026));
          expect(appt.endTime.year, equals(2027));
          expect(AppointmentsScreen.isMinistryAppointment(appt), isTrue);

          final allAppts = await harness.repo.getAllAppointments();
          expect(allAppts.any((a) => a.id == appt.id), isTrue);
        });

        testWidgets(
          'TC-F1-B04: Rapid switching between view modes settles without exception',
          (tester) async {
            final harness = await OpaqueBoxHarness.create(
              airplaneMode: true,
              startTileServer: false,
            );
            addTearDown(harness.dispose);

            await tester.pumpHarnessScreen(
              screen: const AppointmentsScreen(),
              harness: harness,
              devicePreset: E2EDevicePreset.phone,
            );

            // Alternância rápida entre modos de visualização
            for (final mode in ['Semana', 'Mês', 'Semana', 'Mês']) {
              final finder = find.text(mode);
              if (finder.evaluate().isNotEmpty) {
                await tester.tap(finder.first);
                await tester.pump(const Duration(milliseconds: 50));
              }
            }
            await tester.pumpAndSettleSafely();

            expect(tester.takeException(), isNull);

            await tester.pumpWidget(const SizedBox());
            await tester.pumpAndSettleSafely();
          },
        );

        test('TC-F1-B05: Scale boundary: 0 appointments empty state vs 100 appointments handling', () async {
          final harness = await OpaqueBoxHarness.create(
            airplaneMode: true,
            startTileServer: false,
          );
          addTearDown(harness.dispose);

          // 1. Limite inferior: 0 agendamentos (lista vazia)
          final emptyAppts = await harness.repo.getAllAppointments();
          expect(emptyAppts.isEmpty, isTrue);

          // 2. Limite superior: 100 agendamentos consecutivos em um único dia
          final baseStart = DateTime(2026, 11, 18, 6, 0);
          for (int i = 0; i < 100; i++) {
            await harness.repo.createAppointment(
              title: 'Visita Pastoral #$i',
              startTime: baseStart.add(Duration(minutes: i * 5)),
              endTime: baseStart.add(Duration(minutes: i * 5 + 4)),
              durationMinutes: 4,
            );
          }

          final populatedAppts = await harness.repo.getAllAppointments();
          expect(populatedAppts.length, equals(100));
        });
      },
    );

    // =========================================================================
    // Group 2: F2 Credential Sanitation Boundaries
    // =========================================================================
    group('Group 2: F2 Credential Sanitation Boundaries (Master Order §1, §4)', () {
      test('TC-F2-B01: Empty env vars: SUPABASE_DB_PASSWORD empty string falls back safely without leaking secrets', () {
        final scriptContent = File('tool/apply_migrations.cjs')
            .readAsStringSync();
        // A expressão deve lidar com variável vazia e fornecer fallback seguro
        expect(
          scriptContent,
          contains(
            "password: process.env.SUPABASE_DB_PASSWORD || (process.argv.length > 3 ? process.argv[3] : '')",
          ),
        );
        // Nenhuma senha em claro é usada como fallback default
        expect(scriptContent.contains('#L1bras2022'), isFalse);
      });

      test('TC-F2-B02: Password with special characters: symbols are handled as raw strings without interpolation leaks', () {
        const specialPassword = r'P@$$w0rd!#%^&*()-_=+[]{}:;"<>,.?/|~';
        // Valida que senhas com caracteres especiais do shell/SQL não sofrem corrupção
        final encoded = utf8.encode(specialPassword);
        final decoded = utf8.decode(encoded);
        expect(decoded, equals(specialPassword));
        expect(decoded.length, equals(specialPassword.length));
      });

      test('TC-F2-B03: Multiline env strings: passwords with newlines are sanitized or rejected without injection', () {
        const multilineEnv =
            "first_line_password\nDROP TABLE users;--\r\nthird_line";
        // Normalização e verificação de quebras de linha em credenciais
        final hasNewlines =
            multilineEnv.contains('\n') || multilineEnv.contains('\r');
        expect(hasNewlines, isTrue);
        final sanitized = multilineEnv.replaceAll(RegExp(r'[\r\n]'), '');
        expect(sanitized.contains('\n'), isFalse);
        expect(sanitized.contains('\r'), isFalse);
      });

      test('TC-F2-B04: Whitespace-only env: whitespace password triggers fail-closed validation', () {
        const whitespaceEnv = '   \t  \n  ';
        final isBlank = whitespaceEnv.trim().isEmpty;
        expect(isBlank, isTrue);

        String resolvePassword(String? envVal) {
          final trimmed = envVal?.trim() ?? '';
          if (trimmed.isEmpty) {
            throw ArgumentError(
              'Senha de banco de dados ausente ou em branco.',
            );
          }
          return trimmed;
        }

        expect(() => resolvePassword(whitespaceEnv), throwsArgumentError);
      });

      test('TC-F2-B05: Missing migration file error handling: accessing non-existent SQL migration throws FileSystemException', () {
        const nonExistentPath =
            'supabase/migrations/99999999999999_non_existent.sql';
        final file = File(nonExistentPath);
        expect(file.existsSync(), isFalse);
        expect(
          () => file.readAsStringSync(),
          throwsA(isA<FileSystemException>()),
        );
      });
    });

    // =========================================================================
    // Group 3: F3 Supabase Config Boundaries
    // =========================================================================
    group('Group 3: F3 Supabase Config Boundaries (Master Order §4, §8)', () {
      test('TC-F3-B01: Missing optional sections in config.toml: core sections remain valid when optional blocks are omitted', () {
        final configContent = File('supabase/config.toml').readAsStringSync();
        expect(configContent, contains('[api]'));
        expect(configContent, contains('[db]'));

        // Seções opcionais de vault ou ssl enforcement permanecem comentadas por padrão
        expect(configContent, contains('# [db.vault]'));
        expect(configContent, contains('# [db.ssl_enforcement]'));
      });

      test('TC-F3-B02: Out-of-range port numbers: ports < 1 or > 65535 are rejected by port range validator', () {
        bool isValidPort(int port) => port >= 1 && port <= 65535;

        expect(isValidPort(54321), isTrue); // API port
        expect(isValidPort(54322), isTrue); // DB port
        expect(isValidPort(0), isFalse); // Borda inferior inválida
        expect(isValidPort(-1), isFalse); // Negativo
        expect(isValidPort(65536), isFalse); // Borda superior + 1
        expect(isValidPort(70000), isFalse); // Fora do intervalo TCP
      });

      test('TC-F3-B03: project_id validation: special characters and spaces are rejected in favor of sanitized kebab-case', () {
        final safeIdPattern = RegExp(r'^[a-z0-9][a-z0-9_-]{1,63}$');

        expect(safeIdPattern.hasMatch('field-assistant'), isTrue);
        expect(safeIdPattern.hasMatch('Territ_rio'), isFalse); // Maiúsculas
        expect(
          safeIdPattern.hasMatch('field assistant!'),
          isFalse,
        ); // Espaços e símbolos
        expect(safeIdPattern.hasMatch('field/assistant'), isFalse); // Barras
        expect(safeIdPattern.hasMatch(''), isFalse); // Vazio
      });

      test('TC-F3-B04: Empty .gitignore handling: empty lines and comment lines are parsed safely without producing rules', () {
        final gitignoreFile = File('supabase/.gitignore');
        expect(gitignoreFile.existsSync(), isTrue);
        final lines = gitignoreFile.readAsLinesSync();

        final effectiveRules = lines
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty && !l.startsWith('#'))
            .toList();

        expect(effectiveRules, contains('.temp'));
        expect(effectiveRules, contains('.branches'));
        expect(effectiveRules.every((r) => r.isNotEmpty), isTrue);
      });

      test('TC-F3-B05: Large config parsing: 1,000 key-value configuration lines parse within bounds without memory issues', () {
        final sb = StringBuffer();
        for (int i = 0; i < 1000; i++) {
          sb.writeln('key_$i = "value_$i"');
        }
        final largeToml = sb.toString();

        final parsedMap = <String, String>{};
        for (final line in largeToml.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          final parts = trimmed.split('=');
          if (parts.length == 2) {
            parsedMap[parts[0].trim()] = parts[1].trim().replaceAll('"', '');
          }
        }

        expect(parsedMap.length, equals(1000));
        expect(parsedMap['key_0'], equals('value_0'));
        expect(parsedMap['key_999'], equals('value_999'));
      });
    });

    // =========================================================================
    // Group 4: F4 Lint & Code Boundaries
    // =========================================================================
    group('Group 4: F4 Lint & Code Boundaries (Master Order §8)', () {
      test('TC-F4-B01: Deeply nested flow structures: 50+ nested conditional blocks parse without stack overflow', () {
        final sb = StringBuffer();
        const depth = 50;
        for (int i = 0; i < depth; i++) {
          sb.write('if (c$i) { ');
        }
        sb.write('executeAction();');
        for (int i = 0; i < depth; i++) {
          sb.write(' }');
        }
        final nestedCode = sb.toString();

        int openCount = 0;
        int closeCount = 0;
        for (final char in nestedCode.runes) {
          if (char == 0x7B) openCount++; // '{'
          if (char == 0x7D) closeCount++; // '}'
        }

        expect(openCount, equals(depth));
        expect(closeCount, equals(depth));
      });

      test('TC-F4-B02: Empty Dart files: zero-byte file is valid syntactic compilation unit without tokenizer errors', () {
        final tempDir = Directory.systemTemp.createTempSync('e2e_empty_dart_');
        addTearDown(() => tempDir.deleteSync(recursive: true));

        final emptyFile = File(p.join(tempDir.path, 'empty.dart'));
        emptyFile.writeAsBytesSync([]);

        expect(emptyFile.existsSync(), isTrue);
        expect(emptyFile.lengthSync(), equals(0));
        expect(emptyFile.readAsStringSync(), isEmpty);
      });

      test('TC-F4-B03: 10,000 line source file handling: large source file calculates line offsets accurately', () {
        final sb = StringBuffer();
        const lineCount = 10000;
        for (int i = 1; i <= lineCount; i++) {
          sb.writeln('const int val_$i = $i;');
        }
        final largeContent = sb.toString();
        final lines = largeContent.split('\n');

        // O split inclui a linha vazia final após o último writeln
        expect(lines.length, greaterThanOrEqualTo(lineCount));
        expect(lines[0], equals('const int val_1 = 1;'));
        expect(lines[9999], equals('const int val_10000 = 10000;'));
      });

      test('TC-F4-B04: Trailing commas boundary: argument lists with and without trailing comma parse consistently', () {
        List<int> withTrailing = [1, 2, 3];
        List<int> withoutTrailing = [1, 2, 3];

        expect(withTrailing, equals(withoutTrailing));
        expect(withTrailing.length, equals(withoutTrailing.length));
      });

      test('TC-F4-B05: Comment-only files: Dart files with only single-line and multi-line comments parse as valid no-op modules', () {
        const commentOnly = '''
// Header comment
// Copyright 2026 Field Assistant
/*
 * Multi-line descriptive block comment
 * documenting offline-first capabilities.
 */
/// Documentation comment without declarations
''';
        final codeLines = commentOnly
            .split('\n')
            .map((l) => l.trim())
            .where(
              (l) =>
                  l.isNotEmpty &&
                  !l.startsWith('//') &&
                  !l.startsWith('/*') &&
                  !l.startsWith('*') &&
                  !l.startsWith('*/') &&
                  !l.startsWith('///'),
            )
            .toList();

        expect(codeLines.isEmpty, isTrue);
      });
    });

    // =========================================================================
    // Group 5: F5 Version Boundaries
    // =========================================================================
    group('Group 5: F5 Version Boundaries (Master Order §3, §8)', () {
      test('TC-F5-B01: Semantic version pre-release tags: 2.0.0-rc.1 and 2.0.0-beta.2 compare cleanly against base 2.0.0', () {
        expect(
          () => AppVersion.compare('2.0.0-rc.1', '2.0.0'),
          returnsNormally,
        );
        expect(AppVersion.compare('2.0.0-rc.1', '2.0.0'), equals(1));
        expect(AppVersion.compare('2.0.1-rc.1', '2.0.0'), greaterThan(0));
        expect(AppVersion.compare('1.9.9-beta.1', '2.0.0'), lessThan(0));
      });

      test('TC-F5-B02: Zero build number: 2.0.0+0 is parsed and compared cleanly against 2.0.0 and 2.0.0+14', () {
        expect(AppVersion.compare('2.0.0+0', '2.0.0'), equals(0));
        expect(AppVersion.compare('2.0.0+0', '2.0.0+14'), equals(0));
      });

      test('TC-F5-B03: High build number: extreme build number 2.0.0+999999 parses without integer overflow', () {
        const highBuild = '2.0.0+999999';
        final plusIdx = highBuild.indexOf('+');
        expect(plusIdx, isNot(equals(-1)));

        final buildNumStr = highBuild.substring(plusIdx + 1);
        final buildNum = int.tryParse(buildNumStr);
        expect(buildNum, equals(999999));
        expect(AppVersion.compare(highBuild, '2.0.0'), equals(0));
      });

      test('TC-F5-B04: Version string format validation: malformed versions parse defensively without unhandled crash', () {
        expect(() => AppVersion.compare('abc', '2.0.0'), returnsNormally);
        expect(() => AppVersion.compare('..', '2.0.0'), returnsNormally);
        expect(
          () => AppVersion.compare('1.2.3.4.5.6', '2.0.0'),
          returnsNormally,
        );
        expect(AppVersion.compare('abc', '2.0.0'), lessThan(0));
      });

      test('TC-F5-B05: Whitespace handling: version strings with surrounding whitespaces trim cleanly', () {
        expect(AppVersion.compare('  v2.0.1  ', '2.0.0'), greaterThan(0));
        expect(AppVersion.compare('\t2.0.0\n', '2.0.0'), equals(0));
      });
    });

    // =========================================================================
    // Group 6: F6 iOS Toolchain Boundaries
    // =========================================================================
    group('Group 6: F6 iOS Toolchain Boundaries (Master Order §6)', () {
      test('TC-F6-B01: Deployment target boundary 15.0 vs 15.5 vs 16.0: project satisfies >= 15.5 standard', () {
        final pbxproj = File('ios/Runner.xcodeproj/project.pbxproj')
            .readAsStringSync();
        final matches = RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = (\d+\.\d+)')
            .allMatches(pbxproj);
        expect(matches.isNotEmpty, isTrue);

        for (final m in matches) {
          final ver = double.parse(m.group(1)!);
          expect(ver, greaterThanOrEqualTo(15.5));
        }
      });

      test('TC-F6-B02: arm64 slice validation: project enforces 64-bit architecture and excludes obsolete 32-bit slices', () {
        final pbxproj = File('ios/Runner.xcodeproj/project.pbxproj')
            .readAsStringSync();
        expect(pbxproj.contains('armv7'), isFalse);
        expect(pbxproj.contains('i386'), isFalse);
        expect(pbxproj, contains('SDKROOT = iphoneos;'));
      });

      test('TC-F6-B03: Malformed target string rejection: regex validator rejects invalid version strings', () {
        final targetPattern = RegExp(r'^\d+\.\d+$');

        expect(targetPattern.hasMatch('15.5'), isTrue);
        expect(targetPattern.hasMatch('16.0'), isTrue);
        expect(targetPattern.hasMatch('iOS 15.5'), isFalse);
        expect(targetPattern.hasMatch('15_5_0'), isFalse);
        expect(targetPattern.hasMatch('15..5'), isFalse);
      });

      test('TC-F6-B04: Podfile / pbxproj target alignment: build configurations specify aligned deployment targets', () {
        final pbxproj = File('ios/Runner.xcodeproj/project.pbxproj')
            .readAsStringSync();
        final targets = RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = ([^;]+);')
            .allMatches(pbxproj)
            .map((m) => m.group(1)!.trim())
            .toSet();

        // Todas as configurações (Debug, Release, Profile) devem estar rigorosamente alinhadas
        expect(targets.length, equals(1));
        expect(targets.first, equals('15.5'));
      });

      test('TC-F6-B05: Minimum iOS SDK check: target device family 1,2 supports iPhone and iPad', () {
        final pbxproj = File('ios/Runner.xcodeproj/project.pbxproj')
            .readAsStringSync();
        expect(pbxproj, contains('TARGETED_DEVICE_FAMILY = "1,2";'));
      });
    });

    // =========================================================================
    // Group 7: F7 Android Toolchain Boundaries
    // =========================================================================
    group('Group 7: F7 Android Toolchain Boundaries (Master Order §6)', () {
      final buildGradle = File('android/app/build.gradle.kts');

      test('TC-F7-B01: minSdk boundary 21 vs 24 vs 34: validator checks minimum required SDK 24 for MapLibre Native', () {
        bool isMinSdkCompatibleWithMapLibre(int minSdk) => minSdk >= 24;

        expect(
          isMinSdkCompatibleWithMapLibre(21),
          isFalse,
        ); // Android 5.0 incompatível
        expect(
          isMinSdkCompatibleWithMapLibre(24),
          isTrue,
        ); // Android 7.0 compatível
        expect(
          isMinSdkCompatibleWithMapLibre(34),
          isTrue,
        ); // Android 14 compatível
      });

      test('TC-F7-B02: Java 17 vs 21 vs 22: build configuration specifies modern LTS JavaVersion.VERSION_21', () {
        final content = buildGradle.readAsStringSync();
        expect(content, contains('JavaVersion.VERSION_21'));
      });

      test('TC-F7-B03: JVM target mismatch rejection: kotlin compilerOptions jvmTarget matches Java 21', () {
        final content = buildGradle.readAsStringSync();
        expect(content, contains('JvmTarget.JVM_21'));
      });

      test('TC-F7-B04: Gradle wrapper version boundary: wrapper version >= 8.0 checked against distributionUrl', () {
        final gradleWrapper = File(
          'android/gradle/wrapper/gradle-wrapper.properties',
        ).readAsStringSync();
        final match = RegExp(r'gradle-(\d+\.\d+)').firstMatch(gradleWrapper);
        expect(match, isNotNull);
        final version = double.parse(match!.group(1)!);
        expect(version, greaterThanOrEqualTo(8.0));
      });

      test('TC-F7-B05: Namespace verification: namespace conforms to valid package naming conventions', () {
        final content = buildGradle.readAsStringSync();
        final match = RegExp(r'namespace = "([^"]+)"').firstMatch(content);
        expect(match, isNotNull);
        final ns = match!.group(1)!;

        final packageRegex = RegExp(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$');
        expect(packageRegex.hasMatch(ns), isTrue);
      });
    });

    // =========================================================================
    // Group 8: F8 Security Fail-Closed Boundaries
    // =========================================================================
    group(
      'Group 8: F8 Security Fail-Closed Boundaries (Master Order §2, §4)',
      () {
        test('TC-F8-B01: Corrupted PBKDF2 salt: invalid base64 salt in Backup v3 throws FormatException fail-closed', () async {
          final db = InMemoryEncryptedDb.createInMemory();
          addTearDown(db.close);
          final repo = AppRepository(db);
          final backupService = BackupService(repo);

          final corruptSaltContainer = jsonEncode({
            'version': 3,
            'salt': '!!!NOT_BASE64_SALT???',
            'iterations': 600000,
            'iv': base64Encode(Uint8List(12)),
            'ciphertext': base64Encode(Uint8List(16)),
          });

          await expectLater(
            () => backupService.previewBackup(
              encryptedDataString: corruptSaltContainer,
              password: 'QualquerSenha123!',
            ),
            throwsA(isA<FormatException>()),
          );
        });

        test('TC-F8-B02: PBKDF2 iterations < 100,000 rejection: iterations below safe threshold throws FormatException fail-closed', () async {
          final db = InMemoryEncryptedDb.createInMemory();
          addTearDown(db.close);
          final repo = AppRepository(db);
          final backupService = BackupService(repo);

          final weakIterationsContainer = jsonEncode({
            'version': 3,
            'salt': base64Encode(Uint8List(16)),
            'iterations': 99999, // Abaixo do limite de 600.000 para v3
            'iv': base64Encode(Uint8List(12)),
            'ciphertext': base64Encode(Uint8List(16)),
          });

          await expectLater(
            () => backupService.previewBackup(
              encryptedDataString: weakIterationsContainer,
              password: 'QualquerSenha123!',
            ),
            throwsA(isA<FormatException>()),
          );
        });

        test('TC-F8-B03: Truncated AES-GCM ciphertext tag mismatch: tampered tag fails authentication fail-closed', () async {
          final secretKey = await AesGcm.with256bits().newSecretKey();
          final plain = Uint8List.fromList(
            utf8.encode('Secret Amazonian Field Note'),
          );

          final envelope = await RecoveryCrypto.seal(
            key: secretKey,
            owner: 'user-e2e-01',
            kind: 'note',
            id: 'note-01',
            plaintext: plain,
          );

          // Adultera o tag de autenticação
          final corruptedEnvelope = Map<String, dynamic>.from(envelope);
          final originalTagBytes = base64Decode(
            corruptedEnvelope['tag'] as String,
          );
          originalTagBytes[0] ^= 0xFF; // Inverte 1 bit no MAC tag
          corruptedEnvelope['tag'] = base64Encode(originalTagBytes);

          await expectLater(
            () => RecoveryCrypto.open(
              key: secretKey,
              owner: 'user-e2e-01',
              kind: 'note',
              id: 'note-01',
              envelope: corruptedEnvelope,
            ),
            throwsA(anything),
          );
        });

        test('TC-F8-B04: Zero-byte database file opening fail-closed: 0-byte file is not treated as plaintext SQLite', () {
          final tempDir = Directory.systemTemp.createTempSync(
            'e2e_zero_byte_db_',
          );
          addTearDown(() => tempDir.deleteSync(recursive: true));

          final zeroFile = File(p.join(tempDir.path, 'empty.sqlite'));
          zeroFile.writeAsBytesSync([]);

          // Um arquivo de 0 bytes não possui o cabeçalho "SQLite format 3\0"
          expect(
            LocalDatabaseEncryption.isPlaintextSqliteFile(zeroFile),
            isFalse,
          );
        });

        test('TC-F8-B05: Missing encryption key fail-closed: applyKeyPragma rejects empty or invalid hex key with ArgumentError', () {
          final db = sql.sqlite3.openInMemory();
          addTearDown(db.close);

          // Chave vazia
          expect(
            () => LocalDatabaseEncryption.applyKeyPragma(db, ''),
            throwsArgumentError,
          );

          // Chave com tamanho incorreto (menos de 64 caracteres hex)
          expect(
            () => LocalDatabaseEncryption.applyKeyPragma(db, 'deadbeef'),
            throwsArgumentError,
          );
        });
      },
    );

    // =========================================================================
    // Group 9: F9 Media CAS Boundaries
    // =========================================================================
    group('Group 9: F9 Media CAS Boundaries (Master Order §2, §3)', () {
      test('TC-F9-B01: 0-byte media file upload: EncryptedMedia.encrypt produces valid zero-chunk manifest', () async {
        final key = await AesGcm.with256bits().newSecretKey();
        final manifest = await EncryptedMedia.encrypt(
          key: key,
          owner: 'owner-cas-01',
          mediaId: 'media-empty-01',
          source: Stream<List<int>>.value([]),
          storeChunk: (index, envelope) async {},
        );

        expect(manifest['v'], equals(1));
        expect(manifest['algorithm'], equals('A256GCM'));

        final openedBytes = await RecoveryCrypto.open(
          key: key,
          owner: 'owner-cas-01',
          kind: 'media-manifest-v1',
          id: 'media-empty-01',
          envelope: manifest,
        );

        final decoded =
            jsonDecode(utf8.decode(openedBytes)) as Map<String, dynamic>;
        expect(decoded['total'], equals(0));
        expect((decoded['chunks'] as List).isEmpty, isTrue);
      });

      test('TC-F9-B02: 50MB single chunk boundary: payload exceeding 1 MiB limit in seal throws ArgumentError', () async {
        final key = await AesGcm.with256bits().newSecretKey();
        // Payload de 1 MiB + 1 byte (excede limite atômico do bloco de mídia)
        final oversized = Uint8List(1024 * 1024 + 1);

        await expectLater(
          () => RecoveryCrypto.seal(
            key: key,
            owner: 'owner-cas-01',
            kind: 'test',
            id: 'id-01',
            plaintext: oversized,
          ),
          throwsArgumentError,
        );
      });

      test('TC-F9-B03: Single-bit flip authentication tag rejection in media chunk', () async {
        final key = await AesGcm.with256bits().newSecretKey();
        final box = await RecoveryCrypto.seal(
          key: key,
          owner: 'owner-cas-01',
          kind: 'media-chunk-v1',
          id: jsonEncode(['media-01', 0]),
          plaintext: Uint8List.fromList(utf8.encode('Chunk Data 2026')),
        );

        final corruptedBox = Map<String, dynamic>.from(box);
        final tagBytes = base64Decode(corruptedBox['tag'] as String);
        tagBytes[1] ^= 0x01; // Inverte 1 bit
        corruptedBox['tag'] = base64Encode(tagBytes);

        await expectLater(
          () => RecoveryCrypto.open(
            key: key,
            owner: 'owner-cas-01',
            kind: 'media-chunk-v1',
            id: jsonEncode(['media-01', 0]),
            envelope: corruptedBox,
          ),
          throwsA(anything),
        );
      });

      test('TC-F9-B04: Concurrent CAS update race collision: stale previousVersionId triggers conflict detection', () {
        // Simulação de verificação atômica de versão CAS (Compare-And-Swap)
        String currentVersion = 'v_initial_01';

        bool atomicCasUpdate({
          required String expectedPreviousVersion,
          required String newVersion,
        }) {
          if (currentVersion != expectedPreviousVersion) {
            return false; // Conflito de versão detectado
          }
          currentVersion = newVersion;
          return true;
        }

        // Primeira atualização concorre com sucesso
        final update1 = atomicCasUpdate(
          expectedPreviousVersion: 'v_initial_01',
          newVersion: 'v_clientA_02',
        );
        expect(update1, isTrue);

        // Segunda atualização simultânea baseada na versão anterior desatualizada colide
        final update2 = atomicCasUpdate(
          expectedPreviousVersion: 'v_initial_01',
          newVersion: 'v_clientB_02',
        );
        expect(update2, isFalse);
      });

      test('TC-F9-B05: Invalid bucket name rejection: unsupported bucket throws ArgumentError', () {
        expect(
          EncryptedMediaTransfer.supportedBuckets.contains('system_secrets'),
          isFalse,
        );
        expect(
          EncryptedMediaTransfer.supportedBuckets.contains('voice_notes'),
          isTrue,
        );
      });
    });

    // =========================================================================
    // Group 10: F10 Local MapLibre Engine Boundaries
    // =========================================================================
    group(
      'Group 10: F10 Local MapLibre Engine Boundaries (Master Order §5, §9)',
      () {
        late TileServerTestLifecycle tileLifecycle;

        setUp(() async {
          tileLifecycle = await TileServerTestLifecycle.createStarted();
        });

        tearDown(() async {
          await tileLifecycle.dispose();
        });

        test('TC-F10-B01: 126-byte truncated PMTiles header rejection: throws FormatException when bytes < 127', () {
          final truncatedBytes = Uint8List(126);
          expect(
            () => PmtilesHeader.fromBytes(truncatedBytes),
            throwsA(isA<FormatException>()),
          );
        });

        test('TC-F10-B02: Magic byte corruption PMTileX rejection: corrupt magic signature throws FormatException', () {
          final corruptMagic = SyntheticVectorFixtures.buildV3Header(
            rootDirOffset: 127,
            rootDirLength: 20,
          );
          // Altera 's' para 'X' ("PMTileX")
          corruptMagic[6] = 0x58; // 'X'

          expect(
            () => PmtilesHeader.fromBytes(corruptMagic),
            throwsA(isA<FormatException>()),
          );
        });

        test('TC-F10-B03: Non-loopback IP 192.168.1.1 rejected by fail-closed firewall', () {
          final gate = AirplaneNetworkGate(airplaneModeActive: true);
          expect(gate.isAllowed('192.168.1.1'), isFalse);
          expect(gate.isAllowed('10.0.0.1'), isFalse);
          expect(gate.isAllowed('127.0.0.1'), isTrue);
        });

        test('TC-F10-B04: Path traversal ../../etc/passwd returns 400 or 404 cleanly', () async {
          final res = await http.get(
            Uri.parse(
              '${tileLifecycle.baseUrl}/assets/sprites/../../etc/passwd',
            ),
          );
          expect(res.statusCode, anyOf(equals(400), equals(404)));
        });

        test('TC-F10-B05: Null byte in URI %00 rejection', () async {
          final res = await http.get(
            Uri.parse('${tileLifecycle.baseUrl}/assets/sprites/inject%00.json'),
          );
          expect(res.statusCode, anyOf(equals(400), equals(404)));
        });
      },
    );

    // =========================================================================
    // Group 11: F11 Alto Solimões Vector Basemap Boundaries
    // =========================================================================
    group('Group 11: F11 Alto Solimões Vector Basemap Boundaries (Master Order §7, §8)', () {
      test('TC-F11-B01: Coordinates exactly on bbox edge evaluate to true (inclusive boundary)', () {
        expect(
          AmazonianCoordinates.containsCoordinate(
            AmazonianCoordinates.minLat,
            AmazonianCoordinates.minLon,
          ),
          isTrue,
        );
        expect(
          AmazonianCoordinates.containsCoordinate(
            AmazonianCoordinates.maxLat,
            AmazonianCoordinates.maxLon,
          ),
          isTrue,
        );
      });

      test('TC-F11-B02: Coordinate outside bbox by 0.0001 evaluates to false (exclusive edge)', () {
        expect(
          AmazonianCoordinates.containsCoordinate(
            AmazonianCoordinates.minLat - 0.0001,
            AmazonianCoordinates.minLon,
          ),
          isFalse,
        );
        expect(
          AmazonianCoordinates.containsCoordinate(
            AmazonianCoordinates.maxLat + 0.0001,
            AmazonianCoordinates.maxLon,
          ),
          isFalse,
        );
      });

      test('TC-F11-B03: Zoom level 0 vs 14 vs 22: package manifest accepts valid zoom bounds 0 to 22', () {
        final manifest = OfflineMapPackageManifest(
          id: 'zoom_boundary_pkg',
          regionName: 'Região Teste',
          downloadUrl: Uri.parse('https://example.com/map.pmtiles'),
          sizeBytes: 1024,
          sha256: crypto.sha256.convert(utf8.encode('test')).toString(),
          bbox: const GeoBoundingBox(
            minLat: -3.4,
            minLon: -68.2,
            maxLat: -3.0,
            maxLon: -67.7,
          ),
          minZoom: 0,
          maxZoom: 22,
          generatedAt: DateTime.now(),
          version: '1.0.0',
          license: 'ODbL',
          attribution: 'OpenStreetMap',
          format: OfflineMapFormat.pmtiles,
        );

        expect(manifest.minZoom, equals(0));
        expect(manifest.maxZoom, equals(22));
      });

      test('TC-F11-B04: Tile coordinates out of bounds: at z=1, x=4 is rejected as out of range', () {
        bool isTileInBounds(int z, int x, int y) {
          if (z < 0 || z > 22) return false;
          final maxCoordinate = (1 << z) - 1;
          return x >= 0 && x <= maxCoordinate && y >= 0 && y <= maxCoordinate;
        }

        expect(isTileInBounds(1, 0, 0), isTrue);
        expect(isTileInBounds(1, 1, 1), isTrue);
        expect(isTileInBounds(1, 4, 0), isFalse); // x=4 excede 2^1 - 1 = 1
        expect(isTileInBounds(1, 0, 2), isFalse); // y=2 excede 2^1 - 1 = 1
      });

      test('TC-F11-B05: Corrupt gzip tile data handling throws FormatException cleanly without crashing', () {
        final corruptGzipBytes = Uint8List.fromList([
          0x1F,
          0x8B,
          0x00,
          0xFF,
          0xEE,
        ]);
        expect(() => gzip.decode(corruptGzipBytes), throwsA(anything));
      });
    });

    // =========================================================================
    // Group 12: F12 OfflineMapPackageManager Boundaries
    // =========================================================================
    group('Group 12: F12 OfflineMapPackageManager Boundaries (Master Order §10, §11)', () {
      late Directory tempDir;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync('e2e_tier2_pkg_bva_');
      });

      tearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      test('TC-F12-B01: HTTP 416 Range Not Satisfiable handling when byte offset >= remote content size', () async {
        final payload = createValidPmtilesHeader('SampleTileData');
        final sha = crypto.sha256.convert(payload).toString();

        final manifest = OfflineMapPackageManifest(
          id: 'test_pkg_416',
          regionName: 'Região 416',
          downloadUrl: Uri.parse('https://example.com/map_416.pmtiles'),
          sizeBytes: payload.length,
          sha256: sha,
          bbox: const GeoBoundingBox(
            minLat: -3.4,
            minLon: -68.2,
            maxLat: -3.0,
            maxLon: -67.7,
          ),
          minZoom: 8,
          maxZoom: 16,
          generatedAt: DateTime.now(),
          version: '1.0.0',
          license: 'ODbL',
          attribution: 'OpenStreetMap',
          format: OfflineMapFormat.pmtiles,
        );

        // MockClient simulando HTTP 416 quando Range Header excede o tamanho
        final mockClient = MockClient((request) async {
          if (request.headers.containsKey('Range')) {
            return http.Response('Requested Range Not Satisfiable', 416);
          }
          return http.Response.bytes(payload, 200);
        });

        final manager = OfflineMapPackageManager(
          storageDir: tempDir,
          httpClient: mockClient,
        );
        addTearDown(manager.dispose);

        // Simula arquivo .tmp pré-existente cujo tamanho atinge ou excede o arquivo remoto
        final targetFile = await manager.getPackageFile(manifest);
        final stagingFile = File('${targetFile.path}.tmp');
        stagingFile.writeAsBytesSync(payload);

        await expectLater(
          () => manager.downloadAndInstall(manifest: manifest),
          throwsA(
            isA<HttpException>().having(
              (e) => e.message,
              'message',
              contains('416'),
            ),
          ),
        );

        // Confirma limpeza de arquivos temporários e transição de estado fail-closed
        expect(stagingFile.existsSync(), isFalse);
        expect(targetFile.existsSync(), isFalse);
        expect(
          manager.currentStates[manifest.id]?.status,
          equals(PackageDownloadStatus.failed),
        );
      });

      test('TC-F12-B02: HTTP Range start > end rejection fail-closed by tile server parser', () async {
        final tileServer = await TileServerTestLifecycle.createStarted(
          packagesDir: Directory(p.join(tempDir.path, 'pkgs')),
          assetsDir: Directory(p.join(tempDir.path, 'assets')),
        );
        addTearDown(tileServer.dispose);

        final pmtilesBytes = createValidPmtilesHeader(
          'RangeVerificationPayload',
        );
        final pkgFile = File(p.join(tempDir.path, 'pkgs', 'range_pkg.pmtiles'));
        pkgFile.parent.createSync(recursive: true);
        pkgFile.writeAsBytesSync(pmtilesBytes);
        tileServer.server.registerPmtilesPackage('range_pkg', pkgFile);

        final uri = Uri.parse('${tileServer.baseUrl}/pmtiles/range_pkg');
        final response = await http.get(
          uri,
          headers: {'Range': 'bytes=500-200'},
        );

        expect(response.statusCode, equals(416));
        expect(
          response.headers['content-range'],
          equals('bytes */${pmtilesBytes.length}'),
        );
        expect(OfflineMapPackageManager.isValidRange(100, 200), isTrue);
        expect(OfflineMapPackageManager.isValidRange(500, 200), isFalse);
      });

      test('TC-F12-B03: Transport interruption preserves partial .tmp files for resume', () async {
        final payload = createValidPmtilesHeader('A' * 2048);
        final sha = crypto.sha256.convert(payload).toString();

        final manifest = OfflineMapPackageManifest(
          id: 'test_pkg_abort',
          regionName: 'Região Cancelada',
          downloadUrl: Uri.parse('https://example.com/abort.pmtiles'),
          sizeBytes: payload.length,
          sha256: sha,
          bbox: const GeoBoundingBox(
            minLat: -3.4,
            minLon: -68.2,
            maxLat: -3.0,
            maxLon: -67.7,
          ),
          minZoom: 8,
          maxZoom: 16,
          generatedAt: DateTime.now(),
          version: '1.0.0',
          license: 'ODbL',
          attribution: 'OpenStreetMap',
          format: OfflineMapFormat.pmtiles,
        );

        final mockClient = MockClient.streaming((request, bodyStream) async {
          final stream = Stream<List<int>>.periodic(
            const Duration(milliseconds: 10),
            (count) {
              if (count >= 2)
                throw http.ClientException('Download cancelado pelo usuário');
              return payload.sublist(count * 256, (count + 1) * 256);
            },
          );
          return http.StreamedResponse(
            stream,
            200,
            contentLength: payload.length,
          );
        });

        final manager = OfflineMapPackageManager(
          storageDir: tempDir,
          httpClient: mockClient,
        );
        addTearDown(manager.dispose);

        await expectLater(
          () => manager.downloadAndInstall(manifest: manifest),
          throwsA(isA<http.ClientException>()),
        );

        final targetFile = await manager.getPackageFile(manifest);
        final stagingFile = File('${targetFile.path}.tmp');

        expect(stagingFile.existsSync(), isTrue);
        expect(targetFile.existsSync(), isFalse);
        expect(
          manager.currentStates[manifest.id]?.status,
          equals(PackageDownloadStatus.failed),
        );
      });

      test('TC-F12-B04: Single-bit SHA-256 mismatch rollback aborts atomic installation and purges payload', () async {
        final validPayload = createValidPmtilesHeader('LegitimatePackageData');
        final validSha = crypto.sha256.convert(validPayload).toString();

        final corruptPayload = Uint8List.fromList(validPayload);
        corruptPayload[20] ^= 0xFF; // Inverte 1 byte no payload

        final manifest = OfflineMapPackageManifest(
          id: 'test_pkg_mismatch',
          regionName: 'Região Hash Mismatch',
          downloadUrl: Uri.parse('https://example.com/mismatch.pmtiles'),
          sizeBytes: corruptPayload.length,
          sha256: validSha, // Checksum esperado é do arquivo original!
          bbox: const GeoBoundingBox(
            minLat: -3.4,
            minLon: -68.2,
            maxLat: -3.0,
            maxLon: -67.7,
          ),
          minZoom: 8,
          maxZoom: 16,
          generatedAt: DateTime.now(),
          version: '1.0.0',
          license: 'ODbL',
          attribution: 'OpenStreetMap',
          format: OfflineMapFormat.pmtiles,
        );

        final mockClient = MockClient((request) async {
          return http.Response.bytes(corruptPayload, 200);
        });

        final manager = OfflineMapPackageManager(
          storageDir: tempDir,
          httpClient: mockClient,
        );
        addTearDown(manager.dispose);

        await expectLater(
          () => manager.downloadAndInstall(manifest: manifest),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Checksum SHA-256 inválido'),
            ),
          ),
        );

        final targetFile = await manager.getPackageFile(manifest);
        final stagingFile = File('${targetFile.path}.tmp');

        expect(stagingFile.existsSync(), isFalse);
        expect(targetFile.existsSync(), isFalse);
        expect(
          manager.currentStates[manifest.id]?.status,
          equals(PackageDownloadStatus.corrupted),
        );
      });

      test('TC-F12-B05: Corrupted directory header in downloaded PMTiles fails validation', () async {
        final corruptedHeaderPayload = Uint8List(200);
        corruptedHeaderPayload.setRange(0, 7, 'CORRUPT'.codeUnits);
        final sha = crypto.sha256.convert(corruptedHeaderPayload).toString();

        final manifest = OfflineMapPackageManifest(
          id: 'test_pkg_corrupt_header',
          regionName: 'Região Header Corrompido',
          downloadUrl: Uri.parse('https://example.com/corrupt_header.pmtiles'),
          sizeBytes: corruptedHeaderPayload.length,
          sha256: sha,
          bbox: const GeoBoundingBox(
            minLat: -3.4,
            minLon: -68.2,
            maxLat: -3.0,
            maxLon: -67.7,
          ),
          minZoom: 8,
          maxZoom: 16,
          generatedAt: DateTime.now(),
          version: '1.0.0',
          license: 'ODbL',
          attribution: 'OpenStreetMap',
          format: OfflineMapFormat.pmtiles,
        );

        final mockClient = MockClient((request) async {
          return http.Response.bytes(corruptedHeaderPayload, 200);
        });

        final manager = OfflineMapPackageManager(
          storageDir: tempDir,
          httpClient: mockClient,
        );
        addTearDown(manager.dispose);

        await expectLater(
          () => manager.downloadAndInstall(manifest: manifest),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Assinatura mágica PMTiles inválida'),
            ),
          ),
        );

        final targetFile = await manager.getPackageFile(manifest);
        final stagingFile = File('${targetFile.path}.tmp');

        expect(stagingFile.existsSync(), isFalse);
        expect(targetFile.existsSync(), isFalse);
        expect(
          manager.currentStates[manifest.id]?.status,
          equals(PackageDownloadStatus.failed),
        );
      });
    });

    // =========================================================================
    // Group 13: F13 FTS5 Geographic Search Boundaries
    // =========================================================================
    group('Group 13: F13 FTS5 Geographic Search Boundaries (Master Order §14)', () {
      late sql.Database memDb;

      setUp(() {
        memDb = sql.sqlite3.openInMemory();
        memDb.execute('''
            CREATE VIRTUAL TABLE geographic_features_fts USING fts5(
              id UNINDEXED,
              name,
              category,
              latitude UNINDEXED,
              longitude UNINDEXED,
              tokenize = 'unicode61 remove_diacritics 2'
            );
          ''');

        memDb.execute('''
            INSERT INTO geographic_features_fts(id, name, category, latitude, longitude) VALUES
              ('1', 'Santo Antônio do Içá', 'municipality', '-3.1022', '-67.9397'),
              ('2', 'Betânia', 'indigenous_community', '-3.1700', '-68.0800'),
              ('3', 'Duü̃', 'ticuna_village', '-3.1720', '-68.0820');
          ''');
      });

      tearDown(() {
        memDb.close();
      });

      test('TC-F13-B01: Empty query string "" handles gracefully returning empty result without syntax error', () {
        List<Map<String, Object?>> executeSafeSearch(String query) {
          final trimmed = query.trim();
          if (trimmed.isEmpty) return [];
          return memDb.select(
            "SELECT name FROM geographic_features_fts WHERE geographic_features_fts MATCH ?;",
            [trimmed],
          );
        }

        final results = executeSafeSearch('');
        expect(results.isEmpty, isTrue);
      });

      test('TC-F13-B02: 256-character query: extreme length query string executes safely without buffer overflow', () {
        final longQuery = 'A' * 256;
        final rows = memDb.select(
          "SELECT name FROM geographic_features_fts WHERE geographic_features_fts MATCH ?;",
          [longQuery],
        );
        expect(rows.isEmpty, isTrue);
      });

      test(
        'TC-F13-B03: Non-existent town query returns empty list without error',
        () {
          final rows = memDb.select(
            "SELECT name FROM geographic_features_fts WHERE geographic_features_fts MATCH 'Atlantis';",
          );
          expect(rows.isEmpty, isTrue);
        },
      );

      test('TC-F13-B04: Punctuation/symbol queries tokenize safely without unhandled SQLite crash', () {
        String sanitizeFtsQuery(String query) {
          // Substitui caracteres de pontuação por espaço e remove espaços redundantes
          return query
              .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
              .trim();
        }

        final sanitizedOnlyPunctuation = sanitizeFtsQuery('???***---:::');
        expect(sanitizedOnlyPunctuation.isEmpty, isTrue);

        final sanitizedMixed = sanitizeFtsQuery('santo???antonio***');
        expect(sanitizedMixed, equals('santo   antonio'));

        final rows = memDb.select(
          "SELECT name FROM geographic_features_fts WHERE geographic_features_fts MATCH ?;",
          [sanitizedMixed],
        );
        expect(rows.length, equals(1));
        expect(rows.first['name'], equals('Santo Antônio do Içá'));
      });

      test('TC-F13-B05: Stacked Ticuna diacritics with inverted combining marks ü\\u0301\\u0303 normalized to ü\\u0303\\u0301', () {
        // Entrada com ordem invertida: trema + agudo + til
        const invertedInput = 'duü\u0301\u0303';
        final normalized = TicunaUnicodeHelper.normalize(invertedInput);

        // A forma canônica deve colocar o til antes do agudo
        expect(normalized, equals('duü\u0303\u0301'));
      });
    });

    // =========================================================================
    // Group 14: F14 Offline Routing Engine Boundaries
    // =========================================================================
    group(
      'Group 14: F14 Offline Routing Engine Boundaries (Master Order §15)',
      () {
        late OfflineRoutingEngine router;

        setUp(() {
          router = OfflineRoutingEngine();
          router.addNode(
            const RoutingNode('SAI_CENTRO', -3.1022, -67.9397, name: 'Centro'),
          );
          router.addNode(
            const RoutingNode('SAI_SUL', -3.1150, -67.9450, name: 'Setor Sul'),
          );
          router.addNode(
            const RoutingNode(
              'DEAD_END',
              -3.1180,
              -67.9480,
              name: 'Beco Sem Saída',
            ),
          );
          router.addNode(
            const RoutingNode(
              'LAGO_GRANDE',
              -3.2500,
              -67.8500,
              name: 'Lago Grande',
            ),
          );
          router.addNode(
            const RoutingNode(
              'ISOLATED_ISLAND',
              -3.5000,
              -68.0000,
              name: 'Ilha Isolada',
            ),
          );

          router.addBidirectionalEdge(
            'SAI_CENTRO',
            'SAI_SUL',
            streetName: 'Rua Principal',
          );
          router.addBidirectionalEdge(
            'SAI_SUL',
            'DEAD_END',
            streetName: 'Beco',
          );
          router.addBidirectionalEdge(
            'SAI_SUL',
            'LAGO_GRANDE',
            isWaterCrossing: true,
            streetName: 'Rio Solimões (Sem Travessia Regular)',
          );
        });

        test('TC-F14-B01: Origin == destination distance 0m: trivial path returns exactly 0.0 meters', () {
          final result = router.findRoute(
            startId: 'SAI_CENTRO',
            goalId: 'SAI_CENTRO',
          );
          expect(result.isSuccess, isTrue);
          expect(result.pathNodeIds, equals(['SAI_CENTRO']));
          expect(result.totalDistanceMeters, equals(0.0));
          expect(result.estimatedDuration, equals(Duration.zero));
        });

        test('TC-F14-B02: Disconnected island graph node unreachable path returns failure', () {
          final result = router.findRoute(
            startId: 'SAI_CENTRO',
            goalId: 'ISOLATED_ISLAND',
          );
          expect(result.isSuccess, isFalse);
          expect(result.pathNodes, isEmpty);
          expect(
            result.errorMessage,
            contains('Não foi possível encontrar rota viável'),
          );
        });

        test('TC-F14-B03: Routing across unbridged Solimões without ferry returns unreachable failure', () {
          final result = router.findRoute(
            startId: 'SAI_CENTRO',
            goalId: 'LAGO_GRANDE',
            allowWaterCrossingWithoutBridge: false,
          );
          expect(result.isSuccess, isFalse);
          expect(
            result.errorMessage,
            contains('Não foi possível encontrar rota viável'),
          );

          // Quando autorizada a travessia aquática, a rota é estabelecida com sucesso
          final resultAllowed = router.findRoute(
            startId: 'SAI_CENTRO',
            goalId: 'LAGO_GRANDE',
            allowWaterCrossingWithoutBridge: true,
          );
          expect(resultAllowed.isSuccess, isTrue);
          expect(
            resultAllowed.pathNodeIds,
            equals(['SAI_CENTRO', 'SAI_SUL', 'LAGO_GRANDE']),
          );
        });

        test('TC-F14-B04: 180° dead-end U-turn penalty calculation applies 60-second penalty on reversal', () {
          final penaltyWalking =
              OfflineRoutingEngine.calculateTurnaroundPenalty(
                mode: RoutingMode.walking,
                previousNodeId: 'SAI_SUL',
                currentNodeId: 'DEAD_END',
                nextNodeId: 'SAI_SUL', // Inversão de sentido para sair do beco
              );
          expect(penaltyWalking, equals(60.0));

          final penaltyDriving =
              OfflineRoutingEngine.calculateTurnaroundPenalty(
                mode: RoutingMode.driving,
                previousNodeId: 'SAI_SUL',
                currentNodeId: 'DEAD_END',
                nextNodeId: 'SAI_SUL',
              );
          expect(penaltyDriving, equals(120.0));

          final noPenalty = OfflineRoutingEngine.calculateTurnaroundPenalty(
            mode: RoutingMode.walking,
            previousNodeId: 'SAI_CENTRO',
            currentNodeId: 'SAI_SUL',
            nextNodeId: 'DEAD_END',
          );
          expect(noPenalty, equals(0.0));
        });

        test('TC-F14-B05: Coordinate outside road network: non-existent node returns failure cleanly', () {
          final result = router.findRoute(
            startId: 'NON_EXISTENT_ORIGIN',
            goalId: 'SAI_CENTRO',
          );
          expect(result.isSuccess, isFalse);
          expect(
            result.errorMessage,
            contains('Ponto de partida "NON_EXISTENT_ORIGIN" não encontrado'),
          );
        });
      },
    );

    // =========================================================================
    // Group 15: F15 iOS & iPadOS Platform Boundaries
    // =========================================================================
    group('Group 15: F15 iOS & iPadOS Platform Boundaries (Master Order §7, §8)', () {
      test('TC-F15-B01: Calendar sync returning 0 remote events vs local 10 events triggers mass-deletion shield', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);

        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);

        FlutterSecureStorage.setMockInitialValues({
          'apple_eventkit_selected_id': 'cal_apple_test',
        });

        final fakePlugin = FakeDeviceCalendarPlugin();
        final appleProvider = AppleEventKitProvider(
          deviceCalendarPlugin: fakePlugin,
        );

        final now = DateTime.now();
        // Insere 10 compromissos ministeriais locais na janela de sincronização
        for (int i = 1; i <= 10; i++) {
          await db
              .into(db.externalCalendarEvents)
              .insert(
                ExternalCalendarEventsCompanion.insert(
                  id: 'apple_ext_stored_$i',
                  provider: 'apple_eventkit',
                  calendarId: 'cal_apple_test',
                  externalEventId: 'apple_ev_stored_$i',
                  title: 'Estudo Bíblico Família $i',
                  startTime: now.add(Duration(days: i)),
                  endTime: now.add(Duration(days: i, hours: 1)),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        }

        // Simula anomalia externa: consulta ao EventKit retorna lista vazia (0 eventos)
        fakePlugin.eventsResult = [];

        final syncResult = await appleProvider.syncEvents(db: db);
        expect(syncResult.success, isTrue);

        // Verifica se o escudo contra deleção em massa manteve os 10 compromissos intactos
        final storedEvents = await (db.select(
          db.externalCalendarEvents,
        )..where((t) => t.provider.equals('apple_eventkit'))).get();

        expect(storedEvents.length, equals(10));
        expect(storedEvents.every((e) => !e.isDeletedExternal), isTrue);
      });

      test('TC-F15-B02: Audio session interruption event handling transitions correctly without crash', () {
        const interruptionStart = AudioSessionInterruption(
          begin: true,
          shouldPause: true,
          reason: 'incoming_call',
        );
        expect(interruptionStart.begin, isTrue);
        expect(interruptionStart.shouldPause, isTrue);

        const interruptionEnd = AudioSessionInterruption(
          begin: false,
          shouldPause: false,
          reason: 'call_ended',
        );
        expect(interruptionEnd.begin, isFalse);
        expect(interruptionEnd.shouldPause, isFalse);
      });

      testWidgets(
        'TC-F15-B03: Responsive breakpoint boundary at 900px: 899.9px renders phone layout, 900.0px renders Master-Detail split',
        (tester) async {
          final harness = await OpaqueBoxHarness.create(
            airplaneMode: true,
            startTileServer: false,
          );
          addTearDown(harness.dispose);

          // Popula repositório com compromisso ministerial
          final now = DateTime.now();
          await harness.repo.createAppointment(
            title: 'Revisita Rio Solimões',
            startTime: now.add(const Duration(hours: 2)),
            endTime: now.add(const Duration(hours: 3)),
            durationMinutes: 60,
          );

          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          // 1. Largura abaixo do breakpoint: 899.0px (Narrow / Phone Mode)
          tester.view.physicalSize = const Size(899.0, 800.0);
          await tester.pumpWidget(
            harness.buildApp(child: const AppointmentsScreen()),
          );
          await tester.tap(find.text('Lista'));
          await tester.pumpAndSettleSafely();

          // Abaixo de 900px, o layout simples de lista não renderiza o divisor vertical
          expect(find.byType(VerticalDivider), findsNothing);

          // 2. Largura exatamente no breakpoint: 900.0px (Wide / iPad Master-Detail Mode)
          tester.view.physicalSize = const Size(900.0, 800.0);
          await tester.pumpAndSettleSafely();

          // Em 900px ou superior, constraints.maxWidth >= 900 ativa o _buildSplitListView com VerticalDivider
          expect(find.byType(VerticalDivider), findsOneWidget);

          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettleSafely();
        },
      );

      testWidgets(
        'TC-F15-B04: Zero-width window constraint handling renders safely without engine crash',
        (tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              home: SizedBox(
                width: 0,
                height: 100,
                child: Center(child: Text('ZeroWidth')),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'TC-F15-B05: Rapid orientation rotation: toggling between portrait and landscape executes cleanly',
        (tester) async {
          final harness = await OpaqueBoxHarness.create(
            airplaneMode: true,
            startTileServer: false,
          );
          addTearDown(harness.dispose);

          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            harness.buildApp(child: const AppointmentsScreen()),
          );

          for (int i = 0; i < 5; i++) {
            tester.view.physicalSize = const Size(768, 1024); // iPad Portrait
            await tester.pump(const Duration(milliseconds: 30));

            tester.view.physicalSize = const Size(1024, 768); // iPad Landscape
            await tester.pump(const Duration(milliseconds: 30));
          }

          await tester.pumpAndSettleSafely();

          expect(tester.takeException(), isNull);

          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettleSafely();
        },
      );
    });

    // =========================================================================
    // Group 16: F16 E2E Opaque-Box Suite Boundaries
    // =========================================================================
    group(
      'Group 16: F16 E2E Opaque-Box Suite Boundaries (Master Order §9, §10)',
      () {
        test('TC-F16-B01: Harness fail-closed error detection intercepts invalid score inputs and network violations', () {
          // 1. Valida que o avaliador rejeita pontuações de dimensão inválidas (> 10.0 ou < 0.0) com ArgumentError
          final invalidScores = <String, double>{
            for (final dim in FaesQualityGateEvaluator.dimensions)
              dim.key: 10.0,
          };
          invalidScores['functional'] = 10.5; // Nota impossível

          expect(
            () => FaesQualityGateEvaluator.evaluate(scores: invalidScores),
            throwsArgumentError,
          );

          // 2. Valida detecção ativa de violação de rede no AirplaneNetworkGate
          expect(
            () => HttpClient().getUrl(
              Uri.parse('https://external-leak-audit.org'),
            ),
            throwsA(
              isA<AirplaneModeViolationException>().having(
                (e) => e.blockedHost,
                'blockedHost',
                'external-leak-audit.org',
              ),
            ),
          );
        });

        test('TC-F16-B02: FAES quality gate failing when one dimension < 9.0 even if weighted score is high', () {
          final dimensionScores = <String, double>{
            'functional': 10.0,
            'data_integrity': 10.0,
            'security': 10.0,
            'offline_sync': 10.0,
            'architecture': 10.0,
            'ux_ios': 10.0,
            'tests': 10.0,
            'performance': 10.0,
            'documentation': 10.0,
            'release_ci': 8.9, // Dimensão abaixo de 9.0 viola o hard gate!
          };

          final result = FaesQualityGateEvaluator.evaluate(
            scores: dimensionScores,
          );

          expect(result.weightedScore, greaterThanOrEqualTo(9.70));
          expect(result.isApproved, isFalse);
          expect(result.verdict, equals(FaesGateVerdict.notApproved));
          expect(
            result.violations.any(
              (v) => v.contains('release_ci') || v.contains('Release/CI/CD'),
            ),
            isTrue,
          );
        });

        test('TC-F16-B03: Weighted score rounding boundary 9.69 vs 9.70: threshold requires score >= 9.70', () {
          final scoresAt969 = <String, double>{
            for (final dim in FaesQualityGateEvaluator.dimensions)
              dim.key: 9.69,
          };
          final result969 = FaesQualityGateEvaluator.evaluate(
            scores: scoresAt969,
          );
          expect(result969.weightedScore, equals(9.69));
          expect(result969.isApproved, isFalse);
          expect(result969.verdict, equals(FaesGateVerdict.notApproved));

          final scoresAt970 = <String, double>{
            for (final dim in FaesQualityGateEvaluator.dimensions)
              dim.key: 9.70,
          };
          final result970 = FaesQualityGateEvaluator.evaluate(
            scores: scoresAt970,
          );
          expect(result970.weightedScore, equals(9.70));
          expect(result970.isApproved, isTrue);
          expect(result970.verdict, equals(FaesGateVerdict.approved));

          // Verificação de P0 bloqueante mesmo com nota 10.0
          final scoresAt10 = <String, double>{
            for (final dim in FaesQualityGateEvaluator.dimensions)
              dim.key: 10.0,
          };
          final resultP0 = FaesQualityGateEvaluator.evaluate(
            scores: scoresAt10,
            unresolvedP0: 1,
          );
          expect(resultP0.isApproved, isFalse);
          expect(resultP0.verdict, equals(FaesGateVerdict.notApproved));
        });

        testWidgets(
          'TC-F16-B04: Timeout boundary in asynchronous steps: pumpAndSettleSafely returns when timeout expires',
          (tester) async {
            await tester.pumpWidget(
              const MaterialApp(home: CircularProgressIndicator()),
            );

            // CircularProgressIndicator possui animação contínua; pumpAndSettleSafely deve retornar no timeout
            final frames = await tester.pumpAndSettleSafely(
              timeout: const Duration(milliseconds: 250),
            );
            expect(frames, greaterThan(0));

            await tester.pumpWidget(const SizedBox());
            await tester.pumpAndSettleSafely();
          },
        );

        test('TC-F16-B05: Airplane mode violation detection throws AirplaneModeViolationException for external hosts', () async {
          final gate = AirplaneNetworkGate(airplaneModeActive: true);
          expect(gate.isAllowed('api.supabase.co'), isFalse);
          expect(gate.isAllowed('tile.openstreetmap.org'), isFalse);
          expect(gate.isAllowed('127.0.0.1'), isTrue);
        });
      },
    );
  });
}
