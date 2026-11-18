import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/core/biometric_auth_service.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/inbox/inbox_manager.dart';
import 'package:ministerio_pessoal/knowledge/knowledge_manager.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/screens/inbox_screen.dart';
import 'package:ministerio_pessoal/ui/screens/knowledge_base_screen.dart';
import 'package:ministerio_pessoal/ui/screens/studies_screen.dart';
import 'package:ministerio_pessoal/ui/widgets/studies/study_detail_pane.dart';

class _AlwaysUnlockedBiometricService extends BiometricAuthService {
  @override
  bool get isSessionUnlocked => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('iPadOS Adaptive Master-Detail Layout Tests (P2-01 / P2-03)', () {
    testWidgets(
      'StudiesScreen uses single-column on iPhone (390px) and Master-Detail Split View on iPad (1024px)',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = AppRepository(db);

        final person = await repo.createPerson(
          name: 'Mateus Oliveira',
          status: 'estudo',
          firstContactAt: DateTime.now(),
        );
        await repo.createStudy(
          title: 'Estudo com Mateus',
          publicationId: 'lff',
          participantPersonIds: [person.id],
          currentLesson: 5,
        );

        // Mobile viewport (<900px)
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
            child: const MaterialApp(home: StudiesScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(VerticalDivider), findsNothing);
        expect(find.byType(StudyDetailPane), findsNothing);

        // Tablet / iPad viewport (>=900px)
        tester.view.physicalSize = const Size(1024, 768);
        await tester.pumpAndSettle();

        expect(find.byType(VerticalDivider), findsOneWidget);
        expect(
          find.text('Selecione um estudo bíblico para visualizar detalhes'),
          findsOneWidget,
        );

        // Selecting a study renders StudyDetailPane on the right pane
        await tester.tap(find.text('Estudo com Mateus'));
        await tester.pumpAndSettle();

        expect(find.byType(StudyDetailPane), findsOneWidget);
        expect(find.text('Progresso do Estudo'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 50));
      },
    );

    testWidgets(
      'KnowledgeBaseScreen renders Master-Detail Notes split view on iPad (1024px) and single column on iPhone (390px)',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = AppRepository(db);
        final km = KnowledgeManager(db: db);

        await km.createNote(
          title: 'Resumo de Salmos 83',
          content: 'Conteúdo detalhado da nota pastoral para leitura no iPad.',
          category: 'Pesquisa Bíblica',
        );

        // Mobile (<900px)
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
            child: const MaterialApp(home: KnowledgeBaseScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(VerticalDivider), findsNothing);

        // iPad (>=900px)
        tester.view.physicalSize = const Size(1024, 768);
        await tester.pumpAndSettle();

        expect(find.byType(VerticalDivider), findsOneWidget);
        expect(
          find.text('Selecione uma nota para leitura completa'),
          findsOneWidget,
        );

        await tester.tap(find.text('Resumo de Salmos 83'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Conteúdo detalhado da nota pastoral para leitura no iPad.',
          ),
          findsWidgets,
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 50));
      },
    );

    testWidgets(
      'InboxScreen renders Master-Detail Captures split view on iPad (1024px) and single column on iPhone (390px)',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = AppRepository(db);
        final inboxMgr = InboxManager(db: db);

        await inboxMgr.captureText(
          content: 'Lembrar de levar brochura para Dona Rosa na quinta-feira',
        );

        // Mobile (<900px)
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
              biometricAuthServiceProvider.overrideWithValue(
                _AlwaysUnlockedBiometricService(),
              ),
            ],
            child: const MaterialApp(home: InboxScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(VerticalDivider), findsNothing);

        // iPad (>=900px)
        tester.view.physicalSize = const Size(1024, 768);
        await tester.pumpAndSettle();

        expect(find.byType(VerticalDivider), findsOneWidget);
        expect(
          find.text('Selecione uma captura para visualizar detalhes'),
          findsOneWidget,
        );

        await tester.tap(
          find.text('Lembrar de levar brochura para Dona Rosa na quinta-feira'),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Selecione uma captura para visualizar detalhes'),
          findsNothing,
        );
        expect(find.textContaining('Detalhe da Captura'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 50));
      },
    );
  });
}
