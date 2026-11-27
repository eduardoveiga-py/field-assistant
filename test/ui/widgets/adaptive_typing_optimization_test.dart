import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/screens/knowledge_base_screen.dart';
import 'package:ministerio_pessoal/ui/widgets/adaptive_ministry_sheet.dart';
import 'package:ministerio_pessoal/ui/widgets/knowledge/second_brain_rich_editor.dart';
import 'package:ministerio_pessoal/ui/widgets/rich_formatted_editing_controller.dart';

void main() {
  group('Otimização Global de Digitação (iPhone, Android e iPad)', () {
    testWidgets(
      'showAdaptiveMinistrySheet adapta altura ao teclado virtual e alterna para tela cheia no iPhone e iPad',
      (tester) async {
        for (final viewport in const [Size(375, 667), Size(1024, 768)]) {
          tester.view.physicalSize = viewport;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: viewport,
                  viewInsets: const EdgeInsets.only(bottom: 290),
                ),
                child: Builder(
                  builder: (ctx) => Scaffold(
                    body: ElevatedButton(
                      onPressed: () => showAdaptiveMinistrySheet<void>(
                        context: ctx,
                        title: 'Editor Responsivo',
                        bottomBarBuilder: (bCtx) => ElevatedButton(
                          key: const Key('btn_test_fixed_save'),
                          onPressed: () => Navigator.pop(bCtx),
                          child: const Text('Salvar Fixo'),
                        ),
                        builder: (sCtx, _) => SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: SecondBrainRichEditor(
                            controller: RichFormattedEditingController(),
                            labelText: 'Conteúdo Principal',
                          ),
                        ),
                      ),
                      child: const Text('Abrir Modal'),
                    ),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('Abrir Modal'));
          await tester.pumpAndSettle();

          expect(find.text('Conteúdo Principal'), findsOneWidget);
          expect(find.byKey(const Key('btn_test_fixed_save')), findsOneWidget);
          expect(
            find.byKey(const Key('btn_sheet_fullscreen_toggle')),
            findsOneWidget,
          );

          await tester.tap(
            find.byKey(const Key('btn_sheet_fullscreen_toggle')),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          await tester.tap(find.byKey(const Key('btn_test_fixed_save')));
          await tester.pumpAndSettle();
        }
      },
    );

    testWidgets(
      'Modal Nova Nota prioriza Título + Editor de Conteúdo e recolhe propriedades no iPad com teclado',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: const MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(1024, 768),
                  viewInsets: EdgeInsets.only(bottom: 310),
                ),
                child: KnowledgeBaseScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        // Título, Capa, Editor e botão Salvar ficam acessíveis imediatamente, com Propriedades recolhidas
        expect(find.text('Título da Nota'), findsOneWidget);
        expect(find.text('Conteúdo da Nota'), findsOneWidget);
        expect(find.byKey(const Key('btn_note_form_save')), findsOneWidget);
        expect(
          find.byKey(const Key('note_form_metadata_section')),
          findsOneWidget,
        );
        expect(find.text('Incluir na Revisão Espaçada (SM-2)'), findsNothing);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );
  });
}
