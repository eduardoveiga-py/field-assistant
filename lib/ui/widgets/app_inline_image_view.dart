import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../database/app_database.dart';
import '../../media/media_file_image.dart';
import '../../picture_bank/picture_entry_model.dart';
import '../../references/app_reference.dart';
import '../providers.dart';
import '../screens/picture_bank_screen.dart';
import 'markdown_preview_text.dart';

/// Renderizador visual de imagem incorporado em leitores e editores.
/// Resolve automaticamente `app://ref/picture/<id>`, Base64 (`data:image`), URLs HTTP(S),
/// assets locais e caminhos nativos (apenas fora da Web), abrindo zoom em tela cheia ao tocar.
class AppInlineImageView extends StatelessWidget {
  final String src;
  final String alt;
  final double maxHeight;
  final VoidCallback? onRemove;

  const AppInlineImageView({
    super.key,
    required this.src,
    this.alt = 'Imagem',
    this.maxHeight = 220,
    this.onRemove,
  });

  static AppDatabase? _tryReadDb(BuildContext context) {
    try {
      return ProviderScope.containerOf(
        context,
        listen: false,
      ).read(databaseProvider);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = src.trim();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final parsedRef = AppReferenceHelper.isAppReferenceUrl(trimmed)
        ? AppReferenceHelper.parseUri(trimmed)
        : null;

    if (parsedRef != null && parsedRef.category == AppRefCategory.picture) {
      final db = _tryReadDb(context);
      if (db == null) {
        return _buildFallbackBox(isDark, caption: alt);
      }
      return FutureBuilder<List<PictureEntry>>(
        future: PictureBankManager.loadPictures(db),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Container(
              height: 120,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final pic = (snap.data ?? const [])
              .where((p) => p.id == parsedRef.itemId)
              .firstOrNull;
          if (pic == null) {
            return _buildFallbackBox(isDark, caption: alt);
          }
          return _wrapCard(
            context,
            isDark,
            child: _buildRawImageWidget(pic.imageData, isDark),
            caption: MarkdownPreviewText.cleanMarkdown(pic.caption),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PictureDetailViewerScreen(picture: pic),
                ),
              );
            },
          );
        },
      );
    }

    return _wrapCard(
      context,
      isDark,
      child: _buildRawImageWidget(trimmed, isDark),
      caption: alt,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PictureDetailViewerScreen(
              picture: PictureEntry(
                id: 'inline_${trimmed.hashCode}',
                caption: alt.isEmpty ? 'Imagem' : alt,
                tags: const [],
                imageData: trimmed,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _wrapCard(
    BuildContext context,
    bool isDark, {
    required Widget child,
    required String caption,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: maxHeight,
                    minHeight: 72,
                  ),
                  child: child,
                ),
                if (caption.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      caption.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? const Color(0xFFCBD5E1)
                            : const Color(0xFF475569),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: 6,
              right: 6,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onRemove,
                  child: const Padding(
                    padding: EdgeInsets.all(5),
                    child: Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRawImageWidget(String data, bool isDark) {
    if (data.startsWith('data:image')) {
      try {
        final idx = data.indexOf(',');
        if (idx != -1) {
          final bytes = base64Decode(data.substring(idx + 1));
          return Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _brokenPlaceholder(isDark),
          );
        }
      } catch (_) {}
    } else if (data.startsWith('http://') || data.startsWith('https://')) {
      return Image.network(
        data,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _brokenPlaceholder(isDark),
      );
    } else if (data.startsWith('assets/')) {
      return Container(
        height: 110,
        color: const Color(0xFF0F172A),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.landscape, size: 36, color: AppTheme.accentTeal),
              const SizedBox(height: 4),
              Text(
                data.split('/').last.replaceAll('.png', ''),
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    } else if (data.isNotEmpty) {
      return buildLocalFileImage(
        data,
        fit: BoxFit.contain,
        fallback: () => _brokenPlaceholder(isDark),
      );
    }
    return _brokenPlaceholder(isDark);
  }

  Widget _brokenPlaceholder(bool isDark) {
    return Container(
      height: 88,
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
      child: const Center(
        child: Icon(Icons.image_outlined, size: 32, color: Colors.grey),
      ),
    );
  }

  Widget _buildFallbackBox(bool isDark, {required String caption}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.photo_outlined, color: AppTheme.primaryBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              caption.isEmpty ? 'Gravura' : caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Seletor modal visual do **Banco de Gravuras** reutilizável por editores, Captura Rápida,
/// Documentos, Assinatura e JW Mail (excluindo explicitamente telas de Pessoas/Estudantes).
Future<PictureEntry?> showPictureBankPickerModal(
  BuildContext context, {
  required AppDatabase db,
}) async {
  return showDialog<PictureEntry>(
    context: context,
    barrierDismissible: true,
    builder: (dlgCtx) => _PictureBankPickerDialog(db: db),
  );
}

class _PictureBankPickerDialog extends StatefulWidget {
  final AppDatabase db;

  const _PictureBankPickerDialog({required this.db});

  @override
  State<_PictureBankPickerDialog> createState() =>
      _PictureBankPickerDialogState();
}

class _PictureBankPickerDialogState extends State<_PictureBankPickerDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<PictureEntry> _pictures = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final items = await PictureBankManager.loadPictures(widget.db);
    if (!mounted) return;
    setState(() {
      _pictures = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _pictures
        : _pictures.where((p) {
            return p.caption.toLowerCase().contains(query) ||
                p.tags.any((t) => t.toLowerCase().contains(query));
          }).toList();

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 620),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
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
                    Icons.photo_library_rounded,
                    color: AppTheme.primaryBlue,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Escolher do Banco de Gravuras',
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
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Filtrar gravura por legenda ou tag...',
                  prefixIcon: Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Nenhuma gravura encontrada no Banco de Gravuras.',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(14),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            childAspectRatio: 0.92,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, idx) {
                        final pic = filtered[idx];
                        return InkWell(
                          key: Key('btn_pick_picture_${pic.id}'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.of(context).pop(pic),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: IgnorePointer(
                                    child: AppInlineImageView(
                                      src: pic.imageData,
                                      alt: '',
                                      maxHeight: 150,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    MarkdownPreviewText.cleanMarkdown(
                                      pic.caption,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
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
      ),
    );
  }
}
