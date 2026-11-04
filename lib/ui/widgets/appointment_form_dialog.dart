import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../appointments/availability_engine.dart';
import '../../appointments/calendar_sync_coordinator.dart';
import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../database/app_database.dart';
import '../providers.dart';

/// Modal de criação e reagendamento de compromissos com checagem de colisão e recorrência.
class AppointmentFormDialog extends ConsumerStatefulWidget {
  final DateTime? initialDateTime;
  final AppointmentEntry? existingAppointment;
  final String? initialPersonId;
  final VoidCallback? onSaved;

  const AppointmentFormDialog({
    super.key,
    this.initialDateTime,
    this.existingAppointment,
    this.initialPersonId,
    this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    DateTime? initialDateTime,
    AppointmentEntry? existingAppointment,
    String? initialPersonId,
    VoidCallback? onSaved,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => AppointmentFormDialog(
        initialDateTime: initialDateTime,
        existingAppointment: existingAppointment,
        initialPersonId: initialPersonId,
        onSaved: onSaved,
      ),
    );
  }

  static Future<void> showReschedule(
    BuildContext context, {
    required AppointmentEntry appointment,
    VoidCallback? onSaved,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => AppointmentFormDialog(
        existingAppointment: appointment,
        onSaved: onSaved,
      ),
    );
  }

  @override
  ConsumerState<AppointmentFormDialog> createState() =>
      _AppointmentFormDialogState();
}

class _AppointmentFormDialogState extends ConsumerState<AppointmentFormDialog> {
  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late DateTime _chosenDate;
  late TimeOfDay _chosenTime;
  late int _durationMinutes;
  String? _selectedPersonId;
  String _appointmentCategory = 'Revisita';
  String _recurrence = 'Único';
  int _recurrenceCount = 8;
  bool _respectAvailability = true;

  bool get _isReschedule => widget.existingAppointment != null;

  @override
  void initState() {
    super.initState();
    final appt = widget.existingAppointment;
    if (appt != null) {
      _titleController = TextEditingController(text: appt.title);
      _locationController = TextEditingController(text: appt.locationNotes ?? '');
      _chosenDate = appt.startTime.add(const Duration(days: 7));
      _chosenTime = TimeOfDay.fromDateTime(appt.startTime);
      _durationMinutes = appt.durationMinutes;
      _selectedPersonId = appt.personId;
    } else {
      _titleController = TextEditingController();
      _locationController = TextEditingController();
      final initDt = widget.initialDateTime ?? DateTime.now();
      _chosenDate = initDt;
      _chosenTime = widget.initialDateTime != null
          ? TimeOfDay(hour: initDt.hour, minute: initDt.minute)
          : const TimeOfDay(hour: 14, minute: 0);
      _durationMinutes = 30;
      _selectedPersonId = widget.initialPersonId;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _triggerBackgroundCalendarSync() {
    ref.read(calendarSyncCoordinatorProvider).syncAll().ignore();
  }

  @override
  Widget build(BuildContext context) {
    if (_isReschedule) {
      return _buildRescheduleDialog(context);
    }
    return _buildNewAppointmentDialog(context);
  }

  Widget _buildRescheduleDialog(BuildContext context) {
    final appt = widget.existingAppointment!;
    final start = DateTime(
      _chosenDate.year,
      _chosenDate.month,
      _chosenDate.day,
      _chosenTime.hour,
      _chosenTime.minute,
    );
    final existingAppts = ref.watch(appointmentsStreamProvider).value ?? [];
    final availability = AvailabilityEngine.checkAvailability(
      startTime: start,
      durationMinutes: _durationMinutes,
      existingAppointments: existingAppts,
      excludeAppointmentId: appt.id,
    );

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.sync_alt, color: AppTheme.primaryBlue),
          SizedBox(width: 8),
          Text('Reagendar Compromisso'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              appt.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Anterior: ${AppDateUtils.formatDateTime(appt.startTime)}',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range, size: 16),
                  label: Text(AppDateUtils.formatDate(_chosenDate)),
                  onPressed: () async {
                    final p = await showDatePicker(
                      context: context,
                      initialDate: _chosenDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (p != null) setState(() => _chosenDate = p);
                  },
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.access_time, size: 16),
                  label: Text(
                    '${_chosenTime.hour.toString().padLeft(2, '0')}:${_chosenTime.minute.toString().padLeft(2, '0')}',
                  ),
                  onPressed: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: _chosenTime,
                    );
                    if (t != null) setState(() => _chosenTime = t);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
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
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      availability.message,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () async {
            final repo = ref.read(repositoryProvider);
            await repo.rescheduleAppointment(
              oldAppointment: appt,
              newStartTime: start,
              newEndTime: start.add(Duration(minutes: _durationMinutes)),
            );
            _triggerBackgroundCalendarSync();
            widget.onSaved?.call();
            if (context.mounted) Navigator.pop(context);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Compromisso reagendado com sucesso! Histórico preservado.',
                  ),
                ),
              );
            }
          },
          child: const Text('Confirmar Reagendamento'),
        ),
      ],
    );
  }

  Widget _buildNewAppointmentDialog(BuildContext context) {
    final start = DateTime(
      _chosenDate.year,
      _chosenDate.month,
      _chosenDate.day,
      _chosenTime.hour,
      _chosenTime.minute,
    );
    final existingAppts = ref.watch(appointmentsStreamProvider).value ?? [];
    final availability = AvailabilityEngine.checkAvailability(
      startTime: start,
      durationMinutes: _durationMinutes,
      existingAppointments: existingAppts,
    );

    final people = ref.watch(peopleStreamProvider).value ?? [];

    final occurrences = <DateTime>[start];
    if (_recurrence != 'Único') {
      for (int i = 1; i < _recurrenceCount; i++) {
        if (_recurrence == 'Semanal' || _recurrence == 'Toda semana') {
          occurrences.add(start.add(Duration(days: i * 7)));
        } else if (_recurrence == 'Quinzenal' ||
            _recurrence == 'A cada 15 dias') {
          occurrences.add(start.add(Duration(days: i * 14)));
        } else if (_recurrence == '2x por semana') {
          final daysOffset = (i ~/ 2) * 7 + (i % 2 == 1 ? 3 : 0);
          occurrences.add(start.add(Duration(days: daysOffset)));
        } else if (_recurrence == 'Mensal') {
          final targetMonth = start.month + i;
          final yearOffset = (targetMonth - 1) ~/ 12;
          final month = ((targetMonth - 1) % 12) + 1;
          final year = start.year + yearOffset;
          final daysInMonth = DateTime(year, month + 1, 0).day;
          final day = start.day.clamp(1, daysInMonth);
          occurrences.add(DateTime(year, month, day, start.hour, start.minute));
        } else if (_recurrence == 'A cada 2 meses') {
          final targetMonth = start.month + (i * 2);
          final yearOffset = (targetMonth - 1) ~/ 12;
          final month = ((targetMonth - 1) % 12) + 1;
          final year = start.year + yearOffset;
          final daysInMonth = DateTime(year, month + 1, 0).day;
          final day = start.day.clamp(1, daysInMonth);
          occurrences.add(DateTime(year, month, day, start.hour, start.minute));
        }
      }
    }

    int recurrenceConflicts = 0;
    if (_recurrence != 'Único') {
      for (final occ in occurrences) {
        if (AvailabilityEngine.hasCollision(
          start: occ,
          end: occ.add(Duration(minutes: _durationMinutes)),
          existingAppointments: existingAppts,
        )) {
          recurrenceConflicts++;
        }
      }
    }

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.event, color: AppTheme.primaryBlue),
          SizedBox(width: 8),
          Text('Novo Compromisso'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _appointmentCategory,
              decoration: const InputDecoration(labelText: 'Tipo de Compromisso'),
              items: const [
                DropdownMenuItem(
                  value: 'Serviço de Campo',
                  child: Text('🚶 Saída de Campo / Testemunho'),
                ),
                DropdownMenuItem(value: 'Revisita', child: Text('🔄 Revisita')),
                DropdownMenuItem(
                  value: 'Estudo Bíblico',
                  child: Text('📖 Estudo Bíblico'),
                ),
                DropdownMenuItem(
                  value: 'Reunião',
                  child: Text('🏛️ Reunião Congregacional'),
                ),
                DropdownMenuItem(
                  value: 'Viagem',
                  child: Text('✈️ Viagem (Bloqueio de Agenda)'),
                ),
                DropdownMenuItem(
                  value: 'Folga',
                  child: Text('🏖️ Folga / Descanso (Bloqueio de Agenda)'),
                ),
                DropdownMenuItem(
                  value: 'Ausência',
                  child: Text('🚫 Ausência / Indisponível'),
                ),
                DropdownMenuItem(
                  value: 'Pessoal',
                  child: Text('👤 Pessoal (Médico, Família, Trabalho)'),
                ),
                DropdownMenuItem(
                  value: 'Outro',
                  child: Text('📌 Outro Compromisso'),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _appointmentCategory = val;
                    if (_titleController.text.isEmpty) {
                      if (val == 'Pessoal') {
                        _titleController.text = 'Compromisso Pessoal';
                      }
                      if (val == 'Reunião') {
                        _titleController.text = 'Reunião Congregacional';
                      }
                      if (val == 'Serviço de Campo') {
                        _titleController.text = 'Saída de Campo';
                      }
                      if (val == 'Viagem') _titleController.text = 'Viagem';
                      if (val == 'Folga') _titleController.text = 'Folga';
                      if (val == 'Ausência') {
                        _titleController.text = 'Ausência Programada';
                      }
                    }
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Título do Compromisso',
                hintText: 'Ex: Estudo com João, Saída no Carrinho...',
              ),
            ),
            const SizedBox(height: 12),
            if (_appointmentCategory == 'Revisita' ||
                _appointmentCategory == 'Estudo Bíblico') ...[
              DropdownButtonFormField<String?>(
                initialValue: _selectedPersonId,
                decoration: const InputDecoration(
                  labelText: 'Vincular a uma Pessoa / Contato',
                  helperText:
                      'Opcional. Permite registrar revisita e abrir ficha.',
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Nenhum (Compromisso Geral)'),
                  ),
                  ...people.map(
                    (p) => DropdownMenuItem(
                      value: p.id,
                      child: Text(
                        '${p.name} (${p.status})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedPersonId = val;
                    if (val != null && _titleController.text.isEmpty) {
                      final p = people.firstWhere((element) => element.id == val);
                      _titleController.text =
                          '$_appointmentCategory: ${p.name}';
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.date_range, size: 16),
                    label: Text(AppDateUtils.formatDate(_chosenDate)),
                    onPressed: () async {
                      final p = await showDatePicker(
                        context: context,
                        initialDate: _chosenDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (p != null) setState(() => _chosenDate = p);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.access_time, size: 16),
                    label: Text(
                      '${_chosenTime.hour.toString().padLeft(2, '0')}:${_chosenTime.minute.toString().padLeft(2, '0')}',
                    ),
                    onPressed: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: _chosenTime,
                      );
                      if (t != null) setState(() => _chosenTime = t);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    initialValue: _recurrence,
                    decoration: const InputDecoration(
                      labelText: 'Repetição / Recorrência',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Único',
                        child: Text('Apenas uma vez (Não repete)'),
                      ),
                      DropdownMenuItem(
                        value: 'Semanal',
                        child: Text('Semanal (Toda semana)'),
                      ),
                      DropdownMenuItem(
                        value: 'Quinzenal',
                        child: Text('Quinzenal (A cada 15 dias)'),
                      ),
                      DropdownMenuItem(
                        value: '2x por semana',
                        child: Text('2 vezes por semana'),
                      ),
                      DropdownMenuItem(
                        value: 'Mensal',
                        child: Text('Mensal (Mesmo dia do mês)'),
                      ),
                      DropdownMenuItem(
                        value: 'A cada 2 meses',
                        child: Text('Bimestral (A cada 2 meses)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _recurrence = val);
                    },
                  ),
                ),
                if (_recurrence != 'Único') ...[
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<int>(
                      initialValue: _recurrenceCount,
                      decoration: const InputDecoration(labelText: 'Repetir'),
                      items: const [
                        DropdownMenuItem(value: 2, child: Text('2 vezes')),
                        DropdownMenuItem(value: 4, child: Text('4 vezes')),
                        DropdownMenuItem(value: 8, child: Text('8 vezes')),
                        DropdownMenuItem(value: 12, child: Text('12 vezes')),
                        DropdownMenuItem(value: 24, child: Text('24 vezes')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _recurrenceCount = val);
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _durationMinutes,
              decoration: const InputDecoration(labelText: 'Duração Estimada'),
              items: const [
                DropdownMenuItem(value: 15, child: Text('15 minutos')),
                DropdownMenuItem(value: 20, child: Text('20 minutos')),
                DropdownMenuItem(value: 30, child: Text('30 minutos')),
                DropdownMenuItem(value: 45, child: Text('45 minutos')),
                DropdownMenuItem(value: 60, child: Text('1 hora (60 min)')),
                DropdownMenuItem(
                  value: 90,
                  child: Text('1 hora e meia (90 min)'),
                ),
                DropdownMenuItem(value: 120, child: Text('2 horas (120 min)')),
                DropdownMenuItem(value: 180, child: Text('3 horas (180 min)')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _durationMinutes = val);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Local ou Detalhes / Observações',
                hintText: 'Ex: Na casa do morador, Salão do Reino...',
              ),
            ),
            const SizedBox(height: 16),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        availability.isAvailable
                            ? Icons.check_circle
                            : Icons.warning_amber,
                        color: availability.isAvailable
                            ? AppTheme.successGreen
                            : AppTheme.alertAmber,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          availability.message,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: availability.isAvailable
                                ? AppTheme.successGreen
                                : const Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (availability.conflictingAppointments.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Conflito com: ${availability.conflictingAppointments.map((a) => a.title).join(", ")}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ],
                  if (_recurrence != 'Único') ...[
                    const SizedBox(height: 6),
                    Text(
                      'Recorrência: ${occurrences.length} datas programadas'
                      '${recurrenceConflicts > 0 ? " ($recurrenceConflicts com conflito de horário)" : ""}.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: recurrenceConflicts > 0
                            ? const Color(0xFFB45309)
                            : AppTheme.successGreen,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!availability.isAvailable) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.lightbulb_outline, size: 16),
                label: const Text('Verificar sugestões de horários livres'),
                onPressed: () {
                  final suggestions = availability.suggestedAlternativeSlots;
                  if (suggestions.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Nenhum horário livre encontrado nesta data.',
                        ),
                      ),
                    );
                    return;
                  }
                  showModalBottomSheet(
                    context: context,
                    builder: (sheetCtx) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const ListTile(
                            leading: Icon(
                              Icons.schedule,
                              color: AppTheme.primaryBlue,
                            ),
                            title: Text(
                              'Horários Livres Sugeridos',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text('Toque em um horário para aplicar'),
                          ),
                          ...suggestions.map(
                            (slot) => ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.check,
                                color: AppTheme.successGreen,
                                size: 16,
                              ),
                              title: Text(
                                '${slot.hour.toString().padLeft(2, '0')}:${slot.minute.toString().padLeft(2, '0')} até '
                                '${slot.add(Duration(minutes: _durationMinutes)).hour.toString().padLeft(2, '0')}:${slot.add(Duration(minutes: _durationMinutes)).minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onTap: () {
                                Navigator.pop(sheetCtx);
                                setState(() {
                                  _chosenTime = TimeOfDay(
                                    hour: slot.hour,
                                    minute: slot.minute,
                                  );
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
            if (_recurrence != 'Único') ...[
              const SizedBox(height: 4),
              CheckboxListTile(
                value: _respectAvailability,
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: AppTheme.primaryBlue,
                title: const Text(
                  'Ignorar ocorrências que colidirem com outros compromissos',
                  style: TextStyle(fontSize: 12),
                ),
                onChanged: (val) {
                  setState(() => _respectAvailability = val ?? true);
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: availability.isAvailable
                ? AppTheme.primaryBlue
                : AppTheme.alertAmber,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            final title = _titleController.text.trim().isEmpty
                ? _appointmentCategory
                : _titleController.text.trim();

            if (!availability.isAvailable && occurrences.length == 1) {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (confirmCtx) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.warning, color: AppTheme.alertAmber),
                      SizedBox(width: 8),
                      Text('Conflito de Horário'),
                    ],
                  ),
                  content: Text(
                    'Já existe um compromisso agendado neste mesmo intervalo:\n'
                    '${availability.conflictingAppointments.map((a) => a.title).join(", ")}\n\n'
                    'Deseja agendar mesmo assim?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(confirmCtx, false),
                      child: const Text('Voltar e Ajustar'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.alertAmber,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(confirmCtx, true),
                      child: const Text('Agendar Mesmo Assim'),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
            }

            final repo = ref.read(repositoryProvider);
            int createdCount = 0;
            int skippedCount = 0;
            final runningAppts = List<AppointmentEntry>.from(existingAppts);

            for (final occ in occurrences) {
              final occEnd = occ.add(Duration(minutes: _durationMinutes));
              final hasConflict = AvailabilityEngine.hasCollision(
                start: occ,
                end: occEnd,
                existingAppointments: runningAppts,
              );

              if (hasConflict &&
                  _respectAvailability &&
                  occurrences.length > 1) {
                skippedCount++;
                continue;
              }

              final newEntry = await repo.createAppointment(
                personId: _selectedPersonId,
                title: title,
                startTime: occ,
                endTime: occEnd,
                durationMinutes: _durationMinutes,
                status: 'confirmado',
                locationNotes: _locationController.text.trim().isEmpty
                    ? null
                    : _locationController.text.trim(),
              );
              runningAppts.add(newEntry);
              createdCount++;
            }

            _triggerBackgroundCalendarSync();
            widget.onSaved?.call();

            if (context.mounted) Navigator.pop(context);
            if (context.mounted) {
              final message = occurrences.length == 1
                  ? 'Compromisso agendado no calendário com sucesso!'
                  : '$createdCount compromisso(s) recorrente(s) agendado(s)!${skippedCount > 0 ? " ($skippedCount pulado(s) por conflito)" : ""}';
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(message)));
            }
          },
          child: const Text('Salvar no Calendário'),
        ),
      ],
    );
  }
}
