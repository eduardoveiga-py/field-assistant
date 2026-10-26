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
