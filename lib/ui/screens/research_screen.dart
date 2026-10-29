import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_theme.dart';
import '../../media/media_picker_helper.dart';
import '../../research/research_manager.dart';

class ResearchScreen extends ConsumerStatefulWidget {
  const ResearchScreen({super.key});

  @override
  ConsumerState<ResearchScreen> createState() => _ResearchScreenState();
}

class _ResearchScreenState extends ConsumerState<ResearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategoryTag;
  bool _isWeeklyCardExpanded = true;
  String _sampleTitle = 'Como a Bíblia pode ajudar você?';
  String _sampleQuestion = 'Você acha que a Bíblia pode nos ajudar a lidar com as ansiedades da vida?';
  String _sampleScripture = 'Filipenses 4:6, 7 — "Não fiquem ansiosos por causa de coisa alguma, mas em tudo... as suas petições sejam conhecidas por Deus."';
  String _samplePublication = 'Livro "Seja Feliz Para Sempre!" (Lição 01)';
  String _sampleVideoUrl = 'https://www.jw.org/pt/biblioteca/videos/';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showManageTagsDialog(BuildContext context, List<ResearchTagItem> tags) {
    final newTagController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.label, color: AppTheme.primaryBlue),
                SizedBox(width: 8),
                Text('Gerenciar Categorias / Tags'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: newTagController,
                            decoration: const InputDecoration(
                              labelText: 'Nova Categoria / Tag',
                              hintText: 'Ex: Arqueologia Bíblica',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final text = newTagController.text.trim();
                            if (text.isNotEmpty) {
                              final mgr = ref.read(researchManagerProvider);
                              await mgr.addTag(text);
                              newTagController.clear();
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Categoria "$text" criada com sucesso!')),
                                );
                              }
                            }
                          },
                          child: const Text('Adicionar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const Text('Categorias Existentes:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    if (tags.isEmpty)
                      const Text('Nenhuma categoria cadastrada.', style: TextStyle(color: AppTheme.textMuted))
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: tags.length,
                        itemBuilder: (c, i) {
                          final t = tags[i];
                          return ListTile(
                            dense: true,
                            title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  tooltip: 'Renomear',
                                  onPressed: () {
                                    final editController = TextEditingController(text: t.name);
                                    showDialog(
                                      context: context,
                                      builder: (editCtx) => AlertDialog(
                                        title: const Text('Renomear Categoria'),
                                        content: TextField(controller: editController, autofocus: true),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(editCtx), child: const Text('Cancelar')),
                                          ElevatedButton(
                                            onPressed: () async {
                                              final newName = editController.text.trim();
                                              if (newName.isNotEmpty) {
                                                final mgr = ref.read(researchManagerProvider);
                                                await mgr.updateTag(t.id, newName);
                                                if (editCtx.mounted) Navigator.pop(editCtx);
                                                if (ctx.mounted) Navigator.pop(ctx);
                                              }
                                            },
                                            child: const Text('Salvar'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                  tooltip: 'Excluir',
                                  onPressed: () async {
                                    final mgr = ref.read(researchManagerProvider);
                                    await mgr.deleteTag(t.id);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Categoria "${t.name}" excluída.')),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
            ],
          );
        },
      ),
    );
  }

  void _showReadMoreDialog(BuildContext context, ResearchArticleItem article) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          article.title,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  if (article.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: article.tags.map((t) {
                        return Chip(
                          label: Text('#$t', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // Bloco de Resumo em destaque
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '📌 Resumo para Visitas / Estudos:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryBlue),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          article.summary,
                          style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Conteúdo Completo
                  const Text('Conteúdo e Textos de Apoio:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  SelectableText(
                    article.content,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.textDark,
                    ),
                  ),

                  // Anexos / Fotos
                  if (article.attachments.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('Fotos e Materiais Anexados:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: article.attachments.length,
                        itemBuilder: (c, i) {
                          final att = article.attachments[i];
                          return GestureDetector(
                            onTap: () => MediaPickerHelper.showFullScreenImage(context, imageSource: att, title: article.title),
                            child: Container(
                              margin: const EdgeInsets.only(right: 10),
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: MediaPickerHelper.buildImageWidget(att),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copiar Texto'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: '${article.title}\n\n${article.summary}\n\n${article.content}'));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Pesquisa copiada para a área de transferência!')),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Editar Pesquisa'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showAddEditArticleModal(context, existing: article);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddEditArticleModal(BuildContext context, {ResearchArticleItem? existing}) {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final summaryController = TextEditingController(text: existing?.summary ?? '');
    final contentController = TextEditingController(text: existing?.content ?? '');
    final tags = List<String>.from(existing?.tags ?? []);
    final attachments = List<String>.from(existing?.attachments ?? []);
    final tagInputController = TextEditingController();

    final availableTags = ref.read(researchTagsStreamProvider).value ?? [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return Dialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(existing != null ? Icons.edit_document : Icons.menu_book, color: AppTheme.primaryBlue, size: 26),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            existing != null ? 'Editar Material de Pesquisa' : 'Nova Pesquisa para o Ministério',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          tooltip: 'Fechar',
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cadastre argumentos, matérias bíblicas e raciocínios para usar durante as visitas e estudos.',
                              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: titleController,
                              decoration: const InputDecoration(
                                labelText: 'Título do Assunto *',
                                hintText: 'Ex: Como provar que a Bíblia é a palavra de Deus',
                              ),
                              autofocus: existing == null,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: summaryController,
                              decoration: const InputDecoration(
                                labelText: 'Pequeno Resumo (aparece no bloco da tela inicial) *',
                                hintText: 'Ex: 3 argumentos práticos: harmonia interna, profecias e exatidão científica',
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: contentController,
                              decoration: const InputDecoration(
                                labelText: 'Conteúdo Completo & Textos Bíblicos *',
                                hintText: 'Digite o conteúdo detalhado, perguntas para raciocinar e textos bíblicos de referência...',
                              ),
                              maxLines: 6,
                            ),
                            const SizedBox(height: 12),

                            // SELETOR DE CATEGORIAS / TAGS
                            const Text('Categorias / Tags:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 6),
                            if (availableTags.isNotEmpty)
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: availableTags.map((t) {
                                  final isSelected = tags.contains(t.name);
                                  return FilterChip(
                                    label: Text(t.name, style: const TextStyle(fontSize: 11)),
                                    selected: isSelected,
                                    onSelected: (val) {
                                      setDialogState(() {
                                        if (val) {
                                          tags.add(t.name);
                                        } else {
                                          tags.remove(t.name);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: tagInputController,
                                    decoration: const InputDecoration(
                                      labelText: 'Ou criar nova tag',
                                      hintText: 'Ex: profecias, trindade',
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle, color: AppTheme.primaryBlue),
                                  onPressed: () async {
                                    final text = tagInputController.text.trim();
                                    if (text.isNotEmpty && !tags.contains(text)) {
                                      final mgr = ref.read(researchManagerProvider);
                                      await mgr.addTag(text);
                                      setDialogState(() {
                                        tags.add(text);
                                        tagInputController.clear();
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),
                            // FOTOS / ARQUIVOS
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Fotos / Arquivos de Apoio:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                IconButton.filledTonal(
                                  icon: const Icon(Icons.add_photo_alternate, size: 18),
                                  onPressed: () async {
                                    final img = await MediaPickerHelper.pickImage(context, title: 'Anexar Imagem à Pesquisa');
                                    if (img != null && img.isNotEmpty) {
                                      setDialogState(() => attachments.add(img));
                                    }
                                  },
                                ),
                              ],
                            ),
                            if (attachments.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: List.generate(attachments.length, (i) {
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        width: 70,
                                        height: 70,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.grey.shade300),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: MediaPickerHelper.buildImageWidget(attachments[i]),
                                        ),
                                      ),
                                      Positioned(
                                        top: -4,
                                        right: -4,
                                        child: InkWell(
                                          onTap: () => setDialogState(() => attachments.removeAt(i)),
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ),
                            ],
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
                          label: const Text('Salvar'),
                          onPressed: () async {
                            final title = titleController.text.trim();
                            final summary = summaryController.text.trim();
                            final content = contentController.text.trim();
                            if (title.isEmpty || summary.isEmpty || content.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Por favor, preencha o título, o resumo e o conteúdo completo.')),
                              );
                              return;
                            }

                            final mgr = ref.read(researchManagerProvider);
                            if (existing != null) {
                              await mgr.updateArticle(ResearchArticleItem(
                                id: existing.id,
                                title: title,
                                summary: summary,
                                content: content,
                                tags: tags,
                                attachments: attachments,
                                createdAt: existing.createdAt,
                                updatedAt: DateTime.now(),
                              ));
                            } else {
                              await mgr.addArticle(
                                title: title,
                                summary: summary,
                                content: content,
                                tags: tags,
                                attachments: attachments,
                              );
                            }

                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(existing != null ? 'Pesquisa atualizada!' : 'Pesquisa cadastrada com sucesso!')),
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

  @override
  Widget build(BuildContext context) {
    final articlesAsync = ref.watch(researchArticlesStreamProvider);
    final tagsAsync = ref.watch(researchTagsStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final articles = articlesAsync.value ?? [];
    final tags = tagsAsync.value ?? [];

    final query = _searchController.text.trim().toLowerCase();

    // PESQUISA COMPLETA: busca em title, summary E content (full text)
    final filtered = articles.where((a) {
      if (query.isNotEmpty) {
        final titleMatches = a.title.toLowerCase().contains(query);
        final summaryMatches = a.summary.toLowerCase().contains(query);
        final contentMatches = a.content.toLowerCase().contains(query);
        final tagMatches = a.tags.any((t) => t.toLowerCase().contains(query));
        if (!titleMatches && !summaryMatches && !contentMatches && !tagMatches) {
          return false;
        }
      }
      if (_selectedCategoryTag != null && !a.tags.contains(_selectedCategoryTag)) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anotações & Pesquisas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.label_outlined),
            tooltip: 'Gerenciar Categorias / Tags',
            onPressed: () => _showManageTagsDialog(context, tags),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '+ Nova Pesquisa',
            onPressed: () => _showAddEditArticleModal(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.post_add),
        label: const Text('+ Nova Pesquisa'),
        onPressed: () => _showAddEditArticleModal(context),
      ),
      body: Column(
        children: [
          // Ideia 6: Cartão de Bolso da Apresentação da Semana
          _buildWeeklyPresentationPocketCard(context, isDark),

          // Barra de Pesquisa Completa
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Pesquisar em todo o texto, título, resumo ou assunto...',
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

          // Categorias / Tags em destaque na tela inicial
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: const Text('Todas Categorias'),
                            selected: _selectedCategoryTag == null,
                            onSelected: (val) => setState(() => _selectedCategoryTag = null),
                            selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
                            checkmarkColor: AppTheme.primaryBlue,
                          ),
                        ),
                        for (final t in tags)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(t.name),
                              selected: _selectedCategoryTag == t.name,
                              onSelected: (val) => setState(() => _selectedCategoryTag = val ? t.name : null),
                              selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
                              checkmarkColor: AppTheme.primaryBlue,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.tune, size: 14),
                  label: const Text('Tags', style: TextStyle(fontSize: 12)),
                  onPressed: () => _showManageTagsDialog(context, tags),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Blocos com Título, Resumo e Botão "Leia mais"
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.menu_book_outlined, size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            query.isEmpty
                                ? 'Nenhuma pesquisa cadastrada ainda.\nToque em "+ Nova Pesquisa" para organizar matérias e textos bíblicos para o ministério.'
                                : 'Nenhuma matéria encontrada com a expressão "$query".',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.article, color: AppTheme.primaryBlue, size: 22),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.summary,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textDark,
                                            height: 1.3,
                                          ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    padding: EdgeInsets.zero,
                                    onSelected: (val) async {
                                      if (val == 'edit') {
                                        _showAddEditArticleModal(context, existing: item);
                                      } else if (val == 'delete') {
                                        final mgr = ref.read(researchManagerProvider);
                                        await mgr.deleteArticle(item.id);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Pesquisa removida.')),
                                          );
                                        }
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'edit', child: Text('Editar')),
                                      PopupMenuItem(value: 'delete', child: Text('Excluir')),
                                    ],
                                  ),
                                ],
                              ),
                              if (item.tags.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 4,
                                  children: item.tags.map((t) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text('#$t', style: const TextStyle(fontSize: 10, color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
                                    );
                                  }).toList(),
                                ),
                              ],
                              const Divider(height: 18),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  if (item.attachments.isNotEmpty)
                                    Row(
                                      children: [
                                        const Icon(Icons.attach_file, size: 14, color: AppTheme.textMuted),
                                        const SizedBox(width: 4),
                                        Text('${item.attachments.length} anexo(s)', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                      ],
                                    )
                                  else
                                    const SizedBox.shrink(),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryBlue,
                                      foregroundColor: Colors.white,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    ),
                                    icon: const Icon(Icons.chrome_reader_mode, size: 14),
                                    label: const Text('Leia mais', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    onPressed: () => _showReadMoreDialog(context, item),
                                  ),
                                ],
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
    );
  }

  Widget _buildWeeklyPresentationPocketCard(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _isWeeklyCardExpanded = !_isWeeklyCardExpanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.style_outlined, color: Color(0xFFB45309), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Cartão de Bolso da Semana',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E)),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFB45309).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Vida e Ministério', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                            ),
                          ],
                        ),
                        Text(
                          _sampleTitle,
                          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF78350F), fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(_isWeeklyCardExpanded ? Icons.expand_less : Icons.expand_more, color: const Color(0xFFB45309)),
                    onPressed: () => setState(() => _isWeeklyCardExpanded = !_isWeeklyCardExpanded),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),
          if (_isWeeklyCardExpanded) ...[
            const Divider(height: 1, color: Color(0xFFFDE68A)),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('❓ Pergunta: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFB45309))),
                      Expanded(
                        child: Text(
                          _sampleQuestion,
                          style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('📖 Texto: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFB45309))),
                      Expanded(
                        child: Text(
                          _sampleScripture,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💡 Oferta: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFB45309))),
                      Expanded(
                        child: Text(
                          _samplePublication,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          icon: const Icon(Icons.copy, size: 14),
                          label: const Text('Copiar p/ WhatsApp', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            final text = '''*Apresentação Modelo da Semana*
Olá! Gostaria de compartilhar uma breve reflexão:
❓ *Pergunta:* $_sampleQuestion
📖 *Texto Bíblico:* $_sampleScripture
💡 *Saiba mais:* $_samplePublication''';
                            Clipboard.setData(ClipboardData(text: text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Apresentação copiada para envio via WhatsApp/SMS!')),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFB45309),
                          side: const BorderSide(color: Color(0xFFF59E0B)),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        icon: const Icon(Icons.play_circle_outline, size: 14),
                        label: const Text('Vídeo', style: TextStyle(fontSize: 11)),
                        onPressed: () async {
                          final uri = Uri.parse(_sampleVideoUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.edit_note, color: Color(0xFFB45309), size: 20),
                        tooltip: 'Editar Apresentação da Semana',
                        onPressed: () => _showEditWeeklyPresentationModal(context),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showEditWeeklyPresentationModal(BuildContext context) {
    final titleCtrl = TextEditingController(text: _sampleTitle);
    final questionCtrl = TextEditingController(text: _sampleQuestion);
    final scriptureCtrl = TextEditingController(text: _sampleScripture);
    final pubCtrl = TextEditingController(text: _samplePublication);
    final videoCtrl = TextEditingController(text: _sampleVideoUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.style, color: Color(0xFFD97706)),
            SizedBox(width: 8),
            Text('Editar Cartão da Semana'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Tema / Título da Apresentação'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: questionCtrl,
                decoration: const InputDecoration(labelText: 'Pergunta de Introdução'),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: scriptureCtrl,
                decoration: const InputDecoration(labelText: 'Texto Bíblico Principal'),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: pubCtrl,
                decoration: const InputDecoration(labelText: 'Publicação de Oferta'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: videoCtrl,
                decoration: const InputDecoration(labelText: 'Link do Vídeo / JW Library'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                _sampleTitle = titleCtrl.text.trim();
                _sampleQuestion = questionCtrl.text.trim();
                _sampleScripture = scriptureCtrl.text.trim();
                _samplePublication = pubCtrl.text.trim();
                _sampleVideoUrl = videoCtrl.text.trim();
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cartão de Bolso da Semana atualizado com sucesso!')),
              );
            },
            child: const Text('Salvar Cartão'),
          ),
        ],
      ),
    );
  }
}

