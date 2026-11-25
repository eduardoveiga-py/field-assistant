import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../bible/nwt_bible_books.dart';
import '../../bible/nwt_bible_service.dart';
import '../../core/app_theme.dart';
import '../../database/app_database.dart';
import 'highlight_text_helper.dart';

/// Abre o popup interativo de leitura de passagem bíblica (Tradução do Novo Mundo).
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

/// Diálogo offline-first para leitura de textos bíblicos TNM importados localmente
/// (via `.epub` do jw.org ou `.json`) ou cadastrados manualmente pelo usuário.
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
  BiblePassageLookupResult? _lookup;
  BibleNwtCatalog? _catalog;
  bool _loading = true;
  bool _importing = false;
  double _fontSize = 16;
  String? _statusMessage;
  TextSelection? _activeSelection;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final catalog = await NwtBibleService.loadCatalog(widget.db);
    final res = await NwtBibleService.lookupPassage(
      widget.db,
      bookNumber: widget.bookNumber,
      chapter: widget.chapter,
      verseSpec: widget.verseSpec,
    );
    if (!mounted) return;
    setState(() {
      _catalog = catalog;
      _lookup = res;
      _loading = false;
    });
  }

  Future<void> _importLocalFile() async {
    setState(() {
      _importing = true;
      _statusMessage = null;
    });
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['epub', 'json', 'jwpub'],
      );
      if (files.isEmpty) {
        if (mounted) setState(() => _importing = false);
        return;
      }
      final file = files.first;
      Uint8List bytes;
      try {
        bytes = await file.readAsBytes();
      } catch (e) {
        if (mounted) {
          setState(() {
            _importing = false;
            _statusMessage =
                'Não foi possível ler os bytes do arquivo "${file.name}": $e';
          });
        }
        return;
      }
      if (bytes.isEmpty) {
        if (mounted) {
          setState(() {
            _importing = false;
            _statusMessage = 'O arquivo "${file.name}" está vazio.';
          });
        }
        return;
      }
      final imported = await NwtBibleService.importFromBytes(
        widget.db,
        bytes: bytes,
        fileName: file.name,
      );
      await _loadData();
      if (mounted) {
        setState(() {
          _importing = false;
          _statusMessage =
              'TNM importada com sucesso: ${imported.catalog.bookCount} livro(s), ${imported.catalog.verseCount} versículos.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _importing = false;
          _statusMessage = e.toString();
        });
      }
    }
  }

  Future<void> _showManualVerseModal() async {
    final parsed = NwtBibleService.parseVerseNumbers(widget.verseSpec);
    final defaultVerse = parsed.isNotEmpty ? parsed.first : 1;
    final verseNumCtrl = TextEditingController(text: '$defaultVerse');
    final textCtrl = TextEditingController();

    final existingMatch = _lookup?.verses
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
                  labelText: 'Texto do versículo (TNM)',
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

  List<
    ({
      int number,
      String rawMarkup,
      MappedRichTextResult mapped,
      int docStart,
      int docEnd,
    })
  >
  _buildVerseSlices(bool isDark) {
    final verses = _lookup?.verses ?? const [];
    final slices =
        <
          ({
            int number,
            String rawMarkup,
            MappedRichTextResult mapped,
            int docStart,
            int docEnd,
          })
        >[];
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
      cursor = docEnd + 1; // +1 espaço separador entre versículos
    }
    return slices;
  }

  Future<void> _applyHighlightToSelection(
    List<
      ({
        int number,
        String rawMarkup,
        MappedRichTextResult mapped,
        int docStart,
        int docEnd,
      })
    >
    slices,
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
        );
        changed = true;
      }
    }
    if (changed) {
      final updatedLookup = await NwtBibleService.lookupPassage(
        widget.db,
        bookNumber: widget.bookNumber,
        chapter: widget.chapter,
        verseSpec: widget.verseSpec,
      );
      if (!mounted) return;
      setState(() {
        _lookup = updatedLookup;
        _activeSelection = null;
      });
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final refTitle = NwtBibleBooks.formatReferenceLabel(
      bookNumber: widget.bookNumber,
      chapter: widget.chapter,
      verseSpec: widget.verseSpec,
    );

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 620),
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
                          _catalog != null
                              ? '${_catalog!.title} • Offline'
                              : 'Tradução do Novo Mundo (Offline / Local)',
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
            if (_statusMessage != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                child: Text(
                  _statusMessage!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _lookup != null && _lookup!.hasFoundVerses
                  ? Builder(
                      builder: (ctx) {
                        final slices = _buildVerseSlices(isDark);
                        final hasSel =
                            _activeSelection != null &&
                            !_activeSelection!.isCollapsed &&
                            _activeSelection!.end > _activeSelection!.start;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF0F1A2E)
                                    : const Color(0xFFF8FAFC),
                                border: Border(
                                  bottom: BorderSide(
                                    color: isDark
                                        ? Colors.white10
                                        : Colors.black12,
                                  ),
                                ),
                              ),
                              child: Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.border_color_outlined,
                                        size: 14,
                                        color: hasSel
                                            ? const Color(0xFF4338CA)
                                            : Colors.grey,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        hasSel ? 'Sublinhar versículo:' : 'Selecione um trecho para sublinhar:',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: hasSel
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: isDark
                                              ? const Color(0xFFCBD5E1)
                                              : const Color(0xFF475569),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (final c
                                          in HighlightTextHelper.colors)
                                        Tooltip(
                                          message: 'Sublinhar (${c.label})',
                                          child: InkWell(
                                            key: Key('btn_bible_hl_${c.id}'),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            onTap: hasSel
                                                ? () =>
                                                      _applyHighlightToSelection(
                                                        slices,
                                                        _activeSelection!.start,
                                                        _activeSelection!.end,
                                                        c.hex,
                                                      )
                                                : null,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                    vertical: 3,
                                                  ),
                                              child: CircleAvatar(
                                                radius: 8,
                                                backgroundColor: c.color
                                                    .withValues(
                                                      alpha: hasSel ? 1.0 : 0.4,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      IconButton(
                                        key: const Key('btn_bible_hl_clear'),
                                        tooltip: 'Remover sublinhado',
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 26,
                                          minHeight: 26,
                                        ),
                                        icon: Icon(
                                          Icons.format_clear,
                                          size: 16,
                                          color: hasSel
                                              ? Colors.redAccent
                                              : Colors.grey,
                                        ),
                                        onPressed: hasSel
                                            ? () => _applyHighlightToSelection(
                                                slices,
                                                _activeSelection!.start,
                                                _activeSelection!.end,
                                                null,
                                              )
                                            : null,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(20),
                                child: SelectableText.rich(
                                  TextSpan(
                                    children: [
                                      for (final slice in slices) ...[
                                        TextSpan(
                                          text: '${slice.number} ',
                                          style: TextStyle(
                                            fontSize: _fontSize * 0.78,
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
                                    if (mounted) {
                                      setState(() => _activeSelection = sel);
                                    }
                                  },
                                  contextMenuBuilder: (menuCtx, editableState) {
                                    final sel = editableState
                                        .textEditingValue
                                        .selection;
                                    final canHl =
                                        sel.isValid && !sel.isCollapsed;
                                    final items = <ContextMenuButtonItem>[
                                      ...editableState.contextMenuButtonItems,
                                      if (canHl) ...[
                                        for (final c
                                            in HighlightTextHelper.colors)
                                          ContextMenuButtonItem(
                                            label: 'Sublinhar (${c.label})',
                                            onPressed: () {
                                              ContextMenuController.removeAny();
                                              _applyHighlightToSelection(
                                                slices,
                                                sel.start,
                                                sel.end,
                                                c.hex,
                                              );
                                            },
                                          ),
                                        ContextMenuButtonItem(
                                          label: 'Remover Sublinhado',
                                          onPressed: () {
                                            ContextMenuController.removeAny();
                                            _applyHighlightToSelection(
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
                              ),
                            ),
                          ],
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
                            _lookup?.hasImportedBible == true
                                ? 'Passagem "$refTitle" não localizada no arquivo TNM importado.'
                                : 'Nenhuma cópia local da Bíblia Tradução do Novo Mundo importada ainda.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Para ler 100% offline dentro deste popup sem ferir direitos autorais, '
                            'importe o arquivo .epub oficial baixado no jw.org (ou um .json próprio) '
                            'ou cadastre manualmente este versículo abaixo.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: _importing ? null : _importLocalFile,
                            icon: _importing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.upload_file),
                            label: Text(
                              _importing
                                  ? 'Importando Bíblia...'
                                  : 'Importar TNM (.epub / .json)',
                            ),
                          ),
                          const SizedBox(height: 10),
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
                      if (_lookup != null && _lookup!.hasFoundVerses) ...[
                        TextButton.icon(
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copiar'),
                          onPressed: () {
                            final joined = _lookup!.verses
                                .map((v) => '${v.number} ${v.text}')
                                .join(' ');
                            Clipboard.setData(
                              ClipboardData(text: '$refTitle (TNM)\n$joined'),
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
                      TextButton.icon(
                        icon: const Icon(Icons.upload_file_outlined, size: 16),
                        label: const Text('Importar TNM'),
                        onPressed: _importing ? null : _importLocalFile,
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
