import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/core/biometric_auth_service.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/experiences/experience_manager.dart';
import 'package:ministerio_pessoal/inbox/inbox_manager.dart';
import 'package:ministerio_pessoal/knowledge/knowledge_manager.dart';
import 'package:ministerio_pessoal/projects/project_manager.dart';
import 'package:ministerio_pessoal/tasks/task_manager.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/screens/experiences_screen.dart';
import 'package:ministerio_pessoal/ui/screens/inbox_screen.dart';
import 'package:ministerio_pessoal/ui/screens/knowledge_base_screen.dart';
import 'package:ministerio_pessoal/ui/screens/studies_screen.dart';
import 'package:ministerio_pessoal/ui/screens/tasks_screen.dart';

class _AlwaysUnlockedBiometricService extends BiometricAuthService {
  @override
  bool get isSessionUnlocked => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Visões Notion (Lista | Tabela | Kanban | Galeria) nos Módulos', () {
    testWidgets(
      'Base de Conhecimento suporta Tabela e Kanban drag-drop em Dúvidas, Tabela e Galeria em Documentos e Recursos',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({});
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);

        final km = KnowledgeManager(db: db);
        final q = await km.createQuestion(
          question: 'Por que Deus permite o sofrimento?',
          context: 'Pergunta de revisita',
        );
        await km.registerDocument(
          title: 'Guia de Campo PDF',
          fileName: 'guia.pdf',
          fileType: 'pdf',
          fileSize: 2048,
          filePath: 'guia.pdf',
        );
        await km.createResource(
          title: 'Artigo JW Consolo',
          resourceType: 'jw_article',
          url: 'https://www.jw.org/pt',
          description: 'Artigo de apoio para revisitas.',
        );

        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: const MaterialApp(
              home: KnowledgeBaseScreen(initialTabIndex: 1),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Dúvidas -> Tabela
        await tester.tap(find.byKey(const Key('questions_view_table')));
        await tester.pumpAndSettle();
        expect(find.text('Por que Deus permite o sofrimento?'), findsOneWidget);

        // Dúvidas -> Kanban e drag-and-drop para Respondidas
        await tester.tap(find.byKey(const Key('questions_view_kanban')));
        await tester.pumpAndSettle();
        final cardFinder = find.byKey(Key('questions_kanban_card_${q.id}'));
        final targetCol = find.byKey(
          const Key('questions_kanban_col_answered'),
        );
        expect(cardFinder, findsOneWidget);
        expect(targetCol, findsOneWidget);
        final delta =
            tester.getCenter(targetCol) - tester.getCenter(cardFinder);
        await tester.drag(cardFinder, delta);
        await tester.pumpAndSettle();

        final updatedQ = await (db.select(
          db.knowledgeQuestions,
        )..where((t) => t.id.equals(q.id))).getSingle();
        expect(updatedQ.status, equals('answered'));

        // Documentos -> Tabela & Galeria
        await tester.tap(find.text('📁 Documentos'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('docs_view_table')));
        await tester.pumpAndSettle();
        expect(find.text('Guia de Campo PDF'), findsOneWidget);
        await tester.tap(find.byKey(const Key('docs_view_gallery')));
        await tester.pumpAndSettle();
        expect(find.text('Guia de Campo PDF'), findsOneWidget);

        // Recursos -> Tabela & Galeria
        await tester.tap(find.text('🔗 Recursos'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('resources_view_table')));
        await tester.pumpAndSettle();
        expect(find.text('Artigo JW Consolo'), findsOneWidget);
        await tester.tap(find.byKey(const Key('resources_view_gallery')));
        await tester.pumpAndSettle();
        expect(find.text('Artigo JW Consolo'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'Tarefas & Projetos alternam Tabela/Kanban/Galeria e persistem status ao arrastar no Kanban',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);

        final taskMgr = TaskManager(db: db);
        final projMgr = ProjectManager(db: db);
        final task = await taskMgr.createTask(
          title: 'Preparar discurso especial',
        );
        final project = await projMgr.createProject(
          name: 'Campanha Memorial',
          status: 'active',
        );

        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: const MaterialApp(home: TasksScreen(initialTabIndex: 1)),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('tasks_view_table')));
        await tester.pumpAndSettle();
        expect(find.text('Preparar discurso especial'), findsOneWidget);

        await tester.tap(find.byKey(const Key('tasks_view_kanban')));
        await tester.pumpAndSettle();
        final taskCard = find.byKey(Key('tasks_kanban_card_${task.id}'));
        final completedCol = find.byKey(
          const Key('tasks_kanban_col_completed'),
        );
        await tester.drag(
          taskCard,
          tester.getCenter(completedCol) - tester.getCenter(taskCard),
        );
        await tester.pumpAndSettle();

        final updatedTask = await (db.select(
          db.tasks,
        )..where((t) => t.id.equals(task.id))).getSingle();
        expect(updatedTask.status, equals('completed'));
        expect(updatedTask.completedAt, isNotNull);

        // Aba Projetos -> Tabela, Galeria & Kanban drag para Pausado
        await tester.tap(find.text('📁 Projetos'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('projects_view_table')));
        await tester.pumpAndSettle();
        expect(find.text('Campanha Memorial'), findsOneWidget);
        await tester.tap(find.byKey(const Key('projects_view_gallery')));
        await tester.pumpAndSettle();
        expect(find.text('Campanha Memorial'), findsOneWidget);
        await tester.tap(find.byKey(const Key('projects_view_kanban')));
        await tester.pumpAndSettle();

        final projCard = find.byKey(Key('projects_kanban_card_${project.id}'));
        final pausedCol = find.byKey(const Key('projects_kanban_col_paused'));
        await tester.drag(
          projCard,
          tester.getCenter(pausedCol) - tester.getCenter(projCard),
        );
        await tester.pumpAndSettle();

        final updatedProj = await (db.select(
          db.projects,
        )..where((t) => t.id.equals(project.id))).getSingle();
        expect(updatedProj.status, equals('paused'));
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'Estudos Bíblicos, Inbox e Experiências suportam Tabela, Kanban drag-drop e Galeria sem perda de regras',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({});
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);

        final repo = AppRepository(db);
        final person = await repo.createPerson(
          name: 'Carlos Silva',
          status: 'estudo',
          firstContactAt: DateTime.now(),
        );
        final study = await repo.createStudy(
          title: 'Estudo da Família Silva',
          publicationId: 'lff',
          participantPersonIds: [person.id],
          currentLesson: 4,
        );
        final inboxMgr = InboxManager(db: db);
        final entry = await inboxMgr.captureText(
          content: 'Anotar revisita rua B',
        );
        final expMgr = ExperienceManager(db);
        await expMgr.addExperience(
          title: 'Conversa no ponto de ônibus',
          content: 'Deixamos o folheto sobre esperança.',
        );

        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Estudos
        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('scope_studies'),
            overrides: [
              databaseProvider.overrideWithValue(db),
              repositoryProvider.overrideWithValue(repo),
            ],
            child: const MaterialApp(home: StudiesScreen()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('studies_view_table')));
        await tester.pumpAndSettle();
        expect(find.text('Estudo da Família Silva'), findsOneWidget);
        await tester.tap(find.byKey(const Key('studies_view_gallery')));
        await tester.pumpAndSettle();
        expect(find.text('Estudo da Família Silva'), findsOneWidget);
        await tester.tap(find.byKey(const Key('studies_view_kanban')));
        await tester.pumpAndSettle();
        final studyCard = find.byKey(Key('studies_kanban_card_${study.id}'));
        final studyPausedCol = find.byKey(
          const Key('studies_kanban_col_pausado'),
        );
        await tester.drag(
          studyCard,
          tester.getCenter(studyPausedCol) - tester.getCenter(studyCard),
        );
        await tester.pumpAndSettle();
        final updatedStudy = await (db.select(
          db.bibleStudies,
        )..where((t) => t.id.equals(study.id))).getSingle();
        expect(updatedStudy.status, equals('pausado'));

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 50));

        // Inbox
        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('scope_inbox'),
            overrides: [
              databaseProvider.overrideWithValue(db),
              biometricAuthServiceProvider.overrideWithValue(
                _AlwaysUnlockedBiometricService(),
              ),
            ],
            child: const MaterialApp(home: InboxScreen()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('inbox_view_table')));
        await tester.pumpAndSettle();
        expect(find.text('Anotar revisita rua B'), findsOneWidget);
        await tester.tap(find.byKey(const Key('inbox_view_kanban')));
        await tester.pumpAndSettle();
        final inboxCard = find.byKey(Key('inbox_kanban_card_${entry.id}'));
        final reviewCol = find.byKey(const Key('inbox_kanban_col_in_review'));
        await tester.drag(
          inboxCard,
          tester.getCenter(reviewCol) - tester.getCenter(inboxCard),
        );
        await tester.pumpAndSettle();
        final updatedEntry = await (db.select(
          db.inboxEntries,
        )..where((t) => t.id.equals(entry.id))).getSingle();
        expect(updatedEntry.status, equals('in_review'));

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 50));

        // Experiências
        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('scope_experiences'),
            overrides: [databaseProvider.overrideWithValue(db)],
            child: const MaterialApp(home: ExperiencesScreen()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('experiences_view_table')));
        await tester.pumpAndSettle();
        expect(find.text('Conversa no ponto de ônibus'), findsOneWidget);
        await tester.tap(find.byKey(const Key('experiences_view_gallery')));
        await tester.pumpAndSettle();
        expect(find.text('Conversa no ponto de ônibus'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );
  });
}
