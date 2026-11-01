import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/voice_notes/voice_note_parser.dart';
import 'package:ministerio_pessoal/voice_notes/voice_notes_manager.dart';
import 'package:ministerio_pessoal/contacts/phone_contacts_manager.dart';
import 'package:ministerio_pessoal/territory/landmark_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VoiceNoteParser Theocratic Enhancements & Negative Tests', () {
    test('TC-PARSER-NEG-01: Não confunde capítulos e referências bíblicas com lições de estudo', () {
      // "João 3:16" não deve virar lição 3 nem 16
      final note1 = VoiceNoteParser.parse(
        'Lemos o texto de João capítulo 3 versículo 16 com o morador.',
      );
      expect(note1.lesson, isNull);

      // "Salmo capítulo 23"
      final note2 = VoiceNoteParser.parse(
        'Consideramos o Salmo capítulo 23 sobre consolo.',
      );
      expect(note2.lesson, isNull);

      // "Romanos capítulo 8 versículo 28"
      final note3 = VoiceNoteParser.parse(
        'Lemos Romanos capítulo 8 versículo 28.',
      );
      expect(note3.lesson, isNull);

      // "Mateus 24:14"
      final note4 = VoiceNoteParser.parse(
        'Abrimos em Mateus capítulo 24 versículo 14.',
      );
      expect(note4.lesson, isNull);
    });

    test('TC-PARSER-NEG-02: Não confunde expressões idiomáticas de ponto ou quantidades com pontos de estudo', () {
      // "ponto de ônibus"
      final note1 = VoiceNoteParser.parse(
        'Encontrei a dona Maria no ponto de ônibus às 15 horas.',
      );
      expect(note1.point, isNull);

      // "ponto de encontro"
      final note2 = VoiceNoteParser.parse(
        'Marcamos saída no ponto de encontro para o campo.',
      );
      expect(note2.point, isNull);

      // Quantidades seguidas de unidades ("ponto 2 pessoas", "ponto 3 horas")
      final note3 = VoiceNoteParser.parse(
        'No ponto 2 pessoas estavam aguardando atendimento.',
      );
      expect(note3.point, isNull);
    });

    test('TC-PARSER-POS-03: Respeita limites estritos da publicação vinculada sem inventar unidades', () {
      // Brochura Seja Feliz Para Sempre tem 3 lições
      final noteBrochure = VoiceNoteParser.parse(
        'Estudo na lição 4 ponto 2 da brochura.',
        publicationId: 'lff-brochure',
      );
      // Lição 4 é inválida para a brochura (limite 3)
      expect(noteBrochure.lesson, isNull);

      // Livro Seja Feliz Para Sempre tem 60 lições
      final noteBookValid = VoiceNoteParser.parse(
        'Estudo na lição 58 ponto 3.',
        publicationId: 'lff-book',
      );
      expect(noteBookValid.lesson, equals(58));
      expect(noteBookValid.point, equals(3));

      // Lição 75 excede o limite de 60
      final noteBookInvalid = VoiceNoteParser.parse(
        'Estudo na lição 75 ponto 1.',
        publicationId: 'lff-book',
      );
      expect(noteBookInvalid.lesson, isNull);

      // Ponto 85 excede limite razoável (máx 10)
      final notePointInvalid = VoiceNoteParser.parse('Lição 12 ponto 85.');
      expect(notePointInvalid.point, isNull);
    });

    test('TC-PARSER-POS-04: Extração robusta de nomes com novos conectivos de campo', () {
      final n1 = VoiceNoteParser.parse('Falamos com o Roberto sobre o Reino.');
      expect(n1.studentName, equals('Roberto'));

      final n2 = VoiceNoteParser.parse('Visita ao senhor José da Silva.');
      expect(n2.studentName, equals('José'));

      final n3 = VoiceNoteParser.parse(
        'Conversamos com a senhora Lúcia sobre a Bíblia.',
      );
      expect(n3.studentName, equals('Lúcia'));
    });

    test('TC-PARSER-POS-05: Gatilhos empáticos expandidos de saúde e vida', () {
      final n1 = VoiceNoteParser.parse(
        'Ela comentou que está com internação marcada.',
      );
      expect(n1.empathyNote, isNotNull);
      expect(n1.empathyNote!.toLowerCase(), contains('internação'));

      final n2 = VoiceNoteParser.parse(
        'Ele está com crise de coluna e dor forte.',
      );
      expect(n2.empathyNote, isNotNull);
      expect(n2.empathyNote!.toLowerCase(), contains('coluna'));

      final n3 = VoiceNoteParser.parse(
        'Ela mencionou gravidez recente e bebê a caminho.',
      );
      expect(n3.empathyNote, isNotNull);
      expect(n3.empathyNote!.toLowerCase(), contains('gravidez'));
    });
  });

  group('VoiceNotesManager Visit & Study Integration Rules', () {
    late AppDatabase db;
    late AppRepository repo;
    late VoiceNotesManager manager;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = AppRepository(db);
      manager = VoiceNotesManager(db, repo);
    });

    tearDown(() async {
      await db.close();
    });

    test('TC-VNM-01: Não classifica visita como estudo automaticamente apenas porque pessoa tem estudo vinculado', () async {
      final person = await repo.createPerson(
        name: 'Carlos Oliveira',
        status: 'estudo',
      );

      final study = await repo.createStudy(
        title: 'Seja Feliz para Sempre!',
        publicationId: 'lff-book',
        currentLesson: 10,
        currentParagraph: 2,
        participantPersonIds: [person.id],
      );

      // Nota rápida de visita regular/revisita na porta (sem menção explícita de estudo e sem contactType fornecido)
      final note = VoiceNoteParser.parse(
        'Passei para deixar o convite com o Carlos. Ficou de confirmar a ida.',
      );
      final result = await manager.saveQuickVisitFromVoiceNote(
        personId: person.id,
        parsedNote: note,
      );

      // ContactType DEVE ser revisita, NÃO estudo!
      expect(result.visit!.contactType, equals('revisita'));
      expect(result.visit!.result, equals('revisita_feita'));

      // O estudo NÃO pode ter seu progresso nem lastSessionAt alterados!
      final checkStudy = await repo.getStudyById(study.id);
      expect(checkStudy!.currentLesson, equals(10));
      expect(checkStudy.lastSessionAt, isNull);
    });

    test('TC-VNM-02: Se for explicitamente estudo, cria visita com resultado estudo_realizado e atualiza progresso', () async {
      final person = await repo.createPerson(
        name: 'Mariana Lima',
        status: 'estudo',
      );

      final study = await repo.createStudy(
        title: 'Seja Feliz para Sempre!',
        publicationId: 'lff-book',
        currentLesson: 5,
        currentParagraph: 1,
        participantPersonIds: [person.id],
      );

      final note = VoiceNoteParser.parse(
        'Estudo com a Mariana, lição 6 ponto 3. Ficou de ler o texto.',
      );
      final result = await manager.saveQuickVisitFromVoiceNote(
        personId: person.id,
        parsedNote: note,
        contactType: 'estudo',
      );

      expect(result.visit!.contactType, equals('estudo'));
      expect(result.visit!.result, equals('estudo_realizado'));

      // Progresso atualizado
      final updatedStudy = await repo.getStudyById(study.id);
      expect(updatedStudy!.currentLesson, equals(6));
      expect(updatedStudy.currentParagraph, equals(3));
      expect(updatedStudy.lastSessionAt, isNotNull);
    });
  });

  group('Soft Delete & Sync Queue in PhoneContacts and Landmarks', () {
    late AppDatabase db;
    late PhoneContactsManager phoneManager;
    late LandmarkManager landmarkManager;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      phoneManager = PhoneContactsManager(db);
      landmarkManager = LandmarkManager(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('TC-SYNC-SOFT-01: Exclusão de contato telefônico executa soft delete e enfileira na sync_queue', () async {
      final contact = await phoneManager.addPhoneContact(
        name: 'Lucas Ferreira',
        phone: '11988887777',
      );

      // Confirma que foi enfileirado INSERT
      final queueInsert =
          await (db.select(db.syncQueue)..where(
                (t) =>
                    t.entityId.equals(contact.id) &
                    t.operation.equals('INSERT'),
              ))
              .get();
      expect(queueInsert.length, equals(1));

      // Executa exclusão
      await phoneManager.deletePhoneContact(contact.id);

      // Contato não aparece mais na lista de contatos ativos
      final activeContacts = await phoneManager.getAllPhoneContacts();
      expect(activeContacts.any((c) => c.id == contact.id), isFalse);

      // Registro continua no banco SQLite com deletedAt preenchido (soft delete)
      final rawRow = await (db.select(
        db.phoneContacts,
      )..where((t) => t.id.equals(contact.id))).getSingle();
      expect(rawRow.deletedAt, isNotNull);

      // Enfileirou DELETE na sync_queue
      final queueDelete =
          await (db.select(db.syncQueue)..where(
                (t) =>
                    t.entityId.equals(contact.id) &
                    t.operation.equals('DELETE'),
              ))
              .get();
      expect(queueDelete.length, equals(1));
    });

    test('TC-SYNC-SOFT-02: Exclusão de marco do território executa soft delete e enfileira na sync_queue', () async {
      final landmark = await landmarkManager.addLandmark(
        name: 'Mercado Municipal',
        category: 'mercado',
        address: 'Rua do Comércio, 50',
      );

      // Confirma enfileiramento INSERT
      final queueInsert =
          await (db.select(db.syncQueue)..where(
                (t) =>
                    t.entityId.equals(landmark.id) &
                    t.operation.equals('INSERT'),
              ))
              .get();
      expect(queueInsert.length, equals(1));

      // Executa exclusão
      await landmarkManager.deleteLandmark(landmark.id);

      // Marco não aparece mais na listagem
      final activeLandmarks = await landmarkManager.getLandmarks();
      expect(activeLandmarks.any((l) => l.id == landmark.id), isFalse);

      // Registro preservado com deletedAt
      final rawRow = await (db.select(
        db.territoryLandmarks,
      )..where((t) => t.id.equals(landmark.id))).getSingle();
      expect(rawRow.deletedAt, isNotNull);

      // Enfileirou DELETE na sync_queue
      final queueDelete =
          await (db.select(db.syncQueue)..where(
                (t) =>
                    t.entityId.equals(landmark.id) &
                    t.operation.equals('DELETE'),
              ))
              .get();
      expect(queueDelete.length, equals(1));
    });
  });
}
