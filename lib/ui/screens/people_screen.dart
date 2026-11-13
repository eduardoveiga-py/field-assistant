import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_logger.dart';
import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../database/app_database.dart';
import '../providers.dart';
import 'person_detail_screen.dart';
import 'contacts_map_screen.dart';
import '../../territory/sector_manager.dart';
import '../../reports/report_export_service.dart';
import '../../media/person_photos_manager.dart';
import '../../media/media_picker_helper.dart';
import '../../contacts/recent_seeds_helper.dart';
import '../widgets/recent_seed_badge.dart';
import '../widgets/screen_hero_accent_band.dart';
import '../widgets/add_person_dialog.dart';
import '../widgets/managed_text_controllers.dart';

export '../widgets/add_person_dialog.dart';

class PeopleScreen extends ConsumerStatefulWidget {
  final String? initialFilter;
  const PeopleScreen({super.key, this.initialFilter});

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  final TextEditingController _searchController = TextEditingController();
  late String _selectedFilter;
  String? _selectedTag;
  List<BibleStudyEntry>? _lastStudiesRef;
  List<StudyParticipantEntry>? _lastParticipantsRef;
  Map<String, List<BibleStudyEntry>> _cachedPersonStudies = const {};

  Map<String, List<BibleStudyEntry>> _getPersonStudiesMap(
    List<BibleStudyEntry> allStudies,
    List<StudyParticipantEntry> allParticipants,
  ) {
    if (identical(_lastStudiesRef, allStudies) &&
        identical(_lastParticipantsRef, allParticipants)) {
      return _cachedPersonStudies;
    }
    final studiesById = {
      for (final s in allStudies)
        if (s.deletedAt == null) s.id: s,
    };
    final map = <String, List<BibleStudyEntry>>{};
    for (final part in allParticipants) {
      final study = studiesById[part.studyId];
      if (study != null) {
        map.putIfAbsent(part.personId, () => []).add(study);
      }
    }
    _lastStudiesRef = allStudies;
    _lastParticipantsRef = allParticipants;
    _cachedPersonStudies = map;
    return map;
  }

  @override
  void initState() {
    super.initState();
    final provFilter = ref.read(peopleFilterProvider);
    _selectedFilter = widget.initialFilter ?? provFilter;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showEditTagsDialog(BuildContext context, PersonEntry person) {
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
          AppLogger.debug('Tags não-JSON em ${person.id}: $e', st);
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
                                labelText: 'Nova Etiqueta',
                                hintText: 'Ex: Jovem, Idoso, Espanhol, Cartas',
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
                              size: 28,
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
                          'Nenhuma etiqueta cadastrada.',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        )
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: currentTags.map((t) {
                            return Chip(
                              label: Text(t),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () {
                                setDialogState(() {
                                  currentTags.remove(t);
                                });
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
                      final repo = ref.read(repositoryProvider);
                      await repo.updatePerson(
                        person.copyWith(tags: jsonEncode(currentTags)),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Etiquetas atualizadas com sucesso!'),
                          ),
                        );
                      }
                    },
                    child: const Text('Salvar'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showAddPersonDialog(BuildContext context) {
    showAddPersonDialog(context, ref);
  }

  void _showExportContactsDialog(
    BuildContext context,
    List<PersonEntry> allPeople,
  ) {
    String selectedStatus = 'Todos';
    String selectedSector = 'Todos';
    bool onlyWithPhone = true;

    final sectors = ref.read(sectorsStreamProvider).value ?? [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final filtered = allPeople.where((p) {
            if (p.deletedAt != null) return false;
            if (onlyWithPhone && (p.phone == null || p.phone!.trim().isEmpty)) {
              return false;
            }
            if (selectedStatus != 'Todos') {
              if (selectedStatus == 'Interessados' &&
                  p.status != 'interessado') {
                return false;
              }
              if (selectedStatus == 'Revisitas' && p.status != 'revisita') {
                return false;
              }
              if (selectedStatus == 'Estudos' && p.status != 'estudo') {
                return false;
              }
            }
            if (selectedSector != 'Todos') {
              final addr = (p.address ?? '').toLowerCase();
              final secLower = selectedSector.toLowerCase();
              if (!addr.contains(secLower)) return false;
            }
            return true;
          }).toList();

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.phone_forwarded, color: AppTheme.primaryBlue),
                SizedBox(width: 8),
                Expanded(child: Text('Exportar para Trabalho por Telefone')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Exporte listas formatadas com telefones em destaque para o trabalho de testemunho por telefone ou controle pessoal no Excel e PDF.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Filtrar por Situação',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Todos',
                        child: Text('Todos os Contatos'),
                      ),
                      DropdownMenuItem(
                        value: 'Interessados',
                        child: Text('🌱 Apenas Interessados'),
                      ),
                      DropdownMenuItem(
                        value: 'Revisitas',
                        child: Text('🔄 Apenas Revisitas'),
                      ),
                      DropdownMenuItem(
                        value: 'Estudos',
                        child: Text('📖 Apenas Estudos Bíblicos'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedStatus = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedSector,
                    decoration: const InputDecoration(
                      labelText: 'Filtrar por Bairro / Setor',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'Todos',
                        child: Text('Todos os Bairros'),
                      ),
                      ...sectors.map(
                        (s) => DropdownMenuItem(
                          value: s.name,
                          child: Text(s.name),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedSector = val);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Apenas contatos com telefone cadastrado',
                      style: TextStyle(fontSize: 13),
                    ),
                    value: onlyWithPhone,
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => onlyWithPhone = val);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.people,
                          size: 18,
                          color: AppTheme.primaryBlue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${filtered.length} contato(s) selecionado(s)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.primaryBlue,
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
              OutlinedButton.icon(
                icon: const Icon(Icons.table_view, size: 16),
                label: const Text('Excel (.csv)'),
                onPressed: filtered.isEmpty
                    ? null
                    : () {
                        final csv = ReportExportService.generateCsvForContacts(
                          filtered,
                        );
                        ReportExportService.downloadCsv(
                          'contatos_telefone.csv',
                          csv,
                        );
                        Clipboard.setData(ClipboardData(text: csv));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Arquivo .csv baixado e copiado para a área de transferência!',
                            ),
                          ),
                        );
                      },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf, size: 16),
                label: const Text('Exportar PDF'),
                onPressed: filtered.isEmpty
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        await ReportExportService.exportPhoneWitnessingPdf(
                          context: context,
                          contacts: filtered,
                          filterStatus: selectedStatus,
                          filterNeighborhood: selectedSector,
                        );
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _makePhoneCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/55$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openMapRoute(String address, double? lat, double? lng) async {
    final query = (lat != null && lng != null)
        ? '$lat,$lng'
        : Uri.encodeComponent(address);
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final peopleAsync = ref.watch(peopleStreamProvider);
    final allStudies = ref.watch(studiesStreamProvider).value ?? [];
    final allParticipants =
        ref.watch(studyParticipantsStreamProvider).value ?? [];
    final allVisits = ref.watch(visitsStreamProvider).value ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen<String>(peopleFilterProvider, (previous, next) {
      if (next != _selectedFilter && mounted) {
        setState(() => _selectedFilter = next);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pessoas e Contatos'),
        bottom: ScreenHeroAccentBand.people(),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_forwarded),
            tooltip: 'Exportar Lista Telefônica (Excel e PDF)',
            onPressed: () =>
                _showExportContactsDialog(context, peopleAsync.value ?? []),
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Abrir Mapa dos Contatos',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ContactsMapScreen()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Novo Contato'),
        onPressed: () => _showAddPersonDialog(context),
      ),
      body: Column(
        children: [
          // Banner de atalho para o mapa de contatos
          Container(
            color: isDark
                ? AppTheme.primaryBlue.withValues(alpha: 0.18)
                : AppTheme.primaryBlue.withValues(alpha: 0.06),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on,
                  size: 18,
                  color: AppTheme.primaryBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Visualize todos os contatos no mapa do território',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFF93C5FD)
                          : AppTheme.primaryBlue,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.map, size: 16),
                  label: const Text(
                    'Abrir Mapa',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ContactsMapScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Barra de busca global aprimorada
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nome, telefone, endereço, notas ou dia do estudo...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // Filtros por situação e etiquetas
          peopleAsync.when(
            data: (allPeople) {
              final allTags = <String>{};
              for (final p in allPeople) {
                if (p.tags.isNotEmpty && p.tags != '[]') {
                  if (p.tags.startsWith('[')) {
                    try {
                      final decoded = jsonDecode(p.tags) as List;
                      for (final t in decoded) {
                        final s = t.toString().trim();
                        if (s.isNotEmpty) allTags.add(s);
                      }
                    } catch (e, st) {
                      AppLogger.debug('Falha ao ler tags JSON de filtro (${p.id}): $e', st);
                    }
                  } else {
                    for (final part in p.tags.split(',')) {
                      final s = part.trim();
                      if (s.isNotEmpty) allTags.add(s);
                    }
                  }
                }
              }

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    ...[
                      'Todos',
                      'Sementes Recentes',
                      'Interessados',
                      'Revisitas',
                      'Estudos',
                      'Passadas',
                      'Encerradas',
                    ].map((filter) {
                      final isSelected = _selectedFilter == filter;
                      final isSeeds = filter == 'Sementes Recentes';
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          avatar: isSeeds
                              ? Icon(
                                  Icons.eco,
                                  size: 16,
                                  color: isSelected
                                      ? (isDark
                                            ? const Color(0xFFA7F3D0)
                                            : const Color(0xFF14532D))
                                      : (isDark
                                            ? const Color(0xFF34D399)
                                            : const Color(0xFF16A34A)),
                                )
                              : null,
                          label: Text(filter),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() => _selectedFilter = filter);
                            ref.read(peopleFilterProvider.notifier).state = filter;
                          },
                          selectedColor: isSeeds
                              ? (isDark
                                    ? const Color(0xFF064E3B)
                                          .withValues(alpha: 0.45)
                                    : const Color(0xFFDCFCE7))
                              : AppTheme.primaryBlue.withValues(alpha: 0.15),
                          checkmarkColor: isSeeds
                              ? (isDark
                                    ? const Color(0xFFA7F3D0)
                                    : const Color(0xFF14532D))
                              : AppTheme.primaryBlue,
                        ),
                      );
                    }),
                    if (allTags.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Container(
                        width: 1,
                        height: 24,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(width: 8),
                      ...allTags.map((tag) {
                        final isTagSelected = _selectedTag == tag;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            avatar: const Icon(Icons.label, size: 14),
                            label: Text(tag),
                            selected: isTagSelected,
                            onSelected: (selected) {
                              setState(
                                () => _selectedTag = selected ? tag : null,
                              );
                            },
                            selectedColor: const Color(0xFF0284C7)
                                .withValues(alpha: 0.18),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (err, stack) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),

          // Lista de Pessoas
          Expanded(
            child: peopleAsync.when(
              data: (people) {
                final query = _searchController.text.trim().toLowerCase();

                // Mapeia personId -> lista de estudos vinculados (memoizado O(P + S))
                final personStudies = _getPersonStudiesMap(
                  allStudies,
                  allParticipants,
                );

                var filtered = people.where((p) {
                  final linkedStudies =
                      personStudies[p.id] ?? <BibleStudyEntry>[];
                  final matchesStudy = linkedStudies.any((s) {
                    final titleMatches = s.title.toLowerCase().contains(query);
                    final pubMatches = s.publicationId.toLowerCase().contains(
                      query,
                    );
                    final lessonMatches =
                        s.currentLesson != null &&
                        'lição ${s.currentLesson}'.contains(query);
                    final paraMatches =
                        s.currentParagraph != null &&
                        'parágrafo ${s.currentParagraph}'.contains(query);
                    return titleMatches ||
                        pubMatches ||
                        lessonMatches ||
                        paraMatches;
                  });

                  // Filtro por texto global (nome, telefone, endereço, notas, alvos, tarefas, dia do estudo ou lição)
                  final matchesQuery =
                      query.isEmpty ||
                      p.name.toLowerCase().contains(query) ||
                      (p.phone ?? '').toLowerCase().contains(query) ||
                      (p.address ?? '').toLowerCase().contains(query) ||
                      (p.generalNotes ?? '').toLowerCase().contains(query) ||
                      (p.contactRestrictions ?? '').toLowerCase().contains(
                        query,
                      ) ||
                      (p.nextActionNote ?? '').toLowerCase().contains(query) ||
                      (p.preferredSchedule ?? '').toLowerCase().contains(
                        query,
                      ) ||
                      p.tags.toLowerCase().contains(query) ||
                      matchesStudy;

                  if (!matchesQuery) return false;

                  // Filtro por categoria
                  if (_selectedFilter == 'Todos') {
                    if (p.status == 'revisita_passada' ||
                        p.status == 'revisita_encerrada') {
                      return false;
                    }
                  } else if (_selectedFilter == 'Sementes Recentes') {
                    if (!RecentSeedsHelper.isRecentSeed(
                      person: p,
                      visits: allVisits,
                    )) {
                      return false;
                    }
                  } else if (_selectedFilter == 'Interessados') {
                    if (p.status != 'interessado') return false;
                  } else if (_selectedFilter == 'Revisitas') {
                    if (p.status != 'revisita') return false;
                  } else if (_selectedFilter == 'Estudos') {
                    if (p.status != 'estudo') return false;
                  } else if (_selectedFilter == 'Passadas') {
                    if (p.status != 'revisita_passada') return false;
                  } else if (_selectedFilter == 'Encerradas') {
                    if (p.status != 'revisita_encerrada') return false;
                  }

                  if (_selectedTag != null && _selectedTag!.isNotEmpty) {
                    if (!p.tags.toLowerCase().contains(
                      _selectedTag!.toLowerCase(),
                    )) {
                      return false;
                    }
                  }

                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 56,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            query.isEmpty
                                ? (_selectedFilter == 'Sementes Recentes'
                                      ? 'Nenhuma semente recente pendente de revisita no momento.'
                                      : 'Nenhum contato cadastrado ainda.\nToque em "+ Novo Contato" para começar.')
                                : 'Nenhum contato encontrado para "$query".',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark
                                  ? const Color(0xFFCBD5E1)
                                  : AppTheme.textMuted,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final person = filtered[index];
                    final color = _getStatusColor(person.status);
                    final allPhotos =
                        ref.watch(personPhotosStreamProvider).value ?? [];
                    final personPhoto = allPhotos
                        .where(
                          (p) =>
                              p.personId == person.id &&
                              p.photoType == 'person',
                        )
                        .firstOrNull;

                    Widget avatarWidget;
                    if (personPhoto != null &&
                        personPhoto.imageData.isNotEmpty) {
                      avatarWidget = ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: MediaPickerHelper.buildThumbnail(
                          personPhoto.imageData,
                          width: 42,
                          height: 42,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      );
                    } else {
                      avatarWidget = CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.12),
                        child: Text(
                          person.name.isNotEmpty
                              ? person.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      );
                    }

                    List<String> personTagList = [];
                    if (person.tags.isNotEmpty && person.tags != '[]') {
                      if (person.tags.startsWith('[')) {
                        try {
                          final decoded = jsonDecode(person.tags) as List;
                          personTagList = decoded
                              .map((e) => e.toString().trim())
                              .where((s) => s.isNotEmpty)
                              .toList();
                        } catch (e, st) {
                          AppLogger.debug('Falha ao ler tags JSON no card (${person.id}): $e', st);
                        }
                      } else {
                        personTagList = person.tags
                            .split(',')
                            .map((e) => e.trim())
                            .where((s) => s.isNotEmpty)
                            .toList();
                      }
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PersonDetailScreen(personId: person.id),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  avatarWidget,
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          person.name,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (person.phone != null &&
                                            person.phone!.isNotEmpty)
                                          Text(
                                            person.phone!,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isDark
                                                  ? const Color(0xFFCBD5E1)
                                                  : AppTheme.textMuted,
                                            ),
                                          ),
                                        if (RecentSeedsHelper.isRecentSeed(
                                          person: person,
                                          visits: allVisits,
                                        )) ...[
                                          const SizedBox(height: 4),
                                          RecentSeedBadge(
                                            firstContactAt:
                                                person.firstContactAt,
                                          ),
                                        ],
                                        if (personTagList.isNotEmpty ||
                                            person.status ==
                                                'revisita_passada') ...[
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              if (person.status ==
                                                  'revisita_passada')
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFFFEF3C7,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                    border: Border.all(
                                                      color: const Color(
                                                        0xFFF59E0B,
                                                      ),
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    'Revisita Passada',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Color(0xFF92400E),
                                                    ),
                                                  ),
                                                ),
                                              ...personTagList.map(
                                                (t) => InkWell(
                                                  onTap: () =>
                                                      _showEditTagsDialog(
                                                        context,
                                                        person,
                                                      ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: isDark
                                                          ? Colors.white10
                                                          : Colors
                                                                .grey
                                                                .shade200,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      '#$t',
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Semantics(
                                                button: true,
                                                label: 'Adicionar etiqueta',
                                                child: InkWell(
                                                  onTap: () =>
                                                      _showEditTagsDialog(
                                                        context,
                                                        person,
                                                      ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  child: ConstrainedBox(
                                                    constraints:
                                                        const BoxConstraints(
                                                          minWidth: 48,
                                                          minHeight: 48,
                                                        ),
                                                    child: Center(
                                                      widthFactor: 1.0,
                                                      heightFactor: 1.0,
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 7,
                                                              vertical: 3,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: isDark
                                                              ? AppTheme
                                                                    .primaryBlue
                                                                    .withValues(
                                                                      alpha:
                                                                          0.15,
                                                                    )
                                                              : AppTheme
                                                                    .primaryBlue
                                                                    .withValues(
                                                                      alpha:
                                                                          0.08,
                                                                    ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                          border: Border.all(
                                                            color: AppTheme
                                                                .primaryBlue
                                                                .withValues(
                                                                  alpha: 0.4,
                                                                ),
                                                            width: 0.8,
                                                          ),
                                                        ),
                                                        child: const Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              Icons.add,
                                                              size: 11,
                                                              color: AppTheme
                                                                  .primaryBlue,
                                                            ),
                                                            SizedBox(width: 3),
                                                            ExcludeSemantics(
                                                              child: Text(
                                                                'Tag',
                                                                style: TextStyle(
                                                                  fontSize: 10,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: AppTheme
                                                                      .primaryBlue,
                                                                ),
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
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    tooltip: 'Alterar situação com 1 toque',
                                    initialValue: person.status,
                                    onSelected: (newStatus) async {
                                      final repo = ref.read(repositoryProvider);
                                      await repo.updatePerson(
                                        person.copyWith(status: newStatus),
                                      );
                                      if (context.mounted) {
                                        final hasLinkedStudy =
                                            personStudies[person.id]
                                                ?.isNotEmpty ??
                                            false;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Situação de "${person.name}" alterada para ${_getStatusLabel(newStatus)}!',
                                            ),
                                            action:
                                                newStatus == 'estudo' &&
                                                    !hasLinkedStudy
                                                ? SnackBarAction(
                                                    label: 'Configurar Estudo',
                                                    textColor: const Color(
                                                      0xFFC4B5FD,
                                                    ),
                                                    onPressed: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              PersonDetailScreen(
                                                                personId:
                                                                    person.id,
                                                              ),
                                                        ),
                                                      );
                                                    },
                                                  )
                                                : null,
                                          ),
                                        );
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(
                                        value: 'interessado',
                                        child: Text('🌱 Interessado'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'revisita',
                                        child: Text('🔄 Revisita'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'estudo',
                                        child: Text('📖 Estudo Bíblico'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'revisita_passada',
                                        child: Text('📤 Revisita Passada'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'outro',
                                        child: Text('⚪ Outro'),
                                      ),
                                    ],
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minHeight: 48,
                                        minWidth: 48,
                                      ),
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: color.withValues(
                                              alpha: 0.15,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: color.withValues(
                                                alpha: 0.4,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                _getStatusLabel(person.status),
                                                style: TextStyle(
                                                  color: color,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(width: 2),
                                              Icon(
                                                Icons.arrow_drop_down,
                                                size: 14,
                                                color: color,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (person.address != null &&
                                  person.address!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 16,
                                      color: isDark
                                          ? const Color(0xFFCBD5E1)
                                          : AppTheme.textMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        person.address!,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark
                                              ? AppTheme.darkTextPrimary
                                              : AppTheme.textDark,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (person.preferredSchedule != null &&
                                  person.preferredSchedule!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.schedule,
                                      size: 16,
                                      color: AppTheme.accentTeal,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Horário: ${person.preferredSchedule!}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.accentTeal,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (personStudies[person.id]?.isNotEmpty ==
                                  true) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.school,
                                      size: 16,
                                      color: Color(0xFF7C3AED),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Estudo: ${personStudies[person.id]!.first.title} (${personStudies[person.id]!.first.currentLesson != null ? "Lição ${personStudies[person.id]!.first.currentLesson}" : "Iniciando"})',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF7C3AED),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ] else if (person.status == 'estudo') ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
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
                                    children: [
                                      const Icon(
                                        Icons.school_outlined,
                                        size: 16,
                                        color: Color(0xFF7C3AED),
                                      ),
                                      const SizedBox(width: 6),
                                      const Expanded(
                                        child: Text(
                                          'Estudo não vinculado',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF7C3AED),
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          foregroundColor: const Color(
                                            0xFF7C3AED,
                                          ),
                                        ),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  PersonDetailScreen(
                                                    personId: person.id,
                                                  ),
                                            ),
                                          );
                                        },
                                        child: Text(
                                          '+ Iniciar com ${person.name.split(" ").first}',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (person.nextActionAt != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF78350F)
                                              .withValues(alpha: 0.25)
                                        : Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.amber.shade700
                                          : Colors.amber.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.next_plan_outlined,
                                        size: 16,
                                        color: AppTheme.alertAmber,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Próxima ação: ${AppDateUtils.formatDate(person.nextActionAt)} — ${person.nextActionNote ?? "Sem anotação"}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? const Color(0xFFFDE68A)
                                                : const Color(0xFF92400E),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const Divider(height: 16),
                              // Ações rápidas de contato na lista
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (person.phone != null &&
                                      person.phone!.isNotEmpty) ...[
                                    IconButton(
                                      constraints: const BoxConstraints(
                                        minWidth: 48,
                                        minHeight: 48,
                                      ),
                                      icon: const Icon(
                                        Icons.phone,
                                        size: 20,
                                        color: AppTheme.primaryBlue,
                                      ),
                                      tooltip: 'Ligar',
                                      onPressed: () =>
                                          _makePhoneCall(person.phone!),
                                    ),
                                    IconButton(
                                      constraints: const BoxConstraints(
                                        minWidth: 48,
                                        minHeight: 48,
                                      ),
                                      icon: const Icon(
                                        Icons.chat,
                                        size: 20,
                                        color: Color(0xFF25D366),
                                      ),
                                      tooltip: 'WhatsApp',
                                      onPressed: () =>
                                          _openWhatsApp(person.phone!),
                                    ),
                                  ],
                                  if (person.address != null &&
                                      person.address!.isNotEmpty) ...[
                                    IconButton(
                                      constraints: const BoxConstraints(
                                        minWidth: 48,
                                        minHeight: 48,
                                      ),
                                      icon: const Icon(
                                        Icons.map_outlined,
                                        size: 20,
                                        color: AppTheme.primaryBlue,
                                      ),
                                      tooltip: 'Ver no Mapa do Território',
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
                                      constraints: const BoxConstraints(
                                        minWidth: 48,
                                        minHeight: 48,
                                      ),
                                      icon: const Icon(
                                        Icons.open_in_new,
                                        size: 20,
                                        color: AppTheme.accentTeal,
                                      ),
                                      tooltip: 'Abrir no Google Maps',
                                      onPressed: () => _openMapRoute(
                                        person.address!,
                                        person.latitude,
                                        person.longitude,
                                      ),
                                    ),
                                  ],
                                  IconButton(
                                    constraints: const BoxConstraints(
                                      minWidth: 48,
                                      minHeight: 48,
                                    ),
                                    icon: const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 14,
                                    ),
                                    tooltip: 'Acessar cadastro completo',
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PersonDetailScreen(
                                            personId: person.id,
                                          ),
                                        ),
                                      );
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
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Erro: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'estudo':
        return const Color(0xFF7C3AED);
      case 'revisita':
        return AppTheme.accentTeal;
      case 'revisita_passada':
        return const Color(0xFFD97706);
      case 'interessado':
      default:
        return AppTheme.primaryBlue;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'estudo':
        return 'Estudo Bíblico';
      case 'revisita':
        return 'Revisita';
      case 'revisita_passada':
        return 'Revisita Passada';
      case 'interessado':
      default:
        return 'Interessado';
    }
  }
}
