import 'dart:convert';
import '../database/app_database.dart';
import '../publications/publication_catalog.dart';
import '../publications/publication_link_resolver.dart';
import '../voice_notes/voice_note_models.dart';

/// Modelo de dados consolidado para o card de Briefing na Porta (30 segundos).
class DoorstepBriefingData {
  /// Onde parou a consideração (ex: "Lição 04, Ponto 3", "Salmo 37:11", etc.)
  final String? lessonAndPoint;

  /// URI canônico verificado para abertura direta no JW Library / jw.org
  final Uri? jwLibraryUri;

  /// Pendência, dúvida ou próximo passo acordado na última visita
  final String? pendingDoubt;

  /// Alvo espiritual ativo (meta ainda não concluída)
  final String? spiritualGoal;

  /// Toque de empatia (última observação pessoal ou necessidade registrada)
  final String? empathyNote;

  /// Título da publicação vinculada ao estudo (se houver)
  final String? publicationTitle;

  /// Caminho do arquivo de áudio gravado na última nota de voz
  final String? audioFilePath;

  /// Transcrição da última nota de voz
  final String? voiceNoteTranscription;

  /// Duração em segundos da última nota de voz
  final int? voiceNoteDurationSeconds;

  const DoorstepBriefingData({
    this.lessonAndPoint,
    this.jwLibraryUri,
    this.pendingDoubt,
    this.spiritualGoal,
    this.empathyNote,
    this.publicationTitle,
    this.audioFilePath,
    this.voiceNoteTranscription,
    this.voiceNoteDurationSeconds,
  });

  bool get hasLessonOrTopic => lessonAndPoint != null && lessonAndPoint!.trim().isNotEmpty;
  bool get hasJwLibraryLink => jwLibraryUri != null;
  bool get hasPendingDoubt => pendingDoubt != null && pendingDoubt!.trim().isNotEmpty;
  bool get hasSpiritualGoal => spiritualGoal != null && spiritualGoal!.trim().isNotEmpty;
  bool get hasEmpathyNote => empathyNote != null && empathyNote!.trim().isNotEmpty;
  bool get hasVoiceNote =>
      (audioFilePath != null && audioFilePath!.trim().isNotEmpty) ||
      (voiceNoteTranscription != null && voiceNoteTranscription!.trim().isNotEmpty);

  /// Indica se há pelo menos um dado relevante para exibição no card
  bool get hasAnyData =>
      hasLessonOrTopic ||
      hasPendingDoubt ||
      hasSpiritualGoal ||
      hasEmpathyNote ||
      hasVoiceNote;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DoorstepBriefingData &&
          runtimeType == other.runtimeType &&
          lessonAndPoint == other.lessonAndPoint &&
          jwLibraryUri == other.jwLibraryUri &&
          pendingDoubt == other.pendingDoubt &&
          spiritualGoal == other.spiritualGoal &&
          empathyNote == other.empathyNote &&
          publicationTitle == other.publicationTitle &&
          audioFilePath == other.audioFilePath &&
          voiceNoteTranscription == other.voiceNoteTranscription &&
          voiceNoteDurationSeconds == other.voiceNoteDurationSeconds;

  @override
  int get hashCode =>
      lessonAndPoint.hashCode ^
      jwLibraryUri.hashCode ^
      pendingDoubt.hashCode ^
      spiritualGoal.hashCode ^
      empathyNote.hashCode ^
      publicationTitle.hashCode ^
      audioFilePath.hashCode ^
      voiceNoteTranscription.hashCode ^
      voiceNoteDurationSeconds.hashCode;

  @override
  String toString() =>
      'DoorstepBriefingData(lessonAndPoint: $lessonAndPoint, jwLibraryUri: $jwLibraryUri, '
      'pendingDoubt: $pendingDoubt, spiritualGoal: $spiritualGoal, empathyNote: $empathyNote, '
      'publicationTitle: $publicationTitle, audioFilePath: $audioFilePath, '
      'voiceNoteTranscription: $voiceNoteTranscription, voiceNoteDurationSeconds: $voiceNoteDurationSeconds)';
}

/// Helper puro responsável por consolidar os dados para o Briefing na Porta.
class DoorstepBriefingHelper {
  /// Constrói o [DoorstepBriefingData] a partir dos dados do contato, estudo e última visita.
  static DoorstepBriefingData build({
    required PersonEntry person,
    BibleStudyEntry? linkedStudy,
    VisitEntry? latestVisit,
    VoiceNoteItem? latestVoiceNote,
  }) {
    final lessonInfo = _extractLessonAndPoint(linkedStudy, latestVisit, latestVoiceNote);
    final pendingDoubt = _extractPendingDoubt(latestVisit, linkedStudy, person, latestVoiceNote);
    final spiritualGoal = _extractSpiritualGoal(person, linkedStudy);
    final empathyNote = _extractEmpathyNote(person, latestVoiceNote);

    return DoorstepBriefingData(
      lessonAndPoint: lessonInfo.lessonAndPoint,
      jwLibraryUri: lessonInfo.jwLibraryUri,
      publicationTitle: lessonInfo.publicationTitle,
      pendingDoubt: pendingDoubt,
      spiritualGoal: spiritualGoal,
      empathyNote: empathyNote,
      audioFilePath: latestVoiceNote?.audioFilePath,
      voiceNoteTranscription: latestVoiceNote?.transcription,
      voiceNoteDurationSeconds: latestVoiceNote?.audioDurationSeconds,
    );
  }

  static ({String? lessonAndPoint, Uri? jwLibraryUri, String? publicationTitle}) _extractLessonAndPoint(
    BibleStudyEntry? linkedStudy,
    VisitEntry? latestVisit, [
    VoiceNoteItem? latestVoiceNote,
  ]) {
    String? lessonAndPoint;
    Uri? jwLibraryUri;
    String? publicationTitle;

    if (linkedStudy != null) {
      if (linkedStudy.title.trim().isNotEmpty) {
        publicationTitle = linkedStudy.title.trim();
      }

      final hasLesson = linkedStudy.currentLesson != null;
      final hasParagraph = linkedStudy.currentParagraph != null;

      if (hasLesson && hasParagraph) {
        final lessonPad = linkedStudy.currentLesson.toString().padLeft(2, '0');
        lessonAndPoint = 'Lição $lessonPad, Ponto ${linkedStudy.currentParagraph}';
      } else if (hasLesson) {
        final lessonPad = linkedStudy.currentLesson.toString().padLeft(2, '0');
        lessonAndPoint = 'Lição $lessonPad';
      } else if (hasParagraph) {
        lessonAndPoint = 'Ponto ${linkedStudy.currentParagraph}';
      } else if (linkedStudy.manualReference != null && linkedStudy.manualReference!.trim().isNotEmpty) {
        lessonAndPoint = linkedStudy.manualReference!.trim();
      } else if (publicationTitle != null) {
        lessonAndPoint = publicationTitle;
      } else {
        final pub = PublicationCatalog.getById(linkedStudy.publicationId);
        lessonAndPoint = pub?.title ?? 'Estudo Bíblico';
      }

      try {
        final resolved = PublicationLinkResolver.resolve(
          publicationId: linkedStudy.publicationId,
          languageCode: linkedStudy.language,
          lesson: linkedStudy.currentLesson,
          paragraph: linkedStudy.currentParagraph,
          manualReference: linkedStudy.manualReference,
        );
        if (resolved.url != null && resolved.url!.trim().isNotEmpty) {
          jwLibraryUri = Uri.tryParse(resolved.url!.trim());
        } else if (resolved.fallbackUrl != null && resolved.fallbackUrl!.trim().isNotEmpty) {
          jwLibraryUri = Uri.tryParse(resolved.fallbackUrl!.trim());
        }
      } catch (_) {
        jwLibraryUri = null;
      }
    }

    if ((lessonAndPoint == null || lessonAndPoint.isEmpty) && latestVisit != null) {
      final scripture = latestVisit.scriptureOrPub?.trim();
      final topic = latestVisit.topicsDiscussed?.trim();

      final hasScripture = scripture != null && scripture.isNotEmpty;
      final hasTopic = topic != null && topic.isNotEmpty;

      if (hasScripture && hasTopic) {
        lessonAndPoint = '$scripture — $topic';
      } else if (hasScripture) {
        lessonAndPoint = scripture;
      } else if (hasTopic) {
        lessonAndPoint = topic;
      }
    }

    if ((lessonAndPoint == null || lessonAndPoint.isEmpty) && latestVoiceNote != null) {
      if (latestVoiceNote.detectedLesson != null && latestVoiceNote.detectedPoint != null) {
        final pad = latestVoiceNote.detectedLesson.toString().padLeft(2, '0');
        lessonAndPoint = 'Lição $pad, Ponto ${latestVoiceNote.detectedPoint}';
      } else if (latestVoiceNote.detectedLesson != null) {
        final pad = latestVoiceNote.detectedLesson.toString().padLeft(2, '0');
        lessonAndPoint = 'Lição $pad';
      } else if (latestVoiceNote.detectedPoint != null) {
        lessonAndPoint = 'Ponto ${latestVoiceNote.detectedPoint}';
      }
    }

    return (
      lessonAndPoint: lessonAndPoint != null && lessonAndPoint.trim().isNotEmpty ? lessonAndPoint.trim() : null,
      jwLibraryUri: jwLibraryUri,
      publicationTitle: publicationTitle,
    );
  }

  static String? _extractPendingDoubt(
    VisitEntry? latestVisit,
    BibleStudyEntry? linkedStudy,
    PersonEntry person, [
    VoiceNoteItem? latestVoiceNote,
  ]) {
    if (latestVisit != null) {
      final question = latestVisit.expressedQuestion?.trim();
      if (question != null && question.isNotEmpty) return question;

      final nextStep = latestVisit.nextStep?.trim();
      if (nextStep != null && nextStep.isNotEmpty) return nextStep;
    }

    if (linkedStudy != null) {
      final studyDoubt = linkedStudy.pendingDoubts?.trim();
      if (studyDoubt != null && studyDoubt.isNotEmpty) return studyDoubt;

      final studyTopic = linkedStudy.nextTopic?.trim();
      if (studyTopic != null && studyTopic.isNotEmpty) return studyTopic;
    }

    if (latestVisit != null) {
      final notes = latestVisit.notes?.trim();
      if (notes != null && notes.isNotEmpty) return notes;
    }

    final personNextAction = person.nextActionNote?.trim();
    if (personNextAction != null && personNextAction.isNotEmpty) return personNextAction;

    if (latestVoiceNote != null) {
      final voiceDoubt = latestVoiceNote.extractedPendingDoubt?.trim();
      if (voiceDoubt != null && voiceDoubt.isNotEmpty) return voiceDoubt;
    }

    return null;
  }

  static String? _extractSpiritualGoal(PersonEntry person, BibleStudyEntry? linkedStudy) {
    final targets = parseTargets(person.contactRestrictions);
    for (final target in targets) {
      final isCompleted = target['isCompleted'] == true || target['isCompleted'] == 'true';
      if (!isCompleted) {
        final title = target['title']?.toString().trim();
        if (title != null && title.isNotEmpty) {
          return title;
        }
      }
    }

    if (linkedStudy != null) {
      final goals = linkedStudy.learningGoals?.trim();
      if (goals != null && goals.isNotEmpty) return goals;
    }

    return null;
  }

  static String? _extractEmpathyNote(PersonEntry person, [VoiceNoteItem? latestVoiceNote]) {
    final notes = parseNotes(person.generalNotes);
    if (notes.isEmpty) {
      final voiceEmpathy = latestVoiceNote?.extractedEmpathyNote?.trim();
      if (voiceEmpathy != null && voiceEmpathy.isNotEmpty) return voiceEmpathy;
      return null;
    }

    final validNotes = notes.where((n) {
      final text = n['text']?.toString().trim();
      return text != null && text.isNotEmpty;
    }).toList();

    if (validNotes.isEmpty) return null;

    validNotes.sort((a, b) {
      final dateA = DateTime.tryParse(a['createdAt']?.toString() ?? '');
      final dateB = DateTime.tryParse(b['createdAt']?.toString() ?? '');
      if (dateA != null && dateB != null) {
        return dateB.compareTo(dateA);
      }
      if (dateA != null && dateB == null) return -1;
      if (dateA == null && dateB != null) return 1;
      return 0;
    });

    return validNotes.first['text']?.toString().trim();
  }

  /// Converte a string de notas em lista de mapas, suportando JSON e legado.
  static List<Map<String, dynamic>> parseNotes(String? raw) {
    if (raw == null) return [];
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '[]') return [];
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        if (decoded.isEmpty) return [];
        final list = <Map<String, dynamic>>[];
        for (final item in decoded) {
          if (item is Map) {
            list.add(Map<String, dynamic>.from(item));
          }
        }
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}

    return [
      {
        'id': 'legacy-note',
        'text': trimmed,
        'createdAt': DateTime.now().toIso8601String(),
      }
    ];
  }

  /// Converte a string de alvos em lista de mapas, suportando JSON e legado.
  static List<Map<String, dynamic>> parseTargets(String? raw) {
    if (raw == null) return [];
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '[]') return [];
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        if (decoded.isEmpty) return [];
        final list = <Map<String, dynamic>>[];
        for (final item in decoded) {
          if (item is Map) {
            list.add(Map<String, dynamic>.from(item));
          }
        }
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}

    return [
      {
        'id': 'legacy-target',
        'title': trimmed,
        'isCompleted': false,
        'createdAt': DateTime.now().toIso8601String(),
        'completedAt': null,
      }
    ];
  }
}
