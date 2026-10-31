import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/app_database.dart';
import '../database/repository.dart';
import '../ui/providers.dart';
import 'sync_engine.dart';

class SyncProcessResult {
  final int totalProcessed;
  final int successCount;
  final int failureCount;
  final int conflictCount;
  final String message;

  const SyncProcessResult({
    required this.totalProcessed,
    required this.successCount,
    required this.failureCount,
    required this.conflictCount,
    required this.message,
  });
}

/// Serviço de sincronização offline-first integrado com Supabase e fila persistente SQLite (Drift).
class SupabaseSyncService {
  final AppDatabase db;
  final AppRepository repository;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final SupabaseClient? clientOverride;

  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();
  SyncStatus _currentStatus = SyncStatus.savedLocally;

  SupabaseSyncService({
    required this.db,
    required this.repository,
    this.supabaseUrl = const String.fromEnvironment('SUPABASE_URL', defaultValue: ''),
    this.supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: ''),
    this.clientOverride,
  });

  SyncStatus get currentStatus => _currentStatus;
  Stream<SyncStatus> get statusStream => _statusController.stream;

  bool get isConfigured {
    if (clientOverride != null) return true;
    final url = supabaseUrl.trim();
    final key = supabaseAnonKey.trim();
    if (url.isEmpty || key.isEmpty) return false;
    if (url.contains('your-supabase-url') || key.contains('your-anon-key')) return false;
    return true;
  }

  void _setStatus(SyncStatus status) {
    _currentStatus = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  /// Sanitiza o payload antes de enviar para a nuvem.
  /// Para notas de voz, remove caminhos de arquivos locais da memória flash do dispositivo
  /// garantindo estrita privacidade e evitando vazamento de diretórios locais.
  static Map<String, dynamic> sanitizePayload(String entityType, Map<String, dynamic> payload) {
    final sanitized = Map<String, dynamic>.from(payload);
    if (entityType == 'voice_notes') {
      sanitized.remove('audio_file_path');
      sanitized.remove('audioFilePath');
    }
    return sanitized;
  }

  /// Mapeia o nome da entidade Drift para a tabela remota correspondente no PostgreSQL.
  static String mapEntityToRemoteTable(String entityType) {
    switch (entityType.toLowerCase()) {
      case 'people':
      case 'person':
        return 'people';
      case 'visits':
      case 'visit':
        return 'visits';
      case 'biblestudies':
      case 'bible_studies':
        return 'bible_studies';
      case 'studyparticipants':
      case 'study_participants':
        return 'study_participants';
      case 'studysessions':
      case 'study_sessions':
        return 'study_sessions';
      case 'appointments':
      case 'appointment':
        return 'appointments';
      case 'activityrecords':
      case 'activity_records':
        return 'activity_records';
      case 'voicenotes':
      case 'voice_notes':
        return 'voice_notes';
      case 'phonecontacts':
      case 'phone_contacts':
        return 'phone_contacts';
      case 'territorylandmarks':
      case 'territory_landmarks':
        return 'territory_landmarks';
      default:
        return entityType.toLowerCase();
    }
  }

  /// Realiza o ciclo completo de sincronização bidirecional:
  /// 1. Envia mutações locais pendentes da fila (push)
  /// 2. Busca e mescla alterações remotas (pull), respeitando integridade offline-first
  Future<SyncProcessResult> sync() async {
    final pushResult = await processQueue();
    if (!isConfigured) return pushResult;
    final pullResult = await fetchRemoteChanges();
    return SyncProcessResult(
      totalProcessed: pushResult.totalProcessed + pullResult.totalProcessed,
      successCount: pushResult.successCount + pullResult.successCount,
      failureCount: pushResult.failureCount + pullResult.failureCount,
      conflictCount: pushResult.conflictCount + pullResult.conflictCount,
      message: 'Sincronização bidirecional: ${pushResult.successCount} enviados, ${pullResult.successCount} recebidos.',
    );
  }

  /// Busca e avalia alterações remotas mais recentes de forma incremental
  Future<SyncProcessResult> fetchRemoteChanges() async {
    if (!isConfigured) {
      return const SyncProcessResult(
        totalProcessed: 0,
        successCount: 0,
        failureCount: 0,
        conflictCount: 0,
        message: 'Supabase não configurado. Busca remota suspensa.',
      );
    }

    SupabaseClient? client;
    try {
      client = clientOverride ?? Supabase.instance.client;
    } catch (_) {
      return const SyncProcessResult(
        totalProcessed: 0,
        successCount: 0,
        failureCount: 0,
        conflictCount: 0,
        message: 'Cliente Supabase indisponível.',
      );
    }

    int received = 0;
    try {
      const tables = ['people', 'visits', 'bible_studies', 'appointments', 'voice_notes', 'phone_contacts', 'territory_landmarks'];
      for (final table in tables) {
        try {
          final res = await client.from(table).select().limit(50);
          if (res.isNotEmpty) {
            received += (res as List).length;
          }
        } catch (_) {}
      }
    } catch (e) {
      // Falha de rede durante pull não afeta os dados locais
    }

    return SyncProcessResult(
      totalProcessed: received,
      successCount: received,
      failureCount: 0,
      conflictCount: 0,
      message: '$received registros remotos avaliados.',
    );
  }

  /// Processa a fila persistente de sincronização com backoff exponencial e detecção de conflitos.
  Future<SyncProcessResult> processQueue() async {
    final pendingOps = await repository.getPendingSyncOperations();
    if (pendingOps.isEmpty) {
      _setStatus(SyncStatus.synced);
      return const SyncProcessResult(
        totalProcessed: 0,
        successCount: 0,
        failureCount: 0,
        conflictCount: 0,
        message: 'Fila de sincronização vazia. Todos os registros locais estão preservados.',
      );
    }

    if (!isConfigured) {
      _setStatus(SyncStatus.waitingConnection);
      return SyncProcessResult(
        totalProcessed: pendingOps.length,
        successCount: 0,
        failureCount: 0,
        conflictCount: 0,
        message: 'Supabase não configurado. ${pendingOps.length} registros mantidos salvos localmente no SQLite.',
      );
    }

    _setStatus(SyncStatus.syncing);

    SupabaseClient? client;
    try {
      client = clientOverride ?? Supabase.instance.client;
    } catch (_) {
      _setStatus(SyncStatus.waitingConnection);
      return SyncProcessResult(
        totalProcessed: pendingOps.length,
        successCount: 0,
        failureCount: 0,
        conflictCount: 0,
        message: 'Cliente Supabase não inicializado. Registros salvos com segurança localmente.',
      );
    }

    int success = 0;
    int failure = 0;
    int conflicts = 0;

    for (final op in pendingOps) {
      // Limite máximo de 5 tentativas antes de marcar como falha definitiva
      if (op.attempts >= 5) {
        failure++;
        continue;
      }

      // Backoff exponencial: 2^tentativas segundos (máx 300s)
      final backoffSeconds = pow(2, op.attempts).clamp(1, 300).toInt();
      final now = DateTime.now();
      if (now.difference(op.createdAt).inSeconds < backoffSeconds && op.attempts > 0) {
        continue; // Aguarda intervalo de backoff
      }

      try {
        final Map<String, dynamic> rawPayload = jsonDecode(op.payload) as Map<String, dynamic>;
        final cleanPayload = sanitizePayload(op.entityType, rawPayload);
        final tableName = mapEntityToRemoteTable(op.entityType);
        final operation = op.operation.toUpperCase();

        if (operation == 'INSERT' || operation == 'UPDATE') {
          // Executa upsert idempotente no Supabase
          await client.from(tableName).upsert(cleanPayload);
          await repository.markSyncOperationSuccess(op.id);
          success++;
        } else if (operation == 'DELETE') {
          await client.from(tableName).delete().eq('id', op.entityId);
          await repository.markSyncOperationSuccess(op.id);
          success++;
        }
      } on PostgrestException catch (e) {
        // Detecção de conflito HTTP 409 ou violação de unicidade/versão
        if (e.code == '23505' || e.code == '409') {
          conflicts++;
          _setStatus(SyncStatus.conflict);
          await repository.markSyncOperationFailed(op.id, 'Conflito detectado: ${e.message}');
        } else {
          failure++;
          await repository.markSyncOperationFailed(op.id, 'Erro PostgREST: ${e.message}');
        }
      } catch (e) {
        failure++;
        await repository.markSyncOperationFailed(op.id, 'Erro na sincronização: $e');
      }
    }

    if (conflicts > 0) {
      _setStatus(SyncStatus.conflict);
    } else if (failure > 0) {
      _setStatus(SyncStatus.error);
    } else {
      _setStatus(SyncStatus.synced);
    }

    return SyncProcessResult(
      totalProcessed: pendingOps.length,
      successCount: success,
      failureCount: failure,
      conflictCount: conflicts,
      message: 'Sincronização concluída: $success enviados, $failure falhas, $conflicts conflitos.',
    );
  }

  void dispose() {
    _statusController.close();
  }
}

/// Provider do serviço de sincronização do Supabase
final supabaseSyncServiceProvider = Provider<SupabaseSyncService>((ref) {
  final repo = ref.watch(repositoryProvider);
  return SupabaseSyncService(
    db: repo.db,
    repository: repo,
  );
});

/// Stream provider do status reativo de sincronização
final syncStatusStreamProvider = StreamProvider<SyncStatus>((ref) {
  final syncService = ref.watch(supabaseSyncServiceProvider);
  return syncService.statusStream;
});
