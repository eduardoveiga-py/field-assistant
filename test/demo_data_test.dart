import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:ministerio_pessoal/core/demo_data.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';

void main() {
  late AppDatabase db;
  late AppRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = AppRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('DemoDataGenerator popula e remove dados de demonstração com sucesso', () async {
    expect(await DemoDataGenerator.hasDemoData(repo), isFalse);

    // Popula
    await DemoDataGenerator.populateDemoData(repo);
    expect(await DemoDataGenerator.hasDemoData(repo), isTrue);

    final people = await repo.getAllPeople();
    expect(people.length, greaterThanOrEqualTo(4));
    expect(people.any((p) => p.name.contains('(Demo)')), isTrue);

    final studies = await (db.select(db.bibleStudies)).get();
    expect(studies.length, greaterThanOrEqualTo(2));

    final appts = await repo.getAllAppointments();
    expect(appts.length, greaterThanOrEqualTo(2));

    // Remove
    final removed = await DemoDataGenerator.clearDemoData(repo);
    expect(removed, greaterThanOrEqualTo(4));
    expect(await DemoDataGenerator.hasDemoData(repo), isFalse);

    final remainingPeople = await repo.getAllPeople();
    expect(remainingPeople.where((p) => p.name.contains('(Demo)')), isEmpty);

    final remainingStudies = await (db.select(db.bibleStudies)
          ..where((t) => t.title.isIn(DemoDataGenerator.demoStudyTitles)))
        .get();
    expect(remainingStudies, isEmpty);
  });

  test('AppRepository.clearAllLocalData zera o banco de dados completamente', () async {
    await DemoDataGenerator.populateDemoData(repo);
    expect((await repo.getAllPeople()).isNotEmpty, isTrue);

    await repo.clearAllLocalData();

    expect(await repo.getAllPeople(), isEmpty);
    expect(await repo.getAllAppointments(), isEmpty);
    expect(await (db.select(db.visits)).get(), isEmpty);
    expect(await (db.select(db.bibleStudies)).get(), isEmpty);
    expect(await (db.select(db.activityRecords)).get(), isEmpty);
  });
}
