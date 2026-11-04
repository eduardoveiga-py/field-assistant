import 'package:uuid/uuid.dart';

import '../app_database.dart';

/// Contrato base abstrato para o repositório Drift e seus mixins de domínio.
abstract class BaseRepository {
  AppDatabase get db;
  Uuid get uuid;

  /// Registra uma mutação na outbox de sincronização (sync_queue)
  Future<void> recordSyncOperation({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
    Map<String, dynamic>? baseData,
  });

  /// Busca pessoa por ID (usado por múltiplos domínios como Visits)
  Future<PersonEntry?> getPersonById(String id);

  /// Busca estudo por ID (usado por múltiplos domínios)
  Future<BibleStudyEntry?> getStudyById(String id);
}
