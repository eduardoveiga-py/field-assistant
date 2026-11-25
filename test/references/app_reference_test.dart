import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/experiences/experience_manager.dart';
import 'package:ministerio_pessoal/inbox/email_html_sanitizer.dart';
import 'package:ministerio_pessoal/inbox/inbox_manager.dart';
import 'package:ministerio_pessoal/knowledge/knowledge_manager.dart';
import 'package:ministerio_pessoal/picture_bank/picture_entry_model.dart';
import 'package:ministerio_pessoal/projects/project_manager.dart';
import 'package:ministerio_pessoal/references/app_reference.dart';
import 'package:ministerio_pessoal/research/research_manager.dart';
import 'package:ministerio_pessoal/tasks/task_manager.dart';

void main() {
  group('AppReferenceHelper & EmailHtmlSanitizer Integration Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'constrói, sanitiza rótulos e interpreta URIs de todas as categorias',
      () {
        final mdQuestion = AppReferenceHelper.buildMarkdownLink(
          AppRefCategory.question,
          'id/com espaço',
          '**Jeová** e a [pré-ciência]\nLinha 2',
        );
        expect(mdQuestion, contains('❓ Jeová e a (pré-ciência) Linha 2'));
        expect(
          mdQuestion,
          contains('(app://ref/question/id%2Fcom%20espa%C3%A7o)'),
        );

        final parsed = AppReferenceHelper.parseUri(
          'app://ref/question/id%2Fcom%20espa%C3%A7o',
        );
        expect(parsed, isNotNull);
        expect(parsed!.category, equals(AppRefCategory.question));
        expect(parsed.itemId, equals('id/com espaço'));

        final bibleLink = AppReferenceHelper.buildBibleMarkdownLink(
          bookNumber: 43,
          chapter: 3,
          verseSpec: '16-17',
        );
        expect(
          bibleLink,
          equals('[📖 João 3:16-17 (TNM)](app://ref/bible/43/3/16-17)'),
        );

        final parsedBible = AppReferenceHelper.parseUri(
          'app://ref/bible/43/3/16-17',
        );
        expect(parsedBible, isNotNull);
        expect(parsedBible!.category, equals(AppRefCategory.bible));
        expect(parsedBible.bookNumber, equals(43));
        expect(parsedBible.chapter, equals(3));
        expect(parsedBible.verseSpec, equals('16-17'));

        expect(AppReferenceHelper.parseUri('https://jw.org'), isNull);
        expect(AppReferenceHelper.parseUri('app://ref/unknown/1'), isNull);
      },
    );

    test(
      'carrega candidatos válidos de todas as 14 categorias no banco Drift',
      () async {
        final km = KnowledgeManager(db: db);
        final taskMgr = TaskManager(db: db);
        final projectMgr = ProjectManager(db: db);
        final inboxMgr = InboxManager(db: db);
        final researchMgr = ResearchManager(db);
        final expMgr = ExperienceManager(db);

        final note = await km.createNote(
          title: 'Nota Teste Ref',
          content: 'Conteúdo da nota',
        );
        final question = await km.createQuestion(
          question: 'Jeová e a pré ciência',
          context: 'Contexto teste',
        );
        final doc = await km.registerDocument(
          title: 'Documento Teste Ref',
          fileName: 'doc.pdf',
          fileType: 'pdf',
          fileSize: 1024,
          filePath: 'doc.pdf',
        );
        final resource = await km.createResource(
          title: 'Recurso Teste Ref',
          resourceType: 'article',
          url: 'https://www.jw.org',
        );

        await PictureBankManager.savePicture(
          db,
          PictureEntry(
            id: 'pic-ref-1',
            caption: 'Gravura de Pregação de Campo',
            tags: const ['campo'],
            imageData: 'assets/pictures/example.png',
            createdAt: DateTime(2026, 11, 24),
            updatedAt: DateTime(2026, 11, 24),
          ),
        );

        final task = await taskMgr.createTask(title: 'Tarefa Teste Ref');
        final project = await projectMgr.createProject(
          name: 'Projeto Teste Ref',
          objective: 'Objetivo teste',
        );
        final capture = await inboxMgr.captureText(
          content: 'Ideia capturada para discurso',
        );

        final now = DateTime(2026, 11, 24, 10, 0);
        await db
            .into(db.inboxEntries)
            .insert(
              InboxEntriesCompanion.insert(
                id: 'email-ref-1',
                content: 'Corpo do email',
                sourceType: const drift.Value('email'),
                status: const drift.Value('unprocessed'),
                capturedAt: now,
                createdAt: now,
                updatedAt: now,
                metadata: drift.Value(
                  jsonEncode({
                    'email': {
                      'subject': 'Convite Especial JW Mail',
                      'from': 'irmao@jw.org',
                    },
                  }),
                ),
              ),
            );

        final research = await researchMgr.addArticle(
          title: 'Pesquisa Profecias',
          summary: 'Resumo',
          content: 'Conteúdo longo',
        );
        final exp = await expMgr.addExperience(
          title: 'Experiência no Barco',
          content: 'Relato edificante',
        );

        await db
            .into(db.people)
            .insert(
              PeopleCompanion.insert(
                id: 'person-ref-1',
                name: 'Carlos Morador',
                firstContactAt: now,
                createdAt: now,
                updatedAt: now,
              ),
            );
        await db
            .into(db.bibleStudies)
            .insert(
              BibleStudiesCompanion.insert(
                id: 'study-ref-1',
                title: 'Estudo Livro LFF - Carlos',
                startedAt: now,
                publicationId: 'lff-book',
                createdAt: now,
                updatedAt: now,
              ),
            );

        expect(
          await AppReferenceHelper.loadCandidates(db, AppRefCategory.bible),
          isEmpty,
        );

        final notes = await AppReferenceHelper.loadCandidates(
          db,
          AppRefCategory.note,
        );
        expect(notes.map((c) => c.id), contains(note.id));

        final questions = await AppReferenceHelper.loadCandidates(
          db,
          AppRefCategory.question,
        );
        expect(questions.map((c) => c.id), contains(question.id));

        final docs = await AppReferenceHelper.loadCandidates(
          db,
          AppRefCategory.document,
        );
        expect(docs.map((c) => c.id), contains(doc.id));

        final resources = await AppReferenceHelper.loadCandidates(
          db,
          AppRefCategory.resource,
        );
        expect(resources.map((c) => c.id), contains(resource.id));

        final pics = await AppReferenceHelper.loadCandidates(
          db,
          AppRefCategory.picture,
        );
        expect(pics.map((c) => c.id), contains('pic-ref-1'));

        final tasks = await AppReferenceHelper.loadCandidates(
          db,
          AppRefCategory.task,
        );
        expect(tasks.map((c) => c.id), contains(task.id));

        final projects = await AppReferenceHelper.loadCandidates(
          db,
          AppRefCategory.project,
        );
        expect(projects.map((c) => c.id), contains(project.id));

        final inbox = await AppReferenceHelper.loadCandidates(
          db,
          AppRefCategory.inbox,
        );
        expect(inbox.map((c) => c.id), contains(capture.id));
        expect(inbox.map((c) => c.id), isNot(contains('email-ref-1')));

        final emails = await AppReferenceHelper.loadCandidates(
          db,
          AppRefCategory.email,
        );
        expect(emails.map((c) => c.id), contains('email-ref-1'));
        expect(emails.map((c) => c.id), isNot(contains(capture.id)));

        final researches = await AppReferenceHelper.loadCandidates(
          db,
          AppRefCategory.research,
        );
        expect(researches.map((c) => c.id), contains(research.id));

        final exps = await AppReferenceHelper.loadCandidates(
          db,
          AppRefCategory.experience,
        );
        expect(exps.map((c) => c.id), contains(exp.id));

        final people = await AppReferenceHelper.loadCandidates(
          db,
          AppRefCategory.person,
        );
        expect(people.map((c) => c.id), contains('person-ref-1'));

        final studies = await AppReferenceHelper.loadCandidates(
          db,
          AppRefCategory.study,
        );
        expect(studies.map((c) => c.id), contains('study-ref-1'));
      },
    );

    test('EmailHtmlSanitizer preserva links app:// internamente e remove no envio externo', () {
      const md =
          'Veja [❓ Jeová e a pré-ciência](app://ref/question/q1), '
          '<u style="color:#EAB308">trecho sublinhado</u> e [JW](https://www.jw.org).';

      final externalHtml = EmailHtmlSanitizer.markdownToCleanHtml(
        md,
        preserveAppRefLinks: false,
      );
      expect(externalHtml, isNot(contains('app://ref/')));
      expect(externalHtml, contains('<b>❓ Jeová e a pré-ciência</b>'));
      expect(externalHtml, contains('<a href="https://www.jw.org">JW</a>'));

      final internalHtml = EmailHtmlSanitizer.markdownToCleanHtml(
        md,
        preserveAppRefLinks: true,
      );
      expect(internalHtml, contains('href="app://ref/question/q1"'));

      final stripped = EmailHtmlSanitizer.stripMarkdown(
        '**Sistema incrível!** <u style="color:#10B981">Paz</u> e <mark style="background:#FFEB3B">alegria</mark>.',
      );
      expect(stripped, equals('Sistema incrível! Paz e alegria.'));
    });
  });
}
