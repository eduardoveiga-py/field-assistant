import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../database/repository.dart';
import '../settings/backup_service.dart';
import '../inbox/inbox_manager.dart';
import '../tasks/task_manager.dart';
import '../projects/project_manager.dart';
import '../knowledge/knowledge_manager.dart';
import '../official_docs/official_doc_manager.dart';
import '../official_docs/official_doc_models.dart';
import '../core/biometric_auth_service.dart';
import '../inbox/jw_email_service.dart';
import '../appointments/availability_engine.dart';
import '../core/feature_registry.dart';
import '../navigation/app_navigation_controller.dart';

// Provider do Banco Drift
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// Provider do Repositório
final repositoryProvider = Provider<AppRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return AppRepository(db);
});

// Provider do BackupService
final backupServiceProvider = Provider<BackupService>((ref) {
  final repo = ref.watch(repositoryProvider);
  return BackupService(repo);
});

// ==========================================
// MÓDULO A — INBOX UNIVERSAL
// ==========================================

final inboxManagerProvider = Provider<InboxManager>((ref) {
  final db = ref.watch(databaseProvider);
  return InboxManager(db: db);
});

final unprocessedInboxStreamProvider = StreamProvider<List<InboxEntry>>((ref) {
  final inboxManager = ref.watch(inboxManagerProvider);
  return inboxManager.watchUnprocessedEntries();
});

final unprocessedInboxCountProvider = StreamProvider<int>((ref) {
  final inboxManager = ref.watch(inboxManagerProvider);
  return inboxManager.watchUnprocessedCount();
});

final biometricAuthServiceProvider = Provider<BiometricAuthService>((ref) {
  return BiometricAuthService();
});

final jwEmailServiceProvider = Provider<JwEmailService>((ref) {
  final db = ref.watch(databaseProvider);
  final biometric = ref.watch(biometricAuthServiceProvider);
  return JwEmailService(db: db, biometricAuth: biometric);
});

final retainedEmailsStreamProvider = StreamProvider<List<JwEmailMessage>>((
  ref,
) {
  final emailService = ref.watch(jwEmailServiceProvider);
  return emailService.watchRetainedEmails();
});

// ==========================================
// MÓDULO B — TAREFAS E PROJETOS
// ==========================================

final taskManagerProvider = Provider<TaskManager>((ref) {
  final db = ref.watch(databaseProvider);
  return TaskManager(db: db);
});

final pendingTasksStreamProvider = StreamProvider<List<TaskEntry>>((ref) {
  final taskManager = ref.watch(taskManagerProvider);
  return taskManager.watchPendingTasks();
});

final todayTasksStreamProvider = StreamProvider<List<TaskEntry>>((ref) {
  final taskManager = ref.watch(taskManagerProvider);
  return taskManager.watchTasksForToday();
});

final pendingTaskCountProvider = StreamProvider<int>((ref) {
  final taskManager = ref.watch(taskManagerProvider);
  return taskManager.watchPendingTaskCount();
});

final projectManagerProvider = Provider<ProjectManager>((ref) {
  final db = ref.watch(databaseProvider);
  return ProjectManager(db: db);
});

final activeProjectsStreamProvider = StreamProvider<List<ProjectEntry>>((ref) {
  final projectManager = ref.watch(projectManagerProvider);
  return projectManager.watchActiveProjects();
});

// ==========================================
// MÓDULO C — BASE DE CONHECIMENTO
// ==========================================

final knowledgeManagerProvider = Provider<KnowledgeManager>((ref) {
  final db = ref.watch(databaseProvider);
  return KnowledgeManager(db: db);
});

final recentNotesStreamProvider = StreamProvider<List<KnowledgeNoteEntry>>((
  ref,
) {
  final km = ref.watch(knowledgeManagerProvider);
  return km.watchNotes();
});

final officialDocManagerProvider = Provider<OfficialDocManager>((ref) {
  final db = ref.watch(databaseProvider);
  return OfficialDocManager(db: db);
});

final officialDocBundleStreamProvider =
    StreamProvider<OfficialDocProfileBundle>((ref) {
      final manager = ref.watch(officialDocManagerProvider);
      return manager.watchBundle();
    });

final officialDocTemplatesStreamProvider =
    StreamProvider<List<OfficialDocTemplate>>((ref) {
      final manager = ref.watch(officialDocManagerProvider);
      return manager.watchAllTemplates();
    });

// ==========================================
// STREAM PROVIDERS REATIVOS EXISTENTES
// ==========================================

final peopleStreamProvider = StreamProvider<List<PersonEntry>>((ref) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchAllPeople();
});

final studiesStreamProvider = StreamProvider<List<BibleStudyEntry>>((ref) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchAllStudies();
});

final appointmentsStreamProvider = StreamProvider<List<AppointmentEntry>>((
  ref,
) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchAppointments();
});

/// Provedor reativo de conflitos de horário pós-sincronização
final activeAppointmentConflictsProvider =
    Provider<List<AppointmentConflictPair>>((ref) {
      final appointments = ref.watch(appointmentsStreamProvider).value ?? [];
      return AvailabilityEngine.findActiveConflicts(appointments);
    });

final activitiesStreamProvider = StreamProvider<List<ActivityRecordEntry>>((
  ref,
) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchActivities();
});

final studyParticipantsStreamProvider =
    StreamProvider<List<StudyParticipantEntry>>((ref) {
      final repo = ref.watch(repositoryProvider);
      return (repo.db.select(
        repo.db.studyParticipants,
      )..where((t) => t.deletedAt.isNull())).watch();
    });

final studySessionsStreamProvider = StreamProvider<List<StudySessionEntry>>((
  ref,
) {
  final repo = ref.watch(repositoryProvider);
  return (repo.db.select(
    repo.db.studySessions,
  )..where((t) => t.deletedAt.isNull())).watch();
});

final visitsStreamProvider = StreamProvider<List<VisitEntry>>((ref) {
  final repo = ref.watch(repositoryProvider);
  return (repo.db.select(
    repo.db.visits,
  )..where((t) => t.deletedAt.isNull())).watch();
});

/// Notifier e Provider do Modo Sol Intenso & Alto Contraste
class SunModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  @override
  set state(bool value) => super.state = value;
  @override
  bool get state => super.state;

  void toggle() => state = !state;
}

final sunModeProvider = NotifierProvider<SunModeNotifier, bool>(
  SunModeNotifier.new,
);

// Eventos externos são mantidos separados dos compromissos locais para não
// gerar uploads duplicados ou contabilizá-los como atividade ministerial.
final externalCalendarEventsProvider =
    StreamProvider<List<ExternalCalendarEventEntry>>((ref) {
      final db = ref.watch(databaseProvider);
      return db.select(db.externalCalendarEvents).watch();
    });

final calendarEventLinksProvider = StreamProvider<List<CalendarEventLinkEntry>>(
  (ref) {
    final db = ref.watch(databaseProvider);
    return db.select(db.calendarEventLinks).watch();
  },
);

class PeopleFilterNotifier extends Notifier<String> {
  @override
  String build() => 'Todos';

  @override
  set state(String value) => super.state = value;
  @override
  String get state => super.state;
}

/// Filtro ativo para a lista de pessoas e contatos ('Todos', 'Revisitas', 'Estudos', etc.)
final peopleFilterProvider = NotifierProvider<PeopleFilterNotifier, String>(
  PeopleFilterNotifier.new,
);

class ShortcutsCategoryNotifier extends Notifier<String> {
  @override
  String build() => 'principais';

  @override
  set state(String value) => super.state = value;
  @override
  String get state => super.state;
}

/// Categoria ativa de atalhos rápidos na Home Screen ('principais', 'ministerio', 'produtividade', 'todos')
final todayShortcutsCategoryProvider =
    NotifierProvider<ShortcutsCategoryNotifier, String>(
      ShortcutsCategoryNotifier.new,
    );

class MapFullscreenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  @override
  set state(bool value) => super.state = value;
  @override
  bool get state => super.state;

  void toggle() => state = !state;
}

/// Modo tela cheia imersivo para o mapa dos territórios
final isMapFullscreenProvider = NotifierProvider<MapFullscreenNotifier, bool>(
  MapFullscreenNotifier.new,
);

/// Contadores reativos da fila de sincronização (pendentes, falhas e conflitos)
final syncQueueCountsProvider =
    StreamProvider<({int pending, int failed, int conflict})>((ref) {
      final repo = ref.watch(repositoryProvider);
      return repo.watchSyncQueueCounts();
    });

class AppNavigationNotifier extends Notifier<AppNavigationRequest?> {
  int _counter = 0;

  @override
  AppNavigationRequest? build() => null;

  void navigateTo(AppFeature feature, {int? subTabIndex, String? focusItemId}) {
    _counter++;
    state = AppNavigationRequest(
      requestId: _counter,
      feature: feature,
      subTabIndex: subTabIndex,
      focusItemId: focusItemId,
    );
  }

  void clearIfHandled(int requestId) {
    if (state?.requestId == requestId) {
      state = null;
    }
  }
}

/// Controlador reativo de navegação cruzada acionado por popups de referências.
final appNavigationProvider =
    NotifierProvider<AppNavigationNotifier, AppNavigationRequest?>(
      AppNavigationNotifier.new,
    );
