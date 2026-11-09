import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../database/app_database.dart';
import '../providers.dart';
import '../widgets/adaptive_ministry_sheet.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
            onPressed: _showAddKnowledgeItemMenu,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddKnowledgeItemMenu,
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Novo Item', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
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

        final notes = snapshot.data ?? [];
        if (notes.isEmpty) {
          return _buildEmptyState(
            icon: Icons.note_outlined,
            title: 'Nenhuma nota registrada',
            subtitle: 'Guarde anotações temáticas, ideias de pregações ou notas pastorais.',
            isDark: isDark,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: notes.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 10),
          itemBuilder: (ctx, i) {
            final note = notes[i];
            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                            if (val == 'delete') km.softDeleteNote(note.id);
                          },
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                              value: 'pin',
                              child: Text(note.isPinned ? 'Desafixar' : 'Fixar no Topo'),
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
                    Text(
                      note.content,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        Text(
                          _formatDate(note.updatedAt),
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
      stream: km.watchQuestions(query: _searchQuery.isNotEmpty ? _searchQuery : null),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final questions = snapshot.data ?? [];
        if (questions.isEmpty) {
          return _buildEmptyState(
            icon: Icons.help_outline_rounded,
            title: 'Nenhuma dúvida cadastrada',
            subtitle: 'Registre perguntas de moradores ou pesquisas para responder na próxima visita.',
            isDark: isDark,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: questions.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 10),
          itemBuilder: (ctx, i) {
            final q = questions[i];
            final isAnswered = q.status == 'answered';

            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: (isAnswered ? Colors.green : Colors.amber).withValues(alpha: 0.15),
                  child: Icon(
                    isAnswered ? Icons.check : Icons.question_mark,
                    color: isAnswered ? Colors.green : Colors.amber,
                    size: 18,
                  ),
                ),
                title: Text(q.question, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(
                  isAnswered ? 'Respondida' : 'Dúvida em Aberto',
                  style: TextStyle(
                    fontSize: 11,
                    color: isAnswered ? Colors.green : Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (q.context != null && q.context!.isNotEmpty) ...[
                          Text(
                            'Contexto / Detalhes:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 4),
                          Text(q.context!, style: const TextStyle(fontSize: 13)),
                          const SizedBox(height: 10),
                        ],
                        if (q.answer != null && q.answer!.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.menu_book, size: 14, color: Colors.green),
                                    SizedBox(width: 4),
                                    Text('Resposta Bíblica:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(q.answer!, style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.edit_note, size: 16),
                              label: Text(isAnswered ? 'Editar Resposta' : 'Inserir Resposta Bíblica'),
                              onPressed: () => _showAnswerQuestionModal(q),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                              tooltip: 'Excluir Dúvida',
                              onPressed: () => km.softDeleteQuestion(q.id),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
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
      stream: km.watchDocuments(query: _searchQuery.isNotEmpty ? _searchQuery : null),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data ?? [];
        if (docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.folder_shared_outlined,
            title: 'Nenhum documento anexado',
            subtitle: 'Guarde manuais, roteiros ou apostilas em PDF diretamente no app.',
            isDark: isDark,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final doc = docs[i];
            final sizeKb = (doc.fileSize / 1024).toStringAsFixed(1);

            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.description, color: AppTheme.primaryBlue, size: 24),
                ),
                title: Text(doc.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('${doc.fileName} • $sizeKb KB\nCategoria: ${doc.category}'),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                  onPressed: () => km.softDeleteDocument(doc.id),
                ),
              ),
            );
          },
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
      stream: km.watchResources(query: _searchQuery.isNotEmpty ? _searchQuery : null),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final resources = snapshot.data ?? [];
        if (resources.isEmpty) {
          return _buildEmptyState(
            icon: Icons.link_rounded,
            title: 'Nenhum recurso cadastrado',
            subtitle: 'Salve links do JW.org, lições bíblicas ou vídeos úteis para as conversas.',
            isDark: isDark,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: resources.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final r = resources[i];

            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.link, color: Colors.teal, size: 24),
                ),
                title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(r.description ?? r.url ?? r.resourceType),
                trailing: r.url != null && r.url!.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.open_in_new, size: 18, color: AppTheme.primaryBlue),
                        onPressed: () => _openUrl(r.url!),
                      )
                    : null,
              ),
            );
          },
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
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String category = 'general';

    showAdaptiveMinistrySheet(
      context: context,
      title: 'Nova Nota',
      titleLeading: const Icon(Icons.note_add, color: Color(0xFF8B5CF6)),
      builder: (ctx, scroll) {
        return Padding(
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
              TextField(
                controller: contentCtrl,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Conteúdo...', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  final title = titleCtrl.text.trim();
                  if (title.isEmpty) return;
                  final km = ref.read(knowledgeManagerProvider);
                  await km.createNote(
                    title: title,
                    content: contentCtrl.text.trim(),
                    category: category,
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: const Text('Salvar Nota', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCreateQuestionModal() {
    final qCtrl = TextEditingController();
    final ctxCtrl = TextEditingController();

    showAdaptiveMinistrySheet(
      context: context,
      title: 'Nova Dúvida Teocrática',
      titleLeading: const Icon(Icons.help_outline, color: Color(0xFFF59E0B)),
      builder: (ctx, scroll) {
        return Padding(
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
              TextField(
                controller: ctxCtrl,
                maxLines: 3,
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
                  final km = ref.read(knowledgeManagerProvider);
                  await km.createQuestion(
                    question: q,
                    context: ctxCtrl.text.trim().isNotEmpty ? ctxCtrl.text.trim() : null,
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: const Text('Salvar Dúvida', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAnswerQuestionModal(KnowledgeQuestionEntry question) {
    final ansCtrl = TextEditingController(text: question.answer ?? '');

    showAdaptiveMinistrySheet(
      context: context,
      title: 'Responder Dúvida',
      titleLeading: const Icon(Icons.menu_book, color: Colors.green),
      builder: (ctx, scroll) {
        return Padding(
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
        final km = ref.read(knowledgeManagerProvider);
        await km.registerDocument(
          title: f.name.split('.').first,
          fileName: f.name,
          filePath: f.path ?? f.name,
          fileSize: (await f.length()) ?? 0,
          fileType: f.extension ?? 'other',
          category: 'manual',
        );
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
    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showAdaptiveMinistrySheet(
      context: context,
      title: 'Novo Recurso / Link',
      titleLeading: const Icon(Icons.link, color: Colors.teal),
      builder: (ctx, scroll) {
        return Padding(
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
                controller: descCtrl,
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
                  final km = ref.read(knowledgeManagerProvider);
                  await km.createResource(
                    title: title,
                    resourceType: 'link',
                    url: urlCtrl.text.trim().isNotEmpty ? urlCtrl.text.trim() : null,
                    description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: const Text('Salvar Recurso', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
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
