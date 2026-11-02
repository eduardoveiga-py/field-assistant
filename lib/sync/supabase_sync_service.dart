import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_config.dart';
import '../core/app_logger.dart';
import '../core/supabase_initializer.dart';
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
class SupabaseSyncService with WidgetsBindingObserver {
  final AppDatabase db;
  final AppRepository repository;
  final AppConfig config;
  final SupabaseClient? clientOverride;
  final Future<String> Function()? documentsDirectoryProvider;

  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();
  SyncStatus _currentStatus = SyncStatus.savedLocally;
  bool _isObservingLifecycle = false;
  final Map<String, DateTime> _lastAttemptTime = {};
  bool _isSyncing = false;
  Completer<SyncProcessResult>? _activeSyncCompleter;
  bool _isFetchingRemote = false;
  Completer<SyncProcessResult>? _activeFetchCompleter;
  StreamSubscription<SupabaseConnectionState>? _connectionStateSubscription;

  /// Retorna `true` se o processamento da fila de envio estiver em andamento.
  bool get isSyncing => _isSyncing;

  /// Retorna `true` se a busca de alterações remotas estiver em andamento.
  bool get isFetchingRemote => _isFetchingRemote;

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

  bool get isOffline {
    if (clientOverride != null) return false;
    return SupabaseInitializer.currentState.isOffline;
  }

  void _setStatus(SyncStatus status) {
    _currentStatus = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  /// Retorna o cliente Supabase disponível (injetado via teste ou inicializado globalmente).
  /// Retorna `null` se o Supabase não tiver sido inicializado, prevenindo AssertionError.
  SupabaseClient? get client {
    if (clientOverride != null) return clientOverride;
    return SupabaseInitializer.clientOrNull;
  }

  /// Calcula backoff exponencial com jitter (Full Jitter).
  /// Base: 2^attempts limitado a 300 segundos, com até 25% de jitter aleatório para evitar picos de concorrência.
  static int calculateBackoffSeconds(int attempts, {Random? random}) {
    if (attempts <= 0) return 0;
    final base = pow(2, min(attempts, 8)).clamp(1, 300).toInt();
    final rng = random ?? Random();
    final jitter = (rng.nextDouble() * 0.25 * base).round();
    return (base + jitter).clamp(1, 300);
  }

  /// Inicia a observação de mudanças de estado do ciclo de vida da aplicação Flutter e conectividade.
  void startLifecycleObservation() {
    if (!_isObservingLifecycle) {
      try {
        WidgetsBinding.instance.addObserver(this);
        _isObservingLifecycle = true;
      } catch (_) {}

      _connectionStateSubscription?.cancel();
      SupabaseConnectionState? previousState = SupabaseInitializer.currentState;
      _connectionStateSubscription = SupabaseInitializer.stateStream.listen((
        newState,
      ) {
        if (previousState != SupabaseConnectionState.connected &&
            newState == SupabaseConnectionState.connected) {
          unawaited(handleReconnection());
        }
        previousState = newState;
      });
    }
  }

  /// Encerra a observação do ciclo de vida e conectividade.
  void stopLifecycleObservation() {
    if (_isObservingLifecycle) {
      try {
        WidgetsBinding.instance.removeObserver(this);
        _isObservingLifecycle = false;
      } catch (_) {}
    }
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(handleAppResume());
    }
  }

  /// Trata o retorno do aplicativo do segundo plano para o primeiro plano (resumed).
  Future<void> handleAppResume() async {
    if (!isConfigured) return;
    AppLogger.info(
      'SupabaseSyncService: Aplicativo voltou ao primeiro plano (resumed). Reavaliando conectividade...',
    );
    await SupabaseInitializer.checkConnectivity();
    if (SupabaseInitializer.currentState.isConnected ||
        clientOverride != null) {
      await retryPendingMediaDownloads();
      await processQueue(ignoreBackoff: true);
      await fetchRemoteChanges();
    }
  }

  /// Trata a recuperação explícita de conexão à internet.
  Future<void> handleReconnection() async {
    if (!isConfigured) return;
    final activeClient = client;
    if (activeClient == null) return;
    AppLogger.info(
      'SupabaseSyncService: Conexão restabelecida. Executando sincronização da outbox...',
    );
    await retryPendingMediaDownloads();
    await processQueue(ignoreBackoff: true);
    await fetchRemoteChanges();
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
    final activeClient = client;
    if (activeClient == null) return 0;

    final pendingRows = await (db.select(
      db.appKvStore,
    )..where((t) => t.key.like('pending_audio_download_%'))).get();

    int recovered = 0;
    for (final row in pendingRows) {
      final id = row.key.replaceFirst('pending_audio_download_', '');
      final ok = await _downloadVoiceNoteAudio(id, activeClient);
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
          await (db.select(db.syncQueue)
                ..where(
                  (t) =>
                      t.entityId.equals(id) &
                      (t.status.equals('pending') |
                          t.status.equals('in_progress') |
                          t.status.equals('failed') |
                          t.status.equals('conflict')),
                )
                ..orderBy([
                  (t) => drift.OrderingTerm(
                    expression: t.createdAt,
                    mode: drift.OrderingMode.desc,
                  ),
                ])
                ..limit(1))
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
    if (!isConfigured) {
      return SyncProcessResult(
        totalProcessed: pushResult.totalProcessed,
        successCount: pushResult.successCount,
        failureCount: pushResult.failureCount,
        conflictCount: pushResult.conflictCount,
        errors: pushResult.errors,
        message: 'Sincronização local preservada. Supabase não configurado para sincronização remota.',
      );
    }
    if (isOffline) {
      return SyncProcessResult(
        totalProcessed: pushResult.totalProcessed,
        successCount: pushResult.successCount,
        failureCount: pushResult.failureCount,
        conflictCount: pushResult.conflictCount,
        errors: pushResult.errors,
        message: 'Sincronização local preservada. Dispositivo offline para sincronização remota.',
      );
    }

    final pullResult = await fetchRemoteChanges();
    final allErrors = [...pushResult.errors, ...pullResult.errors];

    if (pullResult.message.contains('não configurado')) {
      return SyncProcessResult(
        totalProcessed: pushResult.totalProcessed + pullResult.totalProcessed,
        successCount: pushResult.successCount + pullResult.successCount,
        failureCount: pushResult.failureCount + pullResult.failureCount,
        conflictCount: pushResult.conflictCount + pullResult.conflictCount,
        errors: allErrors,
        message: 'Sincronização local preservada. Supabase não configurado para sincronização remota.',
      );
    }

    if (pullResult.message.contains('suspensa') ||
        pullResult.message.contains('offline')) {
      return SyncProcessResult(
        totalProcessed: pushResult.totalProcessed + pullResult.totalProcessed,
        successCount: pushResult.successCount + pullResult.successCount,
        failureCount: pushResult.failureCount + pullResult.failureCount,
        conflictCount: pushResult.conflictCount + pullResult.conflictCount,
        errors: allErrors,
        message: 'Sincronização local preservada. Dispositivo offline para sincronização remota.',
      );
    }

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
    if (_activeFetchCompleter != null && !_activeFetchCompleter!.isCompleted) {
      AppLogger.debug(
        'SupabaseSyncService: fetchRemoteChanges já em andamento, aguardando término...',
      );
      return _activeFetchCompleter!.future;
    }

    final completer = Completer<SyncProcessResult>();
    _activeFetchCompleter = completer;
    _isFetchingRemote = true;

    try {
      final result = await _executeFetchRemoteChanges();
      completer.complete(result);
      return result;
    } catch (e, st) {
      completer.completeError(e, st);
      rethrow;
    } finally {
      _isFetchingRemote = false;
      _activeFetchCompleter = null;
    }
  }

  Future<SyncProcessResult> _executeFetchRemoteChanges() async {
    if (!isConfigured) {
      return const SyncProcessResult(
        totalProcessed: 0,
        successCount: 0,
        failureCount: 0,
        conflictCount: 0,
        message: 'Supabase não configurado. Busca remota suspensa.',
      );
    }

    if (isOffline) {
      _setStatus(SyncStatus.waitingConnection);
      return const SyncProcessResult(
        totalProcessed: 0,
        successCount: 0,
        failureCount: 0,
        conflictCount: 0,
        message: 'Dispositivo offline. Busca remota suspensa.',
      );
    }

    final activeClient = client;
    if (activeClient == null) {
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
    bool encounteredNetworkError = false;
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
          var query = activeClient.from(table).select();
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
              client: activeClient,
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
        if (_isNetworkError(e)) {
          encounteredNetworkError = true;
          _setStatus(SyncStatus.waitingConnection);
          if (clientOverride == null) {
            SupabaseInitializer.setDisconnectedDueToNetwork(
              'Falha de rede durante busca remota: $e',
            );
          }
          break;
        } else {
          _setStatus(SyncStatus.error);
        }
      }
    }

    if (encounteredNetworkError) {
      _setStatus(SyncStatus.waitingConnection);
    } else if (conflictCount > 0) {
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
  Future<SyncProcessResult> processQueue({bool ignoreBackoff = false}) async {
    if (_activeSyncCompleter != null && !_activeSyncCompleter!.isCompleted) {
      AppLogger.debug(
        'SupabaseSyncService: processQueue já em andamento, aguardando término...',
      );
      return _activeSyncCompleter!.future;
    }

    final completer = Completer<SyncProcessResult>();
    _activeSyncCompleter = completer;
    _isSyncing = true;

    try {
      final result = await _executeProcessQueue(ignoreBackoff: ignoreBackoff);
      completer.complete(result);
      return result;
    } catch (e, st) {
      completer.completeError(e, st);
      rethrow;
    } finally {
      _isSyncing = false;
      _activeSyncCompleter = null;
    }
  }

  Future<SyncProcessResult> _executeProcessQueue({
    bool ignoreBackoff = false,
  }) async {
    if (!isConfigured) {
      _setStatus(SyncStatus.savedLocally);
      final pendingOps = await repository.getPendingSyncOperations();
      return SyncProcessResult(
        totalProcessed: pendingOps.length,
        successCount: 0,
        failureCount: 0,
        conflictCount: 0,
        message: pendingOps.isEmpty
            ? 'Supabase não configurado. Modo offline local ativo.'
            : 'Supabase não configurado. ${pendingOps.length} registros mantidos salvos localmente no SQLite.',
      );
    }

    if (isOffline) {
      _setStatus(SyncStatus.waitingConnection);
      final pendingOps = await repository.getPendingSyncOperations();
      return SyncProcessResult(
        totalProcessed: pendingOps.length,
        successCount: 0,
        failureCount: 0,
        conflictCount: 0,
        message: pendingOps.isEmpty
            ? 'Dispositivo offline. Modo offline local ativo.'
            : 'Dispositivo offline. ${pendingOps.length} registros mantidos salvos localmente no SQLite.',
      );
    }

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

    final activeClient = client;
    if (activeClient == null) {
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

    _setStatus(SyncStatus.syncing);

    int success = 0;
    int failure = 0;
    int conflicts = 0;
    bool encounteredNetworkError = false;
    final List<String> errors = [];

    for (final op in pendingOps) {
      if (op.attempts >= 5) {
        failure++;
        errors.add(
          'Operação ${op.id} (${op.entityType}) excedeu o limite máximo de 5 tentativas.',
        );
        continue;
      }

      if (!ignoreBackoff) {
        final backoffSeconds = calculateBackoffSeconds(op.attempts);
        final now = DateTime.now();
        final lastAttempt = _lastAttemptTime[op.id] ?? op.createdAt;
        if (op.attempts > 0 &&
            now.difference(lastAttempt).inSeconds < backoffSeconds) {
          continue;
        }
      }

      try {
        final Map<String, dynamic> rawPayload =
            jsonDecode(op.payload) as Map<String, dynamic>;
        final cleanPayload = sanitizePayload(op.entityType, rawPayload);
        final tableName = mapEntityToRemoteTable(op.entityType);
        final operation = op.operation.toUpperCase();

        if (operation == 'INSERT' || operation == 'UPDATE') {
          final remotePayload = toRemotePayload(op.entityType, cleanPayload);
          await activeClient.from(tableName).upsert(remotePayload);

          if (tableName == 'voice_notes') {
            final audioOk = await _uploadVoiceNoteAudio(
              op.entityId,
              activeClient,
              errors,
            );
            if (!audioOk) {
              failure++;
              _lastAttemptTime[op.id] = DateTime.now();
              await repository.markSyncOperationFailed(
                op.id,
                'Falha no upload do arquivo binário de áudio para o Storage',
              );
              continue;
            }
          }

          await repository.markSyncOperationSuccess(op.id);
          _lastAttemptTime.remove(op.id);
          success++;
        } else if (operation == 'DELETE') {
          await activeClient.from(tableName).delete().eq('id', op.entityId);
          await repository.markSyncOperationSuccess(op.id);
          _lastAttemptTime.remove(op.id);
          success++;
        }
      } on PostgrestException catch (e) {
        _lastAttemptTime[op.id] = DateTime.now();
        if (e.code == '23505' || e.code == '409') {
          conflicts++;
          _setStatus(SyncStatus.conflict);
          final err =
              'Conflito detectado na operação ${op.id} (${op.entityType}): ${e.message}';
          errors.add(err);
          await repository.markSyncOperationFailed(op.id, err);
        } else if (_isTransientPostgrestError(e) || _isNetworkError(e)) {
          encounteredNetworkError = true;
          _setStatus(SyncStatus.waitingConnection);
          SupabaseInitializer.setDisconnectedDueToNetwork(
            'Instabilidade temporária no servidor Supabase (${e.code ?? e.message})',
          );
          failure++;
          final err =
              'Instabilidade no servidor PostgREST na operação ${op.id} (${op.entityType}): ${e.message}';
          errors.add(err);
          await repository.markSyncOperationFailed(op.id, err);
          break;
        } else {
          failure++;
          final err =
              'Erro PostgREST na operação ${op.id} (${op.entityType}): ${e.message}';
          errors.add(err);
          await repository.markSyncOperationFailed(op.id, err);
        }
      } catch (e) {
        _lastAttemptTime[op.id] = DateTime.now();
        failure++;
        final err = 'Erro na operação ${op.id} (${op.entityType}): $e';
        errors.add(err);
        await repository.markSyncOperationFailed(op.id, err);
        if (_isNetworkError(e)) {
          encounteredNetworkError = true;
          _setStatus(SyncStatus.waitingConnection);
          SupabaseInitializer.setDisconnectedDueToNetwork(
            'Falha de rede durante sincronização: $e',
          );
          break; // Aborta imediatamente o lote sem queimar tentativas dos itens seguintes
        }
      }
    }

    if (encounteredNetworkError) {
      _setStatus(SyncStatus.waitingConnection);
    } else if (conflicts > 0) {
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

  static bool _isTransientPostgrestError(PostgrestException e) {
    final code = e.code?.trim() ?? '';
    final codeNum = int.tryParse(code);
    if (codeNum != null && codeNum >= 500 && codeNum <= 599) {
      return true;
    }
    if (code == '500' || code == '502' || code == '503' || code == '504') {
      return true;
    }

    final text = '${e.message} ${e.details ?? ''} ${e.hint ?? ''}'
        .toLowerCase();
    return text.contains('500') ||
        text.contains('502') ||
        text.contains('503') ||
        text.contains('504') ||
        text.contains('bad gateway') ||
        text.contains('gateway timeout') ||
        text.contains('gateway time-out') ||
        text.contains('service unavailable') ||
        text.contains('internal server error') ||
        text.contains('server error') ||
        text.contains('cloudflare') ||
        text.contains('upstream connect') ||
        text.contains('connection refused') ||
        text.contains('connection reset') ||
        text.contains('temporarily unavailable') ||
        text.contains('timed out') ||
        text.contains('timeout');
  }

  static bool _isNetworkError(Object error) {
    final str = error.toString().toLowerCase();
    return str.contains('socketexception') ||
        str.contains('network') ||
        str.contains('connection refused') ||
        str.contains('failed host lookup') ||
        str.contains('clientexception') ||
        str.contains('timeoutexception') ||
        str.contains('handshakeexception') ||
        str.contains('os error') ||
        str.contains('timed out');
  }

  void dispose() {
    stopLifecycleObservation();
    if (!_statusController.isClosed) {
      _statusController.close();
    }
  }
}

/// Provider do serviço de sincronização do Supabase
final supabaseSyncServiceProvider = Provider<SupabaseSyncService>((ref) {
  final repo = ref.watch(repositoryProvider);
  final config = ref.watch(appConfigProvider);
  final service = SupabaseSyncService(
    db: repo.db,
    repository: repo,
    config: config,
  );
  service.startLifecycleObservation();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Stream provider do status reativo de sincronização
final syncStatusStreamProvider = StreamProvider<SyncStatus>((ref) {
  final syncService = ref.watch(supabaseSyncServiceProvider);
  return syncService.statusStream;
});
