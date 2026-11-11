import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_logger.dart';
import '../core/sync_timestamp.dart';
import '../database/app_database.dart';
import '../database/repository.dart';
import '../ui/providers.dart';
import 'media_bytes.dart';
import 'sync_engine.dart';
import 'supabase_config.dart';

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
  static const String runtimeUrlStorageKey = 'runtime_supabase_url';
  static const String runtimeAnonKeyStorageKey = 'runtime_supabase_anon_key';

  static bool get isInitialized {
    try {
      Supabase.instance.client;
      return true;
    } catch (e) {
      AppLogger.debug('Supabase ainda não inicializado: $e');
      return false;
    }
  }

  /// Valida URL e Anon Key do projeto Supabase antes de inicializar ou salvar.
  static String? validateSupabaseCredentials(String url, String anonKey) {
    final cleanUrl = url.trim();
    final cleanKey = anonKey.trim();
    if (cleanUrl.isEmpty) {
      return 'Informe a URL do projeto Supabase (ex: https://xyz.supabase.co).';
    }
    final uri = Uri.tryParse(cleanUrl);
    final isLocalHost =
        uri != null &&
        uri.scheme == 'http' &&
        (uri.host == 'localhost' || uri.host == '127.0.0.1');
    final isHttps = uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
    if ((!isHttps && !isLocalHost) || cleanUrl.contains('your-supabase-url')) {
      return 'URL Supabase inválida. Utilize https://seu-projeto.supabase.co.';
    }
    if (cleanKey.isEmpty ||
        cleanKey.length < 20 ||
        cleanKey.contains('your-anon-key')) {
      return 'Chave Anon/Publishable inválida ou muito curta.';
    }
    return null;
  }

  /// Carrega credenciais Supabase configuradas em runtime no armazenamento seguro.
  static Future<({String url, String anonKey})?> loadRuntimeConfig({
    FlutterSecureStorage? storage,
  }) async {
    try {
      final secure = storage ?? const FlutterSecureStorage();
      final url = (await secure.read(key: runtimeUrlStorageKey))?.trim() ?? '';
      final key = (await secure.read(key: runtimeAnonKeyStorageKey))?.trim() ?? '';
      if (url.isEmpty || key.isEmpty) return null;
      if (validateSupabaseCredentials(url, key) != null) return null;
      return (url: url, anonKey: key);
    } catch (e, st) {
      AppLogger.warning('Falha ao ler configuração runtime do Supabase', e, st);
      return null;
    }
  }

  static Future<String?> getRuntimeUrl({FlutterSecureStorage? storage}) async {
    final cfg = await loadRuntimeConfig(storage: storage);
    return cfg?.url;
  }

  static Future<bool> hasRuntimeConfig({FlutterSecureStorage? storage}) async {
    return (await loadRuntimeConfig(storage: storage)) != null;
  }

  static Future<void> initialize({FlutterSecureStorage? storage}) async {
    String url = SupabaseConfig.url.trim();
    String anonKey = SupabaseConfig.publishableKey.trim();

    if (!SupabaseConfig.isConfigured) {
      final runtimeCfg = await loadRuntimeConfig(storage: storage);
      if (runtimeCfg == null) {
        AppLogger.info(
          'Supabase não configurado via --dart-define nem em runtime; operando exclusivamente offline-first.',
        );
        return;
      }
      url = runtimeCfg.url;
      anonKey = runtimeCfg.anonKey;
    }

    if (!isInitialized) {
      await Supabase.initialize(
        url: url,
        publishableKey: anonKey,
      );
    }
  }

  /// Salva credenciais Supabase em runtime no armazenamento seguro e (re)inicializa o cliente.
  static Future<void> configureAndInitialize({
    required String url,
    required String anonKey,
    FlutterSecureStorage? storage,
    bool initializeClient = true,
  }) async {
    final cleanUrl = url.trim();
    final cleanKey = anonKey.trim();
    final validationError = validateSupabaseCredentials(cleanUrl, cleanKey);
    if (validationError != null) {
      throw FormatException(validationError);
    }

    final secure = storage ?? const FlutterSecureStorage();
    if (initializeClient) {
      if (isInitialized) {
        await Supabase.instance.dispose();
      }
      await Supabase.initialize(
        url: cleanUrl,
        publishableKey: cleanKey,
      );
    }

    await secure.write(key: runtimeUrlStorageKey, value: cleanUrl);
    await secure.write(key: runtimeAnonKeyStorageKey, value: cleanKey);
  }

  /// Remove a configuração runtime do Supabase do armazenamento seguro.
  static Future<void> clearRuntimeConfig({
    FlutterSecureStorage? storage,
    bool disposeClientIfNoCompileTime = true,
  }) async {
    final secure = storage ?? const FlutterSecureStorage();
    await secure.delete(key: runtimeUrlStorageKey);
    await secure.delete(key: runtimeAnonKeyStorageKey);
    if (isInitialized &&
        (disposeClientIfNoCompileTime || SupabaseConfig.isConfigured)) {
      await Supabase.instance.dispose();
    }
  }

  final AppDatabase db;
  final AppRepository repository;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final SupabaseClient? clientOverride;
  final Future<String> Function()? documentsDirectoryProvider;
  final bool strictStorageAuth;

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
    'family_ties',
    'ministry_experiences',
    'person_photos',
    'person_publications',
    'research_articles',
    'research_tags',
    'territory_sectors',
    'inbox_entries',
    'projects',
    'tasks',
    'knowledge_notes',
    'knowledge_questions',
    'knowledge_documents',
    'knowledge_resources',
    'ticuna_words',
    'ticuna_phrases',
  ];

  SupabaseSyncService({
    required this.db,
    required this.repository,
    this.supabaseUrl = const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: '',
    ),
    this.supabaseAnonKey = const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: '',
    ),
    this.clientOverride,
    this.documentsDirectoryProvider,
    this.strictStorageAuth = false,
  });

  SyncStatus get currentStatus => _currentStatus;
  Stream<SyncStatus> get statusStream => _statusController.stream;

  bool get isConfigured {
    if (clientOverride != null) return true;
    final url = supabaseUrl.trim();
    final key = supabaseAnonKey.trim();
    if (url.isEmpty || key.isEmpty) return isInitialized;
    if (url.contains('your-supabase-url') || key.contains('your-anon-key')) {
      return false;
    }
    return true;
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
    sanitized.remove('_remote');
    sanitized.remove('_conflicts');
    if (entityType == 'voice_notes' || entityType == 'voiceNotes') {
      sanitized.remove('audio_file_path');
      sanitized.remove('audioFilePath');
    }
    return sanitized;
  }

  static const Set<String> _jsonbColumns = {
    'tags',
    'attachments',
    'metadata',
    'sources',
    'media_urls',
    'participant_ids',
  };

  /// Converte payload com chaves camelCase para snake_case para envio PostgREST
  static Map<String, dynamic> toRemotePayload(
    String entityType,
    Map<String, dynamic> localPayload,
  ) {
    final normalizedDates = SyncTimestamp.normalizeMapDates(
      sanitizePayload(entityType, localPayload),
    );
    final Map<String, dynamic> remote = {};
    normalizedDates.forEach((key, value) {
      final snakeKey = key == 'dateTimeField' ? 'date_time_field' : camelToSnake(key);
      if (_jsonbColumns.contains(snakeKey) && value is String) {
        final trimmed = value.trim();
        if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
          try {
            remote[snakeKey] = jsonDecode(trimmed);
            return;
          } catch (e, st) {
            AppLogger.debug('Campo JSONB ($snakeKey) inválido mantido como string: $e', st);
          }
        }
      }
      remote[snakeKey] = value;
    });
    if (entityType == 'ticuna_words' ||
        entityType == 'ticuna_phrases' ||
        entityType == 'ticunaWords' ||
        entityType == 'ticunaPhrases') {
      final audioPath = remote['audio_path']?.toString();
      if (audioPath != null && audioPath.isNotEmpty && !audioPath.startsWith('http')) {
        final id = remote['id']?.toString() ?? '';
        remote['audio_path'] = '${id}_pronunciation.m4a';
      }
      if (remote.containsKey('is_favorite') && remote['is_favorite'] is bool) {
        remote['is_favorite'] = (remote['is_favorite'] as bool) ? 1 : 0;
      }
    }
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
      if (value is List || value is Map) {
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
      case 'researchtag':
      case 'researchtags':
      case 'research_tag':
      case 'research_tags':
        return 'research_tags';
      case 'researcharticle':
      case 'researcharticles':
      case 'research_article':
      case 'research_articles':
        return 'research_articles';
      case 'territorysector':
      case 'territorysectors':
      case 'territory_sector':
      case 'territory_sectors':
        return 'territory_sectors';
      case 'familytie':
      case 'familyties':
      case 'family_tie':
      case 'family_ties':
        return 'family_ties';
      case 'ministryexperience':
      case 'ministryexperiences':
      case 'ministry_experience':
      case 'ministry_experiences':
        return 'ministry_experiences';
      case 'personpublication':
      case 'personpublications':
      case 'person_publication':
      case 'person_publications':
        return 'person_publications';
      case 'personphoto':
      case 'personphotos':
      case 'person_photo':
      case 'person_photos':
        return 'person_photos';
      default:
        return entityType.toLowerCase();
    }
  }

  static String? _isoString(dynamic val) {
    return SyncTimestamp.toIso8601String(val);
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
      case 'family_ties':
        map['personId'] = map['personId'] ?? map['person_id'] ?? '';
        map['relatedPersonId'] =
            map['relatedPersonId'] ?? map['related_person_id'];
        map['relatedPersonName'] =
            map['relatedPersonName'] ?? map['related_person_name'] ?? '';
        map['relationshipType'] =
            map['relationshipType'] ?? map['relationship_type'] ?? '';
        break;
      case 'ministry_experiences':
        map['title'] = map['title'] ?? '';
        map['content'] = map['content'] ?? '';
        map['dateTimeField'] = _isoString(map['dateTimeField']) ??
            _isoString(map['dateTime']) ??
            _isoString(map['date_time_field']) ??
            _isoString(map['date_time']) ??
            map['createdAt'];
        if (map['mediaUrls'] is List) {
          map['mediaUrls'] = jsonEncode(map['mediaUrls']);
        }
        if (map['media_urls'] is List) {
          map['mediaUrls'] = jsonEncode(map['media_urls']);
        }
        map['mediaUrls'] ??= '[]';
        if (map['tags'] is List) {
          map['tags'] = jsonEncode(map['tags']);
        }
        map['tags'] ??= '[]';
        map['locationOrModality'] =
            map['locationOrModality'] ?? map['location_or_modality'];
        break;
      case 'person_photos':
        map['personId'] = map['personId'] ?? map['person_id'] ?? '';
        map['photoType'] = map['photoType'] ?? map['photo_type'] ?? 'person';
        map['filePath'] = map['filePath'] ?? map['file_path'];
        map['imageData'] = map['imageData'] ?? map['image_data'] ?? '';
        break;
      case 'person_publications':
        map['personId'] = map['personId'] ?? map['person_id'] ?? '';
        map['publicationTitle'] =
            map['publicationTitle'] ?? map['publication_title'] ?? '';
        map['itemType'] = map['itemType'] ?? map['item_type'] ?? 'entregue';
        map['status'] = map['status'] ?? 'entregue';
        map['date'] = _isoString(map['date']) ?? map['createdAt'];
        map['notes'] = map['notes'];
        break;
      case 'research_articles':
        map['title'] = map['title'] ?? '';
        map['summary'] = map['summary'] ?? '';
        map['content'] = map['content'] ?? '';
        if (map['tags'] is List) {
          map['tags'] = jsonEncode(map['tags']);
        }
        map['tags'] ??= '[]';
        if (map['attachments'] is List) {
          map['attachments'] = jsonEncode(map['attachments']);
        }
        map['attachments'] ??= '[]';
        break;
      case 'research_tags':
        map['name'] = map['name'] ?? '';
        break;
      case 'territory_sectors':
        map['name'] = map['name'] ?? '';
        map['description'] = map['description'];
        break;
      case 'ticuna_words':
        map['word'] = map['word'] ?? '';
        map['translation'] = map['translation'] ?? '';
        if (map['tags'] is List) {
          map['tags'] = jsonEncode(map['tags']);
        }
        map['tags'] ??= '[]';
        break;
      case 'ticuna_phrases':
        map['phrase'] = map['phrase'] ?? '';
        map['translation'] = map['translation'] ?? '';
        if (map['tags'] is List) {
          map['tags'] = jsonEncode(map['tags']);
        }
        map['tags'] ??= '[]';
        break;
      case 'inbox_entries':
        if (map['attachments'] is List) map['attachments'] = jsonEncode(map['attachments']);
        map['attachments'] ??= '[]';
        if (map['metadata'] is Map) map['metadata'] = jsonEncode(map['metadata']);
        map['metadata'] ??= '{}';
        break;
      case 'projects':
        if (map['metadata'] is Map) map['metadata'] = jsonEncode(map['metadata']);
        map['metadata'] ??= '{}';
        break;
      case 'tasks':
        if (map['attachments'] is List) map['attachments'] = jsonEncode(map['attachments']);
        map['attachments'] ??= '[]';
        if (map['metadata'] is Map) map['metadata'] = jsonEncode(map['metadata']);
        map['metadata'] ??= '{}';
        break;
      case 'knowledge_notes':
        if (map['tags'] is List) map['tags'] = jsonEncode(map['tags']);
        map['tags'] ??= '[]';
        if (map['attachments'] is List) map['attachments'] = jsonEncode(map['attachments']);
        map['attachments'] ??= '[]';
        if (map['sources'] is List) map['sources'] = jsonEncode(map['sources']);
        map['sources'] ??= '[]';
        break;
      case 'knowledge_questions':
        break;
      case 'knowledge_documents':
        if (map['tags'] is List) map['tags'] = jsonEncode(map['tags']);
        map['tags'] ??= '[]';
        break;
      case 'knowledge_resources':
        if (map['tags'] is List) map['tags'] = jsonEncode(map['tags']);
        map['tags'] ??= '[]';
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
      case 'family_ties':
        await db.into(db.familyTies).insert(FamilyTieEntry.fromJson(map));
        break;
      case 'ministry_experiences':
        await db
            .into(db.ministryExperiences)
            .insert(MinistryExperienceEntry.fromJson(map));
        break;
      case 'person_photos':
        await db.into(db.personPhotos).insert(PersonPhotoEntry.fromJson(map));
        break;
      case 'person_publications':
        await db
            .into(db.personPublications)
            .insert(PersonPublicationEntry.fromJson(map));
        break;
      case 'research_articles':
        await db
            .into(db.researchArticles)
            .insert(ResearchArticleEntry.fromJson(map));
        break;
      case 'research_tags':
        await db.into(db.researchTags).insert(ResearchTagEntry.fromJson(map));
        break;
      case 'territory_sectors':
        await db
            .into(db.territorySectors)
            .insert(TerritorySectorEntry.fromJson(map));
        break;
      case 'inbox_entries':
        await db.into(db.inboxEntries).insert(InboxEntry.fromJson(map));
        break;
      case 'projects':
        await db.into(db.projects).insert(ProjectEntry.fromJson(map));
        break;
      case 'tasks':
        await db.into(db.tasks).insert(TaskEntry.fromJson(map));
        break;
      case 'knowledge_notes':
        await db.into(db.knowledgeNotes).insert(KnowledgeNoteEntry.fromJson(map));
        break;
      case 'knowledge_questions':
        await db.into(db.knowledgeQuestions).insert(KnowledgeQuestionEntry.fromJson(map));
        break;
      case 'knowledge_documents':
        await db.into(db.knowledgeDocuments).insert(KnowledgeDocumentEntry.fromJson(map));
        break;
      case 'knowledge_resources':
        await db.into(db.knowledgeResources).insert(KnowledgeResourceEntry.fromJson(map));
        break;
      case 'ticuna_words':
        await db.customInsert(
          'INSERT OR REPLACE INTO ticuna_words (id, word, translation, phonetics, grammatical_class, example_sentence, example_translation, notes, tags, is_favorite, review_level, review_count, last_reviewed_at, audio_path, audio_duration_seconds, language_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          variables: [
            drift.Variable.withString(map['id']?.toString() ?? ''),
            drift.Variable.withString(map['word']?.toString() ?? ''),
            drift.Variable.withString(map['translation']?.toString() ?? ''),
            drift.Variable.withString(map['phonetics']?.toString() ?? ''),
            drift.Variable.withString(map['grammatical_class']?.toString() ?? map['grammaticalClass']?.toString() ?? ''),
            drift.Variable.withString(map['example_sentence']?.toString() ?? map['exampleSentence']?.toString() ?? ''),
            drift.Variable.withString(map['example_translation']?.toString() ?? map['exampleTranslation']?.toString() ?? ''),
            drift.Variable.withString(map['notes']?.toString() ?? ''),
            drift.Variable.withString(map['tags'] is List ? jsonEncode(map['tags']) : (map['tags']?.toString() ?? '[]')),
            drift.Variable.withInt((map['is_favorite'] == 1 || map['is_favorite'] == true || map['isFavorite'] == 1 || map['isFavorite'] == true) ? 1 : 0),
            drift.Variable.withInt((map['review_level'] as num?)?.toInt() ?? (map['reviewLevel'] as num?)?.toInt() ?? 0),
            drift.Variable.withInt((map['review_count'] as num?)?.toInt() ?? (map['reviewCount'] as num?)?.toInt() ?? 0),
            drift.Variable.withString(map['last_reviewed_at']?.toString() ?? map['lastReviewedAt']?.toString() ?? ''),
            drift.Variable.withString(map['audio_path']?.toString() ?? map['audioPath']?.toString() ?? ''),
            drift.Variable.withInt((map['audio_duration_seconds'] as num?)?.toInt() ?? (map['audioDurationSeconds'] as num?)?.toInt() ?? 0),
            drift.Variable.withString(map['language_id']?.toString() ?? map['languageId']?.toString() ?? 'tca'),
            drift.Variable.withString(_isoString(map['created_at'] ?? map['createdAt']) ?? DateTime.now().toIso8601String()),
            drift.Variable.withString(_isoString(map['updated_at'] ?? map['updatedAt']) ?? DateTime.now().toIso8601String()),
          ],
        );
        break;
      case 'ticuna_phrases':
        await db.customInsert(
          'INSERT OR REPLACE INTO ticuna_phrases (id, phrase, translation, category, phonetics, notes, tags, is_favorite, audio_path, audio_duration_seconds, language_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          variables: [
            drift.Variable.withString(map['id']?.toString() ?? ''),
            drift.Variable.withString(map['phrase']?.toString() ?? ''),
            drift.Variable.withString(map['translation']?.toString() ?? ''),
            drift.Variable.withString(map['category']?.toString() ?? ''),
            drift.Variable.withString(map['phonetics']?.toString() ?? ''),
            drift.Variable.withString(map['notes']?.toString() ?? ''),
            drift.Variable.withString(map['tags'] is List ? jsonEncode(map['tags']) : (map['tags']?.toString() ?? '[]')),
            drift.Variable.withInt((map['is_favorite'] == 1 || map['is_favorite'] == true || map['isFavorite'] == 1 || map['isFavorite'] == true) ? 1 : 0),
            drift.Variable.withString(map['audio_path']?.toString() ?? map['audioPath']?.toString() ?? ''),
            drift.Variable.withInt((map['audio_duration_seconds'] as num?)?.toInt() ?? (map['audioDurationSeconds'] as num?)?.toInt() ?? 0),
            drift.Variable.withString(map['language_id']?.toString() ?? map['languageId']?.toString() ?? 'tca'),
            drift.Variable.withString(_isoString(map['created_at'] ?? map['createdAt']) ?? DateTime.now().toIso8601String()),
            drift.Variable.withString(_isoString(map['updated_at'] ?? map['updatedAt']) ?? DateTime.now().toIso8601String()),
          ],
        );
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
      case 'family_ties':
        await db.update(db.familyTies).replace(FamilyTieEntry.fromJson(map));
        break;
      case 'ministry_experiences':
        await db
            .update(db.ministryExperiences)
            .replace(MinistryExperienceEntry.fromJson(map));
        break;
      case 'person_photos':
        await db.update(db.personPhotos).replace(PersonPhotoEntry.fromJson(map));
        break;
      case 'person_publications':
        await db
            .update(db.personPublications)
            .replace(PersonPublicationEntry.fromJson(map));
        break;
      case 'research_articles':
        await db
            .update(db.researchArticles)
            .replace(ResearchArticleEntry.fromJson(map));
        break;
      case 'research_tags':
        await db.update(db.researchTags).replace(ResearchTagEntry.fromJson(map));
        break;
      case 'territory_sectors':
        await db
            .update(db.territorySectors)
            .replace(TerritorySectorEntry.fromJson(map));
        break;
      case 'inbox_entries':
        await db.update(db.inboxEntries).replace(InboxEntry.fromJson(map));
        break;
      case 'projects':
        await db.update(db.projects).replace(ProjectEntry.fromJson(map));
        break;
      case 'tasks':
        await db.update(db.tasks).replace(TaskEntry.fromJson(map));
        break;
      case 'knowledge_notes':
        await db.update(db.knowledgeNotes).replace(KnowledgeNoteEntry.fromJson(map));
        break;
      case 'knowledge_questions':
        await db.update(db.knowledgeQuestions).replace(KnowledgeQuestionEntry.fromJson(map));
        break;
      case 'knowledge_documents':
        await db.update(db.knowledgeDocuments).replace(KnowledgeDocumentEntry.fromJson(map));
        break;
      case 'knowledge_resources':
        await db.update(db.knowledgeResources).replace(KnowledgeResourceEntry.fromJson(map));
        break;
      case 'ticuna_words':
        await db.customInsert(
          'INSERT OR REPLACE INTO ticuna_words (id, word, translation, phonetics, grammatical_class, example_sentence, example_translation, notes, tags, is_favorite, review_level, review_count, last_reviewed_at, audio_path, audio_duration_seconds, language_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          variables: [
            drift.Variable.withString(map['id']?.toString() ?? ''),
            drift.Variable.withString(map['word']?.toString() ?? ''),
            drift.Variable.withString(map['translation']?.toString() ?? ''),
            drift.Variable.withString(map['phonetics']?.toString() ?? ''),
            drift.Variable.withString(map['grammatical_class']?.toString() ?? map['grammaticalClass']?.toString() ?? ''),
            drift.Variable.withString(map['example_sentence']?.toString() ?? map['exampleSentence']?.toString() ?? ''),
            drift.Variable.withString(map['example_translation']?.toString() ?? map['exampleTranslation']?.toString() ?? ''),
            drift.Variable.withString(map['notes']?.toString() ?? ''),
            drift.Variable.withString(map['tags'] is List ? jsonEncode(map['tags']) : (map['tags']?.toString() ?? '[]')),
            drift.Variable.withInt((map['is_favorite'] == 1 || map['is_favorite'] == true || map['isFavorite'] == 1 || map['isFavorite'] == true) ? 1 : 0),
            drift.Variable.withInt((map['review_level'] as num?)?.toInt() ?? (map['reviewLevel'] as num?)?.toInt() ?? 0),
            drift.Variable.withInt((map['review_count'] as num?)?.toInt() ?? (map['reviewCount'] as num?)?.toInt() ?? 0),
            drift.Variable.withString(map['last_reviewed_at']?.toString() ?? map['lastReviewedAt']?.toString() ?? ''),
            drift.Variable.withString(map['audio_path']?.toString() ?? map['audioPath']?.toString() ?? ''),
            drift.Variable.withInt((map['audio_duration_seconds'] as num?)?.toInt() ?? (map['audioDurationSeconds'] as num?)?.toInt() ?? 0),
            drift.Variable.withString(map['language_id']?.toString() ?? map['languageId']?.toString() ?? 'tca'),
            drift.Variable.withString(_isoString(map['created_at'] ?? map['createdAt']) ?? DateTime.now().toIso8601String()),
            drift.Variable.withString(_isoString(map['updated_at'] ?? map['updatedAt']) ?? DateTime.now().toIso8601String()),
          ],
        );
        break;
      case 'ticuna_phrases':
        await db.customInsert(
          'INSERT OR REPLACE INTO ticuna_phrases (id, phrase, translation, category, phonetics, notes, tags, is_favorite, audio_path, audio_duration_seconds, language_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          variables: [
            drift.Variable.withString(map['id']?.toString() ?? ''),
            drift.Variable.withString(map['phrase']?.toString() ?? ''),
            drift.Variable.withString(map['translation']?.toString() ?? ''),
            drift.Variable.withString(map['category']?.toString() ?? ''),
            drift.Variable.withString(map['phonetics']?.toString() ?? ''),
            drift.Variable.withString(map['notes']?.toString() ?? ''),
            drift.Variable.withString(map['tags'] is List ? jsonEncode(map['tags']) : (map['tags']?.toString() ?? '[]')),
            drift.Variable.withInt((map['is_favorite'] == 1 || map['is_favorite'] == true || map['isFavorite'] == 1 || map['isFavorite'] == true) ? 1 : 0),
            drift.Variable.withString(map['audio_path']?.toString() ?? map['audioPath']?.toString() ?? ''),
            drift.Variable.withInt((map['audio_duration_seconds'] as num?)?.toInt() ?? (map['audioDurationSeconds'] as num?)?.toInt() ?? 0),
            drift.Variable.withString(map['language_id']?.toString() ?? map['languageId']?.toString() ?? 'tca'),
            drift.Variable.withString(_isoString(map['created_at'] ?? map['createdAt']) ?? DateTime.now().toIso8601String()),
            drift.Variable.withString(_isoString(map['updated_at'] ?? map['updatedAt']) ?? DateTime.now().toIso8601String()),
          ],
        );
        break;
    }
  }

  Future<void> _softDeleteLocalEntry(
    String table,
    String id,
    dynamic deletedAtVal,
  ) async {
    final deletedAt = SyncTimestamp.parse(deletedAtVal) ?? DateTime.now();
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
      case 'family_ties':
        await (db.update(db.familyTies)..where((t) => t.id.equals(id))).write(
          FamilyTiesCompanion(deletedAt: drift.Value(deletedAt)),
        );
        break;
      case 'ministry_experiences':
        await (db.update(db.ministryExperiences)..where((t) => t.id.equals(id)))
            .write(
          MinistryExperiencesCompanion(deletedAt: drift.Value(deletedAt)),
        );
        break;
      case 'person_photos':
        await (db.update(db.personPhotos)..where((t) => t.id.equals(id))).write(
          PersonPhotosCompanion(deletedAt: drift.Value(deletedAt)),
        );
        break;
      case 'person_publications':
        await (db.update(db.personPublications)..where((t) => t.id.equals(id)))
            .write(
          PersonPublicationsCompanion(deletedAt: drift.Value(deletedAt)),
        );
        break;
      case 'research_articles':
        await (db.update(db.researchArticles)..where((t) => t.id.equals(id)))
            .write(
          ResearchArticlesCompanion(deletedAt: drift.Value(deletedAt)),
        );
        break;
      case 'research_tags':
        await (db.update(db.researchTags)..where((t) => t.id.equals(id))).write(
          ResearchTagsCompanion(deletedAt: drift.Value(deletedAt)),
        );
        break;
      case 'territory_sectors':
        await (db.update(db.territorySectors)..where((t) => t.id.equals(id)))
            .write(
          TerritorySectorsCompanion(deletedAt: drift.Value(deletedAt)),
        );
        break;
      case 'inbox_entries':
        await (db.update(db.inboxEntries)..where((t) => t.id.equals(id))).write(
          InboxEntriesCompanion(deletedAt: drift.Value(deletedAt)),
        );
        break;
      case 'projects':
        await (db.update(db.projects)..where((t) => t.id.equals(id))).write(
          ProjectsCompanion(deletedAt: drift.Value(deletedAt)),
        );
        break;
      case 'tasks':
        await (db.update(db.tasks)..where((t) => t.id.equals(id))).write(
          TasksCompanion(deletedAt: drift.Value(deletedAt)),
        );
        break;
      case 'knowledge_notes':
        await (db.update(db.knowledgeNotes)..where((t) => t.id.equals(id))).write(
          KnowledgeNotesCompanion(deletedAt: drift.Value(deletedAt)),
        );
        break;
      case 'knowledge_questions':
        await (db.update(db.knowledgeQuestions)..where((t) => t.id.equals(id))).write(
          KnowledgeQuestionsCompanion(deletedAt: drift.Value(deletedAt)),
        );
        break;
      case 'knowledge_documents':
        await (db.update(db.knowledgeDocuments)..where((t) => t.id.equals(id))).write(
          KnowledgeDocumentsCompanion(deletedAt: drift.Value(deletedAt)),
        );
        break;
      case 'knowledge_resources':
        await (db.update(db.knowledgeResources)..where((t) => t.id.equals(id))).write(
          KnowledgeResourcesCompanion(deletedAt: drift.Value(deletedAt)),
        );
        break;
      case 'ticuna_words':
        await db.customStatement('DELETE FROM ticuna_words WHERE id = ?', [id]);
        break;
      case 'ticuna_phrases':
        await db.customStatement('DELETE FROM ticuna_phrases WHERE id = ?', [id]);
        break;
    }
  }

  Future<Map<String, dynamic>?> _getLocalMap(String table, String id) async {
    final raw = await _getRawLocalMap(table, id);
    if (raw == null) return null;
    final normalized = normalizeRemotePayload(raw);
    return SyncTimestamp.normalizeMapDates(sanitizePayload(table, normalized));
  }

  Future<Map<String, dynamic>?> _getRawLocalMap(String table, String id) async {
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
      case 'family_ties':
        final row = await (db.select(
          db.familyTies,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        return row?.toJson();
      case 'ministry_experiences':
        final row = await (db.select(
          db.ministryExperiences,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        return row?.toJson();
      case 'person_photos':
        final row = await (db.select(
          db.personPhotos,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        return row?.toJson();
      case 'person_publications':
        final row = await (db.select(
          db.personPublications,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        return row?.toJson();
      case 'research_articles':
        final row = await (db.select(
          db.researchArticles,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        return row?.toJson();
      case 'research_tags':
        final row = await (db.select(
          db.researchTags,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        return row?.toJson();
      case 'territory_sectors':
        final row = await (db.select(
          db.territorySectors,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        return row?.toJson();
      case 'inbox_entries':
        final row = await (db.select(
          db.inboxEntries,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        return row?.toJson();
      case 'projects':
        final row = await (db.select(
          db.projects,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        return row?.toJson();
      case 'tasks':
        final row = await (db.select(
          db.tasks,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        return row?.toJson();
      case 'knowledge_notes':
        final row = await (db.select(
          db.knowledgeNotes,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        return row?.toJson();
      case 'knowledge_questions':
        final row = await (db.select(
          db.knowledgeQuestions,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        return row?.toJson();
      case 'knowledge_documents':
        final row = await (db.select(
          db.knowledgeDocuments,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        return row?.toJson();
      case 'knowledge_resources':
        final row = await (db.select(
          db.knowledgeResources,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        return row?.toJson();
      case 'ticuna_words':
        try {
          final rows = await db.customSelect(
            'SELECT * FROM ticuna_words WHERE id = ?',
            variables: [drift.Variable.withString(id)],
          ).get();
          if (rows.isEmpty) return null;
          return rows.first.data;
        } catch (e, st) {
          AppLogger.debug('Falha ao ler ticuna_words ($id) em _getRawLocalMap: $e', st);
          return null;
        }
      case 'ticuna_phrases':
        try {
          final rows = await db.customSelect(
            'SELECT * FROM ticuna_phrases WHERE id = ?',
            variables: [drift.Variable.withString(id)],
          ).get();
          if (rows.isEmpty) return null;
          return rows.first.data;
        } catch (e, st) {
          AppLogger.debug('Falha ao ler ticuna_phrases ($id) em _getRawLocalMap: $e', st);
          return null;
        }
      default:
        return null;
    }
  }

  /// Resolve a pasta correspondente ao UUID do usuário autenticado para armazenamento seguro.
  /// Retorna `null` quando não há sessão ativa em produção (evita pasta compartilhada 00000000-...).
  String? _resolveStorageFolder(SupabaseClient client) {
    final uid = client.auth.currentUser?.id ?? client.auth.currentSession?.user.id;
    if (uid != null && uid.isNotEmpty) {
      return uid;
    }
    if (clientOverride != null && !strictStorageAuth) {
      return 'test_mock_uid';
    }
    return null;
  }

  Future<String> _resolveBaseDocsDir() async {
    if (documentsDirectoryProvider != null) {
      return await documentsDirectoryProvider!();
    }
    return await resolveDefaultDocumentsDir();
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
        final bytes = await readMediaBytes(vn.audioFilePath!);
        if (bytes != null && bytes.isNotEmpty) {
          final userFolder = _resolveStorageFolder(client);
          if (userFolder == null) {
            errors.add(
              'Upload de áudio ($id) bloqueado: usuário não autenticado (sessão ausente).',
            );
            return false;
          }
          final rawFileName = id.endsWith('.m4a') ? id : '$id.m4a';
          final storagePath = '$userFolder/$rawFileName';
          await client.storage.from('voice_notes').uploadBinary(
                storagePath,
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

  Future<bool> _uploadTicunaAudio(
    String id,
    String entityType,
    Map<String, dynamic> cleanPayload,
    SupabaseClient client,
    List<String> errors,
  ) async {
    try {
      final audioPath = cleanPayload['audio_path']?.toString() ??
          cleanPayload['audioPath']?.toString();
      if (audioPath != null &&
          audioPath.isNotEmpty &&
          !audioPath.startsWith('http')) {
        final bytes = await readMediaBytes(audioPath);
        if (bytes != null && bytes.isNotEmpty) {
          final userFolder = _resolveStorageFolder(client);
          if (userFolder == null) {
            errors.add(
              'Upload de áudio Ticuna ($id) bloqueado: usuário não autenticado.',
            );
            return false;
          }
          final rawFileName = '${id}_pronunciation.m4a';
          final storagePath = '$userFolder/$rawFileName';
          try {
            await client.storage.from('ticuna_audio').uploadBinary(
                  storagePath,
                  bytes,
                  fileOptions: const FileOptions(upsert: true),
                );
          } catch (e1, st1) {
            AppLogger.error('Erro no upload de áudio Ticuna ($id) para ticuna_audio ($storagePath)', e1, st1);
            errors.add(
              'Erro no upload de áudio Ticuna ($id) no bucket ticuna_audio: $e1',
            );
            return false;
          }
        }
      }
      return true;
    } catch (e) {
      errors.add('Erro no upload de áudio Ticuna ($id): $e');
      return false;
    }
  }

  Future<bool> _downloadTicunaAudio(
    String id,
    String table,
    SupabaseClient client,
  ) async {
    try {
      final userFolder = _resolveStorageFolder(client);
      if (userFolder == null) {
        AppLogger.warning('Download de áudio Ticuna ($id) adiado: usuário não autenticado.');
        return false;
      }
      final rawFileName = '${id}_pronunciation.m4a';
      final storagePath = '$userFolder/$rawFileName';
      Uint8List? bytes;
      try {
        bytes = await client.storage.from('ticuna_audio').download(storagePath);
      } catch (e1) {
        AppLogger.debug('Fallback raiz ticuna_audio ($id): $e1');
        try {
          bytes = await client.storage.from('ticuna_audio').download(rawFileName);
        } catch (e2, st2) {
          AppLogger.debug('Falha no download de ticuna_audio ($id): $e2', st2);
        }
      }

      if (bytes != null && bytes.isNotEmpty) {
        final baseDir = await _resolveBaseDocsDir();
        final localFilePath = await saveMediaBytes(
          baseDir: baseDir,
          subDir: 'ticuna_audio',
          fileName: rawFileName,
          bytes: bytes,
          mimeType: 'audio/m4a',
        );
        if (localFilePath == null || localFilePath.isEmpty) {
          throw Exception('Falha ao salvar áudio Ticuna no dispositivo: $id');
        }

        if (table == 'ticuna_words') {
          await db.customUpdate(
            'UPDATE ticuna_words SET audio_path = ? WHERE id = ?',
            variables: [
              drift.Variable.withString(localFilePath),
              drift.Variable.withString(id),
            ],
          );
        } else if (table == 'ticuna_phrases') {
          await db.customUpdate(
            'UPDATE ticuna_phrases SET audio_path = ? WHERE id = ?',
            variables: [
              drift.Variable.withString(localFilePath),
              drift.Variable.withString(id),
            ],
          );
        }
        await (db.delete(db.appKvStore)
              ..where((t) => t.key.equals('pending_ticuna_audio_download_${table}_$id')))
            .go();
        return true;
      }
      throw Exception('Arquivo de áudio Ticuna não disponível no storage: $id');
    } catch (e, st) {
      AppLogger.warning('Falha no download de áudio Ticuna ($id)', e, st);
      try {
        await db.into(db.appKvStore).insertOnConflictUpdate(
              AppKvStoreCompanion.insert(
                key: 'pending_ticuna_audio_download_${table}_$id',
                value: DateTime.now().toUtc().toIso8601String(),
                updatedAt: drift.Value(DateTime.now()),
              ),
            );
      } catch (kvErr, kvSt) {
        AppLogger.warning('Falha ao registrar pending_ticuna_audio_download ($id)', kvErr, kvSt);
      }
      return false;
    }
  }

  Future<bool> _downloadVoiceNoteAudio(String id, SupabaseClient client) async {
    try {
      final userFolder = _resolveStorageFolder(client);
      if (userFolder == null) {
        AppLogger.warning('Download de áudio voice_note ($id) adiado: usuário não autenticado.');
        return false;
      }
      final rawFileName = id.endsWith('.m4a') ? id : '$id.m4a';
      final storagePath = '$userFolder/$rawFileName';
      Uint8List? bytes;
      try {
        bytes = await client.storage.from('voice_notes').download(storagePath);
      } catch (e1) {
        AppLogger.debug('Fallback raiz voice_notes ($storagePath): $e1');
        try {
          bytes = await client.storage.from('voice_notes').download(rawFileName);
        } catch (dlErr, dlSt) {
          AppLogger.debug('Fallback raiz voice_notes falhou ($rawFileName): $dlErr', dlSt);
        }
      }

      if (bytes != null && bytes.isNotEmpty) {
        final baseDir = await _resolveBaseDocsDir();
        final localFilePath = await saveMediaBytes(
          baseDir: baseDir,
          subDir: 'voice_notes',
          fileName: rawFileName,
          bytes: bytes,
          mimeType: 'audio/m4a',
        );
        if (localFilePath == null || localFilePath.isEmpty) {
          throw Exception('Falha ao salvar áudio de nota de voz: $id');
        }

        await (db.update(db.voiceNotes)..where((t) => t.id.equals(id))).write(
          VoiceNotesCompanion(audioFilePath: drift.Value(localFilePath)),
        );

        await (db.delete(
          db.appKvStore,
        )..where((t) => t.key.equals('pending_audio_download_$id'))).go();
        return true;
      }
      throw Exception('Arquivo de áudio não disponível para download no storage: $id');
    } catch (e, st) {
      AppLogger.warning('Falha no download de áudio voice_notes ($id)', e, st);
      try {
        await db.into(db.appKvStore).insertOnConflictUpdate(
              AppKvStoreCompanion.insert(
                key: 'pending_audio_download_$id',
                value: DateTime.now().toUtc().toIso8601String(),
                updatedAt: drift.Value(DateTime.now()),
              ),
            );
      } catch (kvErr, kvSt) {
        AppLogger.warning('Falha ao registrar pending_audio_download ($id)', kvErr, kvSt);
      }
      return false;
    }
  }

  /// Exclui o arquivo de áudio de uma nota de voz no Supabase Storage
  Future<bool> deleteVoiceNoteAudio(String id) async {
    if (!isConfigured) return false;
    SupabaseClient? client;
    try {
      client = clientOverride ?? Supabase.instance.client;
    } catch (e, st) {
      AppLogger.debug('Supabase client indisponível em deleteVoiceNoteAudio ($id): $e', st);
      return false;
    }
    return _deleteVoiceNoteAudio(id, client);
  }

  Future<bool> _deleteVoiceNoteAudio(String id, SupabaseClient client) async {
    try {
      final userFolder = _resolveStorageFolder(client);
      if (userFolder == null) return false;
      final rawFileName = id.endsWith('.m4a') ? id : '$id.m4a';
      await client.storage.from('voice_notes').remove([
        '$userFolder/$rawFileName',
        rawFileName,
      ]);
      return true;
    } catch (e, st) {
      AppLogger.debug('Falha ao excluir áudio voice_notes ($id): $e', st);
      return false;
    }
  }

  /// Exclui o arquivo de pronúncia Ticuna no Supabase Storage
  Future<bool> deleteTicunaAudio(String id) async {
    if (!isConfigured) return false;
    SupabaseClient? client;
    try {
      client = clientOverride ?? Supabase.instance.client;
    } catch (e, st) {
      AppLogger.debug('Supabase client indisponível em deleteTicunaAudio ($id): $e', st);
      return false;
    }
    return _deleteTicunaAudio(id, client);
  }

  Future<bool> _deleteTicunaAudio(String id, SupabaseClient client) async {
    try {
      final userFolder = _resolveStorageFolder(client);
      if (userFolder == null) return false;
      final rawFileName = '${id}_pronunciation.m4a';
      try {
        await client.storage.from('ticuna_audio').remove([
          '$userFolder/$rawFileName',
          rawFileName,
        ]);
      } on TypeError catch (e, st) {
        AppLogger.debug('Resposta não-lista ao remover ticuna_audio ($rawFileName): $e', st);
      }
      return true;
    } catch (e, st) {
      AppLogger.debug('Falha ao remover áudio Ticuna ($id): $e', st);
      return false;
    }
  }

  /// Realiza o upload do arquivo binário de um documento para o bucket privado knowledge_vault
  Future<bool> _uploadKnowledgeDocument(
    String id,
    SupabaseClient client,
    List<String> errors,
  ) async {
    try {
      final doc = await (db.select(
        db.knowledgeDocuments,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (doc == null) return true;

      Uint8List? bytes;

      // 1. Tenta carregar via camada multiplataforma (arquivo físico no IO ou URI na Web)
      if (doc.filePath.isNotEmpty) {
        try {
          bytes = await readMediaBytes(doc.filePath);
        } catch (e, st) {
          AppLogger.debug('Falha ao ler documento via filePath (${doc.filePath}): $e', st);
        }
      }

      if ((bytes == null || bytes.isEmpty) && !kIsWeb && doc.fileName.isNotEmpty) {
        final baseDir = await _resolveBaseDocsDir();
        if (baseDir.isNotEmpty) {
          for (final candidate in [
            '$baseDir/documents/${doc.fileName}',
            '$baseDir/${doc.fileName}',
          ]) {
            try {
              bytes = await readMediaBytes(candidate);
              if (bytes != null && bytes.isNotEmpty) break;
            } catch (e, st) {
              AppLogger.debug('Falha ao ler candidato knowledge_doc ($candidate): $e', st);
            }
          }
        }
      }

      // 2. Busca no AppKvStore (cache de bytes Web/portátil)
      if (bytes == null || bytes.isEmpty) {
        final kv = await (db.select(db.appKvStore)
              ..where((t) => t.key.equals('doc_bytes_$id')))
            .getSingleOrNull();
        if (kv != null && kv.value.isNotEmpty) {
          try {
            bytes = base64Decode(kv.value);
          } catch (e, st) {
            AppLogger.warning('Cache Base64 doc_bytes_$id corrompido', e, st);
          }
        }
      }

      if (bytes != null && bytes.isNotEmpty) {
        final userFolder = _resolveStorageFolder(client);
        if (userFolder == null) {
          errors.add(
            'Upload de documento ($id) bloqueado: usuário não autenticado.',
          );
          return false;
        }
        final extension = doc.fileType.isNotEmpty ? doc.fileType.replaceAll('.', '') : 'pdf';
        final storageFileName = '$id.$extension';
        final storagePath = '$userFolder/$storageFileName';

        await client.storage.from('knowledge_vault').uploadBinary(
              storagePath,
              bytes,
              fileOptions: const FileOptions(upsert: true),
            );
        return true;
      }
      return true;
    } catch (e) {
      errors.add('Erro no upload de documento para knowledge_vault ($id): $e');
      return false;
    }
  }

  /// Realiza o download do arquivo binário do knowledge_vault e salva no armazenamento local
  Future<bool> _downloadKnowledgeDocument(
    String id,
    SupabaseClient client,
  ) async {
    try {
      final doc = await (db.select(
        db.knowledgeDocuments,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (doc == null) return false;

      final userFolder = _resolveStorageFolder(client);
      if (userFolder == null) {
        AppLogger.warning('Download de documento ($id) adiado: usuário não autenticado.');
        return false;
      }
      final extension = doc.fileType.isNotEmpty ? doc.fileType.replaceAll('.', '') : 'pdf';
      final storageFileName = '$id.$extension';
      final storagePath = '$userFolder/$storageFileName';

      Uint8List? bytes;
      try {
        bytes = await client.storage.from('knowledge_vault').download(storagePath);
      } catch (e, st) {
        AppLogger.debug(
          'Download em $storagePath falhou; tentando caminho legado $storageFileName: $e',
          st,
        );
        try {
          bytes = await client.storage.from('knowledge_vault').download(storageFileName);
        } catch (dlErr, dlSt) {
          AppLogger.debug('Fallback raiz knowledge_vault falhou ($storageFileName): $dlErr', dlSt);
        }
      }

      if (bytes != null && bytes.isNotEmpty) {
        final baseDir = await _resolveBaseDocsDir();
        final safeName = doc.fileName.isNotEmpty ? doc.fileName : storageFileName;
        if (!kIsWeb && baseDir.isNotEmpty) {
          final localFilePath = await saveMediaBytes(
            baseDir: baseDir,
            subDir: 'documents',
            fileName: safeName,
            bytes: bytes,
          );
          if (localFilePath != null) {
            await (db.update(db.knowledgeDocuments)..where((t) => t.id.equals(id))).write(
              KnowledgeDocumentsCompanion(filePath: drift.Value(localFilePath)),
            );
          }
        } else {
          await db.into(db.appKvStore).insertOnConflictUpdate(
                AppKvStoreCompanion.insert(
                  key: 'doc_bytes_$id',
                  value: base64Encode(bytes),
                  updatedAt: drift.Value(DateTime.now()),
                ),
              );
        }

        await (db.delete(
          db.appKvStore,
        )..where((t) => t.key.equals('pending_doc_download_$id'))).go();
        return true;
      }
      throw Exception('Arquivo do documento não disponível para download no storage: $id');
    } catch (e, st) {
      AppLogger.warning('Falha no download de documento knowledge_vault ($id)', e, st);
      try {
        await db.into(db.appKvStore).insertOnConflictUpdate(
              AppKvStoreCompanion.insert(
                key: 'pending_doc_download_$id',
                value: DateTime.now().toUtc().toIso8601String(),
                updatedAt: drift.Value(DateTime.now()),
              ),
            );
      } catch (kvErr, kvSt) {
        AppLogger.warning('Falha ao registrar pending_doc_download ($id)', kvErr, kvSt);
      }
      return false;
    }
  }

  /// Exclui o arquivo físico no Supabase Storage quando o documento é removido
  Future<void> _deleteKnowledgeDocumentStorage(
    String id,
    SupabaseClient client,
  ) async {
    try {
      final userFolder = _resolveStorageFolder(client);
      if (userFolder == null) return;
      await client.storage.from('knowledge_vault').remove([
        '$userFolder/$id.pdf',
        '$userFolder/$id.epub',
        '$userFolder/$id.doc',
        '$userFolder/$id.docx',
        '$userFolder/$id.txt',
        '$userFolder/$id',
        '$id.pdf',
        id,
      ]);
      await (db.delete(db.appKvStore)..where((t) => t.key.equals('doc_bytes_$id'))).go();
    } catch (e, st) {
      AppLogger.warning('Falha ao excluir documento $id do storage', e, st);
    }
  }

  Future<bool> _uploadPersonPhoto(
    String id,
    Map<String, dynamic> remotePayload,
    SupabaseClient client,
    List<String> errors,
  ) async {
    try {
      final photo = await (db.select(db.personPhotos)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      final localPath = photo?.filePath;
      final inlineData = photo?.imageData ?? '';

      Uint8List? bytes;
      if (localPath != null &&
          localPath.isNotEmpty &&
          !localPath.startsWith('http')) {
        try {
          bytes = await readMediaBytes(localPath);
        } catch (e, st) {
          AppLogger.warning('Falha ao ler arquivo local da foto $id', e, st);
        }
      }

      if ((bytes == null || bytes.isEmpty) &&
          inlineData.startsWith('data:image/')) {
        final commaIdx = inlineData.indexOf(',');
        if (commaIdx != -1) {
          try {
            bytes = Uint8List.fromList(
              base64Decode(inlineData.substring(commaIdx + 1)),
            );
          } catch (e, st) {
            AppLogger.warning('Falha ao decodificar base64 da foto $id', e, st);
          }
        }
      }

      // Remove caminhos locais do dispositivo antes de enviar ao PostgREST
      final rawFp = remotePayload['file_path']?.toString() ?? '';
      if (rawFp.startsWith('/') ||
          RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(rawFp)) {
        remotePayload['file_path'] = null;
      }

      if (bytes == null || bytes.isEmpty) {
        return true;
      }

      final userFolder = _resolveStorageFolder(client);
      if (userFolder == null) {
        errors.add('Usuário não autenticado para upload da foto $id.');
        return false;
      }
      final storagePath = '$userFolder/$id.jpg';
      await client.storage.from('person_photos').uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      remotePayload['file_path'] = storagePath;
      remotePayload['image_data'] = '';
      return true;
    } catch (e, st) {
      AppLogger.warning('Falha no upload de person_photos ($id)', e, st);
      errors.add('Falha no upload da foto $id: $e');
      return false;
    }
  }

  Future<bool> _downloadPersonPhoto(String id, SupabaseClient client) async {
    try {
      final photo = await (db.select(db.personPhotos)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      final fp = photo?.filePath;
      if (fp == null || fp.isEmpty || fp.startsWith('http')) {
        return false;
      }
      if (fp.startsWith('/') || RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(fp)) {
        return true;
      }

      final userFolder = _resolveStorageFolder(client);
      final candidates = <String>{
        fp,
        if (userFolder != null) '$userFolder/$id.jpg',
        '$id.jpg',
      }.toList();

      Uint8List? bytes;
      for (final path in candidates) {
        try {
          final dl = await client.storage.from('person_photos').download(path);
          if (dl.isNotEmpty) {
            bytes = dl;
            break;
          }
        } catch (dlErr, dlSt) {
          AppLogger.debug('Tentativa de download person_photos ($path) falhou: $dlErr', dlSt);
        }
      }

      if (bytes != null && bytes.isNotEmpty) {
        if (!kIsWeb) {
          final baseDir = await _resolveBaseDocsDir();
          if (baseDir.isNotEmpty) {
            final localPath = await saveMediaBytes(
              baseDir: baseDir,
              subDir: 'person_photos',
              fileName: '$id.jpg',
              bytes: bytes,
            );
            if (localPath != null) {
              await (db.update(db.personPhotos)..where((t) => t.id.equals(id)))
                  .write(
                PersonPhotosCompanion(
                  filePath: drift.Value(localPath),
                  imageData: const drift.Value(''),
                ),
              );
            }
          }
        } else {
          await (db.update(db.personPhotos)..where((t) => t.id.equals(id)))
              .write(
            PersonPhotosCompanion(
              imageData: drift.Value(
                'data:image/jpeg;base64,${base64Encode(bytes)}',
              ),
            ),
          );
        }

        await (db.delete(db.appKvStore)
              ..where((t) => t.key.equals('pending_photo_download_$id')))
            .go();
        return true;
      }
      throw Exception('Foto não disponível no storage person_photos: $id');
    } catch (e, st) {
      AppLogger.warning('Falha no download de foto person_photos ($id)', e, st);
      try {
        await db.into(db.appKvStore).insertOnConflictUpdate(
              AppKvStoreCompanion.insert(
                key: 'pending_photo_download_$id',
                value: DateTime.now().toUtc().toIso8601String(),
                updatedAt: drift.Value(DateTime.now()),
              ),
            );
      } catch (e2, st2) {
        AppLogger.warning('Falha ao registrar pendência de download de foto $id', e2, st2);
      }
      return false;
    }
  }

  Future<void> _deletePersonPhotoStorage(
    String id,
    SupabaseClient client,
  ) async {
    try {
      final userFolder = _resolveStorageFolder(client);
      if (userFolder == null) return;
      await client.storage.from('person_photos').remove([
        '$userFolder/$id.jpg',
        '$id.jpg',
      ]);
    } catch (e, st) {
      AppLogger.warning('Falha ao excluir foto $id do storage', e, st);
    }
  }

  /// Retenta o download de áudios que falharam durante a recepção de metadados
  Future<int> retryPendingMediaDownloads() async {
    if (!isConfigured) return 0;
    SupabaseClient? client;
    try {
      client = clientOverride ?? Supabase.instance.client;
    } catch (e, st) {
      AppLogger.debug('Cliente Supabase indisponível para retry de mídias: $e', st);
      return 0;
    }

    final pendingVoiceNotes = await (db.select(
      db.appKvStore,
    )..where((t) => t.key.like('pending_audio_download_%'))).get();

    int recovered = 0;
    for (final row in pendingVoiceNotes) {
      final id = row.key.replaceFirst('pending_audio_download_', '');
      final ok = await _downloadVoiceNoteAudio(id, client);
      if (ok) recovered++;
    }

    final pendingTicuna = await (db.select(
      db.appKvStore,
    )..where((t) => t.key.like('pending_ticuna_audio_download_%'))).get();

    for (final row in pendingTicuna) {
      final suffix = row.key.replaceFirst('pending_ticuna_audio_download_', '');
      final parts = suffix.split('_');
      // Esperado: ticuna_words_ID ou ticuna_phrases_ID
      if (parts.length >= 3) {
        final table = '${parts[0]}_${parts[1]}';
        final id = parts.sublist(2).join('_');
        final ok = await _downloadTicunaAudio(id, table, client);
        if (ok) recovered++;
      }
    }

    final pendingDocs = await (db.select(
      db.appKvStore,
    )..where((t) => t.key.like('pending_doc_download_%'))).get();

    for (final row in pendingDocs) {
      final id = row.key.replaceFirst('pending_doc_download_', '');
      final ok = await _downloadKnowledgeDocument(id, client);
      if (ok) recovered++;
    }

    final pendingPhotos = await (db.select(
      db.appKvStore,
    )..where((t) => t.key.like('pending_photo_download_%'))).get();

    for (final row in pendingPhotos) {
      final id = row.key.replaceFirst('pending_photo_download_', '');
      final ok = await _downloadPersonPhoto(id, client);
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
        } else if ((table == 'ticuna_words' || table == 'ticuna_phrases') && client != null) {
          await _downloadTicunaAudio(id, table, client);
        } else if (table == 'knowledge_documents' && client != null) {
          await _downloadKnowledgeDocument(id, client);
        } else if (table == 'person_photos' && client != null) {
          await _downloadPersonPhoto(id, client);
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
          await repository.markSyncOperationConflict(
            pendingOp.id,
            errMsg,
            remoteData: normalized,
            conflicts: mergeResult.conflicts
                .map((c) => {
                      'field': c.fieldName,
                      'local': c.localValue,
                      'remote': c.remoteValue,
                    })
                .toList(),
          );
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

          DateTime? localUpdated = SyncTimestamp.parse(localUpdatedAtStr);
          DateTime? remoteUpdated = SyncTimestamp.parse(remoteUpdatedAtStr);

          final isRemoteNewer = remoteUpdated != null && localUpdated != null
              ? (remoteUpdated.isAfter(localUpdated) ||
                    remoteUpdated.isAtSameMomentAs(localUpdated))
              : remoteRev >= localRev;

          if (isRemoteNewer) {
            await _updateLocalEntry(table, normalized);
            if (table == 'voice_notes' && client != null) {
              await _downloadVoiceNoteAudio(id, client);
            } else if ((table == 'ticuna_words' || table == 'ticuna_phrases') && client != null) {
              await _downloadTicunaAudio(id, table, client);
            } else if (table == 'knowledge_documents' && client != null) {
              await _downloadKnowledgeDocument(id, client);
            } else if (table == 'person_photos' && client != null) {
              await _downloadPersonPhoto(id, client);
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
  Future<SyncProcessResult>? _activeSync;

  Future<SyncProcessResult> sync() {
    return _activeSync ??= _runSync().whenComplete(() => _activeSync = null);
  }

  Future<SyncProcessResult> _runSync() async {
    // C2: Pull-before-push: busca alterações remotas antes de enviar mutações locais
    final pullResult = await fetchRemoteChanges();
    if (!isConfigured) return pullResult;
    final pushResult = await processQueue();
    final allErrors = [...pullResult.errors, ...pushResult.errors];
    return SyncProcessResult(
      totalProcessed: pullResult.totalProcessed + pushResult.totalProcessed,
      successCount: pullResult.successCount + pushResult.successCount,
      failureCount: pullResult.failureCount + pushResult.failureCount,
      conflictCount: pullResult.conflictCount + pushResult.conflictCount,
      errors: allErrors,
      message:
          'Sincronização bidirecional: ${pullResult.successCount} recebidos, ${pushResult.successCount} enviados.',
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
    } catch (e, st) {
      AppLogger.warning('Cliente Supabase indisponível durante fetchRemoteChanges', e, st);
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
        final lastSyncedAt = SyncTimestamp.parse(kvRow?.value);

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
            final dt = SyncTimestamp.parse(updatedAtRaw);

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

  /// Resolve um conflito da sync_queue aceitando a versão remota armazenada (ou baixando do servidor).
  Future<bool> resolveConflictAcceptRemote(String syncQueueId) async {
    final op = await (db.select(db.syncQueue)
          ..where((t) => t.id.equals(syncQueueId)))
        .getSingleOrNull();
    if (op == null) return false;

    final tableName = mapEntityToRemoteTable(op.entityType);
    Map<String, dynamic>? remoteMap;
    try {
      final decoded = jsonDecode(op.payload);
      if (decoded is Map<String, dynamic> && decoded['_remote'] is Map) {
        remoteMap = normalizeRemotePayload(
          Map<String, dynamic>.from(decoded['_remote'] as Map),
        );
      }
    } catch (e, st) {
      AppLogger.debug('Payload sem _remote JSON no conflito (${op.id}): $e', st);
    }

    if (remoteMap == null && isConfigured) {
      try {
        final client = clientOverride ?? Supabase.instance.client;
        final rows = await client
            .from(tableName)
            .select()
            .eq('id', op.entityId)
            .limit(1);
        if (rows.isNotEmpty) {
          remoteMap = normalizeRemotePayload(rows.first);
        }
      } catch (e, st) {
        AppLogger.warning('Falha ao buscar registro remoto para resolução de conflito', e, st);
      }
    }

    if (remoteMap == null) return false;

    final localExisting = await _getLocalMap(tableName, op.entityId);
    if (localExisting == null) {
      await _insertLocalEntry(tableName, remoteMap);
    } else {
      await _updateLocalEntry(tableName, remoteMap);
    }
    await repository.markSyncOperationSuccess(op.id);
    return true;
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
    } catch (e, st) {
      AppLogger.warning('Cliente Supabase não inicializado no processQueue', e, st);
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
      if (op.attempts >= AppRepository.maxSyncAttempts) {
        failure++;
        final maxErr =
            'Operação ${op.id} (${op.entityType}) excedeu o limite máximo de ${AppRepository.maxSyncAttempts} tentativas.';
        errors.add(maxErr);
        await repository.markSyncOperationFailed(
          op.id,
          maxErr,
          forceFailed: true,
        );
        continue;
      }

      final backoffSeconds = pow(2, op.attempts).clamp(1, 300).toInt();
      final now = DateTime.now();
      final lastAttempt = op.lastAttemptAt ?? op.createdAt;
      if (now.difference(lastAttempt).inSeconds < backoffSeconds &&
          op.attempts > 0) {
        continue;
      }

      try {
        final Map<String, dynamic> rawPayload =
            jsonDecode(op.payload) as Map<String, dynamic>;
        final tableName = mapEntityToRemoteTable(op.entityType);
        final operation = op.operation.toUpperCase();

        // F7/M10: Hidratação completa a partir do SQLite local antes do envio
        var cleanPayload = SyncTimestamp.normalizeMapDates(
          normalizeRemotePayload(sanitizePayload(op.entityType, rawPayload)),
        );
        final localRowMap = await _getLocalMap(tableName, op.entityId);
        if (localRowMap != null) {
          final isMinimalStub =
              cleanPayload.length <= 3 && cleanPayload.containsKey('id');
          if (isMinimalStub) {
            cleanPayload = Map<String, dynamic>.from(localRowMap);
          } else {
            for (final entry in localRowMap.entries) {
              cleanPayload.putIfAbsent(entry.key, () => entry.value);
            }
          }
          cleanPayload = sanitizePayload(op.entityType, cleanPayload);
        }

        if (operation == 'INSERT' || operation == 'UPDATE') {
          // C2 Camada 1: Pré-verificação estrita de revisão remota e merge 3-way
          final rawRemoteRows = await client
              .from(tableName)
              .select()
              .eq('id', op.entityId)
              .limit(1);
          final remoteRows = (rawRemoteRows as List)
              .whereType<Map<String, dynamic>>()
              .where((r) => r['id']?.toString() == op.entityId)
              .toList();
          if (remoteRows.isNotEmpty) {
            final remoteRecord = remoteRows.first;
            final normalizedRemote = SyncTimestamp.normalizeMapDates(
              normalizeRemotePayload(remoteRecord),
            );
            final remoteRev = normalizedRemote['revision'] as int? ?? 1;
            final localRev = cleanPayload['revision'] as int? ?? 1;
            final remoteUpdated = SyncTimestamp.parse(
              normalizedRemote['updatedAt'] ?? normalizedRemote['updated_at'],
            );
            final localUpdated = SyncTimestamp.parse(
              cleanPayload['updatedAt'] ?? cleanPayload['updated_at'],
            );

            final baseData = rawPayload.containsKey('_base') &&
                    rawPayload['_base'] is Map
                ? SyncTimestamp.normalizeMapDates(
                    normalizeRemotePayload(
                      rawPayload['_base'] as Map<String, dynamic>,
                    ),
                  )
                : <String, dynamic>{};
            final baseRev = (baseData['revision'] as num?)?.toInt();

            if (_hasConcurrentRemoteDivergence(
              remoteRev: remoteRev,
              localRev: localRev,
              baseRev: baseRev,
              remoteUpdated: remoteUpdated,
              localUpdated: localUpdated,
              localData: cleanPayload,
              remoteData: normalizedRemote,
            )) {
              final mergeResult = SyncEngine.mergeEntities(
                entityType: op.entityType,
                entityId: op.entityId,
                localData: cleanPayload,
                remoteData: normalizedRemote,
                baseData: baseData,
              );
              if (mergeResult.hasConflict) {
                conflicts++;
                _setStatus(SyncStatus.conflict);
                final err =
                    'Conflito de mesclagem 3-way detectado em ${op.entityType} (${op.entityId})';
                errors.add(err);
                await repository.markSyncOperationConflict(
                  op.id,
                  err,
                  remoteData: normalizedRemote,
                  conflicts: mergeResult.conflicts
                      .map((c) => {
                            'field': c.fieldName,
                            'local': c.localValue,
                            'remote': c.remoteValue,
                          })
                      .toList(),
                );
                continue;
              } else {
                cleanPayload.addAll(mergeResult.mergedData);
                cleanPayload['revision'] = remoteRev + 1;
                cleanPayload['updatedAt'] = DateTime.now().toUtc().toIso8601String();
                await _updateLocalEntry(tableName, cleanPayload);
              }
            }
          }

          final remotePayload = toRemotePayload(op.entityType, cleanPayload);
          final currentUserId =
              client.auth.currentUser?.id ?? client.auth.currentSession?.user.id;
          if (currentUserId != null && currentUserId.isNotEmpty) {
            remotePayload['owner_id'] = currentUserId;
          }

          if (tableName == 'person_photos') {
            final photoOk = await _uploadPersonPhoto(
              op.entityId,
              remotePayload,
              client,
              errors,
            );
            if (!photoOk) {
              failure++;
              await repository.markSyncOperationFailed(
                op.id,
                'Falha no upload binário da foto para o Storage (person_photos)',
              );
              continue;
            }
          }

          // C2 Camada 2: RPC Server-Side `sync_upsert` com trava otimista
          bool pushedViaRpc = false;
          try {
            final rpcRes = await client.rpc(
              'sync_upsert',
              params: {
                'p_table': tableName,
                'p_payload': remotePayload,
              },
            );
            if (rpcRes is Map<String, dynamic>) {
              if (rpcRes['conflict'] == true ||
                  rpcRes['code']?.toString() == '23505') {
                conflicts++;
                _setStatus(SyncStatus.conflict);
                final serverRec = rpcRes['server_record'] is Map<String, dynamic>
                    ? normalizeRemotePayload(
                        rpcRes['server_record'] as Map<String, dynamic>,
                      )
                    : null;
                final err =
                    'Conflito otimista detectado pelo servidor em ${op.entityType} (${op.entityId}): ${rpcRes['message'] ?? ''}';
                errors.add(err);
                await repository.markSyncOperationConflict(
                  op.id,
                  err,
                  remoteData: serverRec,
                );
                continue;
              }
              if (rpcRes['success'] == true) {
                pushedViaRpc = true;
              }
            }
          } on PostgrestException catch (rpcErr) {
            if (rpcErr.code == '23505' || rpcErr.code == '409') {
              rethrow;
            }
            AppLogger.warning(
              'RPC sync_upsert indisponível (${rpcErr.code}): fallback para upsert após pré-check.',
            );
          }

          if (!pushedViaRpc) {
            await client.from(tableName).upsert(remotePayload);
          }

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
          } else if (tableName == 'ticuna_words' || tableName == 'ticuna_phrases') {
            final audioOk = await _uploadTicunaAudio(
              op.entityId,
              op.entityType,
              cleanPayload,
              client,
              errors,
            );
            if (!audioOk) {
              failure++;
              await repository.markSyncOperationFailed(
                op.id,
                'Falha no upload do arquivo binário de áudio Ticuna para o Storage',
              );
              continue;
            }
          } else if (tableName == 'knowledge_documents') {
            final docOk = await _uploadKnowledgeDocument(
              op.entityId,
              client,
              errors,
            );
            if (!docOk) {
              failure++;
              await repository.markSyncOperationFailed(
                op.id,
                'Falha no upload do arquivo binário do documento para o Storage (knowledge_vault)',
              );
              continue;
            }
          }

          await repository.markSyncOperationSuccess(op.id);
          success++;
        } else if (operation == 'DELETE') {
          // M5: Verificação de revisão remota antes de aplicar tombstone
          final localRev = cleanPayload['revision'] as int? ?? 1;
          final rawRemoteRows = await client
              .from(tableName)
              .select()
              .eq('id', op.entityId)
              .limit(1);
          final remoteRows = (rawRemoteRows as List)
              .whereType<Map<String, dynamic>>()
              .where((r) => r['id']?.toString() == op.entityId)
              .toList();
          if (remoteRows.isNotEmpty) {
            final remoteRecord = normalizeRemotePayload(remoteRows.first);
            final remoteRev = remoteRecord['revision'] as int? ?? 1;
            if (remoteRev > localRev) {
              conflicts++;
              _setStatus(SyncStatus.conflict);
              final err =
                  'Conflito em DELETE de ${op.entityType} (${op.entityId}): registro remoto (rev $remoteRev) foi alterado após exclusão local (rev $localRev).';
              errors.add(err);
              await repository.markSyncOperationConflict(
                op.id,
                err,
                remoteData: remoteRecord,
              );
              continue;
            }
          }

          // Exclui arquivos binários associados no Storage
          if (tableName == 'voice_notes') {
            await _deleteVoiceNoteAudio(op.entityId, client);
          } else if (tableName == 'ticuna_words' || tableName == 'ticuna_phrases') {
            await _deleteTicunaAudio(op.entityId, client);
          } else if (tableName == 'knowledge_documents') {
            await _deleteKnowledgeDocumentStorage(op.entityId, client);
          } else if (tableName == 'person_photos') {
            await _deletePersonPhotoStorage(op.entityId, client);
          }

          final nowIso = DateTime.now().toUtc().toIso8601String();
          await client
              .from(tableName)
              .update({
                'deleted_at': nowIso,
                'updated_at': nowIso,
                'revision': localRev,
              })
              .eq('id', op.entityId)
              .lte('revision', localRev);
          await repository.markSyncOperationSuccess(op.id);
          success++;
        } else if (operation == 'HARD_DELETE') {
          if (tableName == 'voice_notes') {
            await _deleteVoiceNoteAudio(op.entityId, client);
          } else if (tableName == 'ticuna_words' || tableName == 'ticuna_phrases') {
            await _deleteTicunaAudio(op.entityId, client);
          } else if (tableName == 'knowledge_documents') {
            await _deleteKnowledgeDocumentStorage(op.entityId, client);
          } else if (tableName == 'person_photos') {
            await _deletePersonPhotoStorage(op.entityId, client);
          }

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
          await repository.markSyncOperationConflict(op.id, err);
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

    // Expulga operações sincronizadas antigas (> 30 dias) para manter o SQLite leve e veloz
    try {
      await repository.pruneOldSyncedOperations();
    } catch (e, st) {
      AppLogger.debug('Falha ao limpar operações sincronizadas antigas: $e', st);
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

  bool _hasConcurrentRemoteDivergence({
    required int remoteRev,
    required int localRev,
    required int? baseRev,
    required DateTime? remoteUpdated,
    required DateTime? localUpdated,
    required Map<String, dynamic> localData,
    required Map<String, dynamic> remoteData,
  }) {
    if (remoteRev > localRev) return true;
    if (baseRev != null && remoteRev > baseRev) return true;
    if (remoteUpdated != null &&
        localUpdated != null &&
        remoteUpdated.isAfter(localUpdated)) {
      return true;
    }
    if (remoteRev == localRev && _recordsDifferNonAudit(localData, remoteData)) {
      return true;
    }
    return false;
  }

  bool _recordsDifferNonAudit(
    Map<String, dynamic> localData,
    Map<String, dynamic> remoteData,
  ) {
    const ignoredKeys = {
      'ownerId',
      'owner_id',
      'revision',
      'updatedAt',
      'updated_at',
      'createdAt',
      'created_at',
    };
    final keys = {...localData.keys, ...remoteData.keys};
    for (final k in keys) {
      if (ignoredKeys.contains(k)) continue;
      final a = localData[k];
      final b = remoteData[k];
      if (a == null && b == null) continue;
      if (!_valuesEqualNormalized(a, b)) {
        return true;
      }
    }
    return false;
  }

  bool _valuesEqualNormalized(dynamic a, dynamic b) {
    if (a == b) return true;
    if (a == null || b == null) return false;
    if ((a is bool && b is int) || (a is int && b is bool)) {
      final aInt = a is bool ? (a ? 1 : 0) : a as int;
      final bInt = b is bool ? (b ? 1 : 0) : b as int;
      return aInt == bInt;
    }
    if (a is String && b is String) {
      final aDt = SyncTimestamp.parse(a);
      final bDt = SyncTimestamp.parse(b);
      if (aDt != null && bDt != null) {
        return aDt.difference(bDt).abs() <= const Duration(milliseconds: 1);
      }
    }
    return false;
  }

  void dispose() {
    _statusController.close();
  }
}

/// Provider do serviço de sincronização do Supabase
final supabaseSyncServiceProvider = Provider<SupabaseSyncService>((ref) {
  final repo = ref.watch(repositoryProvider);
  final service = SupabaseSyncService(db: repo.db, repository: repo);
  ref.onDispose(service.dispose);
  return service;
});

/// Stream provider do status reativo de sincronização
final syncStatusStreamProvider = StreamProvider<SyncStatus>((ref) {
  final syncService = ref.watch(supabaseSyncServiceProvider);
  return syncService.statusStream;
});
