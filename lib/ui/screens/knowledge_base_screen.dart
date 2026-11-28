import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_logger.dart';
import '../../core/app_theme.dart';
import '../../core/feature_registry.dart';
import '../../knowledge/knowledge_backlink_indexer.dart';
import '../../knowledge/knowledge_manager.dart';
import '../../knowledge/note_cover_config.dart';
import '../../knowledge/second_brain_review_service.dart';
import '../../official_docs/official_doc_manager.dart';
import '../../official_docs/official_doc_models.dart';
import '../../official_docs/official_doc_pdf_generator.dart';
import '../../references/app_reference.dart';
import 'official_documents_screen.dart';
import '../../database/app_database.dart';
import '../../reports/binary_file_saver.dart';
import '../../reports/knowledge_and_email_pdf_service.dart';
import '../../reports/web_downloader.dart';
import '../../research/research_manager.dart';
import '../providers.dart';
import '../widgets/adaptive_ministry_sheet.dart';
import '../widgets/app_inline_image_view.dart';
import '../widgets/app_reference_viewer.dart';
import '../widgets/knowledge/knowledge_ui_components.dart';
import '../widgets/knowledge/note_cover_picker_dialog.dart';
import '../widgets/knowledge/second_brain_database_views.dart';
import '../widgets/knowledge/second_brain_dialogs.dart';
import '../widgets/knowledge/second_brain_rich_editor.dart';
import '../widgets/knowledge_item_reader_dialog.dart';
import '../widgets/managed_text_controllers.dart';
import '../widgets/markdown_preview_text.dart';
import '../widgets/notion/notion_collection_views.dart';
import '../widgets/rich_formatted_editing_controller.dart';
import '../widgets/rich_markdown_toolbar.dart';
import '../widgets/universal_attachment_viewer.dart';
import 'inbox_screen.dart';
import 'project_detail_screen.dart';
import 'research_screen.dart';

/// Tela do Módulo C — Base de Conhecimento do Field Assistant.
/// Centraliza notas formatadas, dúvidas bíblicas, arquivos/documentos locais e links de estudo.
class KnowledgeBaseScreen extends ConsumerStatefulWidget {
  final int? initialTabIndex;
  final int navigationEpoch;

  const KnowledgeBaseScreen({
    super.key,
    this.initialTabIndex,
    this.navigationEpoch = 0,
  });

  @override
  ConsumerState<KnowledgeBaseScreen> createState() =>
      _KnowledgeBaseScreenState();
}

class _KnowledgeBaseScreenState extends ConsumerState<KnowledgeBaseScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final ValueNotifier<String?> _officialDocSelectionNotifier = ValueNotifier(
    null,
  );
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _selectedAreaId;
  NotesDatabaseViewMode _notesViewMode = NotesDatabaseViewMode.list;
  NotionViewMode _questionsViewMode = NotionViewMode.list;
  NotionViewMode _docsViewMode = NotionViewMode.list;
  NotionViewMode _resourcesViewMode = NotionViewMode.list;
  String? _selectedNoteTag;
  String? _selectedNoteId;
  String? _selectedQuestionStatus = 'all'; // 'all', 'answered', 'unanswered'
  String? _selectedQuestionCategory;
  String? _selectedDocCategory;
  String? _selectedDocTag;
  String? _selectedResourceCategory;
  String? _selectedResourceTag;
  bool _exportingTabPdf = false;

  @override
  void initState() {
    super.initState();
    final safeIdx = (widget.initialTabIndex ?? 0).clamp(0, 4);
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: safeIdx,
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        KnowledgeBacklinkIndexer.ensureInitialBackfill(
          ref.read(databaseProvider),
        ),
      );
    });
  }

  @override
  void didUpdateWidget(covariant KnowledgeBaseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTabIndex != null &&
        (widget.initialTabIndex != oldWidget.initialTabIndex ||
            widget.navigationEpoch != oldWidget.navigationEpoch)) {
      final safeIdx = widget.initialTabIndex!.clamp(0, 4);
      if (_tabController.index != safeIdx) {
        _tabController.animateTo(safeIdx);
      }
    }
  }

  @override
  void dispose() {
    _officialDocSelectionNotifier.dispose();
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final themePrimary = AppTheme.primaryColor(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0E1422) : Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Semantics(
          header: true,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      themePrimary.withValues(alpha: 0.22),
                      themePrimary.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: themePrimary.withValues(alpha: 0.28),
                  ),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  color: themePrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Base de Conhecimento',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            key: const Key('btn_kb_weekly_review'),
            icon: const Icon(
              Icons.psychology_alt_outlined,
              color: Color(0xFF10B981),
            ),
            tooltip: 'Revisão Semanal & Espaçada',
            onPressed: _openWeeklyReviewModal,
          ),
          IconButton(
            key: const Key('btn_kb_export_tab_pdf'),
            icon: _exportingTabPdf
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.picture_as_pdf_outlined,
                    color: isDark
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFFDC2626),
                  ),
            tooltip: 'Exportar aba para PDF',
            onPressed: _exportingTabPdf ? null : _exportCurrentTabToPdf,
          ),
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: themePrimary),
            tooltip: 'Adicionar à Base',
            onPressed: _handleTabAwareAdd,
          ),
          PopupMenuButton<String>(
            key: const Key('btn_kb_more_menu'),
            tooltip: 'Segundo Cérebro & Importações',
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'areas') _openManageAreasModal();
              if (val == 'notion') _openNotionImportModal();
              if (val == 'research') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ResearchScreen()),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'areas',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.layers_outlined, size: 19),
                  title: Text('Gerenciar Áreas P.A.R.A.'),
                ),
              ),
              PopupMenuItem(
                value: 'notion',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.auto_awesome_mosaic_outlined, size: 19),
                  title: Text('Importar do Notion (.zip/.md/.csv)'),
                ),
              ),
              PopupMenuItem(
                value: 'research',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.auto_stories_outlined, size: 19),
                  title: Text('Pesquisas e Apresentações'),
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              dividerColor: Colors.transparent,
              tabAlignment: TabAlignment.start,
              labelColor: isDark ? Colors.white : themePrimary,
              unselectedLabelColor: isDark
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF64748B),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13.5,
              ),
              indicator: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: themePrimary, width: 3),
                ),
              ),
              tabs: const [
                Tab(text: '📝 Notas'),
                Tab(text: '❓ Perguntas & Dúvidas'),
                Tab(text: '📁 Documentos'),
                Tab(text: '🔗 Recursos'),
                Tab(text: '✉️ Cartas & Atas'),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _buildTabAwareFab(),
      body: Column(
        children: [
          // Barra de Pesquisa Rápida na Base
          Container(
            color: isDark ? const Color(0xFF0E1422) : Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              decoration: InputDecoration(
                hintText: 'Pesquisar em toda a base de conhecimento...',
                hintStyle: TextStyle(
                  color: isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8),
                  fontSize: 13.5,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: themePrimary,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF151E32)
                    : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: themePrimary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
              ),
            ),
          ),
          if (_tabController.index < 4)
            _buildAreasFilterBar(isDark, themePrimary),
          const Divider(height: 1),

          // Abas da Base
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildNotesTab(isDark),
                _buildQuestionsTab(isDark),
                _buildDocumentsTab(isDark),
                _buildResourcesTab(isDark),
                _buildOfficialDocsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficialDocsTab() {
    final isEnabled = ref.watch(
      isFeatureEnabledProvider(AppFeature.officialDocuments),
    );
    if (!isEnabled) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.visibility_off_outlined,
                  size: 48,
                  color: Colors.grey,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Módulo "Cartas & Atas" oculto',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Todas as suas cartas, pautas, atas, perfis e modelos salvos continuam intactos e sincronizados.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => FeatureRegistry.setFeatureEnabled(
                    ref,
                    AppFeature.officialDocuments,
                    true,
                  ),
                  icon: const Icon(Icons.visibility),
                  label: const Text('Reativar Cartas & Atas'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return OfficialDocumentsScreen(
      embedded: true,
      externalSelectionNotifier: _officialDocSelectionNotifier,
    );
  }

  // ==========================================
  // ABA 1: NOTAS DE CONHECIMENTO
  // ==========================================

  Widget _buildNotesTab(bool isDark) {
    final km = ref.watch(knowledgeManagerProvider);

    return StreamBuilder<List<KnowledgeAreaEntry>>(
      stream: km.watchAreas(),
      builder: (context, areasSnap) {
        final areas = areasSnap.data ?? const <KnowledgeAreaEntry>[];
        final areasById = {for (final a in areas) a.id: a};

        return StreamBuilder<List<KnowledgeNoteEntry>>(
          stream: km.watchNotes(
            areaId: _selectedAreaId,
            query: _searchQuery.isNotEmpty ? _searchQuery : null,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final allNotes = (snapshot.data ?? [])
                .where(
                  (n) => !OfficialDocManager.isReservedCategory(n.category),
                )
                .toList();
            if (allNotes.isEmpty) {
              return _buildEmptyState(
                icon: Icons.note_outlined,
                title: 'Nenhuma nota registrada',
                subtitle: _selectedAreaId != null
                    ? 'Nenhuma nota nesta Área P.A.R.A. ainda.'
                    : 'Guarde anotações temáticas, ideias de pregações ou notas pastorais.',
                isDark: isDark,
                actionLabel: 'Nova Nota',
                onAction: _showCreateNoteModal,
              );
            }

            final allTags = <String>{};
            for (final n in allNotes) {
              try {
                final list = jsonDecode(n.tags) as List;
                for (final item in list) {
                  final t = item.toString().trim();
                  if (t.isNotEmpty && !t.startsWith('research:')) {
                    allTags.add(t);
                  }
                }
              } catch (e, st) {
                AppLogger.debug(
                  'Falha ao ler tags JSON da nota (${n.id}): $e',
                  st,
                );
              }
            }

            final notes = allNotes.where((n) {
              if (_selectedNoteTag == null) return true;
              try {
                final list = (jsonDecode(n.tags) as List)
                    .map((e) => e.toString())
                    .toList();
                return list.contains(_selectedNoteTag);
              } catch (e, st) {
                AppLogger.debug(
                  'Falha ao filtrar tags da nota (${n.id}): $e',
                  st,
                );
                return false;
              }
            }).toList();

            final viewSwitcherBar = Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final mode in NotesDatabaseViewMode.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        key: Key('view_mode_chip_${mode.name}'),
                        avatar: Icon(mode.icon, size: 15),
                        label: Text(
                          mode.label,
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: _notesViewMode == mode,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _notesViewMode = mode);
                          }
                        },
                      ),
                    ),
                  if (allTags.isNotEmpty) ...[
                    const VerticalDivider(width: 16),
                    FilterChip(
                      label: const Text('Todas as Tags'),
                      selected: _selectedNoteTag == null,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onSelected: (_) =>
                          setState(() => _selectedNoteTag = null),
                    ),
                    const SizedBox(width: 6),
                    for (final tag in allTags)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          avatar: const Icon(Icons.tag, size: 13),
                          label: Text(tag),
                          selected: _selectedNoteTag == tag,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onSelected: (val) => setState(
                            () => _selectedNoteTag = val ? tag : null,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            );

            void openSingleNote(
              KnowledgeNoteEntry note, {
              bool fullScreen = false,
            }) {
              List<String> noteTags = [];
              try {
                noteTags = (jsonDecode(note.tags) as List)
                    .map((e) => e.toString())
                    .where((t) => !t.startsWith('research:'))
                    .toList();
              } catch (_) {}
              showKnowledgeItemReader(
                context,
                initialFullScreen: fullScreen,
                title: note.title,
                content: note.content,
                category: note.category,
                itemType: 'Nota',
                updatedAt: note.updatedAt,
                tags: noteTags,
                allowHighlights: true,
                backlinkTargetType: 'note',
                backlinkTargetId: note.id,
                onContentUpdated: (updated) async {
                  await km.updateNote(note.id, content: updated);
                },
                onEdit: () => _showEditNoteModal(note),
                onDelete: () => km.softDeleteNote(note.id),
                onExport: () => _exportNote(note),
                onExportPdf: () => _exportNotePdf(note),
              );
            }

            return Column(
              children: [
                viewSwitcherBar,
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (_notesViewMode == NotesDatabaseViewMode.table) {
                        return NotesTableView(
                          notes: notes,
                          areasById: areasById,
                          isDark: isDark,
                          formatDate: _formatDate,
                          onOpenNote: openSingleNote,
                        );
                      }

                      if (_notesViewMode == NotesDatabaseViewMode.kanban) {
                        return NotesKanbanView(
                          notes: notes,
                          areasById: areasById,
                          isDark: isDark,
                          onOpenNote: openSingleNote,
                          onChangeStatus: (note, newStatus) async {
                            final props = KnowledgeManager.decodeProperties(
                              note.propertiesJson,
                            );
                            props['status'] = newStatus;
                            await km.updateNote(note.id, properties: props);
                          },
                          onCreateInStatus: (status) =>
                              _showCreateNoteModal(initialStatus: status),
                        );
                      }

                      if (_notesViewMode == NotesDatabaseViewMode.gallery) {
                        return NotesGalleryView(
                          notes: notes,
                          areasById: areasById,
                          isDark: isDark,
                          formatDate: _formatDate,
                          onOpenNote: openSingleNote,
                        );
                      }

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 900;
                          KnowledgeNoteEntry? selectedNote;
                          if (_selectedNoteId != null) {
                            for (final n in notes) {
                              if (n.id == _selectedNoteId) {
                                selectedNote = n;
                                break;
                              }
                            }
                          }

                          final listPane = ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
                            itemCount: notes.length,
                            separatorBuilder: (ctx, i) =>
                                const SizedBox(height: 10),
                            itemBuilder: (ctx, i) {
                              final note = notes[i];
                              List<String> noteTags = [];
                              try {
                                noteTags = (jsonDecode(note.tags) as List)
                                    .map((e) => e.toString())
                                    .where((t) => !t.startsWith('research:'))
                                    .toList();
                              } catch (e, st) {
                                AppLogger.debug(
                                  'Falha ao exibir tags da nota (${note.id}): $e',
                                  st,
                                );
                              }

                              final isSelectedInSplit =
                                  isWide && _selectedNoteId == note.id;
                              return KnowledgeNoteListCard(
                                note: note,
                                tags: noteTags,
                                formattedDate: _formatDate(note.updatedAt),
                                isSelected: isSelectedInSplit,
                                isDark: isDark,
                                onTap: () {
                                  if (isWide) {
                                    setState(() => _selectedNoteId = note.id);
                                    return;
                                  }
                                  openSingleNote(note);
                                },
                                trailingMenu: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.open_in_full,
                                        size: 18,
                                      ),
                                      tooltip: 'Abrir em tela cheia',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => openSingleNote(
                                        note,
                                        fullScreen: true,
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: const Icon(
                                        Icons.more_vert,
                                        size: 20,
                                      ),
                                      onSelected: (val) {
                                        if (val == 'pin') {
                                          km.togglePinNote(note.id);
                                        }
                                        if (val == 'edit') {
                                          _showEditNoteModal(note);
                                        }
                                        if (val == 'research') {
                                          _transformNoteToResearch(note);
                                        }
                                        if (val == 'export_pdf') {
                                          _exportNotePdf(note);
                                        }
                                        if (val == 'export') {
                                          _exportNote(note);
                                        }
                                        if (val == 'delete') {
                                          km.softDeleteNote(note.id);
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        PopupMenuItem(
                                          value: 'pin',
                                          child: Text(
                                            note.isPinned
                                                ? 'Desafixar'
                                                : 'Fixar no Topo',
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Editar Nota'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'research',
                                          child: Text(
                                            'Transformar em Pesquisa',
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'export_pdf',
                                          child: Text('Baixar PDF (.pdf)'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'export',
                                          child: Text('Exportar Nota'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Text(
                                            'Excluir Nota',
                                            style: TextStyle(
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          );

                          if (!isWide) {
                            return listPane;
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(width: 400, child: listPane),
                              const VerticalDivider(width: 1),
                              Expanded(
                                child: selectedNote == null
                                    ? Container(
                                        color: isDark
                                            ? const Color(0xFF090D16)
                                            : const Color(0xFFF1F5F9),
                                        child: Center(
                                          child: Semantics(
                                            label: 'Selecione uma nota para leitura completa',
                                            child: Container(
                                              constraints: const BoxConstraints(
                                                maxWidth: 360,
                                              ),
                                              padding: const EdgeInsets.all(28),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? const Color(0xFF111827)
                                                    : Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: isDark
                                                      ? Colors.white.withValues(
                                                          alpha: 0.08,
                                                        )
                                                      : const Color(0xFFE2E8F0),
                                                ),
                                              ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          16,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme
                                                          .primaryBlue
                                                          .withValues(
                                                            alpha: 0.14,
                                                          ),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                      Icons.menu_book_rounded,
                                                      size: 36,
                                                      color:
                                                          AppTheme.primaryBlue,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 16),
                                                  Text(
                                                    'Selecione uma nota para leitura completa',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      color: isDark
                                                          ? const Color(
                                                              0xFFE2E8F0,
                                                            )
                                                          : AppTheme.textDark,
                                                      fontSize: 15.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    'Toque em um cartão à esquerda para ler referências bíblicas, blocos estilo Notion, backlinks e subpáginas.',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      color: isDark
                                                          ? const Color(
                                                              0xFF94A3B8,
                                                            )
                                                          : AppTheme.textMuted,
                                                      fontSize: 12.5,
                                                      height: 1.45,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    : _buildNoteDetailSidePane(
                                        context,
                                        km,
                                        selectedNote,
                                        areasById,
                                        isDark,
                                      ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildNoteDetailSidePane(
    BuildContext context,
    KnowledgeManager km,
    KnowledgeNoteEntry selectedNote,
    Map<String, KnowledgeAreaEntry> areasById,
    bool isDark,
  ) {
    final db = ref.read(databaseProvider);
    List<String> selectedNoteTags = [];
    try {
      selectedNoteTags = (jsonDecode(selectedNote.tags) as List)
          .map((e) => e.toString())
          .where((t) => !t.startsWith('research:'))
          .toList();
    } catch (_) {}

    final area = selectedNote.areaId != null
        ? areasById[selectedNote.areaId!]
        : null;

    return FutureBuilder<List<KnowledgeNoteEntry>>(
      future: km.getNoteAncestors(selectedNote.id),
      builder: (ctx, ancSnap) {
        final ancestors = ancSnap.data ?? const <KnowledgeNoteEntry>[];
        return StreamBuilder<List<KnowledgeNoteEntry>>(
          stream: km.watchSubpages(selectedNote.id),
          builder: (ctx, subSnap) {
            final subpages = subSnap.data ?? const <KnowledgeNoteEntry>[];
            return StreamBuilder<List<ResolvedBacklink>>(
              stream: KnowledgeBacklinkIndexer.watchBacklinksFor(
                db,
                targetType: 'note',
                targetId: selectedNote.id,
              ),
              builder: (ctx, blSnap) {
                final backlinks = blSnap.data ?? const <ResolvedBacklink>[];
                return KnowledgeNoteDetailPane(
                  note: selectedNote,
                  tags: selectedNoteTags,
                  formattedDate: _formatDate(selectedNote.updatedAt),
                  isDark: isDark,
                  areaName: area?.name,
                  areaColorHex: area?.colorHex,
                  breadcrumbAncestors: ancestors,
                  subpages: subpages,
                  backlinks: backlinks,
                  onSelectNote: (target) {
                    setState(() => _selectedNoteId = target.id);
                  },
                  onCreateSubpage: () => _showCreateNoteModal(
                    initialParentNoteId: selectedNote.id,
                    initialAreaId: selectedNote.areaId,
                  ),
                  onToggleSpacedReview: () async {
                    final enable = selectedNote.nextReviewAt == null;
                    await SecondBrainReviewService.setSpacedReviewEnabled(
                      db,
                      entityType: 'note',
                      entityId: selectedNote.id,
                      enabled: enable,
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          enable
                              ? 'Revisão espaçada (SM-2) ativada para "${selectedNote.title}".'
                              : 'Revisão espaçada pausada.',
                        ),
                      ),
                    );
                  },
                  onOpenBacklink: (link) async {
                    if (link.sourceType == 'note') {
                      setState(() => _selectedNoteId = link.sourceId);
                      return;
                    }
                    final cat = AppRefCategory.fromTypeId(link.sourceType);
                    if (cat != null) {
                      await AppReferenceViewer.openUrl(
                        context,
                        AppReferenceHelper.buildUri(cat, link.sourceId),
                      );
                    }
                  },
                  onEdit: () => _showEditNoteModal(selectedNote),
                  onCustomizeCover: () => _customizeNoteCover(selectedNote),
                  onExportPdf: () => _exportNotePdf(selectedNote),
                  onShare: () => _exportNote(selectedNote),
                  onTogglePin: () => km.togglePinNote(selectedNote.id),
                  onTransformResearch: () =>
                      _transformNoteToResearch(selectedNote),
                  onContentUpdated: (updated) async {
                    await km.updateNote(selectedNote.id, content: updated);
                  },
                  onOpenLink: (url) async {
                    if (AppReferenceHelper.isAppReferenceUrl(url)) {
                      await AppReferenceViewer.openUrl(context, url);
                    } else {
                      await _openUrl(url);
                    }
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  // ==========================================
  // ABA 2: DÚVIDAS E RESPOSTAS TEOCRÁTICAS
  // ==========================================

  Widget _buildQuestionsTab(bool isDark) {
    final km = ref.watch(knowledgeManagerProvider);

    return StreamBuilder<List<KnowledgeQuestionEntry>>(
      stream: km.watchQuestions(
        status: _questionsViewMode == NotionViewMode.kanban
            ? null
            : (_selectedQuestionStatus == 'all'
                  ? null
                  : _selectedQuestionStatus),
        category: _selectedQuestionCategory,
        areaId: _selectedAreaId,
        query: _searchQuery.isNotEmpty ? _searchQuery : null,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final questions = snapshot.data ?? [];

        void openQuestionReader(
          KnowledgeQuestionEntry q, {
          bool fullScreen = false,
        }) {
          final isAnswered = q.status == 'answered';
          final hasAnswer = q.answer != null && q.answer!.trim().isNotEmpty;
          final readerSubtitle = isAnswered
              ? (q.context?.trim().isNotEmpty == true
                    ? 'Respondida • Contexto: ${q.context!.trim()}'
                    : 'Respondida')
              : 'Em Aberto';
          showKnowledgeItemReader(
            context,
            initialFullScreen: fullScreen,
            title: q.question,
            content: hasAnswer
                ? q.answer!
                : (q.context ??
                      'Dúvida ainda sem resposta bíblica cadastrada.'),
            category: q.category,
            itemType: 'Dúvida',
            updatedAt: q.updatedAt,
            subtitle: readerSubtitle,
            allowHighlights: true,
            backlinkTargetType: 'question',
            backlinkTargetId: q.id,
            onContentUpdated: (updated) async {
              if (hasAnswer) {
                await km.updateQuestion(q.id, answer: updated);
              } else {
                await km.updateQuestion(q.id, context: updated);
              }
            },
            onEdit: () => _showEditQuestionModal(q),
            onDelete: () => km.softDeleteQuestion(q.id),
            onExport: () => _exportQuestion(q),
          );
        }

        return Column(
          children: [
            // Filtros de Status e Categoria
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ChoiceChip(
                    label: const Text('Todas'),
                    selected: _selectedQuestionStatus == 'all',
                    onSelected: (val) {
                      if (val) setState(() => _selectedQuestionStatus = 'all');
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(
                      Icons.help_outline_rounded,
                      size: 14,
                      color: Color(0xFFF59E0B),
                    ),
                    label: const Text('Em Aberto'),
                    selected: _selectedQuestionStatus == 'unanswered',
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedQuestionStatus = 'unanswered');
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 14,
                      color: Color(0xFF10B981),
                    ),
                    label: const Text('Respondidas'),
                    selected: _selectedQuestionStatus == 'answered',
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedQuestionStatus = 'answered');
                      }
                    },
                  ),
                ],
              ),
            ),

            if (questions.isNotEmpty)
              NotionViewModeBar(
                mode: _questionsViewMode,
                availableModes: const [
                  NotionViewMode.list,
                  NotionViewMode.table,
                  NotionViewMode.kanban,
                ],
                onChanged: (m) => setState(() => _questionsViewMode = m),
                isDark: isDark,
                keyPrefix: 'questions_view',
              ),

            if (questions.isEmpty)
              Expanded(
                child: _buildEmptyState(
                  icon: Icons.help_outline_rounded,
                  title: 'Nenhuma dúvida cadastrada',
                  subtitle: 'Registre perguntas de moradores ou pesquisas para responder na próxima visita.',
                  isDark: isDark,
                  actionLabel: 'Nova Dúvida',
                  onAction: _showCreateQuestionModal,
                ),
              )
            else if (_questionsViewMode == NotionViewMode.table)
              Expanded(
                child: NotionResponsiveTable(
                  isDark: isDark,
                  columns: const [
                    NotionTableColumnDef(label: 'Pergunta', width: 260),
                    NotionTableColumnDef(label: 'Situação', width: 130),
                    NotionTableColumnDef(
                      label: 'Resumo / Resposta',
                      width: 240,
                    ),
                    NotionTableColumnDef(label: 'Atualizado', width: 100),
                  ],
                  rows: [
                    for (final q in questions)
                      NotionTableRowItem(
                        onTap: () => openQuestionReader(q),
                        cells: [
                          Text(
                            q.question,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          KnowledgePillBadge(
                            label: q.status == 'answered'
                                ? 'Respondida'
                                : 'Em Aberto',
                            color: q.status == 'answered'
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                            isDark: isDark,
                          ),
                          Text(
                            MarkdownPreviewText.cleanMarkdown(
                              q.answer?.trim().isNotEmpty == true
                                  ? q.answer!
                                  : (q.context ?? '—'),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            _formatDate(q.updatedAt),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                  ],
                ),
              )
            else if (_questionsViewMode == NotionViewMode.kanban)
              Expanded(
                child: NotionKanbanBoard<KnowledgeQuestionEntry>(
                  isDark: isDark,
                  keyPrefix: 'questions_kanban',
                  columns: [
                    NotionKanbanColumnSpec(
                      statusKey: 'unanswered',
                      label: 'Em Aberto',
                      accentColor: const Color(0xFFF59E0B),
                      onQuickAdd: _showCreateQuestionModal,
                    ),
                    const NotionKanbanColumnSpec(
                      statusKey: 'answered',
                      label: 'Respondidas',
                      accentColor: Color(0xFF10B981),
                    ),
                  ],
                  itemsByColumn: {
                    'unanswered': questions
                        .where((q) => q.status != 'answered')
                        .toList(),
                    'answered': questions
                        .where((q) => q.status == 'answered')
                        .toList(),
                  },
                  itemId: (q) => q.id,
                  onMoveToColumn: (q, targetCol) async {
                    await km.updateQuestion(q.id, status: targetCol);
                  },
                  cardBuilder: (ctx, q, colKey, {required bool isFeedback}) {
                    final preview = MarkdownPreviewText.cleanMarkdown(
                      q.answer?.trim().isNotEmpty == true
                          ? q.answer!
                          : (q.context ?? ''),
                    );
                    return Card(
                      elevation: isFeedback ? 8 : 0,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isFeedback
                              ? const Color(0xFFF59E0B)
                              : (isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : const Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: isFeedback ? null : () => openQuestionReader(q),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                q.question,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                              if (preview.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  preview,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : AppTheme.textMuted,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                _formatDate(q.updatedAt),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? const Color(0xFF64748B)
                                      : AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              Expanded(
                child: KnowledgeResponsiveCardGrid(
                  children: [
                    for (final q in questions)
                      Builder(
                        builder: (ctx) {
                          final isAnswered = q.status == 'answered';
                          return KnowledgeQuestionCard(
                            question: q,
                            formattedDate: _formatDate(q.updatedAt),
                            isDark: isDark,
                            onTap: () => openQuestionReader(q),
                            onQuickAnswer: () => _showAnswerQuestionModal(q),
                            trailingMenu: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.open_in_full,
                                    size: 18,
                                  ),
                                  tooltip: 'Abrir em tela cheia',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () =>
                                      openQuestionReader(q, fullScreen: true),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 20),
                                  onSelected: (val) {
                                    if (val == 'answer') {
                                      _showAnswerQuestionModal(q);
                                    }
                                    if (val == 'edit')
                                      _showEditQuestionModal(q);
                                    if (val == 'research') {
                                      _transformQuestionToResearch(q);
                                    }
                                    if (val == 'export') _exportQuestion(q);
                                    if (val == 'delete') {
                                      km.softDeleteQuestion(q.id);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    PopupMenuItem(
                                      value: 'answer',
                                      child: Text(
                                        isAnswered
                                            ? 'Editar Resposta'
                                            : 'Inserir Resposta',
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Editar Dúvida'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'research',
                                      child: Text('Transformar em Pesquisa'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'export',
                                      child: Text('Exportar'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text(
                                        'Excluir',
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  // ==========================================
  // ABA 3: DOCUMENTOS LOCAIS
  // ==========================================

  Widget _buildDocumentsTab(bool isDark) {
    final km = ref.watch(knowledgeManagerProvider);

    return StreamBuilder<List<KnowledgeDocumentEntry>>(
      stream: km.watchDocuments(
        category: _selectedDocCategory,
        areaId: _selectedAreaId,
        query: _searchQuery.isNotEmpty ? _searchQuery : null,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allDocs = snapshot.data ?? [];
        if (allDocs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.folder_shared_outlined,
            title: 'Nenhum documento anexado',
            subtitle: 'Guarde manuais, roteiros ou apostilas em PDF diretamente no app.',
            isDark: isDark,
            actionLabel: 'Anexar Documento',
            onAction: _pickAndRegisterDocument,
          );
        }

        // Extrai todas as tags únicas dos documentos
        final allDocTags = <String>{};
        for (final d in allDocs) {
          try {
            final list = jsonDecode(d.tags) as List;
            for (final item in list) {
              final t = item.toString().trim();
              if (t.isNotEmpty) allDocTags.add(t);
            }
          } catch (e, st) {
            AppLogger.debug(
              'Falha ao ler tags JSON do documento (${d.id}): $e',
              st,
            );
          }
        }

        // Filtro opcional por tag
        final docs = allDocs.where((d) {
          if (_selectedDocTag == null) return true;
          try {
            final list = (jsonDecode(d.tags) as List)
                .map((e) => e.toString())
                .toList();
            return list.contains(_selectedDocTag);
          } catch (e, st) {
            AppLogger.debug(
              'Falha ao filtrar tags do documento (${d.id}): $e',
              st,
            );
            return false;
          }
        }).toList();

        return Column(
          children: [
            // Filtros de Categoria
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ChoiceChip(
                    label: const Text('Todos'),
                    selected: _selectedDocCategory == null,
                    onSelected: (val) =>
                        setState(() => _selectedDocCategory = null),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Manuais'),
                    selected: _selectedDocCategory == 'manual',
                    onSelected: (val) => setState(
                      () => _selectedDocCategory = val ? 'manual' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Estudo'),
                    selected: _selectedDocCategory == 'study',
                    onSelected: (val) => setState(
                      () => _selectedDocCategory = val ? 'study' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Esboço'),
                    selected: _selectedDocCategory == 'outline',
                    onSelected: (val) => setState(
                      () => _selectedDocCategory = val ? 'outline' : null,
                    ),
                  ),
                ],
              ),
            ),

            // Filtros de Tags dos Documentos
            if (allDocTags.isNotEmpty)
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    FilterChip(
                      label: const Text('Todas as Tags'),
                      selected: _selectedDocTag == null,
                      onSelected: (val) =>
                          setState(() => _selectedDocTag = null),
                      backgroundColor: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                    ),
                    const SizedBox(width: 8),
                    ...allDocTags.map((tag) {
                      final isSelected = _selectedDocTag == tag;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          avatar: Icon(
                            Icons.tag,
                            size: 14,
                            color: isSelected
                                ? Colors.white
                                : AppTheme.primaryBlue,
                          ),
                          label: Text(tag),
                          selected: isSelected,
                          onSelected: (val) => setState(
                            () => _selectedDocTag = val ? tag : null,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

            NotionViewModeBar(
              mode: _docsViewMode,
              availableModes: const [
                NotionViewMode.list,
                NotionViewMode.table,
                NotionViewMode.gallery,
              ],
              onChanged: (m) => setState(() => _docsViewMode = m),
              isDark: isDark,
              keyPrefix: 'docs_view',
            ),

            if (_docsViewMode == NotionViewMode.table)
              Expanded(
                child: NotionResponsiveTable(
                  isDark: isDark,
                  columns: const [
                    NotionTableColumnDef(label: 'Documento', width: 250),
                    NotionTableColumnDef(label: 'Arquivo', width: 170),
                    NotionTableColumnDef(label: 'Categoria', width: 120),
                    NotionTableColumnDef(label: 'Atualizado', width: 100),
                  ],
                  rows: [
                    for (final doc in docs)
                      NotionTableRowItem(
                        onTap: () => _openDocument(doc),
                        cells: [
                          Text(
                            doc.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            doc.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          KnowledgePillBadge(
                            label: doc.category,
                            color: AppTheme.primaryBlue,
                            isDark: isDark,
                          ),
                          Text(
                            _formatDate(doc.updatedAt),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                  ],
                ),
              )
            else if (_docsViewMode == NotionViewMode.gallery)
              Expanded(
                child: NotionGalleryGrid<KnowledgeDocumentEntry>(
                  items: docs,
                  itemBuilder: (ctx, doc) {
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
                        onTap: () => _openDocument(doc),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.primaryBlue.withValues(
                                      alpha: isDark ? 0.35 : 0.2,
                                    ),
                                    AppTheme.primaryBlue.withValues(
                                      alpha: isDark ? 0.12 : 0.06,
                                    ),
                                  ],
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.description_outlined,
                                    size: 16,
                                    color: AppTheme.primaryBlue,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      doc.fileType.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _formatDate(doc.updatedAt),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      doc.title,
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
                                        doc.description?.trim().isNotEmpty ==
                                                true
                                            ? MarkdownPreviewText.cleanMarkdown(
                                                doc.description!,
                                              )
                                            : doc.fileName,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? const Color(0xFF94A3B8)
                                              : AppTheme.textMuted,
                                        ),
                                      ),
                                    ),
                                    KnowledgePillBadge(
                                      label: doc.category,
                                      color: AppTheme.primaryBlue,
                                      isDark: isDark,
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
                ),
              )
            else
              Expanded(
                child: KnowledgeResponsiveCardGrid(
                  children: [
                    for (final doc in docs)
                      Builder(
                        builder: (ctx) {
                          List<String> docTags = [];
                          try {
                            docTags = (jsonDecode(doc.tags) as List)
                                .map((e) => e.toString())
                                .toList();
                          } catch (e, st) {
                            AppLogger.debug(
                              'Falha ao ler tags JSON na listagem de documentos (${doc.id}): $e',
                              st,
                            );
                          }

                          Future<void> exportDocPdf() async {
                            try {
                              await KnowledgeAndEmailPdfService.exportSingleItemPdf(
                                title: doc.title,
                                content:
                                    doc.description?.trim().isNotEmpty == true
                                    ? doc.description!
                                    : 'Arquivo: ${doc.fileName} (${doc.fileType})',
                                itemType: 'Documento',
                                category: doc.category,
                                subtitle: doc.fileName,
                                tags: docTags,
                                updatedAt: doc.updatedAt,
                              );
                              if (!ctx.mounted) return;
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'PDF do documento gerado com sucesso!',
                                  ),
                                ),
                              );
                            } catch (e, st) {
                              AppLogger.warning(
                                'Falha ao exportar PDF do documento (${doc.id})',
                                e,
                                st,
                              );
                              if (!ctx.mounted) return;
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text('Erro ao gerar PDF: $e'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }

                          void openDocDetails({bool fullScreen = false}) {
                            showKnowledgeItemReader(
                              context,
                              initialFullScreen: fullScreen,
                              title: doc.title,
                              content:
                                  doc.description?.trim().isNotEmpty == true
                                  ? doc.description!
                                  : 'Arquivo: ${doc.fileName} (${doc.fileType})',
                              category: doc.category,
                              itemType: 'Documento',
                              subtitle: doc.fileName,
                              tags: docTags,
                              updatedAt: doc.updatedAt,
                              allowHighlights: true,
                              backlinkTargetType: 'document',
                              backlinkTargetId: doc.id,
                              onContentUpdated: (updated) async {
                                await km.updateDocument(
                                  doc.id,
                                  description: updated,
                                );
                              },
                              onEdit: () => _showEditDocumentModal(doc),
                              onDelete: () => km.softDeleteDocument(doc.id),
                              onExportPdf: exportDocPdf,
                            );
                          }

                          return KnowledgeDocumentCard(
                            doc: doc,
                            tags: docTags,
                            isDark: isDark,
                            onOpen: () => _openDocument(doc),
                            onOpenDetails: openDocDetails,
                            onExportPdf: exportDocPdf,
                            trailingMenu: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.open_in_full,
                                    size: 18,
                                  ),
                                  tooltip: 'Abrir em tela cheia',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () =>
                                      openDocDetails(fullScreen: true),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 20),
                                  onSelected: (val) {
                                    if (val == 'open') _openDocument(doc);
                                    if (val == 'details') openDocDetails();
                                    if (val == 'external') {
                                      _openDocumentExternal(doc);
                                    }
                                    if (val == 'export_pdf') exportDocPdf();
                                    if (val == 'edit')
                                      _showEditDocumentModal(doc);
                                    if (val == 'delete') {
                                      km.softDeleteDocument(doc.id);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'open',
                                      child: Text('Abrir Arquivo no App'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'details',
                                      child: Text('Anotações & Referências'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'external',
                                      child: Text('Abrir Externamente'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'export_pdf',
                                      child: Text('Exportar Resumo em PDF'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Editar'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text(
                                        'Excluir',
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  // ==========================================
  // ABA 4: RECURSOS EXTERNOS E JW.ORG
  // ==========================================

  Widget _buildResourcesTab(bool isDark) {
    final km = ref.watch(knowledgeManagerProvider);

    return StreamBuilder<List<KnowledgeResourceEntry>>(
      stream: km.watchResources(
        category: _selectedResourceCategory,
        areaId: _selectedAreaId,
        query: _searchQuery.isNotEmpty ? _searchQuery : null,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allResources = snapshot.data ?? [];
        if (allResources.isEmpty) {
          return _buildEmptyState(
            icon: Icons.link_rounded,
            title: 'Nenhum recurso cadastrado',
            subtitle: 'Salve links do JW.org, lições bíblicas ou vídeos úteis para as conversas.',
            isDark: isDark,
            actionLabel: 'Novo Recurso',
            onAction: _showCreateResourceModal,
          );
        }

        // Extrai todas as tags únicas dos recursos
        final allResourceTags = <String>{};
        for (final r in allResources) {
          try {
            final list = jsonDecode(r.tags) as List;
            for (final item in list) {
              final t = item.toString().trim();
              if (t.isNotEmpty) allResourceTags.add(t);
            }
          } catch (e, st) {
            AppLogger.debug(
              'Falha ao ler tags JSON de recurso (${r.id}): $e',
              st,
            );
          }
        }

        final resources = allResources.where((r) {
          if (_selectedResourceTag == null) return true;
          try {
            final list = (jsonDecode(r.tags) as List)
                .map((e) => e.toString())
                .toList();
            return list.contains(_selectedResourceTag);
          } catch (e, st) {
            AppLogger.debug(
              'Falha ao filtrar tags JSON de recurso (${r.id}): $e',
              st,
            );
            return false;
          }
        }).toList();

        return Column(
          children: [
            // Filtros de Tags dos Recursos
            if (allResourceTags.isNotEmpty)
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    FilterChip(
                      label: const Text('Todas as Tags'),
                      selected: _selectedResourceTag == null,
                      onSelected: (val) =>
                          setState(() => _selectedResourceTag = null),
                      backgroundColor: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                    ),
                    const SizedBox(width: 8),
                    ...allResourceTags.map((tag) {
                      final isSelected = _selectedResourceTag == tag;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          avatar: Icon(
                            Icons.tag,
                            size: 14,
                            color: isSelected ? Colors.white : Colors.teal,
                          ),
                          label: Text(tag),
                          selected: isSelected,
                          onSelected: (val) => setState(
                            () => _selectedResourceTag = val ? tag : null,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

            NotionViewModeBar(
              mode: _resourcesViewMode,
              availableModes: const [
                NotionViewMode.list,
                NotionViewMode.table,
                NotionViewMode.gallery,
              ],
              onChanged: (m) => setState(() => _resourcesViewMode = m),
              isDark: isDark,
              keyPrefix: 'resources_view',
            ),

            if (_resourcesViewMode == NotionViewMode.table)
              Expanded(
                child: NotionResponsiveTable(
                  isDark: isDark,
                  columns: const [
                    NotionTableColumnDef(label: 'Recurso', width: 240),
                    NotionTableColumnDef(label: 'Tipo', width: 130),
                    NotionTableColumnDef(label: 'Link / Descrição', width: 250),
                    NotionTableColumnDef(label: 'Atualizado', width: 100),
                  ],
                  rows: [
                    for (final r in resources)
                      NotionTableRowItem(
                        onTap: () => _showEditResourceModal(r),
                        cells: [
                          Text(
                            r.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          KnowledgePillBadge(
                            label: r.resourceType,
                            color: Colors.teal,
                            isDark: isDark,
                          ),
                          Text(
                            r.url?.trim().isNotEmpty == true
                                ? r.url!
                                : MarkdownPreviewText.cleanMarkdown(
                                    r.description ?? '—',
                                  ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            _formatDate(r.updatedAt),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                  ],
                ),
              )
            else if (_resourcesViewMode == NotionViewMode.gallery)
              Expanded(
                child: NotionGalleryGrid<KnowledgeResourceEntry>(
                  items: resources,
                  itemBuilder: (ctx, r) {
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
                        onTap: () {
                          if (r.url != null && r.url!.isNotEmpty) {
                            _openUrl(r.url!);
                          } else {
                            _showEditResourceModal(r);
                          }
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.teal.withValues(
                                      alpha: isDark ? 0.35 : 0.2,
                                    ),
                                    Colors.teal.withValues(
                                      alpha: isDark ? 0.12 : 0.06,
                                    ),
                                  ],
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.link_rounded,
                                    size: 16,
                                    color: Colors.teal,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      r.resourceType.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.teal,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _formatDate(r.updatedAt),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.title,
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
                                        r.description?.trim().isNotEmpty == true
                                            ? MarkdownPreviewText.cleanMarkdown(
                                                r.description!,
                                              )
                                            : (r.url ?? ''),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? const Color(0xFF94A3B8)
                                              : AppTheme.textMuted,
                                        ),
                                      ),
                                    ),
                                    KnowledgePillBadge(
                                      label: r.category,
                                      color: Colors.teal,
                                      isDark: isDark,
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
                ),
              )
            else
              Expanded(
                child: KnowledgeResponsiveCardGrid(
                  children: [
                    for (final r in resources)
                      Builder(
                        builder: (ctx) {
                          List<String> resTags = [];
                          try {
                            resTags = (jsonDecode(r.tags) as List)
                                .map((e) => e.toString())
                                .toList();
                          } catch (e, st) {
                            AppLogger.debug(
                              'Falha ao ler tags JSON na listagem de recursos (${r.id}): $e',
                              st,
                            );
                          }

                          Future<void> exportResPdf() async {
                            try {
                              await KnowledgeAndEmailPdfService.exportSingleItemPdf(
                                title: r.title,
                                content:
                                    r.description?.trim().isNotEmpty == true
                                    ? r.description!
                                    : 'Recurso salvo na Base de Conhecimento.',
                                itemType: 'Recurso',
                                category: r.category,
                                url: r.url,
                                tags: resTags,
                                updatedAt: r.updatedAt,
                              );
                              if (!ctx.mounted) return;
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'PDF do recurso gerado com sucesso!',
                                  ),
                                ),
                              );
                            } catch (e, st) {
                              AppLogger.warning(
                                'Falha ao exportar PDF do recurso (${r.id})',
                                e,
                                st,
                              );
                              if (!ctx.mounted) return;
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text('Erro ao gerar PDF: $e'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }

                          return KnowledgeResourceCard(
                            resource: r,
                            tags: resTags,
                            isDark: isDark,
                            onTap: () {
                              final hasDesc =
                                  r.description != null &&
                                  r.description!.trim().isNotEmpty;
                              showKnowledgeItemReader(
                                context,
                                title: r.title,
                                content: r.description ?? 'Recurso / Link salvo na Base de Conhecimento.',
                                category: r.category,
                                itemType: 'Recurso',
                                url: r.url,
                                tags: resTags,
                                updatedAt: r.updatedAt,
                                allowHighlights: hasDesc,
                                backlinkTargetType: 'resource',
                                backlinkTargetId: r.id,
                                onContentUpdated: hasDesc
                                    ? (updated) async {
                                        await km.updateResource(
                                          r.id,
                                          description: updated,
                                        );
                                      }
                                    : null,
                                onEdit: () => _showEditResourceModal(r),
                                onDelete: () => km.softDeleteResource(r.id),
                                onExportPdf: exportResPdf,
                              );
                            },
                            onOpenUrl: r.url != null && r.url!.isNotEmpty
                                ? () => _openUrl(r.url!)
                                : null,
                            onExportPdf: exportResPdf,
                            trailingMenu: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.open_in_full,
                                    size: 18,
                                  ),
                                  tooltip: 'Abrir em tela cheia',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () {
                                    final hasDesc =
                                        r.description != null &&
                                        r.description!.trim().isNotEmpty;
                                    showKnowledgeItemReader(
                                      context,
                                      title: r.title,
                                      content: r.description ?? 'Recurso / Link salvo na Base de Conhecimento.',
                                      category: r.category,
                                      itemType: 'Recurso',
                                      url: r.url,
                                      tags: resTags,
                                      updatedAt: r.updatedAt,
                                      allowHighlights: hasDesc,
                                      backlinkTargetType: 'resource',
                                      backlinkTargetId: r.id,
                                      initialFullScreen: true,
                                      onContentUpdated: hasDesc
                                          ? (updated) async {
                                              await km.updateResource(
                                                r.id,
                                                description: updated,
                                              );
                                            }
                                          : null,
                                      onEdit: () => _showEditResourceModal(r),
                                      onDelete: () =>
                                          km.softDeleteResource(r.id),
                                      onExportPdf: exportResPdf,
                                    );
                                  },
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 20),
                                  onSelected: (val) {
                                    if (val == 'open' &&
                                        r.url != null &&
                                        r.url!.isNotEmpty) {
                                      _openUrl(r.url!);
                                    }
                                    if (val == 'export_pdf') exportResPdf();
                                    if (val == 'edit')
                                      _showEditResourceModal(r);
                                    if (val == 'delete') {
                                      km.softDeleteResource(r.id);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    if (r.url != null && r.url!.isNotEmpty)
                                      const PopupMenuItem(
                                        value: 'open',
                                        child: Text('Abrir Link'),
                                      ),
                                    const PopupMenuItem(
                                      value: 'export_pdf',
                                      child: Text('Exportar em PDF'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Editar'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text(
                                        'Excluir',
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  // ==========================================
  // MODAIS E CRIAÇÃO
  // ==========================================

  void _showAddKnowledgeItemMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF8B5CF6),
                  child: Icon(Icons.note_add, color: Colors.white),
                ),
                title: const Text(
                  'Nova Nota',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Criar uma anotação de estudo ou pesquisa',
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showCreateNoteModal();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFF59E0B),
                  child: Icon(Icons.help_outline, color: Colors.white),
                ),
                title: const Text(
                  'Nova Dúvida Teocrática',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Registrar pergunta de morador ou estudo'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showCreateQuestionModal();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.primaryBlue,
                  child: Icon(Icons.upload_file, color: Colors.white),
                ),
                title: const Text(
                  'Anexar Documento',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Importar arquivo PDF ou texto local'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickAndRegisterDocument();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.teal,
                  child: Icon(Icons.link, color: Colors.white),
                ),
                title: const Text(
                  'Novo Recurso / Link JW',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Salvar link de publicação ou artigo'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showCreateResourceModal();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF0F766E),
                  child: Icon(Icons.description_outlined, color: Colors.white),
                ),
                title: const Text(
                  'Nova Carta, Pauta ou Ata',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Criar documento oficial timbrado para PDF, PNG, DOCX ou e-mail',
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _tabController.animateTo(4);
                  _createOfficialDocFromKb();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAreasFilterBar(bool isDark, Color themePrimary) {
    final km = ref.watch(knowledgeManagerProvider);
    return StreamBuilder<List<KnowledgeAreaEntry>>(
      stream: km.watchAreas(),
      builder: (context, snapshot) {
        final areas = snapshot.data ?? const <KnowledgeAreaEntry>[];
        return Container(
          height: 46,
          color: isDark ? const Color(0xFF0E1422) : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ChoiceChip(
                key: const Key('area_chip_all'),
                avatar: Icon(
                  Icons.layers_outlined,
                  size: 15,
                  color: themePrimary,
                ),
                label: const Text(
                  'Todas as Áreas',
                  style: TextStyle(fontSize: 12),
                ),
                selected: _selectedAreaId == null,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onSelected: (_) => setState(() => _selectedAreaId = null),
              ),
              const SizedBox(width: 6),
              for (final area in areas)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    key: Key('area_chip_${area.id}'),
                    avatar: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(
                          int.tryParse(
                                'FF${(area.colorHex ?? '#6366F1').replaceFirst('#', '')}',
                                radix: 16,
                              ) ??
                              0xFF6366F1,
                        ),
                      ),
                    ),
                    label: Text(
                      area.name,
                      style: const TextStyle(fontSize: 12),
                    ),
                    selected: _selectedAreaId == area.id,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onSelected: (selected) => setState(
                      () => _selectedAreaId = selected ? area.id : null,
                    ),
                  ),
                ),
              ActionChip(
                key: const Key('btn_manage_areas_chip'),
                avatar: const Icon(Icons.add_circle_outline, size: 15),
                label: const Text('Áreas', style: TextStyle(fontSize: 12)),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onPressed: _openManageAreasModal,
              ),
            ],
          ),
        );
      },
    );
  }

  void _openManageAreasModal() {
    final km = ref.read(knowledgeManagerProvider);
    unawaited(
      showManageAreasDialog(
        context,
        km: km,
        currentAreaId: _selectedAreaId,
        onAreaSelected: (areaId) {
          if (mounted) setState(() => _selectedAreaId = areaId);
        },
      ),
    );
  }

  void _openWeeklyReviewModal() {
    final db = ref.read(databaseProvider);
    final km = ref.read(knowledgeManagerProvider);
    unawaited(
      showWeeklyReviewDialog(
        context,
        db: db,
        km: km,
        onAnswerQuestion: _showAnswerQuestionModal,
        onOpenProject: (projectId) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProjectDetailScreen(projectId: projectId),
            ),
          );
        },
        onOpenInbox: () {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const InboxScreen()));
        },
      ),
    );
  }

  void _openNotionImportModal() {
    final db = ref.read(databaseProvider);
    unawaited(
      showNotionImportDialog(context, db: db, fallbackAreaId: _selectedAreaId),
    );
  }

  Future<AppReferenceCandidate?> _createInlineNoteFromEditor(
    String title,
    String? areaId,
  ) async {
    final km = ref.read(knowledgeManagerProvider);
    final created = await km.createNote(
      title: title,
      content: '',
      areaId: areaId,
    );
    return AppReferenceCandidate(
      category: AppRefCategory.note,
      id: created.id,
      title: created.title,
      subtitle: 'Nota vinculada',
    );
  }

  Widget _buildAreaDropdown({
    required KnowledgeManager km,
    required String? selectedAreaId,
    required ValueChanged<String?> onChanged,
  }) {
    return StreamBuilder<List<KnowledgeAreaEntry>>(
      stream: km.watchAreas(),
      builder: (context, snap) {
        final areas = snap.data ?? const <KnowledgeAreaEntry>[];
        if (areas.isEmpty) return const SizedBox.shrink();
        final effective = areas.any((a) => a.id == selectedAreaId)
            ? selectedAreaId
            : null;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String?>(
            initialValue: effective,
            decoration: const InputDecoration(
              labelText: 'Área P.A.R.A. (Opcional)',
              prefixIcon: Icon(Icons.layers_outlined, size: 18),
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Sem área vinculada'),
              ),
              for (final area in areas)
                DropdownMenuItem<String?>(
                  value: area.id,
                  child: Text(area.name),
                ),
            ],
            onChanged: onChanged,
          ),
        );
      },
    );
  }

  Widget _buildParentNoteDropdown({
    required KnowledgeManager km,
    required String? excludeNoteId,
    required String? selectedParentId,
    required ValueChanged<String?> onChanged,
  }) {
    return StreamBuilder<List<KnowledgeNoteEntry>>(
      stream: km.watchNotes(),
      builder: (context, snap) {
        final notes = (snap.data ?? const <KnowledgeNoteEntry>[])
            .where((n) => n.id != excludeNoteId)
            .toList();
        if (notes.isEmpty) return const SizedBox.shrink();
        final effective = notes.any((n) => n.id == selectedParentId)
            ? selectedParentId
            : null;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String?>(
            initialValue: effective,
            decoration: const InputDecoration(
              labelText: 'Subpágina de (Nota Pai)',
              prefixIcon: Icon(Icons.account_tree_outlined, size: 18),
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Nota de nível principal'),
              ),
              for (final n in notes)
                DropdownMenuItem<String?>(
                  value: n.id,
                  child: Text(
                    n.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: onChanged,
          ),
        );
      },
    );
  }

  void _showCreateNoteModal({
    String? initialParentNoteId,
    String? initialAreaId,
    String? initialStatus,
  }) {
    _showNoteFormSheet(
      initialParentNoteId: initialParentNoteId,
      initialAreaId: initialAreaId,
      initialStatus: initialStatus,
    );
  }

  void _showEditNoteModal(KnowledgeNoteEntry note) {
    _showNoteFormSheet(existingNote: note);
  }

  void _showNoteFormSheet({
    KnowledgeNoteEntry? existingNote,
    String? initialParentNoteId,
    String? initialAreaId,
    String? initialStatus,
  }) {
    final isEdit = existingNote != null;
    List<String> existingTags = [];
    if (existingNote != null) {
      try {
        existingTags = (jsonDecode(existingNote.tags) as List)
            .map((e) => e.toString())
            .where((t) => !t.startsWith('research:'))
            .toList();
      } catch (e, st) {
        AppLogger.debug(
          'Falha ao decodificar tags ao editar nota (${existingNote.id}): $e',
          st,
        );
      }
    }

    String category = existingNote?.category ?? 'general';
    String? areaId = isEdit
        ? existingNote.areaId
        : (initialAreaId ?? _selectedAreaId);
    String? parentNoteId = isEdit
        ? existingNote.parentNoteId
        : initialParentNoteId;
    final propMap = isEdit
        ? KnowledgeManager.decodeProperties(existingNote.propertiesJson)
        : <String, dynamic>{};
    final propMeta = isEdit
        ? NotePropertyMeta.fromJson(existingNote.propertiesJson)
        : null;
    String statusProp = isEdit
        ? propMeta!.status
        : (initialStatus ?? 'rascunho');
    String priorityProp = isEdit
        ? ([
                'baixa',
                'normal',
                'alta',
              ].contains(propMeta!.priority.toLowerCase())
              ? propMeta.priority.toLowerCase()
              : 'normal')
        : 'normal';
    bool spacedReviewEnabled = isEdit && existingNote.nextReviewAt != null;
    NoteCoverConfig? coverConfig = isEdit
        ? NoteCoverConfig.fromPropertiesJson(existingNote.propertiesJson)
        : null;
    final km = ref.read(knowledgeManagerProvider);
    final db = ref.read(repositoryProvider).db;

    showAdaptiveMinistrySheet(
      context: context,
      title: isEdit
          ? 'Editar Nota'
          : (parentNoteId != null ? 'Nova Subpágina' : 'Nova Nota'),
      titleLeading: Icon(
        isEdit ? Icons.edit_note : Icons.note_add,
        color: const Color(0xFF8B5CF6),
      ),
      builder: (ctx, scroll) => ManagedTextControllers(
        initialTexts: isEdit
            ? [
                existingNote.title,
                existingNote.content,
                existingTags.join(', '),
              ]
            : const ['', '', ''],
        customFactories: [
          null,
          (text) => RichFormattedEditingController.fromMarkup(text),
          null,
        ],
        builder: (ctx, ctrls) {
          final titleCtrl = ctrls[0];
          final contentCtrl = ctrls[1];
          final tagsCtrl = ctrls[2];

          Future<void> save({required bool sendToResearch}) async {
            final title = titleCtrl.text.trim();
            if (title.isEmpty) return;
            final content = RichFormattedEditingController.readMarkup(
              contentCtrl,
            ).trim();
            final rawTags = tagsCtrl.text
                .split(',')
                .map((t) => t.trim())
                .where((t) => t.isNotEmpty)
                .toList();

            if (isEdit) {
              try {
                final internal = (jsonDecode(existingNote.tags) as List)
                    .map((e) => e.toString())
                    .where((t) => t.startsWith('research:'))
                    .toList();
                rawTags.addAll(internal);
              } catch (e, st) {
                AppLogger.debug(
                  'Falha ao preservar tags research ao editar nota (${existingNote.id}): $e',
                  st,
                );
              }
            }

            var mergedProps =
                NoteCoverConfig.mergeCoverIntoPropertiesMap(
                    propMap,
                    coverConfig,
                  )
                  ..['status'] = statusProp
                  ..['priority'] = priorityProp;

            try {
              if (!isEdit) {
                final created = await km.createNote(
                  title: title,
                  content: content,
                  category: category,
                  areaId: areaId,
                  parentNoteId: parentNoteId,
                  properties: mergedProps,
                  nextReviewAt: spacedReviewEnabled
                      ? DateTime.now().toUtc()
                      : null,
                  tags: rawTags,
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (sendToResearch) {
                  await _transformNoteToResearch(created);
                }
              } else {
                await km.updateNote(
                  existingNote.id,
                  title: title,
                  content: content,
                  category: category,
                  areaId: areaId,
                  clearAreaId: areaId == null,
                  parentNoteId: parentNoteId,
                  clearParentNoteId: parentNoteId == null,
                  properties: mergedProps,
                  nextReviewAt: spacedReviewEnabled
                      ? (existingNote.nextReviewAt ?? DateTime.now().toUtc())
                      : null,
                  clearNextReviewAt: !spacedReviewEnabled,
                  tags: rawTags,
                );
                final updatedNote = sendToResearch
                    ? await km.getNoteById(existingNote.id)
                    : null;
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (updatedNote != null) {
                  await _transformNoteToResearch(updatedNote);
                }
              }
            } on ArgumentError catch (e) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(e.message.toString()),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            }
          }

          return StatefulBuilder(
            builder: (ctx, setSheetState) {
              final keyboardOpen = MediaQuery.viewInsetsOf(ctx).bottom > 40;
              final catLabel =
                  const {
                    'general': 'Geral',
                    'ministry': 'Ministério',
                    'research': 'Pesquisa',
                    'pastoral': 'Pastoral',
                  }[category] ??
                  category;
              final statusLabel = NotePropertyMeta.statusLabel(statusProp);
              final propSummary = '$catLabel • $statusLabel • $priorityProp';

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      controller: scroll,
                      physics: const ClampingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        16,
                        keyboardOpen ? 6 : 16,
                        16,
                        keyboardOpen ? 6 : 12,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (coverConfig != null &&
                              coverConfig!.hasCustomCover &&
                              !keyboardOpen) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                children: [
                                  NoteCoverHeaderBackground(
                                    cover: coverConfig!,
                                    height: 68,
                                  ),
                                  Positioned(
                                    right: 8,
                                    top: 8,
                                    child: FilledButton.tonalIcon(
                                      style: FilledButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        backgroundColor: Colors.black
                                            .withValues(alpha: 0.45),
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () async {
                                        final picked =
                                            await showNoteCoverPickerDialog(
                                              ctx,
                                              initialCover: coverConfig,
                                              pictureBankDb: db,
                                              previewTitle: titleCtrl.text,
                                            );
                                        if (picked != null) {
                                          setSheetState(() {
                                            coverConfig = picked.cleared
                                                ? null
                                                : picked.cover;
                                          });
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.palette_outlined,
                                        size: 15,
                                      ),
                                      label: const Text(
                                        'Capa',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: titleCtrl,
                                  autofocus: !isEdit,
                                  decoration: InputDecoration(
                                    labelText: 'Título da Nota',
                                    isDense: keyboardOpen,
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              if (coverConfig == null ||
                                  !coverConfig!.hasCustomCover ||
                                  keyboardOpen) ...[
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  key: const Key('btn_note_form_cover'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 12,
                                    ),
                                  ),
                                  onPressed: () async {
                                    final picked =
                                        await showNoteCoverPickerDialog(
                                          ctx,
                                          initialCover: coverConfig,
                                          pictureBankDb: db,
                                          previewTitle: titleCtrl.text,
                                        );
                                    if (picked != null) {
                                      setSheetState(() {
                                        coverConfig = picked.cleared
                                            ? null
                                            : picked.cover;
                                      });
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.palette_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Capa'),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: keyboardOpen ? 8 : 10),
                          // Editor Principal priorizado logo no topo para digitação confortável
                          SecondBrainRichEditor(
                            controller: contentCtrl,
                            labelText: 'Conteúdo da Nota',
                            minLines: keyboardOpen ? 5 : (isEdit ? 10 : 8),
                            maxLines: keyboardOpen ? 10 : 20,
                            onCreateInlineNote: (title) =>
                                _createInlineNoteFromEditor(title, areaId),
                          ),
                          SizedBox(height: keyboardOpen ? 8 : 12),
                          // Propriedades recolhíveis (não ocupam o espaço de digitação!)
                          CollapsibleMetadataSection(
                            key: const Key('note_form_metadata_section'),
                            title: 'Propriedades da Nota',
                            summary: propSummary,
                            initiallyExpanded: false,
                            children: [
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue:
                                          [
                                            'general',
                                            'ministry',
                                            'research',
                                            'pastoral',
                                          ].contains(category)
                                          ? category
                                          : 'general',
                                      decoration: const InputDecoration(
                                        labelText: 'Categoria',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'general',
                                          child: Text('Geral'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'ministry',
                                          child: Text('Ministério'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'research',
                                          child: Text('Pesquisa'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'pastoral',
                                          child: Text('Pastoral'),
                                        ),
                                      ],
                                      onChanged: (v) => setSheetState(
                                        () => category = v ?? 'general',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: statusProp,
                                      decoration: const InputDecoration(
                                        labelText: 'Status (Kanban)',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'rascunho',
                                          child: Text('Rascunho'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'em_estudo',
                                          child: Text('Em Estudo'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'revisar',
                                          child: Text('Revisar'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'concluido',
                                          child: Text('Concluído'),
                                        ),
                                      ],
                                      onChanged: (v) => setSheetState(
                                        () => statusProp = v ?? 'rascunho',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _buildAreaDropdown(
                                km: km,
                                selectedAreaId: areaId,
                                onChanged: (v) =>
                                    setSheetState(() => areaId = v),
                              ),
                              _buildParentNoteDropdown(
                                km: km,
                                excludeNoteId: existingNote?.id,
                                selectedParentId: parentNoteId,
                                onChanged: (v) =>
                                    setSheetState(() => parentNoteId = v),
                              ),
                              TextField(
                                controller: tagsCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Tags (separadas por vírgula)',
                                  hintText: 'Ex: pregação, consolo, promessas',
                                  prefixIcon: Icon(Icons.tag, size: 18),
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                initialValue: priorityProp,
                                decoration: const InputDecoration(
                                  labelText: 'Prioridade',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'baixa',
                                    child: Text('Baixa'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'normal',
                                    child: Text('Normal'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'alta',
                                    child: Text('Alta'),
                                  ),
                                ],
                                onChanged: (v) => setSheetState(
                                  () => priorityProp = v ?? 'normal',
                                ),
                              ),
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Incluir na Revisão Espaçada (SM-2)',
                                  style: TextStyle(fontSize: 13.5),
                                ),
                                value: spacedReviewEnabled,
                                onChanged: (val) => setSheetState(
                                  () => spacedReviewEnabled = val,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Barra fixa inferior sempre visível para salvar mesmo com teclado aberto
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Theme.of(ctx).brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.auto_stories, size: 16),
                            label: Text(
                              keyboardOpen ? 'Pesquisar' : 'Salvar & Pesquisar',
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF8B5CF6),
                              side: const BorderSide(color: Color(0xFF8B5CF6)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => save(sendToResearch: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            key: const Key('btn_note_form_save'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B5CF6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => save(sendToResearch: false),
                            child: Text(
                              isEdit ? 'Salvar Alterações' : 'Salvar Nota',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showEditQuestionModal(KnowledgeQuestionEntry q) {
    final km = ref.read(knowledgeManagerProvider);
    String? areaId = q.areaId;
    bool spacedReviewEnabled = q.nextReviewAt != null;

    showAdaptiveMinistrySheet(
      context: context,
      title: 'Editar Dúvida',
      titleLeading: const Icon(Icons.help_outline, color: Color(0xFFF59E0B)),
      builder: (ctx, scroll) => ManagedTextControllers(
        initialTexts: [q.question, q.context ?? '', q.answer ?? ''],
        customFactories: [
          null,
          (text) => RichFormattedEditingController.fromMarkup(text),
          (text) => RichFormattedEditingController.fromMarkup(text),
        ],
        builder: (ctx, ctrls) {
          final qCtrl = ctrls[0];
          final ctxCtrl = ctrls[1];
          final ansCtrl = ctrls[2];

          return StatefulBuilder(
            builder: (ctx, setSheetState) => SingleChildScrollView(
              controller: scroll,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: qCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Pergunta do Morador ou Pesquisa',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SecondBrainRichEditor(
                    controller: ansCtrl,
                    labelText: 'Resposta Bíblica',
                    minLines: 4,
                    maxLines: 10,
                    onCreateInlineNote: (t) =>
                        _createInlineNoteFromEditor(t, areaId),
                  ),
                  const SizedBox(height: 10),
                  CollapsibleMetadataSection(
                    title: 'Contexto, Área & Revisão',
                    summary: spacedReviewEnabled
                        ? 'Revisão SM-2 ativa'
                        : 'Contexto e organização',
                    initiallyExpanded: false,
                    children: [
                      const SizedBox(height: 6),
                      _buildAreaDropdown(
                        km: km,
                        selectedAreaId: areaId,
                        onChanged: (v) => setSheetState(() => areaId = v),
                      ),
                      SecondBrainRichEditor(
                        controller: ctxCtrl,
                        labelText: 'Contexto ou Objeção',
                        minLines: 2,
                        maxLines: 5,
                        enableImagePicker: false,
                        onCreateInlineNote: (t) =>
                            _createInlineNoteFromEditor(t, areaId),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Incluir na Revisão Espaçada (SM-2)',
                          style: TextStyle(fontSize: 13.5),
                        ),
                        value: spacedReviewEnabled,
                        onChanged: (val) =>
                            setSheetState(() => spacedReviewEnabled = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      final question = qCtrl.text.trim();
                      if (question.isEmpty) return;
                      final ctxText = RichFormattedEditingController.readMarkup(
                        ctxCtrl,
                      ).trim();
                      final ansText = RichFormattedEditingController.readMarkup(
                        ansCtrl,
                      ).trim();
                      await km.updateQuestion(
                        q.id,
                        question: question,
                        context: ctxText.isNotEmpty ? ctxText : null,
                        answer: ansText.isNotEmpty ? ansText : null,
                        areaId: areaId,
                        clearAreaId: areaId == null,
                        nextReviewAt: spacedReviewEnabled
                            ? (q.nextReviewAt ?? DateTime.now().toUtc())
                            : null,
                        clearNextReviewAt: !spacedReviewEnabled,
                        status: ansText.isNotEmpty ? 'answered' : 'unanswered',
                      );
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                    child: const Text(
                      'Salvar Alterações',
                      style: TextStyle(fontWeight: FontWeight.bold),
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

  void _showEditDocumentModal(KnowledgeDocumentEntry doc) {
    final km = ref.read(knowledgeManagerProvider);
    List<String> existingTags = [];
    try {
      existingTags = (jsonDecode(doc.tags) as List)
          .map((e) => e.toString())
          .toList();
    } catch (e, st) {
      AppLogger.debug(
        'Falha ao ler tags JSON do documento (${doc.id}): $e',
        st,
      );
    }
    String category = doc.category;
    String? areaId = doc.areaId;

    showAdaptiveMinistrySheet(
      context: context,
      title: 'Editar Documento',
      titleLeading: const Icon(Icons.description, color: AppTheme.primaryBlue),
      builder: (ctx, scroll) => ManagedTextControllers(
        initialTexts: [
          doc.title,
          existingTags.join(', '),
          doc.description ?? '',
        ],
        customFactories: [
          null,
          null,
          (text) => RichFormattedEditingController.fromMarkup(text),
        ],
        builder: (ctx, ctrls) {
          final titleCtrl = ctrls[0];
          final tagsCtrl = ctrls[1];
          final descCtrl = ctrls[2];

          return StatefulBuilder(
            builder: (ctx, setSheetState) {
              return SingleChildScrollView(
                controller: scroll,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Título do Documento',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    RichMarkdownToolbar(controller: descCtrl),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descCtrl,
                      maxLines: 5,
                      scrollPadding: const EdgeInsets.only(bottom: 140),
                      decoration: const InputDecoration(
                        labelText: 'Anotações e Referências',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    CollapsibleMetadataSection(
                      title: 'Categoria, Área & Tags',
                      summary: 'Categoria: $category',
                      initiallyExpanded: false,
                      children: [
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue:
                              [
                                'manual',
                                'study',
                                'outline',
                                'other',
                              ].contains(category)
                              ? category
                              : 'manual',
                          decoration: const InputDecoration(
                            labelText: 'Categoria',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'manual',
                              child: Text('Manual / Guia'),
                            ),
                            DropdownMenuItem(
                              value: 'study',
                              child: Text('Estudo'),
                            ),
                            DropdownMenuItem(
                              value: 'outline',
                              child: Text('Esboço'),
                            ),
                            DropdownMenuItem(
                              value: 'other',
                              child: Text('Outro'),
                            ),
                          ],
                          onChanged: (v) =>
                              setSheetState(() => category = v ?? 'manual'),
                        ),
                        const SizedBox(height: 10),
                        _buildAreaDropdown(
                          km: km,
                          selectedAreaId: areaId,
                          onChanged: (v) => setSheetState(() => areaId = v),
                        ),
                        TextField(
                          controller: tagsCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Tags (separadas por vírgula)',
                            hintText: 'Ex: ministério, apostilas, roteiros',
                            prefixIcon: Icon(Icons.tag, size: 18),
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        final title = titleCtrl.text.trim();
                        if (title.isEmpty) return;
                        final desc = RichFormattedEditingController.readMarkup(
                          descCtrl,
                        ).trim();
                        final rawTags = tagsCtrl.text
                            .split(',')
                            .map((t) => t.trim())
                            .where((t) => t.isNotEmpty)
                            .toList();
                        await km.updateDocument(
                          doc.id,
                          title: title,
                          description: desc.isNotEmpty ? desc : '',
                          category: category,
                          areaId: areaId,
                          clearAreaId: areaId == null,
                          tags: rawTags,
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      child: const Text(
                        'Salvar Alterações',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showEditResourceModal(KnowledgeResourceEntry resource) {
    final km = ref.read(knowledgeManagerProvider);
    List<String> existingTags = [];
    try {
      existingTags = (jsonDecode(resource.tags) as List)
          .map((e) => e.toString())
          .toList();
    } catch (e, st) {
      AppLogger.debug(
        'Falha ao ler tags JSON do recurso (${resource.id}): $e',
        st,
      );
    }
    String resourceType = resource.resourceType;
    String category = resource.category;
    String? areaId = resource.areaId;

    showAdaptiveMinistrySheet(
      context: context,
      title: 'Editar Recurso',
      titleLeading: const Icon(Icons.link, color: Colors.teal),
      builder: (ctx, scroll) => ManagedTextControllers(
        initialTexts: [
          resource.title,
          resource.url ?? '',
          resource.description ?? '',
          existingTags.join(', '),
        ],
        customFactories: [
          null,
          null,
          (text) => RichFormattedEditingController.fromMarkup(text),
          null,
        ],
        builder: (ctx, ctrls) {
          final titleCtrl = ctrls[0];
          final urlCtrl = ctrls[1];
          final descCtrl = ctrls[2];
          final tagsCtrl = ctrls[3];

          return StatefulBuilder(
            builder: (ctx, setSheetState) {
              return SingleChildScrollView(
                controller: scroll,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Título do Recurso',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: urlCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Link / URL (JW.org ou pesquisa)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    RichMarkdownToolbar(controller: descCtrl),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descCtrl,
                      maxLines: 4,
                      scrollPadding: const EdgeInsets.only(bottom: 140),
                      decoration: const InputDecoration(
                        labelText: 'Descrição / Para que serve?',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    CollapsibleMetadataSection(
                      title: 'Tipo, Área & Tags',
                      summary: 'Tipo: $resourceType',
                      initiallyExpanded: false,
                      children: [
                        const SizedBox(height: 6),
                        _buildAreaDropdown(
                          km: km,
                          selectedAreaId: areaId,
                          onChanged: (v) => setSheetState(() => areaId = v),
                        ),
                        TextField(
                          controller: tagsCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Tags (separadas por vírgula)',
                            hintText: 'Ex: jw, vídeos, pregação',
                            prefixIcon: Icon(Icons.tag, size: 18),
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue:
                              [
                                'jw_pub',
                                'video',
                                'article',
                                'scripture_chain',
                                'link',
                              ].contains(resourceType)
                              ? resourceType
                              : 'link',
                          decoration: const InputDecoration(
                            labelText: 'Tipo de Recurso',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'jw_pub',
                              child: Text('Publicação JW'),
                            ),
                            DropdownMenuItem(
                              value: 'video',
                              child: Text('Vídeo'),
                            ),
                            DropdownMenuItem(
                              value: 'article',
                              child: Text('Artigo de Revista'),
                            ),
                            DropdownMenuItem(
                              value: 'scripture_chain',
                              child: Text('Cadeia de Textos'),
                            ),
                            DropdownMenuItem(
                              value: 'link',
                              child: Text('Outro Link'),
                            ),
                          ],
                          onChanged: (v) =>
                              setSheetState(() => resourceType = v ?? 'link'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        final title = titleCtrl.text.trim();
                        if (title.isEmpty) return;
                        final urlText = urlCtrl.text.trim();
                        final descText =
                            RichFormattedEditingController.readMarkup(descCtrl)
                                .trim();
                        final rawTags = tagsCtrl.text
                            .split(',')
                            .map((t) => t.trim())
                            .where((t) => t.isNotEmpty)
                            .toList();
                        await km.updateResource(
                          resource.id,
                          title: title,
                          url: urlText.isNotEmpty ? urlText : null,
                          description: descText.isNotEmpty ? descText : null,
                          resourceType: resourceType,
                          category: category,
                          areaId: areaId,
                          clearAreaId: areaId == null,
                          tags: rawTags,
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      child: const Text(
                        'Salvar Alterações',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _transformNoteToResearch(KnowledgeNoteEntry note) async {
    final researchMgr = ref.read(researchManagerProvider);
    final summary = note.content.length > 120
        ? '${note.content.substring(0, 120)}...'
        : note.content;
    final article = await researchMgr.addArticle(
      title: note.title,
      summary: summary,
      content: note.content,
      tags: [note.category, 'Nota Vinculada', 'knowledge_note:${note.id}'],
    );

    // Mantém os dois conectados adicionando o vínculo nas tags da nota
    final km = ref.read(knowledgeManagerProvider);
    List<String> currentTags = [];
    try {
      currentTags = (jsonDecode(note.tags) as List)
          .map((e) => e.toString())
          .toList();
    } catch (e, st) {
      AppLogger.debug(
        'Falha ao ler tags JSON ao vincular nota à pesquisa (${note.id}): $e',
        st,
      );
    }
    if (!currentTags.contains('research:${article.id}')) {
      currentTags.add('research:${article.id}');
      await km.updateNote(note.id, tags: currentTags);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Nota "${note.title}" transformada e vinculada à aba de Pesquisas!',
          ),
          action: SnackBarAction(
            label: 'Ver Pesquisas',
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ResearchScreen()));
            },
          ),
        ),
      );
    }
  }

  List<String> _decodeNoteTagsSafe(String rawTags) {
    try {
      return (jsonDecode(rawTags) as List)
          .map((e) => e.toString().trim())
          .where((t) => t.isNotEmpty && !t.startsWith('research:'))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _customizeNoteCover(KnowledgeNoteEntry note) async {
    final db = ref.read(repositoryProvider).db;
    final km = ref.read(knowledgeManagerProvider);
    final outcome = await showNoteCoverPickerDialog(
      context,
      initialCover: NoteCoverConfig.fromPropertiesJson(note.propertiesJson),
      pictureBankDb: db,
      previewTitle: note.title,
    );
    if (outcome == null) return;
    final currentProps = NoteCoverConfig.decodePropertiesMap(
      note.propertiesJson,
    );
    final nextProps = NoteCoverConfig.mergeCoverIntoPropertiesMap(
      currentProps,
      outcome.cleared ? null : outcome.cover,
    );
    await km.updateNote(note.id, properties: nextProps);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            outcome.cleared
                ? 'Capa da nota removida.'
                : 'Capa da nota atualizada!',
          ),
        ),
      );
    }
  }

  Future<void> _exportNotePdf(KnowledgeNoteEntry note) async {
    try {
      await KnowledgeAndEmailPdfService.exportSingleItemPdf(
        title: note.title,
        content: note.content,
        itemType: 'Nota',
        category: note.category,
        tags: _decodeNoteTagsSafe(note.tags),
        updatedAt: note.updatedAt,
        cover: NoteCoverConfig.fromPropertiesJson(note.propertiesJson),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF da nota gerado com sucesso!')),
        );
      }
    } catch (e, st) {
      AppLogger.warning('Falha ao gerar PDF da nota (${note.id})', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar PDF: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _exportNote(KnowledgeNoteEntry note) {
    final mdContent =
        '# ${note.title}\n\n**Categoria:** ${note.category}\n**Data:** ${_formatDate(note.updatedAt)}\n\n---\n\n${note.content}';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: const Key('btn_note_export_pdf'),
                leading: const Icon(
                  Icons.picture_as_pdf_outlined,
                  color: Colors.redAccent,
                ),
                title: const Text('Baixar Arquivo PDF (.pdf)'),
                subtitle: const Text(
                  'Gera documento PDF formatado para impressão ou envio',
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _exportNotePdf(note);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy, color: AppTheme.primaryBlue),
                title: const Text('Copiar Texto Formatado'),
                subtitle: const Text(
                  'Copia o conteúdo em Markdown para a área de transferência',
                ),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: mdContent));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Nota copiada para a área de transferência!',
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.download,
                  color: AppTheme.primaryBlue,
                ),
                title: const Text('Baixar Arquivo Markdown (.md)'),
                subtitle: const Text(
                  'Salva localmente o arquivo com formatação',
                ),
                onTap: () {
                  final safeName = note.title.replaceAll(
                    RegExp(r'[^a-zA-Z0-9_-]'),
                    '_',
                  );
                  FileDownloader.download('$safeName.md', mdContent);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Download da anotação concluído!'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _transformQuestionToResearch(KnowledgeQuestionEntry q) async {
    final researchMgr = ref.read(researchManagerProvider);
    final summary = q.context != null && q.context!.isNotEmpty
        ? q.context!
        : 'Dúvida bíblica teocrática registrada';
    final contentBuffer = StringBuffer()
      ..writeln('**Pergunta:** ${q.question}')
      ..writeln();
    if (q.context != null && q.context!.isNotEmpty) {
      contentBuffer.writeln('**Contexto:**\n${q.context}\n');
    }
    if (q.answer != null && q.answer!.isNotEmpty) {
      contentBuffer.writeln('**Resposta Bíblica:**\n${q.answer}');
    }

    await researchMgr.addArticle(
      title: q.question,
      summary: summary.length > 120
          ? '${summary.substring(0, 120)}...'
          : summary,
      content: contentBuffer.toString(),
      tags: ['Dúvida Teocrática', 'knowledge_question:${q.id}'],
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Dúvida transformada e enviada para a aba de Pesquisas!',
          ),
          action: SnackBarAction(
            label: 'Ver Pesquisas',
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ResearchScreen()));
            },
          ),
        ),
      );
    }
  }

  void _exportQuestion(KnowledgeQuestionEntry q) {
    final isAnswered = q.answer != null && q.answer!.isNotEmpty;
    final mdContent =
        '# Pergunta Teocrática: ${q.question}\n\n'
        '**Status:** ${isAnswered ? "Respondida" : "Pendente"}\n'
        '**Data:** ${_formatDate(q.updatedAt)}\n'
        '${q.context != null && q.context!.isNotEmpty ? "\n**Contexto:**\n${q.context}\n" : ""}'
        '${isAnswered ? "\n---\n\n### Resposta Bíblica:\n${q.answer}\n" : ""}';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: const Key('btn_question_export_pdf'),
                leading: const Icon(
                  Icons.picture_as_pdf_outlined,
                  color: Colors.redAccent,
                ),
                title: const Text('Baixar Arquivo PDF (.pdf)'),
                subtitle: const Text(
                  'Gera documento PDF com pergunta, contexto e resposta bíblica',
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final pdfBody = StringBuffer()
                    ..writeln(
                      'Status: ${isAnswered ? "Respondida" : "Pendente"}',
                    );
                  if (q.context != null && q.context!.trim().isNotEmpty) {
                    pdfBody
                      ..writeln()
                      ..writeln('Contexto:')
                      ..writeln(q.context!.trim());
                  }
                  if (isAnswered) {
                    pdfBody
                      ..writeln()
                      ..writeln('Resposta Bíblica:')
                      ..writeln(q.answer!.trim());
                  }
                  try {
                    await KnowledgeAndEmailPdfService.exportSingleItemPdf(
                      title: q.question,
                      content: pdfBody.toString(),
                      itemType: 'Pergunta & Dúvida',
                      category: q.category,
                      updatedAt: q.updatedAt,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('PDF da dúvida gerado com sucesso!'),
                        ),
                      );
                    }
                  } catch (e, st) {
                    AppLogger.warning(
                      'Falha ao exportar dúvida (${q.id}) em PDF',
                      e,
                      st,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Erro ao gerar PDF: $e'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy, color: AppTheme.primaryBlue),
                title: const Text('Copiar Texto Formatado'),
                subtitle: const Text(
                  'Copia a pergunta e resposta em Markdown para a área de transferência',
                ),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: mdContent));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Dúvida copiada para a área de transferência!',
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.download,
                  color: AppTheme.primaryBlue,
                ),
                title: const Text('Baixar Arquivo Markdown (.md)'),
                subtitle: const Text(
                  'Salva localmente o arquivo com formatação',
                ),
                onTap: () {
                  final safeName = q.question.replaceAll(
                    RegExp(r'[^a-zA-Z0-9_-]'),
                    '_',
                  );
                  FileDownloader.download('Duvida_$safeName.md', mdContent);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Download da dúvida teocrática concluído!'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateQuestionModal() {
    final km = ref.read(knowledgeManagerProvider);
    String? areaId = _selectedAreaId;
    bool spacedReviewEnabled = false;

    showAdaptiveMinistrySheet(
      context: context,
      title: 'Nova Dúvida Teocrática',
      titleLeading: const Icon(Icons.help_outline, color: Color(0xFFF59E0B)),
      builder: (ctx, scroll) => ManagedTextControllers(
        initialTexts: const ['', ''],
        customFactories: [
          null,
          (text) => RichFormattedEditingController.fromMarkup(text),
        ],
        builder: (ctx, ctrls) {
          final qCtrl = ctrls[0];
          final ctxCtrl = ctrls[1];

          return StatefulBuilder(
            builder: (ctx, setSheetState) => SingleChildScrollView(
              controller: scroll,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: qCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Pergunta do Morador ou Pesquisa',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SecondBrainRichEditor(
                    controller: ctxCtrl,
                    labelText: 'Contexto ou Objeção (opcional)',
                    minLines: 4,
                    maxLines: 8,
                    onCreateInlineNote: (t) =>
                        _createInlineNoteFromEditor(t, areaId),
                  ),
                  const SizedBox(height: 10),
                  CollapsibleMetadataSection(
                    title: 'Área & Revisão Espaçada',
                    summary: spacedReviewEnabled
                        ? 'Revisão SM-2 ativa'
                        : 'Organização P.A.R.A.',
                    initiallyExpanded: false,
                    children: [
                      const SizedBox(height: 6),
                      _buildAreaDropdown(
                        km: km,
                        selectedAreaId: areaId,
                        onChanged: (v) => setSheetState(() => areaId = v),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Incluir na Revisão Espaçada (SM-2)',
                          style: TextStyle(fontSize: 13.5),
                        ),
                        value: spacedReviewEnabled,
                        onChanged: (val) =>
                            setSheetState(() => spacedReviewEnabled = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      final q = qCtrl.text.trim();
                      if (q.isEmpty) return;
                      final ctxText = RichFormattedEditingController.readMarkup(
                        ctxCtrl,
                      ).trim();
                      await km.createQuestion(
                        question: q,
                        context: ctxText.isNotEmpty ? ctxText : null,
                        areaId: areaId,
                        nextReviewAt: spacedReviewEnabled
                            ? DateTime.now().toUtc()
                            : null,
                      );
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                    child: const Text(
                      'Salvar Dúvida',
                      style: TextStyle(fontWeight: FontWeight.bold),
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

  void _showAnswerQuestionModal(KnowledgeQuestionEntry question) {
    showAdaptiveMinistrySheet(
      context: context,
      title: 'Responder Dúvida',
      titleLeading: const Icon(Icons.menu_book, color: Colors.green),
      builder: (ctx, scroll) => ManagedTextControllers(
        initialTexts: [question.answer ?? ''],
        customFactories: [
          (text) => RichFormattedEditingController.fromMarkup(text),
        ],
        builder: (ctx, ctrls) {
          final ansCtrl = ctrls[0];

          return SingleChildScrollView(
            controller: scroll,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Pergunta: ${question.question}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                SecondBrainRichEditor(
                  controller: ansCtrl,
                  labelText: 'Resposta Bíblica e Textos de Apoio...',
                  minLines: 5,
                  maxLines: 10,
                  onCreateInlineNote: (t) =>
                      _createInlineNoteFromEditor(t, question.areaId),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    final ans = RichFormattedEditingController.readMarkup(
                      ansCtrl,
                    ).trim();
                    if (ans.isEmpty) return;
                    final km = ref.read(knowledgeManagerProvider);
                    await km.answerQuestion(question.id, answer: ans);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: const Text(
                    'Salvar Resposta',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickAndRegisterDocument() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.upload_file, color: AppTheme.primaryBlue),
                    SizedBox(width: 8),
                    Text(
                      'Anexar Arquivo ou Imagem',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                key: const Key('btn_kb_doc_from_device'),
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.primaryBlue,
                  child: Icon(Icons.upload_file, color: Colors.white),
                ),
                title: const Text('Importar do Dispositivo'),
                subtitle: const Text(
                  'PDF, EPUB, DOC, TXT ou Imagem salva no aparelho',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndRegisterDocumentFromDevice();
                },
              ),
              ListTile(
                key: const Key('btn_kb_doc_from_picture_bank'),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF0EA5E9),
                  child: Icon(Icons.photo_library_rounded, color: Colors.white),
                ),
                title: const Text('Importar do Banco de Gravuras'),
                subtitle: const Text(
                  'Registrar uma gravura do aplicativo como documento',
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final db = ref.read(databaseProvider);
                  final pic = await showPictureBankPickerModal(context, db: db);
                  if (pic == null) return;
                  final cleanCaption = MarkdownPreviewText.cleanMarkdown(
                    pic.caption,
                  ).trim();
                  final title = cleanCaption.isEmpty ? 'Gravura' : cleanCaption;
                  final km = ref.read(knowledgeManagerProvider);
                  await km.registerDocument(
                    title: title,
                    fileName:
                        '${title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}.png',
                    filePath: pic.imageData,
                    fileSize: pic.imageData.length,
                    fileType: 'image',
                    category: 'manual',
                    tags: pic.tags,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Gravura registrada em Documentos com sucesso!',
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndRegisterDocumentFromDevice() async {
    try {
      final res = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'epub',
          'doc',
          'docx',
          'txt',
          'png',
          'jpg',
          'jpeg',
          'webp',
        ],
      );
      if (res.isNotEmpty) {
        final f = res.first;
        String finalPath = f.path ?? f.name;
        Uint8List? fileBytes;
        try {
          fileBytes = await f.readAsBytes();
        } catch (e, st) {
          AppLogger.debug(
            'Falha ao ler bytes diretos do FilePicker (${f.name}): $e',
            st,
          );
        }
        int fileSize =
            fileBytes?.length ?? f.lengthSync() ?? (await f.length()) ?? 0;

        if (!kIsWeb) {
          try {
            if ((fileBytes == null || fileBytes.isEmpty) &&
                f.path != null &&
                f.path!.isNotEmpty) {
              final sourceFile = File(f.path!);
              if (await sourceFile.exists()) {
                try {
                  fileBytes = await sourceFile.readAsBytes();
                } catch (e, st) {
                  AppLogger.debug(
                    'Falha ao ler bytes do arquivo origem (${f.path}): $e',
                    st,
                  );
                }
              }
            }

            final appDir = await getApplicationDocumentsDirectory();
            final docsFolder = Directory('${appDir.path}/documents');
            if (!docsFolder.existsSync()) {
              await docsFolder.create(recursive: true);
            }
            final targetFile = File('${docsFolder.path}/${f.name}');

            if (fileBytes != null && fileBytes.isNotEmpty) {
              await targetFile.writeAsBytes(fileBytes, flush: true);
              finalPath = targetFile.path;
              fileSize = fileBytes.length;
            } else if (f.path != null && f.path!.isNotEmpty) {
              final sourceFile = File(f.path!);
              if (await sourceFile.exists()) {
                await sourceFile.copy(targetFile.path);
                finalPath = targetFile.path;
                fileSize = await targetFile.length();
              }
            }
          } catch (err) {
            debugPrint('Erro ao copiar documento permanente: $err');
          }
        }

        final fileExt = f.name.contains('.')
            ? f.name.split('.').last.toLowerCase()
            : 'other';
        final km = ref.read(knowledgeManagerProvider);
        final registeredDoc = await km.registerDocument(
          title: f.name.split('.').first,
          fileName: f.name,
          filePath: finalPath,
          fileSize: fileSize,
          fileType: fileExt,
          category: 'manual',
          areaId: _selectedAreaId,
          documentBytes: fileBytes,
        );

        if (fileBytes != null && fileBytes.isNotEmpty) {
          try {
            final appDb = ref.read(databaseProvider);
            await appDb
                .into(appDb.appKvStore)
                .insertOnConflictUpdate(
                  AppKvStoreCompanion.insert(
                    key: 'doc_bytes_${registeredDoc.id}',
                    value: base64Encode(fileBytes),
                    updatedAt: drift.Value(DateTime.now()),
                  ),
                );
          } catch (e, st) {
            AppLogger.warning(
              'Falha ao armazenar bytes do documento (${registeredDoc.id}) em cache KV',
              e,
              st,
            );
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Documento registrado na Base de Conhecimento!'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao anexar documento: $e')));
      }
    }
  }

  void _showCreateResourceModal() {
    final km = ref.read(knowledgeManagerProvider);
    String? areaId = _selectedAreaId;

    showAdaptiveMinistrySheet(
      context: context,
      title: 'Novo Recurso / Link',
      titleLeading: const Icon(Icons.link, color: Colors.teal),
      builder: (ctx, scroll) => ManagedTextControllers(
        initialTexts: const ['', '', '', ''],
        customFactories: [
          null,
          null,
          (text) => RichFormattedEditingController.fromMarkup(text),
          null,
        ],
        builder: (ctx, ctrls) {
          final titleCtrl = ctrls[0];
          final urlCtrl = ctrls[1];
          final descCtrl = ctrls[2];
          final tagsCtrl = ctrls[3];

          return StatefulBuilder(
            builder: (ctx, setSheetState) => SingleChildScrollView(
              controller: scroll,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: titleCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Título do Recurso',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: urlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'URL (ex: https://www.jw.org/...)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  RichMarkdownToolbar(controller: descCtrl),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descCtrl,
                    maxLines: 4,
                    scrollPadding: const EdgeInsets.only(bottom: 140),
                    decoration: const InputDecoration(
                      labelText: 'Descrição / Para qual ocasião serve?',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  CollapsibleMetadataSection(
                    title: 'Área P.A.R.A. & Tags',
                    initiallyExpanded: false,
                    children: [
                      const SizedBox(height: 6),
                      _buildAreaDropdown(
                        km: km,
                        selectedAreaId: areaId,
                        onChanged: (v) => setSheetState(() => areaId = v),
                      ),
                      TextField(
                        controller: tagsCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Tags (separadas por vírgula)',
                          hintText: 'Ex: jw, vídeos, pregação',
                          prefixIcon: Icon(Icons.tag, size: 18),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      final title = titleCtrl.text.trim();
                      if (title.isEmpty) return;
                      final urlText = urlCtrl.text.trim();
                      final descText =
                          RichFormattedEditingController.readMarkup(descCtrl)
                              .trim();
                      final rawTags = tagsCtrl.text
                          .split(',')
                          .map((t) => t.trim())
                          .where((t) => t.isNotEmpty)
                          .toList();
                      await km.createResource(
                        title: title,
                        resourceType: 'link',
                        url: urlText.isNotEmpty ? urlText : null,
                        description: descText.isNotEmpty ? descText : null,
                        areaId: areaId,
                        tags: rawTags,
                      );
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                    child: const Text(
                      'Salvar Recurso',
                      style: TextStyle(fontWeight: FontWeight.bold),
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

  Future<void> _openDocument(KnowledgeDocumentEntry doc) async {
    String resolvedPath = doc.filePath;
    Uint8List? resolvedBytes;
    if (!kIsWeb) {
      try {
        final direct = File(doc.filePath);
        if (await direct.exists()) {
          resolvedPath = direct.path;
          try {
            resolvedBytes = await direct.readAsBytes();
          } catch (e, st) {
            AppLogger.debug(
              'Falha ao ler arquivo direto (${doc.filePath}): $e',
              st,
            );
          }
        } else {
          final docDir = await getApplicationDocumentsDirectory();
          final fileName = doc.fileName.isNotEmpty
              ? doc.fileName
              : doc.filePath.split(RegExp(r'[\\/]')).last;
          final candidates = [
            File('${docDir.path}/documents/$fileName'),
            File('${docDir.path}/$fileName'),
          ];
          try {
            final supportDir = await getApplicationSupportDirectory();
            candidates.add(File('${supportDir.path}/documents/$fileName'));
            candidates.add(File('${supportDir.path}/$fileName'));
          } catch (e, st) {
            AppLogger.debug(
              'Diretório ApplicationSupport indisponível: $e',
              st,
            );
          }
          try {
            final tempDir = await getTemporaryDirectory();
            candidates.add(File('${tempDir.path}/$fileName'));
            candidates.add(File('${tempDir.path}/file_picker/$fileName'));
          } catch (e, st) {
            AppLogger.debug('Diretório temporário indisponível: $e', st);
          }

          for (final c in candidates) {
            if (await c.exists()) {
              resolvedPath = c.path;
              try {
                resolvedBytes = await c.readAsBytes();
              } catch (e, st) {
                AppLogger.debug(
                  'Falha ao ler candidato de documento (${c.path}): $e',
                  st,
                );
              }
              break;
            }
          }
        }
      } catch (e, st) {
        AppLogger.warning(
          'Falha ao localizar documento (${doc.id}) no disco',
          e,
          st,
        );
      }
    }

    if (resolvedBytes == null || resolvedBytes.isEmpty) {
      try {
        final appDb = ref.read(databaseProvider);
        final kv = await (appDb.select(
          appDb.appKvStore,
        )..where((t) => t.key.equals('doc_bytes_${doc.id}'))).getSingleOrNull();
        if (kv != null && kv.value.isNotEmpty) {
          resolvedBytes = base64Decode(kv.value);
        }
      } catch (e, st) {
        AppLogger.warning('Falha ao ler cache doc_bytes_${doc.id}', e, st);
      }
    }

    if (mounted) {
      await showUniversalAttachmentViewer(
        context,
        filePath: resolvedPath,
        title: doc.title,
        fileType: doc.fileType,
        bytes: resolvedBytes,
      );
    }
  }

  Future<void> _openDocumentExternal(KnowledgeDocumentEntry doc) async {
    String pathToOpen = doc.filePath;
    Uint8List? fileBytes;
    if (!kIsWeb) {
      try {
        final direct = File(doc.filePath);
        if (await direct.exists()) {
          pathToOpen = direct.path;
          try {
            fileBytes = await direct.readAsBytes();
          } catch (e, st) {
            AppLogger.debug(
              'Falha ao ler arquivo direto para abrir (${doc.filePath}): $e',
              st,
            );
          }
        } else {
          final docDir = await getApplicationDocumentsDirectory();
          final fileName = doc.fileName.isNotEmpty
              ? doc.fileName
              : doc.filePath.split(RegExp(r'[\\/]')).last;
          final candidates = [
            File('${docDir.path}/documents/$fileName'),
            File('${docDir.path}/$fileName'),
          ];
          try {
            final supportDir = await getApplicationSupportDirectory();
            candidates.add(File('${supportDir.path}/documents/$fileName'));
            candidates.add(File('${supportDir.path}/$fileName'));
          } catch (e, st) {
            AppLogger.debug(
              'ApplicationSupport indisponível ao abrir anexo: $e',
              st,
            );
          }
          try {
            final tempDir = await getTemporaryDirectory();
            candidates.add(File('${tempDir.path}/$fileName'));
            candidates.add(File('${tempDir.path}/file_picker/$fileName'));
          } catch (e, st) {
            AppLogger.debug('TempDir indisponível ao abrir anexo: $e', st);
          }

          for (final c in candidates) {
            if (await c.exists()) {
              pathToOpen = c.path;
              try {
                fileBytes = await c.readAsBytes();
              } catch (e, st) {
                AppLogger.debug(
                  'Falha ao ler candidato para abrir (${c.path}): $e',
                  st,
                );
              }
              break;
            }
          }
        }
      } catch (e, st) {
        AppLogger.warning(
          'Falha ao localizar documento externo (${doc.id})',
          e,
          st,
        );
      }
    }

    try {
      final res = await OpenFilex.open(pathToOpen);
      if (res.type != ResultType.done) {
        final uri = Uri.file(pathToOpen);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
        if (mounted) {
          await showUniversalAttachmentViewer(
            context,
            filePath: pathToOpen,
            title: doc.title,
            fileType: doc.fileType,
            bytes: fileBytes,
          );
        }
      }
    } catch (e, st) {
      AppLogger.warning(
        'Falha ao abrir documento externamente; usando visualizador interno',
        e,
        st,
      );
      if (mounted) {
        await showUniversalAttachmentViewer(
          context,
          filePath: pathToOpen,
          title: doc.title,
          fileType: doc.fileType,
          bytes: fileBytes,
        );
      }
    }
  }

  Future<void> _exportCurrentTabToPdf() async {
    if (_exportingTabPdf) return;
    setState(() => _exportingTabPdf = true);
    try {
      final km = ref.read(knowledgeManagerProvider);
      final q = _searchQuery.trim().isNotEmpty ? _searchQuery.trim() : null;
      String? msg;

      switch (_tabController.index) {
        case 0: // Notas
          final allNotes = (await km.watchNotes(query: q).first)
              .where((n) => !OfficialDocManager.isReservedCategory(n.category))
              .toList();
          final filtered = allNotes.where((n) {
            if (_selectedNoteTag == null) return true;
            try {
              final list = (jsonDecode(n.tags) as List)
                  .map((e) => e.toString())
                  .toList();
              return list.contains(_selectedNoteTag);
            } catch (_) {
              return false;
            }
          }).toList();
          final filterParts = <String>[
            if (_selectedNoteTag != null) 'Tag: #$_selectedNoteTag',
            if (q != null) 'Busca: "$q"',
          ];
          await KnowledgeAndEmailPdfService.exportNotesListPdf(
            filtered,
            filterDescription: filterParts.isEmpty
                ? null
                : filterParts.join(' • '),
          );
          msg = 'PDF da aba Notas (${filtered.length} item(ns)) gerado!';
          break;

        case 1: // Perguntas & Dúvidas
          final questions = await km
              .watchQuestions(
                status: _selectedQuestionStatus == 'all'
                    ? null
                    : _selectedQuestionStatus,
                category: _selectedQuestionCategory,
                query: q,
              )
              .first;
          final filterParts = <String>[
            if (_selectedQuestionStatus != 'all')
              'Status: $_selectedQuestionStatus',
            if (q != null) 'Busca: "$q"',
          ];
          await KnowledgeAndEmailPdfService.exportQuestionsListPdf(
            questions,
            filterDescription: filterParts.isEmpty
                ? null
                : filterParts.join(' • '),
          );
          msg =
              'PDF da aba Perguntas & Dúvidas (${questions.length} item(ns)) gerado!';
          break;

        case 2: // Documentos
          final allDocs = await km
              .watchDocuments(category: _selectedDocCategory, query: q)
              .first;
          final filtered = allDocs.where((d) {
            if (_selectedDocTag == null) return true;
            try {
              final list = (jsonDecode(d.tags) as List)
                  .map((e) => e.toString())
                  .toList();
              return list.contains(_selectedDocTag);
            } catch (_) {
              return false;
            }
          }).toList();
          final filterParts = <String>[
            if (_selectedDocCategory != null)
              'Categoria: $_selectedDocCategory',
            if (_selectedDocTag != null) 'Tag: #$_selectedDocTag',
            if (q != null) 'Busca: "$q"',
          ];
          await KnowledgeAndEmailPdfService.exportDocumentsListPdf(
            filtered,
            filterDescription: filterParts.isEmpty
                ? null
                : filterParts.join(' • '),
          );
          msg = 'PDF da aba Documentos (${filtered.length} item(ns)) gerado!';
          break;

        case 3: // Recursos
          final allRes = await km
              .watchResources(category: _selectedResourceCategory, query: q)
              .first;
          final filtered = allRes.where((r) {
            if (_selectedResourceTag == null) return true;
            try {
              final list = (jsonDecode(r.tags) as List)
                  .map((e) => e.toString())
                  .toList();
              return list.contains(_selectedResourceTag);
            } catch (_) {
              return false;
            }
          }).toList();
          final filterParts = <String>[
            if (_selectedResourceTag != null) 'Tag: #$_selectedResourceTag',
            if (q != null) 'Busca: "$q"',
          ];
          await KnowledgeAndEmailPdfService.exportResourcesListPdf(
            filtered,
            filterDescription: filterParts.isEmpty
                ? null
                : filterParts.join(' • '),
          );
          msg = 'PDF da aba Recursos (${filtered.length} item(ns)) gerado!';
          break;

        case 4: // Cartas & Atas
          final enabled = ref.read(
            isFeatureEnabledProvider(AppFeature.officialDocuments),
          );
          if (!enabled) {
            msg = 'O módulo Cartas & Atas está oculto em Personalizar Aplicativo.';
            break;
          }
          final odm = ref.read(officialDocManagerProvider);
          final selectedId = _officialDocSelectionNotifier.value;
          final selected = selectedId != null
              ? await odm.getDocumentById(selectedId)
              : null;
          if (selected != null) {
            final bundle = await odm.loadBundle();
            OfficialHeaderProfile? header;
            if (selected.includeHeader) {
              if (selected.headerProfileId != null) {
                header = bundle.headers
                    .where((h) => h.id == selected.headerProfileId)
                    .firstOrNull;
              }
              header ??=
                  bundle.headers.where((h) => h.isDefault).firstOrNull ??
                  bundle.headers.firstOrNull;
            }
            final groupTitle = odm.resolveGroupTitle(selected, bundle);
            final signers = odm.resolveEffectiveSigners(selected, bundle);
            final pdfBytes = await OfficialDocPdfGenerator.generatePdfBytes(
              doc: selected,
              header: header,
              signatureGroupTitle: groupTitle,
              signers: signers,
            );
            final rawTitle = selected.referenceSubject.trim().isNotEmpty
                ? selected.referenceSubject.trim()
                : selected.title;
            final baseName = KnowledgeAndEmailPdfService.sanitizeFileName(
              rawTitle,
              fallback: 'Documento_Oficial',
            );
            await BinaryFileSaver.saveBytes(
              fileName: '$baseName.pdf',
              bytes: pdfBytes,
              mimeType: 'application/pdf',
              dialogTitle: 'Exportar Documento Oficial em PDF',
            );
            msg = 'PDF do documento "${selected.title}" gerado!';
          } else {
            final docs = await odm.watchDocuments().first;
            await KnowledgeAndEmailPdfService.exportOfficialDocsIndexPdf(docs);
            msg =
                'PDF da aba Cartas & Atas (${docs.length} documento(s)) gerado!';
          }
          break;
      }

      if (mounted && msg != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e, st) {
      AppLogger.warning(
        'Falha ao exportar aba da Base de Conhecimento em PDF',
        e,
        st,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha ao gerar PDF da aba: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingTabPdf = false);
    }
  }

  void _handleTabAwareAdd() {
    switch (_tabController.index) {
      case 0:
        _showCreateNoteModal();
        break;
      case 1:
        _showCreateQuestionModal();
        break;
      case 2:
        _pickAndRegisterDocument();
        break;
      case 3:
        _showCreateResourceModal();
        break;
      case 4:
        _createOfficialDocFromKb();
        break;
      default:
        _showAddKnowledgeItemMenu();
    }
  }

  Future<void> _createOfficialDocFromKb() async {
    final enabled = ref.read(
      isFeatureEnabledProvider(AppFeature.officialDocuments),
    );
    if (!enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'O módulo Cartas & Atas está oculto em Personalizar Aplicativo.',
          ),
        ),
      );
      return;
    }
    final created = await OfficialDocumentsScreen.openTemplateChooserAndCreate(
      context,
      ref,
    );
    if (created != null && mounted) {
      _officialDocSelectionNotifier.value = created.id;
    }
  }

  Widget _buildTabAwareFab() {
    switch (_tabController.index) {
      case 0:
        return FloatingActionButton.extended(
          heroTag: 'fab_kb_0',
          onPressed: _showCreateNoteModal,
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.note_add),
          label: const Text(
            'Nova Nota',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      case 1:
        return FloatingActionButton.extended(
          heroTag: 'fab_kb_1',
          onPressed: _showCreateQuestionModal,
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.help_outline),
          label: const Text(
            'Nova Dúvida',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      case 2:
        return FloatingActionButton.extended(
          heroTag: 'fab_kb_2',
          onPressed: _pickAndRegisterDocument,
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.upload_file),
          label: const Text(
            'Anexar Documento',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      case 3:
        return FloatingActionButton.extended(
          heroTag: 'fab_kb_3',
          onPressed: _showCreateResourceModal,
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_link),
          label: const Text(
            'Novo Recurso',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      case 4:
        return FloatingActionButton.extended(
          heroTag: 'fab_kb_4',
          onPressed: _createOfficialDocFromKb,
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.post_add),
          label: const Text(
            'Novo Doc.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      default:
        return FloatingActionButton.extended(
          heroTag: 'fab_kb_def',
          onPressed: _showAddKnowledgeItemMenu,
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text(
            'Novo Item',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        );
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final accent = AppTheme.primaryColor(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131B2E) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: 0.22),
                      accent.withValues(alpha: 0.08),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, size: 36, color: accent),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? const Color(0xFFF8FAFC)
                      : const Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13.2,
                  height: 1.45,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                FilledButton.tonalIcon(
                  onPressed: onAction,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(actionLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }
}
