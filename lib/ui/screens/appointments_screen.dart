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

  Future<void> _syncConnectedCalendars() async {
    if (_isCalendarSyncing) return;
    setState(() => _isCalendarSyncing = true);
    try {
      final coordinator = ref.read(calendarSyncCoordinatorProvider);
      final connected = <CalendarProviderType>{};
      for (final provider in coordinator.allProviders) {
        if (!await provider.isAuthorized()) continue;
        if (provider.providerType == CalendarProviderType.appleEventKit &&
            await provider.getSelectedCalendarId() == null) {
          continue;
        }
        connected.add(provider.providerType);
      }
      if (!mounted) return;
      if (connected.isEmpty) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ConnectedCalendarsScreen()),
        );
        return;
      }
      final result = await coordinator.syncAll(
        fullSync: true,
        providers: connected,
      );
      if (!mounted) return;
      final message = result.success
          ? 'Sincronização concluída: ${result.eventsDownloaded} recebidos, ${result.eventsUploaded} enviados. ${result.conflictsFound} conflitos.'
          : 'Falha na sincronização: ${result.errorMessage ?? "erro desconhecido"}';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Falha na sincronização: $e')));
      }
    } finally {
      if (mounted) setState(() => _isCalendarSyncing = false);
    }
  }

  Future<({int created, int updated})?> _syncFromWebcalUrl(
    String rawUrl, {
    bool silent = false,
  }) async {
    var cleanUrl = rawUrl.trim().replaceAll(RegExp(r'^["\x27]|["\x27]$'), '');
    if (cleanUrl.startsWith('webcal://') || cleanUrl.startsWith('webcals://')) {
      cleanUrl = cleanUrl.replaceFirst(RegExp(r'^webcals?://'), 'https://');
    }
    String? icsBody;
    try {
      final uri = Uri.parse(cleanUrl);
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200 && resp.body.contains('BEGIN:VCALENDAR')) {
        icsBody = resp.body;
      }
    } catch (e) {
      if (icsBody == null && !silent) {
        throw Exception(
          'Não foi possível acessar a URL diretamente por restrições de rede ou CORS.\n\n'
          'Por favor, utilize a integração oficial em "Calendários Conectados", ou baixe o arquivo .ics e importe usando "Selecionar Arquivo .ics" para manter seus dados 100% privados.',
        );
      }
    }

    if (icsBody != null) {
      final res = await _importIcsContent(icsBody);
      await ref
          .read(appSettingsManagerProvider)
          .setString('saved_calendar_url', cleanUrl);
      return res;
    }
    return null;
  }

  Future<void> _checkAutoSyncCalendar() async {
    try {
      final settings = ref.read(appSettingsManagerProvider);
      final savedUrl = await settings.getString('saved_calendar_url');
      if (savedUrl != null && savedUrl.trim().isNotEmpty) {
        await _syncFromWebcalUrl(savedUrl.trim(), silent: true);
      }
    } catch (e, st) {
      AppLogger.warning(
        'Falha no auto-sync silencioso do calendário externo',
        e,
        st,
      );
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

  String _generateIcsFile(List<AppointmentEntry> appts) {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//Ministerio Pessoal//Agenda//PT-BR');
    buffer.writeln('CALSCALE:GREGORIAN');
    buffer.writeln('METHOD:PUBLISH');

    String fmt(DateTime dt) {
      final u = dt.toUtc();
      return '${u.year.toString().padLeft(4, "0")}'
          '${u.month.toString().padLeft(2, "0")}'
          '${u.day.toString().padLeft(2, "0")}T'
          '${u.hour.toString().padLeft(2, "0")}'
          '${u.minute.toString().padLeft(2, "0")}'
          '${u.second.toString().padLeft(2, "0")}Z';
    }

    for (final a in appts) {
      if (a.deletedAt != null || a.status == 'cancelado') continue;
      buffer.writeln('BEGIN:VEVENT');
      buffer.writeln('UID:${a.id}@ministeriopessoal.app');
      buffer.writeln('DTSTAMP:${fmt(a.updatedAt)}');
      buffer.writeln('DTSTART:${fmt(a.startTime)}');
      buffer.writeln('DTEND:${fmt(a.endTime)}');
      buffer.writeln('SUMMARY:${a.title.replaceAll("\n", " ")}');
      if (a.locationNotes != null && a.locationNotes!.isNotEmpty) {
        buffer.writeln('LOCATION:${a.locationNotes!.replaceAll("\n", " ")}');
        buffer.writeln(
          'DESCRIPTION:${a.locationNotes!.replaceAll("\n", "\\n")}',
        );
      }
      buffer.writeln(
        'STATUS:${a.status == "realizado" ? "CONFIRMED" : "TENTATIVE"}',
      );
      buffer.writeln('END:VEVENT');
    }

    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  Future<({int created, int updated})> _importIcsContent(String raw) async {
    int createdCount = 0;
    int updatedCount = 0;
    final repo = ref.read(repositoryProvider);
    final existingAppts = await repo.db.select(repo.db.appointments).get();
    final events = IcsCalendarHelper.parseIcsEvents(raw);

    for (final ev in events) {
      AppointmentEntry? existing;
      if (ev.apptId != null) {
        existing = existingAppts.where((a) => a.id == ev.apptId).firstOrNull;
      }
      existing ??= existingAppts.where((a) {
        final sameTitle =
            a.title.trim().toLowerCase() == ev.summary.trim().toLowerCase();
        final timeDiff = a.startTime.difference(ev.startTime).inMinutes.abs();
        return sameTitle && timeDiff < 5;
      }).firstOrNull;

      if (existing != null) {
        await repo.updateAppointment(
          existing.copyWith(
            title: ev.summary,
            startTime: ev.startTime,
            endTime: ev.endTime,
            durationMinutes: ev.durationMinutes,
            status: ev.status,
            locationNotes: Value(ev.location ?? existing.locationNotes),
          ),
        );
        updatedCount++;
      } else {
        await repo.createAppointment(
          id: ev.apptId,
          title: ev.summary,
          startTime: ev.startTime,
          endTime: ev.endTime,
          durationMinutes: ev.durationMinutes,
          status: ev.status,
          locationNotes: ev.location,
        );
        createdCount++;
      }
    }
    return (created: createdCount, updated: updatedCount);
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
          child: const Text('Agenda do Ministério'),
        ),
        bottom: ScreenHeroAccentBand.agenda(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Semantics(
              button: true,
              label: 'Sincronizar calendários conectados',
              child: MediaQuery.of(context).size.width < 500
                  ? IconButton(
                      icon: const Icon(Icons.sync_alt),
                      tooltip: 'Sincronizar Calendários',
                      onPressed: _isCalendarSyncing
                          ? null
                          : _syncConnectedCalendars,
                    )
                  : FilledButton.tonalIcon(
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
                child: LayoutBuilder(
                  builder: (context, boxConstraints) {
                    final isNarrowBanner = boxConstraints.maxWidth < 620;
                    final hoursText = Text(
                      'Programado: ${scheduledHours.toStringAsFixed(1)}h  •  Efetivo: ${actualHours.toStringAsFixed(1)}h${scheduledHours > 0 ? " (${((actualHours / scheduledHours) * 100).toStringAsFixed(0)}% realizado)" : ""}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? const Color(0xFF93C5FD)
                            : const Color(0xFF1E40AF),
                      ),
                      overflow: TextOverflow.ellipsis,
                    );
                    final actionButtons = SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
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
                            onPressed: () => _showMonthlyScheduleCopyWizard(
                              context,
                              allAppts,
                            ),
                          ),
                          const SizedBox(width: 6),
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
                    );

                    if (isNarrowBanner) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.av_timer,
                                size: 18,
                                color: AppTheme.primaryBlue,
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: hoursText),
                            ],
                          ),
                          actionButtons,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        const Icon(
                          Icons.av_timer,
                          size: 18,
                          color: AppTheme.primaryBlue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: hoursText),
                        actionButtons,
                      ],
                    );
                  },
                ),
              ),
            ),
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
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _viewMode == 'Mês'
                                ? _buildMonthCalendarView(activeAppts)
                                : _buildWeekCalendarView(activeAppts),
                          ),
                          VerticalDivider(
                            width: 1,
                            thickness: 1,
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                          ),
                          SizedBox(
                            width: 380,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  color: isDark
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFFF1F5F9),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_view_day,
                                        size: 18,
                                        color: AppTheme.primaryBlue,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Agenda do Dia: ${AppDateUtils.formatDate(_selectedDate)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                Expanded(
                                  child: _buildDayHourlyGridView(activeAppts),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    if (isWide && _viewMode == 'Lista') {
                      final people =
                          ref.watch(peopleStreamProvider).value ?? [];
                      final selectedAppt = _selectedAppointmentId != null
                          ? activeAppts
                                .where((a) => a.id == _selectedAppointmentId)
                                .firstOrNull
                          : null;
                      final selectedPerson = selectedAppt?.personId != null
                          ? people
                                .where((p) => p.id == selectedAppt!.personId)
                                .firstOrNull
                          : null;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 420,
                            child: _buildListView(activeAppts, isWide: true),
                          ),
                          VerticalDivider(
                            width: 1,
                            thickness: 1,
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                          ),
                          Expanded(
                            child: selectedAppt != null
                                ? AppointmentDetailPane(
                                    appt: selectedAppt,
                                    person: selectedPerson,
                                    onReschedule: () => _showRescheduleModal(
                                      context,
                                      selectedAppt,
                                    ),
                                    onMarkDone: () async {
                                      final repo = ref.read(repositoryProvider);
                                      await repo.updateAppointment(
                                        selectedAppt.copyWith(
                                          status: 'realizado',
                                        ),
                                      );
                                    },
                                    onCancelPlanB: () => _cancelAndShowPlanB(
                                      context,
                                      selectedAppt,
                                    ),
                                    onOpenPersonProfile:
                                        selectedAppt.personId != null
                                        ? () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    PersonDetailScreen(
                                                      personId: selectedAppt
                                                          .personId!,
                                                    ),
                                              ),
                                            );
                                          }
                                        : null,
                                    onAddToGoogleCalendar: () =>
                                        _exportToGoogleCalendar(selectedAppt),
                                    onDelete: () =>
                                        _deleteAppointment(selectedAppt),
                                  )
                                : _buildAppointmentPlaceholder(isDark),
                          ),
                        ],
                      );
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

  Widget _buildAppointmentPlaceholder(bool isDark) {
    return Center(
      child: Semantics(
        label: 'Selecione um compromisso para visualizar detalhes',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 52,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'Selecione um compromisso para visualizar detalhes',
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : AppTheme.textMuted,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelAndShowPlanB(
    BuildContext context,
    AppointmentEntry appt,
  ) async {
    final repo = ref.read(repositoryProvider);
    await repo.updateAppointment(appt.copyWith(status: 'cancelado'));

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
  }

  Future<void> _deleteAppointment(AppointmentEntry appt) async {
    final repo = ref.read(repositoryProvider);
    await repo.deleteAppointment(appt.id);
    if (_selectedAppointmentId == appt.id) {
      setState(() => _selectedAppointmentId = null);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compromisso movido para a lixeira.')),
      );
    }
  }
}
