part of '../contacts_map_screen.dart';

extension _ContactsMapTerritoryModals on _ContactsMapScreenState {
  // Modal para criar novo Ponto de Referência / Marco / Marcação no território estilo Organic Maps
  void _showAddLandmarkModal(
    BuildContext context, {
    double? initialLat,
    double? initialLng,
  }) {
    final initAddr = initialLat != null && initialLng != null
        ? 'Marcação: ${initialLat.toStringAsFixed(5)}, ${initialLng.toStringAsFixed(5)}'
        : '';
    final initLat = initialLat != null ? initialLat.toStringAsFixed(6) : '';
    final initLng = initialLng != null ? initialLng.toStringAsFixed(6) : '';
    String selectedCategory = initialLat != null ? 'outro' : 'padaria';

    showDialog(
      context: context,
      builder: (ctx) => ManagedTextControllers(
        initialTexts: ['', initAddr, '', initLat, initLng],
        builder: (ctx, ctrls) {
          final nameController = ctrls[0];
          final addressController = ctrls[1];
          final notesController = ctrls[2];
          final latController = ctrls[3];
          final lngController = ctrls[4];

          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final dialogIsDark = Theme.of(ctx).brightness == Brightness.dark;
              return AlertDialog(
                title: Row(
                  children: [
                    const Icon(
                      Icons.add_location_alt,
                      color: AppTheme.accentTeal,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      initialLat != null
                          ? 'Nova Marcação no Mapa'
                          : 'Novo Ponto de Referência',
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Crie marcos úteis para localizar endereços com facilidade ou orientar outros publicadores.',
                        style: TextStyle(
                          fontSize: 12,
                          color: dialogIsDark
                              ? const Color(0xFFCBD5E1)
                              : AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nome do Ponto de Referência *',
                          hintText: 'Ex: Padaria do Porto, Escola Municipal...',
                        ),
                        autofocus: true,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Categoria / Tipo de Marco',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'padaria',
                            child: Text('🥖 Padaria / Comércio'),
                          ),
                          DropdownMenuItem(
                            value: 'escola',
                            child: Text('🏫 Escola / Colégio'),
                          ),
                          DropdownMenuItem(
                            value: 'saude',
                            child: Text('🏥 Posto de Saúde / Hospital'),
                          ),
                          DropdownMenuItem(
                            value: 'transporte',
                            child: Text('🚌 Ponto de Ônibus / Terminal'),
                          ),
                          DropdownMenuItem(
                            value: 'mercado',
                            child: Text('🛒 Supermercado'),
                          ),
                          DropdownMenuItem(
                            value: 'praca',
                            child: Text('🌳 Praça / Parque'),
                          ),
                          DropdownMenuItem(
                            value: 'religioso',
                            child: Text('⛪ Salão do Reino / Igreja'),
                          ),
                          DropdownMenuItem(
                            value: 'combustivel',
                            child: Text('⛽ Posto de Combustível'),
                          ),
                          DropdownMenuItem(
                            value: 'outro',
                            child: Text('📍 Outro Marco'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedCategory = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: addressController,
                        decoration: const InputDecoration(
                          labelText: 'Endereço ou Localização',
                          hintText: 'Ex: Av. Beira Rio com Travessa 2 - Centro',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: latController,
                              decoration: const InputDecoration(
                                labelText: 'Latitude GPS (opcional)',
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
                              controller: lngController,
                              decoration: const InputDecoration(
                                labelText: 'Longitude GPS (opcional)',
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
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.my_location, size: 16),
                            label: const Text(
                              'Capturar GPS Atual',
                              style: TextStyle(fontSize: 12),
                            ),
                            onPressed: () async {
                              final pos =
                                  await GeolocationHelper.getCurrentLocation();
                              if (pos != null) {
                                setDialogState(() {
                                  latController.text = pos.latitude
                                      .toStringAsFixed(6);
                                  lngController.text = pos.longitude
                                      .toStringAsFixed(6);
                                });
                                final geo =
                                    await GeocodingService.reverseGeocode(
                                      pos.latitude,
                                      pos.longitude,
                                      db: ref.read(databaseProvider),
                                    );
                                if (geo != null &&
                                    addressController.text.trim().isEmpty) {
                                  setDialogState(() {
                                    addressController.text =
                                        geo.formattedSummary;
                                  });
                                }
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Não foi possível obter sinal GPS. Toque em "🗺️ Escolher no Mapa" para posicionar.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.accentTeal,
                              side: const BorderSide(
                                color: AppTheme.accentTeal,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                            ),
                            icon: const Icon(Icons.map, size: 16),
                            label: const Text(
                              '🗺️ Escolher no Mapa',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () async {
                              final initialLat = double.tryParse(
                                latController.text.trim(),
                              );
                              final initialLng = double.tryParse(
                                lngController.text.trim(),
                              );
                              final res =
                                  await showDialog<ReverseGeocodingResult>(
                                    context: context,
                                    builder: (_) => MapLocationPickerDialog(
                                      initialLat: initialLat,
                                      initialLng: initialLng,
                                      initialAddress: addressController.text
                                          .trim(),
                                    ),
                                  );
                              if (res != null) {
                                setDialogState(() {
                                  latController.text = res.latitude
                                      .toStringAsFixed(6);
                                  lngController.text = res.longitude
                                      .toStringAsFixed(6);
                                  if (addressController.text.trim().isEmpty &&
                                      res.streetAndNumber.isNotEmpty) {
                                    addressController.text =
                                        res.formattedSummary;
                                  }
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: notesController,
                        decoration: const InputDecoration(
                          labelText: 'Observações / Instruções para encontrar',
                          hintText: 'Ex: Ponto de encontro da saída de campo no sábado às 9:00',
                        ),
                        maxLines: 2,
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
                      final name = nameController.text.trim();
                      if (name.isEmpty) return;

                      final mgr = ref.read(landmarkManagerProvider);
                      final lat = double.tryParse(latController.text.trim());
                      final lng = double.tryParse(lngController.text.trim());

                      await mgr.addLandmark(
                        name: name,
                        category: selectedCategory,
                        address: addressController.text.trim().isEmpty
                            ? null
                            : addressController.text.trim(),
                        latitude: lat,
                        longitude: lng,
                        notes: notesController.text.trim().isEmpty
                            ? null
                            : notesController.text.trim(),
                      );

                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Ponto de referência cadastrado no mapa!',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Salvar Marco'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _shareLandmark(TerritoryLandmark landmark) async {
    final text =
        '📍 Ponto de Referência no Território: ${landmark.name}\n'
        'Categoria: ${landmark.categoryLabel}\n'
        '${landmark.address != null ? "Endereço: ${landmark.address}\n" : ""}'
        '${landmark.notes != null ? "Observações: ${landmark.notes}\n" : ""}'
        '${landmark.latitude != null && landmark.longitude != null ? "Coordenadas: ${landmark.latitude},${landmark.longitude}" : ""}';

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Informações do ponto de referência copiadas para compartilhar!',
        ),
      ),
    );
  }

  void _showCoverageAnalysisModal(
    BuildContext context,
    List<PersonEntry> people,
  ) {
    final visits = ref.read(visitsStreamProvider).value ?? [];
    final report = TerritoryCoverageEngine.calculateCoverage(
      people: people,
      visits: visits,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(
                    Icons.analytics_outlined,
                    color: AppTheme.primaryBlue,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Índice de Cobertura & Zonas Esquecidas',
                      style: TextStyle(
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
              const SizedBox(height: 12),
              // Card do IC
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      report.ratingColor.withValues(alpha: isDark ? 0.3 : 0.12),
                      report.ratingColor.withValues(
                        alpha: isDark ? 0.15 : 0.05,
                      ),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: report.ratingColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: CircularProgressIndicator(
                            value: report.coverageIndexPercent / 100.0,
                            strokeWidth: 6,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              report.ratingColor,
                            ),
                          ),
                        ),
                        Text(
                          '${report.coverageIndexPercent.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: report.ratingColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.ratingLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: report.ratingColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${report.workedRecentlyCount + report.workedStandardCount} de ${report.totalAddresses} endereços trabalhados nos últimos 90 dias.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Três Métricas Independentes (Residências, Contatos, Conversas Efetivas)
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488)
                            .withValues(alpha: isDark ? 0.2 : 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.home_work_outlined,
                                size: 14,
                                color: Color(0xFF0D9488),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Residências',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${report.addressCoveragePercent.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF0D9488),
                            ),
                          ),
                          Text(
                            '${report.workedUniqueAddresses}/${report.totalUniqueAddresses}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(
                          alpha: isDark ? 0.2 : 0.08,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 14,
                                color: AppTheme.primaryBlue,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Contatos',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${report.peopleCoveragePercent.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                          Text(
                            '${report.visitedPeopleCount}/${report.totalPeople}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A)
                            .withValues(alpha: isDark ? 0.2 : 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.forum_outlined,
                                size: 14,
                                color: Color(0xFF16A34A),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Conversas',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${report.conversationCoveragePercent.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                          Text(
                            '${report.peopleWithEffectiveConversation}/${report.totalPeople}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Zonas Esquecidas (>90 dias sem visita): ${report.forgottenAddresses.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: report.forgottenAddresses.isEmpty
                    ? const Center(
                        child: Text(
                          'Parabéns! Nenhum endereço esquecido no território.',
                          style: TextStyle(color: AppTheme.successGreen),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: report.forgottenAddresses.length,
                        itemBuilder: (context, i) {
                          final p = report.forgottenAddresses[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(
                                Icons.warning_amber_rounded,
                                color: Color(0xFFDC2626),
                              ),
                              title: Text(
                                p.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                p.address ?? 'Sem endereço cadastrado',
                              ),
                              trailing: TextButton(
                                child: const Text('Localizar'),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _updateState(() {
                                    _highlightPersonId = p.id;
                                    _viewMode = 'Mapa Interativo';
                                    _hasCenteredHighlightPerson = false;
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDuplicateAnalysisModal(
    BuildContext context,
    List<PersonEntry> people,
  ) {
    final duplicates = TerritoryCoverageEngine.findDuplicates(people);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(
                    Icons.compare_arrows,
                    color: Color(0xFFD97706),
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Detecção de Duplicidades no Território',
                      style: TextStyle(
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
              Text(
                'Identifica endereços com distância < 25m e nomes/endereços foneticamente similares.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: duplicates.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhuma duplicidade detectada no território!',
                          style: TextStyle(
                            color: AppTheme.successGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: duplicates.length,
                        itemBuilder: (context, i) {
                          final match = duplicates[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: match.isHighConfidence
                                    ? Colors.red.shade300
                                    : Colors.amber.shade300,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: match.isHighConfidence
                                              ? Colors.red.withValues(
                                                  alpha: 0.15,
                                                )
                                              : Colors.amber.withValues(
                                                  alpha: 0.15,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          match.isHighConfidence
                                              ? 'Alta Certeza (<25m)'
                                              : 'Possível Duplicata',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: match.isHighConfidence
                                                ? Colors.red
                                                : Colors.amber.shade900,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        'Distância: ${match.distanceMeters.toStringAsFixed(0)}m',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '1: ${match.personA.name} (${match.personA.address ?? "Sem endereço"})',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '2: ${match.personB.name} (${match.personB.address ?? "Sem endereço"})',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _exportKml(BuildContext context, List<PersonEntry> people) {
    final kml = TerritoryDataPortService.exportToKml(people: people);
    Clipboard.setData(ClipboardData(text: kml));
    FileDownloader.download(
      'territorio_${DateTime.now().millisecondsSinceEpoch}.kml',
      kml,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Território exportado em KML! Copiado para área de transferência.',
        ),
        backgroundColor: AppTheme.successGreen,
      ),
    );
  }

  void _exportGeoJson(BuildContext context, List<PersonEntry> people) {
    final geojson = TerritoryDataPortService.exportToGeoJson(people: people);
    Clipboard.setData(ClipboardData(text: geojson));
    FileDownloader.download(
      'territorio_${DateTime.now().millisecondsSinceEpoch}.geojson',
      geojson,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Território exportado em GeoJSON! Copiado para área de transferência.',
        ),
        backgroundColor: AppTheme.successGreen,
      ),
    );
  }

  void _exportCsv(BuildContext context, List<PersonEntry> people) {
    final csv = TerritoryDataPortService.exportToCsv(people);
    Clipboard.setData(ClipboardData(text: csv));
    FileDownloader.download(
      'enderecos_territorio_${DateTime.now().millisecondsSinceEpoch}.csv',
      csv,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Endereços exportados em CSV! Copiado para área de transferência.',
        ),
        backgroundColor: AppTheme.successGreen,
      ),
    );
  }

  void _showImportTerritoryDialog(BuildContext context) {
    String detectedFormat = 'Auto-detectar';
    List<ImportedTerritoryContact> previewContacts = [];
    bool isImporting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => ManagedTextControllers(
        initialTexts: const [''],
        builder: (dialogCtx, ctrls) {
          final textController = ctrls[0];

          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final isDark = Theme.of(ctx).brightness == Brightness.dark;

              void analyzeInput() {
                final raw = textController.text.trim();
                if (raw.isEmpty) {
                  setDialogState(() => previewContacts = []);
                  return;
                }

                List<ImportedTerritoryContact> parsed = [];
                final format = detectedFormat.toLowerCase();
                if (format.contains('kml') ||
                    raw.contains('<kml') ||
                    raw.contains('<Placemark')) {
                  parsed = TerritoryDataPortService.importFromKml(raw);
                } else if (format.contains('geojson') ||
                    raw.startsWith('{') ||
                    raw.contains('"FeatureCollection"')) {
                  parsed = TerritoryDataPortService.importFromGeoJson(raw);
                } else {
                  parsed = TerritoryDataPortService.importFromCsv(raw);
                }

                setDialogState(() {
                  previewContacts = parsed;
                });
              }

              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Row(
                  children: [
                    Icon(Icons.file_upload_outlined, color: Color(0xFF0D9488)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Importar Território',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cole o conteúdo de um arquivo KML (Google Earth), GeoJSON (RFC 7946) ou CSV (planilha) para importar contatos e endereços diretamente.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFFCBD5E1)
                                : AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: detectedFormat,
                          decoration: const InputDecoration(
                            labelText: 'Formato do Arquivo',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Auto-detectar',
                              child: Text('Auto-detectar'),
                            ),
                            DropdownMenuItem(
                              value: 'KML (Google Earth)',
                              child: Text('KML (Google Earth)'),
                            ),
                            DropdownMenuItem(
                              value: 'GeoJSON',
                              child: Text('GeoJSON'),
                            ),
                            DropdownMenuItem(
                              value: 'CSV (Planilha)',
                              child: Text('CSV (Planilha)'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => detectedFormat = val);
                              analyzeInput();
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: textController,
                          decoration: InputDecoration(
                            labelText: 'Conteúdo do Arquivo',
                            hintText:
                                'Cole o texto KML, GeoJSON ou CSV aqui...',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.paste_rounded),
                              tooltip: 'Colar da área de transferência',
                              onPressed: () async {
                                final data = await Clipboard.getData(
                                  Clipboard.kTextPlain,
                                );
                                if (data?.text != null) {
                                  textController.text = data!.text!;
                                  analyzeInput();
                                }
                              },
                            ),
                          ),
                          maxLines: 5,
                          onChanged: (_) => analyzeInput(),
                        ),
                        const SizedBox(height: 12),
                        if (previewContacts.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF16A34A)
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF16A34A),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${previewContacts.length} contato(s) identificado(s) prontos para importação.',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Color(0xFF16A34A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (textController.text.trim().isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.amber,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Nenhum contato detectado no texto colado. Verifique o formato selecionado.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.amber,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isImporting
                        ? null
                        : () => Navigator.pop(dialogCtx),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                    ),
                    icon: isImporting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download_done_rounded, size: 16),
                    label: Text(
                      isImporting ? 'Importando...' : 'Confirmar Importação',
                    ),
                    onPressed: (isImporting || previewContacts.isEmpty)
                        ? null
                        : () async {
                            setDialogState(() => isImporting = true);
                            try {
                              final repo = ref.read(repositoryProvider);
                              for (final contact in previewContacts) {
                                await repo.createPerson(
                                  name: contact.name,
                                  phone: contact.phone,
                                  address: contact.address,
                                  status: contact.status,
                                  latitude: contact.latitude,
                                  longitude: contact.longitude,
                                  generalNotes: contact.notes,
                                );
                              }
                              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${previewContacts.length} contatos importados para o território com sucesso!',
                                    ),
                                    backgroundColor: AppTheme.successGreen,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (dialogCtx.mounted) {
                                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Erro ao importar contatos: $e',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } finally {
                              if (dialogCtx.mounted) {
                                setDialogState(() => isImporting = false);
                              }
                            }
                          },
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
