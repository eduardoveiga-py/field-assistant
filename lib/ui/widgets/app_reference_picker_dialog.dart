import 'dart:convert';

import 'package:flutter/material.dart';

import '../../bible/nwt_bible_books.dart';
import '../../bible/nwt_bible_service.dart';
import '../../core/app_theme.dart';
import '../../database/app_database.dart';
import '../../publications/imported_publications_service.dart';
import '../../references/app_reference.dart';

/// Resultado devolvido pelo seletor de referências cruzadas.
class AppReferencePickResult {
  final AppRefCategory category;
  final String markdownToken;
  final AppReferenceCandidate? candidate;

  const AppReferencePickResult({
    required this.category,
    required this.markdownToken,
    this.candidate,
  });
}

/// Abre o menu suspenso/diálogo com categorias e itens de todo o aplicativo
/// (e textos bíblicos TNM) para inserir referências clicáveis em qualquer editor.
Future<AppReferencePickResult?> showAppReferencePickerDialog(
  BuildContext context, {
  required AppDatabase db,
  AppRefCategory initialCategory = AppRefCategory.question,
}) {
  return showDialog<AppReferencePickResult>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) =>
        AppReferencePickerDialog(db: db, initialCategory: initialCategory),
  );
}

/// Diálogo seletor de referências cruzadas com menu suspenso de categorias,
/// busca por título, miniatura de gravuras e seletor de versículos TNM.
class AppReferencePickerDialog extends StatefulWidget {
  final AppDatabase db;
  final AppRefCategory initialCategory;

  const AppReferencePickerDialog({
    super.key,
    required this.db,
    this.initialCategory = AppRefCategory.question,
  });

  @override
  State<AppReferencePickerDialog> createState() =>
      _AppReferencePickerDialogState();
}

class _AppReferencePickerDialogState extends State<AppReferencePickerDialog> {
  late AppRefCategory _selectedCategory;
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _chapterCtrl = TextEditingController(text: '3');
  final TextEditingController _versesCtrl = TextEditingController(text: '16');
  final TextEditingController _manualVerseCtrl = TextEditingController();

  List<AppReferenceCandidate> _candidates = const [];
  bool _loadingCandidates = false;
  int _selectedBookNum = 43; // João
  List<BibleNwtCatalog> _bibleTranslations = const [];
  String? _selectedBibleTranslationId;
  BiblePassageLookupResult? _biblePreview;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _loadCurrentCategoryData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _chapterCtrl.dispose();
    _versesCtrl.dispose();
    _manualVerseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentCategoryData() async {
    if (_selectedCategory == AppRefCategory.bible) {
      await _refreshBiblePreview();
      return;
    }
    setState(() => _loadingCandidates = true);
    final items = await AppReferenceHelper.loadCandidates(
      widget.db,
      _selectedCategory,
    );
    if (!mounted) return;
    setState(() {
      _candidates = items;
      _loadingCandidates = false;
    });
  }

  Future<void> _refreshBiblePreview() async {
    final translations = await NwtBibleService.listTranslations(widget.db);
    var selectedId = _selectedBibleTranslationId;
    if (selectedId == null || !translations.any((t) => t.id == selectedId)) {
      selectedId =
          translations.where((t) => t.isPrimary).firstOrNull?.id ??
          translations.firstOrNull?.id;
    }
    final bookInfo =
        NwtBibleBooks.byNumber(_selectedBookNum) ?? NwtBibleBooks.all.first;
    final chapter = (int.tryParse(_chapterCtrl.text.trim()) ?? 1).clamp(
      1,
      bookInfo.chapterCount,
    );
    final preview = await NwtBibleService.lookupPassage(
      widget.db,
      bookNumber: _selectedBookNum,
      chapter: chapter,
      verseSpec: _versesCtrl.text.trim(),
      translationId: selectedId,
    );
    if (!mounted) return;
    setState(() {
      _bibleTranslations = translations;
      _selectedBibleTranslationId = selectedId;
      _biblePreview = preview;
    });
  }

  Future<void> _pickPublicationChapter(AppReferenceCandidate item) async {
    final summary = await ImportedPublicationsService.getPublication(
      widget.db,
      item.id,
    );
    if (!mounted) return;
    if (summary == null || summary.chapters.isEmpty) {
      Navigator.of(context).pop(
        AppReferencePickResult(
          category: item.category,
          markdownToken: item.buildMarkdownLink(),
          candidate: item,
        ),
      );
      return;
    }
    final selectedChapter = await showDialog<ImportedPublicationChapterMeta>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          summary.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        content: SizedBox(
          width: 440,
          height: 360,
          child: ListView.separated(
            itemCount: summary.chapters.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, idx) {
              final ch = summary.chapters[idx];
              return ListTile(
                dense: true,
                title: Text(
                  ch.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.add_circle_outline, size: 18),
                onTap: () => Navigator.of(ctx).pop(ch),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop(null);
              Navigator.of(context).pop(
                AppReferencePickResult(
                  category: item.category,
                  markdownToken: item.buildMarkdownLink(),
                  candidate: item,
                ),
              );
            },
            child: const Text('Publicação inteira'),
          ),
        ],
      ),
    );
    if (selectedChapter == null || !mounted) return;
    final token = AppReferenceHelper.buildPublicationMarkdownLink(
      publicationId: summary.id,
      title: summary.title,
      chapterIndex: selectedChapter.index,
      chapterTitle: selectedChapter.title,
    );
    Navigator.of(context).pop(
      AppReferencePickResult(
        category: AppRefCategory.publication,
        markdownToken: token,
        candidate: item,
      ),
    );
  }

  Future<void> _insertBibleReference() async {
    final bookInfo =
        NwtBibleBooks.byNumber(_selectedBookNum) ?? NwtBibleBooks.all.first;
    final chapter = (int.tryParse(_chapterCtrl.text.trim()) ?? 1).clamp(
      1,
      bookInfo.chapterCount,
    );
    final verseSpec = _versesCtrl.text.trim();

    if (_manualVerseCtrl.text.trim().isNotEmpty) {
      final nums = NwtBibleService.parseVerseNumbers(verseSpec);
      final targetVerse = nums.isNotEmpty ? nums.first : 1;
      await NwtBibleService.saveManualVerse(
        widget.db,
        bookNumber: _selectedBookNum,
        chapter: chapter,
        verse: targetVerse,
        text: _manualVerseCtrl.text.trim(),
      );
    }

    final token = AppReferenceHelper.buildBibleMarkdownLink(
      bookNumber: _selectedBookNum,
      chapter: chapter,
      verseSpec: verseSpec.isEmpty ? null : verseSpec,
    );
    if (!mounted) return;
    Navigator.of(context).pop(
      AppReferencePickResult(
        category: AppRefCategory.bible,
        markdownToken: token,
      ),
    );
  }

  List<AppReferenceCandidate> get _filteredCandidates {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _candidates;
    return _candidates.where((c) {
      return c.title.toLowerCase().contains(q) ||
          c.subtitle.toLowerCase().contains(q);
    }).toList();
  }

  Widget? _buildThumbnail(String? imageData) {
    if (imageData == null || imageData.isEmpty) return null;
    if (imageData.startsWith('data:image')) {
      try {
        final idx = imageData.indexOf('base64,');
        if (idx >= 0) {
          final bytes = base64Decode(imageData.substring(idx + 7));
          return ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.memory(
              bytes,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
            ),
          );
        }
      } catch (_) {}
    }
    if (imageData.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          imageData,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(Icons.image, size: 22),
        ),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentBook =
        NwtBibleBooks.byNumber(_selectedBookNum) ?? NwtBibleBooks.all.first;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 8, 12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.add_link_rounded,
                    color: AppTheme.primaryBlue,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Inserir Referência / Link Interno',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: DropdownButtonFormField<AppRefCategory>(
                key: const Key('dropdown_ref_category'),
                initialValue: _selectedCategory,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Categoria / Aba',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: AppRefCategory.values.map((cat) {
                  return DropdownMenuItem<AppRefCategory>(
                    value: cat,
                    child: Text(
                      '${cat.emoji} ${cat.label}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (cat) {
                  if (cat == null) return;
                  setState(() {
                    _selectedCategory = cat;
                    _searchCtrl.clear();
                  });
                  _loadCurrentCategoryData();
                },
              ),
            ),
            if (_selectedCategory == AppRefCategory.bible) ...[
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<int>(
                        key: const Key('dropdown_bible_book'),
                        initialValue: _selectedBookNum,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Livro Bíblico (TNM)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: NwtBibleBooks.all.map((b) {
                          return DropdownMenuItem<int>(
                            value: b.number,
                            child: Text('${b.number}. ${b.namePt}'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() => _selectedBookNum = val);
                          _refreshBiblePreview();
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: const Key('field_bible_chapter'),
                              controller: _chapterCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText:
                                    'Capítulo (1-${currentBook.chapterCount})',
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (_) => _refreshBiblePreview(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              key: const Key('field_bible_verses'),
                              controller: _versesCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Versículo(s)',
                                hintText: 'Ex: 16 ou 16-17',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (_) => _refreshBiblePreview(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _bibleTranslations.isNotEmpty
                                      ? Icons.check_circle_outline
                                      : Icons.info_outline,
                                  size: 16,
                                  color: _bibleTranslations.isNotEmpty
                                      ? Colors.green
                                      : Colors.amber,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: _bibleTranslations.isEmpty
                                      ? const Text(
                                          'Nenhuma Bíblia importada ainda. Importe traduções em Configurações > Biblioteca Offline.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        )
                                      : _bibleTranslations.length == 1
                                      ? Text(
                                          '${_bibleTranslations.first.title} (${_bibleTranslations.first.languageDisplay}) • ${_bibleTranslations.first.bookCount} livros',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            key: const Key(
                                              'dropdown_picker_bible_translation',
                                            ),
                                            isDense: true,
                                            isExpanded: true,
                                            value: _selectedBibleTranslationId,
                                            items: _bibleTranslations.map((t) {
                                              return DropdownMenuItem<String>(
                                                value: t.id,
                                                child: Text(
                                                  '${t.title} (${t.languageDisplay})',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (val) {
                                              if (val == null) return;
                                              setState(() {
                                                _selectedBibleTranslationId =
                                                    val;
                                              });
                                              _refreshBiblePreview();
                                            },
                                          ),
                                        ),
                                ),
                              ],
                            ),
                            if (_biblePreview != null &&
                                _biblePreview!.hasFoundVerses) ...[
                              const SizedBox(height: 6),
                              Text(
                                _biblePreview!.verses
                                    .map((v) => '${v.number} ${v.text}')
                                    .join(' '),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12.5),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (_biblePreview == null ||
                          !_biblePreview!.hasFoundVerses) ...[
                        const SizedBox(height: 10),
                        TextField(
                          key: const Key('field_bible_manual_text'),
                          controller: _manualVerseCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText:
                                'Texto do versículo (opcional, salva offline)',
                            hintText: 'Cole o versículo aqui se desejar tê-lo offline no popup mesmo sem arquivo EPUB.',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        key: const Key('btn_insert_bible_ref'),
                        onPressed: _insertBibleReference,
                        icon: const Icon(Icons.menu_book_rounded, size: 18),
                        label: Text(
                          'Inserir ${NwtBibleBooks.formatReferenceLabel(bookNumber: _selectedBookNum, chapter: int.tryParse(_chapterCtrl.text.trim()) ?? 1, verseSpec: _versesCtrl.text.trim())}',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  key: const Key('field_ref_search'),
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Filtrar pelo título do item...',
                    prefixIcon: Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loadingCandidates
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredCandidates.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _selectedCategory == AppRefCategory.publication
                                ? 'Nenhuma publicação EPUB importada ainda.\nImporte publicações em Configurações > Biblioteca Offline.'
                                : 'Nenhum item disponível em "${_selectedCategory.label}".',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: _filteredCandidates.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (ctx, i) {
                          final item = _filteredCandidates[i];
                          final thumb = _buildThumbnail(item.previewImageData);
                          return ListTile(
                            dense: true,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            leading:
                                thumb ??
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppTheme.primaryBlue
                                      .withValues(alpha: 0.12),
                                  child: Text(item.category.emoji),
                                ),
                            title: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                            subtitle: item.subtitle.isNotEmpty
                                ? Text(
                                    item.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11.5),
                                  )
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (item.category == AppRefCategory.publication)
                                  IconButton(
                                    tooltip: 'Escolher capítulo/artigo',
                                    icon: const Icon(
                                      Icons.menu_book_outlined,
                                      size: 18,
                                    ),
                                    onPressed: () =>
                                        _pickPublicationChapter(item),
                                  ),
                                const Icon(
                                  Icons.add_circle_outline,
                                  size: 18,
                                  color: AppTheme.primaryBlue,
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.of(context).pop(
                                AppReferencePickResult(
                                  category: item.category,
                                  markdownToken: item.buildMarkdownLink(),
                                  candidate: item,
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
