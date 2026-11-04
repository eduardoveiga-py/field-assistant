import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:drift/drift.dart' show Value;

import '../../appointments/availability_engine.dart';
import '../../contacts/doorstep_briefing_helper.dart';
import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../database/app_database.dart';
import '../../database/repository.dart';
import '../../media/media_picker_helper.dart';
import '../../media/person_photos_manager.dart';
import '../../territory/geocoding_service.dart';
import '../../territory/geolocation_helper.dart';
import '../../voice_notes/voice_note_models.dart';
import '../../voice_notes/voice_notes_manager.dart';
import '../providers.dart';
import '../screens/contacts_map_screen.dart';
import '../screens/person_detail_screen.dart';
import 'doorstep_briefing_card.dart';
import 'end_return_visit_dialog.dart';
import 'global_appointment_scheduling_section.dart';
import 'map_location_picker_dialog.dart';
import 'person_hand_off_dialog.dart';
import 'person_unified_timeline_section.dart';
import 'publication_link_dialog.dart';
import 'quick_visit_dialog.dart';
import 'quick_voice_note_dialog.dart';
import 'study_form_dialog.dart';

/// Aba 1: Visitas & Contato e Linha do Tempo Unificada
class PersonVisitsTab extends ConsumerWidget {
  final PersonEntry person;
  final BibleStudyEntry? linkedStudy;
  final bool isDark;
  final bool isStudiesEnabled;
  final bool isAgendaEnabled;

  const PersonVisitsTab({
    super.key,
    required this.person,
    this.linkedStudy,
    required this.isDark,
    required this.isStudiesEnabled,
    required this.isAgendaEnabled,
  });

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

  void _showEditPersonTagsDialog(
    BuildContext context,
    AppRepository repo,
    PersonEntry person,
  ) {
    List<String> tags = [];
    if (person.tags.isNotEmpty && person.tags != '[]') {
      if (person.tags.startsWith('[')) {
        try {
          final decoded = jsonDecode(person.tags) as List;
          tags = decoded.map((e) => e.toString().trim()).toList();
        } catch (_) {}
      } else {
        tags = person.tags.split(',').map((e) => e.trim()).toList();
      }
    }

    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.label_outline, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              Expanded(child: Text('Etiquetas: ${person.name}')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: textController,
                        decoration: const InputDecoration(
                          hintText: 'Nova tag (ex: idoso, surdo)',
                          isDense: true,
                        ),
                        onSubmitted: (val) {
                          final v = val.trim();
                          if (v.isNotEmpty && !tags.contains(v)) {
                            setDialogState(() => tags.add(v));
                            textController.clear();
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, color: AppTheme.primaryBlue),
                      onPressed: () {
                        final v = textController.text.trim();
                        if (v.isNotEmpty && !tags.contains(v)) {
                          setDialogState(() => tags.add(v));
                          textController.clear();
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tags.map((t) {
                    return Chip(
                      label: Text('#$t'),
                      onDeleted: () {
                        setDialogState(() => tags.remove(t));
                      },
                    );
                  }).toList(),
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
                  person.copyWith(tags: jsonEncode(tags)),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showScheduleDialog(
    BuildContext context,
    WidgetRef ref,
    PersonEntry person,
  ) {
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

  Widget _buildProximityAlertsSection(
    BuildContext context,
    PersonEntry person,
    WidgetRef ref,
    bool isDark,
  ) {
    if (person.latitude == null || person.longitude == null) {
      return const SizedBox.shrink();
    }

    final allPeople = ref.watch(peopleStreamProvider).value ?? [];
    final nearby = <({PersonEntry contact, double distanceKm, bool isEnded})>[];

    for (final other in allPeople) {
      if (other.id == person.id || other.deletedAt != null) continue;
      if (other.latitude == null || other.longitude == null) continue;

      final distKm = GeolocationHelper.calculateHaversineDistanceKm(
        person.latitude!,
        person.longitude!,
        other.latitude!,
        other.longitude!,
      );

      if (distKm <= 1.2) {
        final isEnded =
            other.status == 'revisita_encerrada' || other.status == 'encerrado';
        nearby.add((contact: other, distanceKm: distKm, isEnded: isEnded));
      }
    }

    if (nearby.isEmpty) return const SizedBox.shrink();
    nearby.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    return Card(
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0FDF4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.accentTeal.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.near_me, color: AppTheme.accentTeal, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Alerta de Proximidade: Vizinhos Próximos (< 1.2 km)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppTheme.accentTeal,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${nearby.length} contato(s)',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentTeal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Aproveite a visita a este contato para revisitar ou reativar contatos vizinhos:',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 10),
            Column(
              children: nearby.take(4).map((item) {
                final c = item.contact;
                final distMeters = (item.distanceKm * 1000).toStringAsFixed(0);
                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PersonDetailScreen(personId: c.id),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          item.isEnded
                              ? Icons.replay_outlined
                              : Icons.location_on,
                          size: 16,
                          color: item.isEnded
                              ? Colors.orange
                              : AppTheme.primaryBlue,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              if (c.address != null && c.address!.isNotEmpty)
                                Text(
                                  c.address!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (item.isEnded)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Reativar?',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ),
                        Text(
                          '~${distMeters}m',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accentTeal,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
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
                            person.nextActionNote ??
                                'Esta revisita foi encerrada, mas todo o histórico está preservado.',
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
                          EndReturnVisitDialog.reactivate(context, repo, person),
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
                                              .read(
                                                personPhotosManagerProvider,
                                              )
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
                            // Tags da Pessoa
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
                                    } catch (_) {}
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
                            if (await canLaunchUrl(uri)) {
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
                            if (await canLaunchUrl(uri)) {
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
                      final notes = DoorstepBriefingHelper.parseNotes(
                        person.generalNotes,
                      );
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

          // Card de Briefing na Porta
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
                        ? () => PublicationLinkDialog.show(context, linkedStudy!)
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

          // Botão Rápido de Áudio / Ditado (15s)
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
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
                        onPressed: () => StudyFormDialog.show(
                          context,
                          initialPersonId: person.id,
                        ),
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
                  onPressed: () => QuickVisitDialog.show(
                    context: context,
                    person: person,
                    existingStudy: linkedStudy,
                  ),
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
                  onPressed: () => _showScheduleDialog(context, ref, person),
                ),
              ),
            ],
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
                    EndReturnVisitDialog.show(context, repo, person),
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Ideia 3: Alerta de Proximidade Expandido
          _buildProximityAlertsSection(context, person, ref, isDark),
          const SizedBox(height: 20),

          // Linha do Tempo Unificada do Contato
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
