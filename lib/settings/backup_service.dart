import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:drift/drift.dart' show Variable;
import '../database/app_database.dart';
import '../database/repository.dart';

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
  final Map<String, dynamic> rawDecryptedData;

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
    required this.rawDecryptedData,
  });
}

class BackupService {
  final AppRepository repository;

  BackupService(this.repository);

  /// Cria chave de 32 bytes (256 bits) derivada da senha
  static enc.Key _deriveKey(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    final digest = sha256.convert(bytes);
    return enc.Key(Uint8List.fromList(digest.bytes));
  }

  /// Exporta todos os registros em JSON criptografado com verificação de integridade
  Future<String> exportEncryptedBackup(String password) async {
    final db = repository.db;

    final people = await db.select(db.people).get();
    final visits = await db.select(db.visits).get();
    final studies = await db.select(db.bibleStudies).get();
    final participants = await db.select(db.studyParticipants).get();
    final sessions = await db.select(db.studySessions).get();
    final appointments = await db.select(db.appointments).get();
    final activities = await db.select(db.activityRecords).get();

    final payload = {
      'people': people.map((p) => p.toJson()).toList(),
      'visits': visits.map((v) => v.toJson()).toList(),
      'bibleStudies': studies.map((s) => s.toJson()).toList(),
      'studyParticipants': participants.map((p) => p.toJson()).toList(),
      'studySessions': sessions.map((s) => s.toJson()).toList(),
      'appointments': appointments.map((a) => a.toJson()).toList(),
      'activityRecords': activities.map((a) => a.toJson()).toList(),
    };

    final rawJson = jsonEncode(payload);
    final checksum = sha256.convert(utf8.encode(rawJson)).toString();

    final backupEnvelope = {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'checksum': checksum,
      'salt': 'ministerio_pessoal_salt_v1',
      'data': rawJson,
    };

    final envelopeJson = jsonEncode(backupEnvelope);

    // Criptografia AES
    final salt = backupEnvelope['salt'] as String;
    final key = _deriveKey(password, salt);
    final iv = enc.IV.fromLength(16);
    final encrypter = enc.Encrypter(enc.AES(key));

    final encrypted = encrypter.encrypt(envelopeJson, iv: iv);

    // Retorna payload codificado em base64 com IV prefixado
    final result = {
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
    final iv = enc.IV.fromBase64(container['iv'] as String);
    final ciphertext = container['ciphertext'] as String;

    // Chave padrão inicial
    final key = _deriveKey(password, 'ministerio_pessoal_salt_v1');
    final encrypter = enc.Encrypter(enc.AES(key));

    String decryptedEnvelopeJson;
    try {
      decryptedEnvelopeJson = encrypter.decrypt64(ciphertext, iv: iv);
    } catch (e) {
      throw FormatException('Senha incorreta ou arquivo de backup corrompido.');
    }

    final envelope = jsonDecode(decryptedEnvelopeJson) as Map<String, dynamic>;
    final version = envelope['version'] as int;
    if (version > 1) {
      throw FormatException('Versão de backup ($version) mais recente que a versão suportada pelo app (1).');
    }

    final rawDataJson = envelope['data'] as String;
    final expectedChecksum = envelope['checksum'] as String;
    final calculatedChecksum = sha256.convert(utf8.encode(rawDataJson)).toString();

    if (calculatedChecksum != expectedChecksum) {
      throw const FormatException('Falha de integridade: checksum do backup não confere.');
    }

    final data = jsonDecode(rawDataJson) as Map<String, dynamic>;

    // Calcula prévia comparando UUIDs com os existentes
    final existingPeople = await repository.getAllPeople();
    final existingPeopleMap = {for (var p in existingPeople) p.id: p};

    final importedPeople = (data['people'] as List<dynamic>?) ?? [];
    int pAdd = 0;
    int pUpdate = 0;
    int pUnchanged = 0;

    for (final item in importedPeople) {
      final id = item['id'] as String;
      if (!existingPeopleMap.containsKey(id)) {
        pAdd++;
      } else {
        final existing = existingPeopleMap[id]!;
        final dynamic impUpdatedRaw = item['updatedAt'];
        final DateTime impUpdated = impUpdatedRaw is int
            ? DateTime.fromMillisecondsSinceEpoch(impUpdatedRaw)
            : DateTime.parse(impUpdatedRaw.toString());
        if (impUpdated.isAfter(existing.updatedAt)) {
          pUpdate++;
        } else {
          pUnchanged++;
        }
      }
    }

    final importedVisits = (data['visits'] as List<dynamic>?) ?? [];
    final existingVisits = await repository.getAllVisits();
    final existingVisitsIds = {for (var v in existingVisits) v.id};
    int vAdd = 0;
    int vUpdate = 0;
    for (final item in importedVisits) {
      final id = item['id'] as String;
      if (!existingVisitsIds.contains(id)) {
        vAdd++;
      } else {
        vUpdate++;
      }
    }

    final importedStudies = (data['bibleStudies'] as List<dynamic>?) ?? [];
    final existingStudies = await repository.getAllStudies();
    final existingStudiesIds = {for (var s in existingStudies) s.id};
    int sAdd = 0;
    for (final item in importedStudies) {
      if (!existingStudiesIds.contains(item['id'] as String)) sAdd++;
    }

    final importedSessions = (data['studySessions'] as List<dynamic>?) ?? [];
    final existingSessions = await repository.getAllSessions();
    final existingSessionsIds = {for (var s in existingSessions) s.id};
    int sessAdd = 0;
    for (final item in importedSessions) {
      if (!existingSessionsIds.contains(item['id'] as String)) sessAdd++;
    }

    final importedAppointments = (data['appointments'] as List<dynamic>?) ?? [];
    final existingAppts = await repository.getAllAppointments();
    final existingApptsIds = {for (var a in existingAppts) a.id};
    int aAdd = 0;
    for (final item in importedAppointments) {
      if (!existingApptsIds.contains(item['id'] as String)) aAdd++;
    }

    final importedActivities = (data['activityRecords'] as List<dynamic>?) ?? [];
    final existingActivities = await repository.getAllActivities();
    final existingActivitiesIds = {for (var act in existingActivities) act.id};
    int actAdd = 0;
    for (final item in importedActivities) {
      if (!existingActivitiesIds.contains(item['id'] as String)) actAdd++;
    }

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
      rawDecryptedData: data,
    );
  }

  /// Aplica a restauração de forma transacional e idempotente
  Future<void> commitRestore(RestorePreview preview) async {
    final db = repository.db;
    final data = preview.rawDecryptedData;

    await db.transaction(() async {
      // Pessoas
      final people = (data['people'] as List<dynamic>?) ?? [];
      for (final item in people) {
        final entry = PersonEntry.fromJson(item as Map<String, dynamic>);
        await db.into(db.people).insertOnConflictUpdate(entry);
      }

      // Visitas
      final visits = (data['visits'] as List<dynamic>?) ?? [];
      for (final item in visits) {
        final entry = VisitEntry.fromJson(item as Map<String, dynamic>);
        await db.into(db.visits).insertOnConflictUpdate(entry);
      }

      // Estudos
      final studies = (data['bibleStudies'] as List<dynamic>?) ?? [];
      for (final item in studies) {
        final entry = BibleStudyEntry.fromJson(item as Map<String, dynamic>);
        await db.into(db.bibleStudies).insertOnConflictUpdate(entry);
      }

      // Participantes
      final participants = (data['studyParticipants'] as List<dynamic>?) ?? [];
      for (final item in participants) {
        final entry = StudyParticipantEntry.fromJson(item as Map<String, dynamic>);
        await db.into(db.studyParticipants).insertOnConflictUpdate(entry);
      }

      // Sessões
      final sessions = (data['studySessions'] as List<dynamic>?) ?? [];
      for (final item in sessions) {
        final entry = StudySessionEntry.fromJson(item as Map<String, dynamic>);
        await db.into(db.studySessions).insertOnConflictUpdate(entry);
      }

      // Compromissos
      final appointments = (data['appointments'] as List<dynamic>?) ?? [];
      for (final item in appointments) {
        final entry = AppointmentEntry.fromJson(item as Map<String, dynamic>);
        await db.into(db.appointments).insertOnConflictUpdate(entry);
      }

      // Atividades
      final activities = (data['activityRecords'] as List<dynamic>?) ?? [];
      for (final item in activities) {
        final entry = ActivityRecordEntry.fromJson(item as Map<String, dynamic>);
        await db.into(db.activityRecords).insertOnConflictUpdate(entry);
      }
    });
  }

  static const String _silentBackupKey = 'last_silent_backup_timestamp';
  static const String _silentBackupDataKey = 'last_silent_backup_payload';

  /// Realiza backup silencioso se o último foi há mais de 24 horas (ou se force = true)
  Future<bool> performSilentBackupIfNeeded({bool force = false}) async {
    final db = repository.db;
    try {
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS app_kv_store (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        );
      ''');

      if (!force) {
        final row = await db.customSelect(
          'SELECT value FROM app_kv_store WHERE key = ?',
          variables: [Variable.withString(_silentBackupKey)],
        ).getSingleOrNull();

        if (row != null) {
          final lastBackupTime = DateTime.tryParse(row.read<String>('value'));
          if (lastBackupTime != null && DateTime.now().difference(lastBackupTime).inHours < 24) {
            return false; // Já realizado nas últimas 24h
          }
        }
      }

      final backupJson = await exportEncryptedBackup('silent_auto_backup_key_v1');
      final nowStr = DateTime.now().toIso8601String();

      await db.customInsert(
        'INSERT OR REPLACE INTO app_kv_store (key, value) VALUES (?, ?)',
        variables: [Variable.withString(_silentBackupKey), Variable.withString(nowStr)],
      );
      await db.customInsert(
        'INSERT OR REPLACE INTO app_kv_store (key, value) VALUES (?, ?)',
        variables: [Variable.withString(_silentBackupDataKey), Variable.withString(backupJson)],
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
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS app_kv_store (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        );
      ''');
      final row = await db.customSelect(
        'SELECT value FROM app_kv_store WHERE key = ?',
        variables: [Variable.withString(_silentBackupKey)],
      ).getSingleOrNull();

      if (row != null) {
        return DateTime.tryParse(row.read<String>('value'));
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
