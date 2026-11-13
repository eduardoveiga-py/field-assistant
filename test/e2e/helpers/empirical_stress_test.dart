import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

import 'e2e_assertions.dart';
import 'e2e_test_context.dart';
import 'mock_fixtures.dart';

void main() {
  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Challenge 1: Hermetic Concurrency & Resource Cleanup', () {
    test('10 concurrent E2ETestContext instances execute without collisions or lockups', () async {
      const int concurrencyCount = 10;

      // 1. Concurrently create 10 contexts
      final contexts = await Future.wait(
        List.generate(concurrencyCount, (index) => E2ETestContext.create()),
      );

      expect(contexts.length, equals(concurrencyCount));

      final createdTempPaths = <String>[];

      // 2. Perform concurrent isolated operations across all 10 contexts
      await Future.wait(
        contexts.asMap().entries.map((entry) async {
          final index = entry.key;
          final ctx = entry.value;

          createdTempPaths.add(ctx.tempDir.path);

          // Verify tempDir exists
          expect(await ctx.tempDir.exists(), isTrue);

          // Insert a person with unique index-specific ID
          final personId = 'person_concurrent_$index';
          await ctx.db.into(ctx.db.people).insert(
            PeopleCompanion.insert(
              id: personId,
              name: 'Concurrent Publisher $index',
              firstContactAt: DateTime.now(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

          // Verify table isolation: each database must contain ONLY its own record
          final peopleInDb = await ctx.db.select(ctx.db.people).get();
          expect(peopleInDb.length, equals(1),
              reason: 'Database in context $index was not isolated; found ${peopleInDb.length} records.');
          expect(peopleInDb.first.id, equals(personId));

          // Create an isolated temp file in its temp directory
          final tempFile = await ctx.createTempFile('data_$index.bin', [index, index + 1, index + 2]);
          expect(await tempFile.exists(), isTrue);
          expect(await tempFile.readAsBytes(), equals([index, index + 1, index + 2]));
        }),
      );

      // 3. Concurrently dispose all 10 contexts
      await Future.wait(contexts.map((ctx) => ctx.dispose()));

      // 4. Verify that ALL temporary directories were strictly cleaned up from disk
      for (int i = 0; i < createdTempPaths.length; i++) {
        final path = createdTempPaths[i];
        final exists = await Directory(path).exists();
        expect(
          exists,
          isFalse,
          reason: 'Temp directory at $path was not cleaned up after dispose() for context $i',
        );
      }
    });
  });

  group('Challenge 2: Strict Foreign Key Enforcement & SqliteException', () {
    test('orphan visit insertion strictly throws SqliteException with foreign key constraint failure', () async {
      final ctx = await E2ETestContext.create();

      Object? thrownError;
      try {
        await ctx.db.into(ctx.db.visits).insert(
          VisitsCompanion.insert(
            id: 'orphan_visit_strict_fk',
            personId: 'non_existent_person_xyz',
            dateTimeField: DateTime.now(),
            contactType: 'revisita',
            result: 'conversa_produtiva',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      } catch (e) {
        thrownError = e;
      }

      await ctx.dispose();

      expect(thrownError, isNotNull, reason: 'Expected foreign key constraint violation to throw.');

      // Check whether it is a SqliteException or wraps one
      final isDirectSqliteException = thrownError is SqliteException;
      final isWrappedSqliteException = thrownError.toString().contains('SqliteException') ||
          thrownError.toString().contains('FOREIGN KEY constraint failed');

      expect(
        isDirectSqliteException || isWrappedSqliteException,
        isTrue,
        reason: 'Error should be or contain SqliteException (FOREIGN KEY constraint failed). Thrown: $thrownError (${thrownError.runtimeType})',
      );

      if (thrownError is SqliteException) {
        // SQLite error code 787 is SQLITE_CONSTRAINT_FOREIGNKEY, primary code 19 is SQLITE_CONSTRAINT
        expect(thrownError.extendedResultCode == 787 || thrownError.resultCode == 19, isTrue);
      }
    });

    test('orphan study participant insertion strictly violates foreign key', () async {
      final ctx = await E2ETestContext.create();

      expect(
        () async => ctx.db.into(ctx.db.studyParticipants).insert(
          StudyParticipantsCompanion.insert(
            id: 'orphan_part_1',
            studyId: 'non_existent_study_id',
            personId: 'non_existent_person_id',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ),
        throwsA(anyOf(isA<SqliteException>(), predicate((e) => e.toString().contains('FOREIGN KEY')))),
      );

      await ctx.dispose();
    });
  });

  group('Challenge 3: Assertion Boundary Conditions', () {
    group('isSantoAntonioDoIcaCoordinate boundary tests', () {
      const targetLat = -3.1022;
      const targetLng = -67.9397;
      const tol = 0.005;

      test('exact center matches', () {
        expect({'latitude': targetLat, 'longitude': targetLng}, isSantoAntonioDoIcaCoordinate(tolerance: tol));
      });

      test('exact boundary (+tol) matches', () {
        // latDiff == 0.005, lngDiff == 0.0
        final atLatBoundary = {'latitude': targetLat + tol, 'longitude': targetLng};
        expect(atLatBoundary, isSantoAntonioDoIcaCoordinate(tolerance: tol));

        // latDiff == 0.0, lngDiff == 0.005
        final atLngBoundary = {'latitude': targetLat, 'longitude': targetLng + tol};
        expect(atLngBoundary, isSantoAntonioDoIcaCoordinate(tolerance: tol));

        // negative boundary
        final atNegBoundary = {'latitude': targetLat - tol, 'longitude': targetLng - tol};
        expect(atNegBoundary, isSantoAntonioDoIcaCoordinate(tolerance: tol));
      });

      test('just outside boundary (+tol + 0.0001) fails', () {
        final outsideLat = {'latitude': targetLat + tol + 0.0001, 'longitude': targetLng};
        expect(outsideLat, isNot(isSantoAntonioDoIcaCoordinate(tolerance: tol)));

        final outsideLng = {'latitude': targetLat, 'longitude': targetLng + tol + 0.0001};
        expect(outsideLng, isNot(isSantoAntonioDoIcaCoordinate(tolerance: tol)));

        final outsideBoth = {'latitude': targetLat - tol - 0.0001, 'longitude': targetLng - tol - 0.0001};
        expect(outsideBoth, isNot(isSantoAntonioDoIcaCoordinate(tolerance: tol)));
      });

      test('record patterns with lat/lng keys match', () {
        expect((latitude: targetLat, longitude: targetLng), isSantoAntonioDoIcaCoordinate());
        expect((lat: targetLat, lng: targetLng), isSantoAntonioDoIcaCoordinate());
        expect({'lat': targetLat, 'lng': targetLng}, isSantoAntonioDoIcaCoordinate());
      });

      test('non-coordinate item or null safely fails', () {
        expect(null, isNot(isSantoAntonioDoIcaCoordinate()));
        expect('not a coord', isNot(isSantoAntonioDoIcaCoordinate()));
        expect({'foo': 'bar'}, isNot(isSantoAntonioDoIcaCoordinate()));
      });
    });

    group('isValidAudioBytes boundary tests', () {
      test('valid WAV audio bytes pass', () {
        final wav = MockFixtures.validWavAudioBytes();
        expect(wav, isValidAudioBytes());
      });

      test('valid WAV written to file passes', () async {
        final tempFile = File('${Directory.systemTemp.path}/boundary_valid_audio.wav');
        await tempFile.writeAsBytes(MockFixtures.validWavAudioBytes());
        try {
          expect(tempFile, isValidAudioBytes());
        } finally {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }
      });

      test('0 bytes fails', () {
        expect(Uint8List(0), isNot(isValidAudioBytes()));
      });

      test('truncated WAV <= 64 bytes fails (boundary: exactly 64 bytes)', () {
        // 44 bytes (e.g. PCM header without audio data)
        final headerOnly = MockFixtures.validWavAudioBytes().sublist(0, 44);
        expect(headerOnly.length, equals(44));
        expect(headerOnly, isNot(isValidAudioBytes()));

        // Exactly 64 bytes of non-zero audio
        final exact64 = MockFixtures.validWavAudioBytes().sublist(0, 64);
        expect(exact64.length, equals(64));
        expect(exact64.any((b) => b != 0), isTrue);
        expect(exact64, isNot(isValidAudioBytes()),
            reason: '64 bytes must be rejected as boundary requires strictly > 64 bytes');
      });

      test('65 bytes with non-zero samples passes boundary', () {
        final exact65 = MockFixtures.validWavAudioBytes().sublist(0, 65);
        expect(exact65.length, equals(65));
        expect(exact65.any((b) => b != 0), isTrue);
        expect(exact65, isValidAudioBytes(), reason: '65 bytes with non-zero sample should pass');
      });

      test('65 bytes of all zeros fails boundary (non-zero requirement)', () {
        final zeros65 = Uint8List(65);
        expect(zeros65.length, equals(65));
        expect(zeros65, isNot(isValidAudioBytes()));
      });

      test('128-byte all-zero array fails', () {
        final zeros128 = MockFixtures.dummyZerosAudio(size: 128);
        expect(zeros128.length, equals(128));
        expect(zeros128.every((b) => b == 0), isTrue);
        expect(zeros128, isNot(isValidAudioBytes()),
            reason: '128-byte all-zero array must be rejected as fake/dummy audio');
      });

      test('non-existent file fails', () {
        final nonExistent = File('${Directory.systemTemp.path}/definitely_non_existent_audio_xyz.wav');
        expect(nonExistent, isNot(isValidAudioBytes()));
      });

      test('invalid type fails gracefully', () {
        expect('not bytes', isNot(isValidAudioBytes()));
        expect(12345, isNot(isValidAudioBytes()));
        expect(null, isNot(isValidAudioBytes()));
      });
    });

    group('containsNoTheocraticSeeds adversarial inputs', () {
      test('rejects all known fake theocratic seeds in string', () {
        for (final seed in [
          'Padaria Central Betânia',
          'Padaria Betânia',
          'Posto de Saúde Lago Grande',
          'Escola Municipal Cidade',
          'seed_hub_letter_01',
          'seed_hub_form_02',
          'seed_email_03',
          'seed_email_04',
          'Arranjos_Comemoracao_2026.pdf',
          'Formulario_S21_Instrucoes.pdf',
          'Programa_Assembleia_Circuito.pdf',
          'filial.br@hub.jw.org',
          'corpo.anciaos@jw.org',
          'secretaria@hub.jw.org',
        ]) {
          expect('Prefix text $seed suffix text', isNot(containsNoTheocraticSeeds()));
        }
      });

      test('handles deeply nested maps and lists containing seeds', () {
        final nestedData = {
          'level1': {
            'level2': [
              {'notes': 'Encontro marcado na Padaria Betânia pela manhã'}
            ]
          }
        };
        expect(nestedData, isNot(containsNoTheocraticSeeds()));
      });

      test('clean payload passes without issue', () {
        final cleanData = {
          'id': 'real_id_1',
          'title': 'Estudo Bíblico',
          'address': 'Comunidade Belém do Solimões',
          'notes': 'Publicador esteve presente no salão',
        };
        expect(cleanData, containsNoTheocraticSeeds());
      });
    });

    group('isFullyHydratedSyncPayload column coverage', () {
      test('validates all 7 strategic tables', () {
        const tables = [
          'people',
          'visits',
          'bible_studies',
          'study_participants',
          'study_sessions',
          'appointments',
          'activity_records',
        ];

        for (final table in tables) {
          final payload = MockFixtures.samplePayloadForTable(table);
          expect(payload, isFullyHydratedSyncPayload(table));
        }
      });

      test('rejects payload if any required column is null or missing', () {
        final person = MockFixtures.samplePersonPayload();
        person['status'] = null;
        expect(person, isNot(isFullyHydratedSyncPayload('people')));

        final visit = MockFixtures.sampleVisitPayload();
        visit.remove('result');
        expect(visit, isNot(isFullyHydratedSyncPayload('visits')));

        final study = MockFixtures.sampleBibleStudyPayload();
        study['started_at'] = null;
        expect(study, isNot(isFullyHydratedSyncPayload('bible_studies')));
      });

      test('supports camelCase aliases as well as snake_case', () {
        final camelPerson = {
          'id': 'p1',
          'name': 'Publicador',
          'firstContactAt': '2026-11-10T10:00:00.000Z',
          'status': 'ativo',
          'createdAt': '2026-11-10T10:00:00.000Z',
          'updatedAt': '2026-11-10T10:00:00.000Z',
        };
        expect(camelPerson, isFullyHydratedSyncPayload('people'));
      });

      test('rejects case-insensitive seeds and RIFF/WAVE header with zeroed PCM payload', () {
        expect('PADARIA CENTRAL BETÂNIA', isNot(containsNoTheocraticSeeds()));
        expect('seed_hub_letter_01'.toUpperCase(), isNot(containsNoTheocraticSeeds()));

        final header = MockFixtures.validWavAudioBytes().sublist(0, 44);
        final zeroPcmWav = Uint8List(128)..setRange(0, 44, header);
        expect(zeroPcmWav, isNot(isValidAudioBytes()));
      });
    });
  });
}
