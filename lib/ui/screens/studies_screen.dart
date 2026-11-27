import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'knowledge_base_screen.dart';

import '../../appointments/availability_engine.dart';
import '../../appointments/schedule_release_coordinator.dart';
import '../../core/app_logger.dart';
import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../database/app_database.dart';
import '../../publications/publication_catalog.dart';
import '../../publications/publication_link_resolver.dart';
import '../../dashboard/counting_rules.dart';
import '../providers.dart';
import '../widgets/global_appointment_scheduling_section.dart';
import '../widgets/managed_text_controllers.dart';
import '../widgets/notion/notion_collection_views.dart';
import '../widgets/rich_formatted_editing_controller.dart';
import '../widgets/rich_markdown_toolbar.dart';
import '../../publications/lff_book_catalog.dart';
import '../../dashboard/student_priority_engine.dart';
import '../widgets/screen_hero_accent_band.dart';
import 'person_detail_screen.dart';
import '../../media/person_photos_manager.dart';
import '../../media/media_picker_helper.dart';
import '../widgets/studies/study_detail_pane.dart';

part 'studies/study_dialogs.dart';
part 'studies/study_priority_view.dart';

class StudiesScreen extends ConsumerStatefulWidget {
  const StudiesScreen({super.key});

  @override
  ConsumerState<StudiesScreen> createState() => _StudiesScreenState();
}

class _StudiesScreenState extends ConsumerState<StudiesScreen> {
  void _updateState(VoidCallback fn) => setState(fn);
  String _selectedStatusFilter =
      'Ativos'; // 'Ativos', 'Prioridade & Progresso', 'Encerrados'
  NotionViewMode _viewMode = NotionViewMode.list;
  final Map<String, int> _manualOrderMap = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedPubFilter;
  String? _selectedTagFilter;
  String? _selectedStudyId;
  final Set<String> _expandedStudyIds = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.trim().toLowerCase();
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final db = ref.read(repositoryProvider).db;
      final loaded = await StudentPriorityEngine.loadManualOrder(db);
      if (mounted && loaded.isNotEmpty) {
        setState(() {
          _manualOrderMap.addAll(loaded);
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studiesAsync = ref.watch(studiesStreamProvider);
    final participants = ref.watch(studyParticipantsStreamProvider).value ?? [];
    final people = ref.watch(peopleStreamProvider).value ?? [];
    final sessions = ref.watch(studySessionsStreamProvider).value ?? [];
    final appointments = ref.watch(appointmentsStreamProvider).value ?? [];
    final allPhotos = ref.watch(personPhotosStreamProvider).value ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Semantics(header: true, child: const Text('Estudos Bíblicos')),
        bottom: ScreenHeroAccentBand.studies(),
        actions: [
          Semantics(
            button: true,
            label: 'Abrir Base de Conhecimento e Recursos',
            child: IconButton(
              icon: const Icon(Icons.menu_book_rounded),
              tooltip: 'Base de Conhecimento & Recursos',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const KnowledgeBaseScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Semantics(
        button: true,
        container: true,
        excludeSemantics: true,
        label: 'Novo Estudo - Iniciar novo estudo bíblico',
        hint: 'Abre formulário para cadastrar estudo bíblico',
        child: FloatingActionButton.extended(
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Novo Estudo'),
          onPressed: () => _showNewStudyDialog(context),
        ),
      ),
      body: studiesAsync.when(
        data: (studies) {
          final activeStudies = studies
              .where((s) => s.status == 'ativo')
              .toList();
          final closedStudies = studies
              .where((s) => s.status != 'ativo')
              .toList();

          // Coleta de publicações e tags disponíveis
          final usedPubIds = studies
              .map((s) => s.publicationId)
              .toSet()
              .toList();
          final Set<String> allAvailableTags = {};
          for (final s in studies) {
            if (s.learningGoals != null && s.learningGoals!.trim().isNotEmpty) {
              for (final raw in s.learningGoals!.split(RegExp(r'[,;]'))) {
                final clean = raw.trim();
                if (clean.isNotEmpty && clean.length <= 30) {
                  allAvailableTags.add(clean);
                }
              }
            }
          }
          for (final p in people) {
            if (p.tags.isNotEmpty) {
              try {
                final tList = (jsonDecode(p.tags) as List).cast<String>();
                allAvailableTags.addAll(
                  tList
                      .map((t) => t.trim())
                      .where((t) => t.isNotEmpty && t.length <= 30),
                );
              } catch (e, st) {
                AppLogger.debug(
                  'Falha ao ler tags JSON (${p.id}) no filtro de estudos: $e',
                  st,
                );
              }
            }
          }

          bool matchesBaseFilters(BibleStudyEntry s) {
            if (_selectedPubFilter != null &&
                s.publicationId != _selectedPubFilter) {
              return false;
            }

            if (_selectedTagFilter != null) {
              bool matchesTag = false;
              if (s.learningGoals != null &&
                  s.learningGoals!.toLowerCase().contains(
                    _selectedTagFilter!.toLowerCase(),
                  )) {
                matchesTag = true;
              }
              if (!matchesTag) {
                final parts = participants.where((p) => p.studyId == s.id);
                for (final part in parts) {
                  final person = people.firstWhereOrNull(
                    (p) => p.id == part.personId,
                  );
                  if (person != null && person.tags.isNotEmpty) {
                    try {
                      final tList = (jsonDecode(person.tags) as List)
                          .cast<String>();
                      if (tList.any(
                        (t) =>
                            t.trim().toLowerCase() ==
                            _selectedTagFilter!.toLowerCase(),
                      )) {
                        matchesTag = true;
                        break;
                      }
                    } catch (e, st) {
                      AppLogger.debug(
                        'Falha ao filtrar tag JSON (${person.id}) em estudos: $e',
                        st,
                      );
                    }
                  }
                }
              }
              if (!matchesTag) return false;
            }

            if (_searchQuery.isNotEmpty) {
              final pub = PublicationCatalog.getById(s.publicationId);
              final pubTitle = pub?.title.toLowerCase() ?? '';
              final titleMatch = s.title.toLowerCase().contains(_searchQuery);
              final pubMatch =
                  pubTitle.contains(_searchQuery) ||
                  s.publicationId.toLowerCase().contains(_searchQuery);
              final goalsMatch =
                  s.learningGoals?.toLowerCase().contains(_searchQuery) ??
                  false;
              final notesMatch =
                  s.manualReference?.toLowerCase().contains(_searchQuery) ??
                  false;

              final studyParts = participants.where((p) => p.studyId == s.id);
              final studentMatch = studyParts.any((part) {
                final person = people.firstWhereOrNull(
                  (p) => p.id == part.personId,
                );
                return person != null &&
                    person.name.toLowerCase().contains(_searchQuery);
              });

              if (!titleMatch &&
                  !pubMatch &&
                  !goalsMatch &&
                  !notesMatch &&
                  !studentMatch) {
                return false;
              }
            }

            return true;
          }

          final baseFiltered = studies.where(matchesBaseFilters).toList();
          final filtered = baseFiltered.where((s) {
            if (_selectedStatusFilter == 'Ativos' ||
                _selectedStatusFilter == 'Prioridade & Progresso') {
              return s.status == 'ativo';
            } else if (_selectedStatusFilter == 'Encerrados') {
              return s.status != 'ativo';
            }
            return true;
          }).toList();

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final selectedStudy = _selectedStudyId != null
                  ? filtered.firstWhereOrNull((s) => s.id == _selectedStudyId)
                  : null;
              final masterPane = Column(
                children: [
                  // Barra de Pesquisa
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Pesquisar estudante, publicação ou tags...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  // Chips de Status Principal
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: Text('Ativos (${activeStudies.length})'),
                            selected: _selectedStatusFilter == 'Ativos',
                            onSelected: (val) {
                              if (val) {
                                setState(
                                  () => _selectedStatusFilter = 'Ativos',
                                );
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text(
                              'Prioridade & Progresso (${activeStudies.length})',
                            ),
                            selected:
                                _selectedStatusFilter ==
                                'Prioridade & Progresso',
                            onSelected: (val) {
                              if (val) {
                                setState(
                                  () => _selectedStatusFilter =
                                      'Prioridade & Progresso',
                                );
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text(
                              'Encerrados / Concluídos (${closedStudies.length})',
                            ),
                            selected: _selectedStatusFilter == 'Encerrados',
                            onSelected: (val) {
                              if (val) {
                                setState(
                                  () => _selectedStatusFilter = 'Encerrados',
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Filtros Secundários de Publicações e Tags
                  if (usedPubIds.length > 1 || allAvailableTags.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            if (usedPubIds.length > 1) ...[
                              FilterChip(
                                label: const Text(
                                  'Todas as Publicações',
                                  style: TextStyle(fontSize: 11),
                                ),
                                selected: _selectedPubFilter == null,
                                onSelected: (_) =>
                                    setState(() => _selectedPubFilter = null),
                              ),
                              const SizedBox(width: 6),
                              ...usedPubIds.map((pubId) {
                                final pub = PublicationCatalog.getById(pubId);
                                final title = pub?.title ?? pubId;
                                final shortTitle = title.length > 22
                                    ? '${title.substring(0, 20)}...'
                                    : title;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: FilterChip(
                                    label: Text(
                                      shortTitle,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    selected: _selectedPubFilter == pubId,
                                    onSelected: (val) => setState(
                                      () => _selectedPubFilter = val
                                          ? pubId
                                          : null,
                                    ),
                                  ),
                                );
                              }),
                              const SizedBox(width: 8),
                            ],
                            if (allAvailableTags.isNotEmpty) ...[
                              FilterChip(
                                avatar: const Icon(
                                  Icons.label_outline,
                                  size: 14,
                                ),
                                label: const Text(
                                  'Todas as Tags',
                                  style: TextStyle(fontSize: 11),
                                ),
                                selected: _selectedTagFilter == null,
                                onSelected: (_) =>
                                    setState(() => _selectedTagFilter = null),
                              ),
                              const SizedBox(width: 6),
                              ...allAvailableTags.map(
                                (tag) => Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: FilterChip(
                                    label: Text(
                                      '#$tag',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    selected: _selectedTagFilter == tag,
                                    onSelected: (val) => setState(
                                      () =>
                                          _selectedTagFilter = val ? tag : null,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                  // Barra de contagem e botão para recolher/expandir todos os cards
                  if (filtered.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${filtered.length} estudo(s) encontrado(s)',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: Icon(
                              _expandedStudyIds.length >= filtered.length
                                  ? Icons.unfold_less
                                  : Icons.unfold_more,
                              size: 16,
                            ),
                            label: Text(
                              _expandedStudyIds.length >= filtered.length
                                  ? 'Recolher Todos'
                                  : 'Expandir Todos',
                              style: const TextStyle(fontSize: 12),
                            ),
                            onPressed: () {
                              setState(() {
                                if (_expandedStudyIds.length >=
                                    filtered.length) {
                                  _expandedStudyIds.clear();
                                } else {
                                  _expandedStudyIds.addAll(
                                    filtered.map((s) => s.id),
                                  );
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                  const Divider(height: 1),
                  if (_selectedStatusFilter != 'Prioridade & Progresso')
                    NotionViewModeBar(
                      mode: _viewMode,
                      availableModes: const [
                        NotionViewMode.list,
                        NotionViewMode.table,
                        NotionViewMode.kanban,
                        NotionViewMode.gallery,
                      ],
                      onChanged: (m) => setState(() => _viewMode = m),
                      isDark: isDark,
                      keyPrefix: 'studies_view',
                    ),
                  Expanded(
                    child: _selectedStatusFilter == 'Prioridade & Progresso'
                        ? _buildPriorityAndProgressView(
                            activeStudies: filtered,
                            participants: participants,
                            people: people,
                            sessions: sessions,
                            appointments: appointments,
                            allPhotos: allPhotos,
                            isDark: isDark,
                          )
                        : (filtered.isEmpty &&
                              _viewMode != NotionViewMode.kanban)
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.menu_book,
                                    size: 56,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _searchQuery.isNotEmpty ||
                                            _selectedPubFilter != null ||
                                            _selectedTagFilter != null
                                        ? 'Nenhum estudo corresponde aos filtros ou pesquisa.'
                                        : (_selectedStatusFilter == 'Ativos'
                                              ? 'Nenhum estudo bíblico ativo no momento.\nToque em "+ Novo Estudo" para registrar.'
                                              : 'Nenhum estudo encerrado ou concluído.'),
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
                          )
                        : _viewMode == NotionViewMode.table
                        ? NotionResponsiveTable(
                            isDark: isDark,
                            columns: const [
                              NotionTableColumnDef(
                                label: 'Estudo / Estudante',
                                width: 240,
                              ),
                              NotionTableColumnDef(
                                label: 'Publicação',
                                width: 190,
                              ),
                              NotionTableColumnDef(
                                label: 'Progresso',
                                width: 110,
                              ),
                              NotionTableColumnDef(
                                label: 'Situação',
                                width: 110,
                              ),
                            ],
                            rows: [
                              for (final study in filtered)
                                NotionTableRowItem(
                                  onTap: () =>
                                      _showEditStudyDialog(context, study),
                                  cells: [
                                    Text(
                                      study.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      PublicationCatalog.getById(
                                            study.publicationId,
                                          )?.title ??
                                          study.publicationId,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      study.currentLesson != null
                                          ? 'Lição ${study.currentLesson}${study.currentParagraph != null ? ' • § ${study.currentParagraph}' : ''}'
                                          : 'Inicial',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      study.status.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: study.status == 'ativo'
                                            ? AppTheme.successGreen
                                            : AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          )
                        : _viewMode == NotionViewMode.kanban
                        ? NotionKanbanBoard<BibleStudyEntry>(
                            isDark: isDark,
                            keyPrefix: 'studies_kanban',
                            columns: const [
                              NotionKanbanColumnSpec(
                                statusKey: 'ativo',
                                label: 'Ativo',
                                accentColor: AppTheme.successGreen,
                              ),
                              NotionKanbanColumnSpec(
                                statusKey: 'pausado',
                                label: 'Pausado',
                                accentColor: Color(0xFFF59E0B),
                              ),
                              NotionKanbanColumnSpec(
                                statusKey: 'concluido',
                                label: 'Concluído',
                                accentColor: AppTheme.primaryBlue,
                              ),
                              NotionKanbanColumnSpec(
                                statusKey: 'encerrado',
                                label: 'Encerrado',
                                accentColor: Colors.grey,
                              ),
                            ],
                            itemsByColumn: {
                              'ativo': baseFiltered
                                  .where((s) => s.status == 'ativo')
                                  .toList(),
                              'pausado': baseFiltered
                                  .where((s) => s.status == 'pausado')
                                  .toList(),
                              'concluido': baseFiltered
                                  .where((s) => s.status == 'concluido')
                                  .toList(),
                              'encerrado': baseFiltered
                                  .where(
                                    (s) =>
                                        s.status != 'ativo' &&
                                        s.status != 'pausado' &&
                                        s.status != 'concluido',
                                  )
                                  .toList(),
                            },
                            itemId: (s) => s.id,
                            onMoveToColumn: (study, targetCol) async {
                              if (targetCol == 'encerrado') {
                                _showEndStudyDialog(context, study);
                                return;
                              }
                              if (targetCol == 'ativo') {
                                await _reactivateStudy(context, study);
                                return;
                              }
                              final repo = ref.read(repositoryProvider);
                              await repo.updateStudy(
                                study.copyWith(status: targetCol),
                              );
                            },
                            cardBuilder:
                                (
                                  ctx,
                                  study,
                                  colKey, {
                                  required bool isFeedback,
                                }) {
                                  final pubTitle =
                                      PublicationCatalog.getById(
                                        study.publicationId,
                                      )?.title ??
                                      study.publicationId;
                                  return Card(
                                    elevation: isFeedback ? 8 : 0,
                                    margin: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: isFeedback
                                            ? AppTheme.primaryBlue
                                            : (isDark
                                                  ? Colors.white.withValues(
                                                      alpha: 0.08,
                                                    )
                                                  : const Color(0xFFE2E8F0)),
                                      ),
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: isFeedback
                                          ? null
                                          : () => _showEditStudyDialog(
                                              context,
                                              study,
                                            ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              study.title,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13.5,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '📖 $pubTitle',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.primaryBlue,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              study.currentLesson != null
                                                  ? 'Lição ${study.currentLesson}${study.currentParagraph != null ? ' • § ${study.currentParagraph}' : ''}'
                                                  : 'Não iniciada',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark
                                                    ? const Color(0xFF94A3B8)
                                                    : AppTheme.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                          )
                        : _viewMode == NotionViewMode.gallery
                        ? NotionGalleryGrid<BibleStudyEntry>(
                            items: filtered,
                            itemBuilder: (ctx, study) {
                              final pubTitle =
                                  PublicationCatalog.getById(
                                    study.publicationId,
                                  )?.title ??
                                  study.publicationId;
                              final isActive = study.status == 'ativo';
                              final accent = isActive
                                  ? AppTheme.successGreen
                                  : AppTheme.primaryBlue;
                              return Card(
                                margin: EdgeInsets.zero,
                                clipBehavior: Clip.antiAlias,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: InkWell(
                                  onTap: () =>
                                      _showEditStudyDialog(context, study),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Container(
                                        height: 44,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              accent.withValues(
                                                alpha: isDark ? 0.35 : 0.2,
                                              ),
                                              accent.withValues(
                                                alpha: isDark ? 0.12 : 0.06,
                                              ),
                                            ],
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.menu_book_rounded,
                                              size: 16,
                                              color: accent,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                study.status.toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: accent,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              study.currentLesson != null
                                                  ? 'Lição ${study.currentLesson}'
                                                  : 'Inicial',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                study.title,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Expanded(
                                                child: Text(
                                                  pubTitle,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isDark
                                                        ? const Color(
                                                            0xFF94A3B8,
                                                          )
                                                        : AppTheme.textMuted,
                                                  ),
                                                ),
                                              ),
                                              if (study.learningGoals != null &&
                                                  study.learningGoals!
                                                      .trim()
                                                      .isNotEmpty)
                                                Text(
                                                  study.learningGoals!,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: accent,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final study = filtered[index];
                              final pub = PublicationCatalog.getById(
                                study.publicationId,
                              );

                              String? endReason;
                              if (study.pauseOrCloseReason != null &&
                                  study.pauseOrCloseReason!.isNotEmpty) {
                                try {
                                  final d = jsonDecode(
                                    study.pauseOrCloseReason!,
                                  );
                                  if (d is Map && d.containsKey('endReason')) {
                                    endReason = d['endReason'];
                                  }
                                } catch (e, st) {
                                  AppLogger.debug(
                                    'Motivo do estudo em texto livre (não JSON): $e',
                                    st,
                                  );
                                  endReason = study.pauseOrCloseReason;
                                }
                              }

                              final studyParts = participants
                                  .where((p) => p.studyId == study.id)
                                  .toList();
                              final primaryPersonId = studyParts.isNotEmpty
                                  ? studyParts.first.personId
                                  : null;
                              final primaryPerson = primaryPersonId != null
                                  ? people.firstWhereOrNull(
                                      (p) => p.id == primaryPersonId,
                                    )
                                  : null;
                              final isExpanded = _expandedStudyIds.contains(
                                study.id,
                              );

                              // Tags para este estudo
                              final studyTags = <String>[];
                              if (study.learningGoals != null &&
                                  study.learningGoals!.trim().isNotEmpty) {
                                for (final raw in study.learningGoals!.split(
                                  RegExp(r'[,;]'),
                                )) {
                                  final clean = raw.trim();
                                  if (clean.isNotEmpty &&
                                      !studyTags.contains(clean)) {
                                    studyTags.add(clean);
                                  }
                                }
                              }
                              if (primaryPerson != null &&
                                  primaryPerson.tags.isNotEmpty) {
                                try {
                                  final pTags = (jsonDecode(
                                    primaryPerson.tags,
                                  ) as List).cast<String>();
                                  for (final t in pTags) {
                                    final clean = t.trim();
                                    if (clean.isNotEmpty &&
                                        !studyTags.contains(clean)) {
                                      studyTags.add(clean);
                                    }
                                  }
                                } catch (e, st) {
                                  AppLogger.debug(
                                    'Falha ao ler tags JSON do contato principal (${primaryPerson.id}): $e',
                                    st,
                                  );
                                }
                              }

                              final isSelectedInSplit =
                                  isWide && _selectedStudyId == study.id;
                              return Semantics(
                                container: true,
                                selected: isSelectedInSplit,
                                label:
                                    'Estudo bíblico ${study.title}, lição ${study.currentLesson ?? 1}',
                                child: Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  clipBehavior: Clip.antiAlias,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: isSelectedInSplit
                                        ? const BorderSide(
                                            color: AppTheme.primaryBlue,
                                            width: 2,
                                          )
                                        : BorderSide.none,
                                  ),
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        if (isWide) {
                                          _selectedStudyId = study.id;
                                        } else {
                                          if (isExpanded) {
                                            _expandedStudyIds.remove(study.id);
                                          } else {
                                            _expandedStudyIds.add(study.id);
                                          }
                                        }
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Cabeçalho sempre visível
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              _buildStudentAvatar(
                                                personId: primaryPersonId,
                                                fallbackName: study.title,
                                                people: people,
                                                allPhotos: allPhotos,
                                                size: 40,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      study.title,
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    if (primaryPerson != null &&
                                                        primaryPerson.name !=
                                                            study.title)
                                                      Text(
                                                        primaryPerson.name,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: isDark
                                                              ? const Color(
                                                                  0xFF94A3B8,
                                                                )
                                                              : const Color(
                                                                  0xFF64748B,
                                                                ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.edit_outlined,
                                                  color: AppTheme.primaryBlue,
                                                  size: 20,
                                                ),
                                                tooltip:
                                                    'Editar Dados do Estudo',
                                                onPressed: () =>
                                                    _showEditStudyDialog(
                                                      context,
                                                      study,
                                                    ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.account_box_outlined,
                                                  color: AppTheme.primaryBlue,
                                                  size: 22,
                                                ),
                                                tooltip: 'Ver Cadastro e Opções da Pessoa',
                                                onPressed: () async {
                                                  final parts = await ref
                                                      .read(repositoryProvider)
                                                      .getParticipantsForStudy(
                                                        study.id,
                                                      );
                                                  if (parts.isNotEmpty &&
                                                      context.mounted) {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            PersonDetailScreen(
                                                              personId: parts
                                                                  .first
                                                                  .personId,
                                                            ),
                                                      ),
                                                    );
                                                  }
                                                },
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  isExpanded
                                                      ? Icons.keyboard_arrow_up
                                                      : Icons
                                                            .keyboard_arrow_down,
                                                  color: AppTheme.primaryBlue,
                                                ),
                                                tooltip: isExpanded
                                                    ? 'Recolher detalhes'
                                                    : 'Expandir detalhes',
                                                onPressed: () {
                                                  setState(() {
                                                    if (isExpanded) {
                                                      _expandedStudyIds.remove(
                                                        study.id,
                                                      );
                                                    } else {
                                                      _expandedStudyIds.add(
                                                        study.id,
                                                      );
                                                    }
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),

                                          // Linha de Badges Compactos (visível mesmo recolhido para leitura rápida)
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: study.status == 'ativo'
                                                      ? AppTheme.successGreen
                                                            .withValues(
                                                              alpha: 0.12,
                                                            )
                                                      : (isDark
                                                            ? const Color(
                                                                0xFF334155,
                                                              )
                                                            : Colors
                                                                  .grey
                                                                  .shade200),
                                                  borderRadius:
                                                      BorderRadius.circular(5),
                                                ),
                                                child: Text(
                                                  study.status.toUpperCase(),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        study.status == 'ativo'
                                                        ? AppTheme.successGreen
                                                        : (isDark
                                                              ? const Color(
                                                                  0xFFCBD5E1,
                                                                )
                                                              : Colors
                                                                    .grey
                                                                    .shade700),
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.primaryBlue
                                                      .withValues(alpha: 0.08),
                                                  borderRadius:
                                                      BorderRadius.circular(5),
                                                ),
                                                child: Text(
                                                  '📖 ${pub?.title ?? study.publicationId}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppTheme.primaryBlue,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? const Color(0xFF1E293B)
                                                      : const Color(0xFFE2E8F0),
                                                  borderRadius:
                                                      BorderRadius.circular(5),
                                                ),
                                                child: Text(
                                                  study.currentLesson != null
                                                      ? 'Lição ${study.currentLesson}${study.currentParagraph != null ? ' • § ${study.currentParagraph}' : ''}'
                                                      : 'Não iniciada',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isDark
                                                        ? const Color(
                                                            0xFFCBD5E1,
                                                          )
                                                        : const Color(
                                                            0xFF475569,
                                                          ),
                                                  ),
                                                ),
                                              ),
                                              ...studyTags.map(
                                                (tag) => Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.purple
                                                        .withValues(
                                                          alpha: 0.08,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.purple
                                                          .withValues(
                                                            alpha: 0.25,
                                                          ),
                                                      width: 0.8,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    '#$tag',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.purple,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),

                                          // Conteúdo Expandido (abre apenas com um clique/toque economizando espaço vertical)
                                          if (isExpanded) ...[
                                            const Divider(height: 20),
                                            if (studyParts.isNotEmpty)
                                              Builder(
                                                builder: (context) {
                                                  final peopleMap = {
                                                    for (var p in people)
                                                      p.id: p.name,
                                                  };
                                                  final names = studyParts
                                                      .map(
                                                        (p) =>
                                                            peopleMap[p
                                                                .personId] ??
                                                            'Participante',
                                                      )
                                                      .join(', ');
                                                  return InkWell(
                                                    onTap: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              PersonDetailScreen(
                                                                personId:
                                                                    studyParts
                                                                        .first
                                                                        .personId,
                                                              ),
                                                        ),
                                                      );
                                                    },
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 5,
                                                          ),
                                                      margin:
                                                          const EdgeInsets.only(
                                                            bottom: 8,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: AppTheme
                                                            .primaryBlue
                                                            .withValues(
                                                              alpha: 0.08,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              6,
                                                            ),
                                                        border: Border.all(
                                                          color: AppTheme
                                                              .primaryBlue
                                                              .withValues(
                                                                alpha: 0.2,
                                                              ),
                                                        ),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          const Icon(
                                                            Icons
                                                                .people_alt_outlined,
                                                            size: 16,
                                                            color: AppTheme
                                                                .primaryBlue,
                                                          ),
                                                          const SizedBox(
                                                            width: 6,
                                                          ),
                                                          Expanded(
                                                            child: Text(
                                                              'Participam: $names',
                                                              style: const TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: AppTheme
                                                                    .primaryBlue,
                                                              ),
                                                            ),
                                                          ),
                                                          const Icon(
                                                            Icons
                                                                .arrow_forward_ios,
                                                            size: 11,
                                                            color: AppTheme
                                                                .primaryBlue,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? const Color(0xFF1E293B)
                                                    : const Color(0xFFF1F5F9),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceAround,
                                                children: [
                                                  Column(
                                                    children: [
                                                      Text(
                                                        'Lição Atual',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: isDark
                                                              ? const Color(
                                                                  0xFFCBD5E1,
                                                                )
                                                              : AppTheme
                                                                    .textMuted,
                                                        ),
                                                      ),
                                                      Text(
                                                        study.currentLesson !=
                                                                null
                                                            ? 'Lição ${study.currentLesson}'
                                                            : 'Não iniciada',
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Column(
                                                    children: [
                                                      Text(
                                                        study.publicationId ==
                                                                    'lff-book' ||
                                                                study.publicationId == 'lff-brochure'
                                                            ? 'Ponto Atual'
                                                            : 'Parágrafo',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: isDark
                                                              ? const Color(
                                                                  0xFFCBD5E1,
                                                                )
                                                              : AppTheme
                                                                    .textMuted,
                                                        ),
                                                      ),
                                                      Text(
                                                        study.currentParagraph !=
                                                                null
                                                            ? (study.publicationId ==
                                                                          'lff-book' ||
                                                                      study.publicationId == 'lff-brochure'
                                                                  ? 'Ponto ${study.currentParagraph}'
                                                                  : '§ ${study.currentParagraph}')
                                                            : '—',
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Column(
                                                    children: [
                                                      Text(
                                                        'Idioma',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: isDark
                                                              ? const Color(
                                                                  0xFFCBD5E1,
                                                                )
                                                              : AppTheme
                                                                    .textMuted,
                                                        ),
                                                      ),
                                                      Text(
                                                        study.language
                                                            .toUpperCase(),
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (endReason != null) ...[
                                              const SizedBox(height: 8),
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFFEF3C7,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.info_outline,
                                                      color: Color(0xFFB45309),
                                                      size: 16,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        'Motivo do Encerramento: $endReason',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Color(
                                                            0xFF92400E,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: OutlinedButton.icon(
                                                    style:
                                                        OutlinedButton.styleFrom(
                                                          foregroundColor:
                                                              AppTheme
                                                                  .primaryBlue,
                                                          side: const BorderSide(
                                                            color: AppTheme
                                                                .primaryBlue,
                                                          ),
                                                        ),
                                                    icon: const Icon(
                                                      Icons.person_outline,
                                                      size: 16,
                                                    ),
                                                    label: const Text(
                                                      'Ver Cadastro & Opções',
                                                    ),
                                                    onPressed: () async {
                                                      final parts = await ref
                                                          .read(
                                                            repositoryProvider,
                                                          )
                                                          .getParticipantsForStudy(
                                                            study.id,
                                                          );
                                                      if (parts.isNotEmpty &&
                                                          context.mounted) {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (_) =>
                                                                PersonDetailScreen(
                                                                  personId: parts
                                                                      .first
                                                                      .personId,
                                                                ),
                                                          ),
                                                        );
                                                      } else if (context
                                                          .mounted) {
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          const SnackBar(
                                                            content: Text(
                                                              'Nenhum contato vinculado diretamente a este estudo.',
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    },
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
                                                      Icons.menu_book,
                                                      size: 16,
                                                    ),
                                                    label: const Text(
                                                      'Abrir no JW Library',
                                                    ),
                                                    onPressed: () =>
                                                        _openPublicationLink(
                                                          context,
                                                          study,
                                                        ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: ElevatedButton.icon(
                                                    icon: const Icon(
                                                      Icons.playlist_add_check,
                                                      size: 16,
                                                    ),
                                                    label: const Text('Sessão'),
                                                    onPressed:
                                                        study.status == 'ativo'
                                                        ? () =>
                                                              _showRecordSessionDialog(
                                                                context,
                                                                study,
                                                              )
                                                        : null,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            if (study.status == 'ativo')
                                              SizedBox(
                                                width: double.infinity,
                                                child: OutlinedButton.icon(
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                        foregroundColor:
                                                            AppTheme.alertRed,
                                                        side: const BorderSide(
                                                          color:
                                                              AppTheme.alertRed,
                                                        ),
                                                        visualDensity:
                                                            VisualDensity
                                                                .compact,
                                                      ),
                                                  icon: const Icon(
                                                    Icons.stop_circle_outlined,
                                                    size: 16,
                                                  ),
                                                  label: const Text(
                                                    'Encerrar Estudo (com motivo)',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  onPressed: () =>
                                                      _showEndStudyDialog(
                                                        context,
                                                        study,
                                                      ),
                                                ),
                                              )
                                            else
                                              SizedBox(
                                                width: double.infinity,
                                                child: ElevatedButton.icon(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            AppTheme
                                                                .successGreen,
                                                        foregroundColor:
                                                            Colors.white,
                                                        visualDensity:
                                                            VisualDensity
                                                                .compact,
                                                      ),
                                                  icon: const Icon(
                                                    Icons.refresh,
                                                    size: 16,
                                                  ),
                                                  label: const Text(
                                                    'Reativar Estudo Bíblico',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  onPressed: () =>
                                                      _reactivateStudy(
                                                        context,
                                                        study,
                                                      ),
                                                ),
                                              ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );

              if (!isWide || _viewMode != NotionViewMode.list) {
                return masterPane;
              }

              final selectedStudyParts = selectedStudy != null
                  ? participants
                        .where((p) => p.studyId == selectedStudy.id)
                        .toList()
                  : const <StudyParticipantEntry>[];
              final selectedPrimaryPersonId = selectedStudyParts.isNotEmpty
                  ? selectedStudyParts.first.personId
                  : null;
              final selectedPrimaryPerson = selectedPrimaryPersonId != null
                  ? people.firstWhereOrNull(
                      (p) => p.id == selectedPrimaryPersonId,
                    )
                  : null;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 420, child: masterPane),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: selectedStudy == null
                        ? Center(
                            child: Semantics(
                              label: 'Selecione um estudo bíblico para visualizar detalhes',
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.menu_book_outlined,
                                    size: 52,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Selecione um estudo bíblico para visualizar detalhes',
                                    style: TextStyle(
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : AppTheme.textMuted,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : StudyDetailPane(
                            study: selectedStudy,
                            primaryPerson: selectedPrimaryPerson,
                            sessions: sessions,
                            onRecordSession: () => _showRecordSessionDialog(
                              context,
                              selectedStudy,
                            ),
                            onEditStudy: () =>
                                _showEditStudyDialog(context, selectedStudy),
                            onOpenPublication: () =>
                                _openPublicationLink(context, selectedStudy),
                            onOpenStudentProfile:
                                selectedPrimaryPersonId == null
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PersonDetailScreen(
                                          personId: selectedPrimaryPersonId,
                                        ),
                                      ),
                                    );
                                  },
                            onEndOrReactivateStudy: () {
                              if (selectedStudy.status == 'ativo') {
                                _showEndStudyDialog(context, selectedStudy);
                              } else {
                                _reactivateStudy(context, selectedStudy);
                              }
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro: $err')),
      ),
    );
  }
}
