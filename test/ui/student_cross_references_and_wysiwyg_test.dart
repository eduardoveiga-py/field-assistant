import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/contacts/doorstep_briefing_helper.dart';
import 'package:ministerio_pessoal/contacts/person_hand_off_helper.dart'
    as foreign_handoff;
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/reports/report_export_service.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/screens/person_detail_screen.dart';
import 'package:ministerio_pessoal/ui/screens/studies_screen.dart';
import 'package:ministerio_pessoal/ui/widgets/add_person_dialog.dart';
import 'package:ministerio_pessoal/ui/widgets/doorstep_briefing_card.dart';
import 'package:ministerio_pessoal/ui/widgets/markdown_preview_text.dart';
import 'package:ministerio_pessoal/ui/widgets/person_hand_off_dialog.dart';
import 'package:ministerio_pessoal/ui/widgets/rich_formatted_editing_controller.dart';
import 'package:ministerio_pessoal/ui/widgets/rich_markdown_toolbar.dart';

void main() {
  group('Referências do App e Formatação WYSIWYG em Estudantes/Revisitas', () {
    test('DoorstepBriefingHelper, PersonHandOffHelper e ReportExportService limpam Markdown, links app:// e JSON', () {
      final notesJson = jsonEncode([
        {
          'id': 'n1',
          'text': '**Urgente:** reler [📖 Apocalipse 1:1 (TNM)](app://ref/bible/66/1/1) e <u style="color:#EAB308">meditar</u>',
          'createdAt': '2026-10-15T10:00:00.000Z',
        },
      ]);

      final plain = DoorstepBriefingHelper.extractPlainNotesSummary(notesJson);
      expect(plain, contains('Urgente: reler 📖 Apocalipse 1:1 (TNM)'));
      expect(plain, isNot(contains('**')));
      expect(plain, isNot(contains('app://')));
      expect(plain, isNot(contains('<u')));
      expect(plain, isNot(contains('"id"')));

      final person = PersonEntry(
        id: 'p-1',
        name: 'Maria Clara',
        firstContactAt: DateTime(2026, 10, 1),
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 15),
        status: 'revisita',
        generalNotes: notesJson,
        nextActionNote:
            'Recapitular [📖 João 3:16 (TNM)](app://ref/bible/43/3/16)',
        tags: '[]',
        revision: 1,
      );

      final handoffMsg = PersonHandOffHelper.generateMessage(person: person);
      expect(handoffMsg, contains('Urgente: reler 📖 Apocalipse 1:1 (TNM)'));
      expect(handoffMsg, contains('Recapitular 📖 João 3:16 (TNM)'));
      expect(handoffMsg, isNot(contains('app://')));
      expect(handoffMsg, isNot(contains('**Urgente:**')));

      final foreignMsg =
          foreign_handoff.PersonHandOffHelper.formatHandOffMessage(
            person: person,
            additionalNotes: '**Obs:** ver [📝 Nota](app://ref/note/abc)',
          );
      expect(foreignMsg, contains('Urgente: reler 📖 Apocalipse 1:1 (TNM)'));
      expect(foreignMsg, contains('Obs: ver 📝 Nota'));
      expect(foreignMsg, isNot(contains('app://')));

      final csv = ReportExportService.generateCsvForContacts([person]);
      expect(csv, contains('Urgente: reler 📖 Apocalipse 1:1 (TNM)'));
      expect(csv, isNot(contains('app://')));
      expect(csv, isNot(contains('"id"')));
    });

    testWidgets(
      'RichMarkdownToolbar para estudantes/revisitas expõe referências e oculta gravuras e cores JW sem sintaxe crua',
      (tester) async {
        final ctrl = RichFormattedEditingController.fromMarkup(
          'Conversar sobre **esperança** em [📖 Apocalipse 1:1 (TNM)](app://ref/bible/66/1/1)',
        );
        addTearDown(ctrl.dispose);

        expect(
          ctrl.text,
          equals('Conversar sobre esperança em 📖 Apocalipse 1:1 (TNM)'),
        );
        expect(ctrl.text, isNot(contains('**')));
        expect(ctrl.text, isNot(contains('app://')));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  RichMarkdownToolbar(
                    controller: ctrl,
                    enableHighlightPalette: false,
                    enableImagePicker: false,
                    enableCrossReferences: true,
                  ),
                  TextField(controller: ctrl),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('btn_toolbar_insert_bible')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('btn_toolbar_insert_ref')), findsOneWidget);
        expect(
          find.byKey(const Key('btn_toolbar_highlight_color')),
          findsNothing,
        );
        expect(find.byKey(const Key('btn_toolbar_insert_image')), findsNothing);
        expect(
          RichFormattedEditingController.readMarkup(ctrl),
          equals(
            'Conversar sobre **esperança** em [📖 Apocalipse 1:1 (TNM)](app://ref/bible/66/1/1)',
          ),
        );
      },
    );

    testWidgets(
      'DoorstepBriefingCard renderiza notas formatadas e referências via MarkdownPreviewText sem sintaxe bruta',
      (tester) async {
        const data = DoorstepBriefingData(
          lessonAndPoint:
              'Lição 02 — [📖 Apocalipse 21:4 (TNM)](app://ref/bible/66/21/4)',
          pendingDoubt: '**Dúvida:** [❓ Pergunta](app://ref/question/q-1)',
          spiritualGoal:
              'Ler [📖 Salmos 37:11 (TNM)](app://ref/bible/19/37/11)',
          empathyNote: '**Família** receptiva com **visitas**',
        );

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: DoorstepBriefingCard(data: data),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MarkdownPreviewText), findsAtLeastNWidgets(4));
        expect(find.textContaining('app://'), findsNothing);
        expect(find.textContaining('**Dúvida:**'), findsNothing);
        expect(find.textContaining('📖 Apocalipse 21:4 (TNM)'), findsOneWidget);
        expect(find.textContaining('❓ Pergunta'), findsOneWidget);
      },
    );

    testWidgets(
      'showAddPersonDialog inclui toolbar WYSIWYG com referências (sem gravuras/cores) e salva markup',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = AppRepository(db);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) => ElevatedButton(
                    onPressed: () => showAddPersonDialog(context, ref),
                    child: const Text('Abrir Novo Contato'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir Novo Contato'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('btn_toolbar_insert_bible')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('btn_toolbar_insert_ref')), findsOneWidget);
        expect(
          find.byKey(const Key('btn_toolbar_highlight_color')),
          findsNothing,
        );
        expect(find.byKey(const Key('btn_toolbar_insert_image')), findsNothing);

        await tester.enterText(
          find.widgetWithText(
            TextField,
            'Nome completo ou como é conhecido(a) *',
          ),
          'Lucas Oliveira',
        );
        await tester.enterText(
          find.widgetWithText(
            TextField,
            'Observações, necessidades e assuntos de interesse',
          ),
          'Interessado na Biblia',
        );

        await tester.ensureVisible(find.text('Salvar'));
        await tester.tap(find.text('Salvar'));
        await tester.pumpAndSettle();

        final people = await repo.getAllPeople();
        expect(people.any((p) => p.name == 'Lucas Oliveira'), isTrue);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'PersonDetailScreen exibe notas e sessões via MarkdownPreviewText e abre diálogo de nota com referências isolado',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = AppRepository(db);
        final now = DateTime(2026, 10, 15, 9, 30);

        final person = await repo.createPerson(
          name: 'Ana Revisita',
          status: 'revisita',
          firstContactAt: now,
          generalNotes: jsonEncode([
            {
              'id': 'note-1',
              'text': '**Observação:** revisar [📖 João 3:16 (TNM)](app://ref/bible/43/3/16)',
              'createdAt': now.toIso8601String(),
            },
          ]),
        );

        tester.view.physicalSize = const Size(1024, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
            ],
            child: MaterialApp(home: PersonDetailScreen(personId: person.id)),
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Necessidades & Obs.'));
        await tester.tap(find.text('Necessidades & Obs.'));
        await tester.pumpAndSettle();

        expect(find.byType(MarkdownPreviewText), findsAtLeastNWidgets(1));
        expect(find.textContaining('app://'), findsNothing);
        expect(find.textContaining('**Observação:**'), findsNothing);

        await tester.ensureVisible(find.text('+ Nova Observação'));
        await tester.tap(find.text('+ Nova Observação'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('btn_toolbar_insert_bible')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('btn_toolbar_insert_ref')), findsOneWidget);
        expect(
          find.byKey(const Key('btn_toolbar_highlight_color')),
          findsNothing,
        );
        expect(find.byKey(const Key('btn_toolbar_insert_image')), findsNothing);

        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'StudiesScreen exibe lições/subtópicos reais da brochura lffi e toolbar WYSIWYG com referências ao registrar sessão',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = AppRepository(db);
        final now = DateTime(2026, 10, 15, 10, 0);

        final person = await repo.createPerson(
          name: 'Marcos Brochura',
          status: 'estudo',
          firstContactAt: now,
        );
        await repo.createStudy(
          title: 'Estudo na Brochura LFFI',
          publicationId: 'lff-brochure',
          participantPersonIds: [person.id],
          currentLesson: 2,
          currentParagraph: 1,
        );

        tester.view.physicalSize = const Size(1100, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
            ],
            child: const MaterialApp(home: StudiesScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Estudo na Brochura LFFI'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Registrar Sessão'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Progresso (lffi):'), findsOneWidget);
        expect(find.text('1. Que esperança a Bíblia nos dá?'), findsOneWidget);
        expect(
          find.byKey(const Key('btn_toolbar_insert_bible')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('btn_toolbar_insert_ref')), findsOneWidget);
        expect(
          find.byKey(const Key('btn_toolbar_highlight_color')),
          findsNothing,
        );
        expect(find.byKey(const Key('btn_toolbar_insert_image')), findsNothing);
        expect(
          find.byIcon(Icons.bookmark_add_outlined),
          findsAtLeastNWidgets(2),
        );

        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  });
}
