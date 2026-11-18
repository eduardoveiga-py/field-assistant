part of '../person_detail_screen.dart';

extension _PersonDetailStudyAndNotesTabs on _PersonDetailScreenState {
  Widget _buildBibleStudyTab(
    BuildContext context,
    AppRepository repo,
    PersonEntry person,
    BibleStudyEntry? linkedStudy,
    bool isDark,
  ) {
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
                onPressed: () => _showStartStudyDialog(context, person),
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
                        onPressed: () =>
                            _showEditPreferredScheduleDialog(context, person),
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

    final pub = PublicationCatalog.getById(linkedStudy.publicationId);

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
                              linkedStudy.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              pub?.title ?? linkedStudy.publicationId,
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
                          linkedStudy.status.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: linkedStudy.status == 'ativo'
                            ? const Color(0xFF059669).withValues(alpha: 0.15)
                            : AppTheme.primaryBlue.withValues(alpha: 0.1),
                        side: BorderSide(
                          color: linkedStudy.status == 'ativo'
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
                            linkedStudy.currentLesson != null
                                ? 'Lição ${linkedStudy.currentLesson}'
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
                            linkedStudy.publicationId == 'lff-book' ||
                                    linkedStudy.publicationId == 'lff-brochure'
                                ? 'Ponto Atual'
                                : 'Parágrafo',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          Text(
                            linkedStudy.currentParagraph != null
                                ? (linkedStudy.publicationId == 'lff-book' ||
                                          linkedStudy.publicationId ==
                                              'lff-brochure'
                                      ? 'Ponto ${linkedStudy.currentParagraph}'
                                      : 'Parágrafo ${linkedStudy.currentParagraph}')
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
                              linkedStudy.frequency.toUpperCase(),
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
                          onPressed: () =>
                              _showEditPreferredScheduleDialog(context, person),
                        ),
                      ],
                    ),
                  ),
                  if (linkedStudy.nextTopic != null) ...[
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
                              'Próximo assunto: ${linkedStudy.nextTopic}',
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
                              _openPublicationLink(context, linkedStudy),
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
                          onPressed: () => _showRecordStudySessionDialog(
                            context,
                            linkedStudy,
                            person,
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
          if (linkedStudy.publicationId == 'lff-book') ...[
            Builder(
              builder: (context) {
                final lesson = linkedStudy.currentLesson ?? 1;
                final point = linkedStudy.currentParagraph ?? 1;
                final progressPct = LffBookCatalog.calculateProgressPercentage(
                  lesson: lesson,
                  point: point,
                );
                final section = LffBookCatalog.getSectionForLesson(lesson);
                final lessonInfo = LffBookCatalog.getLesson(lesson);
                final pointsCovered = (lesson - 1) * 6 + point.clamp(1, 6);

                final studyAgeDays = DateTime.now()
                    .difference(linkedStudy.startedAt)
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
                                  onPressed: () => _showEditStudyDialog(
                                    context,
                                    linkedStudy,
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
          _buildSpiritualTimelineCard(
            context,
            person,
            linkedStudy,
            repo,
            isDark,
          ),
          const SizedBox(height: 14),

          // Card de Métricas do Estudante & Funil de Progresso
          StreamBuilder<List<StudySessionEntry>>(
            stream: repo.watchSessionsForStudy(linkedStudy.id),
            builder: (context, sessionSnap) {
              final sessions = sessionSnap.data ?? [];
              return StreamBuilder<List<VisitEntry>>(
                stream: repo.watchVisitsForPerson(person.id),
                builder: (context, visitSnap) {
                  final visits = visitSnap.data ?? [];
                  final progress = DashboardCalculator.calculateStudentProgress(
                    person: person,
                    study: linkedStudy,
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
                                child: PersonMetricSmallCard(
                                  label: 'Total de Visitas',
                                  value: '${progress.totalVisits}',
                                  icon: Icons.repeat,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: PersonMetricSmallCard(
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
                                child: PersonMetricSmallCard(
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
                                child: PersonMetricSmallCard(
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
                          // Progresso no Livro "Seja Feliz Para Sempre!"
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
                          if (linkedStudy.status == 'encerrado' ||
                              linkedStudy.status == 'concluido') ...[
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
                                    onPressed: () => _reactivateStudy(
                                      context,
                                      repo,
                                      linkedStudy,
                                      person,
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
                                onPressed: () => _showEndStudyDialog(
                                  context,
                                  repo,
                                  linkedStudy,
                                  person,
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
          const SizedBox(height: 8),

          StreamBuilder<List<StudySessionEntry>>(
            stream: repo.watchSessionsForStudy(linkedStudy.id),
            builder: (context, sessionSnapshot) {
              final sessions = sessionSnapshot.data ?? [];
              if (sessions.isEmpty) {
                final isAdvanced = (linkedStudy.currentLesson ?? 1) > 1;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        isAdvanced
                            ? 'Estudo em andamento (iniciado em ${AppDateUtils.formatDate(linkedStudy.startedAt)} • Lição atual: ${linkedStudy.currentLesson ?? 1}).\n${linkedStudy.lastSessionAt != null ? "Última sessão informada: ${AppDateUtils.formatDate(linkedStudy.lastSessionAt!)}.\n" : ""}Nenhuma sessão individual registrada no app ainda. Toque em "Registrar Sessão" para continuar acompanhando o progresso.'
                            : 'Nenhuma sessão registrada para este estudo ainda.\nToque em "Registrar Sessão" ou "Registrar Conversa" para pontuar as lições.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: sessions.map((s) {
                  final attendance = DashboardCalculator.parseSessionAttendance(
                    s,
                  );

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                AppDateUtils.formatDateTime(s.dateTimeField),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF7C3AED),
                                ),
                              ),
                              Chip(
                                avatar: Icon(
                                  s.status == 'cancelada'
                                      ? Icons.cancel_outlined
                                      : Icons.group,
                                  size: 14,
                                  color: s.status == 'cancelada'
                                      ? AppTheme.alertRed
                                      : const Color(0xFF7C3AED),
                                ),
                                label: Text(
                                  s.status == 'cancelada'
                                      ? 'Estudo Falhou / Não Realizado'
                                      : '$attendance ${attendance == 1 ? "presente" : "presentes"}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: s.status == 'cancelada'
                                        ? AppTheme.alertRed
                                        : null,
                                  ),
                                ),
                                backgroundColor: s.status == 'cancelada'
                                    ? AppTheme.alertRed.withValues(alpha: 0.1)
                                    : null,
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (s.lessonCovered != null)
                                Text(
                                  'Lição ${s.lessonCovered}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              if (s.paragraphsCovered != null) ...[
                                const Text(' • '),
                                Text('Parágrafos: ${s.paragraphsCovered}'),
                              ],
                            ],
                          ),
                          if (s.sessionNotes != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              s.sessionNotes!,
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                          if (s.nextStep != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED)
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Próximo passo: ${s.nextStep}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF7C3AED),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ABA 3: NECESSIDADES & OBSERVAÇÕES (Registro de data/hora exata em JSON)
  // ---------------------------------------------------------------------------
  Widget _buildNeedsAndNotesTab(
    BuildContext context,
    AppRepository repo,
    PersonEntry person,
    bool isDark,
  ) {
    final notes = _parseNotes(person.generalNotes);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Necessidades & Observações',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${notes.length} ${notes.length == 1 ? "registro com data e hora" : "registros com data e hora"}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentTeal,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('+ Nova Observação'),
                onPressed: () =>
                    _showAddOrEditNoteDialog(context, repo, person),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (notes.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.note_alt_outlined,
                        size: 56,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Nenhuma necessidade ou observação registrada para ${person.name}.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Toque no botão "+ Nova Observação" para registrar circunstâncias familiares, pontos de interesse ou dúvidas bíblicas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentTeal,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('+ Registrar Primeira Observação'),
                        onPressed: () =>
                            _showAddOrEditNoteDialog(context, repo, person),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Column(
              children: notes.map((note) {
                final createdAt = DateTime.tryParse(note['createdAt'] ?? '');
                final updatedAt = note['updatedAt'] != null
                    ? DateTime.tryParse(note['updatedAt'])
                    : null;
                final text = note['text'] ?? '';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                  color: AppTheme.accentTeal,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  AppDateUtils.formatDateTimeWithAt(createdAt),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppTheme.accentTeal,
                                  ),
                                ),
                                if (updatedAt != null) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '(editado)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade500,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                  tooltip: 'Editar',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _showAddOrEditNoteDialog(
                                    context,
                                    repo,
                                    person,
                                    note,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: AppTheme.alertRed,
                                  ),
                                  tooltip: 'Excluir',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        title: const Text('Excluir Observação'),
                                        content: const Text(
                                          'Tem certeza que deseja excluir esta anotação?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(c, false),
                                            child: const Text('Cancelar'),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppTheme.alertRed,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () =>
                                                Navigator.pop(c, true),
                                            child: const Text('Excluir'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      final updated = notes
                                          .where((n) => n['id'] != note['id'])
                                          .toList();
                                      await _saveNotes(repo, person, updated);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 12),
                        SelectableText(
                          text,
                          style: const TextStyle(fontSize: 14, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ABA 4: ALVOS & TAREFAS ESPIRITUAIS (Checkbox, Risco, Datas de Criação/Conclusão em JSON)
  // ---------------------------------------------------------------------------
  Widget _buildTargetsAndTasksTab(
    BuildContext context,
    AppRepository repo,
    PersonEntry person,
    bool isDark,
  ) {
    final targets = _parseTargets(person.contactRestrictions);
    final completedCount = targets
        .where((t) => t['isCompleted'] == true)
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Alvos & Tarefas Espirituais',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$completedCount de ${targets.length} concluído(s)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add_task, size: 18),
                label: const Text('+ Novo Alvo'),
                onPressed: () =>
                    _showAddOrEditTargetDialog(context, repo, person),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tarefas Formais Integradas (Módulo B)
          StreamBuilder<List<TaskEntry>>(
            stream: ref
                .watch(taskManagerProvider)
                .watchTasksForPerson(person.id),
            builder: (ctx, snap) {
              final tasks = snap.data ?? [];
              if (tasks.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tarefas Vinculadas a este Contato',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  ...tasks.map(
                    (task) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: CheckboxListTile(
                        value: task.status == 'completed',
                        activeColor: AppTheme.primaryBlue,
                        onChanged: (val) => ref
                            .read(taskManagerProvider)
                            .toggleTaskComplete(task.id, completed: val),
                        title: Text(
                          task.title,
                          style: TextStyle(
                            decoration: task.status == 'completed'
                                ? TextDecoration.lineThrough
                                : null,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: task.dueDate != null
                            ? Text('Vencimento: //')
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 10),
                ],
              );
            },
          ),

          if (targets.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.track_changes,
                        size: 56,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Nenhum alvo ou tarefa espiritual definido para ${person.name}.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Defina alvos espirituais para a pessoa cumprir até a próxima visita (ex: ler um capítulo da Bíblia, baixar o JW Library, assistir ao vídeo da lição).',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('+ Cadastrar Primeiro Alvo'),
                        onPressed: () =>
                            _showAddOrEditTargetDialog(context, repo, person),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Column(
              children: targets.asMap().entries.map((entry) {
                final idx = entry.key;
                final target = entry.value;
                final isCompleted = target['isCompleted'] == true;
                final title = target['title'] ?? '';
                final createdAt = DateTime.tryParse(target['createdAt'] ?? '');
                final completedAt = target['completedAt'] != null
                    ? DateTime.tryParse(target['completedAt'])
                    : null;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final updated = List<Map<String, dynamic>>.from(targets);
                      final nextCompleted = !isCompleted;
                      updated[idx] = {
                        ...target,
                        'isCompleted': nextCompleted,
                        'completedAt': nextCompleted
                            ? DateTime.now().toIso8601String()
                            : null,
                      };
                      await _saveTargets(repo, person, updated);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: isCompleted,
                            activeColor: const Color(0xFF059669),
                            onChanged: (val) async {
                              final updated = List<Map<String, dynamic>>.from(
                                targets,
                              );
                              final nextCompleted = val ?? false;
                              updated[idx] = {
                                ...target,
                                'isCompleted': nextCompleted,
                                'completedAt': nextCompleted
                                    ? DateTime.now().toIso8601String()
                                    : null,
                              };
                              await _saveTargets(repo, person, updated);
                            },
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      decoration: isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: isCompleted
                                          ? (isDark
                                                ? const Color(0xFF94A3B8)
                                                : Colors.grey.shade600)
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.schedule,
                                        size: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        createdAt != null
                                            ? 'Criado em: ${AppDateUtils.formatDateTimeWithAt(createdAt)}'
                                            : 'Criado em: data não disponível',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isCompleted) ...[
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle,
                                          size: 12,
                                          color: Color(0xFF059669),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          completedAt != null
                                              ? 'Concluído em: ${AppDateUtils.formatDateTimeWithAt(completedAt)}'
                                              : 'Concluído (data não informada)',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF059669),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: 'Editar',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _showAddOrEditTargetDialog(
                              context,
                              repo,
                              person,
                              target,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: AppTheme.alertRed,
                            ),
                            tooltip: 'Excluir',
                            visualDensity: VisualDensity.compact,
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text('Excluir Alvo'),
                                  content: const Text(
                                    'Tem certeza que deseja excluir este alvo espiritual?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.alertRed,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('Excluir'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                final updated = targets
                                    .where((t) => t['id'] != target['id'])
                                    .toList();
                                await _saveTargets(repo, person, updated);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildProximityAlertsSection(
    BuildContext context,
    PersonEntry person,
    WidgetRef ref,
    bool isDark,
  ) {
    if (person.latitude == null || person.longitude == null) {
      return const SizedBox.shrink();
    }

    final allPeople = ref.watch(peopleStreamProvider).value ?? [];
    final nearby = <({PersonEntry contact, double distanceKm, bool isEnded})>[];

    for (final other in allPeople) {
      if (other.id == person.id || other.deletedAt != null) continue;
      if (other.latitude == null || other.longitude == null) continue;

      final distKm = GeolocationHelper.calculateHaversineDistanceKm(
        person.latitude!,
        person.longitude!,
        other.latitude!,
        other.longitude!,
      );

      if (distKm <= 1.2) {
        final isEnded =
            other.status == 'revisita_encerrada' || other.status == 'encerrado';
        nearby.add((contact: other, distanceKm: distKm, isEnded: isEnded));
      }
    }

    if (nearby.isEmpty) return const SizedBox.shrink();
    nearby.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    return Card(
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0FDF4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.accentTeal.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.near_me, color: AppTheme.accentTeal, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Alerta de Proximidade: Vizinhos Próximos (< 1.2 km)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppTheme.accentTeal,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${nearby.length} contato(s)',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentTeal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Aproveite a visita a este contato para revisitar ou reativar contatos vizinhos:',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 10),
            Column(
              children: nearby.take(4).map((item) {
                final c = item.contact;
                final distMeters = (item.distanceKm * 1000).toStringAsFixed(0);
                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PersonDetailScreen(personId: c.id),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          item.isEnded
                              ? Icons.replay_outlined
                              : Icons.location_on,
                          size: 16,
                          color: item.isEnded
                              ? Colors.orange
                              : AppTheme.primaryBlue,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              if (c.address != null && c.address!.isNotEmpty)
                                Text(
                                  c.address!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (item.isEnded)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Reativar?',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ),
                        Text(
                          '~${distMeters}m',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accentTeal,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpiritualTimelineCard(
    BuildContext context,
    PersonEntry person,
    BibleStudyEntry study,
    AppRepository repo,
    bool isDark,
  ) {
    final List<String> completedGoals = [];
    if (person.contactRestrictions != null &&
        person.contactRestrictions!.isNotEmpty) {
      try {
        final decoded = jsonDecode(person.contactRestrictions!);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map &&
                item['isCompleted'] == true &&
                item['title'] != null) {
              completedGoals.add(item['title'].toString());
            }
          }
        }
      } catch (e, st) {
        AppLogger.debug('Falha ao ler alvos concluídos (${person.id}): $e', st);
      }
    }

    final currentLesson = study.currentLesson ?? 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.timeline,
                    color: Color(0xFFD97706),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Linha do Tempo Espiritual do Estudante',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 14),

            PersonTimelineStep(
              icon: Icons.person_add_outlined,
              iconColor: AppTheme.primaryBlue,
              title: 'Primeiro Contato Registrado',
              date: AppDateUtils.formatDate(person.createdAt),
              subtitle: 'Início das conversas no ministério de campo',
              isCompleted: true,
            ),

            PersonTimelineStep(
              icon: Icons.menu_book,
              iconColor: currentLesson >= 1
                  ? const Color(0xFF0284C7)
                  : Colors.grey,
              title: 'Brochura Inicial (Lições 01 a 03)',
              date: currentLesson > 3
                  ? 'Concluída'
                  : (currentLesson >= 1
                        ? 'Em andamento (Lição $currentLesson)'
                        : 'Início'),
              subtitle: 'Brochura "Seja Feliz para Sempre!": 3 lições introdutórias da Bíblia',
              isCompleted: currentLesson >= 3,
            ),

            PersonTimelineStep(
              icon: Icons.handshake_outlined,
              iconColor: currentLesson >= 4
                  ? AppTheme.successGreen
                  : (currentLesson == 3 ? AppTheme.alertAmber : Colors.grey),
              title: 'Aceitou Continuar com o Livro Completo',
              date: currentLesson >= 4
                  ? 'Recebeu o livro (Lição 4+)'
                  : (currentLesson == 3
                        ? 'Consideração da Lição 3'
                        : 'Pendente'),
              subtitle: currentLesson >= 4
                  ? 'Estudante aceitou o curso completo e recebeu o livro "Seja Feliz para Sempre!"'
                  : 'No final da lição 3: Consideração sobre continuar no livro a partir da Lição 4',
              isCompleted: currentLesson >= 4,
            ),

            PersonTimelineStep(
              icon: Icons.auto_stories,
              iconColor: const Color(0xFF7C3AED),
              title: 'Curso Completo no Livro',
              date: currentLesson >= 4 ? 'Em andamento' : 'Aguardando Lição 4',
              subtitle:
                  'Publicação: Livro "Seja Feliz para Sempre!" (60 lições)',
              isCompleted: currentLesson >= 4,
            ),

            PersonTimelineStep(
              icon: Icons.military_tech_outlined,
              iconColor: currentLesson >= 12
                  ? AppTheme.successGreen
                  : Colors.grey,
              title: 'Marco 1: Conclusão da Seção 1 (Lições 01 a 12)',
              date: currentLesson >= 12 ? 'Concluída' : 'Em andamento',
              subtitle: 'Fundamentos da Bíblia e aproximação de Deus',
              isCompleted: currentLesson >= 12,
            ),

            PersonTimelineStep(
              icon: Icons.verified_outlined,
              iconColor: currentLesson >= 33
                  ? AppTheme.successGreen
                  : Colors.grey,
              title: 'Marco 2: Conclusão da Seção 2 (Lições 13 a 33)',
              date: currentLesson >= 33
                  ? 'Concluída'
                  : (currentLesson >= 12 ? 'Em andamento' : 'Pendente'),
              subtitle: 'O Reino de Deus e a vida de Jesus Cristo',
              isCompleted: currentLesson >= 33,
            ),

            PersonTimelineStep(
              icon: Icons.shield_outlined,
              iconColor: currentLesson >= 47
                  ? AppTheme.successGreen
                  : Colors.grey,
              title: 'Marco 3: Conclusão da Seção 3 (Lições 34 a 47)',
              date: currentLesson >= 47
                  ? 'Concluída'
                  : (currentLesson >= 33 ? 'Em andamento' : 'Pendente'),
              subtitle: 'Aplicação das leis divinas, conduta moral e dedicação a Deus',
              isCompleted: currentLesson >= 47,
            ),

            PersonTimelineStep(
              icon: Icons.flag_outlined,
              iconColor: currentLesson >= 60
                  ? AppTheme.successGreen
                  : Colors.grey,
              title: 'Marco 4: Conclusão da Seção 4 (Lições 48 a 60)',
              date: currentLesson >= 60
                  ? 'Concluída'
                  : (currentLesson >= 47 ? 'Em andamento' : 'Pendente'),
              subtitle: 'Amizades, congregação, perseverança e amizade eterna com Jeová',
              isCompleted: currentLesson >= 60,
            ),

            if (completedGoals.isNotEmpty)
              for (final goal in completedGoals)
                PersonTimelineStep(
                  icon: Icons.check_circle,
                  iconColor: AppTheme.successGreen,
                  title: 'Alvo Espiritual Cumprido',
                  date: 'Alcançado',
                  subtitle: goal,
                  isCompleted: true,
                ),

            PersonTimelineStep(
              icon: Icons.workspace_premium,
              iconColor: currentLesson >= 60
                  ? AppTheme.successGreen
                  : Colors.grey,
              title: 'Alvo Final: Conclusão do Livro "Seja Feliz Para Sempre!"',
              date: currentLesson >= 60 ? '🎉 Livro Concluído!' : 'Alvo Final',
              subtitle:
                  'Preparo espiritual completo para continuar crescendo na fé',
              isCompleted: currentLesson >= 60,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}
