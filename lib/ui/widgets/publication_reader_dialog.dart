import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../bible/nwt_bible_books.dart';
import '../../core/app_theme.dart';
import '../../database/app_database.dart';
import '../../publications/imported_publications_service.dart';

/// Abre o leitor offline de uma publicação EPUB importada na Biblioteca.
Future<void> showPublicationReaderDialog(
  BuildContext context, {
  required AppDatabase db,
  required String publicationId,
  int? initialChapterIndex,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => PublicationReaderDialog(
      db: db,
      publicationId: publicationId,
      initialChapterIndex: initialChapterIndex,
    ),
  );
}

class PublicationReaderDialog extends StatefulWidget {
  final AppDatabase db;
  final String publicationId;
  final int? initialChapterIndex;

  const PublicationReaderDialog({
    super.key,
    required this.db,
    required this.publicationId,
    this.initialChapterIndex,
  });

  @override
  State<PublicationReaderDialog> createState() =>
      _PublicationReaderDialogState();
}

class _PublicationReaderDialogState extends State<PublicationReaderDialog> {
  ImportedPublicationSummary? _summary;
  ImportedPublicationChapterContent? _chapter;
  int _chapterIndex = 0;
  bool _loading = true;
  double _fontSize = 15.5;

  @override
  void initState() {
    super.initState();
    _chapterIndex = widget.initialChapterIndex ?? 0;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final summary = await ImportedPublicationsService.getPublication(
      widget.db,
      widget.publicationId,
    );
    ImportedPublicationChapterContent? chapter;
    if (summary != null && summary.chapters.isNotEmpty) {
      final safeIdx = _chapterIndex.clamp(0, summary.chapters.length - 1);
      _chapterIndex = safeIdx;
      chapter = await ImportedPublicationsService.loadChapter(
        widget.db,
        publicationId: widget.publicationId,
        chapterIndex: summary.chapters[safeIdx].index,
      );
    }
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _chapter = chapter;
      _loading = false;
    });
  }

  Future<void> _selectChapter(int index) async {
    setState(() {
      _chapterIndex = index;
      _loading = true;
    });
    final chapter = await ImportedPublicationsService.loadChapter(
      widget.db,
      publicationId: widget.publicationId,
      chapterIndex: index,
    );
    if (!mounted) return;
    setState(() {
      _chapter = chapter;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 660),
        child: Column(
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
                  const Icon(
                    Icons.auto_stories_rounded,
                    color: AppTheme.primaryBlue,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _summary?.title ?? 'Publicação',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_summary != null)
                          Text(
                            '${NwtBibleBooks.languageDisplayName(_summary!.language)} • Offline',
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
                  IconButton(
                    tooltip: 'Diminuir fonte',
                    icon: const Icon(Icons.text_decrease, size: 18),
                    onPressed: () => setState(
                      () => _fontSize = (_fontSize - 1.5).clamp(12, 24),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Aumentar fonte',
                    icon: const Icon(Icons.text_increase, size: 18),
                    onPressed: () => setState(
                      () => _fontSize = (_fontSize + 1.5).clamp(12, 24),
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
            if (_summary != null && _summary!.chapters.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: DropdownButtonFormField<int>(
                  initialValue: _chapterIndex,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Seção / Capítulo',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _summary!.chapters
                      .map(
                        (c) => DropdownMenuItem<int>(
                          value: c.index,
                          child: Text(
                            c.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (idx) {
                    if (idx != null) _selectChapter(idx);
                  },
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _chapter == null
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Publicação ou capítulo não encontrado na biblioteca local.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: SelectableText(
                        _chapter!.plainText,
                        style: TextStyle(fontSize: _fontSize, height: 1.6),
                      ),
                    ),
            ),
            if (_chapter != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copiar seção'),
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(
                            text:
                                '${_chapter!.title}\n\n${_chapter!.plainText}',
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Conteúdo da seção copiado!'),
                          ),
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
}
