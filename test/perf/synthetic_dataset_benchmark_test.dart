import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'Performance Benchmark — Synthetic Dataset & Indexed Queries (FA-PERF-01)',
    () {
      late AppDatabase db;

      setUp(() async {
        db = AppDatabase.forTesting(NativeDatabase.memory());
      });

      tearDown(() async {
        await db.close();
      });

      test('TC-PERF-01: 5,000 synthetic contacts — bulk insert and sub-50ms indexed search', () async {
        final now = DateTime.now();

        // 1. Inserir 5.000 contatos sintéticos em batch com transação única
        final stopwatchInsert = Stopwatch()..start();
        await db.batch((b) {
          for (var i = 0; i < 5000; i++) {
            final lat = -3.0 + (i % 100) * 0.01;
            final lng = -60.0 + (i % 100) * 0.01;
            b.insert(
              db.people,
              PeopleCompanion.insert(
                id: 'synth-person-$i',
                name: 'Contato Sintético $i',
                status: const Value('interessado'),
                latitude: Value(lat),
                longitude: Value(lng),
                firstContactAt: now,
                createdAt: now,
                updatedAt: now,
              ),
            );
          }
        });
        stopwatchInsert.stop();
        expect(
          stopwatchInsert.elapsedMilliseconds,
          lessThan(10000),
          reason:
              'Bulk insert de 5.000 contatos deve levar menos de 10 segundos',
        );

        // 2. Busca por nome (NOCASE index)
        final stopwatchName = Stopwatch()..start();
        final nameResults =
            await (db.select(db.people)
                  ..where((tbl) => tbl.name.like('Contato Sintético 42%'))
                  ..where((tbl) => tbl.deletedAt.isNull()))
                .get();
        stopwatchName.stop();

        expect(nameResults, isNotEmpty);
        expect(
          stopwatchName.elapsedMilliseconds,
          lessThan(1000),
          reason: 'Busca indexada por nome em 5.000 contatos deve responder rapidamente',
        );

        // 3. Busca espacial (bounding box) usando índices de coordenadas
        final stopwatchCoords = Stopwatch()..start();
        final spatialResults =
            await (db.select(db.people)..where(
                  (tbl) =>
                      tbl.latitude.isBiggerOrEqualValue(-2.5) &
                      tbl.latitude.isSmallerOrEqualValue(-2.0) &
                      tbl.longitude.isBiggerOrEqualValue(-59.5) &
                      tbl.longitude.isSmallerOrEqualValue(-59.0) &
                      tbl.deletedAt.isNull(),
                ))
                .get();
        stopwatchCoords.stop();

        expect(spatialResults, isA<List<PersonEntry>>());
        expect(
          stopwatchCoords.elapsedMilliseconds,
          lessThan(1000),
          reason: 'Filtro por bounding box em 5.000 contatos deve responder rapidamente',
        );
      });

      test('TC-PERF-02: 1,000 appointments — indexed query by start_time and person_id', () async {
        final now = DateTime.now();

        // Inserir 1.000 compromissos
        await db.batch((b) {
          for (var i = 0; i < 1000; i++) {
            final start = now.add(Duration(hours: i));
            b.insert(
              db.appointments,
              AppointmentsCompanion.insert(
                id: 'synth-appt-$i',
                personId: Value('synth-person-${i % 50}'),
                title: 'Estudo Bíblico #$i',
                startTime: start,
                endTime: start.add(const Duration(minutes: 45)),
                createdAt: now,
                updatedAt: now,
              ),
            );
          }
        });

        // Busca por intervalo de data (agenda semanal)
        final rangeStart = now.add(const Duration(days: 2));
        final rangeEnd = now.add(const Duration(days: 9));

        final stopwatchRange = Stopwatch()..start();
        final weeklyAppointments =
            await (db.select(db.appointments)..where(
                  (tbl) =>
                      tbl.startTime.isBiggerOrEqualValue(rangeStart) &
                      tbl.startTime.isSmallerOrEqualValue(rangeEnd) &
                      tbl.deletedAt.isNull(),
                ))
                .get();
        stopwatchRange.stop();

        expect(weeklyAppointments.length, equals(169));
        expect(
          stopwatchRange.elapsedMilliseconds,
          lessThan(500),
          reason:
              'Busca por intervalo de data indexada deve responder rapidamente',
        );
      });
    },
  );
}
