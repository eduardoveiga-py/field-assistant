import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../bible/nwt_bible_books.dart';
import '../../../bible/nwt_bible_service.dart';
import '../../../core/app_logger.dart';
import '../../../core/app_theme.dart';
import '../../../database/app_database.dart';
import '../../../publications/imported_publications_service.dart';
import '../bible_verse_popup_dialog.dart';
import '../publication_reader_dialog.dart';
import 'library_file_picker.dart';

/// Abre a janela de gerenciamento da Biblioteca Offline (Bíblias e Publicações) em Configurações.
Future<void> showOfflineLibraryDialog(
  BuildContext context, {
  required AppDatabase db,
  Future<PickedLibraryFile?> Function()? onPickFile,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => OfflineLibraryDialog(db: db, onPickFile: onPickFile),
  );
}

/// Janela centralizada em Configurações para importar Bíblias (múltiplos idiomas/traduções)
/// e outras publicações em EPUB (ou JSON para Bíblias), exibindo aviso claro caso .jwpub criptografado seja selecionado.
class OfflineLibraryDialog extends StatefulWidget {
  final AppDatabase db;
  final Future<PickedLibraryFile?> Function()? onPickFile;

  const OfflineLibraryDialog({super.key, required this.db, this.onPickFile});

  @override
  State<OfflineLibraryDialog> createState() => _OfflineLibraryDialogState();
}

class _OfflineLibraryDialogState extends State<OfflineLibraryDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<BibleNwtCatalog> _bibles = const [];
  List<ImportedPublicationSummary> _publications = const [];
  bool _loading = true;
  bool _importing = false;
  String? _progressLabel;
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refresh();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final bibles = await NwtBibleService.listTranslations(widget.db);
    final pubs = await ImportedPublicationsService.listPublications(widget.db);
    if (!mounted) return;
    setState(() {
      _bibles = bibles;
      _publications = pubs;
      _loading = false;
    });
  }

  void _updateImportProgress(int processed, int total) {
    if (!mounted || total <= 0) return;
    final pct = ((processed / total) * 100).round().clamp(1, 100);
    final next = 'Importando ($pct%)...';
    if (_progressLabel != next) {
      setState(() => _progressLabel = next);
    }
  }

  Future<void> _runImport({
    required String dialogTitle,
    required List<String> allowedExtensions,
    required String failureLogContext,
    required Future<String> Function(PickedLibraryFile picked) importer,
  }) async {
    setState(() {
      _importing = true;
      _progressLabel = 'Selecionando...';
      _statusMessage = null;
      _statusIsError = false;
    });
    try {
      final picked = await (widget.onPickFile != null
          ? widget.onPickFile!()
          : pickLibraryFile(
              dialogTitle: dialogTitle,
              allowedExtensions: allowedExtensions,
            ));
      if (picked == null) {
        if (mounted) {
          setState(() {
            _importing = false;
            _progressLabel = null;
          });
        }
        return;
      }
      if (picked.bytes.isEmpty) {
        throw StateError(
          'O arquivo "${picked.name}" está vazio ou não pôde ser lido pelo navegador/sistema.',
        );
      }
      if (mounted) {
        setState(() => _progressLabel = 'Processando...');
      }
      final successMessage = await importer(picked);
      await _refresh();
      if (mounted) {
        setState(() {
          _importing = false;
          _progressLabel = null;
          _statusIsError = false;
          _statusMessage = successMessage;
        });
      }
    } catch (e, st) {
      AppLogger.warning(failureLogContext, e, st);
      if (mounted) {
        setState(() {
          _importing = false;
          _progressLabel = null;
          _statusIsError = true;
          _statusMessage = e.toString();
        });
      }
    }
  }

  Future<void> _importBible() async {
    await _runImport(
      dialogTitle: 'Selecionar Bíblia (.epub ou .json)',
      allowedExtensions: const ['epub', 'json', 'jwpub', 'jwlpub'],
      failureLogContext: 'Falha ao importar Bíblia na biblioteca offline',
      importer: (picked) async {
        final res = await NwtBibleService.importFromBytes(
          widget.db,
          bytes: picked.bytes,
          fileName: picked.name,
          onProgress: _updateImportProgress,
        );
        return 'Bíblia "${res.catalog.title}" (${res.catalog.languageDisplay}) importada: '
            '${res.catalog.bookCount} livro(s), ${res.catalog.verseCount} versículos.';
      },
    );
  }

  Future<void> _importPublication() async {
    await _runImport(
      dialogTitle: 'Selecionar Publicação (.epub)',
      allowedExtensions: const ['epub', 'jwpub', 'jwlpub'],
      failureLogContext: 'Falha ao importar publicação na biblioteca offline',
      importer: (picked) async {
        final pub =
            await ImportedPublicationsService.importPublicationFromBytes(
              widget.db,
              bytes: picked.bytes,
              fileName: picked.name,
              onProgress: _updateImportProgress,
            );
        return 'Publicação "${pub.title}" (${NwtBibleBooks.languageDisplayName(pub.language)}) '
            'importada com ${pub.chapterCount} seção(ões) e disponível na lista de Referências.';
      },
    );
  }

  Widget _buildCoverThumbnail(String? coverBase64, IconData fallbackIcon) {
    if (coverBase64 != null && coverBase64.isNotEmpty) {
      try {
        final bytes = base64Decode(coverBase64);
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            bytes,
            width: 44,
            height: 54,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallbackCoverBox(fallbackIcon),
          ),
        );
      } catch (_) {}
    }
    return _fallbackCoverBox(fallbackIcon);
  }

  Widget _fallbackCoverBox(IconData icon) {
    return Container(
      width: 44,
      height: 54,
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: AppTheme.primaryBlue, size: 22),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.library_books_rounded,
                        color: AppTheme.primaryBlue,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Biblioteca Offline (Bíblias & Publicações)',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Fechar',
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  TabBar(
                    controller: _tabController,
                    labelColor: AppTheme.primaryBlue,
                    indicatorColor: AppTheme.primaryBlue,
                    tabs: [
                      Tab(text: 'Bíblias (${_bibles.length})'),
                      Tab(text: 'Publicações (${_publications.length})'),
                    ],
                  ),
                ],
              ),
            ),
            if (_statusMessage != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                color: _statusIsError
                    ? AppTheme.alertRed.withValues(alpha: 0.12)
                    : AppTheme.successGreen.withValues(alpha: 0.12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _statusIsError
                          ? Icons.error_outline
                          : Icons.check_circle_outline,
                      size: 18,
                      color: _statusIsError
                          ? AppTheme.alertRed
                          : AppTheme.successGreen,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildBiblesTab(isDark),
                        _buildPublicationsTab(isDark),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBiblesTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Importe uma ou mais traduções da Bíblia (português, espanhol, inglês, ticuna ou outro idioma) '
                'em formato .epub (jw.org) ou .json para leitura e comparação lado a lado no popup.',
                style: TextStyle(fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 6),
              Text(
                'Nota: arquivos .jwpub/.jwlpub possuem texto interno criptografado exclusivo do JW Library; '
                'baixe a edição .epub no jw.org ou use .json.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('btn_settings_import_bible'),
                onPressed: _importing ? null : _importBible,
                icon: _importing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.upload_file_rounded, size: 18),
                label: Text(
                  _importing
                      ? (_progressLabel ?? 'Importando...')
                      : 'Importar Bíblia (.epub / .json)',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_bibles.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: Text(
                'Nenhuma Bíblia importada ainda.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          for (final b in _bibles)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                leading: _buildCoverThumbnail(
                  b.coverBase64,
                  Icons.menu_book_rounded,
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        b.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (b.isPrimary)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Principal',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Text(
                  '${b.languageDisplay} • ${b.bookCount} livro(s) • ${b.verseCount} versículos',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) async {
                    if (action == 'primary') {
                      await NwtBibleService.setPrimaryTranslation(
                        widget.db,
                        b.id,
                      );
                      await _refresh();
                    } else if (action == 'read') {
                      final firstBook = b.chaptersByBook.keys.isNotEmpty
                          ? (b.chaptersByBook.keys.toList()..sort()).first
                          : 43;
                      await showBibleVersePopup(
                        context,
                        db: widget.db,
                        bookNumber: b.chaptersByBook.containsKey(43)
                            ? 43
                            : firstBook,
                        chapter: b.chaptersByBook.containsKey(43) ? 3 : 1,
                        verseSpec: b.chaptersByBook.containsKey(43)
                            ? '16'
                            : '1',
                      );
                    } else if (action == 'delete') {
                      await NwtBibleService.deleteTranslation(widget.db, b.id);
                      await _refresh();
                    }
                  },
                  itemBuilder: (_) => [
                    if (!b.isPrimary)
                      const PopupMenuItem(
                        value: 'primary',
                        child: Text('Definir como Principal'),
                      ),
                    const PopupMenuItem(
                      value: 'read',
                      child: Text('Abrir no Leitor / Comparar'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Remover Tradução',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildPublicationsTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Importe livros, brochuras e apostilas em .epub. Todas as publicações importadas '
                'ficam visíveis na lista de Referências (📚) para inserir em notas, estudos e pesquisas.',
                style: TextStyle(fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('btn_settings_import_publication'),
                onPressed: _importing ? null : _importPublication,
                icon: _importing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_stories_rounded, size: 18),
                label: Text(
                  _importing
                      ? (_progressLabel ?? 'Importando...')
                      : 'Importar Publicação (.epub)',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_publications.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: Text(
                'Nenhuma publicação EPUB importada ainda.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          for (final p in _publications)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                leading: _buildCoverThumbnail(
                  p.coverBase64,
                  Icons.auto_stories_rounded,
                ),
                title: Text(
                  p.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${NwtBibleBooks.languageDisplayName(p.language)} • ${p.chapterCount} seção(ões)',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Ler publicação',
                      icon: const Icon(
                        Icons.chrome_reader_mode_outlined,
                        color: AppTheme.primaryBlue,
                      ),
                      onPressed: () => showPublicationReaderDialog(
                        context,
                        db: widget.db,
                        publicationId: p.id,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remover publicação',
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: () async {
                        await ImportedPublicationsService.deletePublication(
                          widget.db,
                          p.id,
                        );
                        await _refresh();
                      },
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
