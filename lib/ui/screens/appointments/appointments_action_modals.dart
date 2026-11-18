part of '../appointments_screen.dart';

extension _AppointmentsActionModals on _AppointmentsScreenState {
  void _showNewAppointmentModal(
    BuildContext context, {
    DateTime? initialDateTime,
  }) {
    DateTime chosenDate = initialDateTime ?? _selectedDate;
    TimeOfDay chosenTime = initialDateTime != null
        ? TimeOfDay(hour: initialDateTime.hour, minute: initialDateTime.minute)
        : const TimeOfDay(hour: 14, minute: 0);
    int durationMinutes = 30;
    String? selectedPersonId;
    String appointmentCategory = 'Revisita';
    String recurrence = 'Único';
    int recurrenceCount = 8;
    bool respectAvailability = true;

    showDialog(
      context: context,
      builder: (ctx) => ManagedTextControllers(
        initialTexts: const ['', ''],
        builder: (ctx, ctrls) {
          final titleController = ctrls[0];
          final locationController = ctrls[1];

          return StatefulBuilder(
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

              final people = ref.read(peopleStreamProvider).value ?? [];

              final occurrences = <DateTime>[start];
              if (recurrence != 'Único') {
                for (int i = 1; i < recurrenceCount; i++) {
                  if (recurrence == 'Semanal' || recurrence == 'Toda semana') {
                    occurrences.add(start.add(Duration(days: i * 7)));
                  } else if (recurrence == 'Quinzenal' ||
                      recurrence == 'A cada 15 dias') {
                    occurrences.add(start.add(Duration(days: i * 14)));
                  } else if (recurrence == '2x por semana') {
                    final daysOffset = (i ~/ 2) * 7 + (i % 2 == 1 ? 3 : 0);
                    occurrences.add(start.add(Duration(days: daysOffset)));
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
                  } else if (recurrence == 'A cada 2 meses') {
                    final targetMonth = start.month + (i * 2);
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

              int recurrenceConflicts = 0;
              if (recurrence != 'Único') {
                for (final occ in occurrences) {
                  if (AvailabilityEngine.hasCollision(
                    start: occ,
                    end: occ.add(Duration(minutes: durationMinutes)),
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
                        initialValue: appointmentCategory,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de Compromisso',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Serviço de Campo',
                            child: Text('🚶 Saída de Campo / Testemunho'),
                          ),
                          DropdownMenuItem(
                            value: 'Revisita',
                            child: Text('🔄 Revisita'),
                          ),
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
                            child: Text(
                              '🏖️ Folga / Descanso (Bloqueio de Agenda)',
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'Ausência',
                            child: Text('🚫 Ausência / Indisponível'),
                          ),
                          DropdownMenuItem(
                            value: 'Pessoal',
                            child: Text(
                              '👤 Pessoal (Médico, Família, Trabalho)',
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'Outro',
                            child: Text('📌 Outro Compromisso'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              appointmentCategory = val;
                              if (titleController.text.isEmpty) {
                                if (val == 'Pessoal') {
                                  titleController.text = 'Compromisso Pessoal';
                                }
                                if (val == 'Reunião') {
                                  titleController.text =
                                      'Reunião Congregacional';
                                }
                                if (val == 'Serviço de Campo') {
                                  titleController.text = 'Saída de Campo';
                                }
                                if (val == 'Viagem') {
                                  titleController.text = 'Viagem';
                                }
                                if (val == 'Folga')
                                  titleController.text = 'Folga';
                                if (val == 'Ausência') {
                                  titleController.text = 'Ausência';
                                }
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: 'Título do compromisso *',
                          hintText: appointmentCategory == 'Pessoal'
                              ? 'Ex: Consulta médica ou Banco'
                              : 'Ex: Revisita ou Estudo Bíblico',
                        ),
                        autofocus: true,
                      ),
                      const SizedBox(height: 12),
                      if (people.isNotEmpty) ...[
                        DropdownButtonFormField<String?>(
                          initialValue: selectedPersonId,
                          decoration: const InputDecoration(
                            labelText: 'Contato Cadastrado (opcional)',
                            prefixIcon: Icon(Icons.person_outline, size: 20),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Nenhum vínculo'),
                            ),
                            ...people.map(
                              (p) => DropdownMenuItem<String?>(
                                value: p.id,
                                child: Text(p.name),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            setDialogState(() {
                              selectedPersonId = val;
                              if (val != null) {
                                final p = people.firstWhere(
                                  (element) => element.id == val,
                                );
                                if (titleController.text.isEmpty ||
                                    titleController.text == 'Revisita' ||
                                    titleController.text == 'Estudo Bíblico') {
                                  titleController.text =
                                      '${appointmentCategory == "Estudo Bíblico" ? "Estudo" : "Revisita"}: ${p.name}';
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
                                firstDate: DateTime.now().subtract(
                                  const Duration(days: 30),
                                ),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (p != null)
                                setDialogState(() => chosenDate = p);
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
                              if (t != null)
                                setDialogState(() => chosenTime = t);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: durationMinutes,
                        decoration: const InputDecoration(
                          labelText: 'Duração estimada',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 15,
                            child: Text('15 min (Rápida)'),
                          ),
                          DropdownMenuItem(
                            value: 30,
                            child: Text('30 min (Padrão)'),
                          ),
                          DropdownMenuItem(value: 45, child: Text('45 min')),
                          DropdownMenuItem(
                            value: 60,
                            child: Text('60 min (1 hora)'),
                          ),
                          DropdownMenuItem(
                            value: 90,
                            child: Text('90 min (1h 30m)'),
                          ),
                          DropdownMenuItem(
                            value: 120,
                            child: Text('120 min (2 horas)'),
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
                            value: '2x por semana',
                            child: Text('2x por semana'),
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
                            value: 'Mensal',
                            child: Text('Mensal (a cada mês)'),
                          ),
                          DropdownMenuItem(
                            value: 'A cada 2 meses',
                            child: Text('A cada 2 meses (Bimestral)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null)
                            setDialogState(() => recurrence = val);
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
                              child: Text('4 ocorrências'),
                            ),
                            DropdownMenuItem(
                              value: 8,
                              child: Text('8 ocorrências'),
                            ),
                            DropdownMenuItem(
                              value: 12,
                              child: Text('12 ocorrências'),
                            ),
                            DropdownMenuItem(
                              value: 16,
                              child: Text('16 ocorrências'),
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
                          labelText: 'Local ou observação',
                          hintText: 'Ex: Salão do Reino / Casa do estudante / Pessoal',
                        ),
                      ),
                      const SizedBox(height: 14),

                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:
                              (recurrence == 'Único'
                                  ? availability.isAvailable
                                  : recurrenceConflicts == 0)
                              ? AppTheme.successGreen.withValues(alpha: 0.1)
                              : AppTheme.alertAmber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                (recurrence == 'Único'
                                    ? availability.isAvailable
                                    : recurrenceConflicts == 0)
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
                                  (recurrence == 'Único'
                                          ? availability.isAvailable
                                          : recurrenceConflicts == 0)
                                      ? Icons.check_circle
                                      : Icons.warning_amber,
                                  color:
                                      (recurrence == 'Único'
                                          ? availability.isAvailable
                                          : recurrenceConflicts == 0)
                                      ? AppTheme.successGreen
                                      : AppTheme.alertAmber,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    recurrence == 'Único'
                                        ? availability.message
                                        : recurrenceConflicts == 0
                                        ? 'Todas as ${occurrences.length} datas estão 100% livres!'
                                        : 'Atenção: $recurrenceConflicts de ${occurrences.length} datas possuem sobreposição!',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color:
                                          (recurrence == 'Único'
                                              ? availability.isAvailable
                                              : recurrenceConflicts == 0)
                                          ? AppTheme.successGreen
                                          : const Color(0xFF92400E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (recurrence == 'Único' &&
                                !availability.isAvailable &&
                                availability
                                    .suggestedAlternativeSlots
                                    .isNotEmpty) ...[
                              const SizedBox(height: 6),
                              const Text(
                                'Sugestões livres:',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Wrap(
                                spacing: 6,
                                children: availability.suggestedAlternativeSlots
                                    .map((s) {
                                      return ActionChip(
                                        label: Text(AppDateUtils.formatTime(s)),
                                        onPressed: () {
                                          setDialogState(() {
                                            chosenDate = s;
                                            chosenTime = TimeOfDay.fromDateTime(
                                              s,
                                            );
                                          });
                                        },
                                      );
                                    })
                                    .toList(),
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
                    onPressed: () async {
                      final title = titleController.text.trim();
                      if (title.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Informe o título do compromisso.'),
                          ),
                        );
                        return;
                      }

                      final repo = ref.read(repositoryProvider);
                      int createdCount = 0;
                      int skippedCount = 0;
                      final runningAppts = List<AppointmentEntry>.from(
                        existingAppts,
                      );

                      for (final occ in occurrences) {
                        final occEnd = occ.add(
                          Duration(minutes: durationMinutes),
                        );
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
                          personId: selectedPersonId,
                          title: title,
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

                      if (ctx.mounted) Navigator.pop(ctx);
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
            },
          );
        },
      ),
    );
  }

  void _showAppointmentActions(BuildContext context, AppointmentEntry appt) {
    if (appt.id.startsWith('task:')) {
      final taskId = appt.id.replaceFirst('task:', '');
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(appt.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Data Limite: ${AppDateUtils.formatDate(appt.startTime)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (appt.locationNotes != null) ...[
                const SizedBox(height: 8),
                Text(appt.locationNotes!),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fechar'),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Concluir'),
              onPressed: () async {
                Navigator.pop(ctx);
                await ref
                    .read(taskManagerProvider)
                    .toggleTaskComplete(taskId, completed: true);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tarefa marcada como concluída!'),
                    ),
                  );
                }
              },
            ),
            FilledButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('Ver Tarefas'),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TasksScreen()),
                );
              },
            ),
          ],
        ),
      );
      return;
    }
    if (appt.id.startsWith('project:')) {
      final projectId = appt.id.replaceFirst('project:', '');
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(appt.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Prazo do Projeto: ${AppDateUtils.formatDate(appt.startTime)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (appt.locationNotes != null) ...[
                const SizedBox(height: 8),
                Text(appt.locationNotes!),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fechar'),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Concluir'),
              onPressed: () async {
                Navigator.pop(ctx);
                await ref
                    .read(projectManagerProvider)
                    .updateProjectStatus(projectId, 'completed');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Projeto marcado como concluído!'),
                    ),
                  );
                }
              },
            ),
            FilledButton.icon(
              icon: const Icon(Icons.folder_open),
              label: const Text('Abrir Projeto'),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProjectDetailScreen(projectId: projectId),
                  ),
                );
              },
            ),
          ],
        ),
      );
      return;
    }
    if (appt.id.startsWith('external-calendar:')) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(appt.title),
          content: Text(
            'Evento de calendário conectado (somente leitura).\n'
            '${AppDateUtils.formatDateTime(appt.startTime)} — '
            '${AppDateUtils.formatDateTime(appt.endTime)}'
            '${appt.locationNotes == null ? "" : "\n${appt.locationNotes}"}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
      return;
    }
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
                      backgroundColor: _AppointmentsScreenState._getStatusColor(
                        appt.status,
                      ).withValues(alpha: 0.15),
                      child: Icon(
                        Icons.event,
                        color: _AppointmentsScreenState._getStatusColor(
                          appt.status,
                        ),
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
    DateTime chosenDate = appt.startTime.add(const Duration(days: 7));
    TimeOfDay chosenTime = TimeOfDay.fromDateTime(appt.startTime);
    int durationMinutes = appt.durationMinutes;

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
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Anterior: ${AppDateUtils.formatDateTime(appt.startTime)}',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
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
                  await repo.rescheduleAppointment(
                    oldAppointment: appt,
                    newStartTime: start,
                    newEndTime: start.add(Duration(minutes: durationMinutes)),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
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
        },
      ),
    );
  }

  void _showFieldMinistryScheduleModal(BuildContext context) {
    DateTime chosenDate = _selectedDate;
    TimeOfDay chosenTime = const TimeOfDay(hour: 9, minute: 0);
    int durationMinutes = 120; // 2 horas padrão
    String modality = 'De Casa em Casa';
    String recurrence = 'Toda semana';
    int recurrenceCount = 8;
    bool respectAvailability = true;

    showDialog(
      context: context,
      builder: (ctx) => ManagedTextControllers(
        initialTexts: const [''],
        builder: (ctx, ctrls) {
          final locationController = ctrls[0];

          return StatefulBuilder(
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
                          DropdownMenuItem(
                            value: 'Outro',
                            child: Text('📌 Outro'),
                          ),
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
                              if (p != null)
                                setDialogState(() => chosenDate = p);
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
                              if (t != null)
                                setDialogState(() => chosenTime = t);
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
                          if (val != null)
                            setDialogState(() => recurrence = val);
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
                          hintText:
                              'Ex: Salão do Reino / Praça Central / Setor 03',
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
                        final occEnd = occ.add(
                          Duration(minutes: durationMinutes),
                        );
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
          );
        },
      ),
    );
  }
}
