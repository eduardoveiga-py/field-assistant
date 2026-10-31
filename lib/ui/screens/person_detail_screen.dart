import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../database/app_database.dart';
import '../../database/repository.dart';
import '../../appointments/availability_engine.dart';
import '../../publications/publication_catalog.dart';
import '../../publications/publication_link_resolver.dart';
import '../../dashboard/counting_rules.dart';
import '../providers.dart';
import '../widgets/global_appointment_scheduling_section.dart';
import '../../media/person_photos_manager.dart';
import '../../media/media_picker_helper.dart';
import '../widgets/person_hand_off_dialog.dart';
import '../widgets/person_publications_tab.dart';
import '../widgets/person_family_ties_tab.dart';
import '../widgets/person_photos_tab.dart';
import '../../publications/lff_book_catalog.dart';
import '../../territory/geolocation_helper.dart';
import '../../territory/geocoding_service.dart';
import '../widgets/map_location_picker_dialog.dart';
import '../../territory/sector_manager.dart';
import 'contacts_map_screen.dart';
import '../../contacts/doorstep_briefing_helper.dart';
import '../widgets/doorstep_briefing_card.dart';

class PersonDetailScreen extends ConsumerStatefulWidget {
  final String personId;

  const PersonDetailScreen({super.key, required this.personId});

  @override
  ConsumerState<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends ConsumerState<PersonDetailScreen> {
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
                  style: const TextStyle(fontSize: 13, color: Color(0xFF1E3A8A)),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (resolved.url != null) ...[
              Text(
                'Link Oficial Verificado:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 4),
              SelectableText(
                resolved.url!,
                style: const TextStyle(fontSize: 12, color: AppTheme.accentTeal),
              ),
            ],
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copiar'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: resolved.url ?? resolved.displayText));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Referência copiada para a área de transferência!')),
              );
            },
          ),
          if (resolved.url != null)
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Abrir'),
              onPressed: () async {
                final uri = Uri.parse(resolved.url!);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else if (resolved.fallbackUrl != null) {
                  await launchUrl(Uri.parse(resolved.fallbackUrl!), mode: LaunchMode.externalApplication);
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
    final titleController = TextEditingController(text: 'Estudo de ${person.name}');
    final lessonController = TextEditingController(text: '1');
    final paragraphController = TextEditingController(text: '1');
    String selectedPublicationId = 'lff-book';
    String selectedLanguage = 'pt';
    String selectedFrequency = 'semanal';
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
      builder: (ctx) => StatefulBuilder(
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
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Título do estudo *',
                      hintText: 'Ex: Estudo da Família Lima',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedPublicationId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Publicação Principal'),
                    items: PublicationCatalog.allPublications.map((p) {
                      return DropdownMenuItem(
                        value: p.id,
                        child: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedPublicationId = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedLanguage,
                    decoration: const InputDecoration(labelText: 'Idioma do estudo'),
                    items: const [
                      DropdownMenuItem(value: 'pt', child: Text('Português')),
                      DropdownMenuItem(value: 'bzs', child: Text('Libras (Língua de Sinais)')),
                      DropdownMenuItem(value: 'tca', child: Text('Ticuna')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedLanguage = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: lessonController,
                          decoration: const InputDecoration(labelText: 'Lição Inicial'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: paragraphController,
                          decoration: const InputDecoration(labelText: 'Parágrafo Inicial'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedFrequency,
                    decoration: const InputDecoration(labelText: 'Frequência do estudo'),
                    items: const [
                      DropdownMenuItem(value: 'semanal', child: Text('Semanal (1x por semana)')),
                      DropdownMenuItem(value: 'duas_vezes_semana', child: Text('Intensivo (2x por semana)')),
                      DropdownMenuItem(value: 'quinzenal', child: Text('Quinzenal')),
                      DropdownMenuItem(value: 'variavel', child: Text('Variável / Flexível')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedFrequency = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: Color(0xFF7C3AED)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'O status de ${person.name} será automaticamente atualizado para "Estudo Bíblico" e integrado aos relatórios mensais.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF5B21B6),
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
                    onToggle: (v) => setDialogState(() => scheduleFirstStudy = v),
                    selectedDateTime: firstStudyDateTime,
                    onDateTimeChanged: (dt) => setDialogState(() => firstStudyDateTime = dt),
                    durationMinutes: firstStudyDuration,
                    onDurationChanged: (d) => setDialogState(() => firstStudyDuration = d),
                    existingAppointments: ref.read(appointmentsStreamProvider).value ?? [],
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
                    final allAppts = ref.read(appointmentsStreamProvider).value ?? [];
                    final avail = AvailabilityEngine.checkAvailability(
                      startTime: firstStudyDateTime,
                      durationMinutes: firstStudyDuration,
                      existingAppointments: allAppts,
                    );
                    final canProceed = await GlobalAppointmentSchedulingSection.confirmConflictIfNeeded(
                      context: context,
                      availability: avail,
                    );
                    if (!canProceed) return;
                  }

                  final initialLesson = int.tryParse(lessonController.text.trim()) ?? 1;
                  final initialPara = int.tryParse(paragraphController.text.trim()) ?? 1;

                  final repo = ref.read(repositoryProvider);
                  await repo.createStudy(
                    title: title,
                    publicationId: selectedPublicationId,
                    language: selectedLanguage,
                    currentLesson: initialLesson,
                    currentParagraph: initialPara,
                    frequency: selectedFrequency,
                    participantPersonIds: [person.id],
                    primaryParticipantId: person.id,
                  );

                  if (person.status != 'estudo') {
                    await repo.updatePerson(person.copyWith(status: 'estudo'));
                  }

                  if (scheduleFirstStudy) {
                    await repo.createAppointment(
                      personId: person.id,
                      title: 'Estudo Bíblico: ${person.name}',
                      startTime: firstStudyDateTime,
                      endTime: firstStudyDateTime.add(Duration(minutes: firstStudyDuration)),
                      durationMinutes: firstStudyDuration,
                      status: 'confirmado',
                      locationNotes: person.address != null ? 'Local: ${person.address}' : null,
                    );
                  }

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Estudo Bíblico iniciado com sucesso com ${person.name}!')),
                    );
                  }
                },
                child: const Text('Iniciar Estudo'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditPersonTagsDialog(BuildContext context, AppRepository repo, PersonEntry person) {
    List<String> currentTags = [];
    if (person.tags.isNotEmpty && person.tags != '[]') {
      if (person.tags.startsWith('[')) {
        try {
          final decoded = jsonDecode(person.tags) as List;
          currentTags = decoded.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
        } catch (_) {}
      } else {
        currentTags = person.tags.split(',').map((e) => e.trim()).where((s) => s.isNotEmpty).toList();
      }
    }

    final tagController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
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
                  const Text('Gerencie tags para organizar contatos por afinidade, idioma ou situação:', style: TextStyle(fontSize: 12)),
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
                        icon: const Icon(Icons.add_circle, color: AppTheme.primaryBlue),
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
                    const Text('Nenhuma tag cadastrada ainda.', style: TextStyle(color: AppTheme.textMuted, fontSize: 13))
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: currentTags.map((t) => Chip(
                        label: Text(t, style: const TextStyle(fontSize: 12)),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () {
                          setDialogState(() => currentTags.remove(t));
                        },
                      )).toList(),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  await repo.updatePerson(person.copyWith(tags: jsonEncode(currentTags)));
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Salvar Tags'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEndStudyDialog(BuildContext context, AppRepository repo, BibleStudyEntry study, PersonEntry person) {
    String selectedReason = 'Falta de interesse / tempo';
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
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
                  'Você está encerrando o estudo bíblico com ${person.name}. O contato NÃO será excluído e continuará preservado no seu histórico.',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: selectedReason,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Motivo do Encerramento *'),
                  items: const [
                    DropdownMenuItem(value: 'Falta de interesse / tempo', child: Text('Falta de interesse / tempo')),
                    DropdownMenuItem(value: 'Mudou-se de território', child: Text('Mudou-se de território')),
                    DropdownMenuItem(value: 'Oposição familiar', child: Text('Oposição familiar')),
                    DropdownMenuItem(value: 'Estudo concluído / Batizado', child: Text('Estudo concluído / Batizado')),
                    DropdownMenuItem(value: 'Problemas de saúde', child: Text('Problemas de saúde')),
                    DropdownMenuItem(value: 'Outro', child: Text('Outro motivo')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedReason = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Observação complementar (opcional)',
                    hintText: 'Ex: Portas abertas para contato futuro...',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.alertAmber, foregroundColor: Colors.black),
              onPressed: () async {
                final reasonPayload = jsonEncode({
                  'endReason': selectedReason,
                  'notes': notesController.text.trim(),
                  'endedAt': DateTime.now().toIso8601String(),
                });
                await repo.updateStudy(
                  study.copyWith(
                    status: selectedReason == 'Estudo concluído / Batizado' ? 'concluido' : 'encerrado',
                    pauseOrCloseReason: Value(reasonPayload),
                  ),
                );
                await repo.updatePerson(person.copyWith(status: 'revisita'));
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Estudo encerrado ($selectedReason). Contato mantido no território!')),
                  );
                }
              },
              child: const Text('Confirmar Encerramento'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reactivateStudy(BuildContext context, AppRepository repo, BibleStudyEntry study, PersonEntry person) async {
    await repo.updateStudy(
      study.copyWith(
        status: 'ativo',
        pauseOrCloseReason: const Value(null),
      ),
    );
    await repo.updatePerson(person.copyWith(status: 'estudo'));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Estudo bíblico com "${person.name}" reativado com sucesso!')),
      );
    }
  }

  void _showEndReturnVisitDialog(BuildContext context, PersonEntry person, AppRepository repo) {
    String selectedReason = 'Falta de interesse / tempo';
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
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
                DropdownButtonFormField<String>(
                  initialValue: selectedReason,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Motivo do Encerramento *'),
                  items: const [
                    DropdownMenuItem(value: 'Falta de interesse / tempo', child: Text('Falta de interesse / tempo')),
                    DropdownMenuItem(value: 'Mudou-se de território', child: Text('Mudou-se de território')),
                    DropdownMenuItem(value: 'Pediu para não ser visitado', child: Text('Pediu para não ser visitado')),
                    DropdownMenuItem(value: 'Oposição familiar', child: Text('Oposição familiar')),
                    DropdownMenuItem(value: 'Problemas de saúde / Falecido', child: Text('Problemas de saúde / Falecido')),
                    DropdownMenuItem(value: 'Repassada para outro publicador', child: Text('Repassada para outro publicador')),
                    DropdownMenuItem(value: 'Outro', child: Text('Outro motivo')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedReason = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Observação complementar (opcional)',
                    hintText: 'Ex: Deixou portas abertas para uma ocasião futura...',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.alertAmber, foregroundColor: Colors.black),
              onPressed: () async {
                final reasonPayload = jsonEncode({
                  'endReason': selectedReason,
                  'notes': notesController.text.trim(),
                  'endedAt': DateTime.now().toIso8601String(),
                });
                await repo.updatePerson(person.copyWith(
                  status: 'revisita_encerrada',
                  nextActionNote: Value('Revisita encerrada: $selectedReason${notesController.text.trim().isNotEmpty ? " - ${notesController.text.trim()}" : ""}'),
                  contactRestrictions: Value(person.contactRestrictions == null || person.contactRestrictions!.isEmpty
                      ? reasonPayload
                      : person.contactRestrictions),
                ));
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Revisita encerrada ($selectedReason). Registro mantido no histórico!')),
                  );
                }
              },
              child: const Text('Confirmar Encerramento'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reactivateReturnVisit(BuildContext context, AppRepository repo, PersonEntry person) async {
    await repo.updatePerson(person.copyWith(
      status: 'revisita',
      nextActionNote: const Value(null),
    ));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Revisita com "${person.name}" reativada com sucesso!')),
      );
    }
  }

  Future<void> _openLocationPickerForPerson(BuildContext context, AppRepository repo, PersonEntry person) async {
    final res = await showDialog<ReverseGeocodingResult>(
      context: context,
      builder: (_) => MapLocationPickerDialog(
        initialLat: person.latitude,
        initialLng: person.longitude,
      ),
    );
    if (res != null) {
      final updatedAddr = (person.address == null || person.address!.isEmpty) && res.streetAndNumber.isNotEmpty
          ? res.streetAndNumber
          : person.address;
      await repo.updatePerson(person.copyWith(
        latitude: Value(res.latitude),
        longitude: Value(res.longitude),
        address: Value(updatedAddr),
      ));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Localização de "${person.name}" atualizada com sucesso no mapa!')),
        );
      }
    }
  }

  Future<void> _openExternalGoogleMaps(PersonEntry person) async {
    final query = (person.latitude != null && person.longitude != null && (person.latitude != 0.0 || person.longitude != 0.0))
        ? '${person.latitude},${person.longitude}'
        : Uri.encodeComponent(person.address ?? person.name);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showEditPersonDialog(BuildContext context, AppRepository repo, PersonEntry person) {
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
      if (parts.length >= 2 && parts[1].trim().toLowerCase().startsWith('bairro ')) {
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

    final nameCtrl = TextEditingController(text: person.name);
    final phoneCtrl = TextEditingController(text: person.phone ?? '');
    final addrCtrl = TextEditingController(text: initialStreet);
    final neighborhoodCtrl = TextEditingController(text: initialNeighborhood);
    final refCtrl = TextEditingController(text: initialRef);
    final latCtrl = TextEditingController(text: person.latitude != null && person.latitude != 0.0 ? person.latitude!.toStringAsFixed(6) : '');
    final lngCtrl = TextEditingController(text: person.longitude != null && person.longitude != 0.0 ? person.longitude!.toStringAsFixed(6) : '');
    final scheduleCtrl = TextEditingController(text: person.preferredSchedule ?? '');
    String currentStatus = person.status;
    final sectors = ref.read(sectorsStreamProvider).value ?? [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return Dialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
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
                            Icon(Icons.edit, color: AppTheme.primaryBlue, size: 24),
                            SizedBox(width: 8),
                            Text('Editar Dados do Contato', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
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
                              decoration: const InputDecoration(labelText: 'Nome Completo *'),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: phoneCtrl,
                              decoration: const InputDecoration(labelText: 'Telefone / WhatsApp', hintText: '(11) 98765-4321'),
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: currentStatus,
                              decoration: const InputDecoration(labelText: 'Situação / Classificação'),
                              items: const [
                                DropdownMenuItem(value: 'interessado', child: Text('👤 Interessado')),
                                DropdownMenuItem(value: 'revisita', child: Text('🔄 Revisita Ativa')),
                                DropdownMenuItem(value: 'estudo', child: Text('📖 Estudo Bíblico')),
                                DropdownMenuItem(value: 'revisita_passada', child: Text('📦 Revisita Repassada')),
                                DropdownMenuItem(value: 'revisita_encerrada', child: Text('⛔ Revisita Encerrada')),
                              ],
                              onChanged: (val) {
                                if (val != null) setDialogState(() => currentStatus = val);
                              },
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Localização & Bairro / Setor',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryBlue),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: addrCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Endereço (Rua, Número, Bloco/Apto)',
                                hintText: 'Ex: Rua das Flores, 120, Apto 42',
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
                                      hintText: 'Ex: Betânia, Lago Grande...',
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
                                    final isChosen = neighborhoodCtrl.text.trim().toLowerCase() == sec.name.toLowerCase();
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: ActionChip(
                                        avatar: Icon(Icons.location_city, size: 14, color: isChosen ? Colors.white : AppTheme.primaryBlue),
                                        label: Text(sec.name, style: TextStyle(fontSize: 11, color: isChosen ? Colors.white : null)),
                                        backgroundColor: isChosen ? AppTheme.primaryBlue : null,
                                        onPressed: () {
                                          setDialogState(() {
                                            neighborhoodCtrl.text = sec.name;
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
                                    decoration: const InputDecoration(labelText: 'Latitude GPS', hintText: '-23.5505'),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: lngCtrl,
                                    decoration: const InputDecoration(labelText: 'Longitude GPS', hintText: '-46.6333'),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
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
                                  icon: const Icon(Icons.my_location, size: 16),
                                  label: const Text('🧭 GPS Atual', style: TextStyle(fontSize: 12)),
                                  onPressed: () async {
                                    final pos = await GeolocationHelper.getCurrentLocation();
                                    if (pos != null) {
                                      setDialogState(() {
                                        latCtrl.text = pos.latitude.toStringAsFixed(6);
                                        lngCtrl.text = pos.longitude.toStringAsFixed(6);
                                      });
                                      final geo = await GeocodingService.reverseGeocode(pos.latitude, pos.longitude);
                                      if (geo != null) {
                                        setDialogState(() {
                                          if (addrCtrl.text.trim().isEmpty && geo.streetAndNumber.isNotEmpty) {
                                            addrCtrl.text = geo.streetAndNumber;
                                          }
                                          if (neighborhoodCtrl.text.trim().isEmpty && geo.neighborhood != null) {
                                            neighborhoodCtrl.text = geo.neighborhood!;
                                          }
                                        });
                                      }
                                    }
                                  },
                                ),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.map, size: 16),
                                  label: const Text('🗺️ Escolher no Mapa', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  onPressed: () async {
                                    final curLat = double.tryParse(latCtrl.text.trim());
                                    final curLng = double.tryParse(lngCtrl.text.trim());
                                    final res = await showDialog<ReverseGeocodingResult>(
                                      context: context,
                                      builder: (_) => MapLocationPickerDialog(
                                        initialLat: curLat,
                                        initialLng: curLng,
                                      ),
                                    );
                                    if (res != null) {
                                      setDialogState(() {
                                        latCtrl.text = res.latitude.toStringAsFixed(6);
                                        lngCtrl.text = res.longitude.toStringAsFixed(6);
                                        if (res.streetAndNumber.isNotEmpty && addrCtrl.text.trim().isEmpty) {
                                          addrCtrl.text = res.streetAndNumber;
                                        }
                                        if (res.neighborhood != null && res.neighborhood!.isNotEmpty && neighborhoodCtrl.text.trim().isEmpty) {
                                          neighborhoodCtrl.text = res.neighborhood!;
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
                              decoration: const InputDecoration(labelText: 'Dia e Horário Habitual', hintText: 'Ex: Sábado às 09:00'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Salvar Alterações'),
                          onPressed: () async {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('O nome do contato é obrigatório.')),
                              );
                              return;
                            }
                            final phone = phoneCtrl.text.trim();
                            final addrParts = <String>[];
                            if (addrCtrl.text.trim().isNotEmpty) addrParts.add(addrCtrl.text.trim());
                            if (neighborhoodCtrl.text.trim().isNotEmpty) addrParts.add('Bairro: ${neighborhoodCtrl.text.trim()}');
                            if (refCtrl.text.trim().isNotEmpty) addrParts.add('Ref: ${refCtrl.text.trim()}');
                            final fullAddress = addrParts.isNotEmpty ? addrParts.join(' - ') : null;

                            final lat = double.tryParse(latCtrl.text.trim());
                            final lng = double.tryParse(lngCtrl.text.trim());
                            final sched = scheduleCtrl.text.trim();

                            await repo.updatePerson(person.copyWith(
                              name: name,
                              phone: Value(phone.isNotEmpty ? phone : null),
                              address: Value(fullAddress),
                              latitude: Value(lat),
                              longitude: Value(lng),
                              preferredSchedule: Value(sched.isNotEmpty ? sched : null),
                              status: currentStatus,
                              updatedAt: DateTime.now(),
                            ));

                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Dados do contato atualizados com sucesso!')),
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
      ),
    );
  }

  void _showRecordStudySessionDialog(BuildContext context, BibleStudyEntry study, PersonEntry person) {
    final allAppts = ref.read(appointmentsStreamProvider).value ?? [];

    // Busca agendamento futuro existente para este estudante para evitar duplicatas
    AppointmentEntry? existingUpcomingAppt;
    final upcoming = allAppts
        .where((a) =>
            a.personId == person.id &&
            a.startTime.isAfter(DateTime.now().subtract(const Duration(hours: 1))) &&
            a.status != 'cancelado' &&
            a.deletedAt == null)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    if (upcoming.isNotEmpty) {
      existingUpcomingAppt = upcoming.first;
    }

    int selectedLesson = (study.currentLesson ?? 1).clamp(1, 60);
    int selectedStartPoint = (study.currentParagraph ?? 1).clamp(1, 6);
    int selectedEndPoint = selectedStartPoint;
    String sessionOutcome = 'realizada'; // 'realizada' ou 'cancelada'
    String failureMotive = 'Cancelado pelo estudante';
    String selectedUnitId = 'lesson_$selectedLesson';
    final allUnits = LffBookCatalog.getAllStudyUnits();

    final initialNext = LffBookCatalog.getNextProgression(currentLesson: selectedLesson, currentPoint: selectedEndPoint);
    final lessonController = TextEditingController(text: selectedLesson.toString());
    final paragraphsController = TextEditingController(text: selectedStartPoint == selectedEndPoint ? '$selectedStartPoint' : '$selectedStartPoint-$selectedEndPoint');
    final notesController = TextEditingController();
    final nextStepController = TextEditingController(text: study.nextTopic ?? initialNext.label);
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
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final lessonInfo = LffBookCatalog.getLesson(selectedLesson);
          final progressPercent = LffBookCatalog.calculateProgressPercentage(lesson: selectedLesson, point: selectedEndPoint);

          int currentUnitMaxPoints = 6;
          final foundUnit = allUnits.where((u) => u.id == selectedUnitId).firstOrNull;
          currentUnitMaxPoints = foundUnit?.totalPoints ?? (lessonInfo?.totalPoints ?? 6);

          void updatePoints(int startP, int endP) {
            setDialogState(() {
              selectedStartPoint = startP;
              selectedEndPoint = endP;
              paragraphsController.text = startP == endP ? '$startP' : '$startP-$endP';
              final nextProg = LffBookCatalog.getNextProgression(currentLesson: selectedLesson, currentPoint: endP);
              nextStepController.text = nextProg.label;
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
                            onTap: () => setDialogState(() => sessionOutcome = 'realizada'),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              decoration: BoxDecoration(
                                color: sessionOutcome == 'realizada'
                                    ? AppTheme.successGreen.withValues(alpha: 0.15)
                                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: sessionOutcome == 'realizada' ? AppTheme.successGreen : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 16,
                                    color: sessionOutcome == 'realizada' ? AppTheme.successGreen : Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Realizada',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: sessionOutcome == 'realizada' ? AppTheme.successGreen : Colors.grey,
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
                            onTap: () => setDialogState(() => sessionOutcome = 'cancelada'),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              decoration: BoxDecoration(
                                color: sessionOutcome == 'cancelada'
                                    ? AppTheme.alertRed.withValues(alpha: 0.15)
                                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: sessionOutcome == 'cancelada' ? AppTheme.alertRed : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.cancel,
                                    size: 16,
                                    color: sessionOutcome == 'cancelada' ? AppTheme.alertRed : Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Falhou / Cancelada',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: sessionOutcome == 'cancelada' ? AppTheme.alertRed : Colors.grey,
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
                              Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
                              SizedBox(width: 6),
                              Text('Registrar Falha / Não Realização', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF991B1B), fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'O registro da falha é contabilizado no histórico e na prioridade de atenção do estudante.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF7F1D1D)),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: failureMotive,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Motivo da Falha / Não Realização *',
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Cancelado pelo estudante', child: Text('Cancelado pelo estudante')),
                              DropdownMenuItem(value: 'Estudante ausente / Não atendeu', child: Text('Estudante ausente / Não atendeu')),
                              DropdownMenuItem(value: 'Imprevisto pessoal do publicador', child: Text('Imprevisto pessoal do publicador')),
                              DropdownMenuItem(value: 'Desmarcado com antecedência', child: Text('Desmarcado com antecedência')),
                              DropdownMenuItem(value: 'Outro motivo', child: Text('Outro motivo')),
                            ],
                            onChanged: (val) {
                              if (val != null) setDialogState(() => failureMotive = val);
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
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Progresso no Livro:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                              Text('${progressPercent.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progressPercent / 100.0,
                              minHeight: 8,
                              backgroundColor: Colors.purple.shade100,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Seletor Inteligente de Unidade (Lições 1-60, Revisões 1-4, Entenda Melhor 1-7)
                    DropdownButtonFormField<String>(
                      initialValue: selectedUnitId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Unidade / Lição Estudada (lff) *'),
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
                              selectedLesson = int.parse(val.replaceFirst('lesson_', ''));
                              lessonController.text = selectedLesson.toString();
                              final nextProg = LffBookCatalog.getNextProgression(currentLesson: selectedLesson, currentPoint: selectedEndPoint);
                              nextStepController.text = nextProg.label;
                            } else {
                              nextStepController.text = val;
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Seletor dos Pontos da Lição
                    Text(
                      'Pontos Cobertos:',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: List.generate(currentUnitMaxPoints, (idx) {
                        final pNum = idx + 1;
                        final isSelected = pNum >= selectedStartPoint && pNum <= selectedEndPoint;
                        return FilterChip(
                          label: Text('Ponto $pNum'),
                          selected: isSelected,
                          selectedColor: const Color(0xFF7C3AED).withValues(alpha: 0.25),
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
                                final newEnd = pNum - 1 < selectedStartPoint ? selectedStartPoint : pNum - 1;
                                updatePoints(selectedStartPoint, newEnd);
                              } else {
                                updatePoints(pNum, pNum);
                              }
                            }
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: paragraphsController,
                      decoration: const InputDecoration(
                        labelText: 'Parágrafos / Pontos Estudados (livre para editar)',
                        hintText: 'Ex: 1, 2-3, 1-6 ou anotação personalizada',
                      ),
                      onChanged: (text) {
                        final parsed = int.tryParse(text.trim());
                        if (parsed != null && parsed >= 1 && parsed <= currentUnitMaxPoints) {
                          setDialogState(() {
                            selectedStartPoint = parsed;
                            selectedEndPoint = parsed;
                            final nextProg = LffBookCatalog.getNextProgression(currentLesson: selectedLesson, currentPoint: parsed);
                            nextStepController.text = nextProg.label;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // Seletor de Contagem de Presentes / Assistência
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
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
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF7C3AED)),
                                ),
                                Text(
                                  'Estudante e acompanhantes',
                                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF7C3AED)),
                                onPressed: () {
                                  if (attendanceCount > 1) {
                                    setDialogState(() => attendanceCount--);
                                  }
                                },
                              ),
                              Text(
                                '$attendanceCount',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: Color(0xFF7C3AED)),
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

                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: sessionOutcome == 'cancelada' ? 'Observações da falha' : 'Observações da sessão',
                      hintText: sessionOutcome == 'cancelada'
                          ? 'Descreva o que houve ou motivo de contato...'
                          : 'Dúvidas esclarecidas, pontos de interesse...',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nextStepController,
                    decoration: const InputDecoration(
                      labelText: 'Próximo assunto',
                      hintText: 'Ex: Lição 2, Ponto 1 em diante',
                    ),
                  ),
                  const SizedBox(height: 14),
                  GlobalAppointmentSchedulingSection(
                    title: 'Agendar Próximo Estudo',
                    isEnabled: scheduleNextStudy,
                    onToggle: (v) => setDialogState(() => scheduleNextStudy = v),
                    selectedDateTime: nextStudyDateTime,
                    onDateTimeChanged: (dt) => setDialogState(() => nextStudyDateTime = dt),
                    durationMinutes: nextStudyDuration,
                    onDurationChanged: (d) => setDialogState(() => nextStudyDuration = d),
                    existingAppointments: ref.read(appointmentsStreamProvider).value ?? [],
                    existingPersonAppointment: existingUpcomingAppt,
                    frequencyText: freqLabel,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: sessionOutcome == 'cancelada' ? AppTheme.alertRed : const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  if (scheduleNextStudy) {
                    final allAppts = ref.read(appointmentsStreamProvider).value ?? [];
                    final avail = AvailabilityEngine.checkAvailability(
                      startTime: nextStudyDateTime,
                      durationMinutes: nextStudyDuration,
                      existingAppointments: allAppts,
                    );
                    final canProceed = await GlobalAppointmentSchedulingSection.confirmConflictIfNeeded(
                      context: context,
                      availability: avail,
                    );
                    if (!canProceed) return;
                  }

                  final repo = ref.read(repositoryProvider);

                  if (sessionOutcome == 'cancelada') {
                    final formattedNotes = notesController.text.trim().isEmpty
                        ? '[Sessão Cancelada: $failureMotive]'
                        : '[Sessão Cancelada: $failureMotive] ${notesController.text.trim()}';

                    await repo.createStudySession(
                      studyId: study.id,
                      dateTime: DateTime.now(),
                      lessonCovered: study.currentLesson,
                      paragraphsCovered: null,
                      sessionNotes: formattedNotes,
                      nextStep: nextStepController.text.trim().isEmpty ? null : nextStepController.text.trim(),
                      status: 'cancelada',
                      participantIds: [person.id],
                    );

                    if (nextStepController.text.trim().isNotEmpty) {
                      await repo.updateStudy(
                        study.copyWith(
                          nextTopic: Value(nextStepController.text.trim()),
                        ),
                      );
                    }
                  } else {
                    final lesson = int.tryParse(lessonController.text.trim()) ?? selectedLesson;
                    final formattedNotes = DashboardCalculator.formatSessionNotesWithAttendance(
                      notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                      attendanceCount,
                    );

                    await repo.createStudySession(
                      studyId: study.id,
                      dateTime: DateTime.now(),
                      lessonCovered: lesson,
                      paragraphsCovered: paragraphsController.text.trim().isEmpty ? null : paragraphsController.text.trim(),
                      sessionNotes: formattedNotes,
                      nextStep: nextStepController.text.trim().isEmpty ? null : nextStepController.text.trim(),
                      status: 'realizada',
                      participantIds: [person.id],
                    );

                    await repo.updateStudy(
                      study.copyWith(
                        currentLesson: Value(lesson),
                        currentParagraph: Value(int.tryParse(paragraphsController.text.trim()) ?? selectedEndPoint),
                        nextTopic: Value(nextStepController.text.trim().isEmpty ? null : nextStepController.text.trim()),
                        lastSessionAt: Value(DateTime.now()),
                      ),
                    );
                  }

                  if (scheduleNextStudy) {
                    // Prevenção de duplicidade: atualiza compromisso existente na mesma data ou cria novo
                    final existingAppts = ref.read(appointmentsStreamProvider).value ?? [];
                    final existingOnDate = existingAppts.firstWhereOrNull((a) =>
                        a.deletedAt == null &&
                        a.status != 'cancelado' &&
                        a.personId == person.id &&
                        a.startTime.year == nextStudyDateTime.year &&
                        a.startTime.month == nextStudyDateTime.month &&
                        a.startTime.day == nextStudyDateTime.day);

                    if (existingOnDate != null) {
                      await repo.updateAppointment(
                        existingOnDate.copyWith(
                          studyId: Value(study.id),
                          startTime: nextStudyDateTime,
                          endTime: nextStudyDateTime.add(Duration(minutes: nextStudyDuration)),
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
                        endTime: nextStudyDateTime.add(Duration(minutes: nextStudyDuration)),
                        durationMinutes: nextStudyDuration,
                        status: 'confirmado',
                        locationNotes: person.address != null ? 'Local: ${person.address}' : null,
                      );
                    }
                  }

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(sessionOutcome == 'cancelada'
                            ? 'Falha no estudo registrada ($failureMotive).'
                            : 'Sessão registrada com sucesso! ($attendanceCount presentes computados)'),
                      ),
                    );
                  }
                },
                child: const Text('Salvar Sessão'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Modal Unificado: Registro de Visita, Estudo Bíblico e Agendamento Global (Fluxo Rápido Atômico)
  void _showQuickVisitDialog(BuildContext context, PersonEntry person, BibleStudyEntry? existingStudy) {
    final notesController = TextEditingController();
    final topicsController = TextEditingController();
    final nextStepController = TextEditingController(text: existingStudy?.nextTopic ?? '');
    String selectedType = (existingStudy != null || person.status == 'estudo') ? 'estudo' : 'revisita';
    bool recordStudy = existingStudy != null || person.status == 'estudo';
    String selectedResult = 'Conversa receptiva';
    DateTime selectedDate = DateTime.now();

    // Campos do Estudo Bíblico
    String selectedPublicationId = existingStudy?.publicationId ?? 'lff-book';
    final lessonController = TextEditingController(text: existingStudy?.currentLesson?.toString() ?? '1');
    final paragraphsController = TextEditingController(
      text: existingStudy?.currentParagraph != null ? '${existingStudy!.currentParagraph}' : '1-5',
    );
    int attendanceCount = 1;

    // Campos de Agendamento Global com AvailabilityEngine
    bool scheduleReturn = true;
    final allApptsList = ref.read(appointmentsStreamProvider).value ?? [];
    AppointmentEntry? existingUpcomingAppt;
    final upcomingList = allApptsList
        .where((a) =>
            a.personId == person.id &&
            a.startTime.isAfter(DateTime.now().subtract(const Duration(hours: 1))) &&
            a.status != 'cancelado' &&
            a.deletedAt == null)
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
    int returnDuration = existingUpcomingAppt?.durationMinutes ?? ((selectedType == 'estudo' || recordStudy) ? 60 : 30);

    if (existingUpcomingAppt != null) {
      returnDateTime = existingUpcomingAppt.startTime;
    } else {
      final target = DateTime.now().add(Duration(days: daysToAdd));
      returnDateTime = DateTime(
        target.year,
        target.month,
        target.day,
        10,
        0,
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
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
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
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
                      DropdownMenuItem(value: 'estudo', child: Text('Estudo Bíblico')),
                      DropdownMenuItem(value: 'conversa_inicial', child: Text('Conversa Inicial')),
                      DropdownMenuItem(value: 'contato_telefonico', child: Text('Contato Telefônico / Carta')),
                      DropdownMenuItem(value: 'tentativa_sem_contato', child: Text('Tentativa sem Contato (Não contou)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setSheetState(() {
                          selectedType = val;
                          if (val == 'estudo') {
                            recordStudy = true;
                            returnDuration = 60;
                          } else if (existingStudy == null && person.status != 'estudo') {
                            returnDuration = 30;
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 10),

                  if (selectedType != 'estudo') ...[
                    InkWell(
                      onTap: () {
                        setSheetState(() {
                          recordStudy = !recordStudy;
                          if (recordStudy) returnDuration = 60;
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
                              });
                            },
                          ),
                          const Expanded(
                            child: Text(
                              'Considerou matéria de estudo bíblico nesta conversa',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF7C3AED)),
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
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.menu_book, size: 18, color: Color(0xFF7C3AED)),
                              const SizedBox(width: 8),
                              Text(
                                existingStudy != null ? 'Progresso do Estudo Bíblico' : 'Novo Estudo Bíblico Integrado',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF7C3AED)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: selectedPublicationId,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Publicação'),
                            items: PublicationCatalog.allPublications.map((p) {
                              return DropdownMenuItem(value: p.id, child: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setSheetState(() => selectedPublicationId = val);
                            },
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: lessonController,
                                  decoration: const InputDecoration(labelText: 'Lição estudada'),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: paragraphsController,
                                  decoration: const InputDecoration(labelText: 'Parágrafos considerados'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Contagem de Assistência / Presentes
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Assistência / Ouvintes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF7C3AED))),
                                    Text('Estudante e acompanhantes', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted)),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF7C3AED)),
                                    onPressed: () {
                                      if (attendanceCount > 1) {
                                        setSheetState(() => attendanceCount--);
                                      }
                                    },
                                  ),
                                  Text('$attendanceCount', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, color: Color(0xFF7C3AED)),
                                    onPressed: () {
                                      setSheetState(() => attendanceCount++);
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
                      labelText: 'Próximo passo / Próximo estudo combinado',
                      hintText: 'Ex: Responder por que Deus permite o sofrimento',
                    ),
                  ),
                  const SizedBox(height: 14),

                  // SEÇÃO DE AGENDAMENTO GLOBAL COM AVAILABILITY ENGINE
                  GlobalAppointmentSchedulingSection(
                    title: (selectedType == 'estudo' || recordStudy)
                        ? 'Agendar Próximo Estudo'
                        : 'Agendar Próximo Retorno',
                    isEnabled: scheduleReturn,
                    onToggle: (val) => setSheetState(() => scheduleReturn = val),
                    selectedDateTime: returnDateTime,
                    onDateTimeChanged: (dt) => setSheetState(() => returnDateTime = dt),
                    durationMinutes: returnDuration,
                    onDurationChanged: (dur) => setSheetState(() => returnDuration = dur),
                    existingAppointments: allAppts,
                    existingPersonAppointment: existingUpcomingAppt,
                    frequencyText: freqLabel,
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (selectedType == 'estudo' || recordStudy) ? const Color(0xFF7C3AED) : AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        if (scheduleReturn) {
                          final availability = AvailabilityEngine.checkAvailability(
                            startTime: returnDateTime,
                            durationMinutes: returnDuration,
                            existingAppointments: allAppts,
                          );
                          final proceed = await GlobalAppointmentSchedulingSection.confirmConflictIfNeeded(
                            context: context,
                            availability: availability,
                          );
                          if (!proceed) return;
                        }

                        final isStudyConsidered = selectedType == 'estudo' || recordStudy;
                        final repo = ref.read(repositoryProvider);
                        String? appointmentId;

                        // 1. Agendamento Global (se ativado)
                        if (scheduleReturn) {
                          final apptTitle = isStudyConsidered
                              ? 'Estudo Bíblico: ${person.name}'
                              : 'Revisita: ${person.name}';

                          // Prevenção de duplicidade: atualiza compromisso existente na mesma data ou cria novo
                          final existingAppts = ref.read(appointmentsStreamProvider).value ?? [];
                          final existingOnDate = existingAppts.firstWhereOrNull((a) =>
                              a.deletedAt == null &&
                              a.status != 'cancelado' &&
                              a.personId == person.id &&
                              a.startTime.year == returnDateTime.year &&
                              a.startTime.month == returnDateTime.month &&
                              a.startTime.day == returnDateTime.day);

                          if (existingOnDate != null) {
                            await repo.updateAppointment(
                              existingOnDate.copyWith(
                                studyId: existingStudy != null ? Value(existingStudy.id) : const Value.absent(),
                                startTime: returnDateTime,
                                endTime: returnDateTime.add(Duration(minutes: returnDuration)),
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
                              endTime: returnDateTime.add(Duration(minutes: returnDuration)),
                              durationMinutes: returnDuration,
                              status: 'confirmado',
                              locationNotes: person.address != null ? 'Local: ${person.address}' : null,
                            );
                            appointmentId = appt.id;
                          }
                        }

                        // 2. Registro da Visita (Atômico)
                        final formattedNotes = isStudyConsidered
                            ? DashboardCalculator.formatSessionNotesWithAttendance(
                                notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                                attendanceCount,
                              )
                            : (notesController.text.trim().isEmpty ? null : notesController.text.trim());

                        await repo.createVisit(
                          personId: person.id,
                          dateTime: selectedDate,
                          contactType: selectedType,
                          result: selectedResult,
                          topicsDiscussed: topicsController.text.trim().isEmpty ? null : topicsController.text.trim(),
                          notes: formattedNotes,
                          nextStep: nextStepController.text.trim().isEmpty ? null : nextStepController.text.trim(),
                          suggestedReturnDate: scheduleReturn ? returnDateTime : null,
                          appointmentId: appointmentId,
                        );

                        // 3. Registro do Estudo e Sessão (se tipo Estudo ou matéria considerada)
                        if (isStudyConsidered) {
                          final lesson = int.tryParse(lessonController.text.trim()) ?? 1;
                          final paraText = paragraphsController.text.trim().isEmpty ? '1-5' : paragraphsController.text.trim();

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
                            nextStep: nextStepController.text.trim().isEmpty ? null : nextStepController.text.trim(),
                            status: 'realizada',
                            participantIds: [person.id],
                          );

                          if (person.status != 'estudo') {
                            await repo.updatePerson(person.copyWith(status: 'estudo'));
                          }
                        }

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
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Modal de Agendamento Tipo Consultório (com Verificação Instantânea de Conflitos)
  void _showScheduleDialog(BuildContext context, PersonEntry person) {
    DateTime selectedDateTime = DateTime.now().add(const Duration(days: 1, hours: 2));
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
                onDateTimeChanged: (dt) => setDialogState(() => selectedDateTime = dt),
                durationMinutes: durationMinutes,
                onDurationChanged: (dur) => setDialogState(() => durationMinutes = dur),
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
                  final proceed = await GlobalAppointmentSchedulingSection.confirmConflictIfNeeded(
                    context: context,
                    availability: availability,
                  );
                  if (!proceed) return;

                  final repo = ref.read(repositoryProvider);
                  await repo.createAppointment(
                    personId: person.id,
                    title: 'Retorno: ${person.name}',
                    startTime: selectedDateTime,
                    endTime: selectedDateTime.add(Duration(minutes: durationMinutes)),
                    durationMinutes: durationMinutes,
                    status: 'confirmado',
                    locationNotes: person.address != null ? 'Local: ${person.address}' : null,
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
    final people = ref.watch(peopleStreamProvider).value ?? [];
    final studies = ref.watch(studiesStreamProvider).value ?? [];
    final participants = ref.watch(studyParticipantsStreamProvider).value ?? [];

    final person = people.where((p) => p.id == widget.personId).firstOrNull;

    if (person == null) {
      return FutureBuilder<PersonEntry?>(
        future: repo.getPersonById(widget.personId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final fallbackPerson = snapshot.data!;
          return _buildMainScaffold(context, repo, fallbackPerson, studies, participants);
        },
      );
    }

    return _buildMainScaffold(context, repo, person, studies, participants);
  }

  // ---------------------------------------------------------------------------
  // MÉTODOS DE PARSING E PERSISTÊNCIA ESTRUTURADA EM JSON (Aba 3 e Aba 4)
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> _parseNotes(String? raw) {
    return DoorstepBriefingHelper.parseNotes(raw);
  }

  Future<void> _saveNotes(AppRepository repo, PersonEntry person, List<Map<String, dynamic>> notes) async {
    final jsonStr = notes.isEmpty ? null : jsonEncode(notes);
    await repo.updatePerson(person.copyWith(generalNotes: Value(jsonStr)));
  }

  List<Map<String, dynamic>> _parseTargets(String? raw) {
    return DoorstepBriefingHelper.parseTargets(raw);
  }

  Future<void> _saveTargets(AppRepository repo, PersonEntry person, List<Map<String, dynamic>> targets) async {
    final jsonStr = targets.isEmpty ? null : jsonEncode(targets);
    await repo.updatePerson(person.copyWith(contactRestrictions: Value(jsonStr)));
  }

  // Dialog para definir Dia e Horário Habitual (ex: "Sábado às 09:00")
  void _showEditPreferredScheduleDialog(BuildContext context, PersonEntry person) {
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
    final customController = TextEditingController(text: person.preferredSchedule ?? 'Sábado às 09:00');
    bool isCustom = false;

    if (person.preferredSchedule != null && person.preferredSchedule!.contains(' às ')) {
      final parts = person.preferredSchedule!.split(' às ');
      final dayCandidate = parts[0].trim();
      final timeCandidate = parts[1].trim();
      if (daysOfWeek.contains(dayCandidate) && dayCandidate != 'Personalizado') {
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
    } else if (person.preferredSchedule != null && person.preferredSchedule!.isNotEmpty) {
      isCustom = true;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final formattedTime = '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
          final previewText = isCustom ? customController.text : '$selectedDay às $formattedTime';

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
                    style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 14),
                  if (!isCustom) ...[
                    DropdownButtonFormField<String>(
                      initialValue: selectedDay,
                      decoration: const InputDecoration(labelText: 'Dia da Semana'),
                      items: daysOfWeek.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
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
                            const Text('Horário Específico', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                            Text(
                              formattedTime,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
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
                      onPressed: () => setDialogState(() => isCustom = true),
                      child: const Text('Escrever texto livre personalizado...'),
                    ),
                  ] else ...[
                    TextField(
                      controller: customController,
                      decoration: const InputDecoration(
                        labelText: 'Horário habitual personalizado',
                        hintText: 'Ex: Sábado às 09:00 ou Domingos após reunião',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => setDialogState(() => isCustom = false),
                      child: const Text('Voltar para seleção de dia e hora padrão'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: Color(0xFF7C3AED)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Será salvo como: "$previewText"',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
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
                  final textToSave = isCustom ? customController.text.trim() : '$selectedDay às $formattedTime';
                  final repo = ref.read(repositoryProvider);
                  await repo.updatePerson(person.copyWith(preferredSchedule: Value(textToSave)));
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Horário habitual atualizado para "$textToSave"')),
                    );
                  }
                },
                child: const Text('Salvar Horário'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Dialog para adicionar ou editar Necessidade / Observação
  void _showAddOrEditNoteDialog(BuildContext context, AppRepository repo, PersonEntry person, [Map<String, dynamic>? noteToEdit]) {
    final textController = TextEditingController(text: noteToEdit?['text'] ?? '');
    final isEditing = noteToEdit != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.note_alt_outlined, color: AppTheme.accentTeal),
            const SizedBox(width: 8),
            Text(isEditing ? 'Editar Necessidade / Obs.' : 'Nova Necessidade / Obs.'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Registre circunstâncias familiares, dúvidas levantadas, assuntos de interesse ou necessidades de ${person.name}.',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 12),
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
                  const Icon(Icons.access_time, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    isEditing
                        ? 'Criado em: ${AppDateUtils.formatDateTimeWithAt(DateTime.tryParse(noteToEdit['createdAt'] ?? ''))}'
                        : 'Registro de data e hora automático.',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentTeal, foregroundColor: Colors.white),
            onPressed: () async {
              final text = textController.text.trim();
              if (text.isEmpty) return;

              final currentNotes = _parseNotes(person.generalNotes);
              if (isEditing) {
                final idx = currentNotes.indexWhere((n) => n['id'] == noteToEdit['id']);
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
                  SnackBar(content: Text(isEditing ? 'Anotação atualizada!' : 'Necessidade/observação registrada com data e hora!')),
                );
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  // Dialog para adicionar ou editar Alvo ou Tarefa
  void _showAddOrEditTargetDialog(BuildContext context, AppRepository repo, PersonEntry person, [Map<String, dynamic>? targetToEdit]) {
    final titleController = TextEditingController(text: targetToEdit?['title'] ?? '');
    final isEditing = targetToEdit != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.track_changes, color: Color(0xFF7C3AED)),
            const SizedBox(width: 8),
            Text(isEditing ? 'Editar Alvo / Tarefa' : 'Novo Alvo ou Tarefa Espiritual'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Defina um alvo espiritual ou tarefa deixada para ${person.name} até a próxima visita.',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 12),
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
                  const Icon(Icons.access_time, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    isEditing
                        ? 'Criado em: ${AppDateUtils.formatDateTimeWithAt(DateTime.tryParse(targetToEdit['createdAt'] ?? ''))}'
                        : 'Data e hora da criação gravadas automaticamente.',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white),
            onPressed: () async {
              final title = titleController.text.trim();
              if (title.isEmpty) return;

              final currentTargets = _parseTargets(person.contactRestrictions);
              if (isEditing) {
                final idx = currentTargets.indexWhere((t) => t['id'] == targetToEdit['id']);
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
                  SnackBar(content: Text(isEditing ? 'Alvo atualizado!' : 'Novo alvo cadastrado com sucesso!')),
                );
              }
            },
            child: const Text('Salvar Alvo'),
          ),
        ],
      ),
    );
  }

  Widget _buildMainScaffold(
    BuildContext context,
    AppRepository repo,
    PersonEntry person,
    List<BibleStudyEntry> studies,
    List<StudyParticipantEntry> participants,
  ) {
    // Localiza estudo bíblico vinculado a esta pessoa
    final linkedParticipant = participants.where((p) => p.personId == person.id && p.deletedAt == null).firstOrNull;
    final linkedStudy = linkedParticipant != null
        ? studies.where((s) => s.id == linkedParticipant.studyId && s.deletedAt == null).firstOrNull
        : null;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: Text(person.name),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar Dados do Contato',
              onPressed: () => _showEditPersonDialog(context, repo, person),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppTheme.primaryBlue,
            tabs: [
              Tab(icon: Icon(Icons.history_edu), text: 'Visitas & Contato'),
              Tab(icon: Icon(Icons.school), text: 'Estudo Bíblico'),
              Tab(icon: Icon(Icons.photo_library), text: 'Fotos'),
              Tab(icon: Icon(Icons.auto_stories), text: 'Publicações & Pedidos'),
              Tab(icon: Icon(Icons.family_restroom), text: 'Família & Vínculos'),
              Tab(icon: Icon(Icons.note_alt_outlined), text: 'Necessidades & Obs.'),
              Tab(icon: Icon(Icons.track_changes), text: 'Alvos & Tarefas'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: VISITAS & CONTATO
            _buildVisitsAndContactTab(context, repo, person, linkedStudy, isDark),

            // TAB 2: ESTUDO BÍBLICO (Progresso, Publicações, JW Library e Sessões)
            _buildBibleStudyTab(context, repo, person, linkedStudy, isDark),

            // TAB 3: FOTOS DA PESSOA / RESIDÊNCIA / ESTUDO
            PersonPhotosTab(person: person),

            // TAB 4: PUBLICAÇÕES & PEDIDOS (Checklist e Pedidos)
            PersonPublicationsTab(person: person),

            // TAB 5: FAMÍLIA & VÍNCULOS (Relacionamentos bidirecionais automáticos)
            PersonFamilyTiesTab(person: person),

            // TAB 6: NECESSIDADES & OBSERVAÇÕES
            _buildNeedsAndNotesTab(context, repo, person, isDark),

            // TAB 7: ALVOS & TAREFAS
            _buildTargetsAndTasksTab(context, repo, person, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitsAndContactTab(
    BuildContext context,
    AppRepository repo,
    PersonEntry person,
    BibleStudyEntry? linkedStudy,
    bool isDark,
  ) {
    final allPhotos = ref.watch(personPhotosStreamProvider).value ?? [];
    final personPhoto = allPhotos.where((p) => p.personId == person.id && p.photoType == 'person').firstOrNull;
    final housePhoto = allPhotos.where((p) => p.personId == person.id && p.photoType == 'house').firstOrNull;

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
                    const Icon(Icons.outbox, color: Color(0xFFB45309), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Revisita Repassada para Outro Publicador',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF92400E)),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Esta revisita está oculta da agenda e estatísticas ativas. Se você voltou a atendê-la, pode reativá-la com 1 toque.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF78350F)),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB45309),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => PersonHandOffHelper.reactivatePerson(context: context, ref: ref, person: person),
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
                    const Icon(Icons.person_off_outlined, color: Color(0xFFB45309), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Revisita Encerrada (com motivo)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF92400E)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            person.nextActionNote ?? 'Esta revisita foi encerrada, mas todo o histórico está preservado.',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF78350F)),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB45309),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _reactivateReturnVisit(context, repo, person),
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
                          if (personPhoto != null && personPhoto.imageData.isNotEmpty) {
                            showModalBottomSheet(
                              context: context,
                              builder: (bCtx) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.fullscreen, color: AppTheme.primaryBlue),
                                      title: const Text('Ver Foto em Tela Cheia'),
                                      onTap: () {
                                        Navigator.pop(bCtx);
                                        MediaPickerHelper.showFullScreenImage(
                                          context,
                                          imageSource: personPhoto.imageData,
                                          title: 'Foto: ${person.name}',
                                          onDelete: () async {
                                            await ref.read(personPhotosManagerProvider).deletePhoto(person.id, 'person');
                                          },
                                        );
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.add_a_photo, color: AppTheme.accentTeal),
                                      title: const Text('Trocar Foto'),
                                      onTap: () async {
                                        Navigator.pop(bCtx);
                                        final img = await MediaPickerHelper.pickImageOrCapture(context);
                                        if (img != null) {
                                          await ref.read(personPhotosManagerProvider).savePersonPhoto(person.id, img);
                                        }
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.delete_outline, color: Colors.red),
                                      title: const Text('Remover Foto', style: TextStyle(color: Colors.red)),
                                      onTap: () async {
                                        Navigator.pop(bCtx);
                                        await ref.read(personPhotosManagerProvider).deletePhoto(person.id, 'person');
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          } else {
                            final img = await MediaPickerHelper.pickImageOrCapture(context);
                            if (img != null) {
                              await ref.read(personPhotosManagerProvider).savePersonPhoto(person.id, img);
                            }
                          }
                        },
                        borderRadius: BorderRadius.circular(30),
                        child: Stack(
                          children: [
                            if (personPhoto != null && personPhoto.imageData.isNotEmpty)
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
                                backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                child: Text(
                                  person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                                ),
                              ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: AppTheme.primaryBlue, shape: BoxShape.circle),
                                child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
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
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            Row(
                              children: [
                                Chip(
                                  label: Text(
                                    person.status.toUpperCase(),
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                  backgroundColor: person.status == 'estudo'
                                      ? const Color(0xFF7C3AED).withValues(alpha: 0.15)
                                      : person.status == 'revisita_passada'
                                          ? const Color(0xFFFEF3C7)
                                          : AppTheme.primaryBlue.withValues(alpha: 0.1),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Primeiro: ${AppDateUtils.formatDate(person.firstContactAt)}',
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Tags da Pessoa com botão de gerenciar
                            Builder(
                              builder: (context) {
                                List<String> personTags = [];
                                if (person.tags.isNotEmpty && person.tags != '[]') {
                                  if (person.tags.startsWith('[')) {
                                    try {
                                      final decoded = jsonDecode(person.tags) as List;
                                      personTags = decoded.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
                                    } catch (_) {}
                                  } else {
                                    personTags = person.tags.split(',').map((e) => e.trim()).where((s) => s.isNotEmpty).toList();
                                  }
                                }

                                return Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    ...personTags.map((t) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white10 : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text('#$t', style: const TextStyle(fontSize: 10)),
                                    )),
                                    InkWell(
                                      onTap: () => _showEditPersonTagsDialog(context, repo, person),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.label_outline, size: 12, color: AppTheme.primaryBlue),
                                            SizedBox(width: 3),
                                            Text('Tags', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                                          ],
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
                        const Icon(Icons.phone, size: 18, color: AppTheme.textMuted),
                        const SizedBox(width: 8),
                        Expanded(child: Text(person.phone!, style: const TextStyle(fontSize: 15))),
                        IconButton(
                          icon: const Icon(Icons.call, size: 20, color: AppTheme.primaryBlue),
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
                          icon: const Icon(Icons.chat, size: 20, color: Color(0xFF25D366)),
                          tooltip: 'WhatsApp',
                          visualDensity: VisualDensity.compact,
                          onPressed: () async {
                            final cleanPhone = person.phone!.replaceAll(RegExp(r'\D'), '');
                            final uri = Uri.parse('https://wa.me/$cleanPhone');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 18, color: AppTheme.textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          person.address != null && person.address!.isNotEmpty
                              ? person.address!
                              : (person.latitude != null && person.longitude != null
                                  ? 'GPS: ${person.latitude!.toStringAsFixed(4)}, ${person.longitude!.toStringAsFixed(4)}'
                                  : 'Endereço não cadastrado (toque no mapa para definir)'),
                          style: TextStyle(
                            fontSize: 14,
                            color: (person.address == null || person.address!.isEmpty) ? AppTheme.textMuted : null,
                            fontStyle: (person.address == null || person.address!.isEmpty) ? FontStyle.italic : null,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.map, size: 20, color: AppTheme.primaryBlue),
                        tooltip: 'Ver no Mapa do Território',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ContactsMapScreen(highlightPersonId: person.id),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_location_alt, size: 20, color: AppTheme.accentTeal),
                        tooltip: 'Ajustar Localização / Escolher no Mapa',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _openLocationPickerForPerson(context, repo, person),
                      ),
                      if ((person.address != null && person.address!.isNotEmpty) || (person.latitude != null && person.longitude != null))
                        IconButton(
                          icon: const Icon(Icons.open_in_new, size: 20, color: Colors.blueGrey),
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
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        if (housePhoto != null && housePhoto.imageData.isNotEmpty)
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
                              message: 'Toque para ampliar foto em alta resolução',
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
                                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                                      child: const Icon(Icons.zoom_in, size: 12, color: Colors.white),
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
                              color: isDark ? Colors.white10 : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.home, color: Colors.grey, size: 28),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Foto da Residência / Fachada', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 2),
                              Text(
                                housePhoto != null
                                    ? 'Foto cadastrada. Toque para ver em tela cheia.'
                                    : 'Facilita localizar a residência no território.',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          icon: const Icon(Icons.add_a_photo, size: 14),
                          label: Text(housePhoto != null ? 'Trocar' : 'Tirar Foto', style: const TextStyle(fontSize: 11)),
                          onPressed: () async {
                            final img = await MediaPickerHelper.pickImageOrCapture(context);
                            if (img != null) {
                              await ref.read(personPhotosManagerProvider).saveHousePhoto(person.id, img);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  if (person.preferredSchedule != null && person.preferredSchedule!.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.alarm, size: 18, color: Color(0xFF7C3AED)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Horário habitual: ${person.preferredSchedule!}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
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
                          const Icon(Icons.note_alt_outlined, size: 18, color: AppTheme.accentTeal),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${notes.length} ${notes.length == 1 ? "anotação/necessidade registrada" : "anotações/necessidades registradas"} (ver aba Necessidades & Obs.)',
                              style: const TextStyle(fontSize: 13, color: AppTheme.accentTeal, fontWeight: FontWeight.w500),
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
              final briefingData = DoorstepBriefingHelper.build(
                person: person,
                linkedStudy: linkedStudy,
                latestVisit: latestVisit,
              );
              return DoorstepBriefingCard(
                data: briefingData,
                onOpenJwLibrary: linkedStudy != null
                    ? () => _openPublicationLink(context, linkedStudy)
                    : null,
              );
            },
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
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF7C3AED)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${person.name} ainda não possui um livro ou brochura vinculado para registro de lições.',
                      style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
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
                        label: Text('+ Iniciar Estudo Bíblico com ${person.name}'),
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
                  onPressed: () => _showQuickVisitDialog(context, person, linkedStudy),
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
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFD97706),
                side: const BorderSide(color: Color(0xFFD97706)),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Passar Revisita para Outro Publicador (WhatsApp / GPS)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              onPressed: () => PersonHandOffHelper.showHandOffDialog(context: context, ref: ref, person: person, linkedStudy: linkedStudy),
            ),
          ),
          if (person.status == 'revisita' || person.status == 'interessado') ...[
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
                label: const Text('Encerrar Revisita (com motivo)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () => _showEndReturnVisitDialog(context, person, repo),
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Ideia 3: Alerta de Proximidade Expandido (Contatos e Reativações Vizinhas)
          _buildProximityAlertsSection(context, person, ref, isDark),
          const SizedBox(height: 20),

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
                              Row(
                                children: [
                                  Builder(
                                    builder: (context) {
                                      final attendance = DashboardCalculator.parseVisitAttendance(v);
                                      if (attendance <= 0) return const SizedBox.shrink();
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: Chip(
                                          avatar: const Icon(Icons.group, size: 14, color: AppTheme.primaryBlue),
                                          label: Text(
                                            '$attendance ${attendance == 1 ? "ouvinte" : "ouvintes"}',
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                          padding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      );
                                    },
                                  ),
                                  Chip(
                                    label: Text(v.contactType, style: const TextStyle(fontSize: 11)),
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
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
    );
  }

  Widget _buildBibleStudyTab(
    BuildContext context,
    AppRepository repo,
    PersonEntry person,
    BibleStudyEntry? linkedStudy,
    bool isDark,
  ) {
    if (linkedStudy == null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.menu_book, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                'Nenhum Estudo Bíblico Vinculado',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Inicie o estudo bíblico com ${person.name} para acompanhar o progresso das lições no livro "Viva Feliz para Sempre!", referências oficiais do JW Library e sessões com contagem de assistência.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textMuted),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: const Icon(Icons.add_circle_outline),
                label: Text('+ Iniciar Estudo Bíblico com ${person.name}'),
                onPressed: () => _showStartStudyDialog(context, person),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.alarm, size: 20, color: Color(0xFF7C3AED)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Dia e Horário Habitual', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                  Text(
                                    person.preferredSchedule != null && person.preferredSchedule!.isNotEmpty
                                        ? person.preferredSchedule!
                                        : 'Não definido (ex: Sábado às 09:00)',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => _showEditPreferredScheduleDialog(context, person),
                        child: Text(person.preferredSchedule == null || person.preferredSchedule!.isEmpty ? 'Definir' : 'Alterar'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final pub = PublicationCatalog.getById(linkedStudy.publicationId);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Principal do Estudo
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.menu_book, color: Color(0xFF7C3AED), size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              linkedStudy.title,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              pub?.title ?? linkedStudy.publicationId,
                              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(
                          linkedStudy.status.toUpperCase(),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: linkedStudy.status == 'ativo'
                            ? const Color(0xFF059669).withValues(alpha: 0.15)
                            : AppTheme.primaryBlue.withValues(alpha: 0.1),
                        side: BorderSide(
                          color: linkedStudy.status == 'ativo'
                              ? const Color(0xFF059669)
                              : AppTheme.primaryBlue,
                        ),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Lição Atual', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                          Text(
                            linkedStudy.currentLesson != null ? 'Lição ${linkedStudy.currentLesson}' : 'Não definida',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            linkedStudy.publicationId == 'lff-book' || linkedStudy.publicationId == 'lff-brochure'
                                ? 'Ponto Atual'
                                : 'Parágrafo',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                          Text(
                            linkedStudy.currentParagraph != null
                                ? (linkedStudy.publicationId == 'lff-book' || linkedStudy.publicationId == 'lff-brochure'
                                    ? 'Ponto ${linkedStudy.currentParagraph}'
                                    : 'Parágrafo ${linkedStudy.currentParagraph}')
                                : 'Início',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Frequência', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                          Chip(
                            label: Text(linkedStudy.frequency.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.alarm, size: 20, color: Color(0xFF7C3AED)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Dia e Horário Habitual do Estudo',
                                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                    ),
                                    Text(
                                      person.preferredSchedule != null && person.preferredSchedule!.isNotEmpty
                                          ? person.preferredSchedule!
                                          : 'Não definido (ex: Sábado às 09:00)',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          icon: const Icon(Icons.edit, size: 16),
                          label: Text(
                            person.preferredSchedule == null || person.preferredSchedule!.isEmpty ? 'Definir' : 'Alterar',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () => _showEditPreferredScheduleDialog(context, person),
                        ),
                      ],
                    ),
                  ),
                  if (linkedStudy.nextTopic != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.flag_outlined, size: 16, color: Color(0xFF7C3AED)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Próximo assunto: ${linkedStudy.nextTopic}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF7C3AED), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('Abrir no JW Library', style: TextStyle(fontSize: 12)),
                          onPressed: () => _openPublicationLink(context, linkedStudy),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.add_task, size: 16),
                          label: const Text('Registrar Sessão', style: TextStyle(fontSize: 12)),
                          onPressed: () => _showRecordStudySessionDialog(context, linkedStudy, person),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Card de Progresso Individual 0–100% no Livro LFF
          if (linkedStudy.publicationId == 'lff-book') ...[
            Builder(builder: (context) {
              final lesson = linkedStudy.currentLesson ?? 1;
              final point = linkedStudy.currentParagraph ?? 1;
              final progressPct = LffBookCatalog.calculateProgressPercentage(lesson: lesson, point: point);
              final section = LffBookCatalog.getSectionForLesson(lesson);
              final lessonInfo = LffBookCatalog.getLesson(lesson);
              final pointsCovered = (lesson - 1) * 6 + point.clamp(1, 6);

              final studyAgeDays = DateTime.now().difference(linkedStudy.startedAt).inDays;
              final effectiveDays = studyAgeDays < 1 ? 1 : studyAgeDays;
              final studyAgeWeeks = (effectiveDays / 7.0) < 0.5 ? 0.5 : (effectiveDays / 7.0);
              final velocity = (lesson - 1 + (point / 6.0)) / studyAgeWeeks;
              final String velocityText;
              final Color velocityColor;
              if (velocity >= 1.2) {
                velocityText = '⚡ Ritmo Acelerado (${velocity.toStringAsFixed(1)} lições/sem)';
                velocityColor = const Color(0xFF059669);
              } else if (velocity >= 0.8) {
                velocityText = '🎯 Ritmo Ideal (~1 lição/sem)';
                velocityColor = const Color(0xFF2563EB);
              } else if (velocity >= 0.4) {
                velocityText = '🌱 Ritmo Constante (${velocity.toStringAsFixed(1)} lições/sem)';
                velocityColor = const Color(0xFFD97706);
              } else {
                velocityText = '🐢 Ritmo Calmo / Pausado';
                velocityColor = const Color(0xFF64748B);
              }

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.speed_rounded, color: Color(0xFF7C3AED), size: 22),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Progresso Oficial do Livro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text('Seção ${section.sectionNumber}: ${section.title}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                ],
                              ),
                            ],
                          ),
                          Text(
                            '${progressPct.toStringAsFixed(1)}%',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progressPct / 100.0,
                          minHeight: 12,
                          backgroundColor: Colors.purple.shade100,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$pointsCovered de 360 pontos concluídos', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                          Text('Lição $lesson de 60', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Lição Atual:', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                Text(
                                  lessonInfo != null ? 'Lição $lesson: ${lessonInfo.title}' : 'Lição $lesson',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: velocityColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: velocityColor.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              velocityText,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: velocityColor),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 14),
          ],

          // Ideia 5: Linha do Tempo Espiritual do Estudante
          _buildSpiritualTimelineCard(context, person, linkedStudy, repo, isDark),
          const SizedBox(height: 14),

          // Card de Métricas do Estudante & Funil de Progresso
          StreamBuilder<List<StudySessionEntry>>(
            stream: repo.watchSessionsForStudy(linkedStudy.id),
            builder: (context, sessionSnap) {
              final sessions = sessionSnap.data ?? [];
              return StreamBuilder<List<VisitEntry>>(
                stream: repo.watchVisitsForPerson(person.id),
                builder: (context, visitSnap) {
                  final visits = visitSnap.data ?? [];
                  final progress = DashboardCalculator.calculateStudentProgress(
                    person: person,
                    study: linkedStudy,
                    sessions: sessions,
                    visits: visits,
                  );

                  return Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.insights, color: Color(0xFF7C3AED), size: 20),
                              SizedBox(width: 8),
                              Text('Métricas e Regularidade do Estudante', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _MetricSmallCard(
                                  label: 'Total de Visitas',
                                  value: '${progress.totalVisits}',
                                  icon: Icons.repeat,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _MetricSmallCard(
                                  label: 'Não estava em casa',
                                  value: '${progress.notAtHomeVisits}',
                                  icon: Icons.door_front_door_outlined,
                                  color: AppTheme.alertAmber,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _MetricSmallCard(
                                  label: '% Regularidade',
                                  value: '${progress.regularityPercent.toStringAsFixed(0)}%',
                                  icon: Icons.check_circle_outline,
                                  color: progress.regularityPercent >= 70 ? AppTheme.successGreen : AppTheme.alertAmber,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _MetricSmallCard(
                                  label: 'Média Presentes',
                                  value: progress.averageAttendees.toStringAsFixed(1),
                                  icon: Icons.group,
                                  color: const Color(0xFF7C3AED),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Progresso no Livro "Seja Feliz Para Sempre!"
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: progress.isPart3Reached
                                  ? AppTheme.successGreen.withValues(alpha: 0.08)
                                  : const Color(0xFF7C3AED).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: progress.isPart3Reached
                                    ? AppTheme.successGreen.withValues(alpha: 0.3)
                                    : const Color(0xFF7C3AED).withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  progress.isPart3Reached ? Icons.check_circle : Icons.bookmark,
                                  color: progress.isPart3Reached ? AppTheme.successGreen : const Color(0xFF7C3AED),
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        progress.isBookCompleted
                                            ? '🎉 Livro Seja Feliz Para Sempre! Concluído'
                                            : progress.isPart3Reached
                                                ? '🎯 Atingiu a Parte 3 (Lição 34+) - Avançando no Livro!'
                                                : 'Progresso: Lição ${progress.currentLesson} de 60',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: progress.isPart3Reached ? AppTheme.successGreen : const Color(0xFF7C3AED),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        progress.isPart3Reached
                                            ? 'Estudante passou com êxito da transição da brochura e segue o estudo até o batismo.'
                                            : 'Base fundamental das seções 1 e 2 até a Lição 33.',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Botão Encerrar Estudo ou Reativar Estudo
                          if (linkedStudy.status == 'encerrado' || linkedStudy.status == 'concluido') ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFF59E0B)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info, color: Color(0xFFB45309), size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Estudo encerrado: ${progress.endReason ?? "Sem motivo informado"}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.successGreen,
                                      foregroundColor: Colors.white,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    icon: const Icon(Icons.refresh, size: 14),
                                    label: const Text('Reativar Estudo', style: TextStyle(fontSize: 11)),
                                    onPressed: () => _reactivateStudy(context, repo, linkedStudy, person),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.alertRed,
                                  side: const BorderSide(color: AppTheme.alertRed),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                                icon: const Icon(Icons.stop_circle_outlined, size: 16),
                                label: const Text('Encerrar Estudo Bíblico (com motivo)'),
                                onPressed: () => _showEndStudyDialog(context, repo, linkedStudy, person),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 20),

          // Histórico das Sessões de Estudo
          const Text(
            'Histórico de Sessões Realizadas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
          ),
          const SizedBox(height: 8),

          StreamBuilder<List<StudySessionEntry>>(
            stream: repo.watchSessionsForStudy(linkedStudy.id),
            builder: (context, sessionSnapshot) {
              final sessions = sessionSnapshot.data ?? [];
              if (sessions.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        'Nenhuma sessão registrada para este estudo ainda.\nToque em "Registrar Sessão" ou "Registrar Conversa" para pontuar as lições.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: sessions.map((s) {
                  final attendance = DashboardCalculator.parseSessionAttendance(s);

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
                                AppDateUtils.formatDateTime(s.dateTimeField),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                              ),
                              Chip(
                                avatar: Icon(
                                  s.status == 'cancelada' ? Icons.cancel_outlined : Icons.group,
                                  size: 14,
                                  color: s.status == 'cancelada' ? AppTheme.alertRed : const Color(0xFF7C3AED),
                                ),
                                label: Text(
                                  s.status == 'cancelada'
                                      ? 'Estudo Falhou / Não Realizado'
                                      : '$attendance ${attendance == 1 ? "presente" : "presentes"}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: s.status == 'cancelada' ? AppTheme.alertRed : null,
                                  ),
                                ),
                                backgroundColor: s.status == 'cancelada' ? AppTheme.alertRed.withValues(alpha: 0.1) : null,
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (s.lessonCovered != null)
                                Text('Lição ${s.lessonCovered}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              if (s.paragraphsCovered != null) ...[
                                const Text(' • '),
                                Text('Parágrafos: ${s.paragraphsCovered}'),
                              ],
                            ],
                          ),
                          if (s.sessionNotes != null) ...[
                            const SizedBox(height: 4),
                            Text(s.sessionNotes!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                          ],
                          if (s.nextStep != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Próximo passo: ${s.nextStep}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF7C3AED)),
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
    );
  }

  // ---------------------------------------------------------------------------
  // ABA 3: NECESSIDADES & OBSERVAÇÕES (Registro de data/hora exata em JSON)
  // ---------------------------------------------------------------------------
  Widget _buildNeedsAndNotesTab(
    BuildContext context,
    AppRepository repo,
    PersonEntry person,
    bool isDark,
  ) {
    final notes = _parseNotes(person.generalNotes);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Necessidades & Observações',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${notes.length} ${notes.length == 1 ? "registro com data e hora" : "registros com data e hora"}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentTeal,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('+ Nova Observação'),
                onPressed: () => _showAddOrEditNoteDialog(context, repo, person),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (notes.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.note_alt_outlined, size: 56, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'Nenhuma necessidade ou observação registrada para ${person.name}.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Toque no botão "+ Nova Observação" para registrar circunstâncias familiares, pontos de interesse ou dúvidas bíblicas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentTeal,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('+ Registrar Primeira Observação'),
                        onPressed: () => _showAddOrEditNoteDialog(context, repo, person),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Column(
              children: notes.map((note) {
                final createdAt = DateTime.tryParse(note['createdAt'] ?? '');
                final updatedAt = note['updatedAt'] != null ? DateTime.tryParse(note['updatedAt']) : null;
                final text = note['text'] ?? '';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 14, color: AppTheme.accentTeal),
                                const SizedBox(width: 6),
                                Text(
                                  AppDateUtils.formatDateTimeWithAt(createdAt),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.accentTeal),
                                ),
                                if (updatedAt != null) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '(editado)',
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  tooltip: 'Editar',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _showAddOrEditNoteDialog(context, repo, person, note),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.alertRed),
                                  tooltip: 'Excluir',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        title: const Text('Excluir Observação'),
                                        content: const Text('Tem certeza que deseja excluir esta anotação?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.alertRed, foregroundColor: Colors.white),
                                            onPressed: () => Navigator.pop(c, true),
                                            child: const Text('Excluir'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      final updated = notes.where((n) => n['id'] != note['id']).toList();
                                      await _saveNotes(repo, person, updated);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 12),
                        SelectableText(
                          text,
                          style: const TextStyle(fontSize: 14, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ABA 4: ALVOS & TAREFAS ESPIRITUAIS (Checkbox, Risco, Datas de Criação/Conclusão em JSON)
  // ---------------------------------------------------------------------------
  Widget _buildTargetsAndTasksTab(
    BuildContext context,
    AppRepository repo,
    PersonEntry person,
    bool isDark,
  ) {
    final targets = _parseTargets(person.contactRestrictions);
    final completedCount = targets.where((t) => t['isCompleted'] == true).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Alvos & Tarefas Espirituais',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '$completedCount de ${targets.length} concluído(s)',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add_task, size: 18),
                label: const Text('+ Novo Alvo'),
                onPressed: () => _showAddOrEditTargetDialog(context, repo, person),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (targets.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.track_changes, size: 56, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'Nenhum alvo ou tarefa espiritual definido para ${person.name}.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Defina alvos espirituais para a pessoa cumprir até a próxima visita (ex: ler um capítulo da Bíblia, baixar o JW Library, assistir ao vídeo da lição).',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('+ Cadastrar Primeiro Alvo'),
                        onPressed: () => _showAddOrEditTargetDialog(context, repo, person),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Column(
              children: targets.asMap().entries.map((entry) {
                final idx = entry.key;
                final target = entry.value;
                final isCompleted = target['isCompleted'] == true;
                final title = target['title'] ?? '';
                final createdAt = DateTime.tryParse(target['createdAt'] ?? '');
                final completedAt = target['completedAt'] != null ? DateTime.tryParse(target['completedAt']) : null;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final updated = List<Map<String, dynamic>>.from(targets);
                      final nextCompleted = !isCompleted;
                      updated[idx] = {
                        ...target,
                        'isCompleted': nextCompleted,
                        'completedAt': nextCompleted ? DateTime.now().toIso8601String() : null,
                      };
                      await _saveTargets(repo, person, updated);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: isCompleted,
                            activeColor: const Color(0xFF059669),
                            onChanged: (val) async {
                              final updated = List<Map<String, dynamic>>.from(targets);
                              final nextCompleted = val ?? false;
                              updated[idx] = {
                                ...target,
                                'isCompleted': nextCompleted,
                                'completedAt': nextCompleted ? DateTime.now().toIso8601String() : null,
                              };
                              await _saveTargets(repo, person, updated);
                            },
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                                      color: isCompleted ? (isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600) : null,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.schedule, size: 12, color: Colors.grey.shade500),
                                      const SizedBox(width: 4),
                                      Text(
                                        createdAt != null
                                            ? 'Criado em: ${AppDateUtils.formatDateTimeWithAt(createdAt)}'
                                            : 'Criado em: data não disponível',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                      ),
                                    ],
                                  ),
                                  if (isCompleted) ...[
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(Icons.check_circle, size: 12, color: Color(0xFF059669)),
                                        const SizedBox(width: 4),
                                        Text(
                                          completedAt != null
                                              ? 'Concluído em: ${AppDateUtils.formatDateTimeWithAt(completedAt)}'
                                              : 'Concluído (data não informada)',
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Editar',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _showAddOrEditTargetDialog(context, repo, person, target),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.alertRed),
                          tooltip: 'Excluir',
                          visualDensity: VisualDensity.compact,
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text('Excluir Alvo'),
                                content: const Text('Tem certeza que deseja excluir este alvo espiritual?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.alertRed, foregroundColor: Colors.white),
                                    onPressed: () => Navigator.pop(c, true),
                                    child: const Text('Excluir'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              final updated = targets.where((t) => t['id'] != target['id']).toList();
                              await _saveTargets(repo, person, updated);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
            ),
        ],
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
        final isEnded = other.status == 'revisita_encerrada' || other.status == 'encerrado';
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.accentTeal),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${nearby.length} contato(s)',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accentTeal),
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
                      MaterialPageRoute(builder: (_) => PersonDetailScreen(personId: c.id)),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          item.isEnded ? Icons.replay_outlined : Icons.location_on,
                          size: 16,
                          color: item.isEnded ? Colors.orange : AppTheme.primaryBlue,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              if (c.address != null && c.address!.isNotEmpty)
                                Text(c.address!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                            ],
                          ),
                        ),
                        if (item.isEnded)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Reativar?', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                          ),
                        Text('~${distMeters}m', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accentTeal)),
                        const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
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

  Widget _buildSpiritualTimelineCard(
    BuildContext context,
    PersonEntry person,
    BibleStudyEntry study,
    AppRepository repo,
    bool isDark,
  ) {
    final List<String> completedGoals = [];
    if (person.contactRestrictions != null && person.contactRestrictions!.isNotEmpty) {
      try {
        final decoded = jsonDecode(person.contactRestrictions!);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map && item['isCompleted'] == true && item['title'] != null) {
              completedGoals.add(item['title'].toString());
            }
          }
        }
      } catch (_) {}
    }

    final currentLesson = study.currentLesson ?? 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.timeline, color: Color(0xFFD97706), size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Linha do Tempo Espiritual do Estudante',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 14),

            _TimelineStep(
              icon: Icons.person_add_outlined,
              iconColor: AppTheme.primaryBlue,
              title: 'Primeiro Contato Registrado',
              date: AppDateUtils.formatDate(person.createdAt),
              subtitle: 'Início das conversas no ministério de campo',
              isCompleted: true,
            ),

            _TimelineStep(
              icon: Icons.menu_book,
              iconColor: currentLesson >= 1 ? const Color(0xFF0284C7) : Colors.grey,
              title: 'Brochura Inicial (Lições 01 a 03)',
              date: currentLesson > 3
                  ? 'Concluída'
                  : (currentLesson >= 1 ? 'Em andamento (Lição $currentLesson)' : 'Início'),
              subtitle: 'Brochura "Seja Feliz para Sempre!": 3 lições introdutórias da Bíblia',
              isCompleted: currentLesson >= 3,
            ),

            _TimelineStep(
              icon: Icons.handshake_outlined,
              iconColor: currentLesson >= 4 ? AppTheme.successGreen : (currentLesson == 3 ? AppTheme.alertAmber : Colors.grey),
              title: 'Aceitou Continuar com o Livro Completo',
              date: currentLesson >= 4
                  ? 'Recebeu o livro (Lição 4+)'
                  : (currentLesson == 3 ? 'Consideração da Lição 3' : 'Pendente'),
              subtitle: currentLesson >= 4
                  ? 'Estudante aceitou o curso completo e recebeu o livro "Seja Feliz para Sempre!"'
                  : 'No final da lição 3: Consideração sobre continuar no livro a partir da Lição 4',
              isCompleted: currentLesson >= 4,
            ),

            _TimelineStep(
              icon: Icons.auto_stories,
              iconColor: const Color(0xFF7C3AED),
              title: 'Curso Completo no Livro',
              date: currentLesson >= 4 ? 'Em andamento' : 'Aguardando Lição 4',
              subtitle: 'Publicação: Livro "Seja Feliz para Sempre!" (60 lições)',
              isCompleted: currentLesson >= 4,
            ),

            _TimelineStep(
              icon: Icons.military_tech_outlined,
              iconColor: currentLesson >= 12 ? AppTheme.successGreen : Colors.grey,
              title: 'Marco 1: Conclusão da Seção 1 (Lições 01 a 12)',
              date: currentLesson >= 12 ? 'Concluída' : 'Em andamento',
              subtitle: 'Fundamentos da Bíblia e aproximação de Deus',
              isCompleted: currentLesson >= 12,
            ),

            _TimelineStep(
              icon: Icons.verified_outlined,
              iconColor: currentLesson >= 33 ? AppTheme.successGreen : Colors.grey,
              title: 'Marco 2: Conclusão da Seção 2 (Lições 13 a 33)',
              date: currentLesson >= 33 ? 'Concluída' : (currentLesson >= 12 ? 'Em andamento' : 'Pendente'),
              subtitle: 'O Reino de Deus e a vida de Jesus Cristo',
              isCompleted: currentLesson >= 33,
            ),

            _TimelineStep(
              icon: Icons.shield_outlined,
              iconColor: currentLesson >= 47 ? AppTheme.successGreen : Colors.grey,
              title: 'Marco 3: Conclusão da Seção 3 (Lições 34 a 47)',
              date: currentLesson >= 47 ? 'Concluída' : (currentLesson >= 33 ? 'Em andamento' : 'Pendente'),
              subtitle: 'Aplicação das leis divinas, conduta moral e dedicação a Deus',
              isCompleted: currentLesson >= 47,
            ),

            _TimelineStep(
              icon: Icons.flag_outlined,
              iconColor: currentLesson >= 60 ? AppTheme.successGreen : Colors.grey,
              title: 'Marco 4: Conclusão da Seção 4 (Lições 48 a 60)',
              date: currentLesson >= 60 ? 'Concluída' : (currentLesson >= 47 ? 'Em andamento' : 'Pendente'),
              subtitle: 'Amizades, congregação, perseverança e amizade eterna com Jeová',
              isCompleted: currentLesson >= 60,
            ),

            if (completedGoals.isNotEmpty)
              for (final goal in completedGoals)
                _TimelineStep(
                  icon: Icons.check_circle,
                  iconColor: AppTheme.successGreen,
                  title: 'Alvo Espiritual Cumprido',
                  date: 'Alcançado',
                  subtitle: goal,
                  isCompleted: true,
                ),

            _TimelineStep(
              icon: Icons.workspace_premium,
              iconColor: currentLesson >= 60 ? AppTheme.successGreen : Colors.grey,
              title: 'Alvo Final: Conclusão do Livro "Seja Feliz Para Sempre!"',
              date: currentLesson >= 60 ? '🎉 Livro Concluído!' : 'Alvo Final',
              subtitle: 'Preparo espiritual completo para continuar crescendo na fé',
              isCompleted: currentLesson >= 60,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String date;
  final String subtitle;
  final bool isCompleted;
  final bool isLast;

  const _TimelineStep({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.date,
    required this.subtitle,
    required this.isCompleted,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: iconColor, width: 1.5),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted ? iconColor.withValues(alpha: 0.4) : Colors.grey.shade300,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isCompleted ? null : Colors.grey,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isCompleted ? iconColor.withValues(alpha: 0.1) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          date,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isCompleted ? iconColor : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _MetricSmallCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricSmallCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                Text(
                  value,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

