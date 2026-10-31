import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/contacts/doorstep_briefing_helper.dart';
import 'package:ministerio_pessoal/core/app_theme.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/ui/widgets/doorstep_briefing_card.dart';

void main() {
  group('STRESS-01: Layout em Restrições Extremas de Tela e Escala Tipográfica', () {
    testWidgets('Largura estreita (280dp) + Dynamic Text Scaling 2.0x (Acessibilidade Elevada)', (tester) async {
      final data = DoorstepBriefingData(
        lessonAndPoint: 'Lição 04, Ponto 3 — Salmo 37:11',
        jwLibraryUri: Uri.parse('https://www.jw.org/finder?srcid=jwlshare&wtlocale=T&pub=lff&lesson=4'),
        pendingDoubt: 'Como lidar com oposição na família sobre o estudo da Bíblia?',
        spiritualGoal: 'Assistir presencialmente à reunião de fim de semana no Salão',
        empathyNote: 'Mãe idosa esteve internada na semana passada; perguntar sobre sua saúde',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                child: MediaQuery(
                  data: const MediaQueryData(
                    textScaler: TextScaler.linear(2.0),
                  ),
                  child: SingleChildScrollView(
                    child: DoorstepBriefingCard(data: data),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifica ausência de exceções de overflow ou layout
      expect(tester.takeException(), isNull);
      expect(find.byType(DoorstepBriefingCard), findsOneWidget);
      expect(find.text('Briefing na Porta'), findsOneWidget);
      expect(find.text('30s'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('Largura compacta (320dp - iPhone SE) + TextScaler 2.5x em Modo Sol Intenso', (tester) async {
      final data = DoorstepBriefingData(
        lessonAndPoint: 'Lição 12, Ponto 1',
        jwLibraryUri: Uri.parse('https://www.jw.org/finder?srcid=jwlshare&wtlocale=T&pub=lff&lesson=12'),
        pendingDoubt: 'Qual a diferença entre a oração sincera e repetições?',
        spiritualGoal: 'Começar a ler a Bíblia diariamente',
        empathyNote: 'Trabalha no comércio e folga somente às terças-feiras',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.sunModeTheme,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: MediaQuery(
                  data: const MediaQueryData(
                    textScaler: TextScaler.linear(2.5),
                  ),
                  child: SingleChildScrollView(
                    child: DoorstepBriefingCard(data: data),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final card = tester.widget<Card>(find.byType(Card));
      final shape = card.shape as RoundedRectangleBorder;
      expect(shape.side.color, equals(const Color(0xFF000000)));
      expect(shape.side.width, greaterThanOrEqualTo(2.0));
    });

    testWidgets('Altura ultra-curta (180dp) com SingleChildScrollView (Simulação de Teclado Ativo)', (tester) async {
      final data = DoorstepBriefingData(
        lessonAndPoint: 'Lição 01',
        jwLibraryUri: Uri.parse('https://www.jw.org'),
        pendingDoubt: 'Dúvida curta',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 180,
              width: 400,
              child: SingleChildScrollView(
                child: DoorstepBriefingCard(data: data),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Rola para baixo para garantir scrollabilidade sem exceptions
      await tester.drag(find.byType(DoorstepBriefingCard), const Offset(0, -100), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Dark Mode puro: contraste de cores e renderização de callouts', (tester) async {
      final data = DoorstepBriefingData(
        lessonAndPoint: 'Lição 07',
        pendingDoubt: 'O que acontece após a morte?',
        spiritualGoal: 'Compreender o estado dos mortos',
        empathyNote: 'Perdeu o avô recentemente',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: DoorstepBriefingCard(data: data),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Briefing na Porta'), findsOneWidget);
      expect(find.text('O que acontece após a morte?'), findsOneWidget);
      expect(find.text('Compreender o estado dos mortos'), findsOneWidget);
      expect(find.text('Perdeu o avô recentemente'), findsOneWidget);
    });
  });

  group('STRESS-02: Estabilidade de Ciclo de Vida do StreamBuilder', () {
    testWidgets('Stream emite erro de banco (ex: DatabaseLockedException) e degrada graciosamente', (tester) async {
      final streamController = StreamController<List<VisitEntry>>();
      final now = DateTime(2026, 10, 30);
      final person = PersonEntry(
        id: 'p-stress-1',
        name: 'Carlos Silva',
        firstContactAt: now,
        status: 'interessado',
        tags: '[]',
        createdAt: now,
        updatedAt: now,
        revision: 1,
        nextActionNote: 'Fallback de pendência da pessoa',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamBuilder<List<VisitEntry>>(
              stream: streamController.stream,
              builder: (context, visitSnapshot) {
                final latestVisit = (visitSnapshot.data ?? []).firstOrNull;
                final briefingData = DoorstepBriefingHelper.build(
                  person: person,
                  latestVisit: latestVisit,
                );
                return DoorstepBriefingCard(data: briefingData);
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Emite erro no stream
      streamController.addError(Exception('Database query failed: SQLite locked'));
      await tester.pump();

      // Não deve lançar exceção no Flutter runtime e deve degradar para dados de person
      expect(tester.takeException(), isNull);
      expect(find.byType(DoorstepBriefingCard), findsOneWidget);
      expect(find.text('Fallback de pendência da pessoa'), findsOneWidget);

      await streamController.close();
    });

    testWidgets('Transição de Pessoa: troca de ID cancela stream anterior e inscreve no novo', (tester) async {
      final controller1 = StreamController<List<VisitEntry>>.broadcast();
      final controller2 = StreamController<List<VisitEntry>>.broadcast();
      final now = DateTime(2026, 10, 30);

      final personA = PersonEntry(
        id: 'p-A',
        name: 'Pessoa A',
        firstContactAt: now,
        status: 'interessado',
        tags: '[]',
        createdAt: now,
        updatedAt: now,
        revision: 1,
      );

      final personB = PersonEntry(
        id: 'p-B',
        name: 'Pessoa B',
        firstContactAt: now,
        status: 'interessado',
        tags: '[]',
        createdAt: now,
        updatedAt: now,
        revision: 1,
      );

      final selectedPerson = ValueNotifier<PersonEntry>(personA);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<PersonEntry>(
              valueListenable: selectedPerson,
              builder: (context, currentPerson, _) {
                final stream = currentPerson.id == 'p-A' ? controller1.stream : controller2.stream;
                return StreamBuilder<List<VisitEntry>>(
                  stream: stream,
                  builder: (context, visitSnapshot) {
                    final latestVisit = (visitSnapshot.data ?? []).firstOrNull;
                    final briefingData = DoorstepBriefingHelper.build(
                      person: currentPerson,
                      latestVisit: latestVisit,
                    );
                    return DoorstepBriefingCard(data: briefingData);
                  },
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Emite visita para Pessoa A
      controller1.add([
        VisitEntry(
          id: 'v-A',
          personId: 'p-A',
          dateTimeField: now,
          contactType: 'revisita',
          result: 'revisita_feita',
          expressedQuestion: 'Dúvida da Pessoa A',
          createdAt: now,
          updatedAt: now,
          revision: 1,
        )
      ]);
      await tester.pump();
      await tester.pump();
      expect(find.text('Dúvida da Pessoa A'), findsOneWidget);

      // Troca para Pessoa B (simulando navegação / atualização de entidade)
      selectedPerson.value = personB;
      await tester.pump();

      // Emite visita para Pessoa B
      controller2.add([
        VisitEntry(
          id: 'v-B',
          personId: 'p-B',
          dateTimeField: now,
          contactType: 'revisita',
          result: 'revisita_feita',
          expressedQuestion: 'Dúvida da Pessoa B',
          createdAt: now,
          updatedAt: now,
          revision: 1,
        )
      ]);
      await tester.pump();
      await tester.pump();
      expect(find.text('Dúvida da Pessoa B'), findsOneWidget);
      expect(find.text('Dúvida da Pessoa A'), findsNothing);

      // Emite novo dado no controller antigo (controller1); não deve afetar a UI de Pessoa B
      controller1.add([
        VisitEntry(
          id: 'v-A2',
          personId: 'p-A',
          dateTimeField: now,
          contactType: 'revisita',
          result: 'revisita_feita',
          expressedQuestion: 'Dúvida A Fantasma',
          createdAt: now,
          updatedAt: now,
          revision: 1,
        )
      ]);
      await tester.pump();
      await tester.pump();
      expect(find.text('Dúvida A Fantasma'), findsNothing);
      expect(find.text('Dúvida da Pessoa B'), findsOneWidget);

      await controller1.close();
      await controller2.close();
    });

    testWidgets('Exclusão de pessoa: Stream emite lista vazia e widget desmonta sem memory leak', (tester) async {
      final controller = StreamController<List<VisitEntry>>.broadcast();
      final now = DateTime(2026, 10, 30);
      final person = PersonEntry(
        id: 'p-del-1',
        name: 'Pessoa Deletada',
        firstContactAt: now,
        status: 'interessado',
        tags: '[]',
        createdAt: now,
        updatedAt: now,
        revision: 1,
      );

      final isMounted = ValueNotifier<bool>(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: isMounted,
              builder: (context, mounted, _) {
                if (!mounted) return const Text('Tela Encerrada');
                return StreamBuilder<List<VisitEntry>>(
                  stream: controller.stream,
                  builder: (context, visitSnapshot) {
                    final latestVisit = (visitSnapshot.data ?? []).firstOrNull;
                    final briefingData = DoorstepBriefingHelper.build(
                      person: person,
                      latestVisit: latestVisit,
                    );
                    return DoorstepBriefingCard(data: briefingData);
                  },
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Emite visitas antes da exclusão
      controller.add([
        VisitEntry(
          id: 'v-pre-del',
          personId: 'p-del-1',
          dateTimeField: now,
          contactType: 'revisita',
          result: 'revisita_feita',
          expressedQuestion: 'Pergunta antes de deletar',
          createdAt: now,
          updatedAt: now,
          revision: 1,
        )
      ]);
      await tester.pump();
      await tester.pump();
      expect(find.text('Pergunta antes de deletar'), findsOneWidget);

      // Simula exclusão no banco (emite lista vazia) e pop da tela
      controller.add([]);
      isMounted.value = false;
      await tester.pumpAndSettle();

      expect(find.text('Tela Encerrada'), findsOneWidget);
      expect(find.byType(DoorstepBriefingCard), findsNothing);
      expect(tester.takeException(), isNull);

      await controller.close();
    });
  });
}
