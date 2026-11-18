part of '../person_detail_screen.dart';

extension _PersonDetailVisitsTab on _PersonDetailScreenState {
  Widget _buildVisitsAndContactTab(
    BuildContext context,
    AppRepository repo,
    PersonEntry person,
    BibleStudyEntry? linkedStudy,
    bool isDark,
    bool isStudiesEnabled,
    bool isAgendaEnabled,
  ) {
    final isSunMode = ref.watch(sunModeProvider);
    final allPhotos = ref.watch(personPhotosStreamProvider).value ?? [];
    final personPhoto = allPhotos
        .where((p) => p.personId == person.id && p.photoType == 'person')
        .firstOrNull;
    final housePhoto = allPhotos
        .where((p) => p.personId == person.id && p.photoType == 'house')
        .firstOrNull;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner de aviso se for revisita passada para outro publicador
          if (person.status == 'revisita_passada') ...[
            Card(
              color: const Color(0xFFFEF3C7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(
                      Icons.outbox,
                      color: Color(0xFFB45309),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Revisita Repassada para Outro Publicador',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF92400E),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Esta revisita está oculta da agenda e estatísticas ativas. Se você voltou a atendê-la, pode reativá-la com 1 toque.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF78350F),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB45309),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => PersonHandOffHelper.reactivatePerson(
                        context: context,
                        ref: ref,
                        person: person,
                      ),
                      child: const Text('Reativar'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Banner de aviso se for revisita encerrada
          if (person.status == 'revisita_encerrada') ...[
            Card(
              color: const Color(0xFFFEF3C7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_off_outlined,
                      color: Color(0xFFB45309),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Revisita Encerrada (com motivo)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF92400E),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            person.nextActionNote ?? 'Esta revisita foi encerrada, mas todo o histórico está preservado.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF78350F),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB45309),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () =>
                          _reactivateReturnVisit(context, repo, person),
                      child: const Text('Reativar'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Card de Identificação e Contato
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: () async {
                          if (personPhoto != null &&
                              personPhoto.imageData.isNotEmpty) {
                            showModalBottomSheet(
                              context: context,
                              builder: (bCtx) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(
                                        Icons.fullscreen,
                                        color: AppTheme.primaryBlue,
                                      ),
                                      title: const Text(
                                        'Ver Foto em Tela Cheia',
                                      ),
                                      onTap: () {
                                        Navigator.pop(bCtx);
                                        MediaPickerHelper.showFullScreenImage(
                                          context,
                                          imageSource: personPhoto.imageData,
                                          title: 'Foto: ${person.name}',
                                          onDelete: () async {
                                            await ref
                                                .read(
                                                  personPhotosManagerProvider,
                                                )
                                                .deletePhoto(
                                                  person.id,
                                                  'person',
                                                );
                                          },
                                        );
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.add_a_photo,
                                        color: AppTheme.accentTeal,
                                      ),
                                      title: const Text('Trocar Foto'),
                                      onTap: () async {
                                        Navigator.pop(bCtx);
                                        final img =
                                            await MediaPickerHelper.pickImageOrCapture(
                                              context,
                                            );
                                        if (img != null) {
                                          await ref
                                              .read(personPhotosManagerProvider)
                                              .savePersonPhoto(person.id, img);
                                        }
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                      ),
                                      title: const Text(
                                        'Remover Foto',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                      onTap: () async {
                                        Navigator.pop(bCtx);
                                        await ref
                                            .read(personPhotosManagerProvider)
                                            .deletePhoto(person.id, 'person');
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          } else {
                            final img =
                                await MediaPickerHelper.pickImageOrCapture(
                                  context,
                                );
                            if (img != null) {
                              await ref
                                  .read(personPhotosManagerProvider)
                                  .savePersonPhoto(person.id, img);
                            }
                          }
                        },
                        borderRadius: BorderRadius.circular(30),
                        child: Stack(
                          children: [
                            if (personPhoto != null &&
                                personPhoto.imageData.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(30),
                                child: MediaPickerHelper.buildThumbnail(
                                  personPhoto.imageData,
                                  width: 60,
                                  height: 60,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              )
                            else
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: AppTheme.primaryBlue
                                    .withValues(alpha: 0.1),
                                child: Text(
                                  person.name.isNotEmpty
                                      ? person.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                              ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppTheme.primaryBlue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              person.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                Chip(
                                  label: Text(
                                    person.status.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  backgroundColor: person.status == 'estudo'
                                      ? const Color(0xFF7C3AED)
                                            .withValues(alpha: 0.15)
                                      : person.status == 'revisita_passada'
                                      ? const Color(0xFFFEF3C7)
                                      : AppTheme.primaryBlue.withValues(
                                          alpha: 0.1,
                                        ),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Primeiro: ${AppDateUtils.formatDate(person.firstContactAt)}',
                                  style: const TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Tags da Pessoa com botão de gerenciar
                            Builder(
                              builder: (context) {
                                List<String> personTags = [];
                                if (person.tags.isNotEmpty &&
                                    person.tags != '[]') {
                                  if (person.tags.startsWith('[')) {
                                    try {
                                      final decoded =
                                          jsonDecode(person.tags) as List;
                                      personTags = decoded
                                          .map((e) => e.toString().trim())
                                          .where((s) => s.isNotEmpty)
                                          .toList();
                                    } catch (e, st) {
                                      AppLogger.debug(
                                        'Falha ao ler tags JSON no cabeçalho (${person.id}): $e',
                                        st,
                                      );
                                    }
                                  } else {
                                    personTags = person.tags
                                        .split(',')
                                        .map((e) => e.trim())
                                        .where((s) => s.isNotEmpty)
                                        .toList();
                                  }
                                }

                                return Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    ...personTags.map(
                                      (t) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white10
                                              : Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          '#$t',
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      ),
                                    ),
                                    Semantics(
                                      button: true,
                                      label: 'Editar etiquetas',
                                      child: InkWell(
                                        onTap: () => _showEditPersonTagsDialog(
                                          context,
                                          repo,
                                          person,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            minWidth: 48,
                                            minHeight: 48,
                                          ),
                                          child: Center(
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryBlue
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.label_outline,
                                                    size: 12,
                                                    color: AppTheme.primaryBlue,
                                                  ),
                                                  SizedBox(width: 3),
                                                  Text(
                                                    'Tags',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          AppTheme.primaryBlue,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  if (person.phone != null && person.phone!.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.phone,
                          size: 18,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            person.phone!,
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.call,
                            size: 20,
                            color: AppTheme.primaryBlue,
                          ),
                          tooltip: 'Ligar',
                          visualDensity: VisualDensity.compact,
                          onPressed: () async {
                            final uri = Uri.parse('tel:${person.phone}');
                            final jwAppUri = Uri.tryParse(
                              'jwlibrary:///finder?${uri.query}',
                            );
                            if (jwAppUri != null &&
                                await canLaunchUrl(jwAppUri)) {
                              await launchUrl(
                                jwAppUri,
                                mode: LaunchMode.externalApplication,
                              );
                            } else if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.chat,
                            size: 20,
                            color: Color(0xFF25D366),
                          ),
                          tooltip: 'WhatsApp',
                          visualDensity: VisualDensity.compact,
                          onPressed: () async {
                            final cleanPhone = person.phone!.replaceAll(
                              RegExp(r'\D'),
                              '',
                            );
                            final uri = Uri.parse('https://wa.me/$cleanPhone');
                            final jwAppUri = Uri.tryParse(
                              'jwlibrary:///finder?${uri.query}',
                            );
                            if (jwAppUri != null &&
                                await canLaunchUrl(jwAppUri)) {
                              await launchUrl(
                                jwAppUri,
                                mode: LaunchMode.externalApplication,
                              );
                            } else if (await canLaunchUrl(uri)) {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 18,
                        color: AppTheme.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          person.address != null && person.address!.isNotEmpty
                              ? person.address!
                              : (person.latitude != null &&
                                        person.longitude != null
                                    ? 'GPS: ${person.latitude!.toStringAsFixed(4)}, ${person.longitude!.toStringAsFixed(4)}'
                                    : 'Endereço não cadastrado (toque no mapa para definir)'),
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                (person.address == null ||
                                    person.address!.isEmpty)
                                ? AppTheme.textMuted
                                : null,
                            fontStyle:
                                (person.address == null ||
                                    person.address!.isEmpty)
                                ? FontStyle.italic
                                : null,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.map,
                          size: 20,
                          color: AppTheme.primaryBlue,
                        ),
                        tooltip: 'Ver no Mapa do Território',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ContactsMapScreen(
                                highlightPersonId: person.id,
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.edit_location_alt,
                          size: 20,
                          color: AppTheme.accentTeal,
                        ),
                        tooltip: 'Ajustar Localização / Escolher no Mapa',
                        visualDensity: VisualDensity.compact,
                        onPressed: () =>
                            _openLocationPickerForPerson(context, repo, person),
                      ),
                      if ((person.address != null &&
                              person.address!.isNotEmpty) ||
                          (person.latitude != null && person.longitude != null))
                        IconButton(
                          icon: const Icon(
                            Icons.open_in_new,
                            size: 20,
                            color: Colors.blueGrey,
                          ),
                          tooltip: 'Abrir no Google Maps',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _openExternalGoogleMaps(person),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Foto da Fachada / Residência
                  Container(
                    margin: const EdgeInsets.only(top: 4, bottom: 8),
                    padding: const EdgeInsets.all(10),
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
                    child: Row(
                      children: [
                        if (housePhoto != null &&
                            housePhoto.imageData.isNotEmpty)
                          InkWell(
                            onTap: () {
                              MediaPickerHelper.showFullScreenImage(
                                context,
                                imageSource: housePhoto.imageData,
                                title: 'Fachada da Residência: ${person.name}',
                              );
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Tooltip(
                              message:
                                  'Toque para ampliar foto em alta resolução',
                              child: Stack(
                                children: [
                                  MediaPickerHelper.buildThumbnail(
                                    housePhoto.imageData,
                                    width: 72,
                                    height: 54,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  Positioned(
                                    bottom: 2,
                                    right: 2,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Icon(
                                        Icons.zoom_in,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 72,
                            height: 54,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.home,
                              color: Colors.grey,
                              size: 28,
                            ),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Foto da Residência / Fachada',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                housePhoto != null
                                    ? 'Foto cadastrada. Toque para ver em tela cheia.'
                                    : 'Facilita localizar a residência no território.',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                          icon: const Icon(Icons.add_a_photo, size: 14),
                          label: Text(
                            housePhoto != null ? 'Trocar' : 'Tirar Foto',
                            style: const TextStyle(fontSize: 11),
                          ),
                          onPressed: () async {
                            final img =
                                await MediaPickerHelper.pickImageOrCapture(
                                  context,
                                );
                            if (img != null) {
                              await ref
                                  .read(personPhotosManagerProvider)
                                  .saveHousePhoto(person.id, img);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  if (person.preferredSchedule != null &&
                      person.preferredSchedule!.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.alarm,
                          size: 18,
                          color: Color(0xFF7C3AED),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Horário habitual: ${person.preferredSchedule!}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF7C3AED),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Builder(
                    builder: (context) {
                      final notes = _parseNotes(person.generalNotes);
                      if (notes.isEmpty) return const SizedBox.shrink();
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.note_alt_outlined,
                            size: 18,
                            color: AppTheme.accentTeal,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${notes.length} ${notes.length == 1 ? "anotação/necessidade registrada" : "anotações/necessidades registradas"} (ver aba Necessidades & Obs.)',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.accentTeal,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // -------------------------------------------------------------------
          // Card de "Briefing na Porta" (Consolidação em 1 Toque - R1)
          // -------------------------------------------------------------------
          StreamBuilder<List<VisitEntry>>(
            stream: repo.watchVisitsForPerson(person.id),
            builder: (context, visitSnapshot) {
              final latestVisit = (visitSnapshot.data ?? []).firstOrNull;
              return StreamBuilder<List<VoiceNoteItem>>(
                stream: ref
                    .watch(voiceNotesManagerProvider)
                    .watchVoiceNotesForPerson(person.id),
                builder: (context, voiceSnapshot) {
                  final latestVoiceNote =
                      (voiceSnapshot.data ?? []).firstOrNull;
                  final briefingData = DoorstepBriefingHelper.build(
                    person: person,
                    linkedStudy: linkedStudy,
                    latestVisit: latestVisit,
                    latestVoiceNote: latestVoiceNote,
                  );
                  return DoorstepBriefingCard(
                    data: briefingData,
                    onOpenJwLibrary: linkedStudy != null
                        ? () => _openPublicationLink(context, linkedStudy)
                        : null,
                    onQuickRecord: () => QuickVoiceNoteDialog.show(
                      context: context,
                      person: person,
                      linkedStudy: linkedStudy,
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 12),

          // Botão Rápido de Áudio / Ditado (15s) - Nível 3
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: 48,
            ), // Alvo de toque mínimo >= 48dp
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSunMode
                      ? Colors.black
                      : const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  elevation: isSunMode ? 0 : 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: isSunMode
                        ? const BorderSide(color: Colors.black, width: 2)
                        : BorderSide.none,
                  ),
                ),
                icon: const Icon(Icons.mic, size: 20),
                label: const Text(
                  'Registro Rápido por Áudio / Ditado (15s)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: () => QuickVoiceNoteDialog.show(
                  context: context,
                  person: person,
                  linkedStudy: linkedStudy,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Alerta e Botão Proeminente se pessoa tem status 'estudo' sem estudo iniciado
          if (person.status == 'estudo' && linkedStudy == null) ...[
            Card(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.school, color: Color(0xFF7C3AED)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Contato classificado como Estudo Bíblico',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF7C3AED),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${person.name} ainda não possui um livro ou brochura vinculado para registro de lições.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? const Color(0xFFCBD5E1)
                            : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.add_circle_outline),
                        label: Text(
                          '+ Iniciar Estudo Bíblico com ${person.name}',
                        ),
                        onPressed: () => _showStartStudyDialog(context, person),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Botões de Ação Imediata de Campo
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.rate_review_outlined),
                  label: const Text('Registrar Conversa'),
                  onPressed: () =>
                      _showQuickVisitDialog(context, person, linkedStudy),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.edit_calendar),
                  label: const Text('Agendar Retorno'),
                  onPressed: () => _showScheduleDialog(context, person),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.near_me_outlined),
              label: const Text(
                'Agendar Retorno na Porta (Proximidade)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () =>
                  DoorstepReturnBookingDialog.show(context, person),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFD97706),
                side: const BorderSide(color: Color(0xFFD97706)),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text(
                'Passar Revisita para Outro Publicador (WhatsApp / GPS)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: () => PersonHandOffHelper.showHandOffDialog(
                context: context,
                ref: ref,
                person: person,
                linkedStudy: linkedStudy,
              ),
            ),
          ),
          if (person.status == 'revisita' ||
              person.status == 'interessado') ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.alertAmber,
                  side: const BorderSide(color: AppTheme.alertAmber),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                icon: const Icon(Icons.person_off_outlined, size: 18),
                label: const Text(
                  'Encerrar Revisita (com motivo)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () =>
                    _showEndReturnVisitDialog(context, person, repo),
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Ideia 3: Alerta de Proximidade Expandido (Contatos e Reativações Vizinhas)
          _buildProximityAlertsSection(context, person, ref, isDark),
          const SizedBox(height: 20),

          // Linha do Tempo Unificada do Contato (Visitas, Estudos, Telefones, Agenda e Áudios)
          const Text(
            'Linha do Tempo Unificada do Contato',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),

          PersonUnifiedTimelineSection(
            person: person,
            linkedStudy: linkedStudy,
            isStudiesEnabled: isStudiesEnabled,
            isAgendaEnabled: isAgendaEnabled,
          ),
        ],
      ),
    );
  }
}
