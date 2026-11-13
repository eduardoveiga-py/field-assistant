import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
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
  test('limpeza respeita chaves estrangeiras e inclui módulos novos e cursores', () async {
    await db.customStatement('PRAGMA foreign_keys = ON');
    final person = await repo.createPerson(name: 'Pessoa');
    await repo.createVisit(personId: person.id, dateTime: DateTime.now(), contactType: 'visita', result: 'ok');
    final now = DateTime.now();
    await db.into(db.projects).insert(ProjectsCompanion.insert(
      id: 'project', name: 'Projeto', createdAt: now, updatedAt: now));
    await db.into(db.tasks).insert(TasksCompanion.insert(
      id: 'task', title: 'Tarefa', createdAt: now, updatedAt: now));
    await db.into(db.ticunaWords).insert(TicunaWordsCompanion.insert(
      id: 'word', word: 'palavra', translation: 'tradução',
      createdAt: now.toIso8601String(), updatedAt: now.toIso8601String()));
    await db.into(db.appKvStore).insert(AppKvStoreCompanion.insert(
      key: 'last_synced_at_people', value: now.toIso8601String()));
    await repo.clearAllLocalData();
    expect(await db.select(db.people).get(), isEmpty);
    expect(await db.select(db.visits).get(), isEmpty);
    expect(await db.select(db.projects).get(), isEmpty);
    expect(await db.select(db.tasks).get(), isEmpty);
    expect(await db.select(db.ticunaWords).get(), isEmpty);
    expect(await db.select(db.appKvStore).get(), isEmpty);
    expect(await db.select(db.syncQueue).get(), isEmpty);
  });

  test('exclusão local de pessoa respeita visitas, notas, contatos e links', () async {
    await db.customStatement('PRAGMA foreign_keys = ON');
    final person = await repo.createPerson(name: 'Pessoa a excluir');
    final other = await repo.createPerson(name: 'Outra pessoa');
    final now = DateTime.now();
    final visit = await repo.createVisit(personId: person.id, dateTime: now,
        contactType: 'visita', result: 'ok');
    await db.into(db.voiceNotes).insert(VoiceNotesCompanion.insert(
      id: 'note', personId: other.id, visitId: drift.Value(visit.id),
      transcription: 'nota', createdAt: now, updatedAt: now));
    await db.into(db.phoneContacts).insert(PhoneContactsCompanion.insert(
      id: 'phone', name: 'Contato', phone: '123',
      convertedPersonId: drift.Value(person.id), createdAt: now, updatedAt: now));
    final appointment = await repo.createAppointment(personId: person.id, title: 'Visita',
      startTime: now, endTime: now.add(const Duration(minutes: 30)));
    await db.into(db.calendarEventLinks).insert(CalendarEventLinksCompanion.insert(
      id: 'link', appointmentId: appointment.id, externalEventId: 'external',
      provider: 'google', createdAt: now, updatedAt: now));
    await repo.permanentlyDeleteItem('people', person.id);
    expect(await repo.getPersonById(person.id), isNull);
    expect(await db.select(db.visits).get(), isEmpty);
    expect(await db.select(db.voiceNotes).get(), isEmpty);
    expect(await db.select(db.calendarEventLinks).get(), isEmpty);
    expect((await db.select(db.phoneContacts).get()).single.convertedPersonId, isNull);
    expect((await db.select(db.syncQueue).get()).any((op) =>
      op.entityId == person.id && op.operation == 'HARD_DELETE'), isTrue);
  });

}
