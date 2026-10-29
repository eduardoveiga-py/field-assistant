import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../database/app_database.dart';
import '../../dashboard/counting_rules.dart';
import '../../reports/report_export_service.dart';
import '../providers.dart';
import 'person_detail_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
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
    return DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);
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
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                        );
                        if (p != null) setDialogState(() => selectedDate = p);
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedModality,
                        decoration: const InputDecoration(labelText: 'Modalidade'),
                        items: const [
                          DropdownMenuItem(value: 'campo', child: Text('De Casa em Casa')),
                          DropdownMenuItem(value: 'testemunho_publico', child: Text('Carrinho / Público')),
                          DropdownMenuItem(value: 'informal', child: Text('Informal')),
                          DropdownMenuItem(value: 'carta_telefone', child: Text('Cartas / Telefone')),
                          DropdownMenuItem(value: 'outro', child: Text('Outro')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedModality = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Tempo Dedicado:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: hoursController,
                        decoration: const InputDecoration(labelText: 'Horas', suffixText: 'h'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: minutesController,
                        decoration: const InputDecoration(labelText: 'Minutos', suffixText: 'min'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Resultados do Ministério (Witness Work):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: placementsController,
                        decoration: const InputDecoration(labelText: 'Publicações', hintText: '0'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: videosController,
                        decoration: const InputDecoration(labelText: 'Vídeos Mostrados', hintText: '0'),
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final h = int.tryParse(hoursController.text.trim()) ?? 0;
                final m = int.tryParse(minutesController.text.trim()) ?? 0;
                final totalSeconds = (h * 3600) + (m * 60);

                if (totalSeconds <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Informe ao menos alguns minutos de atividade.')),
                  );
                  return;
                }

                final placements = int.tryParse(placementsController.text.trim()) ?? 0;
                final videos = int.tryParse(videosController.text.trim()) ?? 0;

                final formattedNotes = DashboardCalculator.formatActivityNotes(
                  userNotes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
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
                    const SnackBar(content: Text('Atividade de campo registrada com sucesso!')),
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
    final hoursFormatted = AppDateUtils.formatDuration(metrics.totalActivitySeconds);

    final header = _statsPeriodMode == 'Ano de Serviço'
        ? '📋 Relatório do Ano de Serviço ${_getServiceYear(_selectedMonth)} (01/09 a 31/08)'
        : '📋 Relatório de Serviço de Campo - $monthName de $year';
    final scheduledFormatted = AppDateUtils.formatDuration((scheduledHours * 3600).round());

    final reportText = '''
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                      const Text('Compartilhar Relatório', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDarkModal ? const Color(0xFF1E293B) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDarkModal ? Colors.white12 : Colors.grey.shade300),
                    ),
                    child: SelectableText(
                      reportText,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        fontFamily: 'monospace',
                        color: isDarkModal ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                          icon: const Icon(Icons.chat, size: 18),
                          label: const Text('WhatsApp'),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final encoded = Uri.encodeComponent(reportText);
                            final uri = Uri.parse('https://wa.me/?text=$encoded');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
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
                              const SnackBar(content: Text('Relatório copiado para a área de transferência!')),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const Divider(),
            if (children.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(child: Text('Nenhum registro encontrado para este indicador.', style: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted))),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: children,
                ),
              ),
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
          final scheduledAppts = appointments.where((a) =>
              a.deletedAt == null &&
              a.status != 'cancelado' &&
              a.status != 'reagendado' &&
              a.startTime.isAfter(_periodStart.subtract(const Duration(seconds: 1))) &&
              a.startTime.isBefore(_periodEnd.add(const Duration(seconds: 1)))).toList();
          final scheduledTotalMinutes = scheduledAppts.fold(0, (acc, a) {
            final dur = a.durationMinutes > 0 ? a.durationMinutes : a.endTime.difference(a.startTime).inMinutes;
            return acc + (dur > 0 ? dur : 30);
          });
          final scheduledHours = scheduledTotalMinutes / 60.0;
          final actualHours = metrics.totalActivitySeconds / 3600.0;

          // Cálculos da Meta Pessoal (Witness Work Style)
          final isYearMode = _statsPeriodMode == 'Ano de Serviço';
          final effectiveHourGoal = isYearMode ? _personalHourGoal * 12 : _personalHourGoal;
          final totalHoursDone = actualHours;
          final progressPercent = effectiveHourGoal > 0 ? (totalHoursDone / effectiveHourGoal).clamp(0.0, 1.0) : 0.0;
          final remainingHours = (effectiveHourGoal - totalHoursDone).clamp(0.0, effectiveHourGoal.toDouble());

          final now = DateTime.now();
          final int daysRemaining;
          if (isYearMode) {
            final sy = _getServiceYear(_selectedMonth);
            final syEnd = DateTime(sy, 8, 31);
            daysRemaining = now.isBefore(syEnd) ? syEnd.difference(now).inDays + 1 : 1;
          } else {
            final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
            daysRemaining = _selectedMonth.month == now.month && _selectedMonth.year == now.year
                ? (daysInMonth - now.day + 1).clamp(1, daysInMonth)
                : daysInMonth;
          }
          final dailyHoursNeeded = remainingHours / (daysRemaining > 0 ? daysRemaining : 1);
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final headingColor = isDark ? AppTheme.darkTextPrimary : AppTheme.textDark;
          final bodyColor = isDark ? AppTheme.darkTextPrimary : AppTheme.textDark;
          final mutedColor = isDark ? AppTheme.darkTextMuted : AppTheme.textMuted;
          final dividerColor = isDark ? Colors.white12 : Colors.grey.shade300;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Barra de período e seleção de Mês vs Ano de Serviço
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
                                    });
                                  },
                                ),
                                const Icon(Icons.calendar_month, color: AppTheme.primaryBlue, size: 20),
                                const SizedBox(width: 6),
                                Text(
                                  '${_getMonthName(_selectedMonth.month)} ${_selectedMonth.year}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right),
                                  onPressed: () {
                                    setState(() {
                                      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
                                    });
                                  },
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
                                });
                              },
                              child: const Text('Mês Atual'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'Mês Vigente', label: Text('Mês Vigente')),
                            ButtonSegment(value: 'Ano de Serviço', label: Text('Ano de Serviço (01/09-31/08)')),
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 950;
                    final title = Text(
                      'Relatório Mensal de Campo',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: headingColor),
                    );
                    final buttons = Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: const Size(36, 36),
                          ),
                          icon: const Icon(Icons.picture_as_pdf, size: 16, color: Colors.red),
                          label: const Text('Exportar Relatório PDF', style: TextStyle(fontSize: 12)),
                          onPressed: () {
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
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: const Size(36, 36),
                          ),
                          icon: const Icon(Icons.share, size: 16),
                          label: const Text('Enviar Relatório', style: TextStyle(fontSize: 12)),
                          onPressed: () => _shareMinistryReport(
                            metrics: metrics,
                            month: _selectedMonth.month,
                            year: _selectedMonth.year,
                            scheduledHours: scheduledHours,
                            actualHours: actualHours,
                            activities: activities,
                            studies: studies,
                          ),
                        ),
                      ],
                    );

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          title,
                          const SizedBox(height: 8),
                          buttons,
                        ],
                      );
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        title,
                        Flexible(child: buttons),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),

                // Cartão estilo ficha de relatório com alto contraste
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _ReportCell(
                                label: 'HORAS',
                                value: AppDateUtils.formatDuration(metrics.totalActivitySeconds),
                                icon: Icons.access_time_filled,
                                color: const Color(0xFF0F172A),
                                onTap: () {
                                  final acts = activities.where((a) =>
                                      a.deletedAt == null &&
                                      a.date.isAfter(_periodStart.subtract(const Duration(seconds: 1))) &&
                                      a.date.isBefore(_periodEnd.add(const Duration(seconds: 1)))).toList();
                                  _showRecordsModal(
                                    context: context,
                                    title: 'Lançamentos de Horas (${acts.length})',
                                    children: acts.map((a) => ListTile(
                                      leading: const Icon(Icons.access_time, color: AppTheme.primaryBlue),
                                      title: Text('${(a.durationSeconds / 3600).toStringAsFixed(1)}h • ${a.modality}'),
                                      subtitle: Text(AppDateUtils.formatDate(a.date)),
                                    )).toList(),
                                  );
                                },
                              ),
                            ),
                            Container(width: 1, height: 60, color: dividerColor),
                            Expanded(
                              child: _ReportCell(
                                label: 'ESTUDOS',
                                value: '${metrics.activeStudiesCount}',
                                icon: Icons.menu_book,
                                color: const Color(0xFF7C3AED),
                                onTap: () {
                                  final active = studies.where((s) => s.status == 'ativo' && s.deletedAt == null).toList();
                                  _showRecordsModal(
                                    context: context,
                                    title: 'Estudos Bíblicos Ativos (${active.length})',
                                    children: active.map((s) => ListTile(
                                      leading: const Icon(Icons.menu_book, color: Color(0xFF7C3AED)),
                                      title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text('Lição atual: ${s.currentLesson ?? "1"} • Idioma: ${s.language.toUpperCase()}'),
                                    )).toList(),
                                  );
                                },
                              ),
                            ),
                            Container(width: 1, height: 60, color: dividerColor),
                            Expanded(
                              child: _ReportCell(
                                label: 'REVISITAS',
                                value: '${metrics.heldVisitsCount}',
                                icon: Icons.repeat,
                                color: AppTheme.accentTeal,
                                onTap: () {
                                  final held = visits.where((v) =>
                                      v.deletedAt == null &&
                                      v.contactType != 'tentativa_sem_contato' &&
                                      v.dateTimeField.isAfter(_periodStart.subtract(const Duration(seconds: 1))) &&
                                      v.dateTimeField.isBefore(_periodEnd.add(const Duration(seconds: 1)))).toList();
                                  _showRecordsModal(
                                    context: context,
                                    title: 'Revisitas do Mês (${held.length})',
                                    children: held.map((v) => ListTile(
                                      leading: const Icon(Icons.repeat, color: AppTheme.accentTeal),
                                      title: Text(v.topicsDiscussed ?? 'Revisita considerada'),
                                      subtitle: Text(AppDateUtils.formatDateTime(v.dateTimeField)),
                                    )).toList(),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: _ReportCell(
                                label: 'PUBLICAÇÕES',
                                value: '${metrics.totalPlacements}',
                                icon: Icons.auto_stories,
                                color: const Color(0xFF0284C7),
                              ),
                            ),
                            Container(width: 1, height: 60, color: dividerColor),
                            Expanded(
                              child: _ReportCell(
                                label: 'VÍDEOS',
                                value: '${metrics.totalVideos}',
                                icon: Icons.play_circle_fill,
                                color: const Color(0xFFDC2626),
                              ),
                            ),
                            Container(width: 1, height: 60, color: dividerColor),
                            Expanded(
                              child: _ReportCell(
                                label: 'SESSÕES DADAS',
                                value: '${metrics.heldSessionsCount}',
                                icon: Icons.school,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Seção: Programação de Campo (Horas Programadas vs Horas Efetivas Realizadas)
                Card(
                  elevation: 2,
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
                                Icon(Icons.av_timer, size: 20, color: AppTheme.primaryBlue),
                                SizedBox(width: 8),
                                Text(
                                  'Programação de Campo (Agenda)',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (scheduledHours > 0 && actualHours >= scheduledHours)
                                    ? AppTheme.successGreen.withValues(alpha: 0.15)
                                    : AppTheme.primaryBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                scheduledHours <= 0
                                    ? 'Sem agendamentos'
                                    : actualHours >= scheduledHours
                                        ? (((actualHours - scheduledHours) * 60).round() >= 1
                                            ? '100% cumprido (+${AppDateUtils.formatDuration(((actualHours - scheduledHours) * 3600).round())} adicionais)'
                                            : '100% cumprido')
                                        : '${((actualHours / scheduledHours) * 100).toStringAsFixed(0)}% cumprido',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: (scheduledHours > 0 && actualHours >= scheduledHours)
                                      ? AppTheme.successGreen
                                      : AppTheme.primaryBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Horas Programadas', style: TextStyle(fontSize: 11, color: mutedColor)),
                                  const SizedBox(height: 2),
                                  Text(
                                    AppDateUtils.formatDuration(scheduledTotalMinutes * 60),
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                                  ),
                                  Text('${scheduledAppts.length} agendamento(s)', style: TextStyle(fontSize: 11, color: mutedColor)),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 48, color: dividerColor),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Horas Efetivas Realizadas', style: TextStyle(fontSize: 11, color: mutedColor)),
                                  const SizedBox(height: 2),
                                  Text(
                                    AppDateUtils.formatDuration(metrics.totalActivitySeconds),
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.accentTeal),
                                  ),
                                  Text(
                                    actualHours >= scheduledHours
                                        ? (scheduledHours > 0
                                            ? '+${AppDateUtils.formatDuration(((actualHours - scheduledHours) * 3600).round())} acima do planejado'
                                            : 'Atividades registradas')
                                        : '${AppDateUtils.formatDuration(((scheduledHours - actualHours) * 3600).round())} para cumprir',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: actualHours >= scheduledHours ? AppTheme.successGreen : AppTheme.alertAmber,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (scheduledHours > 0) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: (actualHours / scheduledHours).clamp(0.0, 1.0),
                              minHeight: 8,
                              backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                actualHours >= scheduledHours ? AppTheme.successGreen : AppTheme.primaryBlue,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Seção 2: Contagem & Média de Assistência aos Estudos Bíblicos
                Text(
                  'Assistência aos Estudos Bíblicos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: headingColor),
                ),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.people_alt, size: 18, color: Color(0xFF7C3AED)),
                                        SizedBox(width: 6),
                                        Text('Total Assistência', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${metrics.totalStudyAttendance} pessoas',
                                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                                    ),
                                    Text('Presentes somados no mês', style: TextStyle(fontSize: 11, color: mutedColor)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentTeal.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.analytics, size: 18, color: AppTheme.accentTeal),
                                        SizedBox(width: 6),
                                        Text('Média por Estudo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accentTeal)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${metrics.averageAttendancePerStudy}',
                                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.accentTeal),
                                    ),
                                    Text('Assistência média/sessão', style: TextStyle(fontSize: 11, color: mutedColor)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (sessions.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Últimas sessões registradas com contagem de presentes:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                            ),
                          ),
                          const SizedBox(height: 6),
                          for (final s in sessions.take(3))
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Sessão em ${AppDateUtils.formatDate(s.dateTimeField)} (Lição ${s.lessonCovered ?? "—"})',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${DashboardCalculator.parseSessionAttendance(s)} presentes',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Seção: Métricas dos Estudos Bíblicos & Revisitas
                _buildStudyMetricsOverviewCard(metrics, headingColor, bodyColor, mutedColor, isDark),
                const SizedBox(height: 16),

                // Seção: Funil de Conversão do Ministério
                _buildConversionFunnelSection(metrics, headingColor, bodyColor, mutedColor, isDark),
                const SizedBox(height: 16),

                // Seção: Motivos de Encerramento de Estudos Bíblicos
                _buildEndedStudiesByReasonSection(metrics, headingColor, bodyColor, mutedColor, isDark),
                const SizedBox(height: 16),

                // Seção: Motivos de Encerramento de Revisitas
                _buildEndedVisitsByReasonSection(metrics, headingColor, bodyColor, mutedColor, isDark),
                const SizedBox(height: 16),

                // Seção 3: Meta Pessoal de Horas & Progresso Diário (Witness Work)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Meta Pessoal de Horas',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: headingColor),
                    ),
                    DropdownButton<int>(
                      value: [15, 30, 50, 100].contains(_personalHourGoal) ? _personalHourGoal : 50,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: 15, child: Text('Auxiliar (15h)')),
                        DropdownMenuItem(value: 30, child: Text('Auxiliar (30h)')),
                        DropdownMenuItem(value: 50, child: Text('Regular (50h)')),
                        DropdownMenuItem(value: 100, child: Text('Especial (100h)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _personalHourGoal = val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${totalHoursDone.toStringAsFixed(1)}h de $effectiveHourGoal h${isYearMode ? " (Ano)" : ""}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${(progressPercent * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progressPercent,
                            minHeight: 12,
                            backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progressPercent >= 1.0 ? AppTheme.successGreen : AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Restam para a meta', style: TextStyle(fontSize: 12, color: mutedColor)),
                                  Text(
                                    '${remainingHours.toStringAsFixed(1)}h',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: bodyColor),
                                  ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 35, color: dividerColor),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Média diária necessária', style: TextStyle(fontSize: 12, color: mutedColor)),
                                  Text(
                                    '${(dailyHoursNeeded * 60).round()} min/dia',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.accentTeal),
                                  ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 35, color: dividerColor),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Dias restantes', style: TextStyle(fontSize: 12, color: mutedColor)),
                                  Text(
                                    '$daysRemaining dias',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: bodyColor),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Seção 4: Gráfico e Histórico do Ano de Serviço (01/09 a 31/08)
                Text(
                  _statsPeriodMode == 'Ano de Serviço'
                      ? 'Ano de Serviço ${_getServiceYear(_selectedMonth)} (01/09 a 31/08)'
                      : 'Comparativo Mensal',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: headingColor),
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
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 160,
                          child: _buildServiceYearBarChart(activities, _selectedMonth),
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
                                Icon(Icons.pie_chart, color: AppTheme.accentTeal, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Tempo por Modalidade de Pregação',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ],
                            ),
                            Text(
                              _getMonthName(_selectedMonth.month),
                              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildModalityDistributionChart(activities, _periodStart, _periodEnd),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Seção 5: Precisam de Atenção (Alertas Transparentes)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Precisam de Atenção',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: headingColor),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: attentionItems.isNotEmpty ? AppTheme.alertRed.withValues(alpha: 0.1) : AppTheme.successGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${attentionItems.length} pendência(s)',
                        style: TextStyle(
                          color: attentionItems.isNotEmpty ? AppTheme.alertRed : AppTheme.successGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (attentionItems.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.verified, color: AppTheme.successGreen, size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Excelente! Nenhum contato ou estudo precisa de atenção imediata no momento.',
                              style: TextStyle(color: mutedColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    children: attentionItems.map((item) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getAttentionColor(item.category).withValues(alpha: 0.1),
                            child: Icon(_getAttentionIcon(item.category), color: _getAttentionColor(item.category)),
                          ),
                          title: Text(item.personName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(item.reason, style: TextStyle(fontSize: 12, color: bodyColor)),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => PersonDetailScreen(personId: item.personId)),
                            );
                          },
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildServiceYearBarChart(List<ActivityRecordEntry> activities, DateTime referenceDate) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Ano de serviço vai de Setembro a Agosto (12 meses)
    final serviceYear = _getServiceYear(referenceDate);
    final startYear = serviceYear - 1;

    // Meses do ano de serviço: 9, 10, 11, 12 do startYear, e 1..8 do serviceYear
    final List<Map<String, dynamic>> monthsData = [];
    final monthOrder = [9, 10, 11, 12, 1, 2, 3, 4, 5, 6, 7, 8];

    for (int i = 0; i < monthOrder.length; i++) {
      final m = monthOrder[i];
      final y = m >= 9 ? startYear : serviceYear;
      final mStart = DateTime(y, m, 1);
      final mEnd = DateTime(y, m + 1, 0, 23, 59, 59);

      int secs = 0;
      for (final a in activities) {
        if (a.deletedAt == null && a.date.isAfter(mStart.subtract(const Duration(seconds: 1))) && a.date.isBefore(mEnd.add(const Duration(seconds: 1)))) {
          secs += a.durationSeconds;
        }
      }

      monthsData.add({
        'month': m,
        'year': y,
        'label': _getMonthAbbr(m),
        'hours': secs / 3600.0,
      });
    }

    final maxHours = monthsData.map((d) => d['hours'] as double).fold<double>(0.0, (prev, val) => val > prev ? val : prev);
    final maxY = maxHours > 50 ? (maxHours * 1.2).ceilToDouble() : 60.0;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final d = monthsData[group.x.toInt()];
              return BarTooltipItem(
                '${d["label"]}: ${(d["hours"] as double).toStringAsFixed(1)}h',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx < 0 || idx >= monthsData.length) return const SizedBox.shrink();
                return Text(monthsData[idx]['label'] as String, style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted));
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(monthsData.length, (idx) {
          final h = monthsData[idx]['hours'] as double;
          final isCurrent = monthsData[idx]['month'] == referenceDate.month && monthsData[idx]['year'] == referenceDate.year;

          return BarChartGroupData(
            x: idx,
            barRods: [
              BarChartRodData(
                toY: h,
                color: isCurrent ? AppTheme.accentTeal : AppTheme.primaryBlue,
                width: 14,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }),
      ),
    );
  }

  Color _getAttentionColor(String category) {
    switch (category) {
      case 'overdue_action':
      case 'unresolved_appointment':
        return AppTheme.alertRed;
      case 'inactive_study':
        return AppTheme.alertAmber;
      case 'no_next_action':
      default:
        return Colors.orange;
    }
  }

  IconData _getAttentionIcon(String category) {
    switch (category) {
      case 'overdue_action':
        return Icons.timer_off;
      case 'inactive_study':
        return Icons.hourglass_empty;
      case 'unresolved_appointment':
        return Icons.event_busy;
      case 'no_next_action':
      default:
        return Icons.help_outline;
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return months[month - 1];
  }

  String _getMonthAbbr(int month) {
    const abbr = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    return abbr[month - 1];
  }

  Widget _buildStudyMetricsOverviewCard(
    DashboardMetrics metrics,
    Color headingColor,
    Color bodyColor,
    Color mutedColor,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Métricas dos Estudos Bíblicos & Revisitas',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: headingColor),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.repeat, size: 18, color: Color(0xFF0284C7)),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text('Total de Visitas', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${metrics.heldVisitsCount}',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                            ),
                            Text('Visitas e revisitas realizadas', style: TextStyle(fontSize: 11, color: mutedColor)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEA580C).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFEA580C).withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.person_off_outlined, size: 18, color: Color(0xFFEA580C)),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text('Não em Casa', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEA580C))),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${metrics.notAtHomeCount}',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                            ),
                            Text('Tentativas sem contato', style: TextStyle(fontSize: 11, color: mutedColor)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.schedule, size: 18, color: Color(0xFF059669)),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text('% Regularidade', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${metrics.scheduleRegularityPercentage.toStringAsFixed(0)}%',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                            ),
                            Text('No dia e hora combinados', style: TextStyle(fontSize: 11, color: mutedColor)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.groups, size: 18, color: Color(0xFF7C3AED)),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text('Assistência Média', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${metrics.averageAttendancePerStudy}',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                            ),
                            Text('Presentes por sessão', style: TextStyle(fontSize: 11, color: mutedColor)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConversionFunnelSection(
    DashboardMetrics metrics,
    Color headingColor,
    Color bodyColor,
    Color mutedColor,
    bool isDark,
  ) {
    final stages = [
      (
        label: '1. Interessados',
        count: metrics.funnelInterestedCount,
        color: const Color(0xFF2563EB),
        icon: Icons.person_search,
        desc: 'Pessoas com interesse identificado',
      ),
      (
        label: '2. 1ª Revisita',
        count: metrics.funnelFirstReturnVisitCount,
        color: const Color(0xFF0891B2),
        icon: Icons.mark_chat_read,
        desc: 'Revisita realizada com diálogo',
      ),
      (
        label: '3. Estudo Iniciado',
        count: metrics.funnelStartedStudyCount,
        color: const Color(0xFF7C3AED),
        icon: Icons.menu_book,
        desc: 'Estudo bíblico ativo ou iniciado',
      ),
      (
        label: '4. Parte 3 Livro (Lição 34+)',
        count: metrics.funnelReachedPart3Count,
        color: const Color(0xFF059669),
        icon: Icons.emoji_events,
        desc: 'Avançaram além da Lição 33 do "Seja Feliz"',
      ),
      (
        label: '5. Estudos Encerrados',
        count: metrics.funnelDroppedOutCount,
        color: const Color(0xFFDC2626),
        icon: Icons.cancel_outlined,
        desc: 'Estudos descontinuados ou encerrados',
      ),
    ];

    final maxVal = stages.map((s) => s.count).fold(1, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progresso da Obra',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: headingColor),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Progresso Espiritual',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: stages.map((st) {
                final ratio = maxVal > 0 ? (st.count / maxVal).clamp(0.0, 1.0) : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(st.icon, size: 16, color: st.color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              st.label,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: st.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${st.count}',
                              style: TextStyle(fontWeight: FontWeight.bold, color: st.color, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 8,
                          backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(st.color),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(st.desc, style: TextStyle(fontSize: 10, color: mutedColor)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEndedStudiesByReasonSection(
    DashboardMetrics metrics,
    Color headingColor,
    Color bodyColor,
    Color mutedColor,
    bool isDark,
  ) {
    final reasons = metrics.endedStudiesByReason;
    final totalEnded = metrics.endedStudiesCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Encerramento de Estudos Bíblicos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: headingColor),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: totalEnded > 0 ? const Color(0xFFDC2626).withValues(alpha: 0.1) : AppTheme.successGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                totalEnded > 0 ? '$totalEnded encerrado(s)' : 'Nenhum encerrado',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: totalEnded > 0 ? const Color(0xFFDC2626) : AppTheme.successGreen,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: totalEnded == 0
                ? Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: AppTheme.successGreen, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Nenhum estudo bíblico foi descontinuado ou encerrado até o momento.',
                          style: TextStyle(fontSize: 12, color: mutedColor),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Distribuição dos motivos de encerramento:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: bodyColor),
                      ),
                      const SizedBox(height: 10),
                      ...reasons.entries.map((entry) {
                        final count = entry.value;
                        final percent = totalEnded > 0 ? (count / totalEnded) * 100 : 0.0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(entry.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  Text('$count (${percent.toStringAsFixed(0)}%)', style: TextStyle(fontSize: 12, color: mutedColor, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 3),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: percent / 100.0,
                                  minHeight: 6,
                                  backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE11D48)),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildModalityDistributionChart(List<ActivityRecordEntry> activities, DateTime periodStart, DateTime periodEnd) {
    final periodActivities = activities.where((a) =>
        a.deletedAt == null &&
        a.date.isAfter(periodStart.subtract(const Duration(seconds: 1))) &&
        a.date.isBefore(periodEnd.add(const Duration(seconds: 1)))).toList();

    const modalityLabels = {
      'campo': 'Casa em Casa',
      'testemunho_publico': 'Público / Carrinho',
      'informal': 'Informal',
      'carta_telefone': 'Cartas & Telefone',
      'outro': 'Outras Modalidades',
    };

    const modalityColors = {
      'campo': Color(0xFF2563EB),
      'testemunho_publico': Color(0xFF7C3AED),
      'informal': Color(0xFFF59E0B),
      'carta_telefone': Color(0xFF0D9488),
      'outro': Color(0xFF64748B),
    };

    final Map<String, int> durationByModality = {};
    int totalPeriodSeconds = 0;

    for (final act in periodActivities) {
      final mod = act.modality.trim().toLowerCase();
      durationByModality[mod] = (durationByModality[mod] ?? 0) + act.durationSeconds;
      totalPeriodSeconds += act.durationSeconds;
    }

    if (totalPeriodSeconds <= 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pie_chart_outline, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              const Text('Nenhuma atividade registrada no período selecionado.', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    final sections = <PieChartSectionData>[];
    durationByModality.forEach((mod, seconds) {
      final double pct = (seconds / totalPeriodSeconds) * 100.0;
      final color = modalityColors[mod] ?? const Color(0xFF6366F1);
      sections.add(
        PieChartSectionData(
          value: seconds.toDouble(),
          color: color,
          radius: 44,
          title: '${pct.toStringAsFixed(0)}%',
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    });

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 36,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: durationByModality.entries.map((entry) {
            final mod = entry.key;
            final secs = entry.value;
            final color = modalityColors[mod] ?? const Color(0xFF6366F1);
            final label = modalityLabels[mod] ?? mod;
            final hours = (secs / 3600).toStringAsFixed(1);
            final pct = ((secs / totalPeriodSeconds) * 100).toStringAsFixed(0);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Text('${hours}h ($pct%)', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildEndedVisitsByReasonSection(
    DashboardMetrics metrics,
    Color headingColor,
    Color bodyColor,
    Color mutedColor,
    bool isDark,
  ) {
    final reasons = metrics.endedVisitsByReason;
    final totalEnded = metrics.endedVisitsCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Encerramento de Revisitas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: headingColor),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: totalEnded > 0 ? const Color(0xFFD97706).withValues(alpha: 0.1) : AppTheme.successGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                totalEnded > 0 ? '$totalEnded encerrada(s)' : 'Nenhuma encerrada',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: totalEnded > 0 ? const Color(0xFFD97706) : AppTheme.successGreen,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: totalEnded == 0
                ? Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: AppTheme.successGreen, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Todas as suas revisitas continuam ativas no território.',
                          style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Distribuição dos Motivos de Encerramento:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : AppTheme.textDark),
                      ),
                      const SizedBox(height: 10),
                      ...reasons.entries.map((entry) {
                        final count = entry.value;
                        final percent = totalEnded > 0 ? (count / totalEnded) * 100 : 0.0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(entry.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  Text('$count (${percent.toStringAsFixed(0)}%)', style: TextStyle(fontSize: 12, color: mutedColor, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 3),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: percent / 100.0,
                                  minHeight: 6,
                                  backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD97706)),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _ReportCell extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _ReportCell({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayColor = isDark && (color == const Color(0xFF0F172A) || color == AppTheme.textDark)
        ? Colors.white
        : color;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: displayColor, size: 22),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: displayColor),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
