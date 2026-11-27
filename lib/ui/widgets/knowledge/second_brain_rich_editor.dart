import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_theme.dart';
import '../../../database/app_database.dart';
import '../../../references/app_reference.dart';
import '../../providers.dart';
import '../rich_formatted_editing_controller.dart';
import '../rich_markdown_toolbar.dart';

class _SlashCommandItem {
  final String command;
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final String actionType;

  const _SlashCommandItem({
    required this.command,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.actionType,
  });
}

/// Editor de texto rico completo do Segundo Cérebro estilo Notion:
/// - Integra barra [RichMarkdownToolbar] com realces estilo JW Library
/// - Detecta `[[` antes do cursor e exibe sugestões de notas, estudos, pessoas,
///   tarefas, projetos e documentos com inserção limpa via `app://ref/...`
/// - Detecta `/` para comandos rápidos (`/titulo1`, `/titulo2`, `/checklist`,
///   `/callout`, `/dica`, `/aviso`, `/toggle`, `/tabela`, `/citacao`, `/biblia`, `/link`)
class SecondBrainRichEditor extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final int minLines;
  final int maxLines;
  final bool enableHighlightPalette;
  final bool enableCrossReferences;
  final bool enableImagePicker;
  final AppRefCategory initialReferenceCategory;
  final VoidCallback? onChanged;
  final Future<AppReferenceCandidate?> Function(String title)?
  onCreateInlineNote;

  const SecondBrainRichEditor({
    super.key,
    required this.controller,
    this.labelText = 'Conteúdo da Nota',
    this.hintText =
        'Digite / para blocos e comandos ou [[ para vincular referências...',
    this.minLines = 5,
    this.maxLines = 10,
    this.enableHighlightPalette = true,
    this.enableCrossReferences = true,
    this.enableImagePicker = true,
    this.initialReferenceCategory = AppRefCategory.note,
    this.onChanged,
    this.onCreateInlineNote,
  });

  @override
  ConsumerState<SecondBrainRichEditor> createState() =>
      _SecondBrainRichEditorState();
}

class _SecondBrainRichEditorState extends ConsumerState<SecondBrainRichEditor> {
  static const List<_SlashCommandItem> _slashCommands = [
    _SlashCommandItem(
      command: 'titulo1',
      label: 'Título Principal (H1)',
      description: 'Cabeçalho grande para seção',
      icon: Icons.title_rounded,
      color: Color(0xFF6366F1),
      actionType: 'h1',
    ),
    _SlashCommandItem(
      command: 'titulo2',
      label: 'Subtítulo (H2)',
      description: 'Subseção organizada',
      icon: Icons.format_size_rounded,
      color: Color(0xFF3B82F6),
      actionType: 'h2',
    ),
    _SlashCommandItem(
      command: 'checklist',
      label: 'Checklist Interativo',
      description: 'Caixa clicável de acompanhamento',
      icon: Icons.check_box_outlined,
      color: Color(0xFF10B981),
      actionType: 'checklist',
    ),
    _SlashCommandItem(
      command: 'toggle',
      label: 'Bloco Expansível (Toggle)',
      description: 'Seção recolhível para detalhes',
      icon: Icons.arrow_drop_down_circle_outlined,
      color: Color(0xFF8B5CF6),
      actionType: 'toggle',
    ),
    _SlashCommandItem(
      command: 'callout',
      label: 'Callout / Destaque',
      description: 'Caixa visual de nota importante',
      icon: Icons.info_outline_rounded,
      color: Color(0xFF0EA5E9),
      actionType: 'callout_note',
    ),
    _SlashCommandItem(
      command: 'dica',
      label: 'Callout Dica',
      description: 'Destaque verde de aplicação prática',
      icon: Icons.lightbulb_outline_rounded,
      color: Color(0xFF10B981),
      actionType: 'callout_tip',
    ),
    _SlashCommandItem(
      command: 'aviso',
      label: 'Callout Atenção',
      description: 'Destaque âmbar de alerta',
      icon: Icons.warning_amber_rounded,
      color: Color(0xFFF59E0B),
      actionType: 'callout_warning',
    ),
    _SlashCommandItem(
      command: 'tabela',
      label: 'Tabela Comparativa',
      description: 'Tabela estruturada 3 colunas',
      icon: Icons.table_chart_outlined,
      color: Color(0xFFEC4899),
      actionType: 'table',
    ),
    _SlashCommandItem(
      command: 'citacao',
      label: 'Citação',
      description: 'Parágrafo destacado de citação',
      icon: Icons.format_quote_rounded,
      color: Color(0xFF64748B),
      actionType: 'quote',
    ),
    _SlashCommandItem(
      command: 'biblia',
      label: 'Texto Bíblico (TNM)',
      description: 'Inserir versículo interativo no popup',
      icon: Icons.menu_book_rounded,
      color: Color(0xFF2563EB),
      actionType: 'bible',
    ),
    _SlashCommandItem(
      command: 'link',
      label: 'Vincular Referência [[',
      description: 'Abrir seletor de notas, estudos, pessoas',
      icon: Icons.link_rounded,
      color: Color(0xFF0D9488),
      actionType: 'ref_picker',
    ),
  ];

  // Estado de detecção contextual antes do cursor
  String? _activeTriggerType; // 'wikilink' | 'slash' | null
  int _triggerStartOffset = -1;
  String _triggerQuery = '';

  List<AppReferenceCandidate> _wikiCandidates = const [];
  bool _loadingWikiCandidates = false;
  bool _wikiCatalogLoadedOnce = false;
  List<AppReferenceCandidate> _cachedWikiCatalog = const [];
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextOrSelectionChanged);
  }

  @override
  void didUpdateWidget(covariant SecondBrainRichEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextOrSelectionChanged);
      widget.controller.addListener(_onTextOrSelectionChanged);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    widget.controller.removeListener(_onTextOrSelectionChanged);
    super.dispose();
  }

  AppDatabase? _tryReadDb() {
    try {
      return ProviderScope.containerOf(
        context,
        listen: false,
      ).read(databaseProvider);
    } catch (_) {
      return null;
    }
  }

  void _onTextOrSelectionChanged() {
    if (!mounted) return;
    final sel = widget.controller.selection;
    final text = widget.controller.text;
    if (!sel.isValid || !sel.isCollapsed) {
      _clearTrigger();
      return;
    }

    final cursor = sel.baseOffset.clamp(0, text.length);
    final beforeCursor = text.substring(0, cursor);

    // 1. Verifica gatilho `[[...` sem quebra de linha nem `]`
    final wikiMatch = RegExp(r'\[\[([^\n\]]*)$').firstMatch(beforeCursor);
    if (wikiMatch != null) {
      final query = wikiMatch.group(1) ?? '';
      final start = wikiMatch.start;
      if (_activeTriggerType != 'wikilink' ||
          _triggerStartOffset != start ||
          _triggerQuery != query) {
        setState(() {
          _activeTriggerType = 'wikilink';
          _triggerStartOffset = start;
          _triggerQuery = query;
        });
        _scheduleWikiLookup(query);
      }
      return;
    }

    // 2. Verifica comando `/` no início da linha ou após espaço em branco
    final slashMatch = RegExp(r'(?:^|\n|\s)/([a-zA-Z0-9_-]*)$')
        .firstMatch(beforeCursor);
    if (slashMatch != null) {
      final query = slashMatch.group(1) ?? '';
      final slashIndex = beforeCursor.lastIndexOf('/');
      if (_activeTriggerType != 'slash' ||
          _triggerStartOffset != slashIndex ||
          _triggerQuery != query) {
        setState(() {
          _activeTriggerType = 'slash';
          _triggerStartOffset = slashIndex;
          _triggerQuery = query.toLowerCase();
        });
      }
      return;
    }

    _clearTrigger();
  }

  void _clearTrigger() {
    if (_activeTriggerType != null) {
      setState(() {
        _activeTriggerType = null;
        _triggerStartOffset = -1;
        _triggerQuery = '';
      });
    }
  }

  void _scheduleWikiLookup(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 90), () {
      _loadAndFilterWikiCandidates(query);
    });
  }

  Future<void> _loadAndFilterWikiCandidates(String rawQuery) async {
    final db = _tryReadDb();
    if (db == null) return;
    if (!_wikiCatalogLoadedOnce) {
      if (mounted) setState(() => _loadingWikiCandidates = true);
      const cats = [
        AppRefCategory.note,
        AppRefCategory.question,
        AppRefCategory.research,
        AppRefCategory.project,
        AppRefCategory.task,
        AppRefCategory.document,
        AppRefCategory.resource,
        AppRefCategory.person,
        AppRefCategory.study,
      ];
      final all = <AppReferenceCandidate>[];
      for (final c in cats) {
        try {
          final items = await AppReferenceHelper.loadCandidates(db, c);
          all.addAll(items);
        } catch (_) {}
      }
      _cachedWikiCatalog = all;
      _wikiCatalogLoadedOnce = true;
    }

    final q = rawQuery.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _cachedWikiCatalog.take(10).toList()
        : _cachedWikiCatalog
              .where(
                (c) =>
                    c.title.toLowerCase().contains(q) ||
                    c.subtitle.toLowerCase().contains(q) ||
                    c.category.shortLabel.toLowerCase().contains(q),
              )
              .take(12)
              .toList();

    if (mounted) {
      setState(() {
        _wikiCandidates = filtered;
        _loadingWikiCandidates = false;
      });
    }
  }

  void _replaceTriggerAndInsert({
    String? rawToken,
    String? linkLabel,
    String? linkUrl,
  }) {
    final ctrl = widget.controller;
    final text = ctrl.text;
    final sel = ctrl.selection;
    final cursor = (sel.isValid ? sel.baseOffset : text.length).clamp(
      0,
      text.length,
    );
    final start = _triggerStartOffset.clamp(0, cursor);

    // Remove o trecho do gatilho (`[[query` ou `/cmd`) preservando spans se controller for WYSIWYG.
    final cleanedText = text.replaceRange(start, cursor, '');
    ctrl.value = TextEditingValue(
      text: cleanedText,
      selection: TextSelection.collapsed(offset: start),
    );

    if (linkLabel != null &&
        linkUrl != null &&
        linkUrl.isNotEmpty &&
        ctrl is RichFormattedEditingController) {
      ctrl.insertLink(label: linkLabel, url: linkUrl);
    } else if (rawToken != null && rawToken.isNotEmpty) {
      final cur = ctrl.text;
      final next = cur.replaceRange(start, start, rawToken);
      ctrl.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: start + rawToken.length),
      );
    }
    _clearTrigger();
    widget.onChanged?.call();
  }

  Future<void> _selectWikiCandidate(AppReferenceCandidate candidate) async {
    _replaceTriggerAndInsert(
      linkLabel: '${candidate.category.emoji} ${candidate.title}',
      linkUrl: candidate.buildUri(),
      rawToken: '${candidate.buildMarkdownLink()} ',
    );
  }

  Future<void> _executeSlashCommand(_SlashCommandItem item) async {
    final ctrl = widget.controller;
    final rich = ctrl is RichFormattedEditingController ? ctrl : null;

    // Primeiro remove `/comando`
    _replaceTriggerAndInsert(rawToken: '');

    switch (item.actionType) {
      case 'h1':
        if (rich != null) {
          rich.toggleBlockStyle(RichBlockStyle.h1);
        } else {
          _insertAtCursor('# ');
        }
        break;
      case 'h2':
        if (rich != null) {
          rich.toggleBlockStyle(RichBlockStyle.h2);
        } else {
          _insertAtCursor('## ');
        }
        break;
      case 'quote':
        if (rich != null) {
          rich.toggleBlockStyle(RichBlockStyle.quote);
        } else {
          _insertAtCursor('> ');
        }
        break;
      case 'checklist':
        if (rich != null) {
          rich.insertVisualLinePrefix('☐ ');
        } else {
          _insertAtCursor('- [ ] ');
        }
        break;
      case 'toggle':
        _insertAtCursor(
          ':::toggle Título do detalhe\nConteúdo oculto aqui...\n:::\n',
        );
        break;
      case 'callout_note':
        _insertAtCursor(
          '> [!NOTE] Anotação destacada\n> Escreva sua observação aqui.\n',
        );
        break;
      case 'callout_tip':
        _insertAtCursor(
          '> [!TIP] Aplicação prática\n> Ponto útil para o ministério.\n',
        );
        break;
      case 'callout_warning':
        _insertAtCursor(
          '> [!WARNING] Atenção\n> Detalhe importante para lembrar.\n',
        );
        break;
      case 'table':
        _insertAtCursor(
          '| Ponto | Referência | Aplicação |\n'
          '| --- | --- | --- |\n'
          '| Item 1 | texto | observação |\n',
        );
        break;
      case 'bible':
        final db = _tryReadDb();
        if (db != null && mounted) {
          await RichMarkdownToolbar.pickAndInsertReference(
            context,
            db: db,
            controller: ctrl,
            initialCategory: AppRefCategory.bible,
            onChanged: widget.onChanged,
          );
        }
        break;
      case 'ref_picker':
        final db = _tryReadDb();
        if (db != null && mounted) {
          await RichMarkdownToolbar.pickAndInsertReference(
            context,
            db: db,
            controller: ctrl,
            initialCategory: widget.initialReferenceCategory,
            onChanged: widget.onChanged,
          );
        }
        break;
    }
    widget.onChanged?.call();
  }

  void _insertAtCursor(String snippet) {
    final ctrl = widget.controller;
    final text = ctrl.text;
    final sel = ctrl.selection;
    final pos = (sel.isValid ? sel.baseOffset : text.length).clamp(
      0,
      text.length,
    );
    final next = text.replaceRange(pos, pos, snippet);
    ctrl.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: pos + snippet.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 40;
    final effectiveMinLines = keyboardOpen && widget.minLines > 4
        ? 4
        : widget.minLines;
    final filteredSlash = _activeTriggerType == 'slash'
        ? _slashCommands
              .where(
                (c) =>
                    _triggerQuery.isEmpty ||
                    c.command.contains(_triggerQuery) ||
                    c.label.toLowerCase().contains(_triggerQuery),
              )
              .toList()
        : const <_SlashCommandItem>[];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RichMarkdownToolbar(
          controller: widget.controller,
          enableHighlightPalette: widget.enableHighlightPalette,
          enableCrossReferences: widget.enableCrossReferences,
          enableImagePicker: widget.enableImagePicker,
          initialReferenceCategory: widget.initialReferenceCategory,
          onChanged: widget.onChanged,
        ),
        SizedBox(height: keyboardOpen ? 4 : 6),
        TextField(
          controller: widget.controller,
          minLines: effectiveMinLines,
          maxLines: widget.maxLines,
          scrollPadding: const EdgeInsets.only(bottom: 148),
          onChanged: (_) => widget.onChanged?.call(),
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
            isDense: keyboardOpen,
          ),
        ),
        if (_activeTriggerType == 'wikilink')
          _buildWikiPopup(isDark)
        else if (_activeTriggerType == 'slash' && filteredSlash.isNotEmpty)
          _buildSlashPopup(filteredSlash, isDark),
      ],
    );
  }

  Widget _buildWikiPopup(bool isDark) {
    final q = _triggerQuery.trim();
    final surface = isDark ? const Color(0xFF151E32) : Colors.white;
    final borderColor = AppTheme.primaryColor(context).withValues(alpha: 0.45);
    return Container(
      key: const Key('second_brain_wikilink_popup'),
      margin: const EdgeInsets.only(top: 6),
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  Icon(
                    Icons.link_rounded,
                    size: 15,
                    color: AppTheme.primaryColor(context),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      q.isEmpty
                          ? 'Vincular referência interna ([[...)'
                          : 'Referências para "$q"',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 15),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _clearTrigger,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (_loadingWikiCandidates)
              const Padding(
                padding: EdgeInsets.all(14),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    for (final cand in _wikiCandidates)
                      ListTile(
                        dense: true,
                        leading: Text(
                          cand.category.emoji,
                          style: const TextStyle(fontSize: 16),
                        ),
                        title: Text(
                          cand.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          cand.subtitle.isNotEmpty
                              ? '${cand.category.shortLabel} • ${cand.subtitle}'
                              : cand.category.shortLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                        onTap: () => _selectWikiCandidate(cand),
                      ),
                    if (q.length >= 2 && widget.onCreateInlineNote != null)
                      ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.add_circle_outline,
                          size: 18,
                          color: Color(0xFF8B5CF6),
                        ),
                        title: Text(
                          'Criar nova nota "$q" e vincular',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8B5CF6),
                          ),
                        ),
                        onTap: () async {
                          final created = await widget.onCreateInlineNote!(q);
                          if (created != null && mounted) {
                            _wikiCatalogLoadedOnce = false;
                            await _selectWikiCandidate(created);
                          }
                        },
                      ),
                    ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.menu_book_rounded,
                        size: 18,
                        color: AppTheme.primaryBlue,
                      ),
                      title: const Text(
                        'Escolher versículo da Bíblia (TNM / Ticuna)...',
                        style: TextStyle(fontSize: 12.5),
                      ),
                      onTap: () async {
                        final db = _tryReadDb();
                        if (db == null) return;
                        _replaceTriggerAndInsert(rawToken: '');
                        await RichMarkdownToolbar.pickAndInsertReference(
                          context,
                          db: db,
                          controller: widget.controller,
                          initialCategory: AppRefCategory.bible,
                          onChanged: widget.onChanged,
                        );
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlashPopup(List<_SlashCommandItem> items, bool isDark) {
    final surface = isDark ? const Color(0xFF151E32) : Colors.white;
    final borderColor = AppTheme.primaryColor(context).withValues(alpha: 0.45);
    return Container(
      key: const Key('second_brain_slash_popup'),
      margin: const EdgeInsets.only(top: 6),
      constraints: const BoxConstraints(maxHeight: 230),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    size: 15,
                    color: AppTheme.primaryColor(context),
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Comandos rápidos (/)',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 15),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _clearTrigger,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: items.length,
                itemBuilder: (ctx, idx) {
                  final cmd = items[idx];
                  return ListTile(
                    key: Key('slash_cmd_${cmd.command}'),
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: cmd.color.withValues(alpha: 0.14),
                      child: Icon(cmd.icon, size: 15, color: cmd.color),
                    ),
                    title: Text(
                      cmd.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '/${cmd.command} • ${cmd.description}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    onTap: () => _executeSlashCommand(cmd),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
