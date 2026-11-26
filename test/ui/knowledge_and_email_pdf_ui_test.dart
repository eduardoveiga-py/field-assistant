import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ministerio_pessoal/core/biometric_auth_service.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/inbox/jw_email_service.dart';
import 'package:ministerio_pessoal/knowledge/knowledge_manager.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/screens/inbox_screen.dart';
import 'package:ministerio_pessoal/ui/screens/knowledge_base_screen.dart';
import 'package:ministerio_pessoal/ui/screens/official_documents_screen.dart';
import 'package:ministerio_pessoal/ui/widgets/knowledge/knowledge_ui_components.dart';
import 'package:ministerio_pessoal/ui/widgets/knowledge_item_reader_dialog.dart';

class _UnlockedBiometric extends BiometricAuthService {
  @override
  bool get isSessionUnlocked => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Exportação PDF — E-mails e Todas as Abas da Base de Conhecimento', () {
    testWidgets(
      'InboxScreen oferece Documento PDF (.pdf) no modal de exportacao de e-mail',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final repo = AppRepository(db);
        var dbClosed = false;
        addTearDown(() async {
          if (!dbClosed) {
            await db.close();
          }
        });

        final now = DateTime.now();
        final msg = JwEmailMessage(
          id: 'email-pdf-1',
          folderName: 'INBOX',
          subject: 'Carta de Escala Mensal',
          from: 'secretaria@jw.org',
          to: 'publicador@jw.org',
          date: now,
          bodyText: 'Prezados irmãos,\nConteúdo completo do e-mail para PDF.',
          isDraft: false,
          isRead: true,
        );
        await db
            .into(db.inboxEntries)
            .insert(
              InboxEntriesCompanion.insert(
                id: 'email_${msg.id}',
                sourceType: const drift.Value('email'),
                content: msg.bodyText,
                capturedAt: msg.date,
                createdAt: now,
                updatedAt: now,
                metadata: drift.Value(jsonEncode({'email': msg.toJson()})),
              ),
            );

        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
              biometricAuthServiceProvider.overrideWithValue(
                _UnlockedBiometric(),
              ),
            ],
            child: const MaterialApp(home: InboxScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('JW Mail'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Carta de Escala Mensal').first);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Exportar').first);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('btn_export_email_pdf')), findsOneWidget);
        expect(find.text('Documento PDF (.pdf)'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        dbClosed = true;
        await db.close();
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets('KnowledgeItemReaderDialog exibe botao dedicado Exportar PDF', (
      tester,
    ) async {
      var exportedPdf = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KnowledgeItemReaderDialog(
              title: 'Estudo Temático',
              content: 'Texto de leitura.',
              category: 'Geral',
              itemType: 'Nota',
              onExportPdf: () async {
                exportedPdf = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pdfBtn = find.byKey(const Key('btn_reader_export_pdf'));
      expect(pdfBtn, findsOneWidget);
      await tester.tap(pdfBtn);
      await tester.pumpAndSettle();

      expect(exportedPdf, isTrue);
    });

    testWidgets(
      'KnowledgeBaseScreen exibe botao Exportar PDF em todas as 5 abas e na tela de Cartas & Atas',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final repo = AppRepository(db);
        var dbClosed = false;
        addTearDown(() async {
          if (!dbClosed) {
            await db.close();
          }
        });

        final km = KnowledgeManager(db: db);
        await km.createNote(
          title: 'Nota Teste PDF',
          content: 'Corpo da nota para teste de exportação com [📖 Mateus 7:12 (TNM)](app://ref/bible/40/7/12).',
        );
        await km.createQuestion(question: 'Dúvida Teste PDF');
        await km.registerDocument(
          title: 'Manual de Campo PDF',
          fileName: 'manual.pdf',
          filePath: 'mem://manual.pdf',
          fileType: 'pdf',
          fileSize: 2048,
          category: 'manual',
        );
        await km.createResource(
          title: 'Estudo Bíblico JW',
          url: 'https://www.jw.org/pt/',
          resourceType: 'jw_pub',
          description: 'Artigo de apoio para revisitas.',
        );

        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
            ],
            child: const MaterialApp(
              home: KnowledgeBaseScreen(initialTabIndex: 0),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Aba 0: Notas (card moderno + painel editorial com referências citadas e botão PDF)
        expect(find.byKey(const Key('btn_kb_export_tab_pdf')), findsOneWidget);
        expect(find.byType(KnowledgeNoteListCard), findsOneWidget);
        await tester.tap(find.text('Nota Teste PDF').first);
        await tester.pumpAndSettle();
        expect(find.byType(KnowledgeNoteDetailPane), findsOneWidget);
        expect(
          find.textContaining('REFERÊNCIAS E LINKS CITADOS'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('btn_note_detail_export_pdf')),
          findsOneWidget,
        );

        // Aba 1: Perguntas & Dúvidas
        await tester.tap(find.text('❓ Perguntas & Dúvidas'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('btn_kb_export_tab_pdf')), findsOneWidget);
        expect(find.byType(KnowledgeQuestionCard), findsOneWidget);

        // Aba 2: Documentos
        await tester.tap(find.text('📁 Documentos'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('btn_kb_export_tab_pdf')), findsOneWidget);
        expect(find.byType(KnowledgeDocumentCard), findsOneWidget);

        // Aba 3: Recursos
        await tester.tap(find.text('🔗 Recursos'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('btn_kb_export_tab_pdf')), findsOneWidget);
        expect(find.byType(KnowledgeResourceCard), findsOneWidget);
        expect(find.text('jw.org'), findsOneWidget);

        // Aba 4: Cartas & Atas (também exibe botão rápido na barra de documentos oficiais)
        await tester.tap(find.text('✉️ Cartas & Atas'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('btn_kb_export_tab_pdf')), findsOneWidget);
        expect(
          find.byKey(const Key('btn_official_doc_quick_pdf')),
          findsOneWidget,
        );

        // OfficialDocumentsScreen avulsa também exibe botão rápido PDF
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
            ],
            child: const MaterialApp(home: OfficialDocumentsScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('btn_official_doc_quick_pdf')),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        dbClosed = true;
        await db.close();
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'Base de Conhecimento renderiza cards modernos em modo escuro mobile (390px) sem overflow',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final repo = AppRepository(db);
        var dbClosed = false;
        addTearDown(() async {
          if (!dbClosed) {
            await db.close();
          }
        });

        final km = KnowledgeManager(db: db);
        await km.createNote(
          title: 'Nota Mobile Longa de Estudo Temático',
          content: 'Texto com [📖 João 3:16 (TNM)](app://ref/bible/43/3/16)',
          tags: const ['pregacao'],
        );
        await km.createQuestion(
          question: 'Como responder sobre esperança bíblica em visita rápida?',
        );
        await km.registerDocument(
          title: 'Guia de Estudo Completo em PDF',
          fileName: 'guia_estudo_completo.pdf',
          filePath: 'mem://guia.pdf',
          fileType: 'pdf',
          fileSize: 4096,
          category: 'study',
        );
        await km.createResource(
          title: 'Artigo Oficial de Apoio',
          url: 'https://www.jw.org/pt/ensinos-biblicos/',
          resourceType: 'jw_pub',
          description: 'Material de referência.',
        );

        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
            ],
            child: MaterialApp(
              themeMode: ThemeMode.dark,
              darkTheme: ThemeData.dark(),
              home: const KnowledgeBaseScreen(initialTabIndex: 0),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(KnowledgeNoteListCard), findsOneWidget);

        await tester.ensureVisible(find.text('❓ Perguntas & Dúvidas'));
        await tester.tap(find.text('❓ Perguntas & Dúvidas'));
        await tester.pumpAndSettle();
        expect(find.byType(KnowledgeQuestionCard), findsOneWidget);

        await tester.ensureVisible(find.text('📁 Documentos'));
        await tester.tap(find.text('📁 Documentos'));
        await tester.pumpAndSettle();
        expect(find.byType(KnowledgeDocumentCard), findsOneWidget);

        await tester.ensureVisible(find.text('🔗 Recursos'));
        await tester.tap(find.text('🔗 Recursos'));
        await tester.pumpAndSettle();
        expect(find.byType(KnowledgeResourceCard), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        dbClosed = true;
        await db.close();
        await tester.pump(const Duration(milliseconds: 100));
      },
    );
  });
}
