import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../appointments/availability_engine.dart';
import '../providers.dart';

class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen> {
  DateTime _selectedDate = DateTime.now();
  String _viewMode = 'Lista'; // 'Lista', 'Dia', 'Mês'

  void _showNewAppointmentModal(BuildContext context) {
    final titleController = TextEditingController();
    DateTime chosenDate = _selectedDate;
    TimeOfDay chosenTime = const TimeOfDay(hour: 14, minute: 0);
    int durationMinutes = 30;
    String? selectedPersonId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final start = DateTime(chosenDate.year, chosenDate.month, chosenDate.day, chosenTime.hour, chosenTime.minute);
          final existingAppts = ref.read(appointmentsStreamProvider).value ?? [];
          final availability = AvailabilityEngine.checkAvailability(
            startTime: start,
            durationMinutes: durationMinutes,
            existingAppointments: existingAppts,
          );

          final people = ref.read(peopleStreamProvider).value ?? [];

          return AlertDialog(
            title: const Text('Novo Compromisso / Revisita'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Título do compromisso *',
                      hintText: 'Ex: Revisita ou Estudo Bíblico',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (people.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      initialValue: selectedPersonId,
                      decoration: const InputDecoration(labelText: 'Vincular a uma pessoa (opcional)'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Nenhum vínculo')),
                        ...people.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                      ],
                      onChanged: (val) {
                        setDialogState(() {
                          selectedPersonId = val;
                          if (val != null) {
                            final p = people.firstWhere((element) => element.id == val);
                            if (titleController.text.isEmpty) {
                              titleController.text = 'Revisita: ${p.name}';
                            }
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.date_range, size: 16),
                        label: Text(AppDateUtils.formatDate(chosenDate)),
                        onPressed: () async {
                          final p = await showDatePicker(
                            context: context,
                            initialDate: chosenDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (p != null) setDialogState(() => chosenDate = p);
                        },
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.access_time, size: 16),
                        label: Text('${chosenTime.hour.toString().padLeft(2, '0')}:${chosenTime.minute.toString().padLeft(2, '0')}'),
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
                    decoration: const InputDecoration(labelText: 'Duração'),
                    items: const [
                      DropdownMenuItem(value: 15, child: Text('15 min')),
                      DropdownMenuItem(value: 30, child: Text('30 min (Padrão)')),
                      DropdownMenuItem(value: 45, child: Text('45 min')),
                      DropdownMenuItem(value: 60, child: Text('60 min')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => durationMinutes = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Cartão de Checagem em Tempo Real
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: availability.isAvailable ? AppTheme.successGreen.withValues(alpha: 0.1) : AppTheme.alertAmber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: availability.isAvailable ? AppTheme.successGreen : AppTheme.alertAmber,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              availability.isAvailable ? Icons.check_circle : Icons.warning_amber,
                              color: availability.isAvailable ? AppTheme.successGreen : AppTheme.alertAmber,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                availability.message,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: availability.isAvailable ? AppTheme.successGreen : const Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!availability.isAvailable && availability.suggestedAlternativeSlots.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          const Text('Sugestões livres:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          Wrap(
                            spacing: 6,
                            children: availability.suggestedAlternativeSlots.map((s) {
                              return ActionChip(
                                label: Text(AppDateUtils.formatTime(s)),
                                onPressed: () {
                                  setDialogState(() {
                                    chosenDate = s;
                                    chosenTime = TimeOfDay.fromDateTime(s);
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  final title = titleController.text.trim();
                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Informe o título do compromisso.')),
                    );
                    return;
                  }

                  final repo = ref.read(repositoryProvider);
                  await repo.createAppointment(
                    personId: selectedPersonId,
                    title: title,
                    startTime: start,
                    endTime: start.add(Duration(minutes: durationMinutes)),
                    durationMinutes: durationMinutes,
                    status: 'confirmado',
                  );

                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Agendar'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync = ref.watch(appointmentsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda do Ministério'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Hoje',
            onPressed: () {
              setState(() => _selectedDate = DateTime.now());
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Novo Horário'),
        onPressed: () => _showNewAppointmentModal(context),
      ),
      body: Column(
        children: [
          // Seletor de data e modos de visualização
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () {
                        setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
                      },
                    ),
                    Text(
                      AppDateUtils.formatDate(_selectedDate),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () {
                        setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
                      },
                    ),
                  ],
                ),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Lista', label: Text('Lista')),
                    ButtonSegment(value: 'Dia', label: Text('Dia')),
                  ],
                  selected: {_viewMode},
                  onSelectionChanged: (val) {
                    setState(() => _viewMode = val.first);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Lista de compromissos
          Expanded(
            child: appointmentsAsync.when(
              data: (appts) {
                var filtered = appts;
                if (_viewMode == 'Dia') {
                  filtered = appts.where((a) =>
                      a.startTime.day == _selectedDate.day &&
                      a.startTime.month == _selectedDate.month &&
                      a.startTime.year == _selectedDate.year).toList();
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_note, size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            _viewMode == 'Dia'
                                ? 'Nenhum compromisso marcado para ${AppDateUtils.formatDate(_selectedDate)}.'
                                : 'Nenhum compromisso cadastrado na agenda.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final appt = filtered[index];
                    final isDone = appt.status == 'realizado';
                    final isCancelled = appt.status == 'cancelado';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDone
                                ? AppTheme.successGreen.withValues(alpha: 0.1)
                                : isCancelled
                                    ? Colors.grey.shade200
                                    : AppTheme.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                AppDateUtils.formatTime(appt.startTime),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDone ? AppTheme.successGreen : AppTheme.primaryBlue,
                                ),
                              ),
                              Text(
                                '${appt.durationMinutes}m',
                                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                        title: Text(
                          appt.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: isCancelled ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: Text(
                          '${AppDateUtils.formatDate(appt.startTime)} • Status: ${appt.status}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) async {
                            final repo = ref.read(repositoryProvider);
                            if (action == 'realizado') {
                              await repo.updateAppointment(appt.copyWith(status: 'realizado'));
                            } else if (action == 'cancelado') {
                              await repo.updateAppointment(appt.copyWith(status: 'cancelado'));
                            } else if (action == 'nao_realizado') {
                              await repo.updateAppointment(appt.copyWith(status: 'nao_realizado'));
                            }
                          },
                          itemBuilder: (c) => const [
                            PopupMenuItem(value: 'realizado', child: Text('Marcar como Realizado')),
                            PopupMenuItem(value: 'cancelado', child: Text('Marcar como Cancelado')),
                            PopupMenuItem(value: 'nao_realizado', child: Text('Não Realizado')),
                          ],
                        ),
                      ),
                    );
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
