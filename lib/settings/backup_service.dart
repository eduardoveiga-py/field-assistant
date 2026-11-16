import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:drift/drift.dart' show Value, Variable;
import 'package:uuid/uuid.dart';

import '../core/app_logger.dart';
import '../core/sync_timestamp.dart';
import '../database/app_database.dart';
import '../database/repository.dart';

/// Lançado quando um backup legado (v1 sem salt PBKDF2) é submetido sem confirmação explícita.
class LegacyBackupNotAllowedException extends FormatException {
  const LegacyBackupNotAllowedException([
    super.message =
        'Backup no formato legado (v1, SHA-256 sem salt). Confirme explicitamente para importar e re-exporte na v2.',
  ]);
}

/// Lançado quando a criação do snapshot de segurança falha antes da restauração.
/// A restauração NÃO prossegue quando este erro é lançado.
class RestoreAbortedException implements Exception {
  final String message;
  const RestoreAbortedException(this.message);
  @override
  String toString() => 'RestoreAbortedException: $message';
}

/// Lançado quando um diretório de mídia não pode ser criado durante a restauração.
class RestoreMediaException implements Exception {
  final String message;
  const RestoreMediaException(this.message);
  @override
  String toString() => 'RestoreMediaException: $message';
}

/// Lançado quando não é possível obter um diretório persistente e seguro.
/// O Field Assistant rejeita o uso de diretórios temporários (Directory.systemTemp) para dados críticos.
class StorageUnavailableException implements Exception {
  final String message;
  const StorageUnavailableException(this.message);
  @override
  String toString() => 'StorageUnavailableException: $message';
}

class RestoreResult {
  final bool isIntegral;
  final List<String> corruptedFiles;
  final List<String> missingFiles;
  final int restoredRecordsCount;

  RestoreResult({
    required this.isIntegral,
    this.corruptedFiles = const [],
    this.missingFiles = const [],
    required this.restoredRecordsCount,
  });
}

class RestorePreview {
  final int peopleToAdd;
  final int peopleToUpdate;
  final int peopleUnchanged;
  final int visitsToAdd;
  final int visitsToUpdate;
  final int studiesToAdd;
  final int sessionsToAdd;
  final int appointmentsToAdd;
  final int activitiesToAdd;
  final int syncQueueToAdd;
  final int voiceNotesToAdd;
  final int phoneContactsToAdd;
  final int landmarksToAdd;
  final int familyTiesToAdd;
  final int experiencesToAdd;
  final int photosToAdd;
  final int publicationsToAdd;
  final int articlesToAdd;
  final int sectorsToAdd;
  final int calendarEventsToAdd;
  final int calendarLinksToAdd;
  final int appLanguagesToAdd;
  final int ticunaWordsToAdd;
  final int ticunaPhrasesToAdd;
  final int ticunaTagsToAdd;
  final int knowledgeNotesToAdd;
  final int knowledgeDocumentsToAdd;
  final List<String> inventoryTables;
  final List<String> corruptedAudioIds;
  final List<String> corruptedDocumentIds;
  final Map<String, dynamic> rawDecryptedData;

  bool get isIntegral =>
      corruptedAudioIds.isEmpty && corruptedDocumentIds.isEmpty;

  RestorePreview({
    required this.peopleToAdd,
    required this.peopleToUpdate,
    required this.peopleUnchanged,
    required this.visitsToAdd,
    required this.visitsToUpdate,
    required this.studiesToAdd,
    required this.sessionsToAdd,
    required this.appointmentsToAdd,
    required this.activitiesToAdd,
    this.syncQueueToAdd = 0,
    this.voiceNotesToAdd = 0,
    this.phoneContactsToAdd = 0,
    this.landmarksToAdd = 0,
    this.familyTiesToAdd = 0,
    this.experiencesToAdd = 0,
    this.photosToAdd = 0,
    this.publicationsToAdd = 0,
    this.articlesToAdd = 0,
    this.sectorsToAdd = 0,
    this.calendarEventsToAdd = 0,
    this.calendarLinksToAdd = 0,
    this.appLanguagesToAdd = 0,
    this.ticunaWordsToAdd = 0,
    this.ticunaPhrasesToAdd = 0,
    this.ticunaTagsToAdd = 0,
    this.knowledgeNotesToAdd = 0,
    this.knowledgeDocumentsToAdd = 0,
    this.inventoryTables = const [],
    this.corruptedAudioIds = const [],
    this.corruptedDocumentIds = const [],
    required this.rawDecryptedData,
  });
}

class BackupService {
  final AppRepository repository;
  final Future<Directory> Function()? documentsDirectoryProvider;
  final FlutterSecureStorage? secureStorage;
  final Uuid _uuid = const Uuid();
  String? _lastPreRestoreSafetyBackup;

  String? get lastPreRestoreSafetyBackup => _lastPreRestoreSafetyBackup;

  FlutterSecureStorage get _storage =>
      secureStorage ?? const FlutterSecureStorage();

  BackupService(
    this.repository, {
    this.documentsDirectoryProvider,
    this.secureStorage,
  });

  Future<bool> _tableExists(String tableName) async {
    try {
      final rows = await repository.db.customSelect(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable.withString(tableName)],
      ).get();
      return rows.isNotEmpty;
    } catch (e, st) {
      AppLogger.warning(
        'Erro ao verificar existência da tabela $tableName no backup',
        e,
        st,
      );
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> _readRawTableRows(String tableName) async {
    if (!await _tableExists(tableName)) return const [];
    final rows = await repository.db.customSelect('SELECT * FROM $tableName').get();
    return rows.map((r) => Map<String, dynamic>.from(r.data)).toList();
  }

  Future<void> _ensureTicunaTables() async {
    final db = repository.db;
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS ticuna_words (
        id TEXT PRIMARY KEY,
        word TEXT NOT NULL,
        translation TEXT NOT NULL,
        phonetics TEXT,
        grammatical_class TEXT,
        example_sentence TEXT,
        example_translation TEXT,
        notes TEXT,
        tags TEXT NOT NULL DEFAULT '[]',
        is_favorite INTEGER NOT NULL DEFAULT 0,
        review_level INTEGER NOT NULL DEFAULT 0,
        review_count INTEGER NOT NULL DEFAULT 0,
        last_reviewed_at TEXT,
        audio_path TEXT,
        audio_duration_seconds INTEGER,
        language_id TEXT DEFAULT 'tca',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS ticuna_phrases (
        id TEXT PRIMARY KEY,
        phrase TEXT NOT NULL,
        translation TEXT NOT NULL,
        category TEXT,
        phonetics TEXT,
        notes TEXT,
        tags TEXT NOT NULL DEFAULT '[]',
        is_favorite INTEGER NOT NULL DEFAULT 0,
        audio_path TEXT,
        audio_duration_seconds INTEGER,
        language_id TEXT DEFAULT 'tca',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS ticuna_tags (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL
      );
    ''');
  }

  Future<Directory> _getDocsDir() async {
    try {
      if (documentsDirectoryProvider != null) {
        return await documentsDirectoryProvider!();
      }
      return await getApplicationDocumentsDirectory();
    } catch (e) {
      throw StorageUnavailableException(
        'Armazenamento persistente seguro indisponível no dispositivo: $e',
      );
    }
  }

  Future<File> _persistSnapshotToDisk(String snapshotData) async {
    final docsDir = await _getDocsDir();
    final snapshotDir = Directory('${docsDir.path}/safety_snapshots');
    if (!snapshotDir.existsSync()) {
      await snapshotDir.create(recursive: true);
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${snapshotDir.path}/snapshot_$timestamp.bak');
    await file.writeAsString(snapshotData, flush: true);
    return file;
  }

  Future<void> _validateSnapshotFile(
    File file, {
    required String password,
  }) async {
    if (!await file.exists()) {
      throw const RestoreAbortedException(
        'Arquivo de snapshot não foi criado no disco.',
      );
    }
    final length = await file.length();
    if (length == 0) {
      throw const RestoreAbortedException(
        'Arquivo de snapshot gerado está vazio.',
      );
    }
    final content = await file.readAsString();
    try {
      final preview = await previewBackup(
        encryptedDataString: content,
        password: password,
      );
      if (!preview.isIntegral) {
        throw const RestoreAbortedException(
          'Snapshot de segurança gerado contém arquivos de áudio corrompidos.',
        );
      }
    } catch (e) {
      if (e is RestoreAbortedException) {
        rethrow;
      }
      throw RestoreAbortedException(
        'Snapshot de segurança gerado é inválido ou ilegível: $e',
      );
    }
  }

  /// Retorna o caminho do último snapshot de segurança salvo em disco.
  Future<String?> getLastSafetySnapshotPath() async {
    final db = repository.db;
    final row =
        await (db.select(db.appKvStore)
              ..where((tbl) => tbl.key.equals('last_safety_snapshot_path')))
            .getSingleOrNull();
    return row?.value;
  }

  static Uint8List _generateSecureRandom(int length) {
    final rnd = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => rnd.nextInt(256)),
    );
  }

  /// Derivação de chave PBKDF2-HMAC-SHA256 padrão (100.000 iterações por padrão)
  static Uint8List _deriveKeyPbkdf2(
    String password,
    Uint8List salt, {
    int iterations = 100000,
  }) {
    final hmac = Hmac(sha256, utf8.encode(password));
    // Bloco 1 (32 bytes): salt || [0, 0, 0, 1]
    final saltAndBlock = Uint8List(salt.length + 4);
    saltAndBlock.setRange(0, salt.length, salt);
    saltAndBlock[salt.length + 3] = 1;

    Uint8List u = Uint8List.fromList(hmac.convert(saltAndBlock).bytes);
    final blockResult = Uint8List.fromList(u);

    for (int iter = 1; iter < iterations; iter++) {
      u = Uint8List.fromList(hmac.convert(u).bytes);
      for (int i = 0; i < 32; i++) {
        blockResult[i] ^= u[i];
      }
    }

    return blockResult;
  }

  /// Chave de 32 bytes legada v1 (SHA-256 de senha + salt fixo)
  static enc.Key _deriveKeyV1(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    final digest = sha256.convert(bytes);
    return enc.Key(Uint8List.fromList(digest.bytes));
  }

  /// Exporta todos os registros em JSON criptografado com PBKDF2-HMAC-SHA256 e AES-256-GCM (Versão 2)
  Future<String> exportEncryptedBackup(
    String password, {
    int iterations = 100000,
  }) async {
    final db = repository.db;

    final people = await db.select(db.people).get();
    final visits = await db.select(db.visits).get();
    final studies = await db.select(db.bibleStudies).get();
    final participants = await db.select(db.studyParticipants).get();
    final sessions = await db.select(db.studySessions).get();
    final appointments = await db.select(db.appointments).get();
    final activities = await db.select(db.activityRecords).get();
    final syncQueue = await db.select(db.syncQueue).get();
    final voiceNotes = await db.select(db.voiceNotes).get();
    final phoneContacts = await db.select(db.phoneContacts).get();
    final landmarks = await db.select(db.territoryLandmarks).get();
    final familyTies = await db.select(db.familyTies).get();
    final experiences = await db.select(db.ministryExperiences).get();
    final photos = await db.select(db.personPhotos).get();
    final publications = await db.select(db.personPublications).get();
    final articles = await db.select(db.researchArticles).get();
    final tags = await db.select(db.researchTags).get();
    final sectors = await db.select(db.territorySectors).get();
    final manualOrders = await db.select(db.studentManualOrder).get();
    final calendarEvents = await db.select(db.externalCalendarEvents).get();
    final calendarLinks = await db.select(db.calendarEventLinks).get();
    final inboxes = await db.select(db.inboxEntries).get();
    final projects = await db.select(db.projects).get();
    final tasks = await db.select(db.tasks).get();
    final knowledgeNotes = await db.select(db.knowledgeNotes).get();
    final knowledgeQuestions = await db.select(db.knowledgeQuestions).get();
    final knowledgeDocuments = await db.select(db.knowledgeDocuments).get();
    final knowledgeResources = await db.select(db.knowledgeResources).get();
    final appLanguages = await db.select(db.appLanguages).get();
    final ticunaWords = await _readRawTableRows('ticuna_words');
    final ticunaPhrases = await _readRawTableRows('ticuna_phrases');
    final ticunaTags = await _readRawTableRows('ticuna_tags');
    final kvStore = await (db.select(
      db.appKvStore,
    )..where((t) => t.key.isNotValue(_silentBackupKeySecret))).get();

    // Saneamento e portabilidade multimídia: serializa arquivos físicos de áudio em base64 e gera hashes SHA-256
    final Map<String, String> voiceNoteAudios = {};
    final Map<String, String> voiceNoteAudioHashes = {};
    final Map<String, String> ticunaAudios = {};
    final Map<String, String> ticunaAudioHashes = {};
    final Map<String, String> knowledgeDocumentFiles = {};
    final Map<String, String> knowledgeDocumentHashes = {};
    if (!kIsWeb) {
      for (final vn in voiceNotes) {
        if (vn.audioFilePath != null && vn.audioFilePath!.isNotEmpty) {
          try {
            final f = File(vn.audioFilePath!);
            if (await f.exists()) {
              final bytes = await f.readAsBytes();
              voiceNoteAudios[vn.id] = base64Encode(bytes);
              voiceNoteAudioHashes[vn.id] = sha256.convert(bytes).toString();
            }
          } catch (e, st) {
            AppLogger.warning(
              'Falha ao serializar áudio da nota de voz ${vn.id} para backup',
              e,
              st,
            );
          }
        }
      }

      for (final w in ticunaWords) {
        final audioPath = w['audio_path']?.toString();
        final id = w['id']?.toString();
        if (id != null && audioPath != null && audioPath.isNotEmpty) {
          try {
            final f = File(audioPath);
            if (await f.exists()) {
              final bytes = await f.readAsBytes();
              final key = 'word_$id';
              ticunaAudios[key] = base64Encode(bytes);
              ticunaAudioHashes[key] = sha256.convert(bytes).toString();
            }
          } catch (e, st) {
            AppLogger.warning(
              'Falha ao serializar áudio Ticuna palavra $id para backup',
              e,
              st,
            );
          }
        }
      }

      for (final pRow in ticunaPhrases) {
        final audioPath = pRow['audio_path']?.toString();
        final id = pRow['id']?.toString();
        if (id != null && audioPath != null && audioPath.isNotEmpty) {
          try {
            final f = File(audioPath);
            if (await f.exists()) {
              final bytes = await f.readAsBytes();
              final key = 'phrase_$id';
              ticunaAudios[key] = base64Encode(bytes);
              ticunaAudioHashes[key] = sha256.convert(bytes).toString();
            }
          } catch (e, st) {
            AppLogger.warning(
              'Falha ao serializar áudio Ticuna frase $id para backup',
              e,
              st,
            );
          }
        }
      }

      for (final doc in knowledgeDocuments) {
        if (doc.filePath.isNotEmpty) {
          try {
            var f = File(doc.filePath);
            if (!await f.exists() && !f.isAbsolute) {
              final docs = await _getDocsDir();
              f = File('${docs.path}/${doc.filePath}');
            }
            if (await f.exists()) {
              final bytes = await f.readAsBytes();
              knowledgeDocumentFiles[doc.id] = base64Encode(bytes);
              knowledgeDocumentHashes[doc.id] = sha256.convert(bytes).toString();
            }
          } catch (e, st) {
            AppLogger.warning(
              'Falha ao serializar binário de documento ${doc.id} para backup',
              e,
              st,
            );
          }
        }
      }
    }

    // Saneamento e portabilidade de fotos: se a imagem estiver apontando para um arquivo local em disco,
    // converte os bytes para data URI base64 garantindo restauração perfeita em qualquer dispositivo
    final List<Map<String, dynamic>> exportedPhotos = [];
    for (final p in photos) {
      final photoMap = p.toJson();
      final sourcePath = (p.filePath != null && p.filePath!.isNotEmpty)
          ? p.filePath!
          : p.imageData;
      if (!kIsWeb &&
          sourcePath.isNotEmpty &&
          !sourcePath.startsWith('data:image') &&
          !sourcePath.startsWith('data:video') &&
          !sourcePath.startsWith('http://') &&
          !sourcePath.startsWith('https://')) {
        try {
          final f = File(sourcePath);
          if (await f.exists()) {
            final bytes = await f.readAsBytes();
            final ext = sourcePath.toLowerCase();
            final mime = ext.endsWith('.png')
                ? 'image/png'
                : ext.endsWith('.webp')
                    ? 'image/webp'
                    : ext.endsWith('.gif')
                        ? 'image/gif'
                        : 'image/jpeg';
            photoMap['imageData'] = 'data:$mime;base64,${base64Encode(bytes)}';
            photoMap['filePath'] = null;
          }
        } catch (e, st) {
          AppLogger.warning(
            'Falha ao serializar arquivo de foto ${p.id} para backup',
            e,
            st,
          );
        }
      }
      exportedPhotos.add(photoMap);
    }

    final payload = {
      'exported_tables_count': 33,
      'exported_tables': [
        'people',
        'visits',
        'bibleStudies',
        'studyParticipants',
        'studySessions',
        'appointments',
        'activityRecords',
        'syncQueue',
        'voiceNotes',
        'phoneContacts',
        'territoryLandmarks',
        'familyTies',
        'ministryExperiences',
        'personPhotos',
        'personPublications',
        'researchArticles',
        'researchTags',
        'territorySectors',
        'studentManualOrder',
        'externalCalendarEvents',
        'calendarEventLinks',
        'inboxEntries',
        'projects',
        'tasks',
        'knowledgeNotes',
        'knowledgeQuestions',
        'knowledgeDocuments',
        'knowledgeResources',
        'appLanguages',
        'ticunaWords',
        'ticunaPhrases',
        'ticunaTags',
        'appKvStore',
      ],
      'people': people.map((p) => p.toJson()).toList(),
      'visits': visits.map((v) => v.toJson()).toList(),
      'bibleStudies': studies.map((s) => s.toJson()).toList(),
      'studyParticipants': participants.map((p) => p.toJson()).toList(),
      'studySessions': sessions.map((s) => s.toJson()).toList(),
      'appointments': appointments.map((a) => a.toJson()).toList(),
      'activityRecords': activities.map((a) => a.toJson()).toList(),
      'syncQueue': syncQueue.map((sq) => sq.toJson()).toList(),
      'voiceNotes': voiceNotes.map((v) => v.toJson()).toList(),
      'voiceNoteAudios': voiceNoteAudios,
      'voiceNoteAudioHashes': voiceNoteAudioHashes,
      'phoneContacts': phoneContacts.map((c) => c.toJson()).toList(),
      'territoryLandmarks': landmarks.map((l) => l.toJson()).toList(),
      'familyTies': familyTies.map((f) => f.toJson()).toList(),
      'ministryExperiences': experiences.map((e) => e.toJson()).toList(),
      'personPhotos': exportedPhotos,
      'personPublications': publications.map((p) => p.toJson()).toList(),
      'researchArticles': articles.map((a) => a.toJson()).toList(),
      'researchTags': tags.map((t) => t.toJson()).toList(),
      'territorySectors': sectors.map((s) => s.toJson()).toList(),
      'studentManualOrder': manualOrders.map((m) => m.toJson()).toList(),
      'externalCalendarEvents': calendarEvents.map((c) => c.toJson()).toList(),
      'calendarEventLinks': calendarLinks.map((l) => l.toJson()).toList(),
      'inboxEntries': inboxes.map((i) => i.toJson()).toList(),
      'projects': projects.map((p) => p.toJson()).toList(),
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'knowledgeNotes': knowledgeNotes.map((n) => n.toJson()).toList(),
      'knowledgeQuestions': knowledgeQuestions.map((q) => q.toJson()).toList(),
      'knowledgeDocuments': knowledgeDocuments.map((d) => d.toJson()).toList(),
      'knowledgeDocumentFiles': knowledgeDocumentFiles,
      'knowledgeDocumentHashes': knowledgeDocumentHashes,
      'knowledgeResources': knowledgeResources.map((r) => r.toJson()).toList(),
      'appLanguages': appLanguages.map((l) => l.toJson()).toList(),
      'ticunaWords': ticunaWords,
      'ticunaPhrases': ticunaPhrases,
      'ticunaTags': ticunaTags,
      'ticunaAudios': ticunaAudios,
      'ticunaAudioHashes': ticunaAudioHashes,
      'appKvStore': kvStore.map((k) => k.toJson()).toList(),
    };

    final rawJson = jsonEncode(payload);
    final checksum = sha256.convert(utf8.encode(rawJson)).toString();

    // Salt criptograficamente seguro aleatório de 16 bytes
    final saltBytes = _generateSecureRandom(16);
    final saltBase64 = base64Encode(saltBytes);

    // Derivação de chave AES-256 via PBKDF2-HMAC-SHA256
    final keyBytes = _deriveKeyPbkdf2(
      password,
      saltBytes,
      iterations: iterations,
    );
    final key = enc.Key(keyBytes);

    // IV aleatório seguro de 16 bytes
    final iv = enc.IV.fromSecureRandom(16);

    final backupEnvelope = {
      'version': 2,
      'exported_at': DateTime.now().toIso8601String(),
      'checksum': checksum,
      'iterations': iterations,
      'data': rawJson,
    };

    final envelopeJson = jsonEncode(backupEnvelope);

    // Criptografia autenticada AES-256-GCM com tag de integridade de 128 bits
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    final encrypted = encrypter.encrypt(envelopeJson, iv: iv);

    final result = {
      'version': 2,
      'salt': saltBase64,
      'iterations': iterations,
      'iv': iv.base64,
      'ciphertext': encrypted.base64,
    };

    return jsonEncode(result);
  }

  /// Descriptografa e gera pré-visualização das alterações sem modificar o banco
  Future<RestorePreview> previewBackup({
    required String encryptedDataString,
    required String password,
    bool allowLegacyV1 = false,
  }) async {
    final Map<String, dynamic> container = jsonDecode(encryptedDataString);
    final int containerVersion = container['version'] as int? ?? 1;

    String decryptedEnvelopeJson;

    try {
      if (containerVersion == 2) {
        final saltBase64 = container['salt'] as String;
        final saltBytes = base64Decode(saltBase64);
        final iterations = (container['iterations'] as num?)?.toInt() ?? 100000;
        final iv = enc.IV.fromBase64(container['iv'] as String);
        final ciphertext = container['ciphertext'] as String;

        final keyBytes = _deriveKeyPbkdf2(
          password,
          saltBytes,
          iterations: iterations,
        );
        final key = enc.Key(keyBytes);
        final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));

        decryptedEnvelopeJson = encrypter.decrypt64(ciphertext, iv: iv);
      } else {
        if (!allowLegacyV1) {
          throw const LegacyBackupNotAllowedException();
        }
        // Compatibilidade reversa: Versão 1 legada (somente opt-in explícito)
        final iv = enc.IV.fromBase64(container['iv'] as String);
        final ciphertext = container['ciphertext'] as String;
        final key = _deriveKeyV1(password, 'ministerio_pessoal_salt_v1');
        final encrypter = enc.Encrypter(enc.AES(key));

        decryptedEnvelopeJson = encrypter.decrypt64(ciphertext, iv: iv);
      }
    } on LegacyBackupNotAllowedException {
      rethrow;
    } catch (e, st) {
      AppLogger.warning('Falha ao descriptografar backup', e, st);
      throw const FormatException(
        'Senha incorreta ou arquivo de backup corrompido.',
      );
    }

    final envelope = jsonDecode(decryptedEnvelopeJson) as Map<String, dynamic>;
    final version = envelope['version'] as int;
    if (version > 2) {
      throw FormatException(
        'Versão de backup ($version) mais recente que a versão suportada pelo app (2).',
      );
    }

    final rawDataJson = envelope['data'] as String;
    final expectedChecksum = envelope['checksum'] as String;
    final calculatedChecksum = sha256
        .convert(utf8.encode(rawDataJson))
        .toString();

    if (calculatedChecksum != expectedChecksum) {
      throw const FormatException(
        'Falha de integridade: checksum do backup não confere.',
      );
    }

    final data = jsonDecode(rawDataJson) as Map<String, dynamic>;

    DateTime parseDate(dynamic raw) {
      if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
      if (raw is String) return DateTime.parse(raw);
      if (raw is DateTime) return raw;
      return DateTime.now();
    }

    // Prévia: People
    final existingPeople = await repository.getAllPeople();
    final existingPeopleMap = {for (var p in existingPeople) p.id: p};
    final importedPeople = (data['people'] as List<dynamic>?) ?? [];
    int pAdd = 0, pUpdate = 0, pUnchanged = 0;

    for (final item in importedPeople) {
      final id = item['id'] as String;
      if (!existingPeopleMap.containsKey(id)) {
        pAdd++;
      } else {
        final existing = existingPeopleMap[id]!;
        final impUpdated = parseDate(item['updatedAt']);
        final impRev = (item['revision'] as num?)?.toInt() ?? 1;
        if (impUpdated.isAfter(existing.updatedAt) ||
            impRev > existing.revision) {
          pUpdate++;
        } else {
          pUnchanged++;
        }
      }
    }

    // Prévia: Visits
    final importedVisits = (data['visits'] as List<dynamic>?) ?? [];
    final existingVisits = await repository.getAllVisits();
    final existingVisitsIds = {for (var v in existingVisits) v.id};
    int vAdd = 0, vUpdate = 0;
    for (final item in importedVisits) {
      final id = item['id'] as String;
      if (!existingVisitsIds.contains(id)) {
        vAdd++;
      } else {
        vUpdate++;
      }
    }

    // Prévia: Studies
    final importedStudies = (data['bibleStudies'] as List<dynamic>?) ?? [];
    final existingStudies = await repository.getAllStudies();
    final existingStudiesIds = {for (var s in existingStudies) s.id};
    int sAdd = 0;
    for (final item in importedStudies) {
      if (!existingStudiesIds.contains(item['id'] as String)) sAdd++;
    }

    // Prévia: Sessions
    final importedSessions = (data['studySessions'] as List<dynamic>?) ?? [];
    final existingSessions = await repository.getAllSessions();
    final existingSessionsIds = {for (var s in existingSessions) s.id};
    int sessAdd = 0;
    for (final item in importedSessions) {
      if (!existingSessionsIds.contains(item['id'] as String)) sessAdd++;
    }

    // Prévia: Appointments
    final importedAppointments = (data['appointments'] as List<dynamic>?) ?? [];
    final existingAppts = await repository.getAllAppointments();
    final existingApptsIds = {for (var a in existingAppts) a.id};
    int aAdd = 0;
    for (final item in importedAppointments) {
      if (!existingApptsIds.contains(item['id'] as String)) aAdd++;
    }

    // Prévia: Activities
    final importedActivities =
        (data['activityRecords'] as List<dynamic>?) ?? [];
    final existingActivities = await repository.getAllActivities();
    final existingActivitiesIds = {for (var act in existingActivities) act.id};
    int actAdd = 0;
    for (final item in importedActivities) {
      if (!existingActivitiesIds.contains(item['id'] as String)) actAdd++;
    }

    // Prévia: VoiceNotes
    final db = repository.db;
    final importedVoiceNotes = (data['voiceNotes'] as List<dynamic>?) ?? [];
    final existingVoiceNotes = await db.select(db.voiceNotes).get();
    final existingVnIds = {for (var vn in existingVoiceNotes) vn.id};
    int vnAdd = 0;
    for (final item in importedVoiceNotes) {
      if (!existingVnIds.contains(item['id'] as String)) vnAdd++;
    }

    // Prévia: PhoneContacts
    final importedContacts = (data['phoneContacts'] as List<dynamic>?) ?? [];
    final existingContacts = await db.select(db.phoneContacts).get();
    final existingContactIds = {for (var c in existingContacts) c.id};
    int phoneAdd = 0;
    for (final item in importedContacts) {
      if (!existingContactIds.contains(item['id'] as String)) phoneAdd++;
    }

    // Prévia: Landmarks
    final importedLandmarks =
        (data['territoryLandmarks'] as List<dynamic>?) ?? [];
    final existingLandmarks = await db.select(db.territoryLandmarks).get();
    final existingLandmarkIds = {for (var l in existingLandmarks) l.id};
    int landAdd = 0;
    for (final item in importedLandmarks) {
      if (!existingLandmarkIds.contains(item['id'] as String)) landAdd++;
    }

    // Prévia: FamilyTies
    final importedFamilyTies = (data['familyTies'] as List<dynamic>?) ?? [];
    final existingFamilyTies = await db.select(db.familyTies).get();
    final existingFtIds = {for (var ft in existingFamilyTies) ft.id};
    int ftAdd = 0;
    for (final item in importedFamilyTies) {
      if (!existingFtIds.contains(item['id'] as String)) ftAdd++;
    }

    // Prévia: Experiences
    final importedExp = (data['ministryExperiences'] as List<dynamic>?) ?? [];
    final existingExp = await db.select(db.ministryExperiences).get();
    final existingExpIds = {for (var e in existingExp) e.id};
    int expAdd = 0;
    for (final item in importedExp) {
      if (!existingExpIds.contains(item['id'] as String)) expAdd++;
    }

    // Prévia: Photos
    final importedPhotos = (data['personPhotos'] as List<dynamic>?) ?? [];
    final existingPhotos = await db.select(db.personPhotos).get();
    final existingPhotoIds = {for (var p in existingPhotos) p.id};
    int photoAdd = 0;
    for (final item in importedPhotos) {
      if (!existingPhotoIds.contains(item['id'] as String)) photoAdd++;
    }

    // Prévia: Publications
    final importedPubs = (data['personPublications'] as List<dynamic>?) ?? [];
    final existingPubs = await db.select(db.personPublications).get();
    final existingPubIds = {for (var p in existingPubs) p.id};
    int pubAdd = 0;
    for (final item in importedPubs) {
      if (!existingPubIds.contains(item['id'] as String)) pubAdd++;
    }

    // Prévia: Research Articles
    final importedArticles = (data['researchArticles'] as List<dynamic>?) ?? [];
    final existingArticles = await db.select(db.researchArticles).get();
    final existingArticleIds = {for (var a in existingArticles) a.id};
    int artAdd = 0;
    for (final item in importedArticles) {
      if (!existingArticleIds.contains(item['id'] as String)) artAdd++;
    }

    // Prévia: Territory Sectors
    final importedSectors = (data['territorySectors'] as List<dynamic>?) ?? [];
    final existingSectors = await db.select(db.territorySectors).get();
    final existingSectorIds = {for (var s in existingSectors) s.id};
    int secAdd = 0;
    for (final item in importedSectors) {
      if (!existingSectorIds.contains(item['id'] as String)) secAdd++;
    }

    // Prévia: External Calendar Events
    final importedCalEvents =
        (data['externalCalendarEvents'] as List<dynamic>?) ?? [];
    final existingCalEvents = await db.select(db.externalCalendarEvents).get();
    final existingCalEventIds = {for (var c in existingCalEvents) c.id};
    int calEventAdd = 0;
    for (final item in importedCalEvents) {
      if (!existingCalEventIds.contains(item['id'] as String)) calEventAdd++;
    }

    // Prévia: Calendar Links
    final importedCalLinks =
        (data['calendarEventLinks'] as List<dynamic>?) ?? [];
    final existingCalLinks = await db.select(db.calendarEventLinks).get();
    final existingCalLinkIds = {for (var l in existingCalLinks) l.id};
    int calLinkAdd = 0;
    for (final item in importedCalLinks) {
      if (!existingCalLinkIds.contains(item['id'] as String)) calLinkAdd++;
    }

    // Prévia: Idiomas
    final importedLangs = (data['appLanguages'] as List<dynamic>?) ?? [];
    final existingLangs = await db.select(db.appLanguages).get();
    final existingLangIds = {for (var l in existingLangs) l.id};
    int langAdd = 0;
    for (final item in importedLangs) {
      if (!existingLangIds.contains(item['id'] as String)) langAdd++;
    }

    // Prévia: Ticuna
    final importedTicunaWords = (data['ticunaWords'] as List<dynamic>?) ?? [];
    final existingTicunaWordIds = {
      for (var w in await _readRawTableRows('ticuna_words')) w['id'] as String,
    };
    int twAdd = 0;
    for (final item in importedTicunaWords) {
      if (!existingTicunaWordIds.contains(item['id'] as String)) twAdd++;
    }

    final importedTicunaPhrases =
        (data['ticunaPhrases'] as List<dynamic>?) ?? [];
    final existingTicunaPhraseIds = {
      for (var pRow in await _readRawTableRows('ticuna_phrases'))
        pRow['id'] as String,
    };
    int tpAdd = 0;
    for (final item in importedTicunaPhrases) {
      if (!existingTicunaPhraseIds.contains(item['id'] as String)) tpAdd++;
    }

    final importedTicunaTags = (data['ticunaTags'] as List<dynamic>?) ?? [];
    final existingTicunaTagIds = {
      for (var tRow in await _readRawTableRows('ticuna_tags'))
        tRow['id'] as String,
    };
    int ttAdd = 0;
    for (final item in importedTicunaTags) {
      if (!existingTicunaTagIds.contains(item['id'] as String)) ttAdd++;
    }

    // Prévia: Notas & Documentos de Conhecimento
    final importedKNotes = (data['knowledgeNotes'] as List<dynamic>?) ?? [];
    final existingKNotes = await db.select(db.knowledgeNotes).get();
    final existingKNoteIds = {for (var n in existingKNotes) n.id};
    int kNoteAdd = 0;
    for (final item in importedKNotes) {
      if (!existingKNoteIds.contains(item['id'] as String)) kNoteAdd++;
    }

    final importedKDocs = (data['knowledgeDocuments'] as List<dynamic>?) ?? [];
    final existingKDocs = await db.select(db.knowledgeDocuments).get();
    final existingKDocIds = {for (var d in existingKDocs) d.id};
    int kDocAdd = 0;
    for (final item in importedKDocs) {
      if (!existingKDocIds.contains(item['id'] as String)) kDocAdd++;
    }

    // Prévia: Sync Queue (22ª Tabela)
    final importedSyncQueue = (data['syncQueue'] as List<dynamic>?) ?? [];
    final existingSyncQueue = await db.select(db.syncQueue).get();
    final existingSyncQueueIds = {for (var sq in existingSyncQueue) sq.id};
    int sqAdd = 0;
    for (final item in importedSyncQueue) {
      if (!existingSyncQueueIds.contains(item['id'] as String)) sqAdd++;
    }

    final voiceNoteAudios =
        (data['voiceNoteAudios'] as Map<String, dynamic>?) ?? {};
    final voiceNoteAudioHashes =
        (data['voiceNoteAudioHashes'] as Map<String, dynamic>?) ?? {};
    final corruptedAudioIds = <String>[];
    for (final entry in voiceNoteAudios.entries) {
      if (voiceNoteAudioHashes.containsKey(entry.key)) {
        try {
          final bytes = base64Decode(entry.value as String);
          final actualHash = sha256.convert(bytes).toString();
          if (actualHash != voiceNoteAudioHashes[entry.key]) {
            corruptedAudioIds.add(entry.key);
          }
        } catch (e, st) {
          AppLogger.warning('Falha ao validar hash de áudio voiceNote (${entry.key})', e, st);
          corruptedAudioIds.add(entry.key);
        }
      } else {
        corruptedAudioIds.add(entry.key);
      }
    }

    final ticunaAudios = (data['ticunaAudios'] as Map<String, dynamic>?) ?? {};
    final ticunaAudioHashes =
        (data['ticunaAudioHashes'] as Map<String, dynamic>?) ?? {};
    for (final entry in ticunaAudios.entries) {
      if (ticunaAudioHashes.containsKey(entry.key)) {
        try {
          final bytes = base64Decode(entry.value as String);
          final actualHash = sha256.convert(bytes).toString();
          if (actualHash != ticunaAudioHashes[entry.key]) {
            corruptedAudioIds.add(entry.key);
          }
        } catch (e, st) {
          AppLogger.warning('Falha ao validar hash de áudio Ticuna (${entry.key})', e, st);
          corruptedAudioIds.add(entry.key);
        }
      } else {
        corruptedAudioIds.add(entry.key);
      }
    }

    final docFiles =
        (data['knowledgeDocumentFiles'] as Map<String, dynamic>?) ?? {};
    final docHashes =
        (data['knowledgeDocumentHashes'] as Map<String, dynamic>?) ?? {};
    final corruptedDocumentIds = <String>[];
    for (final entry in docFiles.entries) {
      if (docHashes.containsKey(entry.key)) {
        try {
          final bytes = base64Decode(entry.value as String);
          final actualHash = sha256.convert(bytes).toString();
          if (actualHash != docHashes[entry.key]) {
            corruptedDocumentIds.add(entry.key);
          }
        } catch (e, st) {
          AppLogger.warning('Falha ao validar hash de documento (${entry.key})', e, st);
          corruptedDocumentIds.add(entry.key);
        }
      } else {
        corruptedDocumentIds.add(entry.key);
      }
    }

    final tableList =
        (data['exported_tables'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];

    return RestorePreview(
      peopleToAdd: pAdd,
      peopleToUpdate: pUpdate,
      peopleUnchanged: pUnchanged,
      visitsToAdd: vAdd,
      visitsToUpdate: vUpdate,
      studiesToAdd: sAdd,
      sessionsToAdd: sessAdd,
      appointmentsToAdd: aAdd,
      activitiesToAdd: actAdd,
      syncQueueToAdd: sqAdd,
      voiceNotesToAdd: vnAdd,
      phoneContactsToAdd: phoneAdd,
      landmarksToAdd: landAdd,
      familyTiesToAdd: ftAdd,
      experiencesToAdd: expAdd,
      photosToAdd: photoAdd,
      publicationsToAdd: pubAdd,
      articlesToAdd: artAdd,
      sectorsToAdd: secAdd,
      calendarEventsToAdd: calEventAdd,
      calendarLinksToAdd: calLinkAdd,
      appLanguagesToAdd: langAdd,
      ticunaWordsToAdd: twAdd,
      ticunaPhrasesToAdd: tpAdd,
      ticunaTagsToAdd: ttAdd,
      knowledgeNotesToAdd: kNoteAdd,
      knowledgeDocumentsToAdd: kDocAdd,
      inventoryTables: tableList,
      corruptedAudioIds: corruptedAudioIds,
      corruptedDocumentIds: corruptedDocumentIds,
      rawDecryptedData: data,
    );
  }

  static const Set<String> _dateFieldNames = {
    'createdAt', 'created_at',
    'updatedAt', 'updated_at',
    'deletedAt', 'deleted_at',
    'date', 'dateTimeField', 'date_time_field',
    'firstContactAt', 'first_contact_at',
    'lastContactAt', 'last_contact_at',
    'nextActionAt', 'next_action_at',
    'suggestedReturnDate', 'suggested_return_date',
    'startedAt', 'started_at',
    'lastSessionAt', 'last_session_at',
    'nextPlannedAt', 'next_planned_at',
    'startTime', 'start_time',
    'endTime', 'end_time',
    'lastModifiedExternal', 'last_modified_external',
    'lastSyncedAt', 'last_synced_at',
    'lastReviewedAt', 'last_reviewed_at',
  };

  Map<String, dynamic> _normalizePayloadDates(Map<String, dynamic> payload) {
    final result = Map<String, dynamic>.from(payload);
    for (final entry in result.entries) {
      final key = entry.key;
      final val = entry.value;
      if (_dateFieldNames.contains(key) && val != null) {
        final iso = SyncTimestamp.toIso8601String(val);
        if (iso != null) {
          result[key] = iso;
        }
      }
    }
    return result;
  }

  bool _shouldReconstituteSyncQueue = false;

  Future<void> _reconstituteSyncQueue(
    String entityType,
    String entityId,
    String operation,
    Map<String, dynamic> payload,
  ) async {
    if (!_shouldReconstituteSyncQueue) return;
    try {
      final normalized = _normalizePayloadDates(payload);
      await repository.db
          .into(repository.db.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: _uuid.v4(),
              entityType: entityType,
              entityId: entityId,
              operation: operation,
              payload: jsonEncode(normalized),
              createdAt: DateTime.now(),
              status: const Value('pending'),
            ),
          );
    } catch (e, st) {
      AppLogger.warning(
        'Falha ao reconstituir sync_queue para $entityType/$entityId',
        e,
        st,
      );
    }
  }

  /// Aplica a restauração de forma transacional e idempotente,
  /// garantindo que registros locais mais recentes nunca sejam sobrescritos por backups obsoletos.
  Future<RestoreResult> commitRestore(RestorePreview preview) async {
    final db = repository.db;
    final data = preview.rawDecryptedData;
    _shouldReconstituteSyncQueue = !data.containsKey('syncQueue');
    final corruptedFiles = <String>[];
    int totalRestoredCount = 0;

    // Snapshot de segurança obrigatório: falha ABORTA a restauração — não continua silenciosamente.
    final safetyKey = await _getOrCreateSilentBackupKey();
    final String snapshotData;
    try {
      snapshotData = await exportEncryptedBackup(safetyKey, iterations: 100000);
    } catch (e) {
      throw RestoreAbortedException(
        'Falha ao gerar snapshot de segurança antes da restauração: $e',
      );
    }

    // Persiste snapshot em disco e grava caminho no KV store (ou salva no KV store sob Web).
    _lastPreRestoreSafetyBackup = snapshotData;
    if (kIsWeb) {
      try {
        await db
            .into(db.appKvStore)
            .insertOnConflictUpdate(
              AppKvStoreCompanion.insert(
                key: 'last_safety_snapshot_data',
                value: snapshotData,
                updatedAt: Value(DateTime.now()),
              ),
            );
      } catch (e) {
        throw RestoreAbortedException(
          'Falha ao persistir snapshot de segurança na Web: $e',
        );
      }
    } else {
      try {
        final snapshotFile = await _persistSnapshotToDisk(snapshotData);
        await _validateSnapshotFile(snapshotFile, password: safetyKey);
        await db
            .into(db.appKvStore)
            .insertOnConflictUpdate(
              AppKvStoreCompanion.insert(
                key: 'last_safety_snapshot_path',
                value: snapshotFile.path,
                updatedAt: Value(DateTime.now()),
              ),
            );
      } catch (e) {
        throw RestoreAbortedException(
          'Falha ao persistir ou validar snapshot de segurança: $e',
        );
      }
    }

    Directory? docsDir;
    Directory? stagingDir;
    Directory? audioBackupDir;
    Directory? restoredAudioDir;
    Directory? restoredTicunaDir;
    Directory? restoredDocsDir;
    final stagedFiles = <String, File>{};
    final stagedTicunaFiles = <String, File>{};
    final stagedDocFiles = <String, File>{};
    final replacedOriginalsBackup = <File, File>{};
    final newlyAddedFiles = <File>[];

    final voiceNotes = (data['voiceNotes'] as List<dynamic>?) ?? [];
    final voiceNoteAudios =
        (data['voiceNoteAudios'] as Map<String, dynamic>?) ?? {};
    final voiceNoteAudioHashes =
        (data['voiceNoteAudioHashes'] as Map<String, dynamic>?) ?? {};

    final ticunaWordsRows = (data['ticunaWords'] as List<dynamic>?) ?? [];
    final ticunaPhrasesRows = (data['ticunaPhrases'] as List<dynamic>?) ?? [];
    final ticunaTagsRows = (data['ticunaTags'] as List<dynamic>?) ?? [];
    final ticunaAudios =
        (data['ticunaAudios'] as Map<String, dynamic>?) ?? {};
    final ticunaAudioHashes =
        (data['ticunaAudioHashes'] as Map<String, dynamic>?) ?? {};

    final docRows = (data['knowledgeDocuments'] as List<dynamic>?) ?? [];
    final docFiles =
        (data['knowledgeDocumentFiles'] as Map<String, dynamic>?) ?? {};
    final docHashes =
        (data['knowledgeDocumentHashes'] as Map<String, dynamic>?) ?? {};

    if (!kIsWeb &&
        (voiceNoteAudios.isNotEmpty ||
            ticunaAudios.isNotEmpty ||
            docFiles.isNotEmpty)) {
      try {
        docsDir = await _getDocsDir();
        final runId =
            '${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4().substring(0, 8)}';
        stagingDir = Directory('${docsDir.path}/safety_staging_$runId');
        audioBackupDir = Directory(
          '${docsDir.path}/safety_audio_backup_$runId',
        );
        await stagingDir.create(recursive: true);
        await audioBackupDir.create(recursive: true);

        if (voiceNoteAudios.isNotEmpty) {
          restoredAudioDir = Directory('${docsDir.path}/voice_notes');
          if (!restoredAudioDir.existsSync()) {
            await restoredAudioDir.create(recursive: true);
          }

          // Etapa 1: Extrair e validar notas de voz em staging antes de tocar no destino
          for (final item in voiceNotes) {
            final id = (item as Map<String, dynamic>)['id'] as String?;
            if (id != null && voiceNoteAudios.containsKey(id)) {
              try {
                final audioBytes = base64Decode(voiceNoteAudios[id] as String);
                if (voiceNoteAudioHashes.containsKey(id)) {
                  final expectedHash = voiceNoteAudioHashes[id] as String;
                  final actualHash = sha256.convert(audioBytes).toString();
                  if (actualHash != expectedHash) {
                    corruptedFiles.add(id);
                    continue;
                  }
                }
                final stagingFile = File('${stagingDir.path}/vn_$id.m4a');
                await stagingFile.writeAsBytes(audioBytes, flush: true);
                stagedFiles[id] = stagingFile;

                final targetFile = File('${restoredAudioDir.path}/vn_$id.m4a');
                if (await targetFile.exists()) {
                  final backupFile = File('${audioBackupDir.path}/vn_$id.m4a');
                  await targetFile.copy(backupFile.path);
                  replacedOriginalsBackup[targetFile] = backupFile;
                } else {
                  newlyAddedFiles.add(targetFile);
                }
              } catch (e, st) {
                AppLogger.warning('Falha ao preparar restauração de áudio voiceNote ($id)', e, st);
                corruptedFiles.add(id);
              }
            }
          }
        }

        if (ticunaAudios.isNotEmpty) {
          restoredTicunaDir = Directory('${docsDir.path}/ticuna_audios');
          if (!restoredTicunaDir.existsSync()) {
            await restoredTicunaDir.create(recursive: true);
          }

          for (final entry in ticunaAudios.entries) {
            final key = entry.key;
            try {
              final audioBytes = base64Decode(entry.value as String);
              if (ticunaAudioHashes.containsKey(key)) {
                final expectedHash = ticunaAudioHashes[key] as String;
                final actualHash = sha256.convert(audioBytes).toString();
                if (actualHash != expectedHash) {
                  corruptedFiles.add(key);
                  continue;
                }
              }
              final safeKey = key.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
              final stagingFile = File('${stagingDir.path}/tc_$safeKey.m4a');
              await stagingFile.writeAsBytes(audioBytes, flush: true);
              stagedTicunaFiles[key] = stagingFile;

              final targetFile =
                  File('${restoredTicunaDir.path}/$safeKey.m4a');
              if (await targetFile.exists()) {
                final backupFile =
                    File('${audioBackupDir.path}/tc_$safeKey.m4a');
                await targetFile.copy(backupFile.path);
                replacedOriginalsBackup[targetFile] = backupFile;
              } else {
                newlyAddedFiles.add(targetFile);
              }
            } catch (e, st) {
              AppLogger.warning('Falha ao preparar restauração de áudio Ticuna ($key)', e, st);
              corruptedFiles.add(key);
            }
          }
        }

        if (docFiles.isNotEmpty) {
          restoredDocsDir = Directory('${docsDir.path}/knowledge_documents');
          if (!restoredDocsDir.existsSync()) {
            await restoredDocsDir.create(recursive: true);
          }

          for (final item in docRows) {
            final docMap = item as Map<String, dynamic>;
            final id = docMap['id'] as String?;
            if (id != null && docFiles.containsKey(id)) {
              try {
                final bytes = base64Decode(docFiles[id] as String);
                if (docHashes.containsKey(id)) {
                  final expectedHash = docHashes[id] as String;
                  final actualHash = sha256.convert(bytes).toString();
                  if (actualHash != expectedHash) {
                    corruptedFiles.add(id);
                    continue;
                  }
                }
                final rawName =
                    (docMap['fileName'] ?? docMap['file_name'] ?? 'doc')
                        .toString();
                final safeName =
                    rawName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
                final stagingFile =
                    File('${stagingDir.path}/doc_${id}_$safeName');
                await stagingFile.writeAsBytes(bytes, flush: true);
                stagedDocFiles[id] = stagingFile;

                final targetFile =
                    File('${restoredDocsDir.path}/doc_${id}_$safeName');
                if (await targetFile.exists()) {
                  final backupFile =
                      File('${audioBackupDir.path}/doc_${id}_$safeName');
                  await targetFile.copy(backupFile.path);
                  replacedOriginalsBackup[targetFile] = backupFile;
                } else {
                  newlyAddedFiles.add(targetFile);
                }
              } catch (e, st) {
                AppLogger.warning('Falha ao preparar restauração de documento ($id)', e, st);
                corruptedFiles.add(id);
              }
            }
          }
        }
      } catch (e) {
        if (stagingDir != null && stagingDir.existsSync()) {
          try {
            stagingDir.deleteSync(recursive: true);
          } catch (delErr, delSt) {
            AppLogger.warning('Falha ao limpar stagingDir após erro de mídia', delErr, delSt);
          }
        }
        if (audioBackupDir != null && audioBackupDir.existsSync()) {
          try {
            audioBackupDir.deleteSync(recursive: true);
          } catch (delErr, delSt) {
            AppLogger.warning('Falha ao limpar audioBackupDir após erro de mídia', delErr, delSt);
          }
        }
        throw RestoreMediaException(
          'Falha na preparação da área de staging de mídia/documentos: $e',
        );
      }
    }

    if (ticunaWordsRows.isNotEmpty ||
        ticunaPhrasesRows.isNotEmpty ||
        ticunaTagsRows.isNotEmpty) {
      await _ensureTicunaTables();
    }

    try {
      await db.transaction(() async {
        // 1. Pessoas
        final people = (data['people'] as List<dynamic>?) ?? [];
        for (final item in people) {
          final entry = PersonEntry.fromJson(item as Map<String, dynamic>);
          final existing = await (db.select(
            db.people,
          )..where((tbl) => tbl.id.equals(entry.id))).getSingleOrNull();
          if (existing == null) {
            await db.into(db.people).insert(entry);
            await _reconstituteSyncQueue('people', entry.id, 'INSERT', item);
            totalRestoredCount++;
          } else if (entry.updatedAt.isAfter(existing.updatedAt) ||
              entry.revision > existing.revision) {
            await db.update(db.people).replace(entry);
            await _reconstituteSyncQueue('people', entry.id, 'UPDATE', item);
            totalRestoredCount++;
          }
        }

        // 2. Visitas
        final visits = (data['visits'] as List<dynamic>?) ?? [];
        for (final item in visits) {
          final entry = VisitEntry.fromJson(item as Map<String, dynamic>);
          final existing = await (db.select(
            db.visits,
          )..where((tbl) => tbl.id.equals(entry.id))).getSingleOrNull();
          if (existing == null) {
            await db.into(db.visits).insert(entry);
            await _reconstituteSyncQueue('visits', entry.id, 'INSERT', item);
            totalRestoredCount++;
          } else if (entry.updatedAt.isAfter(existing.updatedAt) ||
              entry.revision > existing.revision) {
            await db.update(db.visits).replace(entry);
            await _reconstituteSyncQueue('visits', entry.id, 'UPDATE', item);
            totalRestoredCount++;
          }
        }

        // 3. Estudos
        final studies = (data['bibleStudies'] as List<dynamic>?) ?? [];
        for (final item in studies) {
          final entry = BibleStudyEntry.fromJson(item as Map<String, dynamic>);
          final existing = await (db.select(
            db.bibleStudies,
          )..where((tbl) => tbl.id.equals(entry.id))).getSingleOrNull();
          if (existing == null) {
            await db.into(db.bibleStudies).insert(entry);
            await _reconstituteSyncQueue(
              'bible_studies',
              entry.id,
              'INSERT',
              item,
            );
            totalRestoredCount++;
          } else if (entry.updatedAt.isAfter(existing.updatedAt) ||
              entry.revision > existing.revision) {
            await db.update(db.bibleStudies).replace(entry);
            await _reconstituteSyncQueue(
              'bible_studies',
              entry.id,
              'UPDATE',
              item,
            );
            totalRestoredCount++;
          }
        }

        // 4. Participantes
        final participants =
            (data['studyParticipants'] as List<dynamic>?) ?? [];
        for (final item in participants) {
          final entry = StudyParticipantEntry.fromJson(
            item as Map<String, dynamic>,
          );
          final existing = await (db.select(
            db.studyParticipants,
          )..where((tbl) => tbl.id.equals(entry.id))).getSingleOrNull();
          if (existing == null) {
            await db.into(db.studyParticipants).insert(entry);
            await _reconstituteSyncQueue(
              'study_participants',
              entry.id,
              'INSERT',
              item,
            );
            totalRestoredCount++;
          } else if (entry.updatedAt.isAfter(existing.updatedAt) ||
              entry.revision > existing.revision) {
            await db.update(db.studyParticipants).replace(entry);
            await _reconstituteSyncQueue(
              'study_participants',
              entry.id,
              'UPDATE',
              item,
            );
            totalRestoredCount++;
          }
        }

        // 5. Sessões
        final sessions = (data['studySessions'] as List<dynamic>?) ?? [];
        for (final item in sessions) {
          final entry = StudySessionEntry.fromJson(
            item as Map<String, dynamic>,
          );
          final existing = await (db.select(
            db.studySessions,
          )..where((tbl) => tbl.id.equals(entry.id))).getSingleOrNull();
          if (existing == null) {
            await db.into(db.studySessions).insert(entry);
            await _reconstituteSyncQueue(
              'study_sessions',
              entry.id,
              'INSERT',
              item,
            );
            totalRestoredCount++;
          } else if (entry.updatedAt.isAfter(existing.updatedAt) ||
              entry.revision > existing.revision) {
            await db.update(db.studySessions).replace(entry);
            await _reconstituteSyncQueue(
              'study_sessions',
              entry.id,
              'UPDATE',
              item,
            );
            totalRestoredCount++;
          }
        }

        // 6. Compromissos
        final appointments = (data['appointments'] as List<dynamic>?) ?? [];
        for (final item in appointments) {
          final entry = AppointmentEntry.fromJson(item as Map<String, dynamic>);
          final existing = await (db.select(
            db.appointments,
          )..where((tbl) => tbl.id.equals(entry.id))).getSingleOrNull();
          if (existing == null) {
            await db.into(db.appointments).insert(entry);
            await _reconstituteSyncQueue(
              'appointments',
              entry.id,
              'INSERT',
              item,
            );
            totalRestoredCount++;
          } else if (entry.updatedAt.isAfter(existing.updatedAt) ||
              entry.revision > existing.revision) {
            await db.update(db.appointments).replace(entry);
            await _reconstituteSyncQueue(
              'appointments',
              entry.id,
              'UPDATE',
              item,
            );
            totalRestoredCount++;
          }
        }

        // 7. Atividades
        final activities = (data['activityRecords'] as List<dynamic>?) ?? [];
        for (final item in activities) {
          final entry = ActivityRecordEntry.fromJson(
            item as Map<String, dynamic>,
          );
          final existing = await (db.select(
            db.activityRecords,
          )..where((tbl) => tbl.id.equals(entry.id))).getSingleOrNull();
          if (existing == null) {
            await db.into(db.activityRecords).insert(entry);
            await _reconstituteSyncQueue(
              'activity_records',
              entry.id,
              'INSERT',
              item,
            );
            totalRestoredCount++;
          } else if (entry.updatedAt.isAfter(existing.updatedAt) ||
              entry.revision > existing.revision) {
            await db.update(db.activityRecords).replace(entry);
            await _reconstituteSyncQueue(
              'activity_records',
              entry.id,
              'UPDATE',
              item,
            );
            totalRestoredCount++;
          }
        }

        // 8. Notas de Voz & Áudios Binários
        for (final item in voiceNotes) {
          var entry = VoiceNoteEntry.fromJson(item as Map<String, dynamic>);
          if (stagedFiles.containsKey(entry.id) && restoredAudioDir != null) {
            final targetFile = File(
              '${restoredAudioDir.path}/vn_${entry.id}.m4a',
            );
            await stagedFiles[entry.id]!.copy(targetFile.path);
            entry = entry.copyWith(audioFilePath: Value(targetFile.path));
          } else if (voiceNoteAudios.containsKey(entry.id) &&
              !stagedFiles.containsKey(entry.id)) {
            // Nota cujo áudio falhou na integridade em staging
            entry = entry.copyWith(audioFilePath: const Value(null));
          }

          final existing = await (db.select(
            db.voiceNotes,
          )..where((tbl) => tbl.id.equals(entry.id))).getSingleOrNull();
          if (existing == null) {
            await db.into(db.voiceNotes).insert(entry);
            await _reconstituteSyncQueue(
              'voice_notes',
              entry.id,
              'INSERT',
              item,
            );
            totalRestoredCount++;
          } else if (entry.updatedAt.isAfter(existing.updatedAt) ||
              entry.revision > existing.revision) {
            await db.update(db.voiceNotes).replace(entry);
            await _reconstituteSyncQueue(
              'voice_notes',
              entry.id,
              'UPDATE',
              item,
            );
            totalRestoredCount++;
          }
        }

        // 9. Contatos Telefônicos
        final contacts = (data['phoneContacts'] as List<dynamic>?) ?? [];
        for (final item in contacts) {
          final entry = PhoneContactEntry.fromJson(
            item as Map<String, dynamic>,
          );
          final existing = await (db.select(
            db.phoneContacts,
          )..where((tbl) => tbl.id.equals(entry.id))).getSingleOrNull();
          if (existing == null) {
            await db.into(db.phoneContacts).insert(entry);
            await _reconstituteSyncQueue(
              'phone_contacts',
              entry.id,
              'INSERT',
              item,
            );
            totalRestoredCount++;
          } else if (entry.updatedAt.isAfter(existing.updatedAt) ||
              entry.revision > existing.revision) {
            await db.update(db.phoneContacts).replace(entry);
            await _reconstituteSyncQueue(
              'phone_contacts',
              entry.id,
              'UPDATE',
              item,
            );
            totalRestoredCount++;
          }
        }

        // 10. Marcos do Território
        final landmarks = (data['territoryLandmarks'] as List<dynamic>?) ?? [];
        for (final item in landmarks) {
          final entry = TerritoryLandmarkEntry.fromJson(
            item as Map<String, dynamic>,
          );
          final existing = await (db.select(
            db.territoryLandmarks,
          )..where((tbl) => tbl.id.equals(entry.id))).getSingleOrNull();
          if (existing == null) {
            await db.into(db.territoryLandmarks).insert(entry);
            await _reconstituteSyncQueue(
              'territory_landmarks',
              entry.id,
              'INSERT',
              item,
            );
            totalRestoredCount++;
          } else if (entry.updatedAt.isAfter(existing.updatedAt) ||
              entry.revision > existing.revision) {
            await db.update(db.territoryLandmarks).replace(entry);
            await _reconstituteSyncQueue(
              'territory_landmarks',
              entry.id,
              'UPDATE',
              item,
            );
            totalRestoredCount++;
          }
        }

        // 11. Vínculos Familiares
        final familyTies = (data['familyTies'] as List<dynamic>?) ?? [];
        for (final item in familyTies) {
          final map = item as Map<String, dynamic>;
          final entry = FamilyTieEntry.fromJson(map);
          final existing = await (db.select(
            db.familyTies,
          )..where((tbl) => tbl.id.equals(entry.id))).getSingleOrNull();
          if (existing == null) {
            await db.into(db.familyTies).insert(entry);
            await _reconstituteSyncQueue('family_ties', entry.id, 'INSERT', map);
            totalRestoredCount++;
          } else if ((entry.updatedAt ?? entry.createdAt).isAfter(
                existing.updatedAt ?? existing.createdAt,
              ) ||
              entry.revision > existing.revision) {
            await db.update(db.familyTies).replace(entry);
            await _reconstituteSyncQueue('family_ties', entry.id, 'UPDATE', map);
            totalRestoredCount++;
          }
        }

        // 12. Experiências Ministeriais
        final experiences =
            (data['ministryExperiences'] as List<dynamic>?) ?? [];
        for (final item in experiences) {
          final map = item as Map<String, dynamic>;
          final entry = MinistryExperienceEntry.fromJson(map);
          final existing = await (db.select(
            db.ministryExperiences,
          )..where((tbl) => tbl.id.equals(entry.id))).getSingleOrNull();
          if (existing == null) {
            await db.into(db.ministryExperiences).insert(entry);
            await _reconstituteSyncQueue(
              'ministry_experiences',
              entry.id,
              'INSERT',
              map,
            );
            totalRestoredCount++;
          } else if (entry.updatedAt.isAfter(existing.updatedAt) ||
              entry.revision > existing.revision) {
            await db.update(db.ministryExperiences).replace(entry);
            await _reconstituteSyncQueue(
              'ministry_experiences',
              entry.id,
              'UPDATE',
              map,
            );
            totalRestoredCount++;
          }
        }

        // 13. Fotos de Pessoas e Residências
        final photos = (data['personPhotos'] as List<dynamic>?) ?? [];
        for (final item in photos) {
          final map = Map<String, dynamic>.from(item as Map);
          if (map.containsKey('image_data') && !map.containsKey('imageData')) {
            map['imageData'] = map['image_data'];
          }
          if (map.containsKey('file_path') && !map.containsKey('filePath')) {
            map['filePath'] = map['file_path'];
          }
          if (map.containsKey('person_id') && !map.containsKey('personId')) {
            map['personId'] = map['person_id'];
          }
          if (map.containsKey('photo_type') && !map.containsKey('photoType')) {
            map['photoType'] = map['photo_type'];
          }
          if (map.containsKey('created_at') && !map.containsKey('createdAt')) {
            map['createdAt'] = map['created_at'];
          }
          if (map.containsKey('updated_at') && !map.containsKey('updatedAt')) {
            map['updatedAt'] = map['updated_at'];
          }
          if (map.containsKey('deleted_at') && !map.containsKey('deletedAt')) {
            map['deletedAt'] = map['deleted_at'];
          }
          final restoredFilePath = map['filePath']?.toString() ?? '';
          final restoredImageData = map['imageData']?.toString() ?? '';
          if (restoredFilePath.isNotEmpty &&
              !restoredFilePath.startsWith('http') &&
              restoredImageData.isNotEmpty &&
              (kIsWeb || !File(restoredFilePath).existsSync())) {
            map['filePath'] = null;
          }
          final entry = PersonPhotoEntry.fromJson(map);
          final existing = await (db.select(
            db.personPhotos,
          )..where((tbl) => tbl.id.equals(entry.id))).getSingleOrNull();
          if (existing == null) {
            await db.into(db.personPhotos).insert(entry);
            await _reconstituteSyncQueue(
              'person_photos',
              entry.id,
              'INSERT',
              entry.toJson(),
            );
            totalRestoredCount++;
          } else if ((entry.updatedAt ?? entry.createdAt).isAfter(
                existing.updatedAt ?? existing.createdAt,
              ) ||
              entry.revision > existing.revision) {
            await db.update(db.personPhotos).replace(entry);
            await _reconstituteSyncQueue(
              'person_photos',
              entry.id,
              'UPDATE',
              entry.toJson(),
            );
            totalRestoredCount++;
          }
        }

        // 14. Publicações e Pedidos das Pessoas
        final publications =
            (data['personPublications'] as List<dynamic>?) ?? [];
        for (final item in publications) {
          final map = item as Map<String, dynamic>;
          final entry = PersonPublicationEntry.fromJson(map);
          final existing = await (db.select(
            db.personPublications,
          )..where((tbl) => tbl.id.equals(entry.id))).getSingleOrNull();
          if (existing == null) {
            await db.into(db.personPublications).insert(entry);
            await _reconstituteSyncQueue(
              'person_publications',
              entry.id,
              'INSERT',
              map,
            );
            totalRestoredCount++;
          } else if ((entry.updatedAt ?? entry.createdAt).isAfter(
                existing.updatedAt ?? existing.createdAt,
              ) ||
              entry.revision > existing.revision) {
            await db.update(db.personPublications).replace(entry);
            await _reconstituteSyncQueue(
              'person_publications',
              entry.id,
              'UPDATE',
              map,
            );
            totalRestoredCount++;
          }
        }

        // 15. Artigos de Pesquisa
        final articles = (data['researchArticles'] as List<dynamic>?) ?? [];
        for (final item in articles) {
          final map = item as Map<String, dynamic>;
          final entry = ResearchArticleEntry.fromJson(map);
          final existing = await (db.select(
            db.researchArticles,
          )..where((tbl) => tbl.id.equals(entry.id))).getSingleOrNull();
          if (existing == null) {
            await db.into(db.researchArticles).insert(entry);
            await _reconstituteSyncQueue(
              'research_articles',
              entry.id,
              'INSERT',
              map,
            );
            totalRestoredCount++;
          } else if (entry.updatedAt.isAfter(existing.updatedAt) ||
              entry.revision > existing.revision) {
            await db.update(db.researchArticles).replace(entry);
            await _reconstituteSyncQueue(
              'research_articles',
              entry.id,
              'UPDATE',
              map,
            );
            totalRestoredCount++;
          }
        }

        // 16. Tags de Pesquisa
        final tags = (data['researchTags'] as List<dynamic>?) ?? [];
        for (final item in tags) {
          final map = item as Map<String, dynamic>;
          final entry = ResearchTagEntry.fromJson(map);
          final existing = await (db.select(
            db.researchTags,
          )..where((tbl) => tbl.id.equals(entry.id))).getSingleOrNull();
          if (existing == null) {
            await db.into(db.researchTags).insert(entry);
            await _reconstituteSyncQueue(
              'research_tags',
              entry.id,
              'INSERT',
              map,
            );
            totalRestoredCount++;
          } else if (entry.revision > existing.revision) {
            await db.update(db.researchTags).replace(entry);
            await _reconstituteSyncQueue(
              'research_tags',
              entry.id,
              'UPDATE',
              map,
            );
            totalRestoredCount++;
          }
        }

        // 17. Setores de Território
        final sectors = (data['territorySectors'] as List<dynamic>?) ?? [];
        for (final item in sectors) {
          final map = item as Map<String, dynamic>;
          final entry = TerritorySectorEntry.fromJson(map);
          final existing = await (db.select(
            db.territorySectors,
          )..where((tbl) => tbl.id.equals(entry.id))).getSingleOrNull();
          if (existing == null) {
            await db.into(db.territorySectors).insert(entry);
            await _reconstituteSyncQueue(
              'territory_sectors',
              entry.id,
              'INSERT',
              map,
            );
            totalRestoredCount++;
          } else if ((entry.updatedAt ?? entry.createdAt).isAfter(
                existing.updatedAt ?? existing.createdAt,
              ) ||
              entry.revision > existing.revision) {
            await db.update(db.territorySectors).replace(entry);
            await _reconstituteSyncQueue(
              'territory_sectors',
              entry.id,
              'UPDATE',
              map,
            );
            totalRestoredCount++;
          }
        }

        // 18. Ordem do Manual de Estudante
        final manualOrders =
            (data['studentManualOrder'] as List<dynamic>?) ?? [];
        for (final item in manualOrders) {
          final entry = StudentManualOrderEntry.fromJson(
            item as Map<String, dynamic>,
          );
          final existing =
              await (db.select(db.studentManualOrder)
                    ..where((tbl) => tbl.studyId.equals(entry.studyId)))
                  .getSingleOrNull();
          if (existing == null) {
            await db.into(db.studentManualOrder).insert(entry);
            totalRestoredCount++;
          } else if (entry.revision > existing.revision ||
              (entry.updatedAt != null &&
                  (existing.updatedAt == null ||
                      entry.updatedAt!.isAfter(existing.updatedAt!)))) {
            await db.update(db.studentManualOrder).replace(entry);
            totalRestoredCount++;
          }
        }

        // 19. Eventos de Calendário Externo
        final calendarEvents =
            (data['externalCalendarEvents'] as List<dynamic>?) ?? [];
        for (final item in calendarEvents) {
          final entry = ExternalCalendarEventEntry.fromJson(
            item as Map<String, dynamic>,
          );
          final existing = await (db.select(
            db.externalCalendarEvents,
          )..where((tbl) => tbl.id.equals(entry.id))).getSingleOrNull();
          if (existing == null) {
            await db.into(db.externalCalendarEvents).insert(entry);
            totalRestoredCount++;
          } else if (entry.updatedAt.isAfter(existing.updatedAt) ||
              entry.revision > existing.revision) {
            await db.update(db.externalCalendarEvents).replace(entry);
            totalRestoredCount++;
          }
        }

        // 20. Links de Compromissos de Calendário
        final calendarLinks =
            (data['calendarEventLinks'] as List<dynamic>?) ?? [];
        for (final item in calendarLinks) {
          final entry = CalendarEventLinkEntry.fromJson(
            item as Map<String, dynamic>,
          );
          final existing = await (db.select(
            db.calendarEventLinks,
          )..where((tbl) => tbl.id.equals(entry.id))).getSingleOrNull();
          if (existing == null) {
            await db.into(db.calendarEventLinks).insert(entry);
            totalRestoredCount++;
          } else if (entry.updatedAt.isAfter(existing.updatedAt) ||
              entry.revision > existing.revision) {
            await db.update(db.calendarEventLinks).replace(entry);
            totalRestoredCount++;
          }
        }

        // 21. Inbox Universal
        final inboxRows = (data['inboxEntries'] as List<dynamic>?) ?? [];
        for (final item in inboxRows) {
          final map = item as Map<String, dynamic>;
          final entry = InboxEntry.fromJson(map);
          final existing = await (db.select(
            db.inboxEntries,
          )..where((tbl) => tbl.id.equals(entry.id))).getSingleOrNull();
          if (existing == null) {
            await db.into(db.inboxEntries).insert(entry);
            await _reconstituteSyncQueue(
              'inbox_entries',
              entry.id,
              'INSERT',
              map,
            );
            totalRestoredCount++;
          } else if (entry.updatedAt.isAfter(existing.updatedAt) ||
              entry.revision > existing.revision) {
            await db.update(db.inboxEntries).replace(entry);
            await _reconstituteSyncQueue(
              'inbox_entries',
              entry.id,
              'UPDATE',
              map,
            );
            totalRestoredCount++;
          }
        }

        // 22. Projetos
        final projectRows = (data['projects'] as List<dynamic>?) ?? [];
        for (final item in projectRows) {
          final map = item as Map<String, dynamic>;
          final entry = ProjectEntry.fromJson(map);
          final existing = await (db.select(
            db.projects,
          )..where((tbl) => tbl.id.equals(entry.id))).getSingleOrNull();
          if (existing == null) {
            await db.into(db.projects).insert(entry);
            await _reconstituteSyncQueue('projects', entry.id, 'INSERT', map);
            totalRestoredCount++;
          } else if (entry.updatedAt.isAfter(existing.updatedAt) ||
              entry.revision > existing.revision) {
            await db.update(db.projects).replace(entry);
            await _reconstituteSyncQueue('projects', entry.id, 'UPDATE', map);
            totalRestoredCount++;
          }
        }

        // 23. Tarefas
        final taskRows = (data['tasks'] as List<dynamic>?) ?? [];
        for (final item in taskRows) {
          final map = item as Map<String, dynamic>;
          final entry = TaskEntry.fromJson(map);
          final existing = await (db.select(
            db.tasks,
          )..where((tbl) => tbl.id.equals(entry.id))).getSingleOrNull();
          if (existing == null) {
            await db.into(db.tasks).insert(entry);
            await _reconstituteSyncQueue('tasks', entry.id, 'INSERT', map);
            totalRestoredCount++;
          } else if (entry.updatedAt.isAfter(existing.updatedAt) ||
              entry.revision > existing.revision) {
            await db.update(db.tasks).replace(entry);
            await _reconstituteSyncQueue('tasks', entry.id, 'UPDATE', map);
            totalRestoredCount++;
          }
        }

        // 24. Notas de Conhecimento
        final noteRows = (data['knowledgeNotes'] as List<dynamic>?) ?? [];
        for (final item in noteRows) {
          final map = item as Map<String, dynamic>;
          final entry = KnowledgeNoteEntry.fromJson(map);
          final existing = await (db.select(
            db.knowledgeNotes,
          )..where((tbl) => tbl.id.equals(entry.id))).getSingleOrNull();
          if (existing == null) {
            await db.into(db.knowledgeNotes).insert(entry);
            await _reconstituteSyncQueue(
              'knowledge_notes',
              entry.id,
              'INSERT',
              map,
            );
            totalRestoredCount++;
          } else if (entry.updatedAt.isAfter(existing.updatedAt) ||
              entry.revision > existing.revision) {
            await db.update(db.knowledgeNotes).replace(entry);
            await _reconstituteSyncQueue(
              'knowledge_notes',
              entry.id,
              'UPDATE',
              map,
            );
            totalRestoredCount++;
          }
        }

        // 25. Perguntas de Conhecimento
        final questionRows = (data['knowledgeQuestions'] as List<dynamic>?) ?? [];
        for (final item in questionRows) {
          final map = item as Map<String, dynamic>;
          final entry = KnowledgeQuestionEntry.fromJson(map);
          final existing = await (db.select(
            db.knowledgeQuestions,
          )..where((tbl) => tbl.id.equals(entry.id))).getSingleOrNull();
          if (existing == null) {
            await db.into(db.knowledgeQuestions).insert(entry);
            await _reconstituteSyncQueue(
              'knowledge_questions',
              entry.id,
              'INSERT',
              map,
            );
            totalRestoredCount++;
          } else if (entry.updatedAt.isAfter(existing.updatedAt) ||
              entry.revision > existing.revision) {
            await db.update(db.knowledgeQuestions).replace(entry);
            await _reconstituteSyncQueue(
              'knowledge_questions',
              entry.id,
              'UPDATE',
              map,
            );
            totalRestoredCount++;
          }
        }

        // 26. Documentos de Conhecimento & Binários
        for (final item in docRows) {
          final map = Map<String, dynamic>.from(item as Map<String, dynamic>);
          var entry = KnowledgeDocumentEntry.fromJson(map);
          if (stagedDocFiles.containsKey(entry.id) && restoredDocsDir != null) {
            final safeName = entry.fileName.replaceAll(
              RegExp(r'[^a-zA-Z0-9._-]'),
              '_',
            );
            final targetFile = File(
              '${restoredDocsDir.path}/doc_${entry.id}_$safeName',
            );
            await stagedDocFiles[entry.id]!.copy(targetFile.path);
            entry = entry.copyWith(filePath: targetFile.path);
            map['filePath'] = targetFile.path;
          }
          final existing = await (db.select(
            db.knowledgeDocuments,
          )..where((tbl) => tbl.id.equals(entry.id))).getSingleOrNull();
          if (existing == null) {
            await db.into(db.knowledgeDocuments).insert(entry);
            await _reconstituteSyncQueue(
              'knowledge_documents',
              entry.id,
              'INSERT',
              map,
            );
            totalRestoredCount++;
          } else if (entry.updatedAt.isAfter(existing.updatedAt) ||
              entry.revision > existing.revision) {
            await db.update(db.knowledgeDocuments).replace(entry);
            await _reconstituteSyncQueue(
              'knowledge_documents',
              entry.id,
              'UPDATE',
              map,
            );
            totalRestoredCount++;
          }
        }

        // 27. Recursos de Conhecimento
        final resRows = (data['knowledgeResources'] as List<dynamic>?) ?? [];
        for (final item in resRows) {
          final map = item as Map<String, dynamic>;
          final entry = KnowledgeResourceEntry.fromJson(map);
          final existing = await (db.select(
            db.knowledgeResources,
          )..where((tbl) => tbl.id.equals(entry.id))).getSingleOrNull();
          if (existing == null) {
            await db.into(db.knowledgeResources).insert(entry);
            await _reconstituteSyncQueue(
              'knowledge_resources',
              entry.id,
              'INSERT',
              map,
            );
            totalRestoredCount++;
          } else if (entry.updatedAt.isAfter(existing.updatedAt) ||
              entry.revision > existing.revision) {
            await db.update(db.knowledgeResources).replace(entry);
            await _reconstituteSyncQueue(
              'knowledge_resources',
              entry.id,
              'UPDATE',
              map,
            );
            totalRestoredCount++;
          }
        }

        // 29. Idiomas da Aplicação (appLanguages)
        final langRows = (data['appLanguages'] as List<dynamic>?) ?? [];
        for (final item in langRows) {
          final entry = AppLanguageEntry.fromJson(item as Map<String, dynamic>);
          final existing = await (db.select(
            db.appLanguages,
          )..where((tbl) => tbl.id.equals(entry.id))).getSingleOrNull();
          if (existing == null) {
            await db.into(db.appLanguages).insert(entry);
            totalRestoredCount++;
          } else if (entry.updatedAt.isAfter(existing.updatedAt)) {
            await db.update(db.appLanguages).replace(entry);
            totalRestoredCount++;
          }
        }

        // 30-32. Dicionário, Frases e Tags Ticuna (F10)
        for (final item in ticunaWordsRows) {
          final map = Map<String, dynamic>.from(item as Map<String, dynamic>);
          final id = map['id']?.toString();
          if (id == null || id.isEmpty) continue;
          final audioKey = 'word_$id';
          if (stagedTicunaFiles.containsKey(audioKey) &&
              restoredTicunaDir != null) {
            final safeKey = audioKey.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
            final targetFile = File('${restoredTicunaDir.path}/$safeKey.m4a');
            await stagedTicunaFiles[audioKey]!.copy(targetFile.path);
            map['audio_path'] = targetFile.path;
          }
          final existingRows = await db.customSelect(
            'SELECT updated_at FROM ticuna_words WHERE id = ?',
            variables: [Variable.withString(id)],
          ).get();
          final existingUpdated = existingRows.isEmpty
              ? null
              : DateTime.tryParse(
                  existingRows.first.data['updated_at']?.toString() ?? '',
                );
          final incomingUpdated = DateTime.tryParse(
            map['updated_at']?.toString() ?? '',
          );
          final shouldWrite = existingRows.isEmpty ||
              (incomingUpdated != null &&
                  (existingUpdated == null ||
                      incomingUpdated.isAfter(existingUpdated)));
          if (shouldWrite) {
            await db.customStatement(
              '''
              INSERT OR REPLACE INTO ticuna_words (
                id, word, translation, phonetics, grammatical_class,
                example_sentence, example_translation, notes, tags,
                is_favorite, review_level, review_count, last_reviewed_at,
                audio_path, audio_duration_seconds, language_id,
                created_at, updated_at
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
              ''',
              [
                id,
                map['word'] ?? '',
                map['translation'] ?? '',
                map['phonetics'],
                map['grammatical_class'],
                map['example_sentence'],
                map['example_translation'],
                map['notes'],
                map['tags'] ?? '[]',
                (map['is_favorite'] as num?)?.toInt() ?? 0,
                (map['review_level'] as num?)?.toInt() ?? 0,
                (map['review_count'] as num?)?.toInt() ?? 0,
                map['last_reviewed_at'],
                map['audio_path'],
                (map['audio_duration_seconds'] as num?)?.toInt(),
                map['language_id'] ?? 'tca',
                map['created_at'] ?? DateTime.now().toIso8601String(),
                map['updated_at'] ?? DateTime.now().toIso8601String(),
              ],
            );
            await _reconstituteSyncQueue(
              'ticuna_words',
              id,
              existingRows.isEmpty ? 'INSERT' : 'UPDATE',
              map,
            );
            totalRestoredCount++;
          }
        }

        for (final item in ticunaPhrasesRows) {
          final map = Map<String, dynamic>.from(item as Map<String, dynamic>);
          final id = map['id']?.toString();
          if (id == null || id.isEmpty) continue;
          final audioKey = 'phrase_$id';
          if (stagedTicunaFiles.containsKey(audioKey) &&
              restoredTicunaDir != null) {
            final safeKey = audioKey.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
            final targetFile = File('${restoredTicunaDir.path}/$safeKey.m4a');
            await stagedTicunaFiles[audioKey]!.copy(targetFile.path);
            map['audio_path'] = targetFile.path;
          }
          final existingRows = await db.customSelect(
            'SELECT updated_at FROM ticuna_phrases WHERE id = ?',
            variables: [Variable.withString(id)],
          ).get();
          final existingUpdated = existingRows.isEmpty
              ? null
              : DateTime.tryParse(
                  existingRows.first.data['updated_at']?.toString() ?? '',
                );
          final incomingUpdated = DateTime.tryParse(
            map['updated_at']?.toString() ?? '',
          );
          final shouldWrite = existingRows.isEmpty ||
              (incomingUpdated != null &&
                  (existingUpdated == null ||
                      incomingUpdated.isAfter(existingUpdated)));
          if (shouldWrite) {
            await db.customStatement(
              '''
              INSERT OR REPLACE INTO ticuna_phrases (
                id, phrase, translation, category, phonetics, notes,
                tags, is_favorite, audio_path, audio_duration_seconds,
                language_id, created_at, updated_at
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
              ''',
              [
                id,
                map['phrase'] ?? '',
                map['translation'] ?? '',
                map['category'],
                map['phonetics'],
                map['notes'],
                map['tags'] ?? '[]',
                (map['is_favorite'] as num?)?.toInt() ?? 0,
                map['audio_path'],
                (map['audio_duration_seconds'] as num?)?.toInt(),
                map['language_id'] ?? 'tca',
                map['created_at'] ?? DateTime.now().toIso8601String(),
                map['updated_at'] ?? DateTime.now().toIso8601String(),
              ],
            );
            await _reconstituteSyncQueue(
              'ticuna_phrases',
              id,
              existingRows.isEmpty ? 'INSERT' : 'UPDATE',
              map,
            );
            totalRestoredCount++;
          }
        }

        for (final item in ticunaTagsRows) {
          final map = Map<String, dynamic>.from(item as Map<String, dynamic>);
          final id = map['id']?.toString();
          final name = map['name']?.toString();
          if (id == null || id.isEmpty || name == null || name.isEmpty) continue;
          final existing = await db.customSelect(
            'SELECT id FROM ticuna_tags WHERE id = ? OR name = ?',
            variables: [Variable.withString(id), Variable.withString(name)],
          ).get();
          if (existing.isEmpty) {
            await db.customStatement(
              'INSERT OR IGNORE INTO ticuna_tags (id, name, created_at) VALUES (?, ?, ?)',
              [
                id,
                name,
                map['created_at'] ?? DateTime.now().toIso8601String(),
              ],
            );
            totalRestoredCount++;
          }
        }

        // 28. Configurações da App (Key-Value Store)
        final kvRows = (data['appKvStore'] as List<dynamic>?) ?? [];
        for (final item in kvRows) {
          final entry = AppKvEntry.fromJson(item as Map<String, dynamic>);
          if (entry.key == _silentBackupKeySecret) continue;
          await db
              .into(db.appKvStore)
              .insertOnConflictUpdate(
                AppKvStoreCompanion.insert(
                  key: entry.key,
                  value: entry.value,
                  updatedAt: Value(entry.updatedAt ?? DateTime.now()),
                ),
              );
          totalRestoredCount++;
        }

        // 22. Fila de Sincronização (SyncQueue)
        final syncQueueRows = (data['syncQueue'] as List<dynamic>?) ?? [];
        for (final item in syncQueueRows) {
          final rawMap = Map<String, dynamic>.from(item as Map<String, dynamic>);
          if (rawMap.containsKey('payload') && rawMap['payload'] is String) {
            try {
              final decodedPayload = jsonDecode(rawMap['payload'] as String);
              if (decodedPayload is Map<String, dynamic>) {
                final normalized = _normalizePayloadDates(decodedPayload);
                rawMap['payload'] = jsonEncode(normalized);
              }
            } catch (e, st) {
              AppLogger.warning('Falha ao normalizar payload de syncQueue na restauração', e, st);
            }
          }
          final entry = SyncQueueEntry.fromJson(rawMap);
          final existing = await (db.select(
            db.syncQueue,
          )..where((tbl) => tbl.id.equals(entry.id))).getSingleOrNull();
          if (existing == null) {
            await db.into(db.syncQueue).insert(entry);
            totalRestoredCount++;
          }
        }
      });
    } catch (e) {
      // Rollback seguro de arquivos de áudio:
      // 1. Remove apenas arquivos recém-adicionados que não existiam antes da restauração
      for (final f in newlyAddedFiles) {
        try {
          if (f.existsSync()) {
            f.deleteSync();
          }
        } catch (cleanupErr, cleanupSt) {
          AppLogger.warning(
            'Falha ao limpar arquivo recém-adicionado no rollback (${f.path})',
            cleanupErr,
            cleanupSt,
          );
        }
      }

      // 2. Restaura integralmente os arquivos originais pré-existentes a partir do backup de segurança
      for (final entry in replacedOriginalsBackup.entries) {
        try {
          if (entry.value.existsSync()) {
            entry.value.copySync(entry.key.path);
          }
        } catch (cleanupErr, cleanupSt) {
          AppLogger.warning(
            'Falha ao restaurar arquivo original no rollback (${entry.key.path})',
            cleanupErr,
            cleanupSt,
          );
        }
      }

      // 3. Limpa diretórios transitórios de staging e backup
      if (stagingDir != null && stagingDir.existsSync()) {
        try {
          stagingDir.deleteSync(recursive: true);
        } catch (cleanupErr, cleanupSt) {
          AppLogger.warning('Falha ao remover stagingDir no rollback', cleanupErr, cleanupSt);
        }
      }
      if (audioBackupDir != null && audioBackupDir.existsSync()) {
        try {
          audioBackupDir.deleteSync(recursive: true);
        } catch (cleanupErr, cleanupSt) {
          AppLogger.warning('Falha ao remover audioBackupDir no rollback', cleanupErr, cleanupSt);
        }
      }

      rethrow;
    }

    // Sucesso: limpa diretórios transitórios de staging e backup
    if (stagingDir != null && stagingDir.existsSync()) {
      try {
        stagingDir.deleteSync(recursive: true);
      } catch (cleanupErr, cleanupSt) {
        AppLogger.warning('Falha ao remover stagingDir após restauração', cleanupErr, cleanupSt);
      }
    }
    if (audioBackupDir != null && audioBackupDir.existsSync()) {
      try {
        audioBackupDir.deleteSync(recursive: true);
      } catch (cleanupErr, cleanupSt) {
        AppLogger.warning('Falha ao remover audioBackupDir após restauração', cleanupErr, cleanupSt);
      }
    }

    return RestoreResult(
      isIntegral: corruptedFiles.isEmpty,
      corruptedFiles: corruptedFiles,
      restoredRecordsCount: totalRestoredCount,
    );
  }

  static const String _silentBackupKey = 'last_silent_backup_timestamp';
  static const String _silentBackupKeySecret = 'device_silent_backup_secret';

  Future<String> _getOrCreateSilentBackupKey() async {
    final db = repository.db;
    final legacyRow =
        await (db.select(db.appKvStore)
              ..where((tbl) => tbl.key.equals(_silentBackupKeySecret)))
            .getSingleOrNull();

    final stored = await _storage.read(key: _silentBackupKeySecret);
    if (stored != null && stored.isNotEmpty) {
      if (legacyRow != null) {
        await (db.delete(db.appKvStore)
              ..where((tbl) => tbl.key.equals(_silentBackupKeySecret)))
            .go();
      }
      return stored;
    }

    final secret = (legacyRow != null && legacyRow.value.isNotEmpty)
        ? legacyRow.value
        : base64Encode(_generateSecureRandom(32));
    await _storage.write(key: _silentBackupKeySecret, value: secret);
    if (await _storage.read(key: _silentBackupKeySecret) != secret) {
      throw const StorageUnavailableException('Não foi possível persistir a chave do backup.');
    }
    if (legacyRow != null) {
      await (db.delete(db.appKvStore)
            ..where((tbl) => tbl.key.equals(_silentBackupKeySecret)))
          .go();
    }
    return secret;
  }

  /// Realiza backup silencioso se o último foi há mais de 24 horas (ou se force = true).
  /// Utiliza chave segura vinculada ao dispositivo (Keychain/Keystore) e grava arquivo local no sistema de arquivos.
  Future<bool> performSilentBackupIfNeeded({bool force = false}) async {
    final db = repository.db;
    try {
      if (!force) {
        final row = await (db.select(
          db.appKvStore,
        )..where((tbl) => tbl.key.equals(_silentBackupKey))).getSingleOrNull();
        if (row != null) {
          final lastBackupTime = DateTime.tryParse(row.value);
          if (lastBackupTime != null &&
              DateTime.now().difference(lastBackupTime).inHours < 24) {
            return false;
          }
        }
      }

      // Não anuncie um backup quando não existe destino persistente na Web.
      if (kIsWeb) return false;

      final deviceSecret = await _getOrCreateSilentBackupKey();
      final backupJson = await exportEncryptedBackup(
        deviceSecret,
        iterations: 100000,
      );
      final nowStr = DateTime.now().toIso8601String();

      final dir = await _getDocsDir();
      final backupDir = Directory('${dir.path}/backups');
      await backupDir.create(recursive: true);
      final backupFile = File('${backupDir.path}/silent_backup.bak');
      final temporaryFile = File('${backupDir.path}/silent_backup_${_uuid.v4()}.tmp');
      try {
        await temporaryFile.writeAsString(backupJson, flush: true);
        await _validateSnapshotFile(temporaryFile, password: deviceSecret);
        // Mantém a última cópia válida se a gravação ou validação falhar.
        await temporaryFile.rename(backupFile.path);
      } finally {
        if (await temporaryFile.exists()) await temporaryFile.delete();
      }

      await db
          .into(db.appKvStore)
          .insertOnConflictUpdate(
            AppKvStoreCompanion.insert(
              key: _silentBackupKey,
              value: nowStr,
              updatedAt: Value(DateTime.now()),
            ),
          );

      return true;
    } catch (e, st) {
      AppLogger.error('Falha ao executar backup silencioso automático', e, st);
      return false;
    }
  }

  /// Retorna a data do último backup silencioso realizado
  Future<DateTime?> getLastSilentBackupDate() async {
    final db = repository.db;
    try {
      final row = await (db.select(
        db.appKvStore,
      )..where((tbl) => tbl.key.equals(_silentBackupKey))).getSingleOrNull();
      if (row != null) {
        return DateTime.tryParse(row.value);
      }
      return null;
    } catch (e, st) {
      AppLogger.warning('Falha ao ler data do último backup silencioso', e, st);
      return null;
    }
  }

  /// Retorna os dados em string do snapshot de segurança pré-restauração (suportado na Web)
  Future<String?> getLastSafetySnapshotData() async {
    final row =
        await (repository.db.select(repository.db.appKvStore)
              ..where((tbl) => tbl.key.equals('last_safety_snapshot_data')))
            .getSingleOrNull();
    return row?.value ?? _lastPreRestoreSafetyBackup;
  }
}
