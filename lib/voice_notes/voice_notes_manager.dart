import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/repository.dart';
import '../ui/providers.dart';
import '../contacts/doorstep_briefing_helper.dart';
import 'voice_note_models.dart';
import 'voice_note_parser.dart';

/// Gerenciador de persistência local SQLite e reatividade para notas de voz offline.
class VoiceNotesManager {
  final AppDatabase db;
  final AppRepository? repo;
  final Uuid _uuid = const Uuid();
  final StreamController<List<VoiceNoteItem>> _notesController =
      StreamController<List<VoiceNoteItem>>.broadcast();
  Future<void>? _initFuture;

  VoiceNotesManager(this.db, [this.repo]) {
    _initTable();
  }

  Future<void> _initTable() {
    _initFuture ??= _doInitTable();
    return _initFuture!;
  }

  Future<void> _doInitTable() async {
    try {
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS voice_notes (
          id TEXT PRIMARY KEY,
          person_id TEXT NOT NULL,
          visit_id TEXT,
          study_id TEXT,
          audio_file_path TEXT,
          audio_duration_seconds INTEGER NOT NULL DEFAULT 0,
          transcription TEXT NOT NULL,
          detected_lesson INTEGER,
          detected_point INTEGER,
          extracted_pending_doubt TEXT,
          extracted_empathy_note TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          deleted_at TEXT,
          revision INTEGER NOT NULL DEFAULT 1
        );
      ''');
      _refresh();
    } catch (_) {}
  }

  Future<void> _refresh() async {
    try {
      final list = await getAllVoiceNotes();
      if (!_notesController.isClosed) {
        _notesController.add(list);
      }
    } catch (_) {}
  }

  Future<void> _recordSyncOperation({
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: _uuid.v4(),
          entityType: 'voice_notes',
          entityId: entityId,
          operation: operation,
          payload: jsonEncode(payload),
          createdAt: DateTime.now(),
          status: const Value('pending'),
        ),
      );
    } catch (_) {}
  }

  Future<List<VoiceNoteItem>> getAllVoiceNotes() async {
    await _initTable();
    try {
      final rows = await db
          .customSelect('SELECT * FROM voice_notes WHERE deleted_at IS NULL ORDER BY created_at DESC')
          .get();
      return rows.map((r) => VoiceNoteItem.fromMap(r.data)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<VoiceNoteItem>> getVoiceNotesForPerson(String personId) async {
    await _initTable();
    try {
      final rows = await db.customSelect(
        'SELECT * FROM voice_notes WHERE person_id = ? AND deleted_at IS NULL ORDER BY created_at DESC',
        variables: [Variable.withString(personId)],
      ).get();
      return rows.map((r) => VoiceNoteItem.fromMap(r.data)).toList();
    } catch (_) {
      return [];
    }
  }

  Stream<List<VoiceNoteItem>> watchVoiceNotesForPerson(String personId) async* {
    yield await getVoiceNotesForPerson(personId);
    yield* _notesController.stream.map((list) {
      return list.where((item) => item.personId == personId && item.deletedAt == null).toList();
    });
  }

  Future<VoiceNoteItem?> getLatestVoiceNoteForPerson(String personId) async {
    await _initTable();
    try {
      final rows = await db.customSelect(
        'SELECT * FROM voice_notes WHERE person_id = ? AND deleted_at IS NULL ORDER BY created_at DESC LIMIT 1',
        variables: [Variable.withString(personId)],
      ).get();
      if (rows.isEmpty) return null;
      return VoiceNoteItem.fromMap(rows.first.data);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveVoiceNote(VoiceNoteItem item) async {
    await _initTable();
    final existing = await getVoiceNoteById(item.id);
    if (existing != null) {
      await db.customUpdate(
        '''
        UPDATE voice_notes SET
          visit_id = ?,
          study_id = ?,
          audio_file_path = ?,
          audio_duration_seconds = ?,
          transcription = ?,
          detected_lesson = ?,
          detected_point = ?,
          extracted_pending_doubt = ?,
          extracted_empathy_note = ?,
          updated_at = ?,
          deleted_at = ?,
          revision = revision + 1
        WHERE id = ?
        ''',
        variables: [
          Variable<String>(item.visitId),
          Variable<String>(item.studyId),
          Variable<String>(item.audioFilePath),
          Variable.withInt(item.audioDurationSeconds),
          Variable.withString(item.transcription),
          Variable<int>(item.detectedLesson),
          Variable<int>(item.detectedPoint),
          Variable<String>(item.extractedPendingDoubt),
          Variable<String>(item.extractedEmpathyNote),
          Variable.withString(DateTime.now().toIso8601String()),
          Variable<String>(item.deletedAt?.toIso8601String()),
          Variable.withString(item.id),
        ],
      );
      await _recordSyncOperation(
        entityId: item.id,
        operation: 'UPDATE',
        payload: item.toMap(),
      );
    } else {
      await db.customInsert(
        '''
        INSERT INTO voice_notes (
          id, person_id, visit_id, study_id, audio_file_path,
          audio_duration_seconds, transcription, detected_lesson,
          detected_point, extracted_pending_doubt, extracted_empathy_note,
          created_at, updated_at, revision
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        variables: [
          Variable.withString(item.id),
          Variable.withString(item.personId),
          Variable<String>(item.visitId),
          Variable<String>(item.studyId),
          Variable<String>(item.audioFilePath),
          Variable.withInt(item.audioDurationSeconds),
          Variable.withString(item.transcription),
          Variable<int>(item.detectedLesson),
          Variable<int>(item.detectedPoint),
          Variable<String>(item.extractedPendingDoubt),
          Variable<String>(item.extractedEmpathyNote),
          Variable.withString(item.createdAt.toIso8601String()),
          Variable.withString(item.updatedAt.toIso8601String()),
          Variable.withInt(item.revision),
        ],
      );
      await _recordSyncOperation(
        entityId: item.id,
        operation: 'INSERT',
        payload: item.toMap(),
      );
    }
    await _refresh();
  }

  Future<VoiceNoteItem?> getVoiceNoteById(String id) async {
    await _initTable();
    try {
      final rows = await db.customSelect(
        'SELECT * FROM voice_notes WHERE id = ?',
        variables: [Variable.withString(id)],
      ).get();
      if (rows.isEmpty) return null;
      return VoiceNoteItem.fromMap(rows.first.data);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteVoiceNote(String id) async {
    await _initTable();
    final now = DateTime.now();
    await db.customUpdate(
      'UPDATE voice_notes SET deleted_at = ?, updated_at = ? WHERE id = ?',
      variables: [
        Variable.withString(now.toIso8601String()),
        Variable.withString(now.toIso8601String()),
        Variable.withString(id),
      ],
    );
    await _recordSyncOperation(
      entityId: id,
      operation: 'DELETE',
      payload: {'id': id, 'deleted_at': now.toIso8601String()},
    );
    await _refresh();
  }

  /// Salva a nota rápida, cria a visita atômica e atualiza o Briefing na Porta (1 Toque).
  Future<({VoiceNoteItem voiceNote, VisitEntry? visit})> saveQuickVisitFromVoiceNote({
    required String personId,
    required ParsedVoiceNote parsedNote,
    String? audioFilePath,
    int audioDurationSeconds = 0,
    DateTime? dateTime,
  }) async {
    await _initTable();
    final now = dateTime ?? DateTime.now();
    final voiceNoteId = _uuid.v4();

    VisitEntry? createdVisit;
    String? studyId;

    if (repo != null) {
      final linkedStudy = await repo!.getPrimaryStudyForPerson(personId);
      studyId = linkedStudy?.id;

      // 1. Determina tópico e próximo passo a partir da extração teocrática
      final topics = parsedNote.formattedProgress ??
          (parsedNote.lesson != null ? 'Lição ${parsedNote.lesson}' : 'Nota rápida de voz');

      final nextStep = parsedNote.pendingDoubt;

      // Cria a visita vinculada
      createdVisit = await repo!.createVisit(
        personId: personId,
        dateTime: now,
        contactType: (linkedStudy != null || parsedNote.lesson != null) ? 'estudo' : 'revisita',
        result: 'revisita_feita',
        topicsDiscussed: topics,
        notes: parsedNote.rawText,
        nextStep: nextStep,
        scriptureOrPub: linkedStudy?.publicationId ?? 'Livro LFF',
      );

      // 2. Se lição ou ponto detectados e estudo ativo, atualiza progresso do estudo
      if (linkedStudy != null && (parsedNote.lesson != null || parsedNote.point != null)) {
        await repo!.updateStudy(
          linkedStudy.copyWith(
            currentLesson: parsedNote.lesson != null ? Value(parsedNote.lesson) : const Value.absent(),
            currentParagraph: parsedNote.point != null ? Value(parsedNote.point) : const Value.absent(),
            pendingDoubts: parsedNote.pendingDoubt != null ? Value(parsedNote.pendingDoubt) : const Value.absent(),
            lastSessionAt: Value(now),
            updatedAt: now,
          ),
        );
      }

      // 3. Se gatilho empático detectado, salva em person.generalNotes no formato JSON suportado pelo briefing
      final freshPerson = await repo!.getPersonById(personId);
      if (freshPerson != null && parsedNote.empathyNote != null && parsedNote.empathyNote!.trim().isNotEmpty) {
        final currentNotes = DoorstepBriefingHelper.parseNotes(freshPerson.generalNotes);
        final newNote = {
          'id': _uuid.v4(),
          'text': parsedNote.empathyNote!.trim(),
          'createdAt': now.toIso8601String(),
        };
        final updatedNotes = [newNote, ...currentNotes];
        await repo!.updatePerson(
          freshPerson.copyWith(
            generalNotes: Value(jsonEncode(updatedNotes)),
            nextActionNote: parsedNote.pendingDoubt != null
                ? Value(parsedNote.pendingDoubt!.trim())
                : const Value.absent(),
            updatedAt: now,
          ),
        );
      } else if (freshPerson != null && parsedNote.pendingDoubt != null) {
        await repo!.updatePerson(
          freshPerson.copyWith(
            nextActionNote: Value(parsedNote.pendingDoubt!.trim()),
            updatedAt: now,
          ),
        );
      }
    }

    final voiceNote = VoiceNoteItem(
      id: voiceNoteId,
      personId: personId,
      visitId: createdVisit?.id,
      studyId: studyId,
      audioFilePath: audioFilePath,
      audioDurationSeconds: audioDurationSeconds,
      transcription: parsedNote.rawText,
      detectedLesson: parsedNote.lesson,
      detectedPoint: parsedNote.point,
      extractedPendingDoubt: parsedNote.pendingDoubt,
      extractedEmpathyNote: parsedNote.empathyNote,
      createdAt: now,
      updatedAt: now,
      revision: 1,
    );

    await saveVoiceNote(voiceNote);

    return (voiceNote: voiceNote, visit: createdVisit);
  }
}

/// Provider do gerenciador de notas de voz.
final voiceNotesManagerProvider = Provider<VoiceNotesManager>((ref) {
  final repo = ref.watch(repositoryProvider);
  return VoiceNotesManager(repo.db, repo);
});

/// Stream provider das notas de voz de uma pessoa específica.
final voiceNotesStreamProvider =
    StreamProvider.family<List<VoiceNoteItem>, String>((ref, personId) {
  final mgr = ref.watch(voiceNotesManagerProvider);
  return mgr.watchVoiceNotesForPerson(personId);
});
