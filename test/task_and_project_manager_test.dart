import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/tasks/task_manager.dart';
import 'package:ministerio_pessoal/projects/project_manager.dart';

void main() {
  group('TaskManager & ProjectManager (Módulo B — Tarefas e Projetos)', () {
    late AppDatabase db;
    late TaskManager taskMgr;
    late ProjectManager projectMgr;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      taskMgr = TaskManager(db: db);
      projectMgr = ProjectManager(db: db);
    });

    tearDown(() async {
      await db.close();
    });

    test('TC-TSK-01: Criação e edição de tarefas simples', () async {
      final task = await taskMgr.createTask(
        title: 'Comprar folhetos e revistas',
        priority: 'high',
        category: 'ministry',
        dueDate: DateTime.now().add(const Duration(days: 2)),
      );

      expect(task.title, equals('Comprar folhetos e revistas'));
      expect(task.priority, equals('high'));
      expect(task.status, equals('todo'));

      await taskMgr.updateTask(task.id, title: 'Comprar revistas e folhetos atualizados');
      final tasks = await taskMgr.watchPendingTasks().first;
      expect(tasks.first.title, equals('Comprar revistas e folhetos atualizados'));
    });

    test('TC-TSK-02: Alternância de conclusão e contagem pendente', () async {
      final task = await taskMgr.createTask(title: 'Ligar para irmão Lucas');
      var count = await taskMgr.watchPendingTaskCount().first;
      expect(count, equals(1));

      await taskMgr.toggleTaskComplete(task.id, completed: true);
      count = await taskMgr.watchPendingTaskCount().first;
      expect(count, equals(0));

      final completed = await taskMgr.watchCompletedTasks().first;
      expect(completed.length, equals(1));
      expect(completed.first.status, equals('completed'));
    });

    test('TC-TSK-03: Recorrência automática semanal', () async {
      final baseDue = DateTime(2026, 11, 10, 14, 0);
      final task = await taskMgr.createTask(
        title: 'Reunião de estudo em família',
        recurrenceRule: 'weekly',
        dueDate: baseDue,
      );

      // Ao completar a tarefa recorrente, a próxima tarefa é gerada para +7 dias
      await taskMgr.toggleTaskComplete(task.id, completed: true);

      final allPending = await taskMgr.watchPendingTasks().first;
      expect(allPending.length, equals(1));
      final nextTask = allPending.first;
      expect(nextTask.title, equals('Reunião de estudo em família'));
      expect(nextTask.dueDate, equals(baseDue.add(const Duration(days: 7))));
    });

    test('TC-PRJ-01: Criação de projeto e cálculo reativo de progresso', () async {
      final project = await projectMgr.createProject(
        name: 'Campanha de Território Rural',
        objective: 'Trabalhar os 5 setores ribeirinhos',
        category: 'ministry',
      );

      expect(project.name, equals('Campanha de Território Rural'));
      expect(project.status, equals('planning'));

      // Cria 4 tarefas vinculadas ao projeto
      final t1 = await taskMgr.createTask(title: 'Mapear barco', projectId: project.id);
      final t2 = await taskMgr.createTask(title: 'Organizar pioneiros', projectId: project.id);
      final t3 = await taskMgr.createTask(title: 'Imprimir mapas', projectId: project.id);
      await taskMgr.createTask(title: 'Revisar combustível', projectId: project.id);

      var progress = await projectMgr.watchProjectProgress(project.id).first;
      expect(progress.totalTasks, equals(4));
      expect(progress.completedTasks, equals(0));
      expect(progress.progressPercent, equals(0.0));

      // Conclui 2 tarefas
      await taskMgr.toggleTaskComplete(t1.id, completed: true);
      await taskMgr.toggleTaskComplete(t2.id, completed: true);

      progress = await projectMgr.watchProjectProgress(project.id).first;
      expect(progress.totalTasks, equals(4));
      expect(progress.completedTasks, equals(2));
      expect(progress.progressPercent, equals(50.0));

      // Conclui a terceira tarefa
      await taskMgr.toggleTaskComplete(t3.id, completed: true);
      progress = await projectMgr.watchProjectProgress(project.id).first;
      expect(progress.completedTasks, equals(3));
      expect(progress.progressPercent, equals(75.0));
    });
  });
}
