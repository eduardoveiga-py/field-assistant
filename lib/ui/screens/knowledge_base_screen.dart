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
import '../../database/app_database.dart';
import '../../reports/web_downloader.dart';
import '../../research/research_manager.dart';
import '../providers.dart';
import '../widgets/adaptive_ministry_sheet.dart';
import '../widgets/knowledge_item_reader_dialog.dart';
import '../widgets/managed_text_controllers.dart';
import '../widgets/markdown_preview_text.dart';
import '../widgets/rich_markdown_toolbar.dart';
import '../widgets/universal_attachment_viewer.dart';
import 'research_screen.dart';

/// Tela do Módulo C — Base de Conhecimento do Field Assistant.
/// Centraliza notas formatadas, dúvidas bíblicas, arquivos/documentos locais e links de estudo.
class KnowledgeBaseScreen extends ConsumerStatefulWidget {
  const KnowledgeBaseScreen({super.key});

  @override
  ConsumerState<KnowledgeBaseScreen> createState() => _KnowledgeBaseScreenState();
}

class _KnowledgeBaseScreenState extends ConsumerState<KnowledgeBaseScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _selectedNoteTag;
  String? _selectedQuestionStatus = 'all'; // 'all', 'answered', 'unanswered'
  String? _selectedQuestionCategory;
  String? _selectedDocCategory;
  String? _selectedDocTag;
  String? _selectedResourceCategory;
  String? _selectedResourceTag;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.menu_book_rounded, color: AppTheme.primaryBlue, size: 24),
            SizedBox(width: 8),
            Text('Base de Conhecimento', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_stories_outlined),
            tooltip: 'Pesquisas e Apresentações do Ministério',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ResearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryBlue),
            tooltip: 'Adicionar à Base',
            onPressed: _handleTabAwareAdd,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          indicatorColor: AppTheme.primaryBlue,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: '📝 Notas'),
            Tab(text: '❓ Perguntas & Dúvidas'),
            Tab(text: '📁 Documentos'),
            Tab(text: '🔗 Recursos'),
          ],
        ),
      ),
      floatingActionButton: _buildTabAwareFab(),
      body: Column(
        children: [
          // Barra de Pesquisa Rápida na Base
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              decoration: InputDecoration(
                hintText: 'Pesquisar em toda a base de conhecimento...',
                prefixIcon: const Icon(Icons.search, size: 20),
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
                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ABA 1: NOTAS DE CONHECIMENTO
  // ==========================================

  Widget _buildNotesTab(bool isDark) {
    final km = ref.watch(knowledgeManagerProvider);

    return StreamBuilder<List<KnowledgeNoteEntry>>(
      stream: km.watchNotes(query: _searchQuery.isNotEmpty ? _searchQuery : null),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allNotes = snapshot.data ?? [];
        if (allNotes.isEmpty) {
          return _buildEmptyState(
            icon: Icons.note_outlined,
            title: 'Nenhuma nota registrada',
            subtitle: 'Guarde anotações temáticas, ideias de pregações ou notas pastorais.',
            isDark: isDark,
          );
        }

        // Extrai todas as tags únicas
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
            AppLogger.debug('Falha ao ler tags JSON da nota (${n.id}): $e', st);
          }
        }

        final notes = allNotes.where((n) {
          if (_selectedNoteTag == null) return true;
          try {
            final list = (jsonDecode(n.tags) as List).map((e) => e.toString()).toList();
            return list.contains(_selectedNoteTag);
          } catch (e, st) {
            AppLogger.debug('Falha ao filtrar tags da nota (${n.id}): $e', st);
            return false;
          }
        }).toList();

        return Column(
          children: [
            // Filtros de Tags
            if (allTags.isNotEmpty)
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    FilterChip(
                      label: const Text('Todas as Tags'),
                      selected: _selectedNoteTag == null,
                      onSelected: (val) => setState(() => _selectedNoteTag = null),
                      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    ),
                    const SizedBox(width: 8),
                    ...allTags.map((tag) {
                      final isSelected = _selectedNoteTag == tag;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          avatar: Icon(Icons.tag, size: 14, color: isSelected ? Colors.white : AppTheme.primaryBlue),
                          label: Text(tag),
                          selected: isSelected,
                          onSelected: (val) => setState(() => _selectedNoteTag = val ? tag : null),
                        ),
                      );
                    }),
                  ],
                ),
              ),

            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: notes.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final note = notes[i];
                  List<String> noteTags = [];
                  try {
                    noteTags = (jsonDecode(note.tags) as List)
                        .map((e) => e.toString())
                        .where((t) => !t.startsWith('research:'))
                        .toList();
                  } catch (e, st) {
                    AppLogger.debug('Falha ao exibir tags da nota (${note.id}): $e', st);
                  }

                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: InkWell(
                        onTap: () {
                          showKnowledgeItemReader(
                            context,
                            title: note.title,
                            content: note.content,
                            category: note.category,
                            itemType: 'Nota',
                            updatedAt: note.updatedAt,
                            tags: noteTags,
                            onEdit: () => _showEditNoteModal(note),
                            onDelete: () => km.softDeleteNote(note.id),
                            onExport: () => _exportNote(note),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (note.isPinned) ...[
                                    const Icon(Icons.push_pin, size: 16, color: Colors.amber),
                                    const SizedBox(width: 4),
                                  ],
                                  Expanded(
                                    child: Text(
                                      note.title,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, size: 20),
                                    onSelected: (val) {
                                      if (val == 'pin') km.togglePinNote(note.id);
                                      if (val == 'edit') _showEditNoteModal(note);
                                      if (val == 'research') _transformNoteToResearch(note);
                                      if (val == 'export') _exportNote(note);
                                      if (val == 'delete') km.softDeleteNote(note.id);
                                    },
                                    itemBuilder: (ctx) => [
                                      PopupMenuItem(
                                        value: 'pin',
                                        child: Text(note.isPinned ? 'Desafixar' : 'Fixar no Topo'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Editar Nota'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'research',
                                        child: Text('Transformar em Pesquisa'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'export',
                                        child: Text('Exportar Nota'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Excluir Nota', style: TextStyle(color: Colors.redAccent)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Expanded(
                                child: MarkdownPreviewText(
                                  text: note.content,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Wrap(
                                    spacing: 6,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          note.category,
                                          style: const TextStyle(fontSize: 11, color: AppTheme.primaryBlue, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      if (noteTags.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.teal.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '#${noteTags.first}',
                                            style: const TextStyle(fontSize: 10, color: Colors.teal, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      if (note.tags.contains('research:'))
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.purple.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.auto_stories, size: 10, color: Colors.purple),
                                              SizedBox(width: 3),
                                              Text('Pesquisa', style: TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  Text(
                                    _formatDate(note.updatedAt),
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
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
        status: _selectedQuestionStatus == 'all' ? null : _selectedQuestionStatus,
        category: _selectedQuestionCategory,
        query: _searchQuery.isNotEmpty ? _searchQuery : null,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final questions = snapshot.data ?? [];

        return Column(
          children: [
            // Filtros de Status e Categoria
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                    avatar: const Icon(Icons.help_outline, size: 14),
                    label: const Text('Em Aberto'),
                    selected: _selectedQuestionStatus == 'unanswered',
                    onSelected: (val) {
                      if (val) setState(() => _selectedQuestionStatus = 'unanswered');
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(Icons.check, size: 14),
                    label: const Text('Respondidas'),
                    selected: _selectedQuestionStatus == 'answered',
                    onSelected: (val) {
                      if (val) setState(() => _selectedQuestionStatus = 'answered');
                    },
                  ),
                ],
              ),
            ),

            if (questions.isEmpty)
              Expanded(
                child: _buildEmptyState(
                  icon: Icons.help_outline_rounded,
                  title: 'Nenhuma dúvida cadastrada',
                  subtitle: 'Registre perguntas de moradores ou pesquisas para responder na próxima visita.',
                  isDark: isDark,
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: questions.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final q = questions[i];
                    final isAnswered = q.status == 'answered';

                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: InkWell(
                          onTap: () {
                            showKnowledgeItemReader(
                              context,
                              title: q.question,
                              content: q.answer != null && q.answer!.isNotEmpty
                                  ? '**Contexto:**\n${q.context ?? "Sem contexto"}\n\n---\n\n**Resposta Bíblica:**\n${q.answer}'
                                  : (q.context ?? 'Dúvida ainda sem resposta bíblica cadastrada.'),
                              category: q.category,
                              itemType: 'Dúvida',
                              updatedAt: q.updatedAt,
                              subtitle: isAnswered ? 'Respondida' : 'Em Aberto',
                              onEdit: () => _showEditQuestionModal(q),
                              onDelete: () => km.softDeleteQuestion(q.id),
                              onExport: () => _exportQuestion(q),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: (isAnswered ? Colors.green : Colors.amber).withValues(alpha: 0.15),
                                      child: Icon(
                                        isAnswered ? Icons.check : Icons.question_mark,
                                        color: isAnswered ? Colors.green : Colors.amber,
                                        size: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        q.question,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert, size: 20),
                                      onSelected: (val) {
                                        if (val == 'answer') _showAnswerQuestionModal(q);
                                        if (val == 'edit') _showEditQuestionModal(q);
                                        if (val == 'research') _transformQuestionToResearch(q);
                                        if (val == 'export') _exportQuestion(q);
                                        if (val == 'delete') km.softDeleteQuestion(q.id);
                                      },
                                      itemBuilder: (ctx) => [
                                        PopupMenuItem(
                                          value: 'answer',
                                          child: Text(isAnswered ? 'Editar Resposta' : 'Inserir Resposta'),
                                        ),
                                        const PopupMenuItem(value: 'edit', child: Text('Editar Dúvida')),
                                        const PopupMenuItem(value: 'research', child: Text('Transformar em Pesquisa')),
                                        const PopupMenuItem(value: 'export', child: Text('Exportar')),
                                        const PopupMenuItem(value: 'delete', child: Text('Excluir', style: TextStyle(color: Colors.redAccent))),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Expanded(
                                  child: MarkdownPreviewText(
                                    text: q.answer != null && q.answer!.isNotEmpty
                                        ? 'Resposta: ${q.answer!}'
                                        : (q.context ?? 'Toque para abrir a janela de leitura e detalhes.'),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (isAnswered ? Colors.green : Colors.amber).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isAnswered ? 'Respondida' : 'Em Aberto',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isAnswered ? Colors.green : Colors.amber,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _formatDate(q.updatedAt),
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
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
        query: _searchQuery.isNotEmpty ? _searchQuery : null,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allDocs = snapshot.data ?? [];
        if (allDocs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.folder_shared_outlined,
            title: 'Nenhum documento anexado',
            subtitle: 'Guarde manuais, roteiros ou apostilas em PDF diretamente no app.',
            isDark: isDark,
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
            AppLogger.debug('Falha ao ler tags JSON do documento (${d.id}): $e', st);
          }
        }

        // Filtro opcional por tag
        final docs = allDocs.where((d) {
          if (_selectedDocTag == null) return true;
          try {
            final list = (jsonDecode(d.tags) as List).map((e) => e.toString()).toList();
            return list.contains(_selectedDocTag);
          } catch (e, st) {
            AppLogger.debug('Falha ao filtrar tags do documento (${d.id}): $e', st);
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
                    onSelected: (val) => setState(() => _selectedDocCategory = null),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Manuais'),
                    selected: _selectedDocCategory == 'manual',
                    onSelected: (val) => setState(() => _selectedDocCategory = val ? 'manual' : null),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Estudo'),
                    selected: _selectedDocCategory == 'study',
                    onSelected: (val) => setState(() => _selectedDocCategory = val ? 'study' : null),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Esboço'),
                    selected: _selectedDocCategory == 'outline',
                    onSelected: (val) => setState(() => _selectedDocCategory = val ? 'outline' : null),
                  ),
                ],
              ),
            ),

            // Filtros de Tags dos Documentos
            if (allDocTags.isNotEmpty)
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    FilterChip(
                      label: const Text('Todas as Tags'),
                      selected: _selectedDocTag == null,
                      onSelected: (val) => setState(() => _selectedDocTag = null),
                      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    ),
                    const SizedBox(width: 8),
                    ...allDocTags.map((tag) {
                      final isSelected = _selectedDocTag == tag;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          avatar: Icon(Icons.tag, size: 14, color: isSelected ? Colors.white : AppTheme.primaryBlue),
                          label: Text(tag),
                          selected: isSelected,
                          onSelected: (val) => setState(() => _selectedDocTag = val ? tag : null),
                        ),
                      );
                    }),
                  ],
                ),
              ),

            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final doc = docs[i];
                  final sizeKb = (doc.fileSize / 1024).toStringAsFixed(1);
                  List<String> docTags = [];
                  try {
                    docTags = (jsonDecode(doc.tags) as List).map((e) => e.toString()).toList();
                  } catch (e, st) {
                    AppLogger.debug('Falha ao ler tags JSON na listagem de documentos (${doc.id}): $e', st);
                  }

                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 140),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        onTap: () => _openDocument(doc),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  doc.fileType.toLowerCase() == 'pdf'
                                      ? Icons.picture_as_pdf
                                      : Icons.description,
                                  color: doc.fileType.toLowerCase() == 'pdf'
                                      ? Colors.redAccent
                                      : AppTheme.primaryBlue,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      doc.title,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${doc.fileName} • $sizeKb KB • ${doc.category}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (docTags.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 4,
                                        children: docTags.take(3).map((t) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '#$t',
                                            style: const TextStyle(fontSize: 10, color: AppTheme.primaryBlue, fontWeight: FontWeight.bold),
                                          ),
                                        )).toList(),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 20),
                                onSelected: (val) {
                                  if (val == 'open') _openDocument(doc);
                                  if (val == 'external') _openDocumentExternal(doc);
                                  if (val == 'edit') _showEditDocumentModal(doc);
                                  if (val == 'delete') km.softDeleteDocument(doc.id);
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(value: 'open', child: Text('Abrir no App')),
                                  const PopupMenuItem(value: 'external', child: Text('Abrir Externamente')),
                                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                                  const PopupMenuItem(value: 'delete', child: Text('Excluir', style: TextStyle(color: Colors.redAccent))),
                                ],
                              ),
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
        query: _searchQuery.isNotEmpty ? _searchQuery : null,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allResources = snapshot.data ?? [];
        if (allResources.isEmpty) {
          return _buildEmptyState(
            icon: Icons.link_rounded,
            title: 'Nenhum recurso cadastrado',
            subtitle: 'Salve links do JW.org, lições bíblicas ou vídeos úteis para as conversas.',
            isDark: isDark,
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
            AppLogger.debug('Falha ao ler tags JSON de recurso (${r.id}): $e', st);
          }
        }

        final resources = allResources.where((r) {
          if (_selectedResourceTag == null) return true;
          try {
            final list = (jsonDecode(r.tags) as List).map((e) => e.toString()).toList();
            return list.contains(_selectedResourceTag);
          } catch (e, st) {
            AppLogger.debug('Falha ao filtrar tags JSON de recurso (${r.id}): $e', st);
            return false;
          }
        }).toList();

        return Column(
          children: [
            // Filtros de Tags dos Recursos
            if (allResourceTags.isNotEmpty)
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    FilterChip(
                      label: const Text('Todas as Tags'),
                      selected: _selectedResourceTag == null,
                      onSelected: (val) => setState(() => _selectedResourceTag = null),
                      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    ),
                    const SizedBox(width: 8),
                    ...allResourceTags.map((tag) {
                      final isSelected = _selectedResourceTag == tag;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          avatar: Icon(Icons.tag, size: 14, color: isSelected ? Colors.white : Colors.teal),
                          label: Text(tag),
                          selected: isSelected,
                          onSelected: (val) => setState(() => _selectedResourceTag = val ? tag : null),
                        ),
                      );
                    }),
                  ],
                ),
              ),

            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: resources.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final r = resources[i];
                  List<String> resTags = [];
                  try {
                    resTags = (jsonDecode(r.tags) as List).map((e) => e.toString()).toList();
                  } catch (e, st) {
                    AppLogger.debug('Falha ao ler tags JSON na listagem de recursos (${r.id}): $e', st);
                  }

                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 140),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        onTap: () {
                          showKnowledgeItemReader(
                            context,
                            title: r.title,
                            content: r.description ?? 'Recurso / Link salvo na Base de Conhecimento.',
                            category: r.category,
                            itemType: 'Recurso',
                            url: r.url,
                            tags: resTags,
                            updatedAt: r.updatedAt,
                            onEdit: () => _showEditResourceModal(r),
                            onDelete: () => km.softDeleteResource(r.id),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  r.resourceType == 'video'
                                      ? Icons.play_circle_fill
                                      : r.resourceType == 'jw_pub'
                                          ? Icons.menu_book
                                          : Icons.link,
                                  color: Colors.teal,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      r.title,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    MarkdownPreviewText(
                                      text: r.description ?? r.url ?? r.resourceType,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (resTags.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 4,
                                        children: resTags.take(3).map((t) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.teal.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '#$t',
                                            style: const TextStyle(fontSize: 10, color: Colors.teal, fontWeight: FontWeight.bold),
                                          ),
                                        )).toList(),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 20),
                                onSelected: (val) {
                                  if (val == 'open' && r.url != null && r.url!.isNotEmpty) _openUrl(r.url!);
                                  if (val == 'edit') _showEditResourceModal(r);
                                  if (val == 'delete') km.softDeleteResource(r.id);
                                },
                                itemBuilder: (ctx) => [
                                  if (r.url != null && r.url!.isNotEmpty)
                                    const PopupMenuItem(value: 'open', child: Text('Abrir Link')),
                                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                                  const PopupMenuItem(value: 'delete', child: Text('Excluir', style: TextStyle(color: Colors.redAccent))),
                                ],
                              ),
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
      },
    );
  }

  // ==========================================
  // MODAIS E CRIAÇÃO
  // ==========================================

  void _showAddKnowledgeItemMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                title: const Text('Nova Nota', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Criar uma anotação de estudo ou pesquisa'),
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
                title: const Text('Nova Dúvida Teocrática', style: TextStyle(fontWeight: FontWeight.bold)),
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
                title: const Text('Anexar Documento', style: TextStyle(fontWeight: FontWeight.bold)),
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
                title: const Text('Novo Recurso / Link JW', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Salvar link de publicação ou artigo'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showCreateResourceModal();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateNoteModal() {
    String category = 'general';

    showAdaptiveMinistrySheet(
      context: context,
      title: 'Nova Nota',
      titleLeading: const Icon(Icons.note_add, color: Color(0xFF8B5CF6)),
      builder: (ctx, scroll) => ManagedTextControllers(
        initialTexts: const ['', '', ''],
        builder: (ctx, ctrls) {
          final titleCtrl = ctrls[0];
          final contentCtrl = ctrls[1];
          final tagsCtrl = ctrls[2];

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
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'Título da Nota', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'general', child: Text('Geral')),
                        DropdownMenuItem(value: 'ministry', child: Text('Ministério')),
                        DropdownMenuItem(value: 'research', child: Text('Pesquisa')),
                        DropdownMenuItem(value: 'pastoral', child: Text('Pastoral')),
                      ],
                      onChanged: (v) => setSheetState(() => category = v ?? 'general'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: tagsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tags (separadas por vírgula)',
                        hintText: 'Ex: pregação, consolo, promessas',
                        prefixIcon: Icon(Icons.tag, size: 18),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    RichMarkdownToolbar(controller: contentCtrl),
                    const SizedBox(height: 6),
                    TextField(
                      controller: contentCtrl,
                      maxLines: 6,
                      decoration: const InputDecoration(labelText: 'Conteúdo (Markdown suportado)...', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.auto_stories, size: 16),
                            label: const Text('Salvar & Pesquisar'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF8B5CF6),
                              side: const BorderSide(color: Color(0xFF8B5CF6)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () async {
                              final title = titleCtrl.text.trim();
                              if (title.isEmpty) return;
                              final content = contentCtrl.text.trim();
                              final rawTags = tagsCtrl.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
                              final km = ref.read(knowledgeManagerProvider);
                              final note = await km.createNote(
                                title: title,
                                content: content,
                                category: category,
                                tags: rawTags,
                              );
                              if (ctx.mounted) Navigator.of(ctx).pop();
                              await _transformNoteToResearch(note);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B5CF6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () async {
                              final title = titleCtrl.text.trim();
                              if (title.isEmpty) return;
                              final content = contentCtrl.text.trim();
                              final rawTags = tagsCtrl.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
                              final km = ref.read(knowledgeManagerProvider);
                              await km.createNote(
                                title: title,
                                content: content,
                                category: category,
                                tags: rawTags,
                              );
                              if (ctx.mounted) Navigator.of(ctx).pop();
                            },
                            child: const Text('Salvar Nota', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
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

  void _showEditNoteModal(KnowledgeNoteEntry note) {
    List<String> existingTags = [];
    try {
      existingTags = (jsonDecode(note.tags) as List).map((e) => e.toString()).where((t) => !t.startsWith('research:')).toList();
    } catch (e, st) {
      AppLogger.debug('Falha ao decodificar tags ao editar nota (${note.id}): $e', st);
    }
    String category = note.category;

    showAdaptiveMinistrySheet(
      context: context,
      title: 'Editar Nota',
      titleLeading: const Icon(Icons.edit_note, color: Color(0xFF8B5CF6)),
      builder: (ctx, scroll) => ManagedTextControllers(
        initialTexts: [note.title, note.content, existingTags.join(', ')],
        builder: (ctx, ctrls) {
          final titleCtrl = ctrls[0];
          final contentCtrl = ctrls[1];
          final tagsCtrl = ctrls[2];

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
                      decoration: const InputDecoration(labelText: 'Título da Nota', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: ['general', 'ministry', 'research', 'pastoral'].contains(category) ? category : 'general',
                      decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'general', child: Text('Geral')),
                        DropdownMenuItem(value: 'ministry', child: Text('Ministério')),
                        DropdownMenuItem(value: 'research', child: Text('Pesquisa')),
                        DropdownMenuItem(value: 'pastoral', child: Text('Pastoral')),
                      ],
                      onChanged: (v) => setSheetState(() => category = v ?? 'general'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: tagsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tags (separadas por vírgula)',
                        hintText: 'Ex: pregação, consolo, promessas',
                        prefixIcon: Icon(Icons.tag, size: 18),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    RichMarkdownToolbar(controller: contentCtrl),
                    const SizedBox(height: 6),
                    TextField(
                      controller: contentCtrl,
                      maxLines: 6,
                      decoration: const InputDecoration(labelText: 'Conteúdo (Markdown)...', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.auto_stories, size: 16),
                            label: const Text('Salvar & Pesquisar'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF8B5CF6),
                              side: const BorderSide(color: Color(0xFF8B5CF6)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () async {
                              final title = titleCtrl.text.trim();
                              if (title.isEmpty) return;
                              final content = contentCtrl.text.trim();
                              final rawTags = tagsCtrl.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
                              // Preserva eventuais tags internas como research:
                              try {
                                final internal = (jsonDecode(note.tags) as List).map((e) => e.toString()).where((t) => t.startsWith('research:')).toList();
                                rawTags.addAll(internal);
                              } catch (e, st) {
                                AppLogger.debug('Falha ao preservar tags research ao editar nota (${note.id}): $e', st);
                              }

                              final km = ref.read(knowledgeManagerProvider);
                              await km.updateNote(
                                note.id,
                                title: title,
                                content: content,
                                category: category,
                                tags: rawTags,
                              );
                              final updatedNote = await km.getNoteById(note.id);
                              if (ctx.mounted) Navigator.of(ctx).pop();
                              if (updatedNote != null) {
                                await _transformNoteToResearch(updatedNote);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B5CF6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () async {
                              final title = titleCtrl.text.trim();
                              if (title.isEmpty) return;
                              final content = contentCtrl.text.trim();
                              final rawTags = tagsCtrl.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
                              try {
                                final internal = (jsonDecode(note.tags) as List).map((e) => e.toString()).where((t) => t.startsWith('research:')).toList();
                                rawTags.addAll(internal);
                              } catch (e, st) {
                                AppLogger.debug('Falha ao preservar tags research ao salvar nota (${note.id}): $e', st);
                              }

                              final km = ref.read(knowledgeManagerProvider);
                              await km.updateNote(
                                note.id,
                                title: title,
                                content: content,
                                category: category,
                                tags: rawTags,
                              );
                              if (ctx.mounted) Navigator.of(ctx).pop();
                            },
                            child: const Text('Salvar Alterações', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
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

  void _showEditQuestionModal(KnowledgeQuestionEntry q) {
    showAdaptiveMinistrySheet(
      context: context,
      title: 'Editar Dúvida',
      titleLeading: const Icon(Icons.help_outline, color: Color(0xFFF59E0B)),
      builder: (ctx, scroll) => ManagedTextControllers(
        initialTexts: [q.question, q.context ?? '', q.answer ?? ''],
        builder: (ctx, ctrls) {
          final qCtrl = ctrls[0];
          final ctxCtrl = ctrls[1];
          final ansCtrl = ctrls[2];

          return SingleChildScrollView(
            controller: scroll,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: qCtrl,
                  decoration: const InputDecoration(labelText: 'Pergunta do Morador ou Pesquisa', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                RichMarkdownToolbar(controller: ctxCtrl),
                const SizedBox(height: 6),
                TextField(
                  controller: ctxCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Contexto ou Objeção', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                RichMarkdownToolbar(controller: ansCtrl),
                const SizedBox(height: 6),
                TextField(
                  controller: ansCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Resposta Bíblica', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    final question = qCtrl.text.trim();
                    if (question.isEmpty) return;
                    final ctxText = ctxCtrl.text.trim();
                    final ansText = ansCtrl.text.trim();
                    final km = ref.read(knowledgeManagerProvider);
                    await km.updateQuestion(
                      q.id,
                      question: question,
                      context: ctxText.isNotEmpty ? ctxText : null,
                      answer: ansText.isNotEmpty ? ansText : null,
                      status: ansText.isNotEmpty ? 'answered' : 'open',
                    );
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: const Text('Salvar Alterações', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditDocumentModal(KnowledgeDocumentEntry doc) {
    List<String> existingTags = [];
    try {
      existingTags = (jsonDecode(doc.tags) as List).map((e) => e.toString()).toList();
    } catch (e, st) {
      AppLogger.debug('Falha ao ler tags JSON do documento (${doc.id}): $e', st);
    }
    String category = doc.category;

    showAdaptiveMinistrySheet(
      context: context,
      title: 'Editar Documento',
      titleLeading: const Icon(Icons.description, color: AppTheme.primaryBlue),
      builder: (ctx, scroll) => ManagedTextControllers(
        initialTexts: [doc.title, existingTags.join(', ')],
        builder: (ctx, ctrls) {
          final titleCtrl = ctrls[0];
          final tagsCtrl = ctrls[1];

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
                      decoration: const InputDecoration(labelText: 'Título do Documento', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: ['manual', 'study', 'outline', 'other'].contains(category) ? category : 'manual',
                      decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'manual', child: Text('Manual / Guia')),
                        DropdownMenuItem(value: 'study', child: Text('Estudo')),
                        DropdownMenuItem(value: 'outline', child: Text('Esboço')),
                        DropdownMenuItem(value: 'other', child: Text('Outro')),
                      ],
                      onChanged: (v) => setSheetState(() => category = v ?? 'manual'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: tagsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tags (separadas por vírgula)',
                        hintText: 'Ex: ministério, apostilas, roteiros',
                        prefixIcon: Icon(Icons.tag, size: 18),
                        border: OutlineInputBorder(),
                      ),
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
                        final rawTags = tagsCtrl.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
                        final km = ref.read(knowledgeManagerProvider);
                        await km.updateDocument(doc.id, title: title, category: category, tags: rawTags);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      child: const Text('Salvar Alterações', style: TextStyle(fontWeight: FontWeight.bold)),
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
    List<String> existingTags = [];
    try {
      existingTags = (jsonDecode(resource.tags) as List).map((e) => e.toString()).toList();
    } catch (e, st) {
      AppLogger.debug('Falha ao ler tags JSON do recurso (${resource.id}): $e', st);
    }
    String resourceType = resource.resourceType;
    String category = resource.category;

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
                      decoration: const InputDecoration(labelText: 'Título do Recurso', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: urlCtrl,
                      decoration: const InputDecoration(labelText: 'Link / URL (JW.org ou pesquisa)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: tagsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tags (separadas por vírgula)',
                        hintText: 'Ex: jw, vídeos, pregação',
                        prefixIcon: Icon(Icons.tag, size: 18),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    RichMarkdownToolbar(controller: descCtrl),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Descrição / Para que serve?', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: ['jw_pub', 'video', 'article', 'scripture_chain', 'link'].contains(resourceType) ? resourceType : 'link',
                      decoration: const InputDecoration(labelText: 'Tipo de Recurso', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'jw_pub', child: Text('Publicação JW')),
                        DropdownMenuItem(value: 'video', child: Text('Vídeo')),
                        DropdownMenuItem(value: 'article', child: Text('Artigo de Revista')),
                        DropdownMenuItem(value: 'scripture_chain', child: Text('Cadeia de Textos')),
                        DropdownMenuItem(value: 'link', child: Text('Outro Link')),
                      ],
                      onChanged: (v) => setSheetState(() => resourceType = v ?? 'link'),
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
                        final descText = descCtrl.text.trim();
                        final rawTags = tagsCtrl.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
                        final km = ref.read(knowledgeManagerProvider);
                        await km.updateResource(
                          resource.id,
                          title: title,
                          url: urlText.isNotEmpty ? urlText : null,
                          description: descText.isNotEmpty ? descText : null,
                          resourceType: resourceType,
                          category: category,
                          tags: rawTags,
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      child: const Text('Salvar Alterações', style: TextStyle(fontWeight: FontWeight.bold)),
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
    final summary = note.content.length > 120 ? '${note.content.substring(0, 120)}...' : note.content;
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
      currentTags = (jsonDecode(note.tags) as List).map((e) => e.toString()).toList();
    } catch (e, st) {
      AppLogger.debug('Falha ao ler tags JSON ao vincular nota à pesquisa (${note.id}): $e', st);
    }
    if (!currentTags.contains('research:${article.id}')) {
      currentTags.add('research:${article.id}');
      await km.updateNote(note.id, tags: currentTags);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nota "${note.title}" transformada e vinculada à aba de Pesquisas!'),
          action: SnackBarAction(
            label: 'Ver Pesquisas',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ResearchScreen()),
              );
            },
          ),
        ),
      );
    }
  }

  void _exportNote(KnowledgeNoteEntry note) {
    final mdContent = '# ${note.title}\n\n**Categoria:** ${note.category}\n**Data:** ${_formatDate(note.updatedAt)}\n\n---\n\n${note.content}';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.copy, color: AppTheme.primaryBlue),
                title: const Text('Copiar Texto Formatado'),
                subtitle: const Text('Copia o conteúdo em Markdown para a área de transferência'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: mdContent));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nota copiada para a área de transferência!')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.download, color: AppTheme.primaryBlue),
                title: const Text('Baixar Arquivo Markdown (.md)'),
                subtitle: const Text('Salva localmente o arquivo com formatação'),
                onTap: () {
                  final safeName = note.title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
                  FileDownloader.download('$safeName.md', mdContent);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Download da anotação concluído!')),
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
      summary: summary.length > 120 ? '${summary.substring(0, 120)}...' : summary,
      content: contentBuffer.toString(),
      tags: ['Dúvida Teocrática', 'knowledge_question:${q.id}'],
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dúvida transformada e enviada para a aba de Pesquisas!'),
          action: SnackBarAction(
            label: 'Ver Pesquisas',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ResearchScreen()),
              );
            },
          ),
        ),
      );
    }
  }

  void _exportQuestion(KnowledgeQuestionEntry q) {
    final isAnswered = q.answer != null && q.answer!.isNotEmpty;
    final mdContent = '# Pergunta Teocrática: ${q.question}\n\n'
        '**Status:** ${isAnswered ? "Respondida" : "Pendente"}\n'
        '**Data:** ${_formatDate(q.updatedAt)}\n'
        '${q.context != null && q.context!.isNotEmpty ? "\n**Contexto:**\n${q.context}\n" : ""}'
        '${isAnswered ? "\n---\n\n### Resposta Bíblica:\n${q.answer}\n" : ""}';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.copy, color: AppTheme.primaryBlue),
                title: const Text('Copiar Texto Formatado'),
                subtitle: const Text('Copia a pergunta e resposta em Markdown para a área de transferência'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: mdContent));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Dúvida copiada para a área de transferência!')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.download, color: AppTheme.primaryBlue),
                title: const Text('Baixar Arquivo Markdown (.md)'),
                subtitle: const Text('Salva localmente o arquivo com formatação'),
                onTap: () {
                  final safeName = q.question.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
                  FileDownloader.download('Duvida_$safeName.md', mdContent);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Download da dúvida teocrática concluído!')),
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
    showAdaptiveMinistrySheet(
      context: context,
      title: 'Nova Dúvida Teocrática',
      titleLeading: const Icon(Icons.help_outline, color: Color(0xFFF59E0B)),
      builder: (ctx, scroll) => ManagedTextControllers(
        initialTexts: const ['', ''],
        builder: (ctx, ctrls) {
          final qCtrl = ctrls[0];
          final ctxCtrl = ctrls[1];

          return SingleChildScrollView(
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
                  decoration: const InputDecoration(labelText: 'Pergunta do Morador ou Pesquisa', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                RichMarkdownToolbar(controller: ctxCtrl),
                const SizedBox(height: 6),
                TextField(
                  controller: ctxCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Contexto ou Objeção (opcional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    final q = qCtrl.text.trim();
                    if (q.isEmpty) return;
                    final ctxText = ctxCtrl.text.trim();
                    final km = ref.read(knowledgeManagerProvider);
                    await km.createQuestion(
                      question: q,
                      context: ctxText.isNotEmpty ? ctxText : null,
                    );
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: const Text('Salvar Dúvida', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 12),
                RichMarkdownToolbar(controller: ansCtrl),
                const SizedBox(height: 6),
                TextField(
                  controller: ansCtrl,
                  autofocus: true,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Resposta Bíblica e Textos de Apoio...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    final ans = ansCtrl.text.trim();
                    if (ans.isEmpty) return;
                    final km = ref.read(knowledgeManagerProvider);
                    await km.answerQuestion(question.id, answer: ans);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: const Text('Salvar Resposta', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickAndRegisterDocument() async {
    try {
      final res = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'epub', 'doc', 'docx', 'txt'],
      );
      if (res.isNotEmpty) {
        final f = res.first;
        String finalPath = f.path ?? f.name;
        Uint8List? fileBytes;
        try {
          fileBytes = await f.readAsBytes();
        } catch (e, st) {
          AppLogger.debug('Falha ao ler bytes diretos do FilePicker (${f.name}): $e', st);
        }
        int fileSize = fileBytes?.length ?? f.lengthSync() ?? (await f.length()) ?? 0;

        if (!kIsWeb) {
          try {
            if ((fileBytes == null || fileBytes.isEmpty) && f.path != null && f.path!.isNotEmpty) {
              final sourceFile = File(f.path!);
              if (await sourceFile.exists()) {
                try {
                  fileBytes = await sourceFile.readAsBytes();
                } catch (e, st) {
                  AppLogger.debug('Falha ao ler bytes do arquivo origem (${f.path}): $e', st);
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

        final fileExt = f.name.contains('.') ? f.name.split('.').last.toLowerCase() : 'other';
        final km = ref.read(knowledgeManagerProvider);
        final registeredDoc = await km.registerDocument(
          title: f.name.split('.').first,
          fileName: f.name,
          filePath: finalPath,
          fileSize: fileSize,
          fileType: fileExt,
          category: 'manual',
        );

        if (fileBytes != null && fileBytes.isNotEmpty) {
          try {
            final appDb = ref.read(databaseProvider);
            await appDb.into(appDb.appKvStore).insertOnConflictUpdate(
                  AppKvStoreCompanion.insert(
                    key: 'doc_bytes_${registeredDoc.id}',
                    value: base64Encode(fileBytes),
                    updatedAt: drift.Value(DateTime.now()),
                  ),
                );
          } catch (e, st) {
            AppLogger.warning('Falha ao armazenar bytes do documento (${registeredDoc.id}) em cache KV', e, st);
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Documento registrado na Base de Conhecimento!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao anexar documento: $e')),
        );
      }
    }
  }

  void _showCreateResourceModal() {
    showAdaptiveMinistrySheet(
      context: context,
      title: 'Novo Recurso / Link',
      titleLeading: const Icon(Icons.link, color: Colors.teal),
      builder: (ctx, scroll) => ManagedTextControllers(
        initialTexts: const ['', '', '', ''],
        builder: (ctx, ctrls) {
          final titleCtrl = ctrls[0];
          final urlCtrl = ctrls[1];
          final descCtrl = ctrls[2];
          final tagsCtrl = ctrls[3];

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
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Título do Recurso', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(labelText: 'URL (ex: https://www.jw.org/...)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tagsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tags (separadas por vírgula)',
                    hintText: 'Ex: jw, vídeos, pregação',
                    prefixIcon: Icon(Icons.tag, size: 18),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                RichMarkdownToolbar(controller: descCtrl),
                const SizedBox(height: 6),
                TextField(
                  controller: descCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Descrição / Para qual ocasião serve?', border: OutlineInputBorder()),
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
                    final descText = descCtrl.text.trim();
                    final rawTags = tagsCtrl.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
                    final km = ref.read(knowledgeManagerProvider);
                    await km.createResource(
                      title: title,
                      resourceType: 'link',
                      url: urlText.isNotEmpty ? urlText : null,
                      description: descText.isNotEmpty ? descText : null,
                      tags: rawTags,
                    );
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: const Text('Salvar Recurso', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
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
            AppLogger.debug('Falha ao ler arquivo direto (${doc.filePath}): $e', st);
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
            AppLogger.debug('Diretório ApplicationSupport indisponível: $e', st);
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
                AppLogger.debug('Falha ao ler candidato de documento (${c.path}): $e', st);
              }
              break;
            }
          }
        }
      } catch (e, st) {
        AppLogger.warning('Falha ao localizar documento (${doc.id}) no disco', e, st);
      }
    }

    if (resolvedBytes == null || resolvedBytes.isEmpty) {
      try {
        final appDb = ref.read(databaseProvider);
        final kv = await (appDb.select(appDb.appKvStore)
              ..where((t) => t.key.equals('doc_bytes_${doc.id}')))
            .getSingleOrNull();
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
            AppLogger.debug('Falha ao ler arquivo direto para abrir (${doc.filePath}): $e', st);
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
            AppLogger.debug('ApplicationSupport indisponível ao abrir anexo: $e', st);
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
                AppLogger.debug('Falha ao ler candidato para abrir (${c.path}): $e', st);
              }
              break;
            }
          }
        }
      } catch (e, st) {
        AppLogger.warning('Falha ao localizar documento externo (${doc.id})', e, st);
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
      AppLogger.warning('Falha ao abrir documento externamente; usando visualizador interno', e, st);
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
      default:
        _showAddKnowledgeItemMenu();
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
          label: const Text('Nova Nota', style: TextStyle(fontWeight: FontWeight.bold)),
        );
      case 1:
        return FloatingActionButton.extended(
          heroTag: 'fab_kb_1',
          onPressed: _showCreateQuestionModal,
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.help_outline),
          label: const Text('Nova Dúvida', style: TextStyle(fontWeight: FontWeight.bold)),
        );
      case 2:
        return FloatingActionButton.extended(
          heroTag: 'fab_kb_2',
          onPressed: _pickAndRegisterDocument,
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.upload_file),
          label: const Text('Anexar Documento', style: TextStyle(fontWeight: FontWeight.bold)),
        );
      case 3:
        return FloatingActionButton.extended(
          heroTag: 'fab_kb_3',
          onPressed: _showCreateResourceModal,
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_link),
          label: const Text('Novo Recurso', style: TextStyle(fontWeight: FontWeight.bold)),
        );
      default:
        return FloatingActionButton.extended(
          heroTag: 'fab_kb_def',
          onPressed: _showAddKnowledgeItemMenu,
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Novo Item', style: TextStyle(fontWeight: FontWeight.bold)),
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
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }
}
