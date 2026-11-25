part of '../person_detail_screen.dart';

extension _PersonDetailStudyDialogs on _PersonDetailScreenState {
  // Modal de Abertura de Publicação no JW Library / Site Oficial
  void _openPublicationLink(BuildContext context, BibleStudyEntry study) {
    final resolved = PublicationLinkResolver.resolve(
      publicationId: study.publicationId,
      languageCode: study.language,
      lesson: study.currentLesson,
      paragraph: study.currentParagraph,
      manualReference: study.manualReference,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.menu_book, color: AppTheme.primaryBlue),
            SizedBox(width: 8),
            Expanded(child: Text('Abrir no JW Library')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              resolved.displayText,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 10),
            if (resolved.note != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  resolved.note!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (resolved.url != null) ...[
              Text(
                'Link Oficial Verificado:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                resolved.url!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.accentTeal,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copiar'),
            onPressed: () {
              Clipboard.setData(
                ClipboardData(text: resolved.url ?? resolved.displayText),
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Referência copiada para a área de transferência!',
                  ),
                ),
              );
            },
          ),
          if (resolved.fallbackUrl != null)
            TextButton.icon(
              icon: const Icon(Icons.language, size: 16),
              label: const Text('No Navegador'),
              onPressed: () async {
                final uri = Uri.parse(resolved.fallbackUrl!);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          if (resolved.url != null)
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('No JW Library'),
              onPressed: () async {
                final uri = Uri.parse(resolved.url!);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else if (resolved.fallbackUrl != null) {
                  await launchUrl(
                    Uri.parse(resolved.fallbackUrl!),
                    mode: LaunchMode.externalApplication,
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
        ],
      ),
    );
  }

  // Modal para Iniciar Estudo Bíblico diretamente do perfil da pessoa
  void _showStartStudyDialog(BuildContext context, PersonEntry person) {
    String selectedPublicationId = 'lff-book';
    String selectedLanguage = 'pt';
    String selectedFrequency = 'semanal';
    String selectedStatus = 'ativo';
    DateTime selectedStartedAt = DateTime.now();
    DateTime? selectedLastSessionAt;
    bool scheduleFirstStudy = true;
    DateTime firstStudyDateTime = DateTime.now().add(const Duration(days: 7));
    firstStudyDateTime = DateTime(
      firstStudyDateTime.year,
      firstStudyDateTime.month,
      firstStudyDateTime.day,
      10,
      0,
    );
    int firstStudyDuration = 60;

    showDialog(
      context: context,
      builder: (ctx) => ManagedTextControllers(
        initialTexts: ['Estudo de ${person.name}', '1', '1'],
        builder: (ctx, ctrls) {
          final titleController = ctrls[0];
          final lessonController = ctrls[1];
          final paragraphController = ctrls[2];
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final isDark = Theme.of(ctx).brightness == Brightness.dark;

              return AlertDialog(
                title: Row(
                  children: [
                    const Icon(Icons.school, color: Color(0xFF7C3AED)),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Iniciar Estudo: ${person.name}')),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED)
                              .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF7C3AED)
                                .withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Color(0xFF7C3AED),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Estudo já em andamento? Defina a data real de início e a lição atual para que as estatísticas reflitam a realidade com precisão sem necessidade de sessões passadas fictícias.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF5B21B6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Título do estudo *',
                          hintText: 'Ex: Estudo da Família Lima',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Situação Inicial *',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'ativo',
                            child: Text('Ativo (Em andamento)'),
                          ),
                          DropdownMenuItem(
                            value: 'pausado',
                            child: Text('Pausado'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedStatus = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      // Data de Início Real
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text(
                                'Início: ${AppDateUtils.formatDate(selectedStartedAt)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedStartedAt,
                                  firstDate: DateTime(2010),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (picked != null) {
                                  setDialogState(
                                    () => selectedStartedAt = picked,
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Data da Última Sessão Realizada (opcional)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.history, size: 16),
                              label: Text(
                                selectedLastSessionAt != null
                                    ? 'Última Sessão: ${AppDateUtils.formatDate(selectedLastSessionAt!)}'
                                    : 'Última Sessão (opcional)',
                                style: const TextStyle(fontSize: 12),
                              ),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      selectedLastSessionAt ??
                                      selectedStartedAt,
                                  firstDate: DateTime(2010),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setDialogState(
                                    () => selectedLastSessionAt = picked,
                                  );
                                }
                              },
                            ),
                          ),
                          if (selectedLastSessionAt != null)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              tooltip: 'Remover data',
                              onPressed: () => setDialogState(
                                () => selectedLastSessionAt = null,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedPublicationId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Publicação Principal',
                        ),
                        items: PublicationCatalog.allPublications.map((p) {
                          return DropdownMenuItem(
                            value: p.id,
                            child: Text(
                              p.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedPublicationId = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedLanguage,
                        decoration: const InputDecoration(
                          labelText: 'Idioma do estudo',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'pt',
                            child: Text('Português'),
                          ),
                          DropdownMenuItem(
                            value: 'bzs',
                            child: Text('Libras (Língua de Sinais)'),
                          ),
                          DropdownMenuItem(value: 'tca', child: Text('Ticuna')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedLanguage = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: lessonController,
                              decoration: const InputDecoration(
                                labelText: 'Lição Inicial / Atual',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: paragraphController,
                              decoration: const InputDecoration(
                                labelText: 'Parágrafo / Ponto',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedFrequency,
                        decoration: const InputDecoration(
                          labelText: 'Frequência do estudo',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'semanal',
                            child: Text('Semanal (1x por semana)'),
                          ),
                          DropdownMenuItem(
                            value: 'duas_vezes_semana',
                            child: Text('Intensivo (2x por semana)'),
                          ),
                          DropdownMenuItem(
                            value: 'quinzenal',
                            child: Text('Quinzenal'),
                          ),
                          DropdownMenuItem(
                            value: 'variavel',
                            child: Text('Variável / Flexível'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedFrequency = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED)
                              .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Color(0xFF7C3AED),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'O status de ${person.name} será automaticamente atualizado para "Estudo Bíblico" e integrado aos relatórios mensais.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF5B21B6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      GlobalAppointmentSchedulingSection(
                        title: 'Agendar Primeiro Estudo na Agenda',
                        isEnabled: scheduleFirstStudy,
                        onToggle: (v) =>
                            setDialogState(() => scheduleFirstStudy = v),
                        selectedDateTime: firstStudyDateTime,
                        onDateTimeChanged: (dt) =>
                            setDialogState(() => firstStudyDateTime = dt),
                        durationMinutes: firstStudyDuration,
                        onDurationChanged: (d) =>
                            setDialogState(() => firstStudyDuration = d),
                        existingAppointments:
                            ref.read(appointmentsStreamProvider).value ?? [],
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
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final title = titleController.text.trim();
                      if (title.isEmpty) return;

                      if (scheduleFirstStudy) {
                        final allAppts =
                            ref.read(appointmentsStreamProvider).value ?? [];
                        final avail = AvailabilityEngine.checkAvailability(
                          startTime: firstStudyDateTime,
                          durationMinutes: firstStudyDuration,
                          existingAppointments: allAppts,
                        );
                        final canProceed =
                            await GlobalAppointmentSchedulingSection.confirmConflictIfNeeded(
                              context: context,
                              availability: avail,
                            );
                        if (!canProceed) return;
                      }

                      final initialLesson =
                          int.tryParse(lessonController.text.trim()) ?? 1;
                      final initialPara =
                          int.tryParse(paragraphController.text.trim()) ?? 1;

                      final repo = ref.read(repositoryProvider);
                      await repo.createStudy(
                        title: title,
                        publicationId: selectedPublicationId,
                        language: selectedLanguage,
                        status: selectedStatus,
                        startedAt: selectedStartedAt,
                        lastSessionAt: selectedLastSessionAt,
                        currentLesson: initialLesson,
                        currentParagraph: initialPara,
                        frequency: selectedFrequency,
                        participantPersonIds: [person.id],
                        primaryParticipantId: person.id,
                      );

                      final shouldUpdateContact =
                          selectedLastSessionAt != null &&
                          (person.lastContactAt == null ||
                              selectedLastSessionAt!.isAfter(
                                person.lastContactAt!,
                              ));
                      if (person.status != 'estudo' || shouldUpdateContact) {
                        await repo.updatePerson(
                          person.copyWith(
                            status: 'estudo',
                            lastContactAt: shouldUpdateContact
                                ? Value(selectedLastSessionAt)
                                : Value(person.lastContactAt),
                          ),
                        );
                      }

                      if (scheduleFirstStudy) {
                        await repo.createAppointment(
                          personId: person.id,
                          title: 'Estudo Bíblico: ${person.name}',
                          startTime: firstStudyDateTime,
                          endTime: firstStudyDateTime.add(
                            Duration(minutes: firstStudyDuration),
                          ),
                          durationMinutes: firstStudyDuration,
                          status: 'confirmado',
                          locationNotes: person.address != null
                              ? 'Local: ${person.address}'
                              : null,
                        );
                      }

                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Estudo Bíblico iniciado com sucesso com ${person.name}!',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Iniciar Estudo'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // Modal para editar dados de um estudo bíblico existente
  void _showEditStudyDialog(BuildContext context, BibleStudyEntry study) {
    String selectedPublicationId = study.publicationId;
    String selectedLanguage = study.language;
    String selectedFrequency = study.frequency;
    String selectedStatus = study.status;
    DateTime realStartDate = study.startedAt;
    DateTime? lastSessionDate = study.lastSessionAt;

    showDialog(
      context: context,
      builder: (ctx) => ManagedTextControllers(
        initialTexts: [
          study.title,
          (study.currentLesson ?? 1).toString(),
          (study.currentParagraph ?? 1).toString(),
        ],
        builder: (ctx, ctrls) {
          final titleController = ctrls[0];
          final lessonController = ctrls[1];
          final paragraphController = ctrls[2];
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              return AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.edit_note, color: Color(0xFF7C3AED)),
                    SizedBox(width: 8),
                    Expanded(child: Text('Editar Dados do Estudo')),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Título do estudo *',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Situação do Estudo',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'ativo',
                            child: Text('Ativo'),
                          ),
                          DropdownMenuItem(
                            value: 'pausado',
                            child: Text('Pausado'),
                          ),
                          DropdownMenuItem(
                            value: 'concluido',
                            child: Text('Concluído'),
                          ),
                          DropdownMenuItem(
                            value: 'encerrado',
                            child: Text('Encerrado'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedStatus = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      // Data de Início Real
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text(
                                'Início: ${AppDateUtils.formatDate(realStartDate)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: realStartDate,
                                  firstDate: DateTime(2010),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (picked != null) {
                                  setDialogState(() => realStartDate = picked);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Lição e Ponto Atual
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: lessonController,
                              decoration: const InputDecoration(
                                labelText: 'Lição Atual',
                                hintText: 'Ex: 15',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: paragraphController,
                              decoration: const InputDecoration(
                                labelText: 'Ponto / Parágrafo',
                                hintText: 'Ex: 2',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Data da Última Sessão
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.history, size: 16),
                              label: Text(
                                lastSessionDate != null
                                    ? 'Última Sessão: ${AppDateUtils.formatDate(lastSessionDate!)}'
                                    : 'Última Sessão (opcional)',
                                style: const TextStyle(fontSize: 12),
                              ),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      lastSessionDate ?? DateTime.now(),
                                  firstDate: DateTime(2010),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setDialogState(
                                    () => lastSessionDate = picked,
                                  );
                                }
                              },
                            ),
                          ),
                          if (lastSessionDate != null)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              tooltip: 'Remover data',
                              onPressed: () =>
                                  setDialogState(() => lastSessionDate = null),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedPublicationId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Publicação',
                        ),
                        items: PublicationCatalog.allPublications.map((p) {
                          return DropdownMenuItem(
                            value: p.id,
                            child: Text(
                              p.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedPublicationId = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedLanguage,
                        decoration: const InputDecoration(
                          labelText: 'Idioma do estudo',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'pt',
                            child: Text('Português'),
                          ),
                          DropdownMenuItem(
                            value: 'bzs',
                            child: Text('Libras (Língua de Sinais)'),
                          ),
                          DropdownMenuItem(value: 'tca', child: Text('Ticuna')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedLanguage = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedFrequency,
                        decoration: const InputDecoration(
                          labelText: 'Frequência do estudo',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'semanal',
                            child: Text('Semanal (1x por semana)'),
                          ),
                          DropdownMenuItem(
                            value: 'duas_vezes_semana',
                            child: Text('Intensivo (2x por semana)'),
                          ),
                          DropdownMenuItem(
                            value: 'quinzenal',
                            child: Text('Quinzenal (A cada 15 dias)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedFrequency = val);
                          }
                        },
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
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final title = titleController.text.trim();
                      if (title.isEmpty) return;
                      final lesson =
                          int.tryParse(lessonController.text.trim()) ?? 1;
                      final paragraph =
                          int.tryParse(paragraphController.text.trim()) ?? 1;

                      final repo = ref.read(repositoryProvider);
                      await repo.updateStudy(
                        study.copyWith(
                          title: title,
                          status: selectedStatus,
                          startedAt: realStartDate,
                          lastSessionAt: Value(lastSessionDate),
                          publicationId: selectedPublicationId,
                          language: selectedLanguage,
                          currentLesson: Value(lesson),
                          currentParagraph: Value(paragraph),
                          frequency: selectedFrequency,
                        ),
                      );

                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Dados do estudo atualizados com sucesso!',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Salvar Alterações'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showEditPersonTagsDialog(
    BuildContext context,
    AppRepository repo,
    PersonEntry person,
  ) {
    List<String> currentTags = [];
    if (person.tags.isNotEmpty && person.tags != '[]') {
      if (person.tags.startsWith('[')) {
        try {
          final decoded = jsonDecode(person.tags) as List;
          currentTags = decoded
              .map((e) => e.toString().trim())
              .where((s) => s.isNotEmpty)
              .toList();
        } catch (e, st) {
          AppLogger.debug('Falha ao ler tags JSON (${person.id}): $e', st);
        }
      } else {
        currentTags = person.tags
            .split(',')
            .map((e) => e.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => ManagedTextControllers(
        initialTexts: const [''],
        customFactories: [
          (text) => RichFormattedEditingController.fromMarkup(text),
        ],
        builder: (ctx, ctrls) {
          final tagController = ctrls[0];

          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              return AlertDialog(
                title: Row(
                  children: [
                    const Icon(Icons.label, color: AppTheme.primaryBlue),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Etiquetas de ${person.name}')),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gerencie tags para organizar contatos por afinidade, idioma ou situação:',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: tagController,
                              decoration: const InputDecoration(
                                labelText: 'Nova tag',
                                hintText: 'Ex: jovem, interessado, bíblia',
                                isDense: true,
                              ),
                              onSubmitted: (val) {
                                final t = val.trim();
                                if (t.isNotEmpty && !currentTags.contains(t)) {
                                  setDialogState(() {
                                    currentTags.add(t);
                                    tagController.clear();
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.add_circle,
                              color: AppTheme.primaryBlue,
                            ),
                            onPressed: () {
                              final t = tagController.text.trim();
                              if (t.isNotEmpty && !currentTags.contains(t)) {
                                setDialogState(() {
                                  currentTags.add(t);
                                  tagController.clear();
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (currentTags.isEmpty)
                        const Text(
                          'Nenhuma tag cadastrada ainda.',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 13,
                          ),
                        )
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: currentTags
                              .map(
                                (t) => Chip(
                                  label: Text(
                                    t,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  deleteIcon: const Icon(Icons.close, size: 14),
                                  onDeleted: () {
                                    setDialogState(() => currentTags.remove(t));
                                  },
                                ),
                              )
                              .toList(),
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
                      await repo.updatePerson(
                        person.copyWith(tags: jsonEncode(currentTags)),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Salvar Tags'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showEndStudyDialog(
    BuildContext context,
    AppRepository repo,
    BibleStudyEntry study,
    PersonEntry person,
  ) async {
    String selectedReason = 'Falta de interesse / tempo';
    if (!context.mounted) return;

    final coordinator = ref.read(scheduleReleaseCoordinatorProvider);
    final futureAppts = await coordinator.getFutureAppointmentsForStudy(
      study.id,
    );
    final participants = await repo.getParticipantsForStudy(study.id);

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => ManagedTextControllers(
        initialTexts: const [''],
        customFactories: [
          (text) => RichFormattedEditingController.fromMarkup(text),
        ],
        builder: (ctx, ctrls) {
          final notesController = ctrls[0];

          return StatefulBuilder(
            builder: (ctx, setDialogState) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.stop_circle_outlined, color: AppTheme.alertAmber),
                  SizedBox(width: 8),
                  Expanded(child: Text('Encerrar Estudo Bíblico')),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Você está encerrando o estudo bíblico com ${person.name}. O contato NÃO será excluído e continuará preservado no seu histórico como revisita.',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 14),

                    // Bloco de aviso de compromissos futuros
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: futureAppts.isNotEmpty
                            ? AppTheme.primaryBlue.withValues(alpha: 0.08)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: futureAppts.isNotEmpty
                              ? AppTheme.primaryBlue.withValues(alpha: 0.3)
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.event_available,
                                size: 16,
                                color: futureAppts.isNotEmpty
                                    ? AppTheme.primaryBlue
                                    : AppTheme.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Agenda: ${futureAppts.length} compromisso(s) futuro(s) vinculado(s)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (futureAppts.isNotEmpty) ...[
                            const Text(
                              'Ao confirmar, os horários abaixo serão cancelados e liberados na agenda ativa:',
                              style: TextStyle(fontSize: 11),
                            ),
                            const SizedBox(height: 4),
                            ...futureAppts.map(
                              (a) => Padding(
                                padding: const EdgeInsets.only(
                                  left: 6,
                                  bottom: 2,
                                ),
                                child: Text(
                                  '• ${a.title} (${AppDateUtils.formatDateTime(a.startTime)} às ${AppDateUtils.formatTime(a.endTime)})',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Os lembretes locais programados serão removidos e sessões passadas permanecerão intactas.',
                              style: TextStyle(
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ] else
                            const Text(
                              'Nenhum compromisso futuro agendado para este estudo.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),

                    if (participants.length > 1) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.alertAmber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.alertAmber.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          'Aviso: Este estudo possui ${participants.length} participantes. Ao encerrá-lo, o status de todos será alterado para revisita e os horários vinculados serão liberados.',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedReason,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Motivo do Encerramento *',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Falta de interesse / tempo',
                          child: Text('Falta de interesse / tempo'),
                        ),
                        DropdownMenuItem(
                          value: 'Mudou-se de território',
                          child: Text('Mudou-se de território'),
                        ),
                        DropdownMenuItem(
                          value: 'Oposição familiar',
                          child: Text('Oposição familiar'),
                        ),
                        DropdownMenuItem(
                          value: 'Estudo concluído / Batizado',
                          child: Text('Estudo concluído / Batizado'),
                        ),
                        DropdownMenuItem(
                          value: 'Problemas de saúde',
                          child: Text('Problemas de saúde'),
                        ),
                        DropdownMenuItem(
                          value: 'Outro',
                          child: Text('Outro motivo'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedReason = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    RichMarkdownToolbar(
                      controller: notesController,
                      enableHighlightPalette: false,
                      enableImagePicker: false,
                      enableCrossReferences: true,
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Observação complementar (opcional)',
                        hintText: 'Ex: Portas abertas para contato futuro...',
                      ),
                      maxLines: 3,
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
                    backgroundColor: AppTheme.alertAmber,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () async {
                    final coordinator = ref.read(
                      scheduleReleaseCoordinatorProvider,
                    );
                    final result = await coordinator
                        .endStudyWithScheduleRelease(
                          study: study,
                          endReason: selectedReason,
                          notes: RichFormattedEditingController.readMarkup(
                            notesController,
                          ).trim(),
                          releaseFutureAppointments: true,
                        );

                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Estudo encerrado ($selectedReason). ${result.message}',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Confirmar Encerramento'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _reactivateStudy(
    BuildContext context,
    AppRepository repo,
    BibleStudyEntry study,
    PersonEntry person,
  ) async {
    await repo.updateStudy(
      study.copyWith(status: 'ativo', pauseOrCloseReason: const Value(null)),
    );
    await repo.updatePerson(person.copyWith(status: 'estudo'));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Estudo bíblico com "${person.name}" reativado com sucesso!',
          ),
        ),
      );
    }
  }

  void _showRecordStudySessionDialog(
    BuildContext context,
    BibleStudyEntry study,
    PersonEntry person,
  ) {
    final allAppts = ref.read(appointmentsStreamProvider).value ?? [];

    // Busca agendamento futuro existente para este estudante para evitar duplicatas
    AppointmentEntry? existingUpcomingAppt;
    final upcoming =
        allAppts
            .where(
              (a) =>
                  a.personId == person.id &&
                  a.startTime.isAfter(
                    DateTime.now().subtract(const Duration(hours: 1)),
                  ) &&
                  a.status != 'cancelado' &&
                  a.deletedAt == null,
            )
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
    if (upcoming.isNotEmpty) {
      existingUpcomingAppt = upcoming.first;
    }

    final pubId = StudyPublicationIndexHelper.isSupported(study.publicationId)
        ? study.publicationId
        : 'lff-book';
    final maxLessons = StudyPublicationIndexHelper.totalLessonsFor(pubId);
    final pubShortCode = StudyPublicationIndexHelper.shortCode(pubId);
    int selectedLesson = (study.currentLesson ?? 1).clamp(1, maxLessons);
    final initLessonPoints = StudyPublicationIndexHelper.getLessonPointTitles(
      pubId,
      selectedLesson,
    );
    final initMaxPt = initLessonPoints.isNotEmpty ? initLessonPoints.length : 6;
    int selectedStartPoint = (study.currentParagraph ?? 1).clamp(1, initMaxPt);
    int selectedEndPoint = selectedStartPoint;
    String sessionOutcome = 'realizada'; // 'realizada' ou 'cancelada'
    String failureMotive = 'Cancelado pelo estudante';
    String selectedUnitId = 'lesson_$selectedLesson';
    final allUnits = StudyPublicationIndexHelper.getAllStudyUnits(pubId);

    final initialNext = StudyPublicationIndexHelper.getNextProgression(
      publicationId: pubId,
      currentLesson: selectedLesson,
      currentPoint: selectedEndPoint,
    );
    int attendanceCount = 1;
    bool scheduleNextStudy = true;

    // Frequência do estudo
    final freq = study.frequency.toLowerCase();
    String freqLabel = 'Semanal';
    int daysToAdd = 7;
    if (freq.contains('2x') || freq.contains('duas')) {
      freqLabel = '2x por semana';
      daysToAdd = 3;
    } else if (freq.contains('quinzenal')) {
      freqLabel = 'Quinzenal';
      daysToAdd = 14;
    } else if (freq.contains('mensal')) {
      freqLabel = 'Mensal';
      daysToAdd = 28;
    }

    DateTime nextStudyDateTime;
    int nextStudyDuration = existingUpcomingAppt?.durationMinutes ?? 60;

    if (existingUpcomingAppt != null) {
      nextStudyDateTime = existingUpcomingAppt.startTime;
    } else {
      final target = DateTime.now().add(Duration(days: daysToAdd));
      nextStudyDateTime = DateTime(
        target.year,
        target.month,
        target.day,
        10,
        0,
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => ManagedTextControllers(
        initialTexts: [
          selectedLesson.toString(),
          selectedStartPoint == selectedEndPoint
              ? '$selectedStartPoint'
              : '$selectedStartPoint-$selectedEndPoint',
          '',
          study.nextTopic ?? initialNext.label,
        ],
        customFactories: [
          null,
          null,
          (text) => RichFormattedEditingController.fromMarkup(text),
          (text) => RichFormattedEditingController.fromMarkup(text),
        ],
        builder: (ctx, ctrls) {
          final lessonController = ctrls[0];
          final paragraphsController = ctrls[1];
          final notesController = ctrls[2];
          final nextStepController = ctrls[3];
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final isDark = Theme.of(ctx).brightness == Brightness.dark;
              final progressPercent =
                  StudyPublicationIndexHelper.calculateProgressPercentage(
                    publicationId: pubId,
                    lesson: selectedLesson,
                    point: selectedEndPoint,
                  );

              final foundUnit = allUnits
                  .where((u) => u.id == selectedUnitId)
                  .firstOrNull;
              final pointTitles = selectedUnitId.startsWith('lesson_')
                  ? StudyPublicationIndexHelper.getLessonPointTitles(
                      pubId,
                      selectedLesson,
                    )
                  : const <String>[];
              final currentUnitMaxPoints =
                  foundUnit?.totalPoints ??
                  (pointTitles.isNotEmpty ? pointTitles.length : 6);

              void updatePoints(int startP, int endP) {
                setDialogState(() {
                  selectedStartPoint = startP;
                  selectedEndPoint = endP;
                  paragraphsController.text = startP == endP
                      ? '$startP'
                      : '$startP-$endP';
                  final nextProg =
                      StudyPublicationIndexHelper.getNextProgression(
                        publicationId: pubId,
                        currentLesson: selectedLesson,
                        currentPoint: endP,
                      );
                  (nextStepController..clear()).text = nextProg.label;
                });
              }

              return AlertDialog(
                title: Text('Registrar Sessão: ${study.title}'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Seletor de Desfecho da Sessão: Realizada com Sucesso vs Falhou/Cancelada
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setDialogState(
                                  () => sessionOutcome = 'realizada',
                                ),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: sessionOutcome == 'realizada'
                                        ? AppTheme.successGreen.withValues(
                                            alpha: 0.15,
                                          )
                                        : (isDark
                                              ? const Color(0xFF1E293B)
                                              : const Color(0xFFF1F5F9)),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: sessionOutcome == 'realizada'
                                          ? AppTheme.successGreen
                                          : Colors.transparent,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        size: 16,
                                        color: sessionOutcome == 'realizada'
                                            ? AppTheme.successGreen
                                            : Colors.grey,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Realizada',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: sessionOutcome == 'realizada'
                                              ? AppTheme.successGreen
                                              : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: InkWell(
                                onTap: () => setDialogState(
                                  () => sessionOutcome = 'cancelada',
                                ),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: sessionOutcome == 'cancelada'
                                        ? AppTheme.alertRed.withValues(
                                            alpha: 0.15,
                                          )
                                        : (isDark
                                              ? const Color(0xFF1E293B)
                                              : const Color(0xFFF1F5F9)),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: sessionOutcome == 'cancelada'
                                          ? AppTheme.alertRed
                                          : Colors.transparent,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.cancel,
                                        size: 16,
                                        color: sessionOutcome == 'cancelada'
                                            ? AppTheme.alertRed
                                            : Colors.grey,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Falhou / Cancelada',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: sessionOutcome == 'cancelada'
                                              ? AppTheme.alertRed
                                              : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (sessionOutcome == 'cancelada') ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFF87171)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: Color(0xFFDC2626),
                                    size: 18,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Registrar Falha / Não Realização',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF991B1B),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'O registro da falha é contabilizado no histórico e na prioridade de atenção do estudante.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF7F1D1D),
                                ),
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                initialValue: failureMotive,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText:
                                      'Motivo da Falha / Não Realização *',
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'Cancelado pelo estudante',
                                    child: Text('Cancelado pelo estudante'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Estudante ausente / Não atendeu',
                                    child: Text(
                                      'Estudante ausente / Não atendeu',
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Imprevisto pessoal do publicador',
                                    child: Text(
                                      'Imprevisto pessoal do publicador',
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Desmarcado com antecedência',
                                    child: Text('Desmarcado com antecedência'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Outro motivo',
                                    child: Text('Outro motivo'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() => failureMotive = val);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ] else ...[
                        // Progresso do Livro Seja Feliz Para Sempre!
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED)
                                .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF7C3AED)
                                  .withValues(alpha: 0.25),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Progresso no Livro:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF7C3AED),
                                    ),
                                  ),
                                  Text(
                                    '${progressPercent.toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF7C3AED),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progressPercent / 100.0,
                                  minHeight: 8,
                                  backgroundColor: Colors.purple.shade100,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Color(0xFF7C3AED),
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Seletor Inteligente de Unidade / Lição e Subtópicos
                        DropdownButtonFormField<String>(
                          initialValue:
                              allUnits.any((u) => u.id == selectedUnitId)
                              ? selectedUnitId
                              : (allUnits.isNotEmpty
                                    ? allUnits.first.id
                                    : null),
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText:
                                'Unidade / Lição Estudada ($pubShortCode) *',
                          ),
                          items: allUnits.map((u) {
                            return DropdownMenuItem<String>(
                              value: u.id,
                              child: Text(
                                u.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedUnitId = val;
                                if (val.startsWith('lesson_')) {
                                  selectedLesson = int.parse(
                                    val.replaceFirst('lesson_', ''),
                                  );
                                  final newPts =
                                      StudyPublicationIndexHelper.getLessonPointTitles(
                                        pubId,
                                        selectedLesson,
                                      );
                                  final maxPt = newPts.isNotEmpty
                                      ? newPts.length
                                      : 6;
                                  selectedStartPoint = 1;
                                  selectedEndPoint = selectedEndPoint.clamp(
                                    1,
                                    maxPt,
                                  );
                                  lessonController.text = selectedLesson
                                      .toString();
                                  paragraphsController.text =
                                      selectedStartPoint == selectedEndPoint
                                      ? '$selectedStartPoint'
                                      : '$selectedStartPoint-$selectedEndPoint';
                                  final nextProg =
                                      StudyPublicationIndexHelper.getNextProgression(
                                        publicationId: pubId,
                                        currentLesson: selectedLesson,
                                        currentPoint: selectedEndPoint,
                                      );
                                  (nextStepController..clear()).text =
                                      nextProg.label;
                                } else {
                                  (nextStepController..clear()).text = val;
                                }
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),

                        // Seletor dos Pontos / Subtópicos da Lição
                        const Text(
                          'Pontos / Subtópicos Cobertos:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: List.generate(currentUnitMaxPoints, (idx) {
                            final pNum = idx + 1;
                            final isSelected =
                                pNum >= selectedStartPoint &&
                                pNum <= selectedEndPoint;
                            return FilterChip(
                              label: Text('Ponto $pNum'),
                              selected: isSelected,
                              selectedColor: const Color(0xFF7C3AED)
                                  .withValues(alpha: 0.25),
                              checkmarkColor: const Color(0xFF7C3AED),
                              onSelected: (val) {
                                if (val) {
                                  if (pNum < selectedStartPoint) {
                                    updatePoints(pNum, selectedEndPoint);
                                  } else {
                                    updatePoints(selectedStartPoint, pNum);
                                  }
                                } else {
                                  if (selectedStartPoint == selectedEndPoint) {
                                    // Mínimo 1 selecionado
                                  } else if (pNum == selectedEndPoint) {
                                    final newEnd = pNum - 1 < selectedStartPoint
                                        ? selectedStartPoint
                                        : pNum - 1;
                                    updatePoints(selectedStartPoint, newEnd);
                                  } else {
                                    updatePoints(pNum, pNum);
                                  }
                                }
                              },
                            );
                          }),
                        ),
                        if (pointTitles.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (
                                  var p = selectedStartPoint;
                                  p <= selectedEndPoint;
                                  p++
                                )
                                  if (p >= 1 && p <= pointTitles.length)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Text(
                                        pointTitles[p - 1],
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: isDark
                                              ? const Color(0xFFCBD5E1)
                                              : const Color(0xFF334155),
                                        ),
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        TextField(
                          controller: paragraphsController,
                          decoration: const InputDecoration(
                            labelText: 'Parágrafos / Pontos Estudados (livre para editar)',
                            hintText:
                                'Ex: 1, 2-3, 1-6 ou anotação personalizada',
                          ),
                          onChanged: (text) {
                            final parsed = int.tryParse(text.trim());
                            if (parsed != null &&
                                parsed >= 1 &&
                                parsed <= currentUnitMaxPoints) {
                              setDialogState(() {
                                selectedStartPoint = parsed;
                                selectedEndPoint = parsed;
                                final nextProg =
                                    StudyPublicationIndexHelper.getNextProgression(
                                      publicationId: pubId,
                                      currentLesson: selectedLesson,
                                      currentPoint: parsed,
                                    );
                                (nextStepController..clear()).text =
                                    nextProg.label;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 14),

                        // Seletor de Contagem de Presentes / Assistência
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED)
                                .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF7C3AED)
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Número de Presentes',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Color(0xFF7C3AED),
                                      ),
                                    ),
                                    Text(
                                      'Estudante e acompanhantes',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? const Color(0xFFCBD5E1)
                                            : AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                      color: Color(0xFF7C3AED),
                                    ),
                                    onPressed: () {
                                      if (attendanceCount > 1) {
                                        setDialogState(() => attendanceCount--);
                                      }
                                    },
                                  ),
                                  Text(
                                    '$attendanceCount',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF7C3AED),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.add_circle_outline,
                                      color: Color(0xFF7C3AED),
                                    ),
                                    onPressed: () {
                                      setDialogState(() => attendanceCount++);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      RichMarkdownToolbar(
                        controller: notesController,
                        enableHighlightPalette: false,
                        enableImagePicker: false,
                        enableCrossReferences: true,
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: notesController,
                        decoration: InputDecoration(
                          labelText: sessionOutcome == 'cancelada'
                              ? 'Observações da falha'
                              : 'Observações da sessão',
                          hintText: sessionOutcome == 'cancelada'
                              ? 'Descreva o que houve ou motivo de contato...'
                              : 'Dúvidas esclarecidas, pontos de interesse...',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nextStepController,
                        decoration: InputDecoration(
                          labelText: 'Próximo assunto',
                          hintText: 'Ex: Lição 2, Ponto 1 em diante',
                          suffixIcon: IconButton(
                            icon: const Icon(
                              Icons.bookmark_add_outlined,
                              size: 19,
                              color: AppTheme.primaryBlue,
                            ),
                            tooltip: 'Inserir referência (TNM ou Abas do App)',
                            onPressed: () =>
                                RichMarkdownToolbar.pickAndInsertReference(
                                  ctx,
                                  db: ref.read(databaseProvider),
                                  controller: nextStepController,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      GlobalAppointmentSchedulingSection(
                        title: 'Agendar Próximo Estudo',
                        isEnabled: scheduleNextStudy,
                        onToggle: (v) =>
                            setDialogState(() => scheduleNextStudy = v),
                        selectedDateTime: nextStudyDateTime,
                        onDateTimeChanged: (dt) =>
                            setDialogState(() => nextStudyDateTime = dt),
                        durationMinutes: nextStudyDuration,
                        onDurationChanged: (d) =>
                            setDialogState(() => nextStudyDuration = d),
                        existingAppointments:
                            ref.read(appointmentsStreamProvider).value ?? [],
                        existingPersonAppointment: existingUpcomingAppt,
                        frequencyText: freqLabel,
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
                      backgroundColor: sessionOutcome == 'cancelada'
                          ? AppTheme.alertRed
                          : const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      if (scheduleNextStudy) {
                        final allAppts =
                            ref.read(appointmentsStreamProvider).value ?? [];
                        final avail = AvailabilityEngine.checkAvailability(
                          startTime: nextStudyDateTime,
                          durationMinutes: nextStudyDuration,
                          existingAppointments: allAppts,
                        );
                        final canProceed =
                            await GlobalAppointmentSchedulingSection.confirmConflictIfNeeded(
                              context: context,
                              availability: avail,
                            );
                        if (!canProceed) return;
                      }

                      final repo = ref.read(repositoryProvider);
                      final rawNotes =
                          RichFormattedEditingController.readMarkup(
                            notesController,
                          ).trim();
                      final rawNextStep =
                          RichFormattedEditingController.readMarkup(
                            nextStepController,
                          ).trim();

                      if (sessionOutcome == 'cancelada') {
                        final formattedNotes = rawNotes.isEmpty
                            ? '[Sessão Cancelada: $failureMotive]'
                            : '[Sessão Cancelada: $failureMotive] $rawNotes';

                        await repo.createStudySession(
                          studyId: study.id,
                          dateTime: DateTime.now(),
                          lessonCovered: study.currentLesson,
                          paragraphsCovered: null,
                          sessionNotes: formattedNotes,
                          nextStep: rawNextStep.isEmpty ? null : rawNextStep,
                          status: 'cancelada',
                          participantIds: [person.id],
                        );

                        if (rawNextStep.isNotEmpty) {
                          await repo.updateStudy(
                            study.copyWith(nextTopic: Value(rawNextStep)),
                          );
                        }
                      } else {
                        final lesson =
                            int.tryParse(lessonController.text.trim()) ??
                            selectedLesson;
                        final formattedNotes =
                            DashboardCalculator.formatSessionNotesWithAttendance(
                              rawNotes.isEmpty ? null : rawNotes,
                              attendanceCount,
                            );

                        await repo.createStudySession(
                          studyId: study.id,
                          dateTime: DateTime.now(),
                          lessonCovered: lesson,
                          paragraphsCovered:
                              paragraphsController.text.trim().isEmpty
                              ? null
                              : paragraphsController.text.trim(),
                          sessionNotes: formattedNotes,
                          nextStep: rawNextStep.isEmpty ? null : rawNextStep,
                          status: 'realizada',
                          participantIds: [person.id],
                        );

                        await repo.updateStudy(
                          study.copyWith(
                            currentLesson: Value(lesson),
                            currentParagraph: Value(
                              int.tryParse(paragraphsController.text.trim()) ??
                                  selectedEndPoint,
                            ),
                            nextTopic: Value(
                              rawNextStep.isEmpty ? null : rawNextStep,
                            ),
                            lastSessionAt: Value(DateTime.now()),
                          ),
                        );
                      }

                      if (scheduleNextStudy) {
                        // Prevenção de duplicidade: atualiza compromisso existente na mesma data ou cria novo
                        final existingAppts =
                            ref.read(appointmentsStreamProvider).value ?? [];
                        final existingOnDate = existingAppts.firstWhereOrNull(
                          (a) =>
                              a.deletedAt == null &&
                              a.status != 'cancelado' &&
                              a.personId == person.id &&
                              a.startTime.year == nextStudyDateTime.year &&
                              a.startTime.month == nextStudyDateTime.month &&
                              a.startTime.day == nextStudyDateTime.day,
                        );

                        if (existingOnDate != null) {
                          await repo.updateAppointment(
                            existingOnDate.copyWith(
                              studyId: Value(study.id),
                              startTime: nextStudyDateTime,
                              endTime: nextStudyDateTime.add(
                                Duration(minutes: nextStudyDuration),
                              ),
                              durationMinutes: nextStudyDuration,
                              status: 'confirmado',
                            ),
                          );
                        } else {
                          await repo.createAppointment(
                            personId: person.id,
                            studyId: study.id,
                            title: 'Estudo Bíblico: ${person.name}',
                            startTime: nextStudyDateTime,
                            endTime: nextStudyDateTime.add(
                              Duration(minutes: nextStudyDuration),
                            ),
                            durationMinutes: nextStudyDuration,
                            status: 'confirmado',
                            locationNotes: person.address != null
                                ? 'Local: ${person.address}'
                                : null,
                          );
                        }
                      }

                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              sessionOutcome == 'cancelada'
                                  ? 'Falha no estudo registrada ($failureMotive).'
                                  : 'Sessão registrada com sucesso! ($attendanceCount presentes computados)',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Salvar Sessão'),
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
