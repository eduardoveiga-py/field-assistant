import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../dashboard/counting_rules.dart';
import '../../database/app_database.dart';
import '../../publications/lff_book_catalog.dart';
import '../../publications/publication_catalog.dart';
import '../providers.dart';
import 'end_study_dialog.dart';
import 'person_preferred_schedule_dialog.dart';
import 'publication_link_dialog.dart';
import 'record_study_session_dialog.dart';
import 'spiritual_timeline_card.dart';
import 'study_form_dialog.dart';

/// Aba de Estudo Bíblico do Contato
/// Exibe dados da publicação, progresso oficial LFF, métricas de assistência,
/// linha do tempo espiritual e histórico de sessões.
class PersonStudyTab extends ConsumerWidget {
  final PersonEntry person;
  final BibleStudyEntry? linkedStudy;
  final bool isDark;

  const PersonStudyTab({
    super.key,
    required this.person,
    this.linkedStudy,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);

    if (linkedStudy == null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.menu_book, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                'Nenhum Estudo Bíblico Vinculado',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Inicie o estudo bíblico com ${person.name} para acompanhar o progresso das lições no livro "Viva Feliz para Sempre!", referências oficiais do JW Library e sessões com contagem de assistência.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textMuted),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.add_circle_outline),
                label: Text('+ Iniciar Estudo Bíblico com ${person.name}'),
                onPressed: () => StudyFormDialog.show(
                  context,
                  initialPersonId: person.id,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.alarm,
                              size: 20,
                              color: Color(0xFF7C3AED),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Dia e Horário Habitual',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                  Text(
                                    person.preferredSchedule != null &&
                                            person.preferredSchedule!.isNotEmpty
                                        ? person.preferredSchedule!
                                        : 'Não definido (ex: Sábado às 09:00)',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => PersonPreferredScheduleDialog.show(
                          context,
                          repo,
                          person,
                        ),
                        child: Text(
                          person.preferredSchedule == null ||
                                  person.preferredSchedule!.isEmpty
                              ? 'Definir'
                              : 'Alterar',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final study = linkedStudy!;
    final pub = PublicationCatalog.getById(study.publicationId);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Principal do Estudo
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.menu_book,
                          color: Color(0xFF7C3AED),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              study.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              pub?.title ?? study.publicationId,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(
                          study.status.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: study.status == 'ativo'
                            ? const Color(0xFF059669).withValues(alpha: 0.15)
                            : AppTheme.primaryBlue.withValues(alpha: 0.1),
                        side: BorderSide(
                          color: study.status == 'ativo'
                              ? const Color(0xFF059669)
                              : AppTheme.primaryBlue,
                        ),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Lição Atual',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          Text(
                            study.currentLesson != null
                                ? 'Lição ${study.currentLesson}'
                                : 'Não definida',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF7C3AED),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            study.publicationId == 'lff-book' ||
                                    study.publicationId == 'lff-brochure'
                                ? 'Ponto Atual'
                                : 'Parágrafo',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          Text(
                            study.currentParagraph != null
                                ? (study.publicationId == 'lff-book' ||
                                          study.publicationId == 'lff-brochure'
                                      ? 'Ponto ${study.currentParagraph}'
                                      : 'Parágrafo ${study.currentParagraph}')
                                : 'Início',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Frequência',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          Chip(
                            label: Text(
                              study.frequency.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.alarm,
                                size: 20,
                                color: Color(0xFF7C3AED),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Dia e Horário Habitual do Estudo',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                    Text(
                                      person.preferredSchedule != null &&
                                              person
                                                  .preferredSchedule!
                                                  .isNotEmpty
                                          ? person.preferredSchedule!
                                          : 'Não definido (ex: Sábado às 09:00)',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF7C3AED),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          icon: const Icon(Icons.edit, size: 16),
                          label: Text(
                            person.preferredSchedule == null ||
                                    person.preferredSchedule!.isEmpty
                                ? 'Definir'
                                : 'Alterar',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () => PersonPreferredScheduleDialog.show(
                            context,
                            repo,
                            person,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (study.nextTopic != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.flag_outlined,
                            size: 16,
                            color: Color(0xFF7C3AED),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Próximo assunto: ${study.nextTopic}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF7C3AED),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text(
                            'Abrir no JW Library',
                            style: TextStyle(fontSize: 12),
                          ),
                          onPressed: () =>
                              PublicationLinkDialog.show(context, study),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.add_task, size: 16),
                          label: const Text(
                            'Registrar Sessão',
                            style: TextStyle(fontSize: 12),
                          ),
                          onPressed: () => RecordStudySessionDialog.show(
                            context,
                            repo: repo,
                            study: study,
                            person: person,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Card de Progresso Individual 0–100% no Livro LFF
          if (study.publicationId == 'lff-book') ...[
            Builder(
              builder: (context) {
                final lesson = study.currentLesson ?? 1;
                final point = study.currentParagraph ?? 1;
                final progressPct = LffBookCatalog.calculateProgressPercentage(
                  lesson: lesson,
                  point: point,
                );
                final section = LffBookCatalog.getSectionForLesson(lesson);
                final lessonInfo = LffBookCatalog.getLesson(lesson);
                final pointsCovered = (lesson - 1) * 6 + point.clamp(1, 6);

                final studyAgeDays = DateTime.now()
                    .difference(study.startedAt)
                    .inDays;
                final effectiveDays = studyAgeDays < 1 ? 1 : studyAgeDays;
                final studyAgeWeeks = (effectiveDays / 7.0) < 0.5
                    ? 0.5
                    : (effectiveDays / 7.0);
                final velocity = (lesson - 1 + (point / 6.0)) / studyAgeWeeks;
                final String velocityText;
                final Color velocityColor;
                if (velocity >= 1.2) {
                  velocityText =
                      '⚡ Ritmo Acelerado (${velocity.toStringAsFixed(1)} lições/sem)';
                  velocityColor = const Color(0xFF059669);
                } else if (velocity >= 0.8) {
                  velocityText = '🎯 Ritmo Ideal (~1 lição/sem)';
                  velocityColor = const Color(0xFF2563EB);
                } else if (velocity >= 0.4) {
                  velocityText =
                      '🌱 Ritmo Constante (${velocity.toStringAsFixed(1)} lições/sem)';
                  velocityColor = const Color(0xFFD97706);
                } else {
                  velocityText = '🐢 Ritmo Calmo / Pausado';
                  velocityColor = const Color(0xFF64748B);
                }

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(
                      color: Color(0xFF7C3AED),
                      width: 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7C3AED)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.speed_rounded,
                                    color: Color(0xFF7C3AED),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Progresso Oficial do Livro',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      'Seção ${section.sectionNumber}: ${section.title}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: Color(0xFF7C3AED),
                                    size: 20,
                                  ),
                                  tooltip: 'Editar Dados do Estudo',
                                  onPressed: () => StudyFormDialog.show(
                                    context,
                                    study: study,
                                  ),
                                ),
                                Text(
                                  '${progressPct.toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF7C3AED),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progressPct / 100.0,
                            minHeight: 12,
                            backgroundColor: Colors.purple.shade100,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF7C3AED),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$pointsCovered de 360 pontos concluídos',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF7C3AED),
                              ),
                            ),
                            Text(
                              'Lição $lesson de 60',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Lição Atual:',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                  Text(
                                    lessonInfo != null
                                        ? 'Lição $lesson: ${lessonInfo.title}'
                                        : 'Lição $lesson',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: velocityColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: velocityColor.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                velocityText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: velocityColor,
                                ),
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
            const SizedBox(height: 14),
          ],

          // Ideia 5: Linha do Tempo Espiritual do Estudante
          SpiritualTimelineCard(
            person: person,
            study: study,
            isDark: isDark,
          ),
          const SizedBox(height: 14),

          // Card de Métricas do Estudante & Funil de Progresso
          StreamBuilder<List<StudySessionEntry>>(
            stream: repo.watchSessionsForStudy(study.id),
            builder: (context, sessionSnap) {
              final sessions = sessionSnap.data ?? [];
              return StreamBuilder<List<VisitEntry>>(
                stream: repo.watchVisitsForPerson(person.id),
                builder: (context, visitSnap) {
                  final visits = visitSnap.data ?? [];
                  final progress = DashboardCalculator.calculateStudentProgress(
                    person: person,
                    study: study,
                    sessions: sessions,
                    visits: visits,
                  );

                  return Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.insights,
                                color: Color(0xFF7C3AED),
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Métricas e Regularidade do Estudante',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: MetricSmallCard(
                                  label: 'Total de Visitas',
                                  value: '${progress.totalVisits}',
                                  icon: Icons.repeat,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: MetricSmallCard(
                                  label: 'Não estava em casa',
                                  value: '${progress.notAtHomeVisits}',
                                  icon: Icons.door_front_door_outlined,
                                  color: AppTheme.alertAmber,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: MetricSmallCard(
                                  label: '% Regularidade',
                                  value:
                                      '${progress.regularityPercent.toStringAsFixed(0)}%',
                                  icon: Icons.check_circle_outline,
                                  color: progress.regularityPercent >= 70
                                      ? AppTheme.successGreen
                                      : AppTheme.alertAmber,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: MetricSmallCard(
                                  label: 'Média Presentes',
                                  value: progress.averageAttendees
                                      .toStringAsFixed(1),
                                  icon: Icons.group,
                                  color: const Color(0xFF7C3AED),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: progress.isPart3Reached
                                  ? AppTheme.successGreen.withValues(
                                      alpha: 0.08,
                                    )
                                  : const Color(0xFF7C3AED)
                                        .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: progress.isPart3Reached
                                    ? AppTheme.successGreen.withValues(
                                        alpha: 0.3,
                                      )
                                    : const Color(0xFF7C3AED)
                                          .withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  progress.isPart3Reached
                                      ? Icons.check_circle
                                      : Icons.bookmark,
                                  color: progress.isPart3Reached
                                      ? AppTheme.successGreen
                                      : const Color(0xFF7C3AED),
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        progress.isBookCompleted
                                            ? '🎉 Livro Seja Feliz Para Sempre! Concluído'
                                            : progress.isPart3Reached
                                            ? '🎯 Atingiu a Parte 3 (Lição 34+) - Avançando no Livro!'
                                            : 'Progresso: Lição ${progress.currentLesson} de 60',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: progress.isPart3Reached
                                              ? AppTheme.successGreen
                                              : const Color(0xFF7C3AED),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        progress.isPart3Reached
                                            ? 'Estudante passou com êxito da transição da brochura e segue o estudo até o batismo.'
                                            : 'Base fundamental das seções 1 e 2 até a Lição 33.',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Botão Encerrar Estudo ou Reativar Estudo
                          if (study.status == 'encerrado' ||
                              study.status == 'concluido') ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFF59E0B),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info,
                                    color: Color(0xFFB45309),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Estudo encerrado: ${progress.endReason ?? "Sem motivo informado"}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF92400E),
                                      ),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.successGreen,
                                      foregroundColor: Colors.white,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    icon: const Icon(Icons.refresh, size: 14),
                                    label: const Text(
                                      'Reativar Estudo',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    onPressed: () => EndStudyDialog.reactivate(
                                      context,
                                      repo,
                                      study,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.alertRed,
                                  side: const BorderSide(
                                    color: AppTheme.alertRed,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.stop_circle_outlined,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Encerrar Estudo Bíblico (com motivo)',
                                ),
                                onPressed: () => EndStudyDialog.show(
                                  context,
                                  repo: repo,
                                  study: study,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 20),

          // Histórico das Sessões de Estudo
          const Text(
            'Histórico de Sessões Realizadas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 10),

          StreamBuilder<List<StudySessionEntry>>(
            stream: repo.watchSessionsForStudy(study.id),
            builder: (context, snapshot) {
              final sessions = snapshot.data ?? [];
              if (sessions.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.history,
                            size: 40,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Nenhuma sessão registrada para este estudo.',
                            style: TextStyle(color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.add_task, size: 16),
                            label: const Text('Registrar Primeira Sessão'),
                            onPressed: () => RecordStudySessionDialog.show(
                              context,
                              repo: repo,
                              study: study,
                              person: person,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  final session = sessions[index];
                  final isDone = session.status == 'realizada';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isDone
                            ? const Color(0xFF7C3AED).withValues(alpha: 0.15)
                            : Colors.grey.shade200,
                        child: Icon(
                          isDone ? Icons.school : Icons.cancel_outlined,
                          color: isDone
                              ? const Color(0xFF7C3AED)
                              : AppTheme.textMuted,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'Lição ${session.lessonCovered ?? 1} • ${AppDateUtils.formatDate(session.dateTimeField)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (session.paragraphsCovered != null)
                            Text(
                              study.publicationId == 'lff-book' ||
                                      study.publicationId == 'lff-brochure'
                                  ? 'Pontos abordados: ${session.paragraphsCovered}'
                                  : 'Parágrafos abordados: ${session.paragraphsCovered}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          if (session.sessionNotes != null &&
                              session.sessionNotes!.isNotEmpty)
                            Text(
                              session.sessionNotes!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                              ),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Builder(
                            builder: (context) {
                              int attendeesCount = 0;
                              if (session.participantIds.isNotEmpty) {
                                try {
                                  final list = jsonDecode(session.participantIds) as List;
                                  attendeesCount = list.length;
                                } catch (_) {}
                              }
                              if (attendeesCount > 0) {
                                return Chip(
                                  avatar: const Icon(Icons.group, size: 12),
                                  label: Text('$attendeesCount pres.'),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 18,
                            ),
                            tooltip: 'Excluir registro da sessão',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Excluir Sessão'),
                                  content: const Text(
                                    'Deseja realmente excluir este registro de sessão? O progresso do estudo não será alterado.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Excluir'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await repo.deleteSession(session.id);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
