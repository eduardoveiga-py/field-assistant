import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../database/repository.dart';
import '../settings/backup_service.dart';

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

// Stream Providers reativos
final peopleStreamProvider = StreamProvider<List<PersonEntry>>((ref) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchAllPeople();
});

final studiesStreamProvider = StreamProvider<List<BibleStudyEntry>>((ref) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchAllStudies();
});

final appointmentsStreamProvider = StreamProvider<List<AppointmentEntry>>((ref) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchAppointments();
});

final activitiesStreamProvider = StreamProvider<List<ActivityRecordEntry>>((ref) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchActivities();
});

final studyParticipantsStreamProvider = StreamProvider<List<StudyParticipantEntry>>((ref) {
  final repo = ref.watch(repositoryProvider);
  return (repo.db.select(repo.db.studyParticipants)..where((t) => t.deletedAt.isNull())).watch();
});

final studySessionsStreamProvider = StreamProvider<List<StudySessionEntry>>((ref) {
  final repo = ref.watch(repositoryProvider);
  return (repo.db.select(repo.db.studySessions)..where((t) => t.deletedAt.isNull())).watch();
});

final visitsStreamProvider = StreamProvider<List<VisitEntry>>((ref) {
  final repo = ref.watch(repositoryProvider);
  return (repo.db.select(repo.db.visits)..where((t) => t.deletedAt.isNull())).watch();
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

final sunModeProvider = NotifierProvider<SunModeNotifier, bool>(SunModeNotifier.new);


