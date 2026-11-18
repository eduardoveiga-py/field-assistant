import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/screens/studies_screen.dart';
import 'package:ministerio_pessoal/ui/widgets/studies/study_detail_pane.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StudiesScreen Adaptive Layout & Master-Detail Tests (FA-UX-03)', () {
    final now = DateTime.now();

    testWidgets(
      'TC-STUDIES-01: Layout móvel (<900px) exibe lista única sem divider de split',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = AppRepository(db);

        final person = await repo.createPerson(
          name: 'Ana Pereira',
          status: 'estudo',
          firstContactAt: now,
        );

        await repo.createStudy(
          title: 'Estudo Bíblico com Ana',
          publicationId: 'lff',
          participantPersonIds: [person.id],
          currentLesson: 3,
        );

        tester.view.physicalSize = const Size(400, 800);
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

        expect(find.text('Estudo Bíblico com Ana'), findsOneWidget);

        // No modo móvel, não existe VerticalDivider de split nem StudyDetailPane
        expect(find.byType(VerticalDivider), findsNothing);
        expect(find.byType(StudyDetailPane), findsNothing);
        expect(
          find.text('Selecione um estudo bíblico para visualizar detalhes'),
          findsNothing,
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'TC-STUDIES-02: Layout iPad (>=900px) exibe Split View master-detail com placeholder',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = AppRepository(db);

        final person = await repo.createPerson(
          name: 'Ana Pereira',
          status: 'estudo',
          firstContactAt: now,
        );

        await repo.createStudy(
          title: 'Estudo Bíblico com Ana',
          publicationId: 'lff',
          participantPersonIds: [person.id],
          currentLesson: 3,
        );

        tester.view.physicalSize = const Size(1024, 768);
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

        // No modo iPad, VerticalDivider e placeholder estão visíveis
        expect(find.byType(VerticalDivider), findsOneWidget);
        expect(
          find.text('Selecione um estudo bíblico para visualizar detalhes'),
          findsOneWidget,
        );
        expect(find.byType(StudyDetailPane), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'TC-STUDIES-03: Tocar no estudo bíblico seleciona e renderiza StudyDetailPane com progresso',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = AppRepository(db);

        final person = await repo.createPerson(
          name: 'Ana Pereira',
          status: 'estudo',
          firstContactAt: now,
        );

        await repo.createStudy(
          title: 'Estudo Bíblico com Ana',
          publicationId: 'lff',
          participantPersonIds: [person.id],
          currentLesson: 3,
        );

        tester.view.physicalSize = const Size(1024, 768);
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

        // Tocar no card do estudo para selecioná-lo
        await tester.tap(find.text('Estudo Bíblico com Ana'));
        await tester.pumpAndSettle();

        // Agora o StudyDetailPane deve estar renderizado
        expect(find.byType(StudyDetailPane), findsOneWidget);
        expect(
          find.text('Selecione um estudo bíblico para visualizar detalhes'),
          findsNothing,
        );
        expect(find.text('Registrar Sessão'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  });
}
