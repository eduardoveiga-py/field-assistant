import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/core/biometric_auth_service.dart';
import 'package:ministerio_pessoal/inbox/jw_email_service.dart';
import 'package:ministerio_pessoal/knowledge/knowledge_manager.dart';
import 'package:ministerio_pessoal/research/research_manager.dart';
import 'package:ministerio_pessoal/ui/screens/appointments_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('General Calendar - Task and Project Deadlines Integration', () {
    final now = DateTime(2026, 11, 10, 10, 0);

    test('isMinistryAppointment does not count tasks or projects toward ministry hours', () {
      final ministryAppt = AppointmentEntry(
        id: 'appt_01',
        title: 'Revisita Sr. Carlos',
        startTime: now,
        endTime: now.add(const Duration(minutes: 45)),
        durationMinutes: 45,
        status: 'agendado',
        isProvisional: false,
        createdAt: now,
        updatedAt: now,
        revision: 1,
      );

      final taskAppt = AppointmentEntry(
        id: 'task:task_99',
        title: '📋 Preparar designação de oração',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        durationMinutes: 60,
        status: 'planejado',
        isProvisional: false,
        createdAt: now,
        updatedAt: now,
        revision: 1,
      );

      final projectAppt = AppointmentEntry(
        id: 'project:proj_88',
        title: '🎯 Manutenção do Salão do Reino',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        durationMinutes: 60,
        status: 'planejado',
        isProvisional: false,
        createdAt: now,
        updatedAt: now,
        revision: 1,
      );

      expect(AppointmentsScreen.isMinistryAppointment(ministryAppt), isTrue);
      expect(AppointmentsScreen.isMinistryAppointment(taskAppt), isFalse);
      expect(AppointmentsScreen.isMinistryAppointment(projectAppt), isFalse);
    });

    test('projectTasksAndProjectsToAppointments projects active tasks and projects with time awareness', () {
      final taskWithHour = TaskEntry(
        id: 't_hour',
        title: 'Ligar para interessado',
        priority: 'high',
        category: 'ministry',
        status: 'todo',
        dueDate: DateTime(2026, 11, 12, 14, 30),
        attachments: '[]',
        isRecurring: false,
        metadata: '{}',
        createdAt: now,
        updatedAt: now,
        revision: 1,
      );

      final taskDateOnly = TaskEntry(
        id: 't_date_only',
        title: 'Comprar materiais',
        priority: 'normal',
        category: 'personal',
        status: 'todo',
        dueDate: DateTime(2026, 11, 13),
        attachments: '[]',
        isRecurring: false,
        metadata: '{}',
        createdAt: now,
        updatedAt: now,
        revision: 1,
      );

      final completedTask = TaskEntry(
        id: 't_done',
        title: 'Tarefa concluída',
        priority: 'normal',
        category: 'ministry',
        status: 'completed',
        dueDate: DateTime(2026, 11, 14),
        attachments: '[]',
        isRecurring: false,
        metadata: '{}',
        createdAt: now,
        updatedAt: now,
        revision: 1,
      );

      final taskNoDueDate = TaskEntry(
        id: 't_no_due',
        title: 'Sem prazo',
        priority: 'low',
        category: 'ministry',
        status: 'todo',
        dueDate: null,
        attachments: '[]',
        isRecurring: false,
        metadata: '{}',
        createdAt: now,
        updatedAt: now,
        revision: 1,
      );

      final projectWithHour = ProjectEntry(
        id: 'p_hour',
        name: 'Campanha Especial',
        category: 'ministry',
        status: 'active',
        targetDate: DateTime(2026, 11, 20, 16, 0),
        metadata: '{}',
        createdAt: now,
        updatedAt: now,
        revision: 1,
      );

      final projectDateOnly = ProjectEntry(
        id: 'p_date_only',
        name: 'Reforma do Balcão',
        category: 'personal',
        status: 'active',
        targetDate: DateTime(2026, 11, 25),
        metadata: '{}',
        createdAt: now,
        updatedAt: now,
        revision: 1,
      );

      final completedProject = ProjectEntry(
        id: 'p_done',
        name: 'Projeto finalizado',
        category: 'ministry',
        status: 'completed',
        targetDate: DateTime(2026, 11, 15),
        metadata: '{}',
        createdAt: now,
        updatedAt: now,
        revision: 1,
      );

      final projected = AppointmentsScreen.projectTasksAndProjectsToAppointments(
        [],
        [taskWithHour, taskDateOnly, completedTask, taskNoDueDate],
        [projectWithHour, projectDateOnly, completedProject],
      );

      // Should only include active items with due/target dates: 2 tasks + 2 projects = 4
      expect(projected.length, equals(4));

      final projTaskHour = projected.firstWhere((a) => a.id == 'task:t_hour');
      expect(projTaskHour.startTime, equals(DateTime(2026, 11, 12, 14, 30)));
      expect(projTaskHour.endTime, equals(DateTime(2026, 11, 12, 15, 30)));

      final projTaskDateOnly = projected.firstWhere((a) => a.id == 'task:t_date_only');
      expect(projTaskDateOnly.startTime, equals(DateTime(2026, 11, 13, 9, 0)));
      expect(projTaskDateOnly.endTime, equals(DateTime(2026, 11, 13, 10, 0)));

      final projProjectHour = projected.firstWhere((a) => a.id == 'project:p_hour');
      expect(projProjectHour.startTime, equals(DateTime(2026, 11, 20, 16, 0)));

      final projProjectDateOnly = projected.firstWhere((a) => a.id == 'project:p_date_only');
      expect(projProjectDateOnly.startTime, equals(DateTime(2026, 11, 25, 10, 0)));
    });
  });

  group('JW.org Email & Permanent Retention Engine', () {
    late AppDatabase db;
    late BiometricAuthService biometricAuth;
    late JwEmailService emailService;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      biometricAuth = BiometricAuthService();
      emailService = JwEmailService(db: db, biometricAuth: biometricAuth);
    });

    tearDown(() async {
      await db.close();
    });

    test('Sync saves messages locally in Drift with permanent retention flag', () async {
      final initialCount = await emailService.syncEmails();
      expect(initialCount, greaterThan(0));

      final retained = await emailService.watchRetainedEmails().first;
      expect(retained.length, equals(initialCount));

      final first = retained.first;
      expect(first.isPermanentRetained, isTrue);
      expect(first.subject, isNotEmpty);
      expect(first.from, isNotEmpty);

      // Re-running sync is idempotent and does not create duplicates
      final secondSyncCount = await emailService.syncEmails();
      expect(secondSyncCount, equals(0));
    });

    test('Hub communications filter correctly and retain restricted metadata', () async {
      await emailService.syncEmails();

      final hubMessages = await emailService.watchRetainedEmails(hubOnly: true).first;
      expect(hubMessages, isNotEmpty);
      for (final msg in hubMessages) {
        expect(msg.isHubCommunication, isTrue);
        expect(msg.hubType, isNotNull);
      }
    });

    test('Dynamic Export generates compliant Markdown, EML (RFC822) and Plain Text', () async {
      final msg = JwEmailMessage(
        id: 'test_msg_01',
        remoteUid: 555,
        subject: 'Designação para a Reunião de Meio de Semana',
        from: 'secretaria@jw.org',
        to: 'publicador@jw.org',
        date: DateTime(2026, 11, 15, 19, 30),
        bodyText: 'Irmão, você foi designado para o Discurso nº 2 sobre os atributos de Jeová.',
        tags: ['reunião', 'discurso', 'vida_e_ministerio'],
        attachments: [
          {'name': 'Esboco_Discurso.pdf', 'size': 102400}
        ],
      );

      // Test Markdown export
      final md = await emailService.exportEmail(msg, format: 'markdown');
      expect(md, contains('# Designação para a Reunião de Meio de Semana'));
      expect(md, contains('secretaria@jw.org'));
      expect(md, contains('`#discurso`'));
      expect(md, contains('Esboco_Discurso.pdf'));

      // Test EML (RFC822) export
      final eml = await emailService.exportEmail(msg, format: 'eml');
      expect(eml, contains('From: secretaria@jw.org'));
      expect(eml, contains('To: publicador@jw.org'));
      expect(eml, contains('Subject: Designação para a Reunião de Meio de Semana'));
      expect(eml, contains('X-JW-Retained: Permanent'));
      expect(eml, contains('MIME-Version: 1.0'));

      // Test Plain Text export
      final txt = await emailService.exportEmail(msg, format: 'text');
      expect(txt, contains('ASSUNTO: Designação para a Reunião de Meio de Semana'));
      expect(txt, contains('DE: secretaria@jw.org'));
    });

    test('Draft teocratic email persists locally in permanent retention', () async {
      final draft = JwEmailMessage(
        id: 'draft_local_01',
        subject: 'Rascunho de Carta aos Anciãos',
        from: 'me@jw.org',
        to: 'corpo.anciaos@jw.org',
        date: DateTime.now(),
        bodyText: 'Seguem as anotações referentes à visita de pastoreio realizada.',
        isDraft: true,
        tags: ['pastoreio', 'rascunho'],
      );

      await emailService.saveDraft(draft);

      final retained = await emailService.watchRetainedEmails().first;
      final foundDraft = retained.firstWhere((m) => m.id == 'draft_local_01');
      expect(foundDraft.isDraft, isTrue);
      expect(foundDraft.subject, equals('Rascunho de Carta aos Anciãos'));
    });
  });

  group('Hub.jw.org Restricted Communications & Biometric Lock Service', () {
    late BiometricAuthService auth;

    setUp(() {
      auth = BiometricAuthService();
    });

    test('Session is initially locked', () {
      expect(auth.isSessionUnlocked, isFalse);
    });

    test('lockSession immediately revokes active session', () async {
      // Simulate authentication
      final authenticated = await auth.authenticate(localizedReason: 'Teste de desbloqueio');
      expect(authenticated, isTrue);
      expect(auth.isSessionUnlocked, isTrue);

      auth.lockSession();
      expect(auth.isSessionUnlocked, isFalse);
    });
  });

  group('Knowledge Base & Research Bidirectional Integration & Dynamic Export', () {
    late AppDatabase db;
    late KnowledgeManager km;
    late ResearchManager rm;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      km = KnowledgeManager(db: db);
      rm = ResearchManager(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Knowledge Note transforms to Research Article and maintains bidirectional link', () async {
      final note = await km.createNote(
        title: 'Natureza das Profecias de Daniel',
        content: 'Daniel 2 fala sobre a estátua imensa dos impérios mundiais.',
        category: 'biblical',
        tags: ['profecia', 'daniel'],
      );

      // Verify initial note
      expect(note.id, isNotEmpty);
      final retrievedNote = await km.getNoteById(note.id);
      expect(retrievedNote, isNotNull);
      expect(retrievedNote!.title, equals('Natureza das Profecias de Daniel'));

      // Transform to research
      final article = await rm.addArticle(
        title: note.title,
        summary: note.content.length > 120 ? '${note.content.substring(0, 120)}...' : note.content,
        content: note.content,
        tags: [note.category, 'Nota Vinculada', 'knowledge_note:${note.id}'],
      );

      // Connect research link back to note
      final tags = (jsonDecode(note.tags) as List).map((e) => e.toString()).toList();
      tags.add('research:${article.id}');
      await km.updateNote(note.id, tags: tags);

      // Verify bidirectional reference
      final updatedNote = await km.getNoteById(note.id);
      expect(updatedNote!.tags, contains('research:${article.id}'));
      expect(article.tags, contains('knowledge_note:${note.id}'));
      expect(article.tags, contains('Nota Vinculada'));
    });

    test('Knowledge Question transforms to Research Article containing answer', () async {
      final q = await km.createQuestion(
        question: 'Quem são os 144.000 citados em Apocalipse?',
        context: 'Pergunta frequente no ministério de campo',
      );
      await km.answerQuestion(q.id, answer: 'São os escolhidos para reinar com Cristo no céu (Apo. 14:1-3).');

      final answeredQ = (await km.watchQuestions().first).firstWhere((item) => item.id == q.id);
      expect(answeredQ.answer, isNotNull);

      final contentBuffer = StringBuffer()
        ..writeln('**Pergunta:** ${answeredQ.question}')
        ..writeln()
        ..writeln('**Contexto:**\n${answeredQ.context}\n')
        ..writeln('**Resposta Bíblica:**\n${answeredQ.answer}');

      final article = await rm.addArticle(
        title: answeredQ.question,
        summary: answeredQ.context ?? 'Dúvida bíblica teocrática',
        content: contentBuffer.toString(),
        tags: ['Dúvida Teocrática', 'knowledge_question:${answeredQ.id}'],
      );

      expect(article.title, equals('Quem são os 144.000 citados em Apocalipse?'));
      expect(article.content, contains('Resposta Bíblica:'));
      expect(article.content, contains('Apo. 14:1-3'));
      expect(article.tags, contains('knowledge_question:${answeredQ.id}'));
    });
  });
}
