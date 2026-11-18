part of '../appointments_screen.dart';

extension _AppointmentsSyncAndIcsModals on _AppointmentsScreenState {
  void _showIcsExportResultDialog(BuildContext context, String icsData) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.successGreen),
            SizedBox(width: 8),
            Text('Arquivo .ics Gerado com Sucesso'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'O download do arquivo "ministerio_pessoal_agenda.ics" foi iniciado.\n\n'
              'Para importar no Google Agenda:\n'
              '1. Acesse calendar.google.com no computador.\n'
              '2. Clique em Configurações > Importar e exportar.\n'
              '3. Selecione o arquivo baixado e confirme a importação.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text(
                'Copiar Conteúdo iCal para a Área de Transferência',
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: icsData));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('iCal copiado para a área de transferência!'),
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _showPasteIcsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => ManagedTextControllers(
        initialTexts: const [''],
        builder: (ctx, ctrls) {
          final textController = ctrls[0];

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.content_paste, color: AppTheme.primaryBlue),
                SizedBox(width: 8),
                Text('Colar Conteúdo .ics / iCal'),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cole abaixo o texto do arquivo .ics (do Google Agenda, Apple Calendar ou outro aplicativo):',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: textController,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      hintText:
                          'BEGIN:VCALENDAR\nVERSION:2.0\nBEGIN:VEVENT\n...',
                      border: OutlineInputBorder(),
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
              ElevatedButton.icon(
                icon: const Icon(Icons.file_download_done, size: 16),
                label: const Text('Importar'),
                onPressed: () async {
                  final raw = textController.text.trim();
                  if (raw.isEmpty || !raw.contains('BEGIN:VEVENT')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Conteúdo iCal inválido ou sem eventos (VEVENT).',
                        ),
                      ),
                    );
                    return;
                  }
                  final res = await _importIcsContent(raw);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Importação concluída! ${res.created} novo(s), ${res.updated} atualizado(s).',
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pasteFromClipboard(BuildContext context) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty || !text.contains('BEGIN:VEVENT')) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'A área de transferência não contém eventos iCal válidos (VEVENT).',
            ),
          ),
        );
      }
      return;
    }
    final res = await _importIcsContent(text);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Importado da área de transferência! ${res.created} novo(s), ${res.updated} atualizado(s).',
          ),
        ),
      );
    }
  }

  void _showOfficialCalendarSyncModal(
    BuildContext context,
    List<AppointmentEntry> allAppts,
  ) {
    bool didScheduleUrlLoad = false;
    bool isSyncingGoogle = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ManagedTextControllers(
        initialTexts: const [''],
        builder: (ctx, ctrls) {
          final googleUrlController = ctrls[0];
          if (!didScheduleUrlLoad) {
            didScheduleUrlLoad = true;
            ref
                .read(appSettingsManagerProvider)
                .getString('saved_calendar_url')
                .then((val) {
                  if (ctx.mounted &&
                      val != null &&
                      val.isNotEmpty &&
                      googleUrlController.text.isEmpty) {
                    googleUrlController.text = val;
                  }
                });
          }

          return StatefulBuilder(
            builder: (ctx, setSheetState) {
              final isDark = Theme.of(ctx).brightness == Brightness.dark;

              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: 20,
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.sync_alt,
                                  color: AppTheme.primaryBlue,
                                  size: 24,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Sincronização de Calendários',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Integração oficial bidirecional com Google Agenda e Apple Calendar (iPhone/iPad).',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 16),

                        Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4285F4)
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.calendar_month,
                                        color: Color(0xFF4285F4),
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Google Agenda (Google Calendar)',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          Text(
                                            'calendar.google.com',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      icon: const Icon(
                                        Icons.open_in_browser,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'Abrir Google Agenda no Navegador',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      onPressed: () async {
                                        final uri = Uri.parse(
                                          'https://calendar.google.com',
                                        );
                                        if (await canLaunchUrl(uri)) {
                                          await launchUrl(
                                            uri,
                                            mode:
                                                LaunchMode.externalApplication,
                                          );
                                        }
                                      },
                                    ),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF1E40AF,
                                        ),
                                        foregroundColor: Colors.white,
                                      ),
                                      icon: const Icon(
                                        Icons.file_download,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'Exportar todos para Google Agenda (.ics)',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      onPressed: () {
                                        final icsData = _generateIcsFile(
                                          allAppts,
                                        );
                                        FileDownloader.download(
                                          'ministerio_pessoal_agenda.ics',
                                          icsData,
                                        );
                                        _showIcsExportResultDialog(
                                          context,
                                          icsData,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                const Text(
                                  'Importar / Puxar do Google Agenda:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF1E40AF),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF334155)
                                          : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: const Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Instruções passo a passo:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '1. Abra o Google Agenda no navegador (calendar.google.com).\n'
                                        '2. Clique em Configurações > Configurações das minhas agendas > Selecione sua agenda.\n'
                                        '3. Role até "Integrar agenda" e copie o "Endereço secreto no formato iCal".\n'
                                        '4. Cole o link abaixo ou baixe o arquivo .ics e importe aqui.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (kIsWeb) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.amber.shade700,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          size: 16,
                                          color: Colors.amber.shade800,
                                        ),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Text(
                                            'Dica Web: No navegador, use "Selecionar Arquivo .ics" ou "Baixar no Navegador" para importar com 1 clique sem restrições de CORS.',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                TextField(
                                  controller: googleUrlController,
                                  decoration: const InputDecoration(
                                    labelText: 'Endereço iCal / Webcal do Google Agenda',
                                    hintText: 'https://calendar.google.com/calendar/ical/.../basic.ics',
                                    isDense: true,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF1E40AF,
                                        ),
                                        foregroundColor: Colors.white,
                                      ),
                                      icon: const Icon(
                                        Icons.file_open,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'Selecionar Arquivo .ics',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      onPressed: () async {
                                        final picked =
                                            await IcsPickerHelper.pickIcsFile();
                                        if (picked != null &&
                                            picked.isNotEmpty) {
                                          final res = await _importIcsContent(
                                            picked,
                                          );
                                          if (ctx.mounted) Navigator.pop(ctx);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Google Agenda importado com sucesso! ${res.created} novo(s), ${res.updated} atualizado(s).',
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                    OutlinedButton.icon(
                                      icon: const Icon(
                                        Icons.download,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'Baixar no Navegador',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      onPressed: () async {
                                        final rawUrl = googleUrlController.text
                                            .trim();
                                        if (rawUrl.isEmpty) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Cole a URL do Google Agenda acima para baixar no navegador.',
                                                  ),
                                                ),
                                              );
                                          return;
                                        }
                                        var cleanUrl = rawUrl;
                                        if (cleanUrl.startsWith('webcal://')) {
                                          cleanUrl = cleanUrl.replaceFirst(
                                            'webcal://',
                                            'https://',
                                          );
                                        }
                                        final uri = Uri.parse(cleanUrl);
                                        if (await canLaunchUrl(uri)) {
                                          await launchUrl(
                                            uri,
                                            mode:
                                                LaunchMode.externalApplication,
                                          );
                                        }
                                      },
                                    ),
                                    OutlinedButton.icon(
                                      icon: isSyncingGoogle
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.sync, size: 16),
                                      label: Text(
                                        isSyncingGoogle
                                            ? 'Sincronizando...'
                                            : 'Sincronizar via Webcal',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      onPressed: isSyncingGoogle
                                          ? null
                                          : () async {
                                              final rawUrl = googleUrlController
                                                  .text
                                                  .trim();
                                              if (rawUrl.isEmpty) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Informe uma URL de calendário válida.',
                                                        ),
                                                      ),
                                                    );
                                                return;
                                              }
                                              setSheetState(
                                                () => isSyncingGoogle = true,
                                              );
                                              try {
                                                final res =
                                                    await _syncFromWebcalUrl(
                                                      rawUrl,
                                                    );
                                                if (res != null) {
                                                  if (ctx.mounted) {
                                                    Navigator.pop(ctx);
                                                  }
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'Google Agenda sincronizado com sucesso! ${res.created} novo(s), ${res.updated} atualizado(s).',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                } else {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Não foi possível obter calendário válido via Webcal.',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Erro na sincronização: $e',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              } finally {
                                                if (ctx.mounted) {
                                                  setSheetState(
                                                    () =>
                                                        isSyncingGoogle = false,
                                                  );
                                                }
                                              }
                                            },
                                    ),
                                    OutlinedButton.icon(
                                      icon: const Icon(
                                        Icons.content_paste,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'Colar Texto .ics',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      onPressed: () =>
                                          _showPasteIcsDialog(context),
                                    ),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.paste, size: 16),
                                      label: const Text(
                                        'Colar da Área de Transferência',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      onPressed: () =>
                                          _pasteFromClipboard(context),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),
                        Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981)
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.apple,
                                        color: Color(0xFF10B981),
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Apple Calendar / iCloud (iPhone / iPad)',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          Text(
                                            'Calendário nativo iOS / iPadOS',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF047857),
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(
                                    Icons.file_download,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Exportar para Apple Calendar (.ics)',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  onPressed: () {
                                    final icsData = _generateIcsFile(allAppts);
                                    FileDownloader.download(
                                      'ministerio_pessoal_agenda_apple.ics',
                                      icsData,
                                    );
                                    _showIcsExportResultDialog(
                                      context,
                                      icsData,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
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

  Future<void> _syncConnectedCalendars() async {
    if (_isCalendarSyncing) return;
    _updateState(() => _isCalendarSyncing = true);
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
      if (mounted) _updateState(() => _isCalendarSyncing = false);
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
}
