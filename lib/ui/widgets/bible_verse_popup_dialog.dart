import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../bible/nwt_bible_books.dart';
import '../../bible/nwt_bible_service.dart';
import '../../database/app_database.dart';
import 'highlight_text_helper.dart';
import 'jw_highlight_floating_toolbar.dart';

typedef _BibleSlice = ({
  int number,
  String rawMarkup,
  MappedRichTextResult mapped,
  int docStart,
  int docEnd,
});

/// Abre o popup interativo de leitura de passagem bíblica (com suporte a 1 ou mais traduções).
Future<void> showBibleVersePopup(
  BuildContext context, {
  required AppDatabase db,
  required int bookNumber,
  required int chapter,
  String? verseSpec,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => BibleVersePopupDialog(
      db: db,
      bookNumber: bookNumber,
      chapter: chapter,
      verseSpec: verseSpec,
    ),
  );
}

/// Diálogo offline-first para leitura e comparação de textos bíblicos importados em Configurações
/// (ou salvos manualmente pelo usuário), sem botões de importação direta no popup.
class BibleVersePopupDialog extends StatefulWidget {
  final AppDatabase db;
  final int bookNumber;
  final int chapter;
  final String? verseSpec;

  const BibleVersePopupDialog({
    super.key,
    required this.db,
    required this.bookNumber,
    required this.chapter,
    this.verseSpec,
  });

  @override
  State<BibleVersePopupDialog> createState() => _BibleVersePopupDialogState();
}

class _BibleVersePopupDialogState extends State<BibleVersePopupDialog> {
  List<BibleNwtCatalog> _translations = const [];
  List<String> _selectedIds = const [];
  List<BibleTranslationPassage> _passages = const [];
  bool _loading = true;
  double _fontSize = 16;
  final JwHighlightFloatingController _hlFloating =
      JwHighlightFloatingController();
  final Map<String, GlobalKey> _anchorKeys = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _hlFloating.dispose();
    super.dispose();
  }

  GlobalKey _anchorKeyFor(String translationId) =>
      _anchorKeys.putIfAbsent(translationId, () => GlobalKey());

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final translations = await NwtBibleService.listTranslations(widget.db);
    var selectedIds = await NwtBibleService.loadSelectedComparisonIds(
      widget.db,
    );
    final validIds = {for (final t in translations) t.id};
    selectedIds = selectedIds.where(validIds.contains).toList();
    if (selectedIds.isEmpty && translations.isNotEmpty) {
      final primary =
          translations.where((t) => t.isPrimary).firstOrNull ??
          translations.first;
      selectedIds = [primary.id];
    }

    final passages = await NwtBibleService.lookupComparisonPassages(
      widget.db,
      translationIds: selectedIds,
      bookNumber: widget.bookNumber,
      chapter: widget.chapter,
      verseSpec: widget.verseSpec,
    );

    if (!mounted) return;
    setState(() {
      _translations = translations;
      _selectedIds = selectedIds;
      _passages = passages;
      _loading = false;
    });
  }

  Future<void> _applyTranslationSelection(List<String> nextIds) async {
    _hlFloating.hide();
    await NwtBibleService.saveSelectedComparisonIds(widget.db, nextIds);
    await _loadData();
  }

  Future<void> _showManualVerseModal() async {
    final parsed = NwtBibleService.parseVerseNumbers(widget.verseSpec);
    final defaultVerse = parsed.isNotEmpty ? parsed.first : 1;
    final verseNumCtrl = TextEditingController(text: '$defaultVerse');
    final textCtrl = TextEditingController();

    final firstWithVerses = _passages
        .where((p) => p.lookup.hasFoundVerses)
        .firstOrNull;
    final existingMatch = firstWithVerses?.lookup.verses
        .where((v) => v.number == defaultVerse)
        .firstOrNull;
    if (existingMatch != null) {
      textCtrl.text = existingMatch.text;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Salvar versículo offline'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: verseNumCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText:
                      'Versículo (${NwtBibleBooks.byNumber(widget.bookNumber)?.namePt ?? 'Livro'} ${widget.chapter})',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textCtrl,
                maxLines: 5,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Texto do versículo (Offline)',
                  hintText:
                      'Cole ou digite o texto bíblico para uso offline...',
                  border: OutlineInputBorder(),
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
          FilledButton(
            onPressed: () async {
              final vNum = int.tryParse(verseNumCtrl.text.trim()) ?? 1;
              if (textCtrl.text.trim().isEmpty) return;
              await NwtBibleService.saveManualVerse(
                widget.db,
                bookNumber: widget.bookNumber,
                chapter: widget.chapter,
                verse: vNum,
                text: textCtrl.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              await _loadData();
            },
            child: const Text('Salvar Offline'),
          ),
        ],
      ),
    );
    verseNumCtrl.dispose();
    textCtrl.dispose();
  }

  Future<void> _showCompareVersionsModal() async {
    if (_translations.isEmpty) return;
    final selectedSet = _selectedIds.toSet();
    final result = await showDialog<List<String>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return AlertDialog(
              title: const Text('Comparar versões'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Selecione 1 tradução para leitura simples ou marque várias para comparar lado a lado no estilo JW Library.',
                        style: TextStyle(fontSize: 12.5, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      for (final tr in _translations)
                        CheckboxListTile(
                          key: Key('chk_compare_bible_${tr.id}'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: selectedSet.contains(tr.id),
                          title: Text(
                            tr.title,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${tr.languageDisplay}${tr.isPrimary ? ' • Principal' : ''}',
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          secondary: _buildCoverWidget(
                            tr.coverBase64,
                            size: 36,
                          ),
                          onChanged: (checked) {
                            setModalState(() {
                              if (checked == true) {
                                selectedSet.add(tr.id);
                              } else if (selectedSet.length > 1) {
                                selectedSet.remove(tr.id);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (_translations.length > 1)
                  TextButton(
                    onPressed: () {
                      setModalState(() {
                        selectedSet
                          ..clear()
                          ..addAll(_translations.map((t) => t.id));
                      });
                    },
                    child: const Text('Marcar todas'),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  key: const Key('btn_apply_compare_versions'),
                  onPressed: selectedSet.isEmpty
                      ? null
                      : () {
                          final ordered = _translations
                              .map((t) => t.id)
                              .where(selectedSet.contains)
                              .toList();
                          Navigator.pop(ctx, ordered);
                        },
                  child: const Text('Aplicar'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result != null && result.isNotEmpty) {
      await _applyTranslationSelection(result);
    }
  }

  Widget _buildCoverWidget(String? coverBase64, {double size = 40}) {
    if (coverBase64 != null && coverBase64.isNotEmpty) {
      try {
        final raw = coverBase64.contains(',')
            ? coverBase64.split(',').last
            : coverBase64;
        final bytes = base64Decode(raw);
        if (bytes.isNotEmpty) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _defaultBibleThumb(size),
            ),
          );
        }
      } catch (_) {}
    }
    return _defaultBibleThumb(size);
  }

  Widget _defaultBibleThumb(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF334155),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        Icons.menu_book_rounded,
        color: Colors.white70,
        size: size * 0.56,
      ),
    );
  }

  List<_BibleSlice> _buildVerseSlices(
    List<BibleVerseEntry> verses,
    bool isDark,
  ) {
    final slices = <_BibleSlice>[];
    var cursor = 0;
    final verseStyle = TextStyle(
      fontSize: _fontSize,
      height: 1.6,
      color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
    );
    for (final v in verses) {
      final prefix = '${v.number} ';
      cursor += prefix.length;
      final rawMarkup = v.displayMarkup;
      final mapped = HighlightTextHelper.buildMappedSpans(
        rawMarkup,
        verseStyle,
        stripBlockPrefixes: false,
        isDark: isDark,
      );
      final docStart = cursor;
      final docEnd = docStart + mapped.plainDisplayText.length;
      slices.add((
        number: v.number,
        rawMarkup: rawMarkup,
        mapped: mapped,
        docStart: docStart,
        docEnd: docEnd,
      ));
      cursor = docEnd + 1;
    }
    return slices;
  }

  Future<void> _applyHighlightToSelection(
    String translationId,
    List<_BibleSlice> slices,
    int selStart,
    int selEnd,
    String? colorHex,
  ) async {
    if (selEnd <= selStart) return;
    var changed = false;
    for (final slice in slices) {
      final overlapStart = selStart > slice.docStart
          ? selStart
          : slice.docStart;
      final overlapEnd = selEnd < slice.docEnd ? selEnd : slice.docEnd;
      if (overlapEnd <= overlapStart) continue;

      final localStart = overlapStart - slice.docStart;
      final localEnd = overlapEnd - slice.docStart;
      final updatedMarkup = HighlightTextHelper.applyUnderlineWithMap(
        rawText: slice.rawMarkup,
        map: slice.mapped,
        selectionStart: localStart,
        selectionEnd: localEnd,
        colorHex: colorHex,
      );
      if (updatedMarkup != slice.rawMarkup) {
        await NwtBibleService.saveVerseHighlightMarkup(
          widget.db,
          bookNumber: widget.bookNumber,
          chapter: widget.chapter,
          verse: slice.number,
          markedText: updatedMarkup,
          translationId: translationId,
        );
        changed = true;
      }
    }
    if (changed) {
      _hlFloating.hide();
      await _loadData();
    }
  }

  Future<void> _openOnJwOrg() async {
    final requested = NwtBibleService.parseVerseNumbers(widget.verseSpec);
    final url = NwtBibleBooks.buildJwOrgFinderUrl(
      bookNumber: widget.bookNumber,
      chapter: widget.chapter,
      firstVerse: requested.isNotEmpty ? requested.first : 1,
    );
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildSelectableVerses({
    required BuildContext context,
    required BibleTranslationPassage passage,
    required bool isDark,
    required String keyPrefix,
  }) {
    final slices = _buildVerseSlices(passage.lookup.verses, isDark);
    return Listener(
      key: _anchorKeyFor(passage.translationId),
      onPointerDown: (e) => _hlFloating.recordPointerDown(e.position),
      onPointerUp: (e) => _hlFloating.recordPointerUp(e.position),
      child: SelectableText.rich(
        TextSpan(
          children: [
            for (final slice in slices) ...[
              TextSpan(
                text: '${slice.number} ',
                style: TextStyle(
                  fontSize: _fontSize * 0.8,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF4338CA),
                ),
              ),
              ...slice.mapped.spans,
              const TextSpan(text: ' '),
            ],
          ],
        ),
        onSelectionChanged: (sel, _) {
          if (!mounted) return;
          if (sel.isValid && !sel.isCollapsed && sel.end > sel.start) {
            _hlFloating.show(
              context: context,
              keyPrefix: keyPrefix,
              anchorKey: _anchorKeyFor(passage.translationId),
              onPickColor: (hex) => _applyHighlightToSelection(
                passage.translationId,
                slices,
                sel.start,
                sel.end,
                hex,
              ),
            );
          } else {
            _hlFloating.hide();
          }
        },
        contextMenuBuilder: (menuCtx, editableState) {
          final sel = editableState.textEditingValue.selection;
          final canHl = sel.isValid && !sel.isCollapsed;
          final items = <ContextMenuButtonItem>[
            ...editableState.contextMenuButtonItems,
            if (canHl) ...[
              for (final c in HighlightTextHelper.colors)
                ContextMenuButtonItem(
                  label: 'Marcar (${c.label})',
                  onPressed: () {
                    ContextMenuController.removeAny();
                    _hlFloating.hide();
                    _applyHighlightToSelection(
                      passage.translationId,
                      slices,
                      sel.start,
                      sel.end,
                      c.hex,
                    );
                  },
                ),
              ContextMenuButtonItem(
                label: 'Remover marcação',
                onPressed: () {
                  ContextMenuController.removeAny();
                  _hlFloating.hide();
                  _applyHighlightToSelection(
                    passage.translationId,
                    slices,
                    sel.start,
                    sel.end,
                    null,
                  );
                },
              ),
            ],
          ];
          return AdaptiveTextSelectionToolbar.buttonItems(
            anchors: editableState.contextMenuAnchors,
            buttonItems: items,
          );
        },
      ),
    );
  }

  Widget _buildComparisonCard(
    BuildContext context,
    BibleTranslationPassage passage,
    bool isDark,
  ) {
    final headerBg = isDark ? const Color(0xFF1F242D) : const Color(0xFFE2E8F0);
    final bodyBg = isDark ? const Color(0xFF121417) : const Color(0xFFF8FAFC);

    return Container(
      key: Key('bible_compare_card_${passage.translationId}'),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bodyBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: _translations.length > 1 ? _showCompareVersionsModal : null,
            child: Container(
              color: headerBg,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: [
                  _buildCoverWidget(passage.coverBase64, size: 38),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          passage.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          passage.languageDisplay,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_translations.length > 1)
                    const Icon(Icons.chevron_right, size: 20),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: passage.lookup.hasFoundVerses
                ? _buildSelectableVerses(
                    context: context,
                    passage: passage,
                    isDark: isDark,
                    keyPrefix: 'bible_${passage.translationId}',
                  )
                : Text(
                    'Passagem não localizada nesta tradução.',
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final refTitle = NwtBibleBooks.formatReferenceLabel(
      bookNumber: widget.bookNumber,
      chapter: widget.chapter,
      verseSpec: widget.verseSpec,
    );
    final isComparing = _passages.length > 1;
    final singlePassage = _passages.length == 1 ? _passages.first : null;
    final anyFoundVerses = _passages.any((p) => p.lookup.hasFoundVerses);

    final subtitleText = isComparing
        ? 'Comparar versões • ${_passages.length} traduções'
        : singlePassage != null
        ? '${singlePassage.title} (${singlePassage.languageDisplay})'
        : 'Biblioteca Bíblica (Offline / Local)';

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 650),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFEEF2FF),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  if (singlePassage != null &&
                      singlePassage.coverBase64 != null)
                    _buildCoverWidget(singlePassage.coverBase64, size: 38)
                  else
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4338CA).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: Color(0xFF4338CA),
                        size: 22,
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          refTitle,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          subtitleText,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF475569),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (_translations.isNotEmpty)
                    IconButton(
                      key: const Key('btn_bible_compare_versions'),
                      tooltip: 'Comparar versões',
                      icon: const Icon(Icons.translate_rounded, size: 19),
                      onPressed: _showCompareVersionsModal,
                    ),
                  IconButton(
                    tooltip: 'Diminuir fonte',
                    icon: const Icon(Icons.text_decrease, size: 18),
                    onPressed: () => setState(
                      () => _fontSize = (_fontSize - 1.5).clamp(12, 26),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Aumentar fonte',
                    icon: const Icon(Icons.text_increase, size: 18),
                    onPressed: () => setState(
                      () => _fontSize = (_fontSize + 1.5).clamp(12, 26),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : anyFoundVerses
                  ? Builder(
                      builder: (ctx) {
                        return NotificationListener<ScrollNotification>(
                          onNotification: (_) {
                            _hlFloating.hide();
                            return false;
                          },
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: isComparing
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      for (final p in _passages)
                                        _buildComparisonCard(ctx, p, isDark),
                                    ],
                                  )
                                : Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: _buildSelectableVerses(
                                      context: ctx,
                                      passage: _passages.first,
                                      isDark: isDark,
                                      keyPrefix: 'bible',
                                    ),
                                  ),
                          ),
                        );
                      },
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(
                            Icons.import_contacts_outlined,
                            size: 44,
                            color: isDark ? Colors.white38 : Colors.black26,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _translations.isNotEmpty
                                ? 'Passagem "$refTitle" não localizada nas Bíblias importadas.'
                                : 'Nenhuma Bíblia local importada ainda.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Importe traduções em múltiplos idiomas (.epub ou .json) '
                            'em Configurações > Biblioteca Offline, ou cadastre este versículo manualmente abaixo.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 18),
                          OutlinedButton.icon(
                            onPressed: _showManualVerseModal,
                            icon: const Icon(Icons.edit_note),
                            label: const Text(
                              'Colar / Salvar Versículo Manual',
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (anyFoundVerses) ...[
                        TextButton.icon(
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copiar'),
                          onPressed: () {
                            final sections = _passages
                                .where((p) => p.lookup.hasFoundVerses)
                                .map((p) {
                                  final joined = p.lookup.verses
                                      .map((v) => '${v.number} ${v.text}')
                                      .join(' ');
                                  return _passages.length > 1
                                      ? '${p.title} (${p.languageDisplay})\n$joined'
                                      : joined;
                                })
                                .join('\n\n');
                            Clipboard.setData(
                              ClipboardData(text: '$refTitle\n$sections'),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Texto bíblico copiado!'),
                              ),
                            );
                          },
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Editar'),
                          onPressed: _showManualVerseModal,
                        ),
                      ],
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_translations.length > 1)
                        TextButton.icon(
                          key: const Key('btn_bible_footer_compare'),
                          icon: const Icon(
                            Icons.view_agenda_outlined,
                            size: 16,
                          ),
                          label: Text(
                            isComparing
                                ? 'Comparando (${_passages.length})'
                                : 'Comparar (${_translations.length})',
                          ),
                          onPressed: _showCompareVersionsModal,
                        ),
                      const SizedBox(width: 4),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('JW.org'),
                        onPressed: _openOnJwOrg,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
