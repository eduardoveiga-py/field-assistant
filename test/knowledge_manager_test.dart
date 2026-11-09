import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/knowledge/knowledge_manager.dart';

void main() {
  group('KnowledgeManager (Módulo C — Base de Conhecimento)', () {
    late AppDatabase db;
    late KnowledgeManager km;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      km = KnowledgeManager(db: db);
    });

    tearDown(() async {
      await db.close();
    });

    test('TC-KNW-01: Criação, fixação e busca de notas de conhecimento', () async {
      final note1 = await km.createNote(
        title: 'Como iniciar conversas com pescadores',
        content: 'Usar ilustração sobre redes e previsão do tempo...',
        category: 'ministry',
      );
      final note2 = await km.createNote(
        title: 'Vocabulário Ticuna de boas-vindas',
        content: 'Ta-ẽ-mã! Nùmá tá i yae?',
        category: 'ticuna',
      );

      expect(note1.title, contains('pescadores'));
      expect(note2.category, equals('ticuna'));

      // Fixa a segunda nota no topo
      await km.togglePinNote(note2.id);
      final notes = await km.watchNotes().first;
      expect(notes.first.id, equals(note2.id));
      expect(notes.first.isPinned, isTrue);

      // Busca textual filtrada
      final searchRes = await km.watchNotes(query: 'pescadores').first;
      expect(searchRes.length, equals(1));
      expect(searchRes.first.id, equals(note1.id));
    });

    test('TC-KNW-02: Gestão de dúvidas teocráticas e respostas bíblicas', () async {
      final q = await km.createQuestion(
        question: 'Por que Deus permite o sofrimento?',
        context: 'Pergunta feita pela dona Maria na rua do porto',
        category: 'biblical',
      );

      expect(q.status, equals('unanswered'));
      expect(q.answer, isNull);

      // Responde a dúvida
      await km.answerQuestion(
        q.id,
        answer: 'Baseado em Tiago 1:13 e 1 João 5:19: Deus nunca causa o mal...',
      );

      final updated = (await km.watchQuestions().first).first;
      expect(updated.status, equals('answered'));
      expect(updated.answer, contains('Tiago 1:13'));
      expect(updated.answeredAt, isNotNull);
    });

    test('TC-KNW-03: Registro de documentos locais com hash SHA-256', () async {
      final doc = await km.registerDocument(
        title: 'Manual de Serviço de Campo 2026',
        fileName: 'manual_campo_2026.pdf',
        fileType: 'pdf',
        fileSize: 204800,
        filePath: 'knowledge_vault/manual_campo_2026.pdf',
        sha256Checksum: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        category: 'manual',
      );

      expect(doc.fileName, equals('manual_campo_2026.pdf'));
      expect(doc.fileSize, equals(204800));

      final docs = await km.watchDocuments().first;
      expect(docs.length, equals(1));
    });

    test('TC-KNW-04: Recursos externos e busca unificada global', () async {
      await km.createResource(
        title: 'Vídeo: Por Que Estudar a Bíblia?',
        resourceType: 'video',
        url: 'https://www.jw.org/pt/biblioteca/videos/#pt/mediaitems/VODMinistryTools/docid-502013341_1_VIDEO',
        description: 'Excelente para introduzir o folheto',
      );

      await km.createNote(
        title: 'A Bíblia e a paz mental',
        content: 'Filipenses 4:6, 7 — A paz de Deus que excede todo o entendimento',
      );

      // Busca unificada por palavra "Bíblia" encontra recurso e nota
      final results = await km.searchKnowledge('Bíblia');
      expect(results.length, greaterThanOrEqualTo(2));
      final types = results.map((r) => r.entityType).toSet();
      expect(types, contains('resource'));
      expect(types, contains('note'));
    });
  });
}
