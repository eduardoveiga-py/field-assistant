import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/inbox/email_account_model.dart';
import 'package:ministerio_pessoal/knowledge/knowledge_backlink_indexer.dart';
import 'package:ministerio_pessoal/knowledge/knowledge_manager.dart';
import 'package:ministerio_pessoal/knowledge/notion_import_parser.dart';
import 'package:ministerio_pessoal/knowledge/second_brain_review_service.dart';
import 'package:ministerio_pessoal/projects/project_manager.dart';
import 'package:ministerio_pessoal/settings/backup_service.dart';
import 'package:ministerio_pessoal/tasks/task_manager.dart';
import 'package:ministerio_pessoal/ui/widgets/knowledge/rich_block_markdown_view.dart';

Uint8List _buildMinimalPdfWithText(String literalText) {
  final contentStream = 'BT /F1 12 Tf 72 720 Td ($literalText) Tj ET';
  final compressed = zlib.encode(latin1.encode(contentStream));
  final header = '%PDF-1.4\n';
  final obj1 = '1 0 obj << /Type /Catalog >> endobj\n';
  final obj2Prefix =
      '2 0 obj << /Length ${compressed.length} /Filter /FlateDecode >>\nstream\n';
  final obj2Suffix = '\nendstream\nendobj\n%%EOF';
  return Uint8List.fromList([
    ...latin1.encode(header),
    ...latin1.encode(obj1),
    ...latin1.encode(obj2Prefix),
    ...compressed,
    ...latin1.encode(obj2Suffix),
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late KnowledgeManager km;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    km = KnowledgeManager(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  test('Áreas P.A.R.A., subpáginas hierárquicas, breadcrumbs e proteção contra ciclos', () async {
    final area = await km.createArea(
      name: 'Tradução & Campo',
      colorHex: '#10B981',
    );
    final root = await km.createNote(
      title: 'Manual Ticuna',
      content: 'Visão geral',
      areaId: area.id,
      properties: {'status': 'em_estudo', 'priority': 'alta'},
    );
    final child = await km.createNote(
      title: 'Fonologia',
      content: 'Tons nasais',
      areaId: area.id,
      parentNoteId: root.id,
    );
    final grandChild = await km.createNote(
      title: 'Diacríticos',
      content: 'Marcadores de tom',
      areaId: area.id,
      parentNoteId: child.id,
    );

    final ancestors = await km.getNoteAncestors(grandChild.id);
    expect(ancestors.map((a) => a.title).toList(), [
      'Manual Ticuna',
      'Fonologia',
    ]);

    final subpagesOfRoot = await km.watchSubpages(root.id).first;
    expect(subpagesOfRoot.map((n) => n.id).toList(), [child.id]);

    final notesInArea = await km.watchNotes(areaId: area.id).first;
    expect(notesInArea.length, 3);

    // Impede transformar um ancestral em filho de seu descendente (ciclo)
    await expectLater(
      () => km.updateNote(root.id, parentNoteId: grandChild.id),
      throwsArgumentError,
    );
  });

  test('Backlinks bidirecionais ([[WikiLink]] + app://ref) e limpeza em soft-delete', () async {
    final targetNote = await km.createNote(
      title: 'Discurso Público Base',
      content: 'Esboço central',
    );
    final citingNote = await km.createNote(
      title: 'Ilustrações de Apoio',
      content: 'Usar na introdução de [[Discurso Público Base]].',
    );
    final pm = ProjectManager(db: db);
    final citingProject = await pm.createProject(
      name: 'Assembleia Circuito',
      description: 'Revisar [esboço](app://ref/note/${targetNote.id}) antes.',
    );

    final linksToTarget = await KnowledgeBacklinkIndexer.getBacklinksFor(
      db,
      targetType: 'note',
      targetId: targetNote.id,
    );
    expect(linksToTarget.length, 2);
    expect(
      linksToTarget.map((b) => b.sourceTitle).toSet(),
      containsAll(['Ilustrações de Apoio', 'Assembleia Circuito']),
    );

    // Atualiza nota removendo a menção e verifica remoção reativa do backlink
    await km.updateNote(citingNote.id, content: 'Sem referência agora.');
    final afterEdit = await KnowledgeBacklinkIndexer.getBacklinksFor(
      db,
      targetType: 'note',
      targetId: targetNote.id,
    );
    expect(afterEdit.length, 1);
    expect(afterEdit.first.sourceId, citingProject.id);

    final deleteQueued =
        await (db.select(db.syncQueue)..where(
              (t) =>
                  t.entityType.equals('knowledge_links') &
                  t.operation.equals('DELETE'),
            ))
            .get();
    expect(deleteQueued, isNotEmpty);
  });

  test('Busca FTS5 + extração de texto PDF e tolerância a acentos', () async {
    final area = await km.createArea(name: 'Idiomas');
    await km.createNote(
      title: 'Bíblia Estudada no Campo',
      content: 'Aplicação prática para revisitas semanais.',
      tags: ['devocional', 'field-service'],
      areaId: area.id,
    );

    final pdfBytes = _buildMinimalPdfWithText('Glossario Ticuna Especial');
    final doc = await km.registerDocument(
      title: 'Caderno Anexo',
      fileName: 'anexo_01.pdf',
      fileType: 'pdf',
      fileSize: pdfBytes.length,
      filePath: '/docs/anexo_01.pdf',
      documentBytes: pdfBytes,
      areaId: area.id,
      tags: ['glossario', 'ticuna'],
    );
    expect(doc.extractedText, contains('Glossario Ticuna Especial'));

    final pdfHits = await km.searchKnowledge('glossario especial');
    expect(
      pdfHits.any((r) => r.entityType == 'document' && r.id == doc.id),
      isTrue,
    );

    // Consulta sem acento encontra "Bíblia Estudada"
    final accentInsensitiveHits = await km.searchKnowledge('biblia estudada');
    expect(
      accentInsensitiveHits.any((r) => r.title.contains('Bíblia Estudada')),
      isTrue,
    );
  });

  test(
    'Revisão Espaçada (SM-2) e Revisão Semanal (GTD + Projetos estagnados)',
    () async {
      final now = DateTime.utc(2026, 11, 26, 12, 0);
      final dueNote = await km.createNote(
        title: 'Pergaminho de Isaías',
        content: 'Notas históricas',
        nextReviewAt: now.subtract(const Duration(hours: 2)),
      );
      final dueQuestion = await km.createQuestion(
        question: 'Como citar João 17:3 em Ticuna?',
        answer: 'Focar em conhecer a Deus.',
        status: 'answered',
        nextReviewAt: now.subtract(const Duration(minutes: 30)),
      );
      await km.createQuestion(
        question: 'Mapa atualizado do setor 4?',
        status: 'unanswered',
      );

      await db
          .into(db.inboxEntries)
          .insert(
            InboxEntriesCompanion.insert(
              id: 'inbox-pending-1',
              content: 'Lembrar de baixar novo cântico',
              status: const Value('unprocessed'),
              capturedAt: now,
              createdAt: now,
              updatedAt: now,
            ),
          );

      final pm = ProjectManager(db: db);
      final tm = TaskManager(db: db);
      final stalledProject = await pm.createProject(
        name: 'Projeto Sem Próxima Ação',
        status: 'active',
      );
      final healthyProject = await pm.createProject(
        name: 'Projeto Saudável',
        status: 'active',
      );
      await tm.createTask(
        title: 'Concluir etapa 1',
        projectId: healthyProject.id,
      );

      final start = now.toLocal().add(const Duration(days: 2));
      await db
          .into(db.appointments)
          .insert(
            AppointmentsCompanion.insert(
              id: 'appt-soon-1',
              title: 'Estudo Familiar',
              startTime: start,
              endTime: start.add(const Duration(hours: 1)),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final review = await SecondBrainReviewService.loadWeeklyReview(
        db,
        now: now,
      );
      expect(review.unprocessedInbox.length, 1);
      expect(review.dueReviewNotes.map((n) => n.id), [dueNote.id]);
      expect(review.dueReviewQuestions.map((q) => q.id), [dueQuestion.id]);
      expect(review.unansweredQuestions.length, 1);
      expect(review.stalledActiveProjects.map((p) => p.id), [
        stalledProject.id,
      ]);
      expect(review.upcomingAppointments.length, 1);

      final next = await SecondBrainReviewService.recordNoteReview(
        db,
        dueNote.id,
        ReviewQuality.good,
        now: now,
      );
      expect(next, isNotNull);
      expect(next!.nextLevel, 1);
      expect(next.nextReviewAt, now.add(const Duration(days: 3)));
    },
  );

  test('Importação Notion (.zip com subpáginas, CSV e links) e commit transacional com Sync', () async {
    final archive = Archive();
    void addTextFile(String path, String content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    addTextFile(
      'Teocracia/Discursos 11111111222222223333333344444444.md',
      '''---
Status: Em Estudo
Tags: discurso, sabado
---
# Discursos

> [!TIP] Confira antes [Subtema](Discursos/Subtema%20aaaaaaaa11111111bbbbbbbb22222222.md).

:::toggle Esboço rápido
- [ ] Revisar introdução
:::
''',
    );
    addTextFile(
      'Teocracia/Discursos/Subtema aaaaaaaa11111111bbbbbbbb22222222.md',
      '''# Subtema
Ligado à raiz [[Discursos]].
''',
    );
    addTextFile(
      'Tabela Estudos.csv',
      'Name,Status,Tags\nEstudo João,Ativo,"lucas, campo"\n',
    );

    final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));
    final parsed = NotionImportParser.parseZipBytes(zipBytes);
    expect(parsed.notes.length, greaterThanOrEqualTo(3));
    expect(parsed.rewrittenLinksCount, greaterThanOrEqualTo(1));

    final result = await SecondBrainReviewService.commitNotionPackage(
      db,
      parsed,
    );
    expect(result.createdAreas, greaterThanOrEqualTo(1));
    expect(result.importedNotes, parsed.notes.length);

    final notes = await (db.select(
      db.knowledgeNotes,
    )..where((t) => t.deletedAt.isNull())).get();
    final parent = notes.firstWhere((n) => n.title == 'Discursos');
    final child = notes.firstWhere((n) => n.title == 'Subtema');
    expect(child.parentNoteId, parent.id);
    expect(parent.content, contains('app://ref/note/${child.id}'));

    final backlinksToChild = await KnowledgeBacklinkIndexer.getBacklinksFor(
      db,
      targetType: 'note',
      targetId: child.id,
    );
    expect(backlinksToChild.any((b) => b.sourceId == parent.id), isTrue);
  });

  test('Parser de blocos estilo Notion (Toggle, Callout, Tabela, Checklist alternável)', () {
    const sample = '''
> [!IMPORTANT] Texto chave de Mateus 24:14.

:::toggle Pontos principais
Detalhes do tópico
:::

| Livro | Capítulo |
| :--- | :---: |
| Salmos | 83 |

- [ ] Ler comentário
- [x] Revisar versículo
''';
    final blocks = SecondBrainBlockParser.parse(sample);
    expect(blocks.whereType<CalloutSecondBrainBlock>().length, 1);
    expect(blocks.whereType<ToggleSecondBrainBlock>().length, 1);
    expect(blocks.whereType<TableSecondBrainBlock>().length, 1);
    final checklists = blocks.whereType<ChecklistSecondBrainBlock>().toList();
    expect(checklists.length, 2);
    expect(checklists[0].checked, isFalse);
    expect(checklists[1].checked, isTrue);

    final toggled = SecondBrainBlockParser.toggleChecklistLine(
      sample,
      checklists[0].sourceLineIndex,
    );
    expect(toggled, contains('- [x] Ler comentário'));
  });

  test('BackupService preserva EmailAccounts (sem senhas), KnowledgeAreas e KnowledgeLinks no roundtrip', () async {
    final tmpDir = Directory.systemTemp.createTempSync('fa_backup_sb_');
    addTearDown(() async {
      if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
    });

    final acc = EmailAccount.createPreset(
      id: 'bk-email-1',
      providerType: EmailProviderType.exchange,
      name: 'Conta Trabalho',
      email: 'trabalho@jwpub.org',
      username: 'trabalho@jwpub.org',
    );
    await EmailAccountsManager.saveAccount(
      db,
      acc,
      password: 'LOCAL_ONLY_PASS',
    );

    final area = await km.createArea(name: 'Congregação');
    final noteA = await km.createNote(
      title: 'Pauta A',
      content: 'Conteúdo A',
      areaId: area.id,
    );
    await km.createNote(
      title: 'Pauta B',
      content: 'Referência à [[Pauta A]].',
      areaId: area.id,
    );

    final backupSvc = BackupService(
      AppRepository(db),
      documentsDirectoryProvider: () async => tmpDir,
      secureStorage: const FlutterSecureStorage(),
    );
    final encrypted = await backupSvc.exportEncryptedBackup('BackupPass123!');

    final db2 = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async => db2.close());
    final backupSvc2 = BackupService(
      AppRepository(db2),
      documentsDirectoryProvider: () async => tmpDir,
      secureStorage: const FlutterSecureStorage(),
    );
    final preview = await backupSvc2.previewBackup(
      encryptedDataString: encrypted,
      password: 'BackupPass123!',
    );
    expect(preview.emailAccountsToAdd, 1);
    expect(preview.knowledgeAreasToAdd, 1);
    expect(preview.knowledgeLinksToAdd, 1);

    final restore = await backupSvc2.commitRestore(preview);
    expect(restore.restoredRecordsCount, greaterThan(0));
    expect(
      preview.rawDecryptedData.toString(),
      isNot(contains('LOCAL_ONLY_PASS')),
    );

    final restoredAccounts = await EmailAccountsManager.loadAccounts(db2);
    expect(restoredAccounts.map((a) => a.email), ['trabalho@jwpub.org']);
    FlutterSecureStorage.setMockInitialValues({});
    expect(
      await EmailAccountsManager.hasLocalCredentials(
        restoredAccounts.first,
        db2,
      ),
      isFalse,
    );
    final restoredBacklinks = await KnowledgeBacklinkIndexer.getBacklinksFor(
      db2,
      targetType: 'note',
      targetId: noteA.id,
    );
    expect(restoredBacklinks.length, 1);
  });
}
