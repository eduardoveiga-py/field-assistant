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
  final ReferenceInsertMode insertMode;
  final String? transcriptHeader;
  final List<String> transcriptLines;
  final String? transcriptMarkdown;

  const AppReferencePickResult({
    required this.category,
    required this.markdownToken,
    this.candidate,
    this.insertMode = ReferenceInsertMode.linkOnly,
    this.transcriptHeader,
    this.transcriptLines = const [],
    this.transcriptMarkdown,
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
  ReferenceInsertMode _bibleInsertMode = ReferenceInsertMode.linkOnly;

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
    final summary =
        await ImportedPublicationsService.repairNumericChapterTitlesIfNeeded(
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

    final result = await showDialog<AppReferencePickResult>(
      context: context,
      builder: (ctx) => _PublicationChapterParagraphDialog(
        db: widget.db,
        summary: summary,
        candidate: item,
      ),
    );
    if (result == null || !mounted) return;
    Navigator.of(context).pop(result);
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
      await _refreshBiblePreview();
    }

    final token = AppReferenceHelper.buildBibleMarkdownLink(
      bookNumber: _selectedBookNum,
      chapter: chapter,
      verseSpec: verseSpec.isEmpty ? null : verseSpec,
    );

    List<BibleVerseEntry> versesToTranscribe = const [];
    if (_biblePreview != null && _biblePreview!.hasFoundVerses) {
      versesToTranscribe = _biblePreview!.verses;
    } else if (_manualVerseCtrl.text.trim().isNotEmpty) {
      final nums = NwtBibleService.parseVerseNumbers(verseSpec);
      versesToTranscribe = [
        BibleVerseEntry(
          number: nums.isNotEmpty ? nums.first : 1,
          text: _manualVerseCtrl.text.trim(),
        ),
      ];
    }

    if (_bibleInsertMode == ReferenceInsertMode.transcriptOnly &&
        versesToTranscribe.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Importe uma Bíblia ou preencha o texto do versículo para transcrever.',
            ),
          ),
        );
      }
      return;
    }

    String? transcriptHeader;
    List<String> transcriptLines = const [];
    String? transcriptMd;
    if (_bibleInsertMode != ReferenceInsertMode.linkOnly &&
        versesToTranscribe.isNotEmpty) {
      final refLabel = NwtBibleBooks.formatReferenceLabel(
        bookNumber: _selectedBookNum,
        chapter: chapter,
        verseSpec: verseSpec.isEmpty ? null : verseSpec,
      );
      final selectedTranslation = _bibleTranslations
          .where((t) => t.id == _selectedBibleTranslationId)
          .firstOrNull;
      final trSuffix = selectedTranslation != null
          ? ' (${selectedTranslation.title})'
          : '';
      transcriptHeader = '📖 $refLabel$trSuffix';
      transcriptLines = versesToTranscribe
          .map((v) => '${v.number} ${v.text.trim()}')
          .toList();
      transcriptMd = AppReferenceHelper.formatBibleTranscript(
        bookNumber: _selectedBookNum,
        chapter: chapter,
        verseSpec: verseSpec.isEmpty ? null : verseSpec,
        translationTitle: selectedTranslation?.title,
        verses: versesToTranscribe,
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop(
      AppReferencePickResult(
        category: AppRefCategory.bible,
        markdownToken: token,
        insertMode: _bibleInsertMode,
        transcriptHeader: transcriptHeader,
        transcriptLines: transcriptLines,
        transcriptMarkdown: transcriptMd,
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
                      const SizedBox(height: 10),
                      _ReferenceInsertModeSelector(
                        mode: _bibleInsertMode,
                        onChanged: (m) => setState(() => _bibleInsertMode = m),
                      ),
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
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: OutlinedButton.icon(
                                      key: Key(
                                        'btn_pick_pub_chapter_${item.id}',
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.menu_book_outlined,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'Cap. / §',
                                        style: TextStyle(fontSize: 11.5),
                                      ),
                                      onPressed: () =>
                                          _pickPublicationChapter(item),
                                    ),
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

class _ReferenceInsertModeSelector extends StatelessWidget {
  final ReferenceInsertMode mode;
  final ValueChanged<ReferenceInsertMode> onChanged;

  const _ReferenceInsertModeSelector({
    required this.mode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Formato de inserção:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(
              key: const Key('insert_mode_link_only'),
              label: const Text(
                '🔗 Link (Popup)',
                style: TextStyle(fontSize: 12),
              ),
              selected: mode == ReferenceInsertMode.linkOnly,
              onSelected: (_) => onChanged(ReferenceInsertMode.linkOnly),
              visualDensity: VisualDensity.compact,
            ),
            ChoiceChip(
              key: const Key('insert_mode_link_and_transcript'),
              label: const Text(
                '📝 Link + Transcrito',
                style: TextStyle(fontSize: 12),
              ),
              selected: mode == ReferenceInsertMode.linkAndTranscript,
              onSelected: (_) =>
                  onChanged(ReferenceInsertMode.linkAndTranscript),
              visualDensity: VisualDensity.compact,
            ),
            ChoiceChip(
              key: const Key('insert_mode_transcript_only'),
              label: const Text(
                '🖨️ Só Transcrito',
                style: TextStyle(fontSize: 12),
              ),
              selected: mode == ReferenceInsertMode.transcriptOnly,
              onSelected: (_) => onChanged(ReferenceInsertMode.transcriptOnly),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ],
    );
  }
}

class _PublicationChapterParagraphDialog extends StatefulWidget {
  final AppDatabase db;
  final ImportedPublicationSummary summary;
  final AppReferenceCandidate candidate;

  const _PublicationChapterParagraphDialog({
    required this.db,
    required this.summary,
    required this.candidate,
  });

  @override
  State<_PublicationChapterParagraphDialog> createState() =>
      _PublicationChapterParagraphDialogState();
}

class _PublicationChapterParagraphDialogState
    extends State<_PublicationChapterParagraphDialog> {
  late int _selectedChapterIdx;
  ImportedPublicationChapterContent? _chapterContent;
  bool _loadingChapter = true;
  final TextEditingController _parSpecCtrl = TextEditingController();
  final Set<int> _selectedNumbers = <int>{};
  ReferenceInsertMode _insertMode = ReferenceInsertMode.linkOnly;

  @override
  void initState() {
    super.initState();
    _selectedChapterIdx = widget.summary.chapters.first.index;
    _loadChapter(_selectedChapterIdx);
  }

  @override
  void dispose() {
    _parSpecCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadChapter(int chapterIndex) async {
    setState(() {
      _selectedChapterIdx = chapterIndex;
      _loadingChapter = true;
      _selectedNumbers.clear();
      _parSpecCtrl.clear();
    });
    final ch = await ImportedPublicationsService.loadChapter(
      widget.db,
      publicationId: widget.summary.id,
      chapterIndex: chapterIndex,
    );
    if (!mounted) return;
    setState(() {
      _chapterContent = ch;
      _loadingChapter = false;
    });
  }

  static String _compressSpec(Set<int> nums) {
    if (nums.isEmpty) return '';
    final sorted = nums.toList()..sort();
    final parts = <String>[];
    var start = sorted.first;
    var prev = sorted.first;
    for (var i = 1; i < sorted.length; i++) {
      final cur = sorted[i];
      if (cur == prev + 1) {
        prev = cur;
      } else {
        parts.add(start == prev ? '$start' : '$start-$prev');
        start = cur;
        prev = cur;
      }
    }
    parts.add(start == prev ? '$start' : '$start-$prev');
    return parts.join(', ');
  }

  void _toggleParagraphSelection(int num) {
    setState(() {
      if (_selectedNumbers.contains(num)) {
        _selectedNumbers.remove(num);
      } else {
        _selectedNumbers.add(num);
      }
      _parSpecCtrl.text = _compressSpec(_selectedNumbers);
    });
  }

  void _syncSelectionFromText(String value) {
    final parsed = ImportedPublicationsService.parseParagraphNumbers(value);
    setState(() {
      _selectedNumbers
        ..clear()
        ..addAll(parsed);
    });
  }

  void _confirmSelection() {
    final chMeta = widget.summary.chapters
        .where((c) => c.index == _selectedChapterIdx)
        .firstOrNull;
    final chapterTitle = chMeta?.title ?? _chapterContent?.title;
    final parSpec = _parSpecCtrl.text.trim();

    final token = AppReferenceHelper.buildPublicationMarkdownLink(
      publicationId: widget.summary.id,
      title: widget.summary.title,
      chapterIndex: _selectedChapterIdx,
      chapterTitle: chapterTitle,
      paragraphSpec: parSpec.isEmpty ? null : parSpec,
    );

    String? transcriptHeader;
    List<String> transcriptLines = const [];
    String? transcriptMd;
    if (_insertMode != ReferenceInsertMode.linkOnly &&
        _chapterContent != null) {
      final selected = ImportedPublicationsService.selectParagraphs(
        _chapterContent!,
        paragraphSpec: parSpec.isEmpty ? null : parSpec,
      );
      final specSuffix = parSpec.isNotEmpty ? ' (§/$parSpec)' : '';
      transcriptHeader =
          '📚 ${widget.summary.title} — ${chapterTitle ?? _chapterContent!.title}$specSuffix';
      String? lastHeading;
      final outLines = <String>[];
      for (final p in selected) {
        if (p.heading != null &&
            p.heading!.isNotEmpty &&
            p.heading != lastHeading &&
            p.heading != p.text) {
          outLines.add(p.heading!);
          lastHeading = p.heading;
        }
        outLines.add(p.text);
      }
      transcriptLines = outLines;
      transcriptMd = ImportedPublicationsService.formatChapterTranscript(
        publication: widget.summary,
        chapter: _chapterContent!,
        paragraphSpec: parSpec.isEmpty ? null : parSpec,
      );
    }

    Navigator.of(context).pop(
      AppReferencePickResult(
        category: AppRefCategory.publication,
        markdownToken: token,
        candidate: widget.candidate,
        insertMode: _insertMode,
        transcriptHeader: transcriptHeader,
        transcriptLines: transcriptLines,
        transcriptMarkdown: transcriptMd,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = _chapterContent?.resolvedParagraphs ?? const [];
    final specClean = _parSpecCtrl.text.trim();
    final previewItems = _chapterContent == null
        ? const <ImportedPublicationParagraph>[]
        : ImportedPublicationsService.selectParagraphs(
            _chapterContent!,
            paragraphSpec: specClean.isEmpty ? null : specClean,
          );

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
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
                    Icons.menu_book_rounded,
                    color: AppTheme.primaryBlue,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.summary.title,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<int>(
                      key: const Key('dropdown_pub_chapter'),
                      initialValue: _selectedChapterIdx,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Capítulo / Lição / Estudo',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: widget.summary.chapters
                          .map(
                            (ch) => DropdownMenuItem<int>(
                              value: ch.index,
                              child: Text(
                                ch.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (idx) {
                        if (idx != null) _loadChapter(idx);
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('field_pub_paragraphs'),
                            controller: _parSpecCtrl,
                            onChanged: _syncSelectionFromText,
                            decoration: InputDecoration(
                              labelText: 'Parágrafo(s) / Pontos (opcional)',
                              hintText: 'Ex: 1, 3-5 (vazio = cap. inteiro)',
                              border: const OutlineInputBorder(),
                              isDense: true,
                              suffixIcon: _parSpecCtrl.text.isNotEmpty
                                  ? IconButton(
                                      tooltip: 'Limpar seleção (Cap. inteiro)',
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _parSpecCtrl.clear();
                                        _syncSelectionFromText('');
                                      },
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Toque abaixo para selecionar pontos ou parágrafos:',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: _loadingChapter
                          ? const Center(child: CircularProgressIndicator())
                          : items.isEmpty
                          ? const Center(
                              child: Text(
                                'Sem parágrafos indexados neste capítulo.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.separated(
                              itemCount: items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 4),
                              itemBuilder: (ctx, i) {
                                final p = items[i];
                                if (p.isHeadingOnly) {
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      top: 6,
                                      bottom: 2,
                                    ),
                                    child: Text(
                                      p.text,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor(context),
                                      ),
                                    ),
                                  );
                                }
                                final selectableNum =
                                    p.number ??
                                    (items
                                        .take(i + 1)
                                        .where((x) => !x.isHeadingOnly)
                                        .length);
                                final isSelected = _selectedNumbers.contains(
                                  selectableNum,
                                );
                                final tagLabel = p.number != null
                                    ? '¶ ${p.number}'
                                    : 'Bloco $selectableNum';
                                return InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () =>
                                      _toggleParagraphSelection(selectableNum),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppTheme.accentTeal.withValues(
                                              alpha: isDark ? 0.22 : 0.12,
                                            )
                                          : (isDark
                                                ? const Color(0xFF1E293B)
                                                : const Color(0xFFF8FAFC)),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppTheme.accentTeal
                                            : (isDark
                                                  ? const Color(0xFF334155)
                                                  : const Color(0xFFE2E8F0)),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? AppTheme.accentTeal
                                                : AppTheme.primaryBlue
                                                      .withValues(alpha: 0.14),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            tagLabel,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected
                                                  ? Colors.white
                                                  : AppTheme.primaryColor(
                                                      context,
                                                    ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (p.heading != null &&
                                                  p.heading!.isNotEmpty &&
                                                  p.heading != p.text)
                                                Text(
                                                  p.heading!,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              Text(
                                                p.text,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    if (previewItems.isNotEmpty &&
                        _insertMode != ReferenceInsertMode.linkOnly) ...[
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 82),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            previewItems.map((e) => e.text).join('\n'),
                            style: const TextStyle(fontSize: 11.5),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    _ReferenceInsertModeSelector(
                      mode: _insertMode,
                      onChanged: (m) => setState(() => _insertMode = m),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
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
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(
                            AppReferencePickResult(
                              category: widget.candidate.category,
                              markdownToken: widget.candidate
                                  .buildMarkdownLink(),
                              candidate: widget.candidate,
                            ),
                          );
                        },
                        child: const Text('Livro inteiro'),
                      ),
                    ],
                  ),
                  FilledButton.icon(
                    key: const Key('btn_insert_pub_ref'),
                    onPressed: _confirmSelection,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      specClean.isEmpty
                          ? 'Inserir capítulo'
                          : 'Inserir § $specClean',
                    ),
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
