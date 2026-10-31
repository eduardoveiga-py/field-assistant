/// Modelo de domínio para notas de voz gravadas e transcritas.
class VoiceNoteItem {
  final String id;
  final String personId;
  final String? visitId;
  final String? studyId;
  final String? audioFilePath;
  final int audioDurationSeconds;
  final String transcription;
  final int? detectedLesson;
  final int? detectedPoint;
  final String? extractedPendingDoubt;
  final String? extractedEmpathyNote;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;

  VoiceNoteItem({
    required this.id,
    required this.personId,
    this.visitId,
    this.studyId,
    this.audioFilePath,
    this.audioDurationSeconds = 0,
    required this.transcription,
    this.detectedLesson,
    this.detectedPoint,
    this.extractedPendingDoubt,
    this.extractedEmpathyNote,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.revision = 1,
  });

  /// Duração formatada em mm:ss (ex: "00:15")
  String get formattedDuration {
    final minutes = (audioDurationSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (audioDurationSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'person_id': personId,
        'visit_id': visitId,
        'study_id': studyId,
        'audio_file_path': audioFilePath,
        'audio_duration_seconds': audioDurationSeconds,
        'transcription': transcription,
        'detected_lesson': detectedLesson,
        'detected_point': detectedPoint,
        'extracted_pending_doubt': extractedPendingDoubt,
        'extracted_empathy_note': extractedEmpathyNote,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
        'revision': revision,
      };

  factory VoiceNoteItem.fromMap(Map<String, dynamic> map) => VoiceNoteItem(
        id: map['id'] as String,
        personId: map['person_id'] as String,
        visitId: map['visit_id'] as String?,
        studyId: map['study_id'] as String?,
        audioFilePath: map['audio_file_path'] as String?,
        audioDurationSeconds: (map['audio_duration_seconds'] as num?)?.toInt() ?? 0,
        transcription: map['transcription'] as String? ?? '',
        detectedLesson: (map['detected_lesson'] as num?)?.toInt(),
        detectedPoint: (map['detected_point'] as num?)?.toInt(),
        extractedPendingDoubt: map['extracted_pending_doubt'] as String?,
        extractedEmpathyNote: map['extracted_empathy_note'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        deletedAt: map['deleted_at'] != null ? DateTime.parse(map['deleted_at'] as String) : null,
        revision: (map['revision'] as num?)?.toInt() ?? 1,
      );

  VoiceNoteItem copyWith({
    String? id,
    String? personId,
    String? visitId,
    String? studyId,
    String? audioFilePath,
    int? audioDurationSeconds,
    String? transcription,
    int? detectedLesson,
    int? detectedPoint,
    String? extractedPendingDoubt,
    String? extractedEmpathyNote,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    int? revision,
  }) {
    return VoiceNoteItem(
      id: id ?? this.id,
      personId: personId ?? this.personId,
      visitId: visitId ?? this.visitId,
      studyId: studyId ?? this.studyId,
      audioFilePath: audioFilePath ?? this.audioFilePath,
      audioDurationSeconds: audioDurationSeconds ?? this.audioDurationSeconds,
      transcription: transcription ?? this.transcription,
      detectedLesson: detectedLesson ?? this.detectedLesson,
      detectedPoint: detectedPoint ?? this.detectedPoint,
      extractedPendingDoubt: extractedPendingDoubt ?? this.extractedPendingDoubt,
      extractedEmpathyNote: extractedEmpathyNote ?? this.extractedEmpathyNote,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
    );
  }
}
