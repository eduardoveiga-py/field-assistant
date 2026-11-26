import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/inbox/inbox_manager.dart';
import 'package:ministerio_pessoal/inbox/jw_email_service.dart';
import 'package:ministerio_pessoal/knowledge/knowledge_manager.dart';
import 'package:ministerio_pessoal/official_docs/official_doc_models.dart';
import 'package:ministerio_pessoal/reports/knowledge_and_email_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  final now = DateTime(2026, 11, 25, 14, 30);

  bool startsWithPdfHeader(List<int> bytes) {
    if (bytes.length < 5) return false;
    return utf8.decode(bytes.sublist(0, 5), allowMalformed: true) == '%PDF-';
  }

  group('KnowledgeAndEmailPdfService', () {
    test('Gera PDF valido para E-mail e Captura do Inbox', () async {
      final email = JwEmailMessage(
        id: 'em-1',
        from: 'secretaria@congregacao.jwpub.org',
        to: 'publicador@jwpub.org',
        subject: 'Designações de Novembro — Língua Ticuna',
        bodyText: 'Prezados irmãos,\n\nSegue a escala atualizada com apoio à língua Tupanaãrü Ore.',
        date: now,
        attachments: const [
          {'name': 'escala.pdf', 'size': 2048},
        ],
      );
      final emailBytes = await KnowledgeAndEmailPdfService.buildEmailPdfBytes(
        email,
      );
      expect(startsWithPdfHeader(emailBytes), isTrue);
      expect(emailBytes.length, greaterThan(500));

      final inboxMgr = InboxManager(db: db);
      final entry = await inboxMgr.captureText(
        content:
            'Revisar [📖 João 3:16 (TNM)](app://ref/bible/43/3/16) na visita.',
      );
      final inboxBytes =
          await KnowledgeAndEmailPdfService.buildInboxEntryPdfBytes(entry);
      expect(startsWithPdfHeader(inboxBytes), isTrue);
      expect(inboxBytes.length, greaterThan(500));
    });

    test(
      'Gera PDF valido para todas as colecoes da Base de Conhecimento',
      () async {
        final km = KnowledgeManager(db: db);
        final note = await km.createNote(
          title: 'Estudo em Ticuna',
          content: 'Texto com marcação <u style="color:#EAB308">importante</u> e Tupanaãrü Ore.',
          category: 'ministério',
          tags: const ['ticuna', 'visita'],
          isPinned: true,
        );
        final notesBytes =
            await KnowledgeAndEmailPdfService.buildNotesListPdfBytes([note]);
        expect(startsWithPdfHeader(notesBytes), isTrue);

        final singleBytes =
            await KnowledgeAndEmailPdfService.buildSingleItemPdfBytes(
              title: note.title,
              content: note.content,
              itemType: 'Nota',
              category: note.category,
              tags: const ['ticuna'],
              updatedAt: note.updatedAt,
            );
        expect(startsWithPdfHeader(singleBytes), isTrue);

        final question = await km.createQuestion(
          question: 'Como explicar Mateus 24:14 em poucas palavras?',
          context: 'Conversa na primeira visita.',
          answer: 'Mostrar o propósito do Reino em todo o mundo.',
          status: 'answered',
          category: 'Pregação',
        );
        final questionsBytes =
            await KnowledgeAndEmailPdfService.buildQuestionsListPdfBytes([
              question,
            ]);
        expect(startsWithPdfHeader(questionsBytes), isTrue);

        final doc = await km.registerDocument(
          title: 'Roteiro da Reunião',
          fileName: 'roteiro.pdf',
          fileType: 'pdf',
          fileSize: 12400,
          filePath: 'roteiro.pdf',
          description: 'Documento de apoio semestral.',
          category: 'manual',
        );
        final docsBytes =
            await KnowledgeAndEmailPdfService.buildDocumentsListPdfBytes([doc]);
        expect(startsWithPdfHeader(docsBytes), isTrue);

        final resource = await km.createResource(
          title: 'Biblioteca Online JW',
          resourceType: 'link',
          url: 'https://wol.jw.org',
          description: 'Acesso rápido às pesquisas bíblicas.',
          category: 'pesquisa',
          tags: const ['wol'],
        );
        final resourcesBytes =
            await KnowledgeAndEmailPdfService.buildResourcesListPdfBytes([
              resource,
            ]);
        expect(startsWithPdfHeader(resourcesBytes), isTrue);

        final officialDocs = [
          OfficialDocumentRecord(
            id: 'od-1',
            docType: OfficialDocType.generalLetter,
            layoutStyleId: OfficialDocLayoutStyle.classicRefined.id,
            title: 'Carta de Apresentação',
            locationDate: 'Manaus - AM, 25 de novembro de 2026',
            referenceSubject: 'Apresentação de Publicadores',
            recipientLine: 'À congregação receptora',
            bodyMarkup: 'Prezados irmãos,\nRecomendamos o irmão...',
            customGroupTitle: 'Comissão de Serviço',
            customSigners: const [],
            includeHeader: true,
            createdAt: now,
            updatedAt: now,
          ),
        ];
        final officialBytes =
            await KnowledgeAndEmailPdfService.buildOfficialDocsIndexPdfBytes(
              officialDocs,
            );
        expect(startsWithPdfHeader(officialBytes), isTrue);
      },
    );
  });
}
