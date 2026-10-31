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

  VoiceNotesManager(this.db, [this.repo]);

  VoiceNoteItem _entryToItem(VoiceNoteEntry entry) {
    return VoiceNoteItem(
      id: entry.id,
      personId: entry.personId,
      visitId: entry.visitId,
      studyId: entry.studyId,
      audioFilePath: entry.audioFilePath,
      audioDurationSeconds: entry.audioDurationSeconds,
      transcription: entry.transcription,
      detectedLesson: entry.detectedLesson,
      detectedPoint: entry.detectedPoint,
      extractedPendingDoubt: entry.extractedPendingDoubt,
      extractedEmpathyNote: entry.extractedEmpathyNote,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
      deletedAt: entry.deletedAt,
      revision: entry.revision,
    );
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
    try {
      final rows = await (db.select(db.voiceNotes)
            ..where((tbl) => tbl.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();
      return rows.map(_entryToItem).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<VoiceNoteItem>> getVoiceNotesForPerson(String personId) async {
    try {
      final rows = await (db.select(db.voiceNotes)
            ..where((tbl) => tbl.personId.equals(personId) & tbl.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();
      return rows.map(_entryToItem).toList();
    } catch (_) {
      return [];
    }
  }

  Stream<List<VoiceNoteItem>> watchVoiceNotesForPerson(String personId) {
    return (db.select(db.voiceNotes)
          ..where((tbl) => tbl.personId.equals(personId) & tbl.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch()
        .map((rows) => rows.map(_entryToItem).toList());
  }

  Future<VoiceNoteItem?> getLatestVoiceNoteForPerson(String personId) async {
    try {
      final rows = await (db.select(db.voiceNotes)
            ..where((tbl) => tbl.personId.equals(personId) & tbl.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(1))
          .get();
      if (rows.isEmpty) return null;
      return _entryToItem(rows.first);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveVoiceNote(VoiceNoteItem item) async {
    final existing = await getVoiceNoteById(item.id);
    final now = DateTime.now();
    if (existing != null) {
      await (db.update(db.voiceNotes)..where((tbl) => tbl.id.equals(item.id))).write(
        VoiceNotesCompanion(
          visitId: Value(item.visitId),
          studyId: Value(item.studyId),
          audioFilePath: Value(item.audioFilePath),
          audioDurationSeconds: Value(item.audioDurationSeconds),
          transcription: Value(item.transcription),
          detectedLesson: Value(item.detectedLesson),
          detectedPoint: Value(item.detectedPoint),
          extractedPendingDoubt: Value(item.extractedPendingDoubt),
          extractedEmpathyNote: Value(item.extractedEmpathyNote),
          updatedAt: Value(now),
          deletedAt: Value(item.deletedAt),
          revision: Value(existing.revision + 1),
        ),
      );
      await _recordSyncOperation(
        entityId: item.id,
        operation: 'UPDATE',
        payload: item.toMap(),
      );
    } else {
      await db.into(db.voiceNotes).insert(
        VoiceNotesCompanion.insert(
          id: item.id,
          personId: item.personId,
          visitId: Value(item.visitId),
          studyId: Value(item.studyId),
          audioFilePath: Value(item.audioFilePath),
          audioDurationSeconds: Value(item.audioDurationSeconds),
          transcription: item.transcription,
          detectedLesson: Value(item.detectedLesson),
          detectedPoint: Value(item.detectedPoint),
          extractedPendingDoubt: Value(item.extractedPendingDoubt),
          extractedEmpathyNote: Value(item.extractedEmpathyNote),
          createdAt: item.createdAt,
          updatedAt: item.updatedAt,
          deletedAt: Value(item.deletedAt),
          revision: Value(item.revision),
        ),
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
    try {
      final row = await (db.select(db.voiceNotes)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
      if (row == null) return null;
      return _entryToItem(row);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteVoiceNote(String id) async {
    final now = DateTime.now();
    await (db.update(db.voiceNotes)..where((tbl) => tbl.id.equals(id))).write(
      VoiceNotesCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await _recordSyncOperation(
      entityId: id,
      operation: 'DELETE',
      payload: {'id': id, 'deleted_at': now.toIso8601String()},
    );
    await _refresh();
  }

  /// Salva a nota rápida, cria a visita de forma atômica dentro de uma única transação e atualiza o Briefing.
  Future<({VoiceNoteItem voiceNote, VisitEntry? visit})> saveQuickVisitFromVoiceNote({
    required String personId,
    required ParsedVoiceNote parsedNote,
    String? audioFilePath,
    int audioDurationSeconds = 0,
    DateTime? dateTime,
    String? contactType,
    String? result,
    bool updateStudyProgress = true,
  }) async {
    final now = dateTime ?? DateTime.now();
    final voiceNoteId = _uuid.v4();

    VisitEntry? createdVisit;
    String? studyId;
    late final VoiceNoteItem voiceNote;

    await db.transaction(() async {
      if (repo != null) {
        final linkedStudy = await repo!.getPrimaryStudyForPerson(personId);
        studyId = linkedStudy?.id;

        // 1. Determina tópico e próximo passo a partir da extração teocrática
        final topics = parsedNote.formattedProgress ??
            (parsedNote.lesson != null ? 'Lição ${parsedNote.lesson}' : 'Nota rápida de voz');
        final nextStep = parsedNote.pendingDoubt;

        final String effectiveContactType;
        if (contactType != null && contactType.isNotEmpty) {
          effectiveContactType = contactType;
        } else if (parsedNote.rawText.toLowerCase().contains(RegExp(r'\bestudo\b')) &&
            (parsedNote.lesson != null || parsedNote.point != null)) {
          // Apenas classifica como estudo se a fala explicitamente mencionar estudo e progresso
          effectiveContactType = 'estudo';
        } else {
          effectiveContactType = 'revisita';
        }

        final String effectiveResult;
        if (result != null && result.isNotEmpty) {
          effectiveResult = result;
        } else if (effectiveContactType == 'estudo') {
          effectiveResult = 'estudo_realizado';
        } else {
          effectiveResult = 'revisita_feita';
        }

        // Cria a visita vinculada
        createdVisit = await repo!.createVisit(
          personId: personId,
          dateTime: now,
          contactType: effectiveContactType,
          result: effectiveResult,
          topicsDiscussed: topics,
          notes: parsedNote.rawText,
          nextStep: nextStep,
          scriptureOrPub: linkedStudy?.publicationId ?? 'Livro LFF',
        );

        // 2. Se for uma sessão de estudo confirmada (effectiveContactType == 'estudo'),
        // com updateStudyProgress habilitado e progresso não-ambíguo dentro dos limites da publicação:
        if (effectiveContactType == 'estudo' &&
            updateStudyProgress &&
            linkedStudy != null &&
            (parsedNote.lesson != null || parsedNote.point != null)) {
          final maxLessons = linkedStudy.publicationId == 'lff-brochure' ? 3 : 60;
          final validLesson = (parsedNote.lesson != null && parsedNote.lesson! >= 1 && parsedNote.lesson! <= maxLessons)
              ? parsedNote.lesson
              : null;
          final validPoint = (parsedNote.point != null && parsedNote.point! >= 1 && parsedNote.point! <= 10)
              ? parsedNote.point
              : null;

          if (validLesson != null || validPoint != null) {
            await repo!.updateStudy(
              linkedStudy.copyWith(
                currentLesson: validLesson != null ? Value(validLesson) : const Value.absent(),
                currentParagraph: validPoint != null ? Value(validPoint) : const Value.absent(),
                pendingDoubts: parsedNote.pendingDoubt != null ? Value(parsedNote.pendingDoubt) : const Value.absent(),
                lastSessionAt: Value(now),
                updatedAt: now,
              ),
            );
          }
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

      voiceNote = VoiceNoteItem(
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

      await db.into(db.voiceNotes).insert(
        VoiceNotesCompanion.insert(
          id: voiceNote.id,
          personId: voiceNote.personId,
          visitId: Value(voiceNote.visitId),
          studyId: Value(voiceNote.studyId),
          audioFilePath: Value(voiceNote.audioFilePath),
          audioDurationSeconds: Value(voiceNote.audioDurationSeconds),
          transcription: voiceNote.transcription,
          detectedLesson: Value(voiceNote.detectedLesson),
          detectedPoint: Value(voiceNote.detectedPoint),
          extractedPendingDoubt: Value(voiceNote.extractedPendingDoubt),
          extractedEmpathyNote: Value(voiceNote.extractedEmpathyNote),
          createdAt: voiceNote.createdAt,
          updatedAt: voiceNote.updatedAt,
          deletedAt: const Value.absent(),
          revision: const Value(1),
        ),
      );

      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: _uuid.v4(),
          entityType: 'voice_notes',
          entityId: voiceNote.id,
          operation: 'INSERT',
          payload: jsonEncode(voiceNote.toMap()),
          createdAt: now,
          status: const Value('pending'),
        ),
      );
    });

    await _refresh();
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
