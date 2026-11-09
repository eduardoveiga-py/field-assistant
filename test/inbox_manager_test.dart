import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/inbox/inbox_manager.dart';

void main() {
  group('InboxManager (Módulo A — Inbox Universal)', () {
    late AppDatabase db;
    late InboxManager inboxMgr;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      inboxMgr = InboxManager(db: db);
    });

    tearDown(() async {
      await db.close();
    });

    test('TC-INB-01: Captura rápida de texto livre', () async {
      final entry = await inboxMgr.captureText(
        content: 'Falar com irmão Marcos sobre a revisita na rua 5',
        suggestedCategory: 'ministry',
      );

      expect(entry.id, isNotEmpty);
      expect(entry.content, equals('Falar com irmão Marcos sobre a revisita na rua 5'));
      expect(entry.sourceType, equals('text'));
      expect(entry.suggestedCategory, equals('ministry'));
      expect(entry.status, equals('unprocessed'));

      final count = await inboxMgr.watchUnprocessedCount().first;
      expect(count, equals(1));
    });

    test('TC-INB-02: Captura rápida de nota de voz (áudio)', () async {
      final entry = await inboxMgr.captureAudio(
        content: 'Ditado de ideias para estudo bíblico',
        audioPath: '/local/audio/note123.m4a',
        durationSeconds: 45,
        suggestedCategory: 'study',
      );

      expect(entry.sourceType, equals('audio'));
      expect(entry.mediaPath, equals('/local/audio/note123.m4a'));
      expect(entry.mediaDurationSeconds, equals(45));
      expect(entry.suggestedCategory, equals('study'));
    });

    test('TC-INB-03: Captura com documento anexado', () async {
      final entry = await inboxMgr.captureAttachment(
        content: 'Manual de pioneiro recebido',
        filePath: '/docs/pioneiro.pdf',
        fileName: 'pioneiro.pdf',
        fileType: 'pdf',
        suggestedCategory: 'ministry',
      );

      expect(entry.sourceType, equals('file'));
      expect(entry.mediaPath, equals('/docs/pioneiro.pdf'));
      expect(entry.attachments, contains('pioneiro.pdf'));
    });

    test('TC-INB-04: Transição de status (in_review, archive, softDelete)', () async {
      final entry = await inboxMgr.captureText(content: 'Ideia para revisar mais tarde');
      expect(entry.status, equals('unprocessed'));

      await inboxMgr.markInReview(entry.id);
      var updated = await inboxMgr.getEntryById(entry.id);
      expect(updated?.status, equals('in_review'));

      await inboxMgr.archiveEntry(entry.id);
      updated = await inboxMgr.getEntryById(entry.id);
      expect(updated?.status, equals('archived'));
      expect(updated?.processedAt, isNotNull);

      await inboxMgr.softDeleteEntry(entry.id);
      updated = await inboxMgr.getEntryById(entry.id);
      expect(updated?.deletedAt, isNotNull);
    });

    test('TC-INB-05: Conversão não-destrutiva em Tarefa', () async {
      final entry = await inboxMgr.captureText(
        content: 'Preparar folhetos para sábado de manhã',
        suggestedCategory: 'ministry',
      );

      final task = await inboxMgr.convertToTask(
        entry.id,
        title: 'Preparar folhetos de campo',
        priority: 'high',
        category: 'ministry',
      );

      expect(task.title, equals('Preparar folhetos de campo'));
      expect(task.originInboxId, equals(entry.id));
      expect(task.priority, equals('high'));

      // Verifica que o item do inbox NÃO foi destruído, mas marcado como converted
      final inboxAfter = await inboxMgr.getEntryById(entry.id);
      expect(inboxAfter?.status, equals('converted'));
      expect(inboxAfter?.convertedEntityType, equals('task'));
      expect(inboxAfter?.convertedEntityId, equals(task.id));
      expect(inboxAfter?.processedAt, isNotNull);
    });

    test('TC-INB-06: Conversão não-destrutiva em Projeto', () async {
      final entry = await inboxMgr.captureText(
        content: 'Construir roteiro de pregação nas aldeias',
        suggestedCategory: 'ministry',
      );

      final project = await inboxMgr.convertToProject(
        entry.id,
        name: 'Campanha Aldeias 2026',
        objective: 'Alcançar 100% das famílias ribeirinhas',
      );

      expect(project.name, equals('Campanha Aldeias 2026'));
      expect(project.originInboxId, equals(entry.id));

      final inboxAfter = await inboxMgr.getEntryById(entry.id);
      expect(inboxAfter?.status, equals('converted'));
      expect(inboxAfter?.convertedEntityType, equals('project'));
      expect(inboxAfter?.convertedEntityId, equals(project.id));
    });

    test('TC-INB-07: Conversão em Nota de Conhecimento e Dúvida', () async {
      final entry = await inboxMgr.captureText(
        content: 'Quem foi o rei Josias e quais lições para jovens?',
        suggestedCategory: 'study',
      );

      final question = await inboxMgr.convertToQuestion(
        entry.id,
        question: 'Quais lições podemos tirar da vida de Josias?',
      );

      expect(question.question, equals('Quais lições podemos tirar da vida de Josias?'));
      expect(question.originInboxId, equals(entry.id));

      final inboxAfter = await inboxMgr.getEntryById(entry.id);
      expect(inboxAfter?.status, equals('converted'));
      expect(inboxAfter?.convertedEntityType, equals('question'));
    });
  });
}
