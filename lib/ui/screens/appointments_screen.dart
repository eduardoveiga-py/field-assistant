import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../appointments/availability_engine.dart';
import '../../appointments/calendar_provider.dart';
import '../../appointments/calendar_sync_coordinator.dart';
import '../../appointments/ics_calendar_helper.dart';
import '../../database/app_database.dart';
import '../../settings/app_settings_manager.dart';
import '../providers.dart';
import 'person_detail_screen.dart';
import '../../appointments/plan_b_recommender.dart';
import '../widgets/plan_b_dialog.dart';

import '../widgets/appointment_form_dialog.dart';
import '../widgets/monthly_schedule_copy_wizard.dart';
import '../widgets/calendar_views/appointment_list_view.dart';
import '../widgets/calendar_views/day_hourly_grid_view.dart';
import '../widgets/calendar_views/month_calendar_view.dart';
import '../widgets/calendar_views/week_calendar_view.dart';

class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen>
    with WidgetsBindingObserver {
  DateTime _selectedDate = DateTime.now();
  String _viewMode = 'Mês'; // 'Mês', 'Semana', 'Dia', 'Lista'
  final ScrollController _timeScrollController = ScrollController();
  bool _isSyncingCalendar = false;

  static bool isMinistryAppointment(AppointmentEntry appt) {
    final titleLower = appt.title.toLowerCase();
    final notesLower = (appt.locationNotes ?? '').toLowerCase();
    if (titleLower.contains('ausência') ||
        titleLower.contains('ausencia') ||
        titleLower.contains('folga') ||
        titleLower.contains('viagem') ||
        titleLower.contains('pessoal') ||
        titleLower.contains('[ausência]') ||
        titleLower.contains('[folga]') ||
        titleLower.contains('[viagem]') ||
        titleLower.contains('[pessoal]') ||
        titleLower.contains('[outro]') ||
        notesLower.contains('tipo:nao_ministerio')) {
      return false;
    }
    return true;
  }


  static Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'realizado':
        return AppTheme.successGreen;
      case 'cancelado':
        return AppTheme.alertRed;
      case 'nao_realizado':
        return AppTheme.alertAmber;
      case 'reagendado':
        return const Color(0xFF8B5CF6);
      case 'conflito':
        return AppTheme.alertRed;
      case 'provisorio':
        return AppTheme.alertAmber;
      default:
        return AppTheme.primaryBlue;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentTime();
      _checkAutoSyncCalendar();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timeScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAutoSyncCalendar();
    }
  }

  void _triggerBackgroundCalendarSync() {
    ref.read(calendarSyncCoordinatorProvider).syncAll().ignore();
  }

  Future<void> _checkAutoSyncCalendar() async {
    try {
      final settings = ref.read(appSettingsManagerProvider);
      final savedUrl = await settings.getString('saved_calendar_url');
      if (savedUrl != null && savedUrl.trim().isNotEmpty) {
        final repo = ref.read(repositoryProvider);
        await IcsCalendarHelper.syncFromWebcalUrl(
          repo: repo,
          rawUrl: savedUrl.trim(),
          silent: true,
        );
      }
      // Silenciosamente sincroniza contas conectadas (Google / Apple) se autorizadas
      await ref.read(calendarSyncCoordinatorProvider).syncAll();
    } catch (_) {
      // Auto-sync silencioso em segundo plano
    }
  }

  Future<void> _syncConnectedCalendars(BuildContext context) async {
    if (_isSyncingCalendar) return;
    setState(() => _isSyncingCalendar = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final coordinator = ref.read(calendarSyncCoordinatorProvider);
      final result = await coordinator.syncAll().timeout(
        const Duration(seconds: 15),
        onTimeout: () => CalendarSyncResult(
          success: false,
          errorMessage:
              'Tempo limite esgotado ao sincronizar com Google Calendar. Verifique sua conexão.',
        ),
      );
      if (!context.mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            result.success
                ? 'Calendários sincronizados com sucesso! (${result.eventsDownloaded} recebidos, ${result.eventsUploaded} enviados)'
                : 'Aviso na sincronização: ${result.errorMessage ?? "Verifique a conexão."}',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Erro na sincronização: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSyncingCalendar = false);
    }
  }

  void _scrollToCurrentTime() {
    if (_timeScrollController.hasClients) {
      final now = DateTime.now();
      final currentHour = now.hour.clamp(7, 22);
      final offset = (currentHour - 7) * 60.0;
      _timeScrollController.animateTo(
        offset.clamp(0.0, _timeScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
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

  Future<void> _exportToGoogleCalendar(AppointmentEntry appt) async {
    String formatCalDate(DateTime dt) {
      final u = dt.toUtc();
      return '${u.year.toString().padLeft(4, "0")}'
          '${u.month.toString().padLeft(2, "0")}'
          '${u.day.toString().padLeft(2, "0")}T'
          '${u.hour.toString().padLeft(2, "0")}'
          '${u.minute.toString().padLeft(2, "0")}00Z';
    }

    final start = formatCalDate(appt.startTime);
    final end = formatCalDate(appt.endTime);
    final text = Uri.encodeComponent(appt.title);
    final details = Uri.encodeComponent(
      appt.locationNotes ?? 'Agendado pelo App Ministério Pessoal',
    );

    final url =
        'https://calendar.google.com/calendar/render?action=TEMPLATE&text=$text&dates=$start/$end&details=$details';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showNewAppointmentModal(
    BuildContext context, {
    DateTime? initialDateTime,
  }) {
    AppointmentFormDialog.show(
      context,
      initialDateTime: initialDateTime ?? _selectedDate,
      onSaved: () => _triggerBackgroundCalendarSync(),
    );
  }

  void _showAppointmentActions(BuildContext context, AppointmentEntry appt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _getStatusColor(appt.status)
                          .withValues(alpha: 0.15),
                      child: Icon(
                        Icons.event,
                        color: _getStatusColor(appt.status),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appt.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${AppDateUtils.formatDateTime(appt.startTime)} - ${AppDateUtils.formatTime(appt.endTime)} (${appt.durationMinutes} min)',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                if (appt.status == 'conflito' || appt.isProvisional)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.alertRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.alertRed, width: 1.2),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: AppTheme.alertRed,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Conflito pós-sincronização: há outro compromisso no mesmo intervalo. Reagende para liberar o horário.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.alertRed,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 24),
                ListTile(
                  leading: const Icon(
                    Icons.sync_alt,
                    color: AppTheme.primaryBlue,
                  ),
                  title: const Text('Reagendar (Preservar Histórico)'),
                  subtitle: const Text(
                    'Move para nova data mantendo rastreabilidade',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showRescheduleModal(context, appt);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.check_circle_outline,
                    color: AppTheme.successGreen,
                  ),
                  title: const Text('Marcar como Realizado'),
                  onTap: () async {
                    final repo = ref.read(repositoryProvider);
                    await repo.updateAppointment(
                      appt.copyWith(status: 'realizado'),
                    );
                    _triggerBackgroundCalendarSync();
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.alt_route, color: Colors.orange),
                  title: const Text('Estudante Desmarcou (Ver Plano B)'),
                  subtitle: const Text(
                    'Marca como cancelado e sugere contatos próximos para o horário',
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final repo = ref.read(repositoryProvider);
                    await repo.updateAppointment(
                      appt.copyWith(status: 'cancelado'),
                    );
                    _triggerBackgroundCalendarSync();

                    final people = ref.read(peopleStreamProvider).value ?? [];
                    final visits = ref.read(visitsStreamProvider).value ?? [];
                    final cancelledPerson = appt.personId != null
                        ? people.where((p) => p.id == appt.personId).firstOrNull
                        : null;

                    final targetPerson =
                        cancelledPerson ??
                        PersonEntry(
                          id: 'temp_appt_${appt.id}',
                          name: appt.title,
                          status: 'potencial',
                          tags: '[]',
                          firstContactAt: DateTime.now(),
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                          revision: 1,
                        );

                    final suggestions = PlanBRecommender.getSuggestions(
                      cancelledPerson: targetPerson,
                      allPeople: people,
                      allVisits: visits,
                      currentLat: targetPerson.latitude,
                      currentLng: targetPerson.longitude,
                      targetDateTime: appt.startTime,
                    );

                    if (context.mounted) {
                      PlanBDialog.show(
                        context,
                        cancelledPerson: targetPerson,
                        suggestions: suggestions,
                      );
                    }
                  },
                ),
                if (appt.personId != null)
                  ListTile(
                    leading: const Icon(
                      Icons.person_outline,
                      color: AppTheme.accentTeal,
                    ),
                    title: const Text('Abrir Cadastro da Pessoa'),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PersonDetailScreen(personId: appt.personId!),
                        ),
                      );
                    },
                  ),
                ListTile(
                  leading: const Icon(
                    Icons.calendar_month,
                    color: Color(0xFF1E40AF),
                  ),
                  title: const Text('Adicionar ao Google Agenda'),
                  subtitle: const Text(
                    'Abre o Google Agenda no navegador com dados preenchidos',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _exportToGoogleCalendar(appt);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: AppTheme.alertRed,
                  ),
                  title: const Text(
                    'Excluir Compromisso',
                    style: TextStyle(color: AppTheme.alertRed),
                  ),
                  onTap: () async {
                    final repo = ref.read(repositoryProvider);
                    await repo.deleteAppointment(appt.id);
                    _triggerBackgroundCalendarSync();
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Compromisso movido para a lixeira.'),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRescheduleModal(BuildContext context, AppointmentEntry appt) {
    AppointmentFormDialog.showReschedule(
      context,
      appointment: appt,
      onSaved: () => _triggerBackgroundCalendarSync(),
    );
  }

  void _showMonthlyScheduleCopyWizard(
    BuildContext context,
    List<AppointmentEntry> allAppts,
  ) {
    MonthlyScheduleCopyWizardDialog.show(
      context,
      selectedDate: _selectedDate,
      allAppointments: allAppts,
      onCompleted: () => _triggerBackgroundCalendarSync(),
    );
  }

  void _showFieldMinistryScheduleModal(BuildContext context) {
    DateTime chosenDate = _selectedDate;
    TimeOfDay chosenTime = const TimeOfDay(hour: 9, minute: 0);
    int durationMinutes = 120; // 2 horas padrão
    String modality = 'De Casa em Casa';
    final locationController = TextEditingController();
    String recurrence = 'Toda semana';
    int recurrenceCount = 8;
    bool respectAvailability = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final start = DateTime(
            chosenDate.year,
            chosenDate.month,
            chosenDate.day,
            chosenTime.hour,
            chosenTime.minute,
          );
          final existingAppts =
              ref.read(appointmentsStreamProvider).value ?? [];
          final availability = AvailabilityEngine.checkAvailability(
            startTime: start,
            durationMinutes: durationMinutes,
            existingAppointments: existingAppts,
          );

          final occurrences = <DateTime>[start];
          if (recurrence != 'Único') {
            for (int i = 1; i < recurrenceCount; i++) {
              if (recurrence == 'Toda semana') {
                occurrences.add(start.add(Duration(days: i * 7)));
              } else if (recurrence == 'A cada 15 dias') {
                occurrences.add(start.add(Duration(days: i * 14)));
              } else if (recurrence == 'Mensal') {
                final targetMonth = start.month + i;
                final yearOffset = (targetMonth - 1) ~/ 12;
                final month = ((targetMonth - 1) % 12) + 1;
                final year = start.year + yearOffset;
                final daysInMonth = DateTime(year, month + 1, 0).day;
                final day = start.day.clamp(1, daysInMonth);
                occurrences.add(
                  DateTime(year, month, day, start.hour, start.minute),
                );
              }
            }
          }

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.alarm_add, color: AppTheme.primaryBlue),
                SizedBox(width: 8),
                Text('Programar Serviço de Campo'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: modality,
                    decoration: const InputDecoration(
                      labelText: 'Modalidade de Testemunho',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'De Casa em Casa',
                        child: Text('🏠 De Casa em Casa'),
                      ),
                      DropdownMenuItem(
                        value: 'Testemunho Público (Carrinho)',
                        child: Text('🛒 Testemunho Público (Carrinho)'),
                      ),
                      DropdownMenuItem(
                        value: 'Testemunho Informal',
                        child: Text('💬 Testemunho Informal'),
                      ),
                      DropdownMenuItem(
                        value: 'Cartas e Telefone',
                        child: Text('✉️ Cartas e Telefone'),
                      ),
                      DropdownMenuItem(value: 'Outro', child: Text('📌 Outro')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => modality = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.date_range, size: 16),
                        label: Text(AppDateUtils.formatDate(chosenDate)),
                        onPressed: () async {
                          final p = await showDatePicker(
                            context: context,
                            initialDate: chosenDate,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 30),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (p != null) setDialogState(() => chosenDate = p);
                        },
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.access_time, size: 16),
                        label: Text(
                          '${chosenTime.hour.toString().padLeft(2, '0')}:${chosenTime.minute.toString().padLeft(2, '0')}',
                        ),
                        onPressed: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: chosenTime,
                          );
                          if (t != null) setDialogState(() => chosenTime = t);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: durationMinutes,
                    decoration: const InputDecoration(
                      labelText: 'Duração Prevista',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 60,
                        child: Text('1 hora (60 min)'),
                      ),
                      DropdownMenuItem(
                        value: 90,
                        child: Text('1h 30m (90 min)'),
                      ),
                      DropdownMenuItem(
                        value: 120,
                        child: Text('2 horas (120 min)'),
                      ),
                      DropdownMenuItem(
                        value: 150,
                        child: Text('2h 30m (150 min)'),
                      ),
                      DropdownMenuItem(
                        value: 180,
                        child: Text('3 horas (180 min)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => durationMinutes = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: recurrence,
                    decoration: const InputDecoration(
                      labelText: 'Repetição / Recorrência',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Único',
                        child: Text('Apenas esta data (Único)'),
                      ),
                      DropdownMenuItem(
                        value: 'Toda semana',
                        child: Text('Toda semana (Semanal)'),
                      ),
                      DropdownMenuItem(
                        value: 'A cada 15 dias',
                        child: Text('A cada 15 dias (Quinzenal)'),
                      ),
                      DropdownMenuItem(
                        value: 'Mensal',
                        child: Text('Mensal (a cada 4 semanas)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => recurrence = val);
                    },
                  ),
                  if (recurrence != 'Único') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: recurrenceCount,
                      decoration: const InputDecoration(
                        labelText: 'Quantidade de ocorrências',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 4,
                          child: Text('4 semanas (1 mês)'),
                        ),
                        DropdownMenuItem(
                          value: 8,
                          child: Text('8 semanas (2 meses)'),
                        ),
                        DropdownMenuItem(
                          value: 12,
                          child: Text('12 semanas (3 meses)'),
                        ),
                        DropdownMenuItem(
                          value: 16,
                          child: Text('16 semanas (4 meses)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => recurrenceCount = val);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Respeitar disponibilidade da agenda',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text(
                        'Pula automaticamente horários conflitantes via AvailabilityEngine',
                        style: TextStyle(fontSize: 11),
                      ),
                      value: respectAvailability,
                      onChanged: (val) =>
                          setDialogState(() => respectAvailability = val),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(
                      labelText: 'Ponto de Encontro / Território',
                      hintText: 'Ex: Salão do Reino / Praça Central / Setor 03',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: availability.isAvailable
                          ? AppTheme.successGreen.withValues(alpha: 0.1)
                          : AppTheme.alertAmber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: availability.isAvailable
                            ? AppTheme.successGreen
                            : AppTheme.alertAmber,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          availability.isAvailable
                              ? Icons.check_circle
                              : Icons.warning_amber,
                          color: availability.isAvailable
                              ? AppTheme.successGreen
                              : AppTheme.alertAmber,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            availability.message,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: availability.isAvailable
                                  ? AppTheme.successGreen
                                  : const Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
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
                  final repo = ref.read(repositoryProvider);
                  int createdCount = 0;
                  int skippedCount = 0;
                  final runningAppts = List<AppointmentEntry>.from(
                    existingAppts,
                  );

                  for (final occ in occurrences) {
                    final occEnd = occ.add(Duration(minutes: durationMinutes));
                    final hasConflict = AvailabilityEngine.hasCollision(
                      start: occ,
                      end: occEnd,
                      existingAppointments: runningAppts,
                    );

                    if (hasConflict &&
                        respectAvailability &&
                        occurrences.length > 1) {
                      skippedCount++;
                      continue;
                    }

                    final newEntry = await repo.createAppointment(
                      title: 'Saída de Campo ($modality)',
                      startTime: occ,
                      endTime: occEnd,
                      durationMinutes: durationMinutes,
                      status: 'confirmado',
                      locationNotes: locationController.text.trim().isEmpty
                          ? null
                          : locationController.text.trim(),
                    );
                    runningAppts.add(newEntry);
                    createdCount++;
                  }

                  _triggerBackgroundCalendarSync();

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    final message = occurrences.length == 1
                        ? 'Saída de campo programada com sucesso!'
                        : '$createdCount saídas de campo programadas!${skippedCount > 0 ? " ($skippedCount puladas por conflito)" : ""}';
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(message)));
                  }
                },
                child: const Text('Programar Saída'),
              ),
            ],
          );
        },
      ),
    );
  }

  // 1. Visão de Calendário Mensal Google Calendar Style
  Widget _buildMonthCalendarView(List<AppointmentEntry> allAppts) {
    return MonthCalendarView(
      selectedDate: _selectedDate,
      allAppointments: allAppts,
      onSelectDate: (dt) => setState(() => _selectedDate = dt),
      onAppointmentTap: (appt) => _showAppointmentActions(context, appt),
      onNewAppointment: (dt) =>
          _showNewAppointmentModal(context, initialDateTime: dt),
      isDark: Theme.of(context).brightness == Brightness.dark,
    );
  }

  // 2. Visão Semanal Estilo Google Calendar em 7 Colunas
  Widget _buildWeekCalendarView(List<AppointmentEntry> allAppts) {
    return WeekCalendarView(
      selectedDate: _selectedDate,
      allAppointments: allAppts,
      onSelectDate: (dt) => setState(() => _selectedDate = dt),
      onAppointmentTap: (appt) => _showAppointmentActions(context, appt),
      isDark: Theme.of(context).brightness == Brightness.dark,
    );
  }

  // 3. Visão Diária com Grade Horária
  Widget _buildDayHourlyGridView(List<AppointmentEntry> allAppts) {
    return DayHourlyGridView(
      selectedDate: _selectedDate,
      allAppointments: allAppts,
      timeScrollController: _timeScrollController,
      onAppointmentTap: (appt) => _showAppointmentActions(context, appt),
      onNewAppointmentAtTime: (dt) =>
          _showNewAppointmentModal(context, initialDateTime: dt),
      isDark: Theme.of(context).brightness == Brightness.dark,
    );
  }

  // 4. Visão Lista Cronológica
  Widget _buildListView(List<AppointmentEntry> allAppts) {
    return AppointmentListView(
      allAppointments: allAppts,
      onAppointmentTap: (appt) => _showAppointmentActions(context, appt),
      isDark: Theme.of(context).brightness == Brightness.dark,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync = ref.watch(appointmentsStreamProvider);
    final activitiesAsync = ref.watch(activitiesStreamProvider);
    final peopleAsync = ref.watch(peopleStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final passedPersonIds = (peopleAsync.value ?? [])
        .where((p) => p.status == 'revisita_passada')
        .map((p) => p.id)
        .toSet();
    final allAppts = (appointmentsAsync.value ?? [])
        .where(
          (a) => a.personId == null || !passedPersonIds.contains(a.personId),
        )
        .toList();
    final allActivities = activitiesAsync.value ?? [];

    final monthActivities = allActivities
        .where(
          (a) =>
              a.deletedAt == null &&
              a.date.year == _selectedDate.year &&
              a.date.month == _selectedDate.month,
        )
        .toList();
    final actualHours = monthActivities.fold(
      0.0,
      (acc, a) => acc + (a.durationSeconds / 3600.0),
    );

    final monthAppts = allAppts
        .where(
          (a) =>
              a.deletedAt == null &&
              a.status != 'cancelado' &&
              a.startTime.year == _selectedDate.year &&
              a.startTime.month == _selectedDate.month,
        )
        .toList();
    final scheduledHours = monthAppts
        .where(isMinistryAppointment)
        .fold(0.0, (acc, a) => acc + (a.durationMinutes / 60.0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda do Ministério'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _isSyncingCalendar
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : MediaQuery.of(context).size.width < 500
                    ? IconButton(
                        icon: const Icon(Icons.sync),
                        tooltip: 'Sincronizar Calendários Conectados',
                        onPressed: () => _syncConnectedCalendars(context),
                      )
                    : FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 0,
                          ),
                        ),
                        icon: const Icon(Icons.sync, size: 16),
                        label: const Text(
                          'Sincronizar Calendários',
                          style: TextStyle(fontSize: 12),
                        ),
                        onPressed: () => _syncConnectedCalendars(context),
                      ),
          ),
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Hoje',
            onPressed: () {
              setState(() => _selectedDate = DateTime.now());
              _scrollToCurrentTime();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_novo_compromisso',
        backgroundColor: isDark
            ? const Color(0xFF3B82F6)
            : AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Novo Compromisso'),
        onPressed: () => _showNewAppointmentModal(context),
      ),
      body: Column(
        children: [
          // Barra de controles de visualização (Mês, Semana, Dia, Lista)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 460;
                    final navRow = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            setState(() {
                              if (_viewMode == 'Mês') {
                                _selectedDate = DateTime(
                                  _selectedDate.year,
                                  _selectedDate.month - 1,
                                  _selectedDate.day.clamp(1, 28),
                                );
                              } else if (_viewMode == 'Semana') {
                                _selectedDate = _selectedDate.subtract(
                                  const Duration(days: 7),
                                );
                              } else {
                                _selectedDate = _selectedDate.subtract(
                                  const Duration(days: 1),
                                );
                              }
                            });
                          },
                        ),
                        Text(
                          _viewMode == 'Mês'
                              ? '${_getMonthName(_selectedDate.month)} ${_selectedDate.year}'
                              : AppDateUtils.formatDate(_selectedDate),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            setState(() {
                              if (_viewMode == 'Mês') {
                                _selectedDate = DateTime(
                                  _selectedDate.year,
                                  _selectedDate.month + 1,
                                  _selectedDate.day.clamp(1, 28),
                                );
                              } else if (_viewMode == 'Semana') {
                                _selectedDate = _selectedDate.add(
                                  const Duration(days: 7),
                                );
                              } else {
                                _selectedDate = _selectedDate.add(
                                  const Duration(days: 1),
                                );
                              }
                            });
                          },
                        ),
                      ],
                    );

                    final segButton = SegmentedButton<String>(
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      segments: const [
                        ButtonSegment(
                          value: 'Mês',
                          label: Text('Mês', style: TextStyle(fontSize: 12)),
                        ),
                        ButtonSegment(
                          value: 'Semana',
                          label: Text('Semana', style: TextStyle(fontSize: 12)),
                        ),
                        ButtonSegment(
                          value: 'Dia',
                          label: Text('Dia', style: TextStyle(fontSize: 12)),
                        ),
                        ButtonSegment(
                          value: 'Lista',
                          label: Text('Lista', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                      selected: {_viewMode},
                      onSelectionChanged: (val) {
                        setState(() => _viewMode = val.first);
                        if (_viewMode == 'Dia') {
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _scrollToCurrentTime(),
                          );
                        }
                      },
                    );

                    if (isNarrow) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              navRow,
                              IconButton(
                                icon: const Icon(Icons.today, size: 20),
                                tooltip: 'Hoje',
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  setState(
                                    () => _selectedDate = DateTime.now(),
                                  );
                                  _scrollToCurrentTime();
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SizedBox(width: double.infinity, child: segButton),
                        ],
                      );
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [navRow, segButton],
                    );
                  },
                ),
              ),
            ),
          ),
          const Divider(height: 1),

          // Comparativo Horas Programadas vs Horas Efetivas Realizadas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Row(
                  children: [
                    const Icon(
                      Icons.av_timer,
                      size: 18,
                      color: AppTheme.primaryBlue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Programado: ${scheduledHours.toStringAsFixed(1)}h  •  Efetivo: ${actualHours.toStringAsFixed(1)}h${scheduledHours > 0 ? " (${((actualHours / scheduledHours) * 100).toStringAsFixed(0)}% realizado)" : ""}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? const Color(0xFF93C5FD)
                              : const Color(0xFF1E40AF),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Wrap(
                      spacing: 6,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.copy_all_outlined, size: 15),
                          label: const Text(
                            'Copiar Programação',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () =>
                              _showMonthlyScheduleCopyWizard(context, allAppts),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.alarm_add, size: 15),
                          label: const Text(
                            'Programar Campo',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () =>
                              _showFieldMinistryScheduleModal(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),

          // Área de visualização do calendário
          Expanded(
            child: appointmentsAsync.when(
              data: (appts) {
                final activeAppts = appts
                    .where(
                      (a) =>
                          a.personId == null ||
                          !passedPersonIds.contains(a.personId),
                    )
                    .toList();
                if (_viewMode == 'Mês') {
                  return _buildMonthCalendarView(activeAppts);
                } else if (_viewMode == 'Semana') {
                  return _buildWeekCalendarView(activeAppts);
                } else if (_viewMode == 'Dia') {
                  return _buildDayHourlyGridView(activeAppts);
                } else {
                  return _buildListView(activeAppts);
                }
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Erro: $err')),
            ),
          ),
        ],
      ),
    );
  }
}
