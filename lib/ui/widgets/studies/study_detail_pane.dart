import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/date_utils.dart';
import '../../../database/app_database.dart';
import '../../../publications/publication_catalog.dart';
import '../markdown_preview_text.dart';

/// Painel de detalhe lateral exibido no modo iPad Master-Detail (>= 900px)
/// da tela de Estudos Bíblicos, reunindo progresso, sessões recentes e ações rápidas.
class StudyDetailPane extends StatelessWidget {
  final BibleStudyEntry study;
  final PersonEntry? primaryPerson;
  final List<StudySessionEntry> sessions;
  final VoidCallback onRecordSession;
  final VoidCallback onEditStudy;
  final VoidCallback onOpenPublication;
  final VoidCallback? onOpenStudentProfile;
  final VoidCallback onEndOrReactivateStudy;

  const StudyDetailPane({
    super.key,
    required this.study,
    required this.primaryPerson,
    required this.sessions,
    required this.onRecordSession,
    required this.onEditStudy,
    required this.onOpenPublication,
    required this.onOpenStudentProfile,
    required this.onEndOrReactivateStudy,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pub = PublicationCatalog.getById(study.publicationId);
    final totalLessons = pub?.totalLessons ?? 60;
    final currentLesson = study.currentLesson ?? 1;
    final progress = totalLessons > 0
        ? (currentLesson / totalLessons).clamp(0.0, 1.0)
        : 0.0;
    final studySessions =
        sessions
            .where((s) => s.studyId == study.id && s.deletedAt == null)
            .toList()
          ..sort((a, b) => b.dateTimeField.compareTo(a.dateTimeField));
    final isActive = study.status == 'ativo';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.14),
                child: const Icon(
                  Icons.school_rounded,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        study.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pub?.title ?? study.publicationId,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text(
                  isActive ? 'Ativo' : 'Encerrado',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor:
                    (isActive ? AppTheme.successGreen : AppTheme.alertAmber)
                        .withValues(alpha: 0.15),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Progresso do Estudo',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Lição $currentLesson de $totalLessons',
                          style: const TextStyle(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Semantics(
                    label:
                        'Progresso do estudo: lição $currentLesson de $totalLessons',
                    value: '${(progress * 100).round()}%',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      Text(
                        'Início: ${AppDateUtils.formatDate(study.startedAt)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (study.lastSessionAt != null)
                        Text(
                          'Última sessão: ${AppDateUtils.formatDate(study.lastSessionAt!)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      if (study.currentParagraph != null)
                        Text(
                          'Parágrafo atual: ${study.currentParagraph}',
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                  if (study.learningGoals != null &&
                      study.learningGoals!.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Alvos de aprendizado: ${study.learningGoals}',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              Semantics(
                container: true,
                excludeSemantics: true,
                button: true,
                label: 'Registrar nova sessão do estudo ${study.title}',
                child: ElevatedButton.icon(
                  onPressed: isActive ? onRecordSession : null,
                  icon: const Icon(Icons.playlist_add_check, size: 18),
                  label: const Text('Registrar Sessão'),
                ),
              ),
              Semantics(
                container: true,
                excludeSemantics: true,
                button: true,
                label: 'Editar dados do estudo ${study.title}',
                child: OutlinedButton.icon(
                  onPressed: onEditStudy,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar Estudo'),
                ),
              ),
              Semantics(
                container: true,
                excludeSemantics: true,
                button: true,
                label: 'Abrir publicação no JW Library',
                child: OutlinedButton.icon(
                  onPressed: onOpenPublication,
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: const Text('JW Library'),
                ),
              ),
              if (onOpenStudentProfile != null)
                Semantics(
                  container: true,
                  excludeSemantics: true,
                  button: true,
                  label:
                      'Abrir cadastro de ${primaryPerson?.name ?? study.title}',
                  child: OutlinedButton.icon(
                    onPressed: onOpenStudentProfile,
                    icon: const Icon(Icons.person_outline, size: 18),
                    label: Text(
                      primaryPerson != null
                          ? 'Cadastro: ${primaryPerson!.name}'
                          : 'Ver Cadastro',
                    ),
                  ),
                ),
              Semantics(
                container: true,
                excludeSemantics: true,
                button: true,
                label: isActive
                    ? 'Encerrar estudo ${study.title}'
                    : 'Reativar estudo ${study.title}',
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isActive
                        ? AppTheme.alertRed
                        : AppTheme.successGreen,
                    side: BorderSide(
                      color: isActive
                          ? AppTheme.alertRed
                          : AppTheme.successGreen,
                    ),
                  ),
                  onPressed: onEndOrReactivateStudy,
                  icon: Icon(
                    isActive ? Icons.stop_circle_outlined : Icons.refresh,
                    size: 18,
                  ),
                  label: Text(isActive ? 'Encerrar Estudo' : 'Reativar Estudo'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: Text(
              'Histórico de Sessões (${studySessions.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          if (studySessions.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Nenhuma sessão registrada ainda para este estudo.',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
              ),
            )
          else
            for (final session in studySessions.take(15))
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(
                    Icons.event_note_rounded,
                    color: AppTheme.primaryBlue,
                  ),
                  title: Text(
                    'Lição ${session.lessonCovered ?? 1} • ${AppDateUtils.formatDateTime(session.dateTimeField)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (session.paragraphsCovered != null &&
                          session.paragraphsCovered!.isNotEmpty)
                        Text('Parágrafos: ${session.paragraphsCovered}'),
                      if (session.sessionNotes != null &&
                          session.sessionNotes!.isNotEmpty)
                        MarkdownPreviewText(
                          text: session.sessionNotes!,
                          style: const TextStyle(fontSize: 13),
                        ),
                      if (session.nextStep != null &&
                          session.nextStep!.isNotEmpty)
                        MarkdownPreviewText(
                          text: 'Próximo passo: ${session.nextStep}',
                          style: const TextStyle(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
