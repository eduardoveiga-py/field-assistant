import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../dashboard/student_priority_engine.dart';
import '../../database/app_database.dart';
import '../../publications/lff_book_catalog.dart';

/// Visualização inteligente de Prioridade & Progresso dos Estudos Bíblicos Ativos.
class StudiesPriorityProgressView extends StatelessWidget {
  final List<BibleStudyEntry> activeStudies;
  final List<StudyParticipantEntry> participants;
  final List<PersonEntry> people;
  final List<StudySessionEntry> sessions;
  final List<AppointmentEntry> appointments;
  final Map<String, int> manualOrderMap;
  final bool isDark;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(BibleStudyEntry study) onRecordSession;
  final void Function(String personId) onOpenContact;

  const StudiesPriorityProgressView({
    super.key,
    required this.activeStudies,
    required this.participants,
    required this.people,
    required this.sessions,
    required this.appointments,
    required this.manualOrderMap,
    required this.isDark,
    required this.onReorder,
    required this.onRecordSession,
    required this.onOpenContact,
  });

  @override
  Widget build(BuildContext context) {
    if (activeStudies.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star_outline, size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'Nenhum estudo bíblico ativo para calcular prioridade.\nAdicione ou ative um estudo para ver a lista inteligente.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final priorityItems = StudentPriorityEngine.calculatePriorities(
      activeStudies: activeStudies,
      participants: participants,
      people: people,
      sessions: sessions,
      appointments: appointments,
      manualOrder: manualOrderMap,
    );

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 16,
                color: AppTheme.primaryBlue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Prioridade calculada por frequência (2x/sem), ritmo e assiduidade. Arraste para reordenar.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF93C5FD)
                        : const Color(0xFF1E40AF),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: priorityItems.length,
            onReorderItem: onReorder,
            itemBuilder: (context, index) {
              final item = priorityItems[index];
              final study = item.study;
              final lffLesson =
                  study.publicationId == 'lff-book' &&
                      study.currentLesson != null
                  ? LffBookCatalog.getLesson(study.currentLesson!)
                  : null;

              Color priorityColor;
              IconData priorityIcon;
              switch (item.priorityTier) {
                case 'Muito Alta':
                  priorityColor = const Color(0xFFDC2626);
                  priorityIcon = Icons.local_fire_department;
                  break;
                case 'Alta':
                  priorityColor = const Color(0xFF2563EB);
                  priorityIcon = Icons.trending_up;
                  break;
                case 'Média':
                  priorityColor = const Color(0xFF0D9488);
                  priorityIcon = Icons.check_circle_outline;
                  break;
                default:
                  priorityColor = const Color(0xFFD97706);
                  priorityIcon = Icons.warning_amber_rounded;
              }

              return Card(
                key: ValueKey(study.id), // CONTRATO CRÍTICO EXIGIDO POR PROJECT.md E TESTES
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '#${item.manualRank}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              study.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: priorityColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: priorityColor.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  priorityIcon,
                                  size: 14,
                                  color: priorityColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  item.priorityTier,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: priorityColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.drag_indicator, color: Colors.grey),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Estudante: ${item.primaryPerson.name}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFFCBD5E1)
                              : AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Progresso LFF
                      if (study.publicationId == 'lff-book') ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                study.currentLesson != null
                                    ? 'Lição ${study.currentLesson}: ${lffLesson?.title ?? "Seja Feliz Para Sempre!"}'
                                    : 'Livro Seja Feliz Para Sempre!',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${item.progressPercent.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentTeal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: item.progressPercent / 100.0,
                            minHeight: 6,
                            backgroundColor: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppTheme.accentTeal,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      // Chips de métricas de prioridade
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (item.frequency == 'duas_vezes_semana')
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '🔥 2x / semana',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.velocityLabel,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                  ? const Color(0xFFCBD5E1)
                                  : AppTheme.textMuted,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.daysSinceLastSession != null
                                  ? 'Última: ${item.daysSinceLastSession}d atrás'
                                  : 'Sem sessões ainda',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                  ? const Color(0xFFCBD5E1)
                                  : AppTheme.textMuted,
                              ),
                            ),
                          ),
                          if (item.spiritualGoalsMetCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '🎯 ${item.spiritualGoalsMetCount} meta(s)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF166534),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.person, size: 16),
                              label: const Text(
                                'Contato',
                                style: TextStyle(fontSize: 12),
                              ),
                              onPressed: () => onOpenContact(item.primaryPerson.id),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7C3AED),
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(
                                Icons.playlist_add_check,
                                size: 16,
                              ),
                              label: const Text(
                                'Registrar Sessão',
                                style: TextStyle(fontSize: 12),
                              ),
                              onPressed: () => onRecordSession(study),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
