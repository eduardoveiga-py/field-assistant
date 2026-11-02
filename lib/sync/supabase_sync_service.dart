import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_config.dart';
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
  final List<String> errors;

  const SyncProcessResult({
    required this.totalProcessed,
    required this.successCount,
    required this.failureCount,
    required this.conflictCount,
    required this.message,
    this.errors = const [],
  });

  bool get success => failureCount == 0 && errors.isEmpty;
}

typedef SyncResult = SyncProcessResult;

/// Serviço de sincronização offline-first integrado com Supabase e fila persistente SQLite (Drift).
class SupabaseSyncService {
  final AppDatabase db;
  final AppRepository repository;
  final AppConfig config;
  final SupabaseClient? clientOverride;
  final Future<String> Function()? documentsDirectoryProvider;

  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();
  SyncStatus _currentStatus = SyncStatus.savedLocally;

  static const List<String> syncTables = [
    'people',
    'visits',
    'bible_studies',
    'study_participants',
    'study_sessions',
    'appointments',
    'activity_records',
    'voice_notes',
    'phone_contacts',
    'territory_landmarks',
  ];

  SupabaseSyncService({
    required this.db,
    required this.repository,
    AppConfig? config,
    String? supabaseUrl,
    String? supabaseAnonKey,
    this.clientOverride,
    this.documentsDirectoryProvider,
  }) : config =
           config ??
           (supabaseUrl != null || supabaseAnonKey != null
               ? AppConfig.create(
                   environment: AppEnvironment.development,
                   supabaseUrl: supabaseUrl ?? '',
                   supabaseAnonKey: supabaseAnonKey ?? '',
                 )
               : AppConfig.fromEnvironment());

  String get supabaseUrl => config.supabaseUrl;
  String get supabaseAnonKey => config.supabaseAnonKey;

  SyncStatus get currentStatus => _currentStatus;
  Stream<SyncStatus> get statusStream => _statusController.stream;

  bool get isConfigured {
    if (clientOverride != null) return true;
    return config.isConfigured;
  }

  void _setStatus(SyncStatus status) {
    _currentStatus = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  static String snakeToCamel(String s) {
    return s.replaceAllMapped(
      RegExp(r'_([a-z0-9])'),
      (m) => m.group(1)!.toUpperCase(),
    );
  }

  static String camelToSnake(String s) {
    return s.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (m) => '_${m.group(0)!.toLowerCase()}',
    );
  }

  /// Sanitiza o payload antes de enviar para a nuvem.
  /// Para notas de voz, remove caminhos de arquivos locais da memória flash do dispositivo
  /// garantindo estrita privacidade e evitando vazamento de diretórios locais.
  static Map<String, dynamic> sanitizePayload(
    String entityType,
    Map<String, dynamic> payload,
  ) {
    final sanitized = Map<String, dynamic>.from(payload);
    sanitized.remove('_base');
    sanitized.remove('baseData');
    if (entityType == 'voice_notes' || entityType == 'voiceNotes') {
      sanitized.remove('audio_file_path');
      sanitized.remove('audioFilePath');
    }
    return sanitized;
  }

  /// Converte payload com chaves camelCase para snake_case para envio PostgREST
  static Map<String, dynamic> toRemotePayload(
    String entityType,
    Map<String, dynamic> localPayload,
  ) {
    final sanitized = sanitizePayload(entityType, localPayload);
    final Map<String, dynamic> remote = {};
    sanitized.forEach((key, value) {
      if (key == 'dateTimeField') {
        remote['date_time_field'] = value;
      } else {
        remote[camelToSnake(key)] = value;
      }
    });
    return remote;
  }

  /// Normaliza payload remoto convertendo chaves snake_case para camelCase
  static Map<String, dynamic> normalizeRemotePayload(
    Map<String, dynamic> remote,
  ) {
    final Map<String, dynamic> result = {};
    remote.forEach((key, value) {
      var camelKey = snakeToCamel(key);
      if (camelKey == 'dateTime') {
        camelKey = 'dateTimeField';
      }
      if (value is List) {
        result[camelKey] = jsonEncode(value);
      } else if (value is int &&
          (camelKey == 'latitude' || camelKey == 'longitude')) {
        result[camelKey] = value.toDouble();
      } else {
        result[camelKey] = value;
      }
    });
    return result;
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
      case 'biblestudyparticipants':
      case 'bible_study_participants':
        return 'study_participants';
      case 'studysessions':
      case 'study_sessions':
      case 'biblestudysessions':
      case 'bible_study_sessions':
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

  static String? _isoString(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val.toUtc().toIso8601String();
    return val.toString();
  }

  Map<String, dynamic> _prepareEntryMap(
    String table,
    Map<String, dynamic> input,
  ) {
    final map = Map<String, dynamic>.from(input);
    final nowStr = DateTime.now().toUtc().toIso8601String();

    map['createdAt'] =
        _isoString(map['createdAt']) ?? _isoString(map['created_at']) ?? nowStr;
    map['updatedAt'] =
        _isoString(map['updatedAt']) ?? _isoString(map['updated_at']) ?? nowStr;
    map['deletedAt'] =
        _isoString(map['deletedAt']) ?? _isoString(map['deleted_at']);
    map['revision'] = map['revision'] is int
        ? map['revision']
        : int.tryParse(map['revision']?.toString() ?? '1') ?? 1;

    switch (table) {
      case 'people':
        map['status'] ??= 'interessado';
        map['tags'] ??= '[]';
        map['firstContactAt'] =
            _isoString(map['firstContactAt']) ??
            _isoString(map['first_contact_at']) ??
            map['createdAt'];
        map['lastContactAt'] =
            _isoString(map['lastContactAt']) ??
            _isoString(map['last_contact_at']);
        map['nextActionAt'] =
            _isoString(map['nextActionAt']) ??
            _isoString(map['next_action_at']);
        break;
      case 'visits':
        map['dateTimeField'] =
            _isoString(map['dateTimeField']) ??
            _isoString(map['dateTime']) ??
            _isoString(map['date_time_field']) ??
            _isoString(map['date_time']) ??
            map['createdAt'];
        map['contactType'] ??= 'revisita';
        map['result'] ??= 'contato';
        map['suggestedReturnDate'] =
            _isoString(map['suggestedReturnDate']) ??
            _isoString(map['suggested_return_date']);
        break;
      case 'bible_studies':
        map['ownerId'] ??= 'local_user';
        map['startedAt'] =
            _isoString(map['startedAt']) ??
            _isoString(map['started_at']) ??
            map['createdAt'];
        map['status'] ??= 'ativo';
        map['publicationId'] ??= 'lff-book';
        map['language'] ??= 'pt';
        map['frequency'] ??= 'semanal';
        map['lastSessionAt'] =
            _isoString(map['lastSessionAt']) ??
            _isoString(map['last_session_at']);
        map['nextPlannedAt'] =
            _isoString(map['nextPlannedAt']) ??
            _isoString(map['next_planned_at']);
        break;
      case 'study_participants':
        map['isPrimary'] =
            map['isPrimary'] == true ||
            map['is_primary'] == true ||
            map['isPrimary'] == 1 ||
            map['is_primary'] == 1;
        break;
      case 'study_sessions':
        map['dateTimeField'] =
            _isoString(map['dateTimeField']) ??
            _isoString(map['dateTime']) ??
            _isoString(map['date_time_field']) ??
            _isoString(map['date_time']) ??
            map['createdAt'];
        map['status'] ??= 'realizada';
        map['participantIds'] ??= '[]';
        break;
      case 'appointments':
        map['durationMinutes'] = map['durationMinutes'] is int
            ? map['durationMinutes']
            : int.tryParse(map['durationMinutes']?.toString() ?? '30') ?? 30;
        map['status'] ??= 'planejado';
        map['isProvisional'] =
            map['isProvisional'] == true ||
            map['is_provisional'] == true ||
            map['isProvisional'] == 1 ||
            map['is_provisional'] == 1;
        map['startTime'] =
            _isoString(map['startTime']) ??
            _isoString(map['start_time']) ??
            map['createdAt'];
        map['endTime'] =
            _isoString(map['endTime']) ??
            _isoString(map['end_time']) ??
            map['createdAt'];
        break;
      case 'activity_records':
        map['date'] =
            _isoString(map['date']) ??
            _isoString(map['created_at']) ??
            map['createdAt'];
        map['durationSeconds'] = map['durationSeconds'] is int
            ? map['durationSeconds']
            : int.tryParse(map['durationSeconds']?.toString() ?? '0') ?? 0;
        map['modality'] ??= 'campo';
        break;
      case 'voice_notes':
        map['audioDurationSeconds'] = map['audioDurationSeconds'] is int
            ? map['audioDurationSeconds']
            : int.tryParse(map['audioDurationSeconds']?.toString() ?? '0') ?? 0;
        map['transcription'] ??= '';
        break;
      case 'phone_contacts':
        map['hasWhatsapp'] =
            map['hasWhatsapp'] == true ||
            map['has_whatsapp'] == true ||
            map['hasWhatsapp'] == 1 ||
            map['has_whatsapp'] == 1;
        map['hasSocial'] =
            map['hasSocial'] == true ||
            map['has_social'] == true ||
            map['hasSocial'] == 1 ||
            map['has_social'] == 1;
        map['tags'] ??= '[]';
        map['origin'] ??= 'Informal';
        map['phone'] ??= '';
        break;
      case 'territory_landmarks':
        map['category'] ??= 'outro';
        break;
    }
    return map;
  }

  Future<void> _insertLocalEntry(String table, Map<String, dynamic> raw) async {
    final map = _prepareEntryMap(table, raw);
    switch (table) {
      case 'people':
        await db.into(db.people).insert(PersonEntry.fromJson(map));
        break;
      case 'visits':
        await db.into(db.visits).insert(VisitEntry.fromJson(map));
        break;
      case 'bible_studies':
        await db.into(db.bibleStudies).insert(BibleStudyEntry.fromJson(map));
        break;
      case 'study_participants':
        await db
            .into(db.studyParticipants)
            .insert(StudyParticipantEntry.fromJson(map));
        break;
      case 'study_sessions':
        await db.into(db.studySessions).insert(StudySessionEntry.fromJson(map));
        break;
      case 'appointments':
        await db.into(db.appointments).insert(AppointmentEntry.fromJson(map));
        break;
      case 'activity_records':
        await db
            .into(db.activityRecords)
            .insert(ActivityRecordEntry.fromJson(map));
        break;
      case 'voice_notes':
        await db.into(db.voiceNotes).insert(VoiceNoteEntry.fromJson(map));
        break;
      case 'phone_contacts':
        await db.into(db.phoneContacts).insert(PhoneContactEntry.fromJson(map));
        break;
      case 'territory_landmarks':
        await db
            .into(db.territoryLandmarks)
            .insert(TerritoryLandmarkEntry.fromJson(map));
        break;
    }
  }

  Future<void> _updateLocalEntry(String table, Map<String, dynamic> raw) async {
    final map = _prepareEntryMap(table, raw);
    switch (table) {
      case 'people':
        await db.update(db.people).replace(PersonEntry.fromJson(map));
        break;
      case 'visits':
        await db.update(db.visits).replace(VisitEntry.fromJson(map));
        break;
      case 'bible_studies':
        await db.update(db.bibleStudies).replace(BibleStudyEntry.fromJson(map));
        break;
      case 'study_participants':
        await db
            .update(db.studyParticipants)
            .replace(StudyParticipantEntry.fromJson(map));
        break;
      case 'study_sessions':
        await db
            .update(db.studySessions)
            .replace(StudySessionEntry.fromJson(map));
        break;
      case 'appointments':
        await db
            .update(db.appointments)
            .replace(AppointmentEntry.fromJson(map));
        break;
      case 'activity_records':
        await db
            .update(db.activityRecords)
            .replace(ActivityRecordEntry.fromJson(map));
        break;
      case 'voice_notes':
        await db.update(db.voiceNotes).replace(VoiceNoteEntry.fromJson(map));
        break;
      case 'phone_contacts':
        await db
            .update(db.phoneContacts)
            .replace(PhoneContactEntry.fromJson(map));
        break;
      case 'territory_landmarks':
        await db
            .update(db.territoryLandmarks)
            .replace(TerritoryLandmarkEntry.fromJson(map));
        break;
    }
  }

  Future<void> _softDeleteLocalEntry(
    String table,
    String id,
    dynamic deletedAtVal,
  ) async {
    final deletedAt = deletedAtVal is DateTime
        ? deletedAtVal
        : DateTime.tryParse(deletedAtVal?.toString() ?? '') ?? DateTime.now();
    switch (table) {
      case 'people':
        await (db.update(db.people)..where((t) => t.id.equals(id))).write(
          PeopleCompanion(deletedAt: drift.Value(deletedAt)),
        );
        break;
      case 'visits':
        await (db.update(db.visits)..where((t) => t.id.equals(id))).write(
          VisitsCompanion(deletedAt: drift.Value(deletedAt)),
        );
        break;
      case 'bible_studies':
        await (db.update(db.bibleStudies)..where((t) => t.id.equals(id))).write(
          BibleStudiesCompanion(deletedAt: drift.Value(deletedAt)),
        );
        break;
      case 'study_participants':
        await (db.update(
          db.studyParticipants,
        )..where((t) => t.id.equals(id))).write(
          StudyParticipantsCompanion(deletedAt: drift.Value(deletedAt)),
        );
        break;
      case 'study_sessions':
        await (db.update(db.studySessions)..where((t) => t.id.equals(id)))
            .write(StudySessionsCompanion(deletedAt: drift.Value(deletedAt)));
        break;
      case 'appointments':
        await (db.update(db.appointments)..where((t) => t.id.equals(id))).write(
          AppointmentsCompanion(deletedAt: drift.Value(deletedAt)),
        );
        break;
      case 'activity_records':
        await (db.update(db.activityRecords)..where((t) => t.id.equals(id)))
            .write(ActivityRecordsCompanion(deletedAt: drift.Value(deletedAt)));
        break;
      case 'voice_notes':
        await (db.update(db.voiceNotes)..where((t) => t.id.equals(id))).write(
          VoiceNotesCompanion(deletedAt: drift.Value(deletedAt)),
        );
        break;
      case 'phone_contacts':
        await (db.update(db.phoneContacts)..where((t) => t.id.equals(id)))
            .write(PhoneContactsCompanion(deletedAt: drift.Value(deletedAt)));
        break;
      case 'territory_landmarks':
        await (db.update(
          db.territoryLandmarks,
        )..where((t) => t.id.equals(id))).write(
          TerritoryLandmarksCompanion(deletedAt: drift.Value(deletedAt)),
        );
        break;
    }
  }

  Future<Map<String, dynamic>?> _getLocalMap(String table, String id) async {
    switch (table) {
      case 'people':
        final row = await (db.select(
          db.people,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        return row?.toJson();
      case 'visits':
        final row = await (db.select(
          db.visits,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        return row?.toJson();
      case 'bible_studies':
        final row = await (db.select(
          db.bibleStudies,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        return row?.toJson();
      case 'study_participants':
        final row = await (db.select(
          db.studyParticipants,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        return row?.toJson();
      case 'study_sessions':
        final row = await (db.select(
          db.studySessions,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        return row?.toJson();
      case 'appointments':
        final row = await (db.select(
          db.appointments,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        return row?.toJson();
      case 'activity_records':
        final row = await (db.select(
          db.activityRecords,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        return row?.toJson();
      case 'voice_notes':
        final row = await (db.select(
          db.voiceNotes,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        return row?.toJson();
      case 'phone_contacts':
        final row = await (db.select(
          db.phoneContacts,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        return row?.toJson();
      case 'territory_landmarks':
        final row = await (db.select(
          db.territoryLandmarks,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        return row?.toJson();
      default:
        return null;
    }
  }

  Future<bool> _uploadVoiceNoteAudio(
    String id,
    SupabaseClient client,
    List<String> errors,
  ) async {
    try {
      final vn = await (db.select(
        db.voiceNotes,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (vn?.audioFilePath != null && vn!.audioFilePath!.isNotEmpty) {
        final file = File(vn.audioFilePath!);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final storageFileName = id.endsWith('.m4a') ? id : '$id.m4a';
          await client.storage
              .from('voice_notes')
              .uploadBinary(
                storageFileName,
                bytes,
                fileOptions: const FileOptions(upsert: true),
              );
          return true;
        }
      }
      return true;
    } catch (e) {
      errors.add('Erro no upload de áudio de voice_notes ($id): $e');
      return false;
    }
  }

  Future<bool> _downloadVoiceNoteAudio(String id, SupabaseClient client) async {
    try {
      final storageFileName = id.endsWith('.m4a') ? id : '$id.m4a';
      final bytes = await client.storage
          .from('voice_notes')
          .download(storageFileName);
      if (bytes.isNotEmpty) {
        final docsDir = documentsDirectoryProvider != null
            ? await documentsDirectoryProvider!()
            : (await getApplicationDocumentsDirectory()).path;
        final voiceNotesDir = Directory(p.join(docsDir, 'voice_notes'));
        if (!await voiceNotesDir.exists()) {
          await voiceNotesDir.create(recursive: true);
        }
        final localFilePath = p.join(voiceNotesDir.path, storageFileName);
        final file = File(localFilePath);
        await file.writeAsBytes(bytes, flush: true);

        await (db.update(db.voiceNotes)..where((t) => t.id.equals(id))).write(
          VoiceNotesCompanion(audioFilePath: drift.Value(localFilePath)),
        );

        // Remove pendência de download se estava registrada
        await (db.delete(
          db.appKvStore,
        )..where((t) => t.key.equals('pending_audio_download_$id'))).go();
        return true;
      }
      return false;
    } catch (e) {
      // Registra a nota no AppKvStore para retentativa resiliente posterior
      try {
        await db
            .into(db.appKvStore)
            .insertOnConflictUpdate(
              AppKvStoreCompanion.insert(
                key: 'pending_audio_download_$id',
                value: DateTime.now().toUtc().toIso8601String(),
                updatedAt: drift.Value(DateTime.now()),
              ),
            );
      } catch (_) {}
      return false;
    }
  }

  /// Retenta o download de áudios que falharam durante a recepção de metadados
  Future<int> retryPendingMediaDownloads() async {
    if (!isConfigured) return 0;
    SupabaseClient? client;
    try {
      client = clientOverride ?? Supabase.instance.client;
    } catch (_) {
      return 0;
    }

    final pendingRows = await (db.select(
      db.appKvStore,
    )..where((t) => t.key.like('pending_audio_download_%'))).get();

    int recovered = 0;
    for (final row in pendingRows) {
      final id = row.key.replaceFirst('pending_audio_download_', '');
      final ok = await _downloadVoiceNoteAudio(id, client);
      if (ok) recovered++;
    }
    return recovered;
  }

  Future<bool> _applyRemoteRecord({
    required String table,
    required Map<String, dynamic> remoteRecord,
    required SupabaseClient? client,
    required List<String> errors,
  }) async {
    final normalized = normalizeRemotePayload(remoteRecord);
    final id = normalized['id'] as String?;
    if (id == null || id.isEmpty) return false;

    try {
      final localMap = await _getLocalMap(table, id);
      final pendingOp =
          await (db.select(db.syncQueue)..where(
                (t) =>
                    t.entityId.equals(id) &
                    (t.status.equals('pending') |
                        t.status.equals('in_progress')),
              ))
              .getSingleOrNull();

      if (localMap == null) {
        await _insertLocalEntry(table, normalized);
        if (table == 'voice_notes' && client != null) {
          await _downloadVoiceNoteAudio(id, client);
        }
        return true;
      }

      if (pendingOp != null) {
        final rawPayload =
            jsonDecode(pendingOp.payload) as Map<String, dynamic>;
        final Map<String, dynamic> baseData;
        final Map<String, dynamic> localData;

        if (rawPayload.containsKey('_base') && rawPayload['_base'] is Map) {
          baseData = normalizeRemotePayload(
            rawPayload['_base'] as Map<String, dynamic>,
          );
          localData = localMap;
        } else if (rawPayload.containsKey('baseData') &&
            rawPayload['baseData'] is Map) {
          baseData = normalizeRemotePayload(
            rawPayload['baseData'] as Map<String, dynamic>,
          );
          localData = localMap;
        } else {
          localData = normalizeRemotePayload(rawPayload);
          baseData = Map<String, dynamic>.from(localMap);
        }

        final mergeResult = SyncEngine.mergeEntities(
          entityType: table,
          entityId: id,
          localData: localData,
          remoteData: normalized,
          baseData: baseData,
        );

        if (mergeResult.hasConflict) {
          final conflictFields = mergeResult.conflicts
              .map((c) => c.fieldName)
              .join(', ');
          final errMsg =
              'Conflito detectado em $table ($id) nos campos: $conflictFields';
          errors.add(errMsg);
          await repository.markSyncOperationFailed(pendingOp.id, errMsg);
          await (db.update(db.syncQueue)
                ..where((t) => t.id.equals(pendingOp.id)))
              .write(const SyncQueueCompanion(status: drift.Value('conflict')));
          _setStatus(SyncStatus.conflict);
          return false;
        } else {
          await _updateLocalEntry(table, mergeResult.mergedData);
          await (db.update(
            db.syncQueue,
          )..where((t) => t.id.equals(pendingOp.id))).write(
            SyncQueueCompanion(
              payload: drift.Value(jsonEncode(mergeResult.mergedData)),
            ),
          );
          return true;
        }
      } else {
        final isRemoteDeleted =
            normalized['deletedAt'] != null || normalized['deleted_at'] != null;
        if (isRemoteDeleted) {
          await _softDeleteLocalEntry(
            table,
            id,
            normalized['deletedAt'] ?? normalized['deleted_at'],
          );
          return true;
        } else {
          final localUpdatedAtStr = localMap['updatedAt']?.toString();
          final remoteUpdatedAtStr =
              normalized['updatedAt']?.toString() ??
              normalized['updated_at']?.toString();
          final localRev = localMap['revision'] as int? ?? 1;
          final remoteRev = normalized['revision'] as int? ?? 1;

          DateTime? localUpdated = localUpdatedAtStr != null
              ? DateTime.tryParse(localUpdatedAtStr)
              : null;
          DateTime? remoteUpdated = remoteUpdatedAtStr != null
              ? DateTime.tryParse(remoteUpdatedAtStr)
              : null;

          final isRemoteNewer = remoteUpdated != null && localUpdated != null
              ? (remoteUpdated.isAfter(localUpdated) ||
                    remoteUpdated.isAtSameMomentAs(localUpdated))
              : remoteRev >= localRev;

          if (isRemoteNewer) {
            await _updateLocalEntry(table, normalized);
            if (table == 'voice_notes' && client != null) {
              await _downloadVoiceNoteAudio(id, client);
            }
          }
          return true;
        }
      }
    } catch (e) {
      errors.add('Erro ao aplicar registro remoto em $table ($id): $e');
      return false;
    }
  }

  /// Realiza o ciclo completo de sincronização bidirecional:
  /// 1. Envia mutações locais pendentes da fila (push)
  /// 2. Busca e mescla alterações remotas (pull), respeitando integridade offline-first
  Future<SyncProcessResult> sync() async {
    final pushResult = await processQueue();
    if (!isConfigured) return pushResult;
    final pullResult = await fetchRemoteChanges();
    final allErrors = [...pushResult.errors, ...pullResult.errors];
    return SyncProcessResult(
      totalProcessed: pushResult.totalProcessed + pullResult.totalProcessed,
      successCount: pushResult.successCount + pullResult.successCount,
      failureCount: pushResult.failureCount + pullResult.failureCount,
      conflictCount: pushResult.conflictCount + pullResult.conflictCount,
      errors: allErrors,
      message:
          'Sincronização bidirecional: ${pushResult.successCount} enviados, ${pullResult.successCount} recebidos.',
    );
  }

  /// Busca e avalia alterações remotas mais recentes de forma incremental e paginada
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
        errors: ['Cliente Supabase indisponível.'],
      );
    }

    int totalProcessed = 0;
    int successCount = 0;
    int failureCount = 0;
    int conflictCount = 0;
    final List<String> errors = [];

    for (final table in syncTables) {
      try {
        final kvRow =
            await (db.select(db.appKvStore)
                  ..where((t) => t.key.equals('last_synced_at_$table')))
                .getSingleOrNull();
        final lastSyncedAt = kvRow != null
            ? DateTime.tryParse(kvRow.value)
            : null;

        int offset = 0;
        const pageSize = 100;
        DateTime? newestUpdatedAt;

        while (true) {
          var query = client.from(table).select();
          if (lastSyncedAt != null) {
            query = query.gt(
              'updated_at',
              lastSyncedAt.toUtc().toIso8601String(),
            );
          }

          final res = await query
              .order('updated_at', ascending: true)
              .order('id', ascending: true)
              .range(offset, offset + pageSize - 1);
          final List rows = res as List;
          if (rows.isEmpty) break;

          for (final rawItem in rows) {
            totalProcessed++;
            final map = rawItem as Map<String, dynamic>;
            final updatedAtRaw = map['updated_at'] ?? map['updatedAt'];
            final dt = updatedAtRaw != null
                ? DateTime.tryParse(updatedAtRaw.toString())
                : null;

            final applied = await _applyRemoteRecord(
              table: table,
              remoteRecord: map,
              client: client,
              errors: errors,
            );

            if (applied) {
              successCount++;
              if (dt != null &&
                  (newestUpdatedAt == null || dt.isAfter(newestUpdatedAt))) {
                newestUpdatedAt = dt;
              }
            } else {
              if (_currentStatus == SyncStatus.conflict) {
                conflictCount++;
              } else {
                failureCount++;
              }
            }
          }

          if (rows.length < pageSize) break;
          offset += pageSize;
        }

        if (newestUpdatedAt != null) {
          await db
              .into(db.appKvStore)
              .insertOnConflictUpdate(
                AppKvStoreCompanion.insert(
                  key: 'last_synced_at_$table',
                  value: newestUpdatedAt.toUtc().toIso8601String(),
                  updatedAt: drift.Value(DateTime.now()),
                ),
              );
        }
      } catch (e) {
        final err = 'Erro ao buscar alterações na tabela $table: $e';
        errors.add(err);
        failureCount++;
        _setStatus(SyncStatus.error);
      }
    }

    if (conflictCount > 0) {
      _setStatus(SyncStatus.conflict);
    } else if (failureCount > 0 || errors.isNotEmpty) {
      _setStatus(SyncStatus.error);
    } else {
      _setStatus(SyncStatus.synced);
    }

    return SyncProcessResult(
      totalProcessed: totalProcessed,
      successCount: successCount,
      failureCount: failureCount,
      conflictCount: conflictCount,
      errors: errors,
      message:
          '$totalProcessed registros remotos avaliados. $successCount mesclados com sucesso, $conflictCount conflitos, $failureCount falhas.',
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
        message:
            'Supabase não configurado. ${pendingOps.length} registros mantidos salvos localmente no SQLite.',
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
        errors: const ['Cliente Supabase não inicializado.'],
        message: 'Cliente Supabase não inicializado. Registros salvos com segurança localmente.',
      );
    }

    int success = 0;
    int failure = 0;
    int conflicts = 0;
    final List<String> errors = [];

    for (final op in pendingOps) {
      if (op.attempts >= 5) {
        failure++;
        errors.add(
          'Operação ${op.id} (${op.entityType}) excedeu o limite máximo de 5 tentativas.',
        );
        continue;
      }

      final backoffSeconds = pow(2, op.attempts).clamp(1, 300).toInt();
      final now = DateTime.now();
      if (now.difference(op.createdAt).inSeconds < backoffSeconds &&
          op.attempts > 0) {
        continue;
      }

      try {
        final Map<String, dynamic> rawPayload =
            jsonDecode(op.payload) as Map<String, dynamic>;
        final cleanPayload = sanitizePayload(op.entityType, rawPayload);
        final tableName = mapEntityToRemoteTable(op.entityType);
        final operation = op.operation.toUpperCase();

        if (operation == 'INSERT' || operation == 'UPDATE') {
          final remotePayload = toRemotePayload(op.entityType, cleanPayload);
          await client.from(tableName).upsert(remotePayload);

          if (tableName == 'voice_notes') {
            final audioOk = await _uploadVoiceNoteAudio(
              op.entityId,
              client,
              errors,
            );
            if (!audioOk) {
              failure++;
              await repository.markSyncOperationFailed(
                op.id,
                'Falha no upload do arquivo binário de áudio para o Storage',
              );
              continue;
            }
          }

          await repository.markSyncOperationSuccess(op.id);
          success++;
        } else if (operation == 'DELETE') {
          await client.from(tableName).delete().eq('id', op.entityId);
          await repository.markSyncOperationSuccess(op.id);
          success++;
        }
      } on PostgrestException catch (e) {
        if (e.code == '23505' || e.code == '409') {
          conflicts++;
          _setStatus(SyncStatus.conflict);
          final err =
              'Conflito detectado na operação ${op.id} (${op.entityType}): ${e.message}';
          errors.add(err);
          await repository.markSyncOperationFailed(op.id, err);
        } else {
          failure++;
          final err =
              'Erro PostgREST na operação ${op.id} (${op.entityType}): ${e.message}';
          errors.add(err);
          await repository.markSyncOperationFailed(op.id, err);
        }
      } catch (e) {
        failure++;
        final err = 'Erro na operação ${op.id} (${op.entityType}): $e';
        errors.add(err);
        await repository.markSyncOperationFailed(op.id, err);
      }
    }

    if (conflicts > 0) {
      _setStatus(SyncStatus.conflict);
    } else if (failure > 0 || errors.isNotEmpty) {
      _setStatus(SyncStatus.error);
    } else {
      _setStatus(SyncStatus.synced);
    }

    return SyncProcessResult(
      totalProcessed: pendingOps.length,
      successCount: success,
      failureCount: failure,
      conflictCount: conflicts,
      errors: errors,
      message:
          'Sincronização concluída: $success enviados, $failure falhas, $conflicts conflitos.',
    );
  }

  void dispose() {
    _statusController.close();
  }
}

/// Provider do serviço de sincronização do Supabase
final supabaseSyncServiceProvider = Provider<SupabaseSyncService>((ref) {
  final repo = ref.watch(repositoryProvider);
  final config = ref.watch(appConfigProvider);
  return SupabaseSyncService(db: repo.db, repository: repo, config: config);
});

/// Stream provider do status reativo de sincronização
final syncStatusStreamProvider = StreamProvider<SyncStatus>((ref) {
  final syncService = ref.watch(supabaseSyncServiceProvider);
  return syncService.statusStream;
});
