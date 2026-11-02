import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../database/repository.dart';

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
  final List<String> inventoryTables;
  final List<String> corruptedAudioIds;
  final Map<String, dynamic> rawDecryptedData;

  bool get isIntegral => corruptedAudioIds.isEmpty;

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
    this.inventoryTables = const [],
    this.corruptedAudioIds = const [],
    required this.rawDecryptedData,
  });
}

class BackupService {
  final AppRepository repository;
  final Future<Directory> Function()? documentsDirectoryProvider;
  final Uuid _uuid = const Uuid();
  String? _lastPreRestoreSafetyBackup;

  String? get lastPreRestoreSafetyBackup => _lastPreRestoreSafetyBackup;

  BackupService(this.repository, {this.documentsDirectoryProvider});

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
    final kvStore = await (db.select(
      db.appKvStore,
    )..where((t) => t.key.isNotValue(_silentBackupKeySecret))).get();

    // Saneamento e portabilidade multimídia: serializa arquivos físicos de áudio em base64 e gera hashes SHA-256
    final Map<String, String> voiceNoteAudios = {};
    final Map<String, String> voiceNoteAudioHashes = {};
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
          } catch (_) {}
        }
      }
    }

    final payload = {
      'exported_tables_count': 22,
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
      'personPhotos': photos.map((p) => p.toJson()).toList(),
      'personPublications': publications.map((p) => p.toJson()).toList(),
      'researchArticles': articles.map((a) => a.toJson()).toList(),
      'researchTags': tags.map((t) => t.toJson()).toList(),
      'territorySectors': sectors.map((s) => s.toJson()).toList(),
      'studentManualOrder': manualOrders.map((m) => m.toJson()).toList(),
      'externalCalendarEvents': calendarEvents.map((c) => c.toJson()).toList(),
      'calendarEventLinks': calendarLinks.map((l) => l.toJson()).toList(),
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
        // Compatibilidade reversa: Versão 1 legada
        final iv = enc.IV.fromBase64(container['iv'] as String);
        final ciphertext = container['ciphertext'] as String;
        final key = _deriveKeyV1(password, 'ministerio_pessoal_salt_v1');
        final encrypter = enc.Encrypter(enc.AES(key));

        decryptedEnvelopeJson = encrypter.decrypt64(ciphertext, iv: iv);
      }
    } catch (_) {
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
        } catch (_) {
          corruptedAudioIds.add(entry.key);
        }
      } else {
        corruptedAudioIds.add(entry.key);
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
      inventoryTables: tableList,
      corruptedAudioIds: corruptedAudioIds,
      rawDecryptedData: data,
    );
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
      await repository.db
          .into(repository.db.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: _uuid.v4(),
              entityType: entityType,
              entityId: entityId,
              operation: operation,
              payload: jsonEncode(payload),
              createdAt: DateTime.now(),
              status: const Value('pending'),
            ),
          );
    } catch (_) {}
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
      snapshotData = await exportEncryptedBackup(safetyKey, iterations: 1000);
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
    final stagedFiles = <String, File>{};
    final replacedOriginalsBackup = <File, File>{};
    final newlyAddedFiles = <File>[];

    final voiceNotes = (data['voiceNotes'] as List<dynamic>?) ?? [];
    final voiceNoteAudios =
        (data['voiceNoteAudios'] as Map<String, dynamic>?) ?? {};
    final voiceNoteAudioHashes =
        (data['voiceNoteAudioHashes'] as Map<String, dynamic>?) ?? {};

    if (!kIsWeb && voiceNoteAudios.isNotEmpty) {
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

        restoredAudioDir = Directory('${docsDir.path}/voice_notes');
        if (!restoredAudioDir.existsSync()) {
          await restoredAudioDir.create(recursive: true);
        }

        // Etapa 1: Extrair e validar em staging antes de tocar no destino
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
                // Etapa 2: Preservar arquivo original antes de qualquer sobrescrita
                final backupFile = File('${audioBackupDir.path}/vn_$id.m4a');
                await targetFile.copy(backupFile.path);
                replacedOriginalsBackup[targetFile] = backupFile;
              } else {
                newlyAddedFiles.add(targetFile);
              }
            } catch (_) {
              corruptedFiles.add(id);
            }
          }
        }
      } catch (e) {
        if (stagingDir != null && stagingDir.existsSync()) {
          try {
            stagingDir.deleteSync(recursive: true);
          } catch (_) {}
        }
        if (audioBackupDir != null && audioBackupDir.existsSync()) {
          try {
            audioBackupDir.deleteSync(recursive: true);
          } catch (_) {}
        }
        throw RestoreMediaException(
          'Falha na preparação da área de staging de áudios: $e',
        );
      }
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
          final entry = FamilyTieEntry.fromJson(item as Map<String, dynamic>);
          final existing = await (db.select(
            db.familyTies,
          )..where((tbl) => tbl.id.equals(entry.id))).getSingleOrNull();
          if (existing == null) {
            await db.into(db.familyTies).insert(entry);
            totalRestoredCount++;
          } else if ((entry.updatedAt ?? entry.createdAt).isAfter(
                existing.updatedAt ?? existing.createdAt,
              ) ||
              entry.revision > existing.revision) {
            await db.update(db.familyTies).replace(entry);
            totalRestoredCount++;
          }
        }

        // 12. Experiências Ministeriais
        final experiences =
            (data['ministryExperiences'] as List<dynamic>?) ?? [];
        for (final item in experiences) {
          final entry = MinistryExperienceEntry.fromJson(
            item as Map<String, dynamic>,
          );
          final existing = await (db.select(
            db.ministryExperiences,
          )..where((tbl) => tbl.id.equals(entry.id))).getSingleOrNull();
          if (existing == null) {
            await db.into(db.ministryExperiences).insert(entry);
            totalRestoredCount++;
          } else if (entry.updatedAt.isAfter(existing.updatedAt) ||
              entry.revision > existing.revision) {
            await db.update(db.ministryExperiences).replace(entry);
            totalRestoredCount++;
          }
        }

        // 13. Fotos de Pessoas e Residências
        final photos = (data['personPhotos'] as List<dynamic>?) ?? [];
        for (final item in photos) {
          final entry = PersonPhotoEntry.fromJson(item as Map<String, dynamic>);
          final existing = await (db.select(
            db.personPhotos,
          )..where((tbl) => tbl.id.equals(entry.id))).getSingleOrNull();
          if (existing == null) {
            await db.into(db.personPhotos).insert(entry);
            totalRestoredCount++;
          } else if ((entry.updatedAt ?? entry.createdAt).isAfter(
                existing.updatedAt ?? existing.createdAt,
              ) ||
              entry.revision > existing.revision) {
            await db.update(db.personPhotos).replace(entry);
            totalRestoredCount++;
          }
        }

        // 14. Publicações e Pedidos das Pessoas
        final publications =
            (data['personPublications'] as List<dynamic>?) ?? [];
        for (final item in publications) {
          final entry = PersonPublicationEntry.fromJson(
            item as Map<String, dynamic>,
          );
          final existing = await (db.select(
            db.personPublications,
          )..where((tbl) => tbl.id.equals(entry.id))).getSingleOrNull();
          if (existing == null) {
            await db.into(db.personPublications).insert(entry);
            totalRestoredCount++;
          } else if ((entry.updatedAt ?? entry.createdAt).isAfter(
                existing.updatedAt ?? existing.createdAt,
              ) ||
              entry.revision > existing.revision) {
            await db.update(db.personPublications).replace(entry);
            totalRestoredCount++;
          }
        }

        // 15. Artigos de Pesquisa
        final articles = (data['researchArticles'] as List<dynamic>?) ?? [];
        for (final item in articles) {
          final entry = ResearchArticleEntry.fromJson(
            item as Map<String, dynamic>,
          );
          final existing = await (db.select(
            db.researchArticles,
          )..where((tbl) => tbl.id.equals(entry.id))).getSingleOrNull();
          if (existing == null) {
            await db.into(db.researchArticles).insert(entry);
            totalRestoredCount++;
          } else if (entry.updatedAt.isAfter(existing.updatedAt) ||
              entry.revision > existing.revision) {
            await db.update(db.researchArticles).replace(entry);
            totalRestoredCount++;
          }
        }

        // 16. Tags de Pesquisa
        final tags = (data['researchTags'] as List<dynamic>?) ?? [];
        for (final item in tags) {
          final entry = ResearchTagEntry.fromJson(item as Map<String, dynamic>);
          final existing = await (db.select(
            db.researchTags,
          )..where((tbl) => tbl.id.equals(entry.id))).getSingleOrNull();
          if (existing == null) {
            await db.into(db.researchTags).insert(entry);
            totalRestoredCount++;
          }
        }

        // 17. Setores de Território
        final sectors = (data['territorySectors'] as List<dynamic>?) ?? [];
        for (final item in sectors) {
          final entry = TerritorySectorEntry.fromJson(
            item as Map<String, dynamic>,
          );
          final existing = await (db.select(
            db.territorySectors,
          )..where((tbl) => tbl.id.equals(entry.id))).getSingleOrNull();
          if (existing == null) {
            await db.into(db.territorySectors).insert(entry);
            totalRestoredCount++;
          } else if ((entry.updatedAt ?? entry.createdAt).isAfter(
                existing.updatedAt ?? existing.createdAt,
              ) ||
              entry.revision > existing.revision) {
            await db.update(db.territorySectors).replace(entry);
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

        // 21. Configurações da App (Key-Value Store)
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
          final entry = SyncQueueEntry.fromJson(item as Map<String, dynamic>);
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
        } catch (_) {}
      }

      // 2. Restaura integralmente os arquivos originais pré-existentes a partir do backup de segurança
      for (final entry in replacedOriginalsBackup.entries) {
        try {
          if (entry.value.existsSync()) {
            entry.value.copySync(entry.key.path);
          }
        } catch (_) {}
      }

      // 3. Limpa diretórios transitórios de staging e backup
      if (stagingDir != null && stagingDir.existsSync()) {
        try {
          stagingDir.deleteSync(recursive: true);
        } catch (_) {}
      }
      if (audioBackupDir != null && audioBackupDir.existsSync()) {
        try {
          audioBackupDir.deleteSync(recursive: true);
        } catch (_) {}
      }

      rethrow;
    }

    // Sucesso: limpa diretórios transitórios de staging e backup
    if (stagingDir != null && stagingDir.existsSync()) {
      try {
        stagingDir.deleteSync(recursive: true);
      } catch (_) {}
    }
    if (audioBackupDir != null && audioBackupDir.existsSync()) {
      try {
        audioBackupDir.deleteSync(recursive: true);
      } catch (_) {}
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
    final row =
        await (db.select(db.appKvStore)
              ..where((tbl) => tbl.key.equals(_silentBackupKeySecret)))
            .getSingleOrNull();
    if (row != null && row.value.isNotEmpty) {
      return row.value;
    }
    final generatedSecret = base64Encode(_generateSecureRandom(32));
    await db
        .into(db.appKvStore)
        .insertOnConflictUpdate(
          AppKvStoreCompanion.insert(
            key: _silentBackupKeySecret,
            value: generatedSecret,
            updatedAt: Value(DateTime.now()),
          ),
        );
    return generatedSecret;
  }

  /// Realiza backup silencioso se o último foi há mais de 24 horas (ou se force = true).
  /// Utiliza chave segura vinculada ao dispositivo e grava arquivo local no sistema de arquivos.
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

      final deviceSecret = await _getOrCreateSilentBackupKey();
      final backupJson = await exportEncryptedBackup(
        deviceSecret,
        iterations: 1000,
      );
      final nowStr = DateTime.now().toIso8601String();

      // Salva em arquivo físico no diretório de documentos quando disponível
      if (!kIsWeb) {
        try {
          final dir = await getApplicationDocumentsDirectory();
          final backupDir = Directory('${dir.path}/backups');
          if (!backupDir.existsSync()) {
            await backupDir.create(recursive: true);
          }
          final backupFile = File('${backupDir.path}/silent_backup.bak');
          await backupFile.writeAsString(backupJson, flush: true);
        } catch (_) {}
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
    } catch (_) {
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
    } catch (_) {
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
