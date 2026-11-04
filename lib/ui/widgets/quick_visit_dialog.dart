import 'package:collection/collection.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../appointments/availability_engine.dart';
import '../../core/feature_registry.dart';
import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../dashboard/counting_rules.dart';
import '../../database/app_database.dart';
import '../../publications/publication_catalog.dart';
import '../providers.dart';
import 'global_appointment_scheduling_section.dart';

/// Diálogo modal bottom sheet para registro rápido de visita e/ou estudo bíblico com toggle retroativo.
class QuickVisitDialog extends ConsumerStatefulWidget {
  final PersonEntry person;
  final BibleStudyEntry? existingStudy;
  final VoidCallback? onSaved;

  const QuickVisitDialog({
    super.key,
    required this.person,
    this.existingStudy,
    this.onSaved,
  });

  static final Map<String, Map<String, dynamic>> quickVisitDrafts = {};

  static Future<void> show({
    required BuildContext context,
    required PersonEntry person,
    BibleStudyEntry? existingStudy,
    VoidCallback? onSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => QuickVisitDialog(
        person: person,
        existingStudy: existingStudy,
        onSaved: onSaved,
      ),
    );
  }

  @override
  ConsumerState<QuickVisitDialog> createState() => _QuickVisitDialogState();
}

class _QuickVisitDialogState extends ConsumerState<QuickVisitDialog> {
  late final TextEditingController _notesController;
  late final TextEditingController _topicsController;
  late final TextEditingController _nextStepController;
  late final TextEditingController _lessonController;
  late final TextEditingController _paragraphsController;

  late String _selectedType;
  late bool _recordStudy;
  late String _selectedResult;
  late String _selectedPublicationId;
  int _attendanceCount = 1;
  bool _scheduleReturn = true;

  // Requisito 4: Toggle de data retroativa
  bool _isRetroactive = false;
  DateTime _selectedDate = DateTime.now();

  late DateTime _returnDateTime;
  late int _returnDuration;
  AppointmentEntry? _existingUpcomingAppt;
  String _freqLabel = 'Semanal';

  @override
  void initState() {
    super.initState();
    final person = widget.person;
    final draft = QuickVisitDialog.quickVisitDrafts[person.id];

    _notesController = TextEditingController(
      text: draft?['notes'] as String? ?? '',
    );
    _topicsController = TextEditingController(
      text: draft?['topics'] as String? ?? '',
    );
    _nextStepController = TextEditingController(
      text: draft?['nextStep'] as String? ?? widget.existingStudy?.nextTopic ?? '',
    );

    _selectedType = draft?['type'] as String? ?? 'revisita';
    _recordStudy = draft?['recordStudy'] as bool? ?? (_selectedType == 'estudo');
    _selectedResult = 'Conversa receptiva';

    _selectedPublicationId = widget.existingStudy?.publicationId ?? 'lff-book';
    _lessonController = TextEditingController(
      text: widget.existingStudy?.currentLesson?.toString() ?? '1',
    );
    _paragraphsController = TextEditingController(
      text: widget.existingStudy?.currentParagraph != null
          ? '${widget.existingStudy!.currentParagraph}'
          : '1-5',
    );

    _notesController.addListener(_updateDraft);
    _topicsController.addListener(_updateDraft);
    _nextStepController.addListener(_updateDraft);

    _initSchedule();
  }

  void _initSchedule() {
    final freq = (widget.existingStudy?.frequency ?? 'semanal').toLowerCase();
    int daysToAdd = 7;
    if (freq.contains('2x') || freq.contains('duas')) {
      _freqLabel = '2x por semana';
      daysToAdd = 3;
    } else if (freq.contains('quinzenal')) {
      _freqLabel = 'Quinzenal';
      daysToAdd = 14;
    } else if (freq.contains('mensal')) {
      _freqLabel = 'Mensal';
      daysToAdd = 28;
    }

    final target = DateTime.now().add(Duration(days: daysToAdd));
    _returnDateTime = DateTime(target.year, target.month, target.day, 10, 0);
    _returnDuration = (_selectedType == 'estudo' || _recordStudy) ? 60 : 30;

    final allApptsList = ref.read(appointmentsStreamProvider).value ?? [];
    final upcomingList = allApptsList
        .where((a) =>
            a.personId == widget.person.id &&
            a.startTime.isAfter(DateTime.now().subtract(const Duration(hours: 1))) &&
            a.status != 'cancelado' &&
            a.deletedAt == null)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (upcomingList.isNotEmpty) {
      _existingUpcomingAppt = upcomingList.first;
      _returnDateTime = upcomingList.first.startTime;
      _returnDuration = upcomingList.first.durationMinutes;
    }
  }

  void _updateDraft() {
    QuickVisitDialog.quickVisitDrafts[widget.person.id] = {
      'notes': _notesController.text,
      'topics': _topicsController.text,
      'nextStep': _nextStepController.text,
      'type': _selectedType,
      'recordStudy': _recordStudy,
    };
  }

  @override
  void dispose() {
    _notesController.dispose();
    _topicsController.dispose();
    _nextStepController.dispose();
    _lessonController.dispose();
    _paragraphsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isStudiesEnabled = ref.watch(isFeatureEnabledProvider(AppFeature.studies));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allAppts = ref.watch(appointmentsStreamProvider).value ?? [];

    return Padding(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      (_selectedType == 'estudo' || _recordStudy)
                          ? Icons.school
                          : Icons.chat_bubble_outline,
                      color: (_selectedType == 'estudo' || _recordStudy)
                          ? const Color(0xFF7C3AED)
                          : AppTheme.primaryBlue,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Registro Rápido: ${widget.person.name}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 20),

            // Tipo de Contato
            SegmentedButton<String>(
              segments: [
                const ButtonSegment(value: 'revisita', label: Text('Revisita')),
                if (isStudiesEnabled)
                  const ButtonSegment(value: 'estudo', label: Text('Estudo Bíblico')),
              ],
              selected: {_selectedType},
              onSelectionChanged: (val) {
                setState(() {
                  _selectedType = val.first;
                  if (_selectedType == 'estudo') {
                    _recordStudy = true;
                    _returnDuration = 60;
                  } else {
                    _returnDuration = 30;
                  }
                  _updateDraft();
                });
              },
            ),
            const SizedBox(height: 12),

            // Requisito 4: Switch de data retroativa
            SwitchListTile.adaptive(
              key: const ValueKey('retroactive_date_toggle'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Registrar com data retroativa', style: TextStyle(fontSize: 14)),
              subtitle: Text(
                _isRetroactive
                    ? 'Data selecionada: ${AppDateUtils.formatDateTime(_selectedDate)}'
                    : 'Padrão: Registrando agora (${AppDateUtils.formatDateTime(DateTime.now())})',
                style: const TextStyle(fontSize: 12),
              ),
              value: _isRetroactive,
              onChanged: (val) {
                setState(() {
                  _isRetroactive = val;
                  if (!val) _selectedDate = DateTime.now();
                });
              },
            ),
            if (_isRetroactive) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('retroactive_date_picker_button'),
                      icon: const Icon(Icons.event, size: 16),
                      label: Text(AppDateUtils.formatDate(_selectedDate)),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedDate = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              _selectedDate.hour,
                              _selectedDate.minute,
                            );
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time, size: 16),
                      label: Text(
                        AppDateUtils.formatTimeOfDay(TimeOfDay.fromDateTime(_selectedDate)),
                      ),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(_selectedDate),
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedDate = DateTime(
                              _selectedDate.year,
                              _selectedDate.month,
                              _selectedDate.day,
                              picked.hour,
                              picked.minute,
                            );
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Se for revisita mas com estudo habilitado, permite marcar 'Considerou matéria de estudo'
            if (isStudiesEnabled && _selectedType == 'revisita') ...[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Considerou matéria de estudo bíblico?'),
                subtitle: const Text(
                  'Gera sessão de estudo bíblico com assistência e atualiza lição',
                  style: TextStyle(fontSize: 12),
                ),
                value: _recordStudy,
                onChanged: (val) {
                  setState(() {
                    _recordStudy = val ?? false;
                    _returnDuration = _recordStudy ? 60 : 30;
                    _updateDraft();
                  });
                },
              ),
              const SizedBox(height: 8),
            ],

            // Campos de Estudo Bíblico se ativo
            if (_selectedType == 'estudo' || _recordStudy) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFDDD6FE),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.school, size: 16, color: Color(0xFF7C3AED)),
                        const SizedBox(width: 6),
                        Text(
                          widget.existingStudy != null
                              ? 'Progresso do Estudo: ${widget.existingStudy!.title}'
                              : 'Iniciar / Registrar Estudo Bíblico',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedPublicationId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Publicação'),
                      items: PublicationCatalog.allPublications.map((p) {
                        return DropdownMenuItem(
                          value: p.id,
                          child: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedPublicationId = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _lessonController,
                            decoration: const InputDecoration(labelText: 'Lição Atual'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _paragraphsController,
                            decoration: const InputDecoration(labelText: 'Pontos / §'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Assistência
                    Row(
                      children: [
                        const Icon(Icons.people_outline, size: 18, color: Color(0xFF7C3AED)),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Assistência (Estudante + Ouvintes):',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 18),
                          onPressed: _attendanceCount > 1
                              ? () => setState(() => _attendanceCount--)
                              : null,
                        ),
                        Text(
                          '$_attendanceCount',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          onPressed: () => setState(() => _attendanceCount++),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            TextField(
              controller: _topicsController,
              decoration: const InputDecoration(
                labelText: 'Ponto Bíblico / Assunto considerado',
                hintText: 'Ex: Mateus 24:14 ou Lição 02',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Anotações da conversa',
                hintText: 'Dúvidas expressas pelo morador, comentários...',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nextStepController,
              decoration: const InputDecoration(
                labelText: 'Próximo passo / Próximo estudo combinado',
                hintText: 'Ex: Responder por que Deus permite o sofrimento',
              ),
            ),
            const SizedBox(height: 14),

            // SEÇÃO DE AGENDAMENTO GLOBAL
            GlobalAppointmentSchedulingSection(
              title: (_selectedType == 'estudo' || _recordStudy)
                  ? 'Agendar Próximo Estudo'
                  : 'Agendar Próximo Retorno',
              isEnabled: _scheduleReturn,
              onToggle: (val) => setState(() => _scheduleReturn = val),
              selectedDateTime: _returnDateTime,
              onDateTimeChanged: (dt) => setState(() => _returnDateTime = dt),
              durationMinutes: _returnDuration,
              onDurationChanged: (dur) => setState(() => _returnDuration = dur),
              existingAppointments: allAppts,
              existingPersonAppointment: _existingUpcomingAppt,
              frequencyText: _freqLabel,
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: (_selectedType == 'estudo' || _recordStudy)
                      ? const Color(0xFF7C3AED)
                      : AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  if (_scheduleReturn) {
                    final availability = AvailabilityEngine.checkAvailability(
                      startTime: _returnDateTime,
                      durationMinutes: _returnDuration,
                      existingAppointments: allAppts,
                    );
                    final proceed =
                        await GlobalAppointmentSchedulingSection.confirmConflictIfNeeded(
                      context: context,
                      availability: availability,
                    );
                    if (!proceed) return;
                  }

                  final isStudyConsidered = _selectedType == 'estudo' || _recordStudy;
                  final repo = ref.read(repositoryProvider);
                  String? appointmentId;

                  final visitTimestamp = _isRetroactive ? _selectedDate : DateTime.now();

                  // 1. Agendamento Global (se ativado)
                  if (_scheduleReturn) {
                    final apptTitle = isStudyConsidered
                        ? 'Estudo Bíblico: ${widget.person.name}'
                        : 'Revisita: ${widget.person.name}';

                    final existingAppts = ref.read(appointmentsStreamProvider).value ?? [];
                    final existingOnDate = existingAppts.firstWhereOrNull(
                      (a) =>
                          a.deletedAt == null &&
                          a.status != 'cancelado' &&
                          a.personId == widget.person.id &&
                          a.startTime.year == _returnDateTime.year &&
                          a.startTime.month == _returnDateTime.month &&
                          a.startTime.day == _returnDateTime.day,
                    );

                    if (existingOnDate != null) {
                      await repo.updateAppointment(
                        existingOnDate.copyWith(
                          studyId: widget.existingStudy != null
                              ? Value(widget.existingStudy!.id)
                              : const Value.absent(),
                          startTime: _returnDateTime,
                          endTime: _returnDateTime.add(Duration(minutes: _returnDuration)),
                          durationMinutes: _returnDuration,
                          status: 'confirmado',
                        ),
                      );
                      appointmentId = existingOnDate.id;
                    } else {
                      final appt = await repo.createAppointment(
                        personId: widget.person.id,
                        studyId: widget.existingStudy?.id,
                        title: apptTitle,
                        startTime: _returnDateTime,
                        endTime: _returnDateTime.add(Duration(minutes: _returnDuration)),
                        durationMinutes: _returnDuration,
                        status: 'confirmado',
                        locationNotes: widget.person.address != null
                            ? 'Local: ${widget.person.address}'
                            : null,
                      );
                      appointmentId = appt.id;
                    }
                  }

                  // 2. Registro da Visita (Atômico)
                  final formattedNotes = isStudyConsidered
                      ? DashboardCalculator.formatSessionNotesWithAttendance(
                          _notesController.text.trim().isEmpty
                              ? null
                              : _notesController.text.trim(),
                          _attendanceCount,
                        )
                      : (_notesController.text.trim().isEmpty
                          ? null
                          : _notesController.text.trim());

                  await repo.createVisit(
                    personId: widget.person.id,
                    dateTime: visitTimestamp,
                    contactType: _selectedType,
                    result: _selectedResult,
                    topicsDiscussed: _topicsController.text.trim().isEmpty
                        ? null
                        : _topicsController.text.trim(),
                    notes: formattedNotes,
                    nextStep: _nextStepController.text.trim().isEmpty
                        ? null
                        : _nextStepController.text.trim(),
                    suggestedReturnDate: _scheduleReturn ? _returnDateTime : null,
                    appointmentId: appointmentId,
                  );

                  // 3. Registro do Estudo e Sessão (se tipo Estudo ou matéria considerada)
                  if (isStudyConsidered) {
                    final lesson = int.tryParse(_lessonController.text.trim()) ?? 1;
                    final paraText = _paragraphsController.text.trim().isEmpty
                        ? '1-5'
                        : _paragraphsController.text.trim();

                    String studyId;
                    if (widget.existingStudy != null) {
                      studyId = widget.existingStudy!.id;
                    } else {
                      final newStudy = await repo.createStudy(
                        title: 'Estudo de ${widget.person.name}',
                        publicationId: _selectedPublicationId,
                        language: 'pt',
                        currentLesson: lesson,
                        currentParagraph: int.tryParse(paraText) ?? 1,
                        participantPersonIds: [widget.person.id],
                        primaryParticipantId: widget.person.id,
                      );
                      studyId = newStudy.id;
                    }

                    await repo.createStudySession(
                      studyId: studyId,
                      dateTime: visitTimestamp,
                      publicationCode: _selectedPublicationId,
                      lessonCovered: lesson,
                      paragraphsCovered: paraText,
                      sessionNotes: formattedNotes,
                      nextStep: _nextStepController.text.trim().isEmpty
                          ? null
                          : _nextStepController.text.trim(),
                      status: 'realizada',
                      participantIds: [widget.person.id],
                    );

                    if (widget.person.status != 'estudo') {
                      await repo.updatePerson(
                        widget.person.copyWith(status: 'estudo'),
                      );
                    }
                  }

                  // Atualiza o lastContactAt da pessoa se a data da visita for mais recente
                  if (widget.person.lastContactAt == null ||
                      visitTimestamp.isAfter(widget.person.lastContactAt!)) {
                    await repo.updatePerson(
                      widget.person.copyWith(lastContactAt: Value(visitTimestamp)),
                    );
                  }

                  QuickVisitDialog.quickVisitDrafts.remove(widget.person.id);
                  widget.onSaved?.call();
                  if (context.mounted) Navigator.pop(context);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isStudyConsidered
                              ? 'Visita, sessão de estudo e agendamento salvos com sucesso!'
                              : 'Visita e agendamento registrados com sucesso!',
                        ),
                      ),
                    );
                  }
                },
                child: Text(
                  (_selectedType == 'estudo' || _recordStudy)
                      ? 'Salvar Visita & Estudo Bíblico'
                      : 'Salvar Visita',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
