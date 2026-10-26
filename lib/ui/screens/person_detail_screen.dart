import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../database/app_database.dart';
import '../../appointments/availability_engine.dart';
import '../providers.dart';

class PersonDetailScreen extends ConsumerStatefulWidget {
  final String personId;

  const PersonDetailScreen({super.key, required this.personId});

  @override
  ConsumerState<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends ConsumerState<PersonDetailScreen> {
  // Modal de Registro Rápido de Revisita (Fluxo de menos de 5 toques para o campo)
  void _showQuickVisitDialog(BuildContext context, PersonEntry person) {
    final notesController = TextEditingController();
    final topicsController = TextEditingController();
    final nextStepController = TextEditingController();
    String selectedType = 'revisita';
    String selectedResult = 'Conversa receptiva';
    DateTime selectedDate = DateTime.now();
    DateTime? suggestedReturnDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 16,
            right: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Registrar Visita com ${person.name}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Tipo de Contato'),
                  items: const [
                    DropdownMenuItem(value: 'revisita', child: Text('Revisita Presencial')),
                    DropdownMenuItem(value: 'conversa_inicial', child: Text('Conversa Inicial')),
                    DropdownMenuItem(value: 'estudo', child: Text('Estudo Bíblico')),
                    DropdownMenuItem(value: 'contato_telefonico', child: Text('Contato Telefônico / Carta')),
                    DropdownMenuItem(value: 'tentativa_sem_contato', child: Text('Tentativa sem Contato (Não contou)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setSheetState(() => selectedType = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: topicsController,
                  decoration: const InputDecoration(
                    labelText: 'Ponto Bíblico / Assunto considerado',
                    hintText: 'Ex: Mateus 24:14 ou Lição 02',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Anotações da conversa',
                    hintText: 'Dúvidas expressas pelo morador, comentários...',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nextStepController,
                  decoration: const InputDecoration(
                    labelText: 'Próximo passo combinado',
                    hintText: 'Ex: Responder por que Deus permite o sofrimento',
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event, color: AppTheme.primaryBlue),
                  title: Text(
                    suggestedReturnDate != null
                        ? 'Retorno sugerido: ${AppDateUtils.formatDate(suggestedReturnDate)}'
                        : 'Data sugerida para retorno (opcional)',
                    style: const TextStyle(fontSize: 14),
                  ),
                  trailing: const Icon(Icons.edit_calendar),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setSheetState(() => suggestedReturnDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final repo = ref.read(repositoryProvider);
                      await repo.createVisit(
                        personId: person.id,
                        dateTime: selectedDate,
                        contactType: selectedType,
                        result: selectedResult,
                        topicsDiscussed: topicsController.text.trim().isEmpty ? null : topicsController.text.trim(),
                        notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                        nextStep: nextStepController.text.trim().isEmpty ? null : nextStepController.text.trim(),
                        suggestedReturnDate: suggestedReturnDate,
                      );

                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Visita registrada com sucesso! Histórico atualizado.')),
                        );
                      }
                    },
                    child: const Text('Salvar Visita'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Modal de Agendamento Tipo Consultório (com Verificação Instantânea de Conflitos)
  void _showScheduleDialog(BuildContext context, PersonEntry person) {
    DateTime selectedDateTime = DateTime.now().add(const Duration(days: 1, hours: 2));
    // Normaliza para início de hora/meia hora
    selectedDateTime = DateTime(
      selectedDateTime.year,
      selectedDateTime.month,
      selectedDateTime.day,
      selectedDateTime.hour,
      selectedDateTime.minute < 30 ? 0 : 30,
    );

    int durationMinutes = 30;
    AvailabilityResult? currentAvailability;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Checagem de disponibilidade
          final allAppts = ref.read(appointmentsStreamProvider).value ?? [];
          currentAvailability = AvailabilityEngine.checkAvailability(
            startTime: selectedDateTime,
            durationMinutes: durationMinutes,
            existingAppointments: allAppts,
          );

          return AlertDialog(
            title: Text('Agendar Revisita: ${person.name}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data: ${AppDateUtils.formatDate(selectedDateTime)} às ${AppDateUtils.formatTime(selectedDateTime)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.date_range, size: 16),
                        label: const Text('Alterar Data'),
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDateTime,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setDialogState(() {
                              selectedDateTime = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                selectedDateTime.hour,
                                selectedDateTime.minute,
                              );
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.access_time, size: 16),
                        label: const Text('Hora'),
                        onPressed: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                          );
                          if (time != null) {
                            setDialogState(() {
                              selectedDateTime = DateTime(
                                selectedDateTime.year,
                                selectedDateTime.month,
                                selectedDateTime.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: durationMinutes,
                    decoration: const InputDecoration(labelText: 'Duração estimada'),
                    items: const [
                      DropdownMenuItem(value: 15, child: Text('15 minutos (Rápida)')),
                      DropdownMenuItem(value: 30, child: Text('30 minutos (Padrão)')),
                      DropdownMenuItem(value: 45, child: Text('45 minutos')),
                      DropdownMenuItem(value: 60, child: Text('1 hora (Estudo)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => durationMinutes = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Indicador de Disponibilidade / Conflito
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: currentAvailability!.isAvailable
                          ? AppTheme.successGreen.withValues(alpha: 0.1)
                          : AppTheme.alertAmber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: currentAvailability!.isAvailable
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
                              currentAvailability!.isAvailable ? Icons.check_circle : Icons.warning_amber,
                              color: currentAvailability!.isAvailable ? AppTheme.successGreen : AppTheme.alertAmber,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                currentAvailability!.message,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: currentAvailability!.isAvailable
                                      ? AppTheme.successGreen
                                      : const Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!currentAvailability!.isAvailable &&
                            currentAvailability!.suggestedAlternativeSlots.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Horários alternativos sugeridos:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            children: currentAvailability!.suggestedAlternativeSlots.map((slot) {
                              return ActionChip(
                                label: Text('${AppDateUtils.formatDate(slot)} ${AppDateUtils.formatTime(slot)}'),
                                onPressed: () {
                                  setDialogState(() => selectedDateTime = slot);
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
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: currentAvailability!.isAvailable ? AppTheme.primaryBlue : AppTheme.alertAmber,
                ),
                onPressed: () async {
                  if (!currentAvailability!.isAvailable) {
                    final proceed = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Atenção: Horário em Conflito'),
                        content: const Text(
                          'Há outro compromisso agendado neste mesmo intervalo. Deseja mesmo confirmar e gerar sobreposição?',
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Não')),
                          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sim, Confirmar')),
                        ],
                      ),
                    );
                    if (proceed != true) return;
                  }

                  final repo = ref.read(repositoryProvider);
                  await repo.createAppointment(
                    personId: person.id,
                    title: 'Revisita: ${person.name}',
                    startTime: selectedDateTime,
                    endTime: selectedDateTime.add(Duration(minutes: durationMinutes)),
                    durationMinutes: durationMinutes,
                    status: 'confirmado',
                  );

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Compromisso agendado na agenda com sucesso!')),
                    );
                  }
                },
                child: const Text('Confirmar Agendamento'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);

    return FutureBuilder<PersonEntry?>(
      future: repo.getPersonById(widget.personId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final person = snapshot.data!;

        return Scaffold(
          appBar: AppBar(
            title: Text(person.name),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card de Identificação e Contato
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                              child: Text(
                                person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    person.name,
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Primeiro contato: ${AppDateUtils.formatDate(person.firstContactAt)}',
                                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        if (person.phone != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.phone, size: 18, color: AppTheme.textMuted),
                              const SizedBox(width: 8),
                              Text(person.phone!, style: const TextStyle(fontSize: 15)),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (person.address != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 18, color: AppTheme.textMuted),
                              const SizedBox(width: 8),
                              Expanded(child: Text(person.address!, style: const TextStyle(fontSize: 15))),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (person.generalNotes != null) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.notes, size: 18, color: AppTheme.textMuted),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  person.generalNotes!,
                                  style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Botões de Ação Imediata de Campo
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.rate_review_outlined),
                        label: const Text('Registrar Conversa'),
                        onPressed: () => _showQuickVisitDialog(context, person),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_calendar),
                        label: const Text('Agendar Retorno'),
                        onPressed: () => _showScheduleDialog(context, person),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Histórico Cronológico de Conversas e Revisitas
                const Text(
                  'Histórico de Visitas e Conversas',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
                const SizedBox(height: 8),

                StreamBuilder<List<VisitEntry>>(
                  stream: repo.watchVisitsForPerson(person.id),
                  builder: (context, visitSnapshot) {
                    final visits = visitSnapshot.data ?? [];
                    if (visits.isEmpty) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Center(
                            child: Text(
                              'Nenhuma visita registrada ainda para ${person.name}.\nToque em "Registrar Conversa" após falar com a pessoa.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppTheme.textMuted),
                            ),
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: visits.map((v) {
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
                                      AppDateUtils.formatDateTime(v.dateTimeField),
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                                    ),
                                    Chip(
                                      label: Text(v.contactType, style: const TextStyle(fontSize: 11)),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ],
                                ),
                                if (v.topicsDiscussed != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Assunto: ${v.topicsDiscussed}',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ],
                                if (v.notes != null) ...[
                                  const SizedBox(height: 4),
                                  Text(v.notes!, style: const TextStyle(color: AppTheme.textMuted)),
                                ],
                                if (v.nextStep != null) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Próximo passo: ${v.nextStep}',
                                      style: const TextStyle(fontSize: 12, color: AppTheme.primaryBlue),
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
          ),
        );
      },
    );
  }
}
