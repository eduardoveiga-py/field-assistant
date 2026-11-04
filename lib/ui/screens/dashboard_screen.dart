import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/dashboard_metrics/attention_items_card.dart';
import '../widgets/dashboard_metrics/conversion_funnel_card.dart';
import '../widgets/dashboard_metrics/ended_studies_reasons_card.dart';
import '../widgets/dashboard_metrics/ended_visits_reasons_card.dart';
import '../widgets/dashboard_metrics/modality_distribution_chart.dart';
import '../widgets/dashboard_metrics/official_report_card.dart';
import '../widgets/dashboard_metrics/personal_hour_goal_card.dart';
import '../widgets/dashboard_metrics/scheduled_vs_actual_hours_card.dart';
import '../widgets/dashboard_metrics/service_year_bar_chart.dart';
import '../widgets/dashboard_metrics/study_attendance_metrics_card.dart';
import '../widgets/dashboard_metrics/study_metrics_overview_card.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../database/app_database.dart';
import '../../dashboard/counting_rules.dart';
import '../../reports/report_export_service.dart';
import '../providers.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  int _personalHourGoal = 50; // Meta padrão: 50h (Pioneiro Regular)
  String _statsPeriodMode = 'Mês Vigente'; // 'Mês Vigente', 'Ano de Serviço'

  DateTime get _periodStart {
    if (_statsPeriodMode == 'Ano de Serviço') {
      final sy = _getServiceYear(_selectedMonth);
      return DateTime(sy - 1, 9, 1);
    }
    return DateTime(_selectedMonth.year, _selectedMonth.month, 1);
  }

  DateTime get _periodEnd {
    if (_statsPeriodMode == 'Ano de Serviço') {
      final sy = _getServiceYear(_selectedMonth);
      return DateTime(sy, 8, 31, 23, 59, 59);
    }
    return DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
      23,
      59,
      59,
    );
  }

  // Determina o ano de serviço de uma data (inicia em 1º de Setembro e vai até 31 de Agosto)
  int _getServiceYear(DateTime date) {
    return date.month >= 9 ? date.year + 1 : date.year;
  }

  void _showAddActivityDialog(BuildContext context) {
    final hoursController = TextEditingController(text: '1');
    final minutesController = TextEditingController(text: '30');
    final placementsController = TextEditingController(text: '0');
    final videosController = TextEditingController(text: '0');
    final notesController = TextEditingController();
    String selectedModality = 'campo';
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.add_task, color: AppTheme.primaryBlue),
              SizedBox(width: 8),
              Text('Lançar Atividade de Campo'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.date_range, size: 16),
                      label: Text(AppDateUtils.formatDate(selectedDate)),
                      onPressed: () async {
                        final p = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(
                            const Duration(days: 30),
                          ),
                        );
                        if (p != null) setDialogState(() => selectedDate = p);
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedModality,
                        decoration: const InputDecoration(
                          labelText: 'Modalidade',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'campo',
                            child: Text('De Casa em Casa'),
                          ),
                          DropdownMenuItem(
                            value: 'testemunho_publico',
                            child: Text('Carrinho / Público'),
                          ),
                          DropdownMenuItem(
                            value: 'informal',
                            child: Text('Informal'),
                          ),
                          DropdownMenuItem(
                            value: 'carta_telefone',
                            child: Text('Cartas / Telefone'),
                          ),
                          DropdownMenuItem(
                            value: 'outro',
                            child: Text('Outro'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedModality = val);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tempo Dedicado:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: hoursController,
                        decoration: const InputDecoration(
                          labelText: 'Horas',
                          suffixText: 'h',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: minutesController,
                        decoration: const InputDecoration(
                          labelText: 'Minutos',
                          suffixText: 'min',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Resultados do Ministério (Witness Work):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: placementsController,
                        decoration: const InputDecoration(
                          labelText: 'Publicações',
                          hintText: '0',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: videosController,
                        decoration: const InputDecoration(
                          labelText: 'Vídeos Mostrados',
                          hintText: '0',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Observações / Ponto de pregação',
                    hintText: 'Ex: Trabalho com cartões de contato no centro comercial',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final h = int.tryParse(hoursController.text.trim()) ?? 0;
                final m = int.tryParse(minutesController.text.trim()) ?? 0;
                final totalSeconds = (h * 3600) + (m * 60);

                if (totalSeconds <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Informe ao menos alguns minutos de atividade.',
                      ),
                    ),
                  );
                  return;
                }

                final placements =
                    int.tryParse(placementsController.text.trim()) ?? 0;
                final videos = int.tryParse(videosController.text.trim()) ?? 0;

                final formattedNotes = DashboardCalculator.formatActivityNotes(
                  userNotes: notesController.text.trim().isEmpty
                      ? null
                      : notesController.text.trim(),
                  placements: placements,
                  videos: videos,
                );

                final repo = ref.read(repositoryProvider);
                await repo.createActivityRecord(
                  date: selectedDate,
                  durationSeconds: totalSeconds,
                  modality: selectedModality,
                  notes: formattedNotes,
                );

                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Atividade de campo registrada com sucesso!',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Salvar Atividade'),
            ),
          ],
        ),
      ),
    );
  }

  void _shareMinistryReport({
    required DashboardMetrics metrics,
    required int month,
    required int year,
    required double scheduledHours,
    required double actualHours,
    required List<ActivityRecordEntry> activities,
    required List<BibleStudyEntry> studies,
  }) {
    final monthName = _getMonthName(month);
    final hoursFormatted = AppDateUtils.formatDuration(
      metrics.totalActivitySeconds,
    );

    final header = _statsPeriodMode == 'Ano de Serviço'
        ? '📋 Relatório do Ano de Serviço ${_getServiceYear(_selectedMonth)} (01/09 a 31/08)'
        : '📋 Relatório de Serviço de Campo - $monthName de $year';
    final scheduledFormatted = AppDateUtils.formatDuration(
      (scheduledHours * 3600).round(),
    );

    final reportText =
        '''
$header
⏱️ Horas Realizadas: $hoursFormatted
📅 Horas Programadas (Agenda): $scheduledFormatted
📖 Estudos Bíblicos: ${metrics.activeStudiesCount}
👥 Assistência aos Estudos: ${metrics.totalStudyAttendance} (Média: ${metrics.averageAttendancePerStudy} por estudo)
🔄 Revisitas Feitas: ${metrics.heldVisitsCount}
📦 Publicações Colocadas: ${metrics.totalPlacements}
🎬 Vídeos Mostrados: ${metrics.totalVideos}
''';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDarkModal = Theme.of(ctx).brightness == Brightness.dark;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Compartilhar Relatório',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDarkModal
                          ? const Color(0xFF1E293B)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDarkModal
                            ? Colors.white12
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: SelectableText(
                      reportText,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        fontFamily: 'monospace',
                        color: isDarkModal
                            ? const Color(0xFFF1F5F9)
                            : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                          ),
                          icon: const Icon(Icons.chat, size: 18),
                          label: const Text('WhatsApp'),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final encoded = Uri.encodeComponent(reportText);
                            final uri = Uri.parse(
                              'https://wa.me/?text=$encoded',
                            );
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('Copiar'),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: reportText));
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Relatório copiado para a área de transferência!',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: const Text('Exportar Relatório em PDF'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        ReportExportService.exportMinistryStatisticsPdf(
                          context: context,
                          metrics: metrics,
                          activities: activities,
                          studies: studies,
                          period: _selectedMonth,
                          periodMode: _statsPeriodMode,
                          scheduledHours: scheduledHours,
                          actualHours: actualHours,
                          personalGoalHours: _personalHourGoal,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showRecordsModal({
    required BuildContext context,
    required String title,
    required List<Widget> children,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              if (children.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'Nenhum registro encontrado para este indicador.',
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.darkTextMuted
                            : AppTheme.textMuted,
                      ),
                    ),
                  ),
                )
              else
                Flexible(child: ListView(shrinkWrap: true, children: children)),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final studies = ref.watch(studiesStreamProvider).value ?? [];
    final people = ref.watch(peopleStreamProvider).value ?? [];
    final appointments = ref.watch(appointmentsStreamProvider).value ?? [];
    final activities = ref.watch(activitiesStreamProvider).value ?? [];
    final repo = ref.watch(repositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estatísticas do Ministério'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_task),
            tooltip: 'Lançar Atividade de Campo',
            onPressed: () => _showAddActivityDialog(context),
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([
          repo.getAllSessions(),
          repo.getAllVisits(),
          repo.db.select(repo.db.studyParticipants).get(),
        ]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final sessions = snapshot.data![0] as List<StudySessionEntry>;
          final visits = snapshot.data![1] as List<VisitEntry>;
          final participants = snapshot.data![2] as List<StudyParticipantEntry>;

          final metrics = DashboardCalculator.calculate(
            studies: studies,
            sessions: sessions,
            visits: visits,
            appointments: appointments,
            activities: activities,
            people: people,
            participants: participants,
            periodStart: _periodStart,
            periodEnd: _periodEnd,
          );

          final attentionItems = DashboardCalculator.getAttentionItems(
            people: people,
            studies: studies,
            participants: participants,
            appointments: appointments,
          );

          // Cálculos de Horas Programadas vs Efetivas
          final scheduledAppts = appointments
              .where(
                (a) =>
                    a.deletedAt == null &&
                    a.status != 'cancelado' &&
                    a.status != 'reagendado' &&
                    a.startTime.isAfter(
                      _periodStart.subtract(const Duration(seconds: 1)),
                    ) &&
                    a.startTime.isBefore(
                      _periodEnd.add(const Duration(seconds: 1)),
                    ),
              )
              .toList();
          final scheduledTotalMinutes = scheduledAppts.fold(0, (acc, a) {
            final dur = a.durationMinutes > 0
                ? a.durationMinutes
                : a.endTime.difference(a.startTime).inMinutes;
            return acc + (dur > 0 ? dur : 30);
          });
          final scheduledHours = scheduledTotalMinutes / 60.0;
          final actualHours = metrics.totalActivitySeconds / 3600.0;

          // Cálculos da Meta Pessoal (Witness Work Style)
          final isYearMode = _statsPeriodMode == 'Ano de Serviço';
          final effectiveHourGoal = isYearMode
              ? _personalHourGoal * 12
              : _personalHourGoal;
          final totalHoursDone = actualHours;
          final progressPercent = effectiveHourGoal > 0
              ? (totalHoursDone / effectiveHourGoal).clamp(0.0, 1.0)
              : 0.0;
          final remainingHours = (effectiveHourGoal - totalHoursDone).clamp(
            0.0,
            effectiveHourGoal.toDouble(),
          );

          final now = DateTime.now();
          final int daysRemaining;
          if (isYearMode) {
            final sy = _getServiceYear(_selectedMonth);
            final syEnd = DateTime(sy, 8, 31);
            daysRemaining = now.isBefore(syEnd)
                ? syEnd.difference(now).inDays + 1
                : 1;
          } else {
            final daysInMonth = DateTime(
              _selectedMonth.year,
              _selectedMonth.month + 1,
              0,
            ).day;
            daysRemaining =
                _selectedMonth.month == now.month &&
                    _selectedMonth.year == now.year
                ? (daysInMonth - now.day + 1).clamp(1, daysInMonth)
                : daysInMonth;
          }
          final dailyHoursNeeded =
              remainingHours / (daysRemaining > 0 ? daysRemaining : 1);
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final headingColor = isDark
              ? AppTheme.darkTextPrimary
              : AppTheme.textDark;
          final bodyColor = isDark
              ? AppTheme.darkTextPrimary
              : AppTheme.textDark;
          final mutedColor = isDark
              ? AppTheme.darkTextMuted
              : AppTheme.textMuted;
          final dividerColor = isDark ? Colors.white12 : Colors.grey.shade300;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Barra de período e seleção de Mês vs Ano de Serviço
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chevron_left),
                                  onPressed: () {
                                    setState(() {
                                      _selectedMonth = DateTime(
                                        _selectedMonth.year,
                                        _selectedMonth.month - 1,
                                        1,
                                      );
                                    });
                                  },
                                ),
                                const Icon(
                                  Icons.calendar_month,
                                  color: AppTheme.primaryBlue,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${_getMonthName(_selectedMonth.month)} ${_selectedMonth.year}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right),
                                  onPressed: () {
                                    setState(() {
                                      _selectedMonth = DateTime(
                                        _selectedMonth.year,
                                        _selectedMonth.month + 1,
                                        1,
                                      );
                                    });
                                  },
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedMonth = DateTime(
                                    DateTime.now().year,
                                    DateTime.now().month,
                                    1,
                                  );
                                });
                              },
                              child: const Text('Mês Atual'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'Mês Vigente',
                              label: Text('Mês Vigente'),
                            ),
                            ButtonSegment(
                              value: 'Ano de Serviço',
                              label: Text('Ano de Serviço (01/09-31/08)'),
                            ),
                          ],
                          selected: {_statsPeriodMode},
                          onSelectionChanged: (val) {
                            setState(() => _statsPeriodMode = val.first);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Seção 1: Formulário Oficial do Relatório de Campo (Witness Work Style)
                OfficialReportCard(
                  metrics: metrics,
                  headingColor: headingColor,
                  dividerColor: dividerColor,
                  onExportPdf: () {
                    final activeStudiesForPeriod = studies.where((s) {
                      if (s.deletedAt != null) return false;
                      final hasSession =
                          sessions.any(
                            (sess) =>
                                sess.studyId == s.id &&
                                sess.status == 'realizada' &&
                                sess.deletedAt == null &&
                                sess.dateTimeField.isAfter(
                                  _periodStart.subtract(
                                    const Duration(seconds: 1),
                                  ),
                                ) &&
                                sess.dateTimeField.isBefore(
                                  _periodEnd.add(
                                    const Duration(seconds: 1),
                                  ),
                                ),
                          ) ||
                          (s.lastSessionAt != null &&
                              !s.lastSessionAt!.isBefore(_periodStart) &&
                              !s.lastSessionAt!.isAfter(_periodEnd));
                      if (hasSession) return true;
                      if (s.status != 'ativo') return false;
                      if (s.startedAt.isAfter(_periodEnd)) return false;
                      return true;
                    }).toList();

                    ReportExportService.exportMinistryStatisticsPdf(
                      context: context,
                      metrics: metrics,
                      activities: activities,
                      studies: activeStudiesForPeriod,
                      period: _selectedMonth,
                      periodMode: _statsPeriodMode,
                      scheduledHours: scheduledHours,
                      actualHours: actualHours,
                      personalGoalHours: _personalHourGoal,
                    );
                  },
                  onShare: () {
                    final activeStudiesForPeriod = studies.where((s) {
                      if (s.deletedAt != null) return false;
                      final hasSession =
                          sessions.any(
                            (sess) =>
                                sess.studyId == s.id &&
                                sess.status == 'realizada' &&
                                sess.deletedAt == null &&
                                sess.dateTimeField.isAfter(
                                  _periodStart.subtract(
                                    const Duration(seconds: 1),
                                  ),
                                ) &&
                                sess.dateTimeField.isBefore(
                                  _periodEnd.add(
                                    const Duration(seconds: 1),
                                  ),
                                ),
                          ) ||
                          (s.lastSessionAt != null &&
                              !s.lastSessionAt!.isBefore(_periodStart) &&
                              !s.lastSessionAt!.isAfter(_periodEnd));
                      if (hasSession) return true;
                      if (s.status != 'ativo') return false;
                      if (s.startedAt.isAfter(_periodEnd)) return false;
                      return true;
                    }).toList();

                    _shareMinistryReport(
                      metrics: metrics,
                      month: _selectedMonth.month,
                      year: _selectedMonth.year,
                      scheduledHours: scheduledHours,
                      actualHours: actualHours,
                      activities: activities,
                      studies: activeStudiesForPeriod,
                    );
                  },
                  onShowHoursRecords: () {
                    final acts = activities
                        .where(
                          (a) =>
                              a.deletedAt == null &&
                              a.date.isAfter(
                                _periodStart.subtract(
                                  const Duration(seconds: 1),
                                ),
                              ) &&
                              a.date.isBefore(
                                _periodEnd.add(const Duration(seconds: 1)),
                              ),
                        )
                        .toList();
                    _showRecordsModal(
                      context: context,
                      title: 'Lançamentos de Horas (${acts.length})',
                      children: acts
                          .map(
                            (a) => ListTile(
                              leading: const Icon(
                                Icons.access_time,
                                color: AppTheme.primaryBlue,
                              ),
                              title: Text(
                                '${(a.durationSeconds / 3600).toStringAsFixed(1)}h • ${a.modality}',
                              ),
                              subtitle: Text(AppDateUtils.formatDate(a.date)),
                            ),
                          )
                          .toList(),
                    );
                  },
                  onShowStudiesRecords: () {
                    final active = studies.where((s) {
                      if (s.deletedAt != null) return false;
                      final hasSessionInPeriod =
                          sessions.any(
                            (sess) =>
                                sess.studyId == s.id &&
                                sess.status == 'realizada' &&
                                sess.deletedAt == null &&
                                sess.dateTimeField.isAfter(
                                  _periodStart.subtract(
                                    const Duration(seconds: 1),
                                  ),
                                ) &&
                                sess.dateTimeField.isBefore(
                                  _periodEnd.add(const Duration(seconds: 1)),
                                ),
                          ) ||
                          (s.lastSessionAt != null &&
                              !s.lastSessionAt!.isBefore(_periodStart) &&
                              !s.lastSessionAt!.isAfter(_periodEnd));
                      if (hasSessionInPeriod) return true;
                      if (s.status != 'ativo') return false;
                      if (s.startedAt.isAfter(_periodEnd)) return false;
                      return true;
                    }).toList();
                    _showRecordsModal(
                      context: context,
                      title: 'Estudos Bíblicos no Período (${active.length})',
                      children: active
                          .map(
                            (s) => ListTile(
                              leading: const Icon(
                                Icons.menu_book,
                                color: Color(0xFF7C3AED),
                              ),
                              title: Text(
                                s.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'Lição atual: ${s.currentLesson ?? "1"} • Início: ${AppDateUtils.formatDate(s.startedAt)} • ${s.frequency.toUpperCase()}',
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                  onShowVisitsRecords: () {
                    final held = visits
                        .where(
                          (v) =>
                              v.deletedAt == null &&
                              v.contactType != 'tentativa_sem_contato' &&
                              v.dateTimeField.isAfter(
                                _periodStart.subtract(
                                  const Duration(seconds: 1),
                                ),
                              ) &&
                              v.dateTimeField.isBefore(
                                _periodEnd.add(const Duration(seconds: 1)),
                              ),
                        )
                        .toList();
                    final visitedPersonIds = held.map((v) => v.personId).toSet();
                    final onboardedRevisits = people.where((p) {
                      if (p.deletedAt != null) return false;
                      if (visitedPersonIds.contains(p.id)) return false;
                      if (p.lastContactAt == null) return false;
                      if (p.lastContactAt!.isBefore(_periodStart) ||
                          p.lastContactAt!.isAfter(_periodEnd)) {
                        return false;
                      }
                      return p.status.toLowerCase() == 'revisita' ||
                          p.lastContactAt!.isAfter(p.firstContactAt);
                    }).toList();

                    final allModalItems = <Widget>[
                      ...held.map(
                        (v) => ListTile(
                          leading: const Icon(
                            Icons.repeat,
                            color: AppTheme.accentTeal,
                          ),
                          title: Text(
                            v.topicsDiscussed ?? 'Revisita considerada',
                          ),
                          subtitle: Text(
                            AppDateUtils.formatDateTime(v.dateTimeField),
                          ),
                        ),
                      ),
                      ...onboardedRevisits.map(
                        (p) => ListTile(
                          leading: const Icon(
                            Icons.person_pin_circle_outlined,
                            color: AppTheme.accentTeal,
                          ),
                          title: Text(
                            'Revisita: ${p.name}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'Última visita registrada em: ${AppDateUtils.formatDate(p.lastContactAt!)}',
                          ),
                        ),
                      ),
                    ];

                    _showRecordsModal(
                      context: context,
                      title: 'Revisitas do Mês (${allModalItems.length})',
                      children: allModalItems,
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Seção: Programação de Campo (Horas Programadas vs Horas Efetivas Realizadas)
                ScheduledVsActualHoursCard(
                  scheduledHours: scheduledHours,
                  actualHours: actualHours,
                  headingColor: headingColor,
                  bodyColor: bodyColor,
                  mutedColor: mutedColor,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),

                // Seção: Contagem & Média de Assistência aos Estudos Bíblicos
                StudyAttendanceMetricsCard(
                  metrics: metrics,
                  headingColor: headingColor,
                  bodyColor: bodyColor,
                  mutedColor: mutedColor,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),

                // Seção: Métricas dos Estudos Bíblicos & Revisitas
                StudyMetricsOverviewCard(
                  metrics: metrics,
                  headingColor: headingColor,
                  bodyColor: bodyColor,
                  mutedColor: mutedColor,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),

                // Seção: Funil de Conversão do Ministério
                ConversionFunnelCard(
                  metrics: metrics,
                  headingColor: headingColor,
                  bodyColor: bodyColor,
                  mutedColor: mutedColor,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),

                // Seção: Motivos de Encerramento de Estudos Bíblicos
                EndedStudiesReasonsCard(
                  metrics: metrics,
                  headingColor: headingColor,
                  bodyColor: bodyColor,
                  mutedColor: mutedColor,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),

                // Seção: Motivos de Encerramento de Revisitas
                EndedVisitsReasonsCard(
                  metrics: metrics,
                  headingColor: headingColor,
                  bodyColor: bodyColor,
                  mutedColor: mutedColor,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),

                // Seção 3: Meta Pessoal de Horas & Progresso Diário (Witness Work)
                PersonalHourGoalCard(
                  progressPercent: progressPercent,
                  totalHoursDone: totalHoursDone,
                  effectiveHourGoal: effectiveHourGoal.toDouble(),
                  remainingHours: remainingHours,
                  dailyHoursNeeded: dailyHoursNeeded,
                  daysRemaining: daysRemaining,
                  isYearMode: isYearMode,
                  personalHourGoal: _personalHourGoal,
                  onGoalChanged: (val) => setState(() => _personalHourGoal = val),
                  headingColor: headingColor,
                  bodyColor: bodyColor,
                  mutedColor: mutedColor,
                  dividerColor: dividerColor,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),

                // Seção 4: Gráfico e Histórico do Ano de Serviço (01/09 a 31/08)
                Text(
                  _statsPeriodMode == 'Ano de Serviço'
                      ? 'Ano de Serviço ${_getServiceYear(_selectedMonth)} (01/09 a 31/08)'
                      : 'Comparativo Mensal',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: headingColor,
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Horas Mês a Mês no Ano de Serviço',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 160,
                          child: ServiceYearBarChart(
                            activities: activities,
                            referenceDate: _selectedMonth,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Seção: Gráfico Colorido de Tempo por Modalidade
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.pie_chart,
                                  color: AppTheme.accentTeal,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Tempo por Modalidade de Pregação',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              _getMonthName(_selectedMonth.month),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ModalityDistributionChart(
                          activities: activities,
                          periodStart: _periodStart,
                          periodEnd: _periodEnd,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Seção 5: Precisam de Atenção (Alertas Transparentes)
                AttentionItemsCard(
                  attentionItems: attentionItems,
                  headingColor: headingColor,
                  bodyColor: bodyColor,
                  mutedColor: mutedColor,
                  isDark: isDark,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    return months[month - 1];
  }
}
