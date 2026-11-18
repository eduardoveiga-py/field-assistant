import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../../core/app_logger.dart';
import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../appointments/availability_engine.dart';
import '../../appointments/brazil_holidays.dart';
import '../../appointments/calendar_sync_coordinator.dart';
import '../../appointments/calendar_provider.dart';
import '../../appointments/external_events_for_display.dart';
import 'connected_calendars_screen.dart';
import '../../appointments/ics_calendar_helper.dart';
import '../../appointments/ics_picker_helper.dart';
import '../../database/app_database.dart';
import '../../reports/web_downloader.dart';
import '../../settings/app_settings_manager.dart';
import '../providers.dart';
import 'person_detail_screen.dart';
import 'project_detail_screen.dart';
import 'tasks_screen.dart';
import '../widgets/schedule_conflict_resolution_banner.dart';
import '../../appointments/plan_b_recommender.dart';
import '../widgets/screen_hero_accent_band.dart';
import '../widgets/managed_text_controllers.dart';
import '../widgets/plan_b_dialog.dart';
import '../widgets/appointments/appointment_detail_pane.dart';
import '../widgets/appointments/appointments_controls_bar.dart';
import '../widgets/appointments/appointments_hours_summary_banner.dart';

part 'appointments/appointments_sync_and_ics_modals.dart';
part 'appointments/appointments_action_modals.dart';
part 'appointments/monthly_schedule_copy_wizard.dart';
part 'appointments/appointments_calendar_views.dart';

class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key, this.calendarToolsOnly = false});

  final bool calendarToolsOnly;

  static bool isMinistryAppointment(AppointmentEntry appt) =>
      _AppointmentsScreenState.isMinistryAppointment(appt);

  static List<AppointmentEntry> projectTasksAndProjectsToAppointments(
    List<AppointmentEntry> appointments,
    List<TaskEntry> tasks,
    List<ProjectEntry> projects,
  ) => _AppointmentsCalendarViews._appointmentsWithTasksAndProjects(
    appointments,
    tasks,
    projects,
  );

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen> {
  void _updateState(VoidCallback fn) => setState(fn);
  DateTime _selectedDate = DateTime.now();
  bool _isCalendarSyncing = false;
  String _viewMode = 'Mês'; // 'Mês', 'Semana', 'Dia', 'Lista'
  String? _selectedAppointmentId;
  final ScrollController _timeScrollController = ScrollController();

  @override
  void dispose() {
    _timeScrollController.dispose();
    super.dispose();
  }

  static bool isMinistryAppointment(AppointmentEntry appt) {
    if (appt.id.startsWith('task:') || appt.id.startsWith('project:')) {
      return false;
    }
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

  static Color _getAppointmentActivityColor(AppointmentEntry appt) {
    if (appt.id.startsWith('task:')) {
      return const Color(0xFF0284C7); // Sky Blue para tarefas
    }
    if (appt.id.startsWith('project:')) {
      return const Color(0xFF6366F1); // Indigo para projetos
    }
    final titleLower = appt.title.toLowerCase();
    if (titleLower.contains('viagem')) return const Color(0xFF0D9488); // Teal
    if (titleLower.contains('ausência') || titleLower.contains('ausencia')) {
      return const Color(0xFFD97706); // Amber
    }
    if (titleLower.contains('folga')) return const Color(0xFF64748B); // Slate
    if (titleLower.contains('pessoal')) {
      return const Color(0xFF9333EA); // Purple
    }
    if (titleLower.contains('outro')) {
      return const Color(0xFF475569); // Slate Grey
    }
    if (titleLower.contains('estudo') || appt.studyId != null) {
      return const Color(0xFF059669); // Emerald Green
    }
    if (titleLower.contains('revisita')) {
      return const Color(0xFFEA580C); // Orange
    }
    return const Color(0xFF2563EB); // Royal Blue (Campo)
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
      default:
        return AppTheme.primaryBlue;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (widget.calendarToolsOnly) {
        final appointments = await ref.read(appointmentsStreamProvider.future);
        if (!mounted) return;
        _showOfficialCalendarSyncModal(context, appointments);
      } else {
        _scrollToCurrentTime();
        _checkAutoSyncCalendar();
      }
    });
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

  String _getMonthName(int month) => AppointmentsControlsBar.getMonthName(month);

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
    final externalEvents =
        ref.watch(externalCalendarEventsProvider).value ?? [];
    final links = ref.watch(calendarEventLinksProvider).value ?? [];
    final pendingTasks = ref.watch(pendingTasksStreamProvider).value ?? [];
    final activeProjects = ref.watch(activeProjectsStreamProvider).value ?? [];
    final withExternal = appointmentsWithExternalEvents(
      allAppts,
      externalEvents,
      links,
    );
    final calendarAppts =
        _AppointmentsCalendarViews._appointmentsWithTasksAndProjects(
          withExternal,
          pendingTasks,
          activeProjects,
        );
    final allActivities = activitiesAsync.value ?? [];

    if (widget.calendarToolsOnly) {
      return Scaffold(
        appBar: AppBar(title: const Text('Importar / Exportar Calendário')),
        body: Center(
          child: ElevatedButton.icon(
            onPressed: () => _showOfficialCalendarSyncModal(context, allAppts),
            icon: const Icon(Icons.import_export),
            label: const Text('Configurar / Importar'),
          ),
        ),
      );
    }

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
        title: Semantics(
          header: true,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: const Text('Agenda do Ministério'),
          ),
        ),
        bottom: ScreenHeroAccentBand.agenda(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Semantics(
              button: true,
              label: 'Sincronizar calendários conectados',
              child: Builder(
                builder: (context) {
                  final textScale = MediaQuery.textScalerOf(context).scale(1.0);
                  final isCompact =
                      MediaQuery.of(context).size.width <
                          (500 * textScale.clamp(1.0, 2.5)) ||
                      textScale >= 1.5;
                  if (isCompact) {
                    return IconButton(
                      icon: const Icon(Icons.sync_alt),
                      tooltip: 'Sincronizar Calendários',
                      onPressed: _isCalendarSyncing
                          ? null
                          : _syncConnectedCalendars,
                    );
                  }
                  return FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 0,
                      ),
                    ),
                    icon: const Icon(Icons.sync_alt, size: 16),
                    label: const Text(
                      'Sincronizar Calendários',
                      style: TextStyle(fontSize: 12),
                    ),
                    onPressed: _isCalendarSyncing
                        ? null
                        : _syncConnectedCalendars,
                  );
                },
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'Ir para a data de hoje',
            child: IconButton(
              icon: const Icon(Icons.today),
              tooltip: 'Hoje',
              onPressed: () {
                setState(() => _selectedDate = DateTime.now());
                _scrollToCurrentTime();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Semantics(
        button: true,
        container: true,
        excludeSemantics: true,
        label: 'Novo Compromisso - Agendar novo compromisso no ministério',
        hint: 'Abre formulário para agendar compromisso',
        child: FloatingActionButton.extended(
          heroTag: 'fab_novo_compromisso',
          backgroundColor: isDark
              ? const Color(0xFF3B82F6)
              : AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Novo Compromisso'),
          onPressed: () => _showNewAppointmentModal(context),
        ),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: ScheduleConflictResolutionBanner(),
          ),
          // Barra de controles de visualização (Mês, Semana, Dia, Lista)
          AppointmentsControlsBar(
            viewMode: _viewMode,
            selectedDate: _selectedDate,
            isDark: isDark,
            onViewModeChanged: (val) {
              setState(() => _viewMode = val);
              if (_viewMode == 'Dia') {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _scrollToCurrentTime(),
                );
              }
            },
            onPreviousDate: () {
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
            onNextDate: () {
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
            onTodayPressed: () {
              setState(() => _selectedDate = DateTime.now());
              _scrollToCurrentTime();
            },
          ),
          const Divider(height: 1),

          // Comparativo Horas Programadas vs Horas Efetivas Realizadas
          AppointmentsHoursSummaryBanner(
            scheduledHours: scheduledHours,
            actualHours: actualHours,
            isDark: isDark,
            onCopySchedule: () => _showMonthlyScheduleCopyWizard(
              context,
              allAppts,
            ),
            onScheduleFieldMinistry: () =>
                _showFieldMinistryScheduleModal(context),
          ),
          const Divider(height: 1),

          // Área de visualização do calendário
          Expanded(
            child: appointmentsAsync.when(
              data: (_) {
                final activeAppts = calendarAppts;
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 900;
                    if (isWide &&
                        (_viewMode == 'Mês' || _viewMode == 'Semana')) {
                      return _buildSplitCalendarView(activeAppts, isDark);
                    }

                    if (isWide && _viewMode == 'Lista') {
                      return _buildSplitListView(activeAppts, isDark);
                    }

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
                );
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
