import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_theme.dart';
import '../../database/app_database.dart';
import '../../references/app_reference.dart';
import '../providers.dart';
import 'app_inline_image_view.dart';
import 'app_reference_picker_dialog.dart';
import 'highlight_text_helper.dart';
import 'jw_highlight_floating_toolbar.dart';
import 'managed_text_controllers.dart';
import 'markdown_preview_text.dart';
import 'rich_formatted_editing_controller.dart';

/// Barra de ferramentas de formatação rica e WYSIWYG ágil.
/// - Quando usada com [RichFormattedEditingController], aplica negrito, itálico,
///   títulos, citações, referências (TNM/Abas/Gravuras), imagens e marcações JW Library
///   visualmente no editor sem exibir caracteres brutos (`**`, `###`, `(app://...)`, `<u...>`).
/// - Também dispara automaticamente a pílula flutuante JW Library assim que o usuário
///   seleciona uma palavra ou frase no campo de edição (quando [enableHighlightPalette] é true).
class RichMarkdownToolbar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onChanged;
  final bool enableHighlightPalette;
  final bool enableCrossReferences;
  final bool enableImagePicker;
  final AppRefCategory initialReferenceCategory;
  final ValueChanged<AppReferencePickResult>? onReferenceInserted;

  const RichMarkdownToolbar({
    super.key,
    required this.controller,
    this.onChanged,
    this.enableHighlightPalette = true,
    this.enableCrossReferences = true,
    this.enableImagePicker = true,
    this.initialReferenceCategory = AppRefCategory.question,
    this.onReferenceInserted,
  });

  /// Aplica uma referência selecionada em [controller], respeitando o modo
  /// escolhido (somente link, link + transcrição, ou somente texto transcrito).
  static void applyPickedReferenceToController(
    TextEditingController controller,
    AppReferencePickResult picked, {
    VoidCallback? onChanged,
  }) {
    final linkMatch = RegExp(r'^\[([^\]]+)\]\(([^)]+)\)$')
        .firstMatch(picked.markdownToken.trim());
    final pickedLabel = linkMatch != null
        ? linkMatch.group(1)!
        : (picked.candidate?.title ?? 'Referência');
    final pickedUrl = linkMatch != null
        ? linkMatch.group(2)!
        : (picked.candidate?.buildUri() ?? '');
    final hasTranscript =
        (picked.transcriptHeader != null &&
            picked.transcriptHeader!.isNotEmpty) ||
        picked.transcriptLines.isNotEmpty ||
        (picked.transcriptMarkdown != null &&
            picked.transcriptMarkdown!.trim().isNotEmpty);

    if (controller is RichFormattedEditingController) {
      if (picked.insertMode != ReferenceInsertMode.transcriptOnly &&
          pickedUrl.isNotEmpty) {
        controller.insertLink(label: pickedLabel, url: pickedUrl);
      } else if (picked.insertMode == ReferenceInsertMode.linkOnly ||
          !hasTranscript) {
        controller.insertLink(label: pickedLabel, url: pickedUrl);
      }

      if (picked.insertMode != ReferenceInsertMode.linkOnly && hasTranscript) {
        final lines = picked.transcriptLines.isNotEmpty
            ? picked.transcriptLines
            : (picked.transcriptMarkdown ?? '')
                  .split('\n')
                  .map((l) => l.replaceFirst(RegExp(r'^>\s*'), ''))
                  .where((l) => l.trim().isNotEmpty)
                  .toList();
        controller.insertQuotedTranscript(
          header: picked.transcriptHeader,
          lines: lines,
        );
      }
      onChanged?.call();
      return;
    }

    final buf = StringBuffer();
    if (picked.insertMode != ReferenceInsertMode.transcriptOnly ||
        !hasTranscript) {
      buf.write(picked.markdownToken.trim());
    }
    if (picked.insertMode != ReferenceInsertMode.linkOnly && hasTranscript) {
      if (buf.isNotEmpty) buf.write('\n');
      buf.write((picked.transcriptMarkdown ?? '').trim());
    }
    final insertion = '${buf.toString()} ';
    final sel = controller.selection;
    final cur = controller.text;
    final start = (sel.isValid ? sel.start : cur.length).clamp(0, cur.length);
    final end = (sel.isValid ? sel.end : cur.length).clamp(start, cur.length);
    controller.value = TextEditingValue(
      text: cur.replaceRange(start, end, insertion),
      selection: TextSelection.collapsed(offset: start + insertion.length),
    );
    onChanged?.call();
  }

  /// Abre o seletor de referências cruzadas (`📖` TNM / `🔖` Abas) diretamente
  /// para qualquer [TextEditingController], mantendo a edição WYSIWYG limpa.
  static Future<AppReferencePickResult?> pickAndInsertReference(
    BuildContext context, {
    required AppDatabase db,
    required TextEditingController controller,
    AppRefCategory initialCategory = AppRefCategory.bible,
    VoidCallback? onChanged,
  }) async {
    final picked = await showAppReferencePickerDialog(
      context,
      db: db,
      initialCategory: initialCategory,
    );
    if (picked == null) return null;

    applyPickedReferenceToController(controller, picked, onChanged: onChanged);
    return picked;
  }

  @override
  State<RichMarkdownToolbar> createState() => _RichMarkdownToolbarState();
}

class _RichMarkdownToolbarState extends State<RichMarkdownToolbar> {
  final JwHighlightFloatingController _hlFloating =
      JwHighlightFloatingController();
  final GlobalKey _toolbarAnchorKey = GlobalKey();
  TextSelection? _lastSelection;

  @override
  void initState() {
    super.initState();
    _lastSelection = widget.controller.selection;
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant RichMarkdownToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      _lastSelection = widget.controller.selection;
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _hlFloating.dispose();
    super.dispose();
  }

  RichFormattedEditingController? get _richCtrl {
    final c = widget.controller;
    return c is RichFormattedEditingController ? c : null;
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final sel = widget.controller.selection;
    if (sel == _lastSelection) return;
    _lastSelection = sel;

    if (!widget.enableHighlightPalette || _richCtrl == null) {
      _hlFloating.hide();
      return;
    }

    if (sel.isValid && !sel.isCollapsed && sel.end > sel.start) {
      final capturedSel = sel;
      _hlFloating.show(
        context: context,
        keyPrefix: 'editor',
        anchorKey: _toolbarAnchorKey,
        onPickColor: (hex) {
          final rich = _richCtrl;
          if (rich == null) return;
          if ((rich.selection.isCollapsed || !rich.selection.isValid) &&
              capturedSel.end <= rich.text.length) {
            rich.selection = capturedSel;
          }
          rich.applyHighlightColor(hex);
          widget.onChanged?.call();
        },
      );
    } else {
      _hlFloating.hide();
    }
  }

  AppDatabase? _tryReadDb(BuildContext context) {
    try {
      return ProviderScope.containerOf(
        context,
        listen: false,
      ).read(databaseProvider);
    } catch (_) {
      return null;
    }
  }

  void _wrapSelection({
    required String prefix,
    required String suffix,
    String defaultText = '',
  }) {
    final controller = widget.controller;
    final text = controller.text;
    final selection = controller.selection;

    if (!selection.isValid || selection.isCollapsed) {
      final rawOffset = selection.isValid ? selection.baseOffset : text.length;
      final insertIndex = rawOffset.clamp(0, text.length);
      final newText = text.replaceRange(
        insertIndex,
        insertIndex,
        '$prefix$defaultText$suffix',
      );
      final newCursorPos = insertIndex + prefix.length + defaultText.length;
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursorPos),
      );
    } else {
      final start = selection.start.clamp(0, text.length);
      final end = selection.end.clamp(0, text.length);
      final selectedText = text.substring(start, end);
      final newText = text.replaceRange(
        start,
        end,
        '$prefix$selectedText$suffix',
      );
      final newCursorPos =
          start + prefix.length + selectedText.length + suffix.length;
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursorPos),
      );
    }
    widget.onChanged?.call();
  }

  void _insertAtLineStart(String linePrefix, String cleanPrefix) {
    final rich = _richCtrl;
    if (rich != null) {
      rich.insertVisualLinePrefix(cleanPrefix);
      widget.onChanged?.call();
      return;
    }
    final controller = widget.controller;
    final text = controller.text;
    final selection = controller.selection;
    final rawCursor = selection.isValid ? selection.baseOffset : text.length;
    final cursor = rawCursor.clamp(0, text.length);

    final lastNewline = text.lastIndexOf('\n', cursor > 0 ? cursor - 1 : 0);
    final lineStart = lastNewline == -1
        ? 0
        : (lastNewline + 1).clamp(0, text.length);

    final newText = text.replaceRange(lineStart, lineStart, linePrefix);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor + linePrefix.length),
    );
    widget.onChanged?.call();
  }

  void _removeSelectionHighlight() {
    final rich = _richCtrl;
    if (rich != null) {
      rich.applyHighlightColor(null);
      widget.onChanged?.call();
      return;
    }
    final controller = widget.controller;
    final text = controller.text;
    final selection = controller.selection;
    if (!selection.isValid || selection.isCollapsed) return;
    final start = selection.start.clamp(0, text.length);
    final end = selection.end.clamp(0, text.length);
    if (end <= start) return;
    final stripped = HighlightTextHelper.stripHighlightTags(
      text.substring(start, end),
    );
    final newText = text.replaceRange(start, end, stripped);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + stripped.length),
    );
    widget.onChanged?.call();
  }

  void _insertPictureMarkdownOrVisual({
    required String caption,
    required String src,
  }) {
    final cleanCaption = MarkdownPreviewText.cleanMarkdown(caption).trim();
    final safeCaption = cleanCaption.isEmpty ? 'Imagem' : cleanCaption;
    final rich = _richCtrl;
    if (rich != null) {
      rich.addInlineImage(alt: safeCaption, src: src);
      widget.onChanged?.call();
      return;
    }
    _wrapSelection(prefix: '![$safeCaption]($src)', suffix: '');
  }

  Future<void> _openReferencePicker(
    BuildContext context, {
    AppRefCategory? overrideCategory,
  }) async {
    final db = _tryReadDb(context);
    if (db == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Banco local indisponível neste contexto para listar referências.',
            ),
          ),
        );
      }
      return;
    }
    final picked = await showAppReferencePickerDialog(
      context,
      db: db,
      initialCategory: overrideCategory ?? widget.initialReferenceCategory,
    );
    if (picked == null) return;

    final tokenMatch = RegExp(r'^\[([^\]]+)\]\(([^\)]+)\)$')
        .firstMatch(picked.markdownToken.trim());
    final pickedLabel =
        tokenMatch?.group(1) ?? picked.candidate?.title ?? picked.markdownToken;
    final pickedUrl =
        tokenMatch?.group(2) ?? picked.candidate?.buildUri() ?? '';

    if (picked.category == AppRefCategory.picture && pickedUrl.isNotEmpty) {
      _insertPictureMarkdownOrVisual(caption: pickedLabel, src: pickedUrl);
    } else {
      RichMarkdownToolbar.applyPickedReferenceToController(
        widget.controller,
        picked,
        onChanged: widget.onChanged,
      );
    }
    widget.onReferenceInserted?.call(picked);
  }

  void _showColorPicker(BuildContext context) {
    final savedSel = widget.controller.selection;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.border_color_outlined,
                    size: 18,
                    color: AppTheme.primaryBlue,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Marcar texto com Cor (JW Library)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final item in HighlightTextHelper.colors)
                    _colorOption(
                      label: item.label,
                      color: item.color,
                      onTap: () {
                        Navigator.pop(ctx);
                        final rich = _richCtrl;
                        if (rich != null) {
                          if ((rich.selection.isCollapsed ||
                                  !rich.selection.isValid) &&
                              savedSel.isValid &&
                              !savedSel.isCollapsed &&
                              savedSel.end <= rich.text.length) {
                            rich.selection = savedSel;
                          }
                          rich.applyHighlightColor(item.hex);
                          widget.onChanged?.call();
                        } else {
                          _wrapSelection(
                            prefix: '<u style="color:${item.hex}">',
                            suffix: '</u>',
                            defaultText: 'destaque',
                          );
                        }
                      },
                    ),
                  InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      final rich = _richCtrl;
                      if (rich != null &&
                          (rich.selection.isCollapsed ||
                              !rich.selection.isValid) &&
                          savedSel.isValid &&
                          !savedSel.isCollapsed &&
                          savedSel.end <= rich.text.length) {
                        rich.selection = savedSel;
                      }
                      _removeSelectionHighlight();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.redAccent),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.format_clear,
                            size: 15,
                            color: Colors.redAccent,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Remover',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _colorOption({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.25),
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 6, backgroundColor: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 40;
    final rich = _richCtrl;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (ctx, _) {
        final inlineImages = rich?.inlineImages ?? const [];
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              key: _toolbarAnchorKey,
              height: keyboardOpen ? 34 : 40,
              margin: EdgeInsets.only(
                bottom: inlineImages.isNotEmpty ? 4 : (keyboardOpen ? 4 : 8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _toolbarButton(
                      icon: Icons.format_bold,
                      tooltip: 'Negrito',
                      isActive: rich?.isStyleAtCursor(bold: true) ?? false,
                      onTap: () {
                        if (rich != null) {
                          rich.toggleInlineStyle(bold: true);
                          widget.onChanged?.call();
                        } else {
                          _wrapSelection(
                            prefix: '**',
                            suffix: '**',
                            defaultText: 'texto',
                          );
                        }
                      },
                    ),
                    _toolbarButton(
                      icon: Icons.format_italic,
                      tooltip: 'Itálico',
                      isActive: rich?.isStyleAtCursor(italic: true) ?? false,
                      onTap: () {
                        if (rich != null) {
                          rich.toggleInlineStyle(italic: true);
                          widget.onChanged?.call();
                        } else {
                          _wrapSelection(
                            prefix: '*',
                            suffix: '*',
                            defaultText: 'texto',
                          );
                        }
                      },
                    ),
                    _toolbarButton(
                      icon: Icons.title,
                      tooltip: 'Título Grande',
                      isActive:
                          rich?.isBlockStyleAtCursor(RichBlockStyle.h2) ??
                          false,
                      onTap: () {
                        if (rich != null) {
                          rich.toggleBlockStyle(RichBlockStyle.h2);
                          widget.onChanged?.call();
                        } else {
                          _insertAtLineStart('### ', '• ');
                        }
                      },
                    ),
                    _toolbarButton(
                      icon: Icons.text_fields,
                      tooltip: 'Subtítulo',
                      isActive:
                          rich?.isBlockStyleAtCursor(RichBlockStyle.h3) ??
                          false,
                      onTap: () {
                        if (rich != null) {
                          rich.toggleBlockStyle(RichBlockStyle.h3);
                          widget.onChanged?.call();
                        } else {
                          _insertAtLineStart('#### ', '• ');
                        }
                      },
                    ),
                    const VerticalDivider(width: 16, indent: 8, endIndent: 8),
                    _toolbarButton(
                      icon: Icons.format_list_bulleted,
                      tooltip: 'Lista de Marcadores',
                      onTap: () => _insertAtLineStart('- ', '• '),
                    ),
                    _toolbarButton(
                      icon: Icons.check_box_outlined,
                      tooltip: 'Checklist / Tarefa',
                      onTap: () => _insertAtLineStart('- [ ] ', '☐ '),
                    ),
                    _toolbarButton(
                      icon: Icons.format_quote,
                      tooltip: 'Citação',
                      onTap: () {
                        if (rich != null) {
                          rich.toggleBlockStyle(RichBlockStyle.quote);
                          widget.onChanged?.call();
                        } else {
                          _insertAtLineStart('> ', '• ');
                        }
                      },
                    ),
                    const VerticalDivider(width: 16, indent: 8, endIndent: 8),
                    _toolbarButton(
                      key: const Key('btn_toolbar_insert_bible'),
                      icon: Icons.menu_book_outlined,
                      tooltip: widget.enableCrossReferences
                          ? 'Referência Bíblica TNM (Popup)'
                          : 'Texto Bíblico',
                      onTap: widget.enableCrossReferences
                          ? () => _openReferencePicker(
                              context,
                              overrideCategory: AppRefCategory.bible,
                            )
                          : () => _wrapSelection(
                              prefix: '📖 ',
                              suffix: '',
                              defaultText: 'Texto bíblico',
                            ),
                    ),
                    if (widget.enableCrossReferences)
                      _toolbarButton(
                        key: const Key('btn_toolbar_insert_ref'),
                        icon: Icons.bookmark_add_outlined,
                        tooltip: 'Inserir Referência de Abas / Gravuras / TNM',
                        onTap: () => _openReferencePicker(context),
                      ),
                    if (widget.enableHighlightPalette)
                      _toolbarButton(
                        key: const Key('btn_toolbar_highlight_color'),
                        icon: Icons.border_color_outlined,
                        tooltip: 'Marcar com Cor (JW Library)',
                        isActive: rich?.pendingHighlightHex != null,
                        onTap: () => _showColorPicker(context),
                      ),
                    const VerticalDivider(width: 16, indent: 8, endIndent: 8),
                    if (widget.enableImagePicker)
                      _toolbarButton(
                        key: const Key('btn_toolbar_insert_image'),
                        icon: Icons.add_photo_alternate_outlined,
                        tooltip: 'Inserir Imagem (Dispositivo ou Gravuras)',
                        onTap: () => _showImagePickerDialog(context),
                      ),
                    _toolbarButton(
                      icon: Icons.link_rounded,
                      tooltip: 'Inserir Link / Publicação',
                      onTap: () => _showLinkPickerDialog(context),
                    ),
                    _toolbarButton(
                      icon: Icons.code,
                      tooltip: 'Código',
                      isActive: rich?.isStyleAtCursor(code: true) ?? false,
                      onTap: () {
                        if (rich != null) {
                          rich.toggleInlineStyle(code: true);
                          widget.onChanged?.call();
                        } else {
                          _wrapSelection(
                            prefix: '`',
                            suffix: '`',
                            defaultText: 'código',
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (inlineImages.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                height: 122,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: inlineImages.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, idx) {
                    final img = inlineImages[idx];
                    return SizedBox(
                      width: 160,
                      child: AppInlineImageView(
                        src: img.src,
                        alt: img.alt,
                        maxHeight: 82,
                        onRemove: () {
                          rich?.removeInlineImageAt(idx);
                          widget.onChanged?.call();
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _pickImageFromDevice(BuildContext context) async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (files.isEmpty) return;
      final picked = files.first;
      final bytes = await picked.readAsBytes();
      if (bytes.isNotEmpty && (kIsWeb || picked.path == null)) {
        final lower = picked.name.toLowerCase();
        final mime = lower.endsWith('.png')
            ? 'image/png'
            : (lower.endsWith('.webp') ? 'image/webp' : 'image/jpeg');
        final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
        _insertPictureMarkdownOrVisual(caption: picked.name, src: dataUrl);
        return;
      }
      final path = picked.path;
      if (path != null && path.isNotEmpty) {
        _insertPictureMarkdownOrVisual(caption: picked.name, src: path);
        return;
      }
      if (bytes.isNotEmpty) {
        final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        _insertPictureMarkdownOrVisual(caption: picked.name, src: dataUrl);
      }
    } catch (e) {
      debugPrint('Erro ao selecionar imagem do dispositivo: $e');
      if (!kIsWeb) {
        try {
          final photo = await ImagePicker().pickImage(
            source: ImageSource.gallery,
            maxWidth: 1280,
            maxHeight: 1280,
            imageQuality: 80,
          );
          if (photo != null) {
            _insertPictureMarkdownOrVisual(
              caption: photo.name,
              src: photo.path,
            );
          }
        } catch (err) {
          debugPrint('Fallback ImagePicker falhou: $err');
        }
      }
    }
  }

  Future<void> _pickImageFromPictureBank(BuildContext context) async {
    final db = _tryReadDb(context);
    if (db == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Banco de Gravuras indisponível neste contexto.'),
          ),
        );
      }
      return;
    }
    final pic = await showPictureBankPickerModal(context, db: db);
    if (pic == null) return;
    _insertPictureMarkdownOrVisual(
      caption: pic.caption,
      src: AppReferenceHelper.buildUri(AppRefCategory.picture, pic.id),
    );
  }

  void _showImagePickerDialog(BuildContext context) {
    final db = _tryReadDb(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.add_photo_alternate,
                      color: AppTheme.primaryBlue,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Inserir Imagem',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              if (db != null)
                ListTile(
                  key: const Key('btn_pick_img_picture_bank'),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF0EA5E9),
                    child: Icon(
                      Icons.photo_library_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: const Text('Escolher do Banco de Gravuras'),
                  subtitle: const Text(
                    'Exibe a gravura salva diretamente no texto',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImageFromPictureBank(context);
                  },
                ),
              ListTile(
                key: const Key('btn_pick_img_device'),
                leading: const Icon(
                  Icons.upload_file_outlined,
                  color: AppTheme.primaryBlue,
                ),
                title: const Text('Importar do Dispositivo / Galeria'),
                subtitle: const Text(
                  'Selecionar foto do celular ou computador',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImageFromDevice(context);
                },
              ),
              if (!kIsWeb)
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt_outlined,
                    color: AppTheme.accentTeal,
                  ),
                  title: const Text('Tirar com a Câmera'),
                  subtitle: const Text(
                    'Fotografar anotação, publicação ou lugar',
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      final picker = ImagePicker();
                      final photo = await picker.pickImage(
                        source: ImageSource.camera,
                        maxWidth: 1280,
                        maxHeight: 1280,
                        imageQuality: 80,
                      );
                      if (photo != null) {
                        _insertPictureMarkdownOrVisual(
                          caption: photo.name,
                          src: photo.path,
                        );
                      }
                    } catch (e) {
                      debugPrint('Erro ao capturar foto: $e');
                    }
                  },
                ),
              if (widget.enableCrossReferences)
                ListTile(
                  leading: const Icon(
                    Icons.bookmark_add_outlined,
                    color: AppTheme.accentTeal,
                  ),
                  title: const Text('Outra Referência Interna / TNM'),
                  subtitle: const Text(
                    'Nota, Dúvida, Documento, Tarefa, Projeto, Inbox ou Bíblia',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openReferencePicker(context);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.link, color: Colors.purple),
                title: const Text('Inserir Link / URL de Imagem'),
                subtitle: const Text(
                  'Usar endereço web (https://...) ou caminho local',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showManualImageDialog(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showManualImageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => ManagedTextControllers(
        initialTexts: const ['', ''],
        builder: (ctx, ctrls) {
          final captionCtrl = ctrls[0];
          final urlCtrl = ctrls[1];

          return AlertDialog(
            title: const Text('Inserir Imagem por URL'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: captionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Legenda da foto',
                    hintText: 'Ex: Mapa do território',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'URL ou Caminho da Imagem',
                    hintText: 'https://exemplo.com/foto.jpg',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  final path = urlCtrl.text.trim();
                  if (path.isNotEmpty) {
                    final caption = captionCtrl.text.trim().isEmpty
                        ? 'Imagem'
                        : captionCtrl.text.trim();
                    _insertPictureMarkdownOrVisual(caption: caption, src: path);
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('Inserir'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLinkPickerDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.bookmark_added_outlined,
                      color: AppTheme.primaryBlue,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Inserir Link ou Publicação',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              if (widget.enableCrossReferences) ...[
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppTheme.accentTeal,
                    child: Icon(
                      Icons.bookmark_add_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Referência Interna do App / Gravura / Bíblia',
                  ),
                  subtitle: const Text(
                    'Nota, Dúvida, Documento, Gravura, Tarefa, Projeto, Inbox ou TNM',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openReferencePicker(context);
                  },
                ),
                const Divider(),
              ],
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF4338CA),
                  child: Icon(Icons.menu_book, color: Colors.white, size: 20),
                ),
                title: const Text('Publicação do JW.org'),
                subtitle: const Text(
                  'Livro, brochura, revista ou artigo teocrático',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showLinkInputModal(
                    context,
                    defaultPrefix: '📖 ',
                    titleHint: 'Ex: Seja Feliz para Sempre! Lição 12',
                    urlHint: 'https://www.jw.org/finder?srcid=share&prefer=lang&pub=lff&lesson=12',
                  );
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFDC2626),
                  child: Icon(
                    Icons.play_circle_fill,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: const Text('Vídeo do JW.org / Broadcasting'),
                subtitle: const Text(
                  'Vídeo de lição, animação bíblica ou música',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showLinkInputModal(
                    context,
                    defaultPrefix: '🎥 ',
                    titleHint: 'Ex: Por Que Estudar a Bíblia?',
                    urlHint: 'https://www.jw.org/finder?srcid=share&prefer=lang&docid=502012480',
                  );
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF0D9488),
                  child: Icon(Icons.link, color: Colors.white, size: 20),
                ),
                title: const Text('Link Geral da Web'),
                subtitle: const Text('Página ou ferramenta de pesquisa'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showLinkInputModal(
                    context,
                    defaultPrefix: '',
                    titleHint: 'Ex: Biblioteca Online da Torre de Vigia',
                    urlHint: 'https://wol.jw.org/pt/wol/h/r5/lp-t',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLinkInputModal(
    BuildContext context, {
    required String defaultPrefix,
    required String titleHint,
    required String urlHint,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => ManagedTextControllers(
        initialTexts: const ['', ''],
        builder: (ctx, ctrls) {
          final titleCtrl = ctrls[0];
          final urlCtrl = ctrls[1];

          return AlertDialog(
            title: Text(
              '${defaultPrefix.isNotEmpty ? defaultPrefix : "🔗 "}Inserir Link',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Título do Link / Publicação',
                    hintText: titleHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlCtrl,
                  decoration: InputDecoration(
                    labelText: 'URL (JW.org ou endereço web)',
                    hintText: urlHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  final url = urlCtrl.text.trim();
                  if (url.isNotEmpty) {
                    final title = titleCtrl.text.trim().isEmpty
                        ? 'Link'
                        : titleCtrl.text.trim();
                    final rich = _richCtrl;
                    if (rich != null) {
                      rich.insertLink(label: '$defaultPrefix$title', url: url);
                      widget.onChanged?.call();
                    } else {
                      _wrapSelection(
                        prefix: '[$defaultPrefix$title]($url)',
                        suffix: '',
                      );
                    }
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('Inserir Link'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _toolbarButton({
    Key? key,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        key: key,
        color: isActive
            ? AppTheme.primaryBlue.withValues(alpha: 0.16)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Icon(icon, size: 18, color: AppTheme.primaryBlue),
          ),
        ),
      ),
    );
  }
}
