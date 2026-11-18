import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/screens/people_screen.dart';
import 'package:ministerio_pessoal/ui/screens/person_detail_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PeopleScreen Adaptive Layout & Master-Detail Tests (FA-UX-01)', () {
    final now = DateTime.now();

    testWidgets(
      'TC-UX-01: Layout móvel (<900px) exibe lista única sem divider de split',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = AppRepository(db);

        await repo.createPerson(
          name: 'Maria Silva',
          status: 'interessado',
          firstContactAt: now,
        );
        await repo.createPerson(
          name: 'João Souza',
          status: 'revisita',
          firstContactAt: now,
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
            child: const MaterialApp(home: PeopleScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Maria Silva'), findsOneWidget);
        expect(find.text('João Souza'), findsOneWidget);

        // No modo móvel, não existe VerticalDivider de split
        expect(find.byType(VerticalDivider), findsNothing);
        expect(
          find.text('Selecione um contato para visualizar detalhes'),
          findsNothing,
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'TC-UX-02: Layout iPad (>=900px) exibe Split View master-detail com seleção',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = AppRepository(db);

        await repo.createPerson(
          name: 'Maria Silva',
          status: 'interessado',
          firstContactAt: now,
        );
        await repo.createPerson(
          name: 'João Souza',
          status: 'revisita',
          firstContactAt: now,
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
            child: const MaterialApp(home: PeopleScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // No modo iPad, VerticalDivider e placeholder estão presentes
        expect(find.byType(VerticalDivider), findsOneWidget);
        expect(
          find.text('Selecione um contato para visualizar detalhes'),
          findsOneWidget,
        );
        expect(find.byType(PersonDetailScreen), findsNothing);

        // Tocar no card de Maria Silva seleciona o contato e renderiza o detalhe no painel direito
        await tester.tap(find.text('Maria Silva'));
        await tester.pumpAndSettle();

        expect(find.byType(PersonDetailScreen), findsOneWidget);
        expect(
          find.text('Selecione um contato para visualizar detalhes'),
          findsNothing,
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  });
}
