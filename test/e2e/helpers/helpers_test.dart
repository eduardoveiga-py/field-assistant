import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';

import 'e2e_assertions.dart';
import 'e2e_test_context.dart';
import 'mock_fixtures.dart';

void main() {
  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('E2ETestContext Lifecycle & Isolation', () {
    test('initializes cleanly in-memory with foreign keys enforced', () async {
      final ctx = await E2ETestContext.create();

      // 1. Verify that database is initialized with tables and languages seeded
      final languages = await ctx.db.select(ctx.db.appLanguages).get();
      expect(languages.length, greaterThanOrEqualTo(5));

      // 2. Foreign keys are enforced: inserting an orphan visit must fail
      expect(
        () async => ctx.db.into(ctx.db.visits).insert(
          VisitsCompanion.insert(
            id: 'orphan_visit_1',
            personId: 'non_existent_person_id',
            dateTimeField: DateTime.now(),
            contactType: 'revisita',
            result: 'conversa_produtiva',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ),
        throwsA(isA<Exception>()),
      );

      // 3. Normal parent-child insertion succeeds
      final personId = 'valid_person_1';
      await ctx.db.into(ctx.db.people).insert(
        PeopleCompanion.insert(
          id: personId,
          name: 'Irmão Local Santo Antônio',
          firstContactAt: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await ctx.db.into(ctx.db.visits).insert(
        VisitsCompanion.insert(
          id: 'valid_visit_1',
          personId: personId,
          dateTimeField: DateTime.now(),
          contactType: 'revisita',
          result: 'estudo_iniciado',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final insertedVisits = await ctx.db.select(ctx.db.visits).get();
      expect(insertedVisits.length, equals(1));
      expect(insertedVisits.first.personId, equals(personId));

      // 4. Temporary directory and file creation works
      final tempFile = await ctx.createTempFile('audio/test.wav', [1, 2, 3]);
      expect(await tempFile.exists(), isTrue);

      final tempPath = ctx.tempDir.path;
      await ctx.dispose();

      // 5. After dispose, temp directory is purged
      expect(await Directory(tempPath).exists(), isFalse);
    });

    test('SupabaseSyncService is configured with MockClient', () async {
      final ctx = await E2ETestContext.create();
      expect(ctx.syncService.isConfigured, isTrue);

      // Running processQueue with empty queue should report cleanly without exceptions
      final result = await ctx.syncService.processQueue();
      expect(result.totalProcessed, equals(0));
      expect(result.success, isTrue);

      await ctx.dispose();
    });
  });

  group('MockFixtures Data Verification', () {
    test('provides exact coordinates for Santo Antônio do Içá and São Paulo', () {
      final am = MockFixtures.santoAntonioCoordinates();
      expect(am['latitude'], equals(-3.1022));
      expect(am['longitude'], equals(-67.9397));

      final sp = MockFixtures.saoPauloCoordinates();
      expect(sp['latitude'], equals(-23.550520));
      expect(sp['longitude'], equals(-46.633308));
    });

    test('provides valid PNG and watermark signatures', () {
      final onePx = MockFixtures.onePixelPngBytes;
      expect(onePx.length, equals(67));
      expect(onePx.sublist(0, 8), equals([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));

      final generatedPng = MockFixtures.validPngTile(size: 256);
      expect(generatedPng.length, equals(256));
      expect(generatedPng.sublist(0, 8), equals([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));

      expect(MockFixtures.cartoLightWatermark().length, equals(2049));
      expect(MockFixtures.cartoDarkWatermark().length, equals(2513));
      expect(MockFixtures.osmBlockedTile().length, equals(6725));
      expect(MockFixtures.osmHtmlBlock().length, greaterThan(20));
      expect(MockFixtures.emptyTile().length, equals(0));

      final mbtilesHeader = MockFixtures.minimalMbtilesDatabaseBytes();
      expect(mbtilesHeader.length, equals(512));
      expect(String.fromCharCodes(mbtilesHeader.sublist(0, 15)), equals('SQLite format 3'));
    });

    test('provides valid encoded WAV bytes vs dummy zero bytes', () {
      final wav = MockFixtures.validWavAudioBytes(durationSeconds: 1);
      expect(wav.length, greaterThan(500));
      // "RIFF" header
      expect(String.fromCharCodes(wav.sublist(0, 4)), equals('RIFF'));
      // "WAVE" header
      expect(String.fromCharCodes(wav.sublist(8, 12)), equals('WAVE'));
      // Contains non-zero samples
      expect(wav.any((b) => b != 0), isTrue);

      expect(MockFixtures.dummyZeroLengthAudio().length, equals(0));
      expect(MockFixtures.dummy64ZeroAudio().length, equals(64));
      expect(MockFixtures.dummy64ZeroAudio().every((b) => b == 0), isTrue);
    });

    test('provides authentic IMAP/SMTP raw protocol strings', () {
      expect(MockFixtures.imapGreeting, contains('IMAP4rev1'));
      expect(MockFixtures.imapAuthOk, contains('A002 OK'));
      expect(MockFixtures.imapAuthFailed, contains('AUTHENTICATIONFAILED'));
      expect(MockFixtures.smtpGreeting, contains('220'));
      expect(MockFixtures.smtpAuthOk, contains('235'));
      expect(MockFixtures.smtpAuthFailed, contains('535'));

      final emailFetch = MockFixtures.imapFetchSingleEmail(
        uid: 101,
        subject: 'Relatório Mensal de Campo',
        from: 'publicador@dominio-real.org',
        body: 'Prezados irmãos, segue relatório de campo.',
      );
      expect(emailFetch, contains('Relatório Mensal de Campo'));
      expect(emailFetch, contains('publicador@dominio-real.org'));
      // Must contain no theocratic fake seeds
      expect(emailFetch, containsNoTheocraticSeeds());
    });

    test('provides complete payloads for the 7 strategic tables and RPC', () {
      const strategicTables = [
        'people',
        'visits',
        'bible_studies',
        'study_participants',
        'study_sessions',
        'appointments',
        'activity_records',
      ];

      for (final table in strategicTables) {
        final payload = MockFixtures.samplePayloadForTable(table);
        expect(payload['id'], isNotNull);
        expect(payload['created_at'], isNotNull);
        expect(payload, isFullyHydratedSyncPayload(table));
      }

      final rpcSuccess = MockFixtures.rpcSyncUpsertSuccess(count: 3);
      expect(rpcSuccess['success'], isTrue);
      expect(rpcSuccess['processed_count'], equals(3));

      final rpcConflict = MockFixtures.rpcSyncUpsertConflict(
        entity: 'people',
        id: 'person_e2e_1',
      );
      expect(rpcConflict['code'], equals('23505'));
      expect(rpcConflict['message'], contains('Optimistic lock conflict'));
    });
  });

  group('E2EAssertions Custom Matchers', () {
    test('isValidAudioBytes matcher validates genuine audio and rejects dummy files', () async {
      final validWav = MockFixtures.validWavAudioBytes();
      expect(validWav, isValidAudioBytes());

      // Test with File
      final tempFile = File('${Directory.systemTemp.path}/test_valid_audio_${DateTime.now().millisecondsSinceEpoch}.wav');
      await tempFile.writeAsBytes(validWav);
      expect(tempFile, isValidAudioBytes());
      await tempFile.delete();

      // Must reject 0 bytes
      expect(MockFixtures.dummyZeroLengthAudio(), isNot(isValidAudioBytes()));
      expect(Uint8List(0), isNot(isValidAudioBytes()));

      // Must reject 64 bytes of zeros
      expect(MockFixtures.dummy64ZeroAudio(), isNot(isValidAudioBytes()));

      // Must reject arbitrary-sized array filled only with zeros
      expect(MockFixtures.dummyZerosAudio(size: 200), isNot(isValidAudioBytes()));

      // Must reject non-existent file
      final nonExistentFile = File('non_existent_file_path_xyz.wav');
      expect(nonExistentFile, isNot(isValidAudioBytes()));
    });

    test('isSantoAntonioDoIcaCoordinate matcher accepts AM coords and rejects SP coords', () {
      expect(MockFixtures.santoAntonioCoordinates(), isSantoAntonioDoIcaCoordinate());
      expect({'latitude': -3.1022, 'longitude': -67.9397}, isSantoAntonioDoIcaCoordinate());
      expect((latitude: -3.1022, longitude: -67.9397), isSantoAntonioDoIcaCoordinate());
      expect((lat: -3.1022, lng: -67.9397), isSantoAntonioDoIcaCoordinate());

      // Small variation within tolerance (0.005)
      expect({'latitude': -3.1030, 'longitude': -67.9400}, isSantoAntonioDoIcaCoordinate());

      // Rejects São Paulo coordinates
      expect(MockFixtures.saoPauloCoordinates(), isNot(isSantoAntonioDoIcaCoordinate()));
      expect({'latitude': -23.550520, 'longitude': -46.633308}, isNot(isSantoAntonioDoIcaCoordinate()));
    });

    test('isNotSaoPauloCoordinate matcher rejects SP coords and accepts others', () {
      expect(MockFixtures.santoAntonioCoordinates(), isNotSaoPauloCoordinate());
      expect({'latitude': -3.1022, 'longitude': -67.9397}, isNotSaoPauloCoordinate());

      // Rejects São Paulo
      expect(MockFixtures.saoPauloCoordinates(), isNot(isNotSaoPauloCoordinate()));
      expect({'latitude': -23.550520, 'longitude': -46.633308}, isNot(isNotSaoPauloCoordinate()));
    });

    test('containsNoTheocraticSeeds matcher detects fake seeds and accepts authentic content', () {
      expect('Mensagem normal de um publicador real', containsNoTheocraticSeeds());
      expect(MockFixtures.samplePersonPayload(), containsNoTheocraticSeeds());

      // Rejects known theocratic seeds
      expect('Padaria Central Betânia', isNot(containsNoTheocraticSeeds()));
      expect('Padaria Betânia', isNot(containsNoTheocraticSeeds()));
      expect('seed_hub_letter_01', isNot(containsNoTheocraticSeeds()));
      expect('seed_hub_form_02', isNot(containsNoTheocraticSeeds()));
      expect('filial.br@hub.jw.org', isNot(containsNoTheocraticSeeds()));
      expect('corpo.anciaos@jw.org', isNot(containsNoTheocraticSeeds()));
      expect('Arranjos_Comemoracao_2026.pdf', isNot(containsNoTheocraticSeeds()));

      // Rejects within nested maps/lists
      final payloadWithSeed = {
        'id': 'p1',
        'notes': 'Reunião perto da Padaria Betânia',
      };
      expect(payloadWithSeed, isNot(containsNoTheocraticSeeds()));
    });

    test('isFullyHydratedSyncPayload matcher verifies NOT NULL columns', () {
      // 1. All valid sample payloads pass
      expect(MockFixtures.samplePersonPayload(), isFullyHydratedSyncPayload('people'));
      expect(MockFixtures.sampleVisitPayload(), isFullyHydratedSyncPayload('visits'));
      expect(MockFixtures.sampleBibleStudyPayload(), isFullyHydratedSyncPayload('bible_studies'));
      expect(MockFixtures.sampleStudyParticipantPayload(), isFullyHydratedSyncPayload('study_participants'));
      expect(MockFixtures.sampleStudySessionPayload(), isFullyHydratedSyncPayload('study_sessions'));
      expect(MockFixtures.sampleAppointmentPayload(), isFullyHydratedSyncPayload('appointments'));
      expect(MockFixtures.sampleActivityRecordPayload(), isFullyHydratedSyncPayload('activity_records'));

      // 2. Missing required column fails
      final missingNamePerson = Map<String, dynamic>.from(MockFixtures.samplePersonPayload())..remove('name');
      expect(missingNamePerson, isNot(isFullyHydratedSyncPayload('people')));

      // 3. Null required column fails
      final nullPersonIdVisit = Map<String, dynamic>.from(MockFixtures.sampleVisitPayload())..['person_id'] = null;
      expect(nullPersonIdVisit, isNot(isFullyHydratedSyncPayload('visits')));

      // 4. Missing created_at fails
      final missingCreated = Map<String, dynamic>.from(MockFixtures.sampleAppointmentPayload())..remove('created_at');
      expect(missingCreated, isNot(isFullyHydratedSyncPayload('appointments')));
    });
  });
}
