import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/app_logger.dart';
import '../../../core/app_theme.dart';
import '../../../database/app_database.dart';
import '../../../knowledge/note_cover_config.dart';
import '../app_inline_image_view.dart';
import '../settings/library_file_picker.dart';

/// Resultado explícito do seletor de capa da nota, diferenciando cancelamento
/// (`null`) de remoção proposital da capa (`cleared: true`).
class NoteCoverPickOutcome {
  final bool cleared;
  final NoteCoverConfig? cover;

  const NoteCoverPickOutcome({this.cleared = false, this.cover});
}

Future<NoteCoverPickOutcome?> showNoteCoverPickerDialog(
  BuildContext context, {
  NoteCoverConfig? initialCover,
  AppDatabase? pictureBankDb,
  String previewTitle = 'Título da Nota',
}) {
  return showDialog<NoteCoverPickOutcome>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _NoteCoverPickerDialog(
      initialCover: initialCover,
      pictureBankDb: pictureBankDb,
      previewTitle: previewTitle,
    ),
  );
}

class _NoteCoverPickerDialog extends StatefulWidget {
  final NoteCoverConfig? initialCover;
  final AppDatabase? pictureBankDb;
  final String previewTitle;

  const _NoteCoverPickerDialog({
    this.initialCover,
    this.pictureBankDb,
    required this.previewTitle,
  });

  @override
  State<_NoteCoverPickerDialog> createState() => _NoteCoverPickerDialogState();
}

class _NoteCoverPickerDialogState extends State<_NoteCoverPickerDialog> {
  String? _presetId;
  String? _iconId;
  String? _imageBase64;
  bool _processingPhoto = false;

  @override
  void initState() {
    super.initState();
    _presetId =
        widget.initialCover?.presetId ?? NoteCoverConfig.presets.first.id;
    _iconId = widget.initialCover?.iconId ?? 'none';
    _imageBase64 = widget.initialCover?.imageBase64;
  }

  NoteCoverConfig get _currentConfig => NoteCoverConfig(
    presetId: _presetId,
    iconId: _iconId,
    imageBase64: _imageBase64,
  );

  Future<void> _pickPhotoFromDevice() async {
    setState(() => _processingPhoto = true);
    try {
      final picked = await pickLibraryFile(
        dialogTitle: 'Escolher foto para capa da nota',
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      );
      if (picked == null || picked.bytes.isEmpty) return;
      final encoded = await NoteCoverConfig.compressImageForCover(picked.bytes);
      if (!mounted) return;
      if (encoded == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível otimizar esta imagem. Escolha outra foto PNG ou JPG menor.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      setState(() => _imageBase64 = encoded);
    } catch (e, st) {
      AppLogger.warning('Falha ao escolher foto para capa da nota', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar foto: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processingPhoto = false);
    }
  }

  Future<void> _pickPhotoFromPictureBank() async {
    final db = widget.pictureBankDb;
    if (db == null) return;
    final pic = await showPictureBankPickerModal(context, db: db);
    if (pic == null || !mounted) return;
    final raw = pic.imageData.trim();
    if (raw.isEmpty) return;

    final tempCfg = NoteCoverConfig(imageBase64: raw);
    final rawBytes = tempCfg.decodeImageBytes();
    if (rawBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A gravura selecionada não está em formato de imagem local compatível.',
          ),
        ),
      );
      return;
    }

    setState(() => _processingPhoto = true);
    try {
      final compressed = await NoteCoverConfig.compressImageForCover(rawBytes);
      if (!mounted) return;
      if (compressed != null) {
        setState(() => _imageBase64 = compressed);
      }
    } catch (e, st) {
      AppLogger.warning('Falha ao aplicar gravura como capa da nota', e, st);
    } finally {
      if (mounted) setState(() => _processingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cfg = _currentConfig;
    final preset = cfg.resolvedPreset ?? NoteCoverConfig.presets.first;
    final iconData = cfg.resolvedIconData;
    final photoBytes = cfg.decodeImageBytes();

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.palette_outlined,
                    color: AppTheme.primaryBlue,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Personalizar Capa da Nota',
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Pré-visualização em escala real da capa
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 118,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (photoBytes != null)
                              Image.memory(
                                photoBytes,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: preset.toLinearGradient(),
                                  ),
                                ),
                              )
                            else
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: preset.toLinearGradient(),
                                ),
                              ),
                            if (photoBytes != null)
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.25),
                                      Colors.black.withValues(alpha: 0.72),
                                    ],
                                  ),
                                ),
                              ),
                            if (iconData != null)
                              Positioned(
                                right: -8,
                                bottom: -12,
                                child: Icon(
                                  iconData,
                                  size: 96,
                                  color: Colors.white.withValues(alpha: 0.14),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    widget.previewTitle.trim().isEmpty
                                        ? 'Título da Nota'
                                        : widget.previewTitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black54,
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Prévia na nota e na exportação em PDF',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.white.withValues(
                                        alpha: 0.82,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Foto personalizada
                    const Text(
                      'Foto de Capa (Opcional)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          key: const Key('btn_cover_pick_device_photo'),
                          onPressed: _processingPhoto
                              ? null
                              : _pickPhotoFromDevice,
                          icon: _processingPhoto
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 18,
                                ),
                          label: const Text('Escolher Foto'),
                        ),
                        if (widget.pictureBankDb != null)
                          OutlinedButton.icon(
                            key: const Key('btn_cover_pick_picture_bank'),
                            onPressed: _processingPhoto
                                ? null
                                : _pickPhotoFromPictureBank,
                            icon: const Icon(
                              Icons.photo_library_outlined,
                              size: 18,
                            ),
                            label: const Text('Banco de Gravuras'),
                          ),
                        if (photoBytes != null)
                          TextButton.icon(
                            key: const Key('btn_cover_clear_photo'),
                            onPressed: () =>
                                setState(() => _imageBase64 = null),
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.redAccent,
                            ),
                            label: const Text(
                              'Remover foto',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Gradientes
                    const Text(
                      'Gradiente de Fundo',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: NoteCoverConfig.presets.map((p) {
                        final selected = _presetId == p.id;
                        return InkWell(
                          key: Key('cover_preset_${p.id}'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _presetId = p.id),
                          child: Container(
                            width: 122,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              gradient: p.toLinearGradient(),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.16),
                                width: selected ? 2.5 : 1,
                              ),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: p.accentTint.withValues(
                                          alpha: 0.4,
                                        ),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                if (selected)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Icon(
                                      Icons.check_circle,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    p.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Ícones decorativos
                    const Text(
                      'Ícone Sutil no Fundo',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: NoteCoverConfig.iconOptions.map((opt) {
                        final selected = (_iconId ?? 'none') == opt.id;
                        return ChoiceChip(
                          key: Key('cover_icon_${opt.id}'),
                          avatar: opt.icon != null
                              ? Icon(opt.icon, size: 16)
                              : const Icon(Icons.block, size: 15),
                          label: Text(
                            opt.label,
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: selected,
                          onSelected: (_) => setState(() => _iconId = opt.id),
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    key: const Key('btn_cover_remove_all'),
                    onPressed: () =>
                        Navigator.of(context)
                            .pop(const NoteCoverPickOutcome(cleared: true)),
                    child: const Text('Sem capa'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    key: const Key('btn_cover_apply'),
                    onPressed: _processingPhoto
                        ? null
                        : () => Navigator.of(context)
                              .pop(NoteCoverPickOutcome(cover: _currentConfig)),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Aplicar Capa'),
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

/// Banner reutilizável de capa de nota para detalhe e cards da Galeria.
class NoteCoverHeaderBackground extends StatelessWidget {
  final NoteCoverConfig cover;
  final double height;
  final Uint8List? cachedBytes;

  const NoteCoverHeaderBackground({
    super.key,
    required this.cover,
    this.height = 120,
    this.cachedBytes,
  });

  @override
  Widget build(BuildContext context) {
    final preset = cover.resolvedPreset ?? NoteCoverConfig.presets.first;
    final iconData = cover.resolvedIconData;
    final bytes = cachedBytes ?? cover.decodeImageBytes();

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (bytes != null)
            Image.memory(
              bytes,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => DecoratedBox(
                decoration: BoxDecoration(gradient: preset.toLinearGradient()),
              ),
            )
          else
            DecoratedBox(
              decoration: BoxDecoration(gradient: preset.toLinearGradient()),
            ),
          if (bytes != null)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.22),
                    Colors.black.withValues(alpha: 0.72),
                  ],
                ),
              ),
            ),
          if (iconData != null)
            Positioned(
              right: -6,
              bottom: -10,
              child: Icon(
                iconData,
                size: height * 0.85,
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
        ],
      ),
    );
  }
}
