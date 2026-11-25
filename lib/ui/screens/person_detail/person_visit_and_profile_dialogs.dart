part of '../person_detail_screen.dart';

extension _PersonDetailVisitAndProfileDialogs on _PersonDetailScreenState {
  void _showEndReturnVisitDialog(
    BuildContext context,
    PersonEntry person,
    AppRepository repo,
  ) async {
    String selectedReason = 'Falta de interesse / tempo';
    if (!context.mounted) return;

    final coordinator = ref.read(scheduleReleaseCoordinatorProvider);
    final futureAppts = await coordinator.getFutureAppointmentsForRevisit(
      person.id,
    );

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
                  Icon(Icons.person_off_outlined, color: AppTheme.alertAmber),
                  SizedBox(width: 8),
                  Expanded(child: Text('Encerrar Revisita')),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Você está encerrando o acompanhamento de revisitas com ${person.name}. O contato NÃO será excluído e todas as visitas anteriores continuam preservadas no seu relatório e histórico.',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 14),

                    // Bloco de aviso de compromissos futuros de revisita
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
                                  'Agenda: ${futureAppts.length} compromisso(s) de retorno futuro(s)',
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
                              'Os lembretes locais programados serão removidos e visitas passadas permanecerão intactas.',
                              style: TextStyle(
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ] else
                            const Text(
                              'Nenhum compromisso de retorno futuro agendado.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),

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
                          value: 'Pediu para não ser visitado',
                          child: Text('Pediu para não ser visitado'),
                        ),
                        DropdownMenuItem(
                          value: 'Oposição familiar',
                          child: Text('Oposição familiar'),
                        ),
                        DropdownMenuItem(
                          value: 'Problemas de saúde / Falecido',
                          child: Text('Problemas de saúde / Falecido'),
                        ),
                        DropdownMenuItem(
                          value: 'Repassada para outro publicador',
                          child: Text('Repassada para outro publicador'),
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
                        hintText: 'Ex: Deixou portas abertas para uma ocasião futura...',
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
                    final extraNotes =
                        RichFormattedEditingController.readMarkup(
                          notesController,
                        ).trim();
                    final coordinator = ref.read(
                      scheduleReleaseCoordinatorProvider,
                    );
                    final result = await coordinator
                        .endRevisitWithScheduleRelease(
                          person: person,
                          endReason: selectedReason,
                          notes: extraNotes,
                          releaseFutureAppointments: true,
                        );

                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Revisita encerrada ($selectedReason). ${result.message}',
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

  Future<void> _reactivateReturnVisit(
    BuildContext context,
    AppRepository repo,
    PersonEntry person,
  ) async {
    await repo.updatePerson(
      person.copyWith(status: 'revisita', nextActionNote: const Value(null)),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Revisita com "${person.name}" reativada com sucesso!'),
        ),
      );
    }
  }

  Future<void> _openLocationPickerForPerson(
    BuildContext context,
    AppRepository repo,
    PersonEntry person,
  ) async {
    final res = await showDialog<ReverseGeocodingResult>(
      context: context,
      builder: (_) => MapLocationPickerDialog(
        initialLat: person.latitude,
        initialLng: person.longitude,
      ),
    );
    if (res != null) {
      final updatedAddr =
          (person.address == null || person.address!.isEmpty) &&
              res.streetAndNumber.isNotEmpty
          ? res.streetAndNumber
          : person.address;
      await repo.updatePerson(
        person.copyWith(
          latitude: Value(res.latitude),
          longitude: Value(res.longitude),
          address: Value(updatedAddr),
        ),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Localização de "${person.name}" atualizada com sucesso no mapa!',
            ),
          ),
        );
      }
    }
  }

  Future<void> _openExternalGoogleMaps(PersonEntry person) async {
    final query =
        (person.latitude != null &&
            person.longitude != null &&
            (person.latitude != 0.0 || person.longitude != 0.0))
        ? '${person.latitude},${person.longitude}'
        : Uri.encodeComponent(person.address ?? person.name);
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showEditPersonDialog(
    BuildContext context,
    AppRepository repo,
    PersonEntry person,
  ) {
    String initialStreet = '';
    String initialNeighborhood = '';
    String initialRef = '';
    final rawAddr = person.address ?? '';
    if (rawAddr.contains('Bairro:') || rawAddr.contains('Ref:')) {
      final parts = rawAddr.split(' - ');
      final streetParts = <String>[];
      for (final p in parts) {
        final t = p.trim();
        if (t.toLowerCase().startsWith('bairro:')) {
          initialNeighborhood = t.substring(7).trim();
        } else if (t.toLowerCase().startsWith('ref:')) {
          initialRef = t.substring(4).trim();
        } else {
          streetParts.add(t);
        }
      }
      initialStreet = streetParts.join(' - ');
    } else if (rawAddr.contains(' - ')) {
      final parts = rawAddr.split(' - ');
      if (parts.length >= 2 &&
          parts[1].trim().toLowerCase().startsWith('bairro ')) {
        initialStreet = parts[0].trim();
        initialNeighborhood = parts[1].trim().substring(7).trim();
        if (parts.length >= 3) {
          initialRef = parts.sublist(2).join(' - ').trim();
        }
      } else {
        initialStreet = rawAddr;
      }
    } else {
      initialStreet = rawAddr;
    }

    String currentStatus = person.status;
    DateTime editFirstContact = person.firstContactAt;
    DateTime? editLastContact = person.lastContactAt;
    final sectors = ref.read(sectorsStreamProvider).value ?? [];

    showDialog(
      context: context,
      builder: (ctx) => ManagedTextControllers(
        initialTexts: [
          person.name,
          person.phone ?? '',
          initialStreet,
          initialNeighborhood,
          initialRef,
          person.latitude != null && person.latitude != 0.0
              ? person.latitude!.toStringAsFixed(6)
              : '',
          person.longitude != null && person.longitude != 0.0
              ? person.longitude!.toStringAsFixed(6)
              : '',
          person.preferredSchedule ?? '',
        ],
        builder: (ctx, ctrls) {
          final nameCtrl = ctrls[0];
          final phoneCtrl = ctrls[1];
          final addrCtrl = ctrls[2];
          final neighborhoodCtrl = ctrls[3];
          final refCtrl = ctrls[4];
          final latCtrl = ctrls[5];
          final lngCtrl = ctrls[6];
          final scheduleCtrl = ctrls[7];
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final isDark = Theme.of(ctx).brightness == Brightness.dark;
              return Dialog(
                backgroundColor: isDark
                    ? const Color(0xFF1E293B)
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 540,
                    maxHeight: 680,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.edit,
                                  color: AppTheme.primaryBlue,
                                  size: 24,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Editar Dados do Contato',
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
                        const Divider(height: 20),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: nameCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Nome Completo *',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: phoneCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Telefone / WhatsApp',
                                    hintText: '(11) 98765-4321',
                                  ),
                                  keyboardType: TextInputType.phone,
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  initialValue: currentStatus,
                                  decoration: const InputDecoration(
                                    labelText: 'Situação / Classificação',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'interessado',
                                      child: Text('👤 Interessado'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'revisita',
                                      child: Text('🔄 Revisita Ativa'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'estudo',
                                      child: Text('📖 Estudo Bíblico'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'revisita_passada',
                                      child: Text('📦 Revisita Repassada'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'revisita_encerrada',
                                      child: Text('⛔ Revisita Encerrada'),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setDialogState(() => currentStatus = val);
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryBlue.withValues(
                                      alpha: 0.06,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppTheme.primaryBlue.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(
                                            Icons.history_edu,
                                            size: 16,
                                            color: AppTheme.primaryBlue,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'Histórico Prévio (Primeiro Uso / Contato Antigo)',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryBlue,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              icon: const Icon(
                                                Icons.calendar_today,
                                                size: 14,
                                              ),
                                              label: Text(
                                                '1º Contato: ${AppDateUtils.formatDate(editFirstContact)}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                              ),
                                              onPressed: () async {
                                                final p = await showDatePicker(
                                                  context: context,
                                                  initialDate: editFirstContact,
                                                  firstDate: DateTime(2010),
                                                  lastDate: DateTime.now(),
                                                );
                                                if (p != null) {
                                                  setDialogState(
                                                    () => editFirstContact = p,
                                                  );
                                                }
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              icon: const Icon(
                                                Icons.history,
                                                size: 14,
                                              ),
                                              label: Text(
                                                editLastContact != null
                                                    ? 'Últ. Visita: ${AppDateUtils.formatDate(editLastContact!)}'
                                                    : 'Última Visita (opcional)',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                              ),
                                              onPressed: () async {
                                                final p = await showDatePicker(
                                                  context: context,
                                                  initialDate:
                                                      editLastContact ??
                                                      DateTime.now(),
                                                  firstDate: DateTime(2010),
                                                  lastDate: DateTime.now(),
                                                );
                                                if (p != null) {
                                                  setDialogState(
                                                    () => editLastContact = p,
                                                  );
                                                }
                                              },
                                            ),
                                          ),
                                          if (editLastContact != null)
                                            IconButton(
                                              icon: const Icon(
                                                Icons.clear,
                                                size: 14,
                                              ),
                                              tooltip: 'Remover data',
                                              onPressed: () => setDialogState(
                                                () => editLastContact = null,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Localização & Bairro / Setor',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: addrCtrl,
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Endereço (Rua, Número, Bloco/Apto)',
                                    hintText:
                                        'Ex: Rua das Flores, 120, Apto 42',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: neighborhoodCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Bairro / Setor',
                                          hintText:
                                              'Ex: Centro, Vila Nova, Porto...',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: refCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Ponto de Referência',
                                          hintText: 'Ex: Próximo à padaria',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (sectors.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: sectors.map((sec) {
                                        final isChosen =
                                            neighborhoodCtrl.text
                                                .trim()
                                                .toLowerCase() ==
                                            sec.name.toLowerCase();
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            right: 6,
                                          ),
                                          child: ActionChip(
                                            avatar: Icon(
                                              Icons.location_city,
                                              size: 14,
                                              color: isChosen
                                                  ? Colors.white
                                                  : AppTheme.primaryBlue,
                                            ),
                                            label: Text(
                                              sec.name,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isChosen
                                                    ? Colors.white
                                                    : null,
                                              ),
                                            ),
                                            backgroundColor: isChosen
                                                ? AppTheme.primaryBlue
                                                : null,
                                            onPressed: () {
                                              setDialogState(() {
                                                neighborhoodCtrl.text =
                                                    sec.name;
                                              });
                                            },
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: latCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Latitude GPS',
                                          hintText: '-3.1022',
                                        ),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                              signed: true,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: lngCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Longitude GPS',
                                          hintText: '-67.9397',
                                        ),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                              signed: true,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      icon: const Icon(
                                        Icons.my_location,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        '🧭 GPS Atual',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      onPressed: () async {
                                        final pos =
                                            await GeolocationHelper.getCurrentLocation();
                                        if (pos != null) {
                                          setDialogState(() {
                                            latCtrl.text = pos.latitude
                                                .toStringAsFixed(6);
                                            lngCtrl.text = pos.longitude
                                                .toStringAsFixed(6);
                                          });
                                          final geo =
                                              await GeocodingService.reverseGeocode(
                                                pos.latitude,
                                                pos.longitude,
                                                db: ref.read(databaseProvider),
                                              );
                                          if (geo != null) {
                                            setDialogState(() {
                                              if (addrCtrl.text
                                                      .trim()
                                                      .isEmpty &&
                                                  geo
                                                      .streetAndNumber
                                                      .isNotEmpty) {
                                                addrCtrl.text =
                                                    geo.streetAndNumber;
                                              }
                                              if (neighborhoodCtrl.text
                                                      .trim()
                                                      .isEmpty &&
                                                  geo.neighborhood != null) {
                                                neighborhoodCtrl.text =
                                                    geo.neighborhood!;
                                              }
                                            });
                                          }
                                        }
                                      },
                                    ),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.map, size: 16),
                                      label: const Text(
                                        '🗺️ Escolher no Mapa',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      onPressed: () async {
                                        final curLat = double.tryParse(
                                          latCtrl.text.trim(),
                                        );
                                        final curLng = double.tryParse(
                                          lngCtrl.text.trim(),
                                        );
                                        final res =
                                            await showDialog<
                                              ReverseGeocodingResult
                                            >(
                                              context: context,
                                              builder: (_) =>
                                                  MapLocationPickerDialog(
                                                    initialLat: curLat,
                                                    initialLng: curLng,
                                                  ),
                                            );
                                        if (res != null) {
                                          setDialogState(() {
                                            latCtrl.text = res.latitude
                                                .toStringAsFixed(6);
                                            lngCtrl.text = res.longitude
                                                .toStringAsFixed(6);
                                            if (res
                                                    .streetAndNumber
                                                    .isNotEmpty &&
                                                addrCtrl.text.trim().isEmpty) {
                                              addrCtrl.text =
                                                  res.streetAndNumber;
                                            }
                                            if (res.neighborhood != null &&
                                                res.neighborhood!.isNotEmpty &&
                                                neighborhoodCtrl.text
                                                    .trim()
                                                    .isEmpty) {
                                              neighborhoodCtrl.text =
                                                  res.neighborhood!;
                                            }
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: scheduleCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Dia e Horário Habitual',
                                    hintText: 'Ex: Sábado às 09:00',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Salvar Alterações'),
                              onPressed: () async {
                                final name = nameCtrl.text.trim();
                                if (name.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'O nome do contato é obrigatório.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                final phone = phoneCtrl.text.trim();
                                final addrParts = <String>[];
                                if (addrCtrl.text.trim().isNotEmpty) {
                                  addrParts.add(addrCtrl.text.trim());
                                }
                                if (neighborhoodCtrl.text.trim().isNotEmpty) {
                                  addrParts.add(
                                    'Bairro: ${neighborhoodCtrl.text.trim()}',
                                  );
                                }
                                if (refCtrl.text.trim().isNotEmpty) {
                                  addrParts.add('Ref: ${refCtrl.text.trim()}');
                                }
                                final fullAddress = addrParts.isNotEmpty
                                    ? addrParts.join(' - ')
                                    : null;

                                final lat = double.tryParse(
                                  latCtrl.text.trim(),
                                );
                                final lng = double.tryParse(
                                  lngCtrl.text.trim(),
                                );
                                final sched = scheduleCtrl.text.trim();

                                if (currentStatus == 'revisita_encerrada' &&
                                    person.status != 'revisita_encerrada') {
                                  final coordinator = ref.read(
                                    scheduleReleaseCoordinatorProvider,
                                  );
                                  final updatedPerson = person.copyWith(
                                    name: name,
                                    phone: Value(
                                      phone.isNotEmpty ? phone : null,
                                    ),
                                    address: Value(fullAddress),
                                    latitude: Value(lat),
                                    longitude: Value(lng),
                                    firstContactAt: editFirstContact,
                                    lastContactAt: Value(editLastContact),
                                    preferredSchedule: Value(
                                      sched.isNotEmpty ? sched : null,
                                    ),
                                    status: currentStatus,
                                    updatedAt: DateTime.now(),
                                  );
                                  await coordinator
                                      .endRevisitWithScheduleRelease(
                                        person: updatedPerson,
                                        endReason: 'Status alterado na edição do contato',
                                        releaseFutureAppointments: true,
                                      );
                                } else {
                                  await repo.updatePerson(
                                    person.copyWith(
                                      name: name,
                                      phone: Value(
                                        phone.isNotEmpty ? phone : null,
                                      ),
                                      address: Value(fullAddress),
                                      latitude: Value(lat),
                                      longitude: Value(lng),
                                      firstContactAt: editFirstContact,
                                      lastContactAt: Value(editLastContact),
                                      preferredSchedule: Value(
                                        sched.isNotEmpty ? sched : null,
                                      ),
                                      status: currentStatus,
                                      updatedAt: DateTime.now(),
                                    ),
                                  );
                                }

                                if (ctx.mounted) Navigator.pop(ctx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Dados do contato atualizados com sucesso!',
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
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

  // Modal Unificado: Registro de Visita, Estudo Bíblico e Agendamento Global (Fluxo Rápido Atômico)
  void _showQuickVisitDialog(
    BuildContext context,
    PersonEntry person,
    BibleStudyEntry? existingStudy,
  ) {
    final isStudiesEnabled = ref.read(
      isFeatureEnabledProvider(AppFeature.studies),
    );
    final draft = _PersonDetailScreenState._quickVisitDrafts[person.id];

    String selectedType = draft?['type'] as String? ?? 'revisita';
    bool recordStudy =
        isStudiesEnabled &&
        (draft?['recordStudy'] as bool? ?? (selectedType == 'estudo'));
    String selectedResult = 'Conversa receptiva';
    DateTime selectedDate = DateTime.now();
    bool didAttachListeners = false;

    // Campos do Estudo Bíblico
    String selectedPublicationId = existingStudy?.publicationId ?? 'lff-book';
    int attendanceCount = 1;

    // Campos de Agendamento Global com AvailabilityEngine
    bool scheduleReturn = true;
    final allApptsList = ref.read(appointmentsStreamProvider).value ?? [];
    AppointmentEntry? existingUpcomingAppt;
    final upcomingList =
        allApptsList
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
    if (upcomingList.isNotEmpty) {
      existingUpcomingAppt = upcomingList.first;
    }

    final freq = (existingStudy?.frequency ?? 'semanal').toLowerCase();
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

    DateTime returnDateTime;
    int returnDuration =
        existingUpcomingAppt?.durationMinutes ??
        ((selectedType == 'estudo' || recordStudy) ? 60 : 30);

    if (existingUpcomingAppt != null) {
      returnDateTime = existingUpcomingAppt.startTime;
    } else {
      final target = DateTime.now().add(Duration(days: daysToAdd));
      returnDateTime = DateTime(target.year, target.month, target.day, 10, 0);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ManagedTextControllers(
        initialTexts: [
          draft?['notes'] as String? ?? '',
          draft?['topics'] as String? ?? '',
          draft?['nextStep'] as String? ?? existingStudy?.nextTopic ?? '',
          existingStudy?.currentLesson?.toString() ?? '1',
          existingStudy?.currentParagraph != null
              ? '${existingStudy!.currentParagraph}'
              : '1-5',
        ],
        customFactories: [
          (text) => RichFormattedEditingController.fromMarkup(text),
          (text) => RichFormattedEditingController.fromMarkup(text),
          (text) => RichFormattedEditingController.fromMarkup(text),
          null,
          null,
        ],
        builder: (ctx, ctrls) {
          final notesController = ctrls[0];
          final topicsController = ctrls[1];
          final nextStepController = ctrls[2];
          final lessonController = ctrls[3];
          final paragraphsController = ctrls[4];
          void updateDraft() {
            _PersonDetailScreenState._quickVisitDrafts[person.id] = {
              'notes': RichFormattedEditingController.readMarkup(
                notesController,
              ),
              'topics': RichFormattedEditingController.readMarkup(
                topicsController,
              ),
              'nextStep': RichFormattedEditingController.readMarkup(
                nextStepController,
              ),
              'type': selectedType,
              'recordStudy': recordStudy,
            };
          }

          if (!didAttachListeners) {
            didAttachListeners = true;
            notesController.addListener(updateDraft);
            topicsController.addListener(updateDraft);
            nextStepController.addListener(updateDraft);
          }

          return StatefulBuilder(
            builder: (ctx, setSheetState) {
              final isDark = Theme.of(ctx).brightness == Brightness.dark;
              final allAppts = ref.read(appointmentsStreamProvider).value ?? [];

              return Padding(
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
                          Expanded(
                            child: Text(
                              'Registrar Conversa com ${person.name}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF4F46E5),
                              side: const BorderSide(
                                color: Color(0xFF4F46E5),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.mic, size: 20),
                            label: const Text(
                              'Preencher via Registro Rápido / Ditado (15s)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              QuickVoiceNoteDialog.show(
                                context: context,
                                person: person,
                                linkedStudy: existingStudy,
                              );
                            },
                          ),
                        ),
                      ),
                      if (draft != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentTeal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.history_toggle_off,
                                size: 16,
                                color: AppTheme.accentTeal,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Rascunho recuperado automaticamente.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.accentTeal,
                                  ),
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () {
                                  _PersonDetailScreenState._quickVisitDrafts
                                      .remove(person.id);
                                  setSheetState(() {
                                    notesController.clear();
                                    topicsController.clear();
                                    nextStepController.clear();
                                  });
                                },
                                child: const Text(
                                  'Limpar',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      DropdownButtonFormField<String>(
                        initialValue: selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de Contato',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'revisita',
                            child: Text('Revisita Presencial'),
                          ),
                          if (isStudiesEnabled)
                            const DropdownMenuItem(
                              value: 'estudo',
                              child: Text('Estudo Bíblico'),
                            ),
                          const DropdownMenuItem(
                            value: 'conversa_inicial',
                            child: Text('Conversa Inicial'),
                          ),
                          const DropdownMenuItem(
                            value: 'contato_telefonico',
                            child: Text('Contato Telefônico / Carta'),
                          ),
                          const DropdownMenuItem(
                            value: 'tentativa_sem_contato',
                            child: Text('Tentativa sem Contato (Não contou)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setSheetState(() {
                              selectedType = val;
                              if (val == 'estudo') {
                                recordStudy = true;
                                returnDuration = 60;
                              } else if (existingStudy == null &&
                                  person.status != 'estudo') {
                                returnDuration = 30;
                              }
                              updateDraft();
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 10),

                      if (isStudiesEnabled && selectedType != 'estudo') ...[
                        InkWell(
                          onTap: () {
                            setSheetState(() {
                              recordStudy = !recordStudy;
                              if (recordStudy) returnDuration = 60;
                              updateDraft();
                            });
                          },
                          child: Row(
                            children: [
                              Checkbox(
                                value: recordStudy,
                                activeColor: const Color(0xFF7C3AED),
                                onChanged: (val) {
                                  setSheetState(() {
                                    recordStudy = val ?? false;
                                    if (recordStudy) returnDuration = 60;
                                    updateDraft();
                                  });
                                },
                              ),
                              const Expanded(
                                child: Text(
                                  'Considerou matéria de estudo bíblico nesta conversa',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF7C3AED),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Seção Especial de Estudo Bíblico (Unificação de fluxo)
                      if (selectedType == 'estudo' || recordStudy) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED)
                                .withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF7C3AED)
                                  .withValues(alpha: 0.25),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.menu_book,
                                    size: 18,
                                    color: Color(0xFF7C3AED),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    existingStudy != null
                                        ? 'Progresso do Estudo Bíblico'
                                        : 'Novo Estudo Bíblico Integrado',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFF7C3AED),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                initialValue: selectedPublicationId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Publicação',
                                ),
                                items: PublicationCatalog.allPublications.map((
                                  p,
                                ) {
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
                                    setSheetState(
                                      () => selectedPublicationId = val,
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: lessonController,
                                      decoration: const InputDecoration(
                                        labelText: 'Lição estudada',
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: paragraphsController,
                                      decoration: const InputDecoration(
                                        labelText: 'Parágrafos considerados',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Contagem de Assistência / Presentes
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Assistência / Ouvintes',
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
                                            setSheetState(
                                              () => attendanceCount--,
                                            );
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
                                          setSheetState(
                                            () => attendanceCount++,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      TextField(
                        controller: topicsController,
                        decoration: InputDecoration(
                          labelText: 'Ponto Bíblico / Assunto considerado',
                          hintText: 'Ex: Mateus 24:14 ou Lição 02',
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
                                  controller: topicsController,
                                  onChanged: updateDraft,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      RichMarkdownToolbar(
                        controller: notesController,
                        enableHighlightPalette: false,
                        enableImagePicker: false,
                        enableCrossReferences: true,
                        onChanged: updateDraft,
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: notesController,
                        decoration: const InputDecoration(
                          labelText: 'Anotações da conversa',
                          hintText:
                              'Dúvidas expressas pelo morador, comentários...',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nextStepController,
                        decoration: InputDecoration(
                          labelText: 'Próximo passo / Próximo estudo combinado',
                          hintText:
                              'Ex: Responder por que Deus permite o sofrimento',
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
                                  onChanged: updateDraft,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // SEÇÃO DE AGENDAMENTO GLOBAL COM AVAILABILITY ENGINE
                      GlobalAppointmentSchedulingSection(
                        title: (selectedType == 'estudo' || recordStudy)
                            ? 'Agendar Próximo Estudo'
                            : 'Agendar Próximo Retorno',
                        isEnabled: scheduleReturn,
                        onToggle: (val) =>
                            setSheetState(() => scheduleReturn = val),
                        selectedDateTime: returnDateTime,
                        onDateTimeChanged: (dt) =>
                            setSheetState(() => returnDateTime = dt),
                        durationMinutes: returnDuration,
                        onDurationChanged: (dur) =>
                            setSheetState(() => returnDuration = dur),
                        existingAppointments: allAppts,
                        existingPersonAppointment: existingUpcomingAppt,
                        frequencyText: freqLabel,
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                (selectedType == 'estudo' || recordStudy)
                                ? const Color(0xFF7C3AED)
                                : AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () async {
                            if (scheduleReturn) {
                              final availability =
                                  AvailabilityEngine.checkAvailability(
                                    startTime: returnDateTime,
                                    durationMinutes: returnDuration,
                                    existingAppointments: allAppts,
                                  );
                              final proceed =
                                  await GlobalAppointmentSchedulingSection.confirmConflictIfNeeded(
                                    context: context,
                                    availability: availability,
                                  );
                              if (!proceed) return;
                            }

                            final isStudyConsidered =
                                selectedType == 'estudo' || recordStudy;
                            final repo = ref.read(repositoryProvider);
                            String? appointmentId;

                            // 1. Agendamento Global (se ativado)
                            if (scheduleReturn) {
                              final apptTitle = isStudyConsidered
                                  ? 'Estudo Bíblico: ${person.name}'
                                  : 'Revisita: ${person.name}';

                              // Prevenção de duplicidade: atualiza compromisso existente na mesma data ou cria novo
                              final existingAppts =
                                  ref.read(appointmentsStreamProvider).value ??
                                  [];
                              final existingOnDate = existingAppts
                                  .firstWhereOrNull(
                                    (a) =>
                                        a.deletedAt == null &&
                                        a.status != 'cancelado' &&
                                        a.personId == person.id &&
                                        a.startTime.year ==
                                            returnDateTime.year &&
                                        a.startTime.month ==
                                            returnDateTime.month &&
                                        a.startTime.day == returnDateTime.day,
                                  );

                              if (existingOnDate != null) {
                                await repo.updateAppointment(
                                  existingOnDate.copyWith(
                                    studyId: existingStudy != null
                                        ? Value(existingStudy.id)
                                        : const Value.absent(),
                                    startTime: returnDateTime,
                                    endTime: returnDateTime.add(
                                      Duration(minutes: returnDuration),
                                    ),
                                    durationMinutes: returnDuration,
                                    status: 'confirmado',
                                  ),
                                );
                                appointmentId = existingOnDate.id;
                              } else {
                                final appt = await repo.createAppointment(
                                  personId: person.id,
                                  studyId: existingStudy?.id,
                                  title: apptTitle,
                                  startTime: returnDateTime,
                                  endTime: returnDateTime.add(
                                    Duration(minutes: returnDuration),
                                  ),
                                  durationMinutes: returnDuration,
                                  status: 'confirmado',
                                  locationNotes: person.address != null
                                      ? 'Local: ${person.address}'
                                      : null,
                                );
                                appointmentId = appt.id;
                              }
                            }

                            // 2. Registro da Visita (Atômico)
                            final rawNotes =
                                RichFormattedEditingController.readMarkup(
                                  notesController,
                                ).trim();
                            final rawTopics =
                                RichFormattedEditingController.readMarkup(
                                  topicsController,
                                ).trim();
                            final rawNextStep =
                                RichFormattedEditingController.readMarkup(
                                  nextStepController,
                                ).trim();
                            final formattedNotes = isStudyConsidered
                                ? DashboardCalculator.formatSessionNotesWithAttendance(
                                    rawNotes.isEmpty ? null : rawNotes,
                                    attendanceCount,
                                  )
                                : (rawNotes.isEmpty ? null : rawNotes);

                            await repo.createVisit(
                              personId: person.id,
                              dateTime: selectedDate,
                              contactType: selectedType,
                              result: selectedResult,
                              topicsDiscussed: rawTopics.isEmpty
                                  ? null
                                  : rawTopics,
                              notes: formattedNotes,
                              nextStep: rawNextStep.isEmpty
                                  ? null
                                  : rawNextStep,
                              suggestedReturnDate: scheduleReturn
                                  ? returnDateTime
                                  : null,
                              appointmentId: appointmentId,
                            );

                            // 3. Registro do Estudo e Sessão (se tipo Estudo ou matéria considerada)
                            if (isStudyConsidered) {
                              final lesson =
                                  int.tryParse(lessonController.text.trim()) ??
                                  1;
                              final paraText =
                                  paragraphsController.text.trim().isEmpty
                                  ? '1-5'
                                  : paragraphsController.text.trim();

                              String studyId;
                              if (existingStudy != null) {
                                studyId = existingStudy.id;
                              } else {
                                final newStudy = await repo.createStudy(
                                  title: 'Estudo de ${person.name}',
                                  publicationId: selectedPublicationId,
                                  language: 'pt',
                                  currentLesson: lesson,
                                  currentParagraph: int.tryParse(paraText) ?? 1,
                                  participantPersonIds: [person.id],
                                  primaryParticipantId: person.id,
                                );
                                studyId = newStudy.id;
                              }

                              await repo.createStudySession(
                                studyId: studyId,
                                dateTime: selectedDate,
                                publicationCode: selectedPublicationId,
                                lessonCovered: lesson,
                                paragraphsCovered: paraText,
                                sessionNotes: formattedNotes,
                                nextStep: rawNextStep.isEmpty
                                    ? null
                                    : rawNextStep,
                                status: 'realizada',
                                participantIds: [person.id],
                              );

                              if (person.status != 'estudo') {
                                await repo.updatePerson(
                                  person.copyWith(status: 'estudo'),
                                );
                              }
                            }

                            _PersonDetailScreenState._quickVisitDrafts.remove(
                              person.id,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);

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
                            (selectedType == 'estudo' || recordStudy)
                                ? 'Salvar Visita & Estudo Bíblico'
                                : 'Salvar Visita',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Modal de Agendamento Tipo Consultório (com Verificação Instantânea de Conflitos)
  void _showScheduleDialog(BuildContext context, PersonEntry person) {
    DateTime selectedDateTime = DateTime.now().add(
      const Duration(days: 1, hours: 2),
    );
    selectedDateTime = DateTime(
      selectedDateTime.year,
      selectedDateTime.month,
      selectedDateTime.day,
      selectedDateTime.hour,
      selectedDateTime.minute < 30 ? 0 : 30,
    );

    int durationMinutes = 30;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final allAppts = ref.read(appointmentsStreamProvider).value ?? [];

          return AlertDialog(
            title: Text('Agendar Retorno: ${person.name}'),
            content: SingleChildScrollView(
              child: GlobalAppointmentSchedulingSection(
                title: 'Data e Horário do Retorno',
                isEnabled: true,
                showHeaderToggle: false,
                onToggle: (_) {},
                selectedDateTime: selectedDateTime,
                onDateTimeChanged: (dt) =>
                    setDialogState(() => selectedDateTime = dt),
                durationMinutes: durationMinutes,
                onDurationChanged: (dur) =>
                    setDialogState(() => durationMinutes = dur),
                existingAppointments: allAppts,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final availability = AvailabilityEngine.checkAvailability(
                    startTime: selectedDateTime,
                    durationMinutes: durationMinutes,
                    existingAppointments: allAppts,
                  );
                  final proceed =
                      await GlobalAppointmentSchedulingSection.confirmConflictIfNeeded(
                        context: context,
                        availability: availability,
                      );
                  if (!proceed) return;

                  final repo = ref.read(repositoryProvider);
                  await repo.createAppointment(
                    personId: person.id,
                    title: 'Retorno: ${person.name}',
                    startTime: selectedDateTime,
                    endTime: selectedDateTime.add(
                      Duration(minutes: durationMinutes),
                    ),
                    durationMinutes: durationMinutes,
                    status: 'confirmado',
                    locationNotes: person.address != null
                        ? 'Local: ${person.address}'
                        : null,
                  );

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Compromisso agendado na agenda com sucesso!',
                        ),
                      ),
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

  Future<void> _saveNotes(
    AppRepository repo,
    PersonEntry person,
    List<Map<String, dynamic>> notes,
  ) async {
    final jsonStr = notes.isEmpty ? null : jsonEncode(notes);
    await repo.updatePerson(person.copyWith(generalNotes: Value(jsonStr)));
  }

  List<Map<String, dynamic>> _parseTargets(String? raw) {
    return DoorstepBriefingHelper.parseTargets(raw);
  }

  Future<void> _saveTargets(
    AppRepository repo,
    PersonEntry person,
    List<Map<String, dynamic>> targets,
  ) async {
    final jsonStr = targets.isEmpty ? null : jsonEncode(targets);
    await repo.updatePerson(
      person.copyWith(contactRestrictions: Value(jsonStr)),
    );
  }

  // Dialog para definir Dia e Horário Habitual (ex: "Sábado às 09:00")
  void _showEditPreferredScheduleDialog(
    BuildContext context,
    PersonEntry person,
  ) {
    final daysOfWeek = [
      'Segunda-feira',
      'Terça-feira',
      'Quarta-feira',
      'Quinta-feira',
      'Sexta-feira',
      'Sábado',
      'Domingo',
      'Personalizado',
    ];

    String selectedDay = 'Sábado';
    TimeOfDay selectedTime = const TimeOfDay(hour: 9, minute: 0);
    bool isCustom = false;

    if (person.preferredSchedule != null &&
        person.preferredSchedule!.contains(' às ')) {
      final parts = person.preferredSchedule!.split(' às ');
      final dayCandidate = parts[0].trim();
      final timeCandidate = parts[1].trim();
      if (daysOfWeek.contains(dayCandidate) &&
          dayCandidate != 'Personalizado') {
        selectedDay = dayCandidate;
      } else {
        isCustom = true;
      }
      final timeParts = timeCandidate.split(':');
      if (timeParts.length == 2) {
        final h = int.tryParse(timeParts[0]);
        final m = int.tryParse(timeParts[1]);
        if (h != null && m != null) {
          selectedTime = TimeOfDay(hour: h, minute: m);
        }
      }
    } else if (person.preferredSchedule != null &&
        person.preferredSchedule!.isNotEmpty) {
      isCustom = true;
    }

    showDialog(
      context: context,
      builder: (ctx) => ManagedTextControllers(
        initialTexts: [person.preferredSchedule ?? 'Sábado às 09:00'],
        builder: (ctx, ctrls) {
          final customController = ctrls[0];
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final formattedTime =
                  '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
              final previewText = isCustom
                  ? customController.text
                  : '$selectedDay às $formattedTime';

              return AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.alarm, color: Color(0xFF7C3AED)),
                    SizedBox(width: 8),
                    Text('Dia e Horário Habitual'),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Defina o dia e horário habitual do estudo bíblico (ex: "Sábado às 09:00").',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (!isCustom) ...[
                        DropdownButtonFormField<String>(
                          initialValue: selectedDay,
                          decoration: const InputDecoration(
                            labelText: 'Dia da Semana',
                          ),
                          items: daysOfWeek
                              .map(
                                (d) =>
                                    DropdownMenuItem(value: d, child: Text(d)),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              if (val == 'Personalizado') {
                                setDialogState(() => isCustom = true);
                              } else {
                                setDialogState(() => selectedDay = val);
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Horário Específico',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                                Text(
                                  formattedTime,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF7C3AED),
                                  ),
                                ),
                              ],
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.access_time, size: 18),
                              label: const Text('Selecionar Hora'),
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: selectedTime,
                                );
                                if (picked != null) {
                                  setDialogState(() => selectedTime = picked);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () =>
                              setDialogState(() => isCustom = true),
                          child: const Text(
                            'Escrever texto livre personalizado...',
                          ),
                        ),
                      ] else ...[
                        TextField(
                          controller: customController,
                          decoration: const InputDecoration(
                            labelText: 'Horário habitual personalizado',
                            hintText:
                                'Ex: Sábado às 09:00 ou Domingos após reunião',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () =>
                              setDialogState(() => isCustom = false),
                          child: const Text(
                            'Voltar para seleção de dia e hora padrão',
                          ),
                        ),
                      ],
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
                                'Será salvo como: "$previewText"',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF7C3AED),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final textToSave = isCustom
                          ? customController.text.trim()
                          : '$selectedDay às $formattedTime';
                      final repo = ref.read(repositoryProvider);
                      await repo.updatePerson(
                        person.copyWith(preferredSchedule: Value(textToSave)),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Horário habitual atualizado para "$textToSave"',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Salvar Horário'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // Dialog para adicionar ou editar Necessidade / Observação
  void _showAddOrEditNoteDialog(
    BuildContext context,
    AppRepository repo,
    PersonEntry person, [
    Map<String, dynamic>? noteToEdit,
  ]) {
    final isEditing = noteToEdit != null;

    showDialog(
      context: context,
      builder: (ctx) => ManagedTextControllers(
        initialTexts: [noteToEdit?['text'] ?? ''],
        customFactories: [
          (text) => RichFormattedEditingController.fromMarkup(text),
        ],
        builder: (ctx, ctrls) {
          final textController = ctrls[0];

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.note_alt_outlined, color: AppTheme.accentTeal),
                const SizedBox(width: 8),
                Text(
                  isEditing
                      ? 'Editar Necessidade / Obs.'
                      : 'Nova Necessidade / Obs.',
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Registre circunstâncias familiares, dúvidas levantadas, assuntos de interesse ou necessidades de ${person.name}.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  RichMarkdownToolbar(
                    controller: textController,
                    enableHighlightPalette: false,
                    enableImagePicker: false,
                    enableCrossReferences: true,
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: textController,
                    decoration: const InputDecoration(
                      labelText: 'Descrição da necessidade ou observação *',
                      hintText: 'Ex: Perdeu um familiar, tem dúvidas sobre a oração, etc.',
                    ),
                    maxLines: 4,
                    autofocus: true,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 14,
                        color: AppTheme.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isEditing
                            ? 'Criado em: ${AppDateUtils.formatDateTimeWithAt(DateTime.tryParse(noteToEdit['createdAt'] ?? ''))}'
                            : 'Registro de data e hora automático.',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
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
                  backgroundColor: AppTheme.accentTeal,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final text = RichFormattedEditingController.readMarkup(
                    textController,
                  ).trim();
                  if (text.isEmpty) return;

                  final currentNotes = _parseNotes(person.generalNotes);
                  if (isEditing) {
                    final idx = currentNotes.indexWhere(
                      (n) => n['id'] == noteToEdit['id'],
                    );
                    if (idx != -1) {
                      currentNotes[idx] = {
                        ...currentNotes[idx],
                        'text': text,
                        'updatedAt': DateTime.now().toIso8601String(),
                      };
                    }
                  } else {
                    currentNotes.insert(0, {
                      'id': const Uuid().v4(),
                      'text': text,
                      'createdAt': DateTime.now().toIso8601String(),
                    });
                  }

                  await _saveNotes(repo, person, currentNotes);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isEditing ? 'Anotação atualizada!' : 'Necessidade/observação registrada com data e hora!',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Dialog para adicionar ou editar Alvo ou Tarefa
  void _showAddOrEditTargetDialog(
    BuildContext context,
    AppRepository repo,
    PersonEntry person, [
    Map<String, dynamic>? targetToEdit,
  ]) {
    final isEditing = targetToEdit != null;

    showDialog(
      context: context,
      builder: (ctx) => ManagedTextControllers(
        initialTexts: [targetToEdit?['title'] ?? ''],
        customFactories: [
          (text) => RichFormattedEditingController.fromMarkup(text),
        ],
        builder: (ctx, ctrls) {
          final titleController = ctrls[0];

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.track_changes, color: Color(0xFF7C3AED)),
                const SizedBox(width: 8),
                Text(
                  isEditing
                      ? 'Editar Alvo / Tarefa'
                      : 'Novo Alvo ou Tarefa Espiritual',
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Defina um alvo espiritual ou tarefa deixada para ${person.name} até a próxima visita.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  RichMarkdownToolbar(
                    controller: titleController,
                    enableHighlightPalette: false,
                    enableImagePicker: false,
                    enableCrossReferences: true,
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Descrição do alvo ou tarefa *',
                      hintText: 'Ex: Ler o Salmo 37, baixar o JW Library, ver vídeo da Lição 01...',
                    ),
                    maxLines: 3,
                    autofocus: true,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 14,
                        color: AppTheme.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isEditing
                            ? 'Criado em: ${AppDateUtils.formatDateTimeWithAt(DateTime.tryParse(targetToEdit['createdAt'] ?? ''))}'
                            : 'Data e hora da criação gravadas automaticamente.',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
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
                  final title = RichFormattedEditingController.readMarkup(
                    titleController,
                  ).trim();
                  if (title.isEmpty) return;

                  final currentTargets = _parseTargets(
                    person.contactRestrictions,
                  );
                  if (isEditing) {
                    final idx = currentTargets.indexWhere(
                      (t) => t['id'] == targetToEdit['id'],
                    );
                    if (idx != -1) {
                      currentTargets[idx] = {
                        ...currentTargets[idx],
                        'title': title,
                      };
                    }
                  } else {
                    currentTargets.insert(0, {
                      'id': const Uuid().v4(),
                      'title': title,
                      'isCompleted': false,
                      'createdAt': DateTime.now().toIso8601String(),
                      'completedAt': null,
                    });
                  }

                  await _saveTargets(repo, person, currentTargets);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isEditing
                              ? 'Alvo atualizado!'
                              : 'Novo alvo cadastrado com sucesso!',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Salvar Alvo'),
              ),
            ],
          );
        },
      ),
    );
  }
}
