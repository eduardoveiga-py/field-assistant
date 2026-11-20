import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_theme.dart';
import '../../picture_bank/picture_entry_model.dart';
import '../providers.dart';

/// Tela da Aba "Banco de Gravuras" do Field Assistant.
/// Galeria visual com pesquisa, filtros por tags e visualizador maximizado
/// em tela cheia com zoom interativo contínuo (pinch-to-zoom e pan livre).
class PictureBankScreen extends ConsumerStatefulWidget {
  const PictureBankScreen({super.key});

  @override
  ConsumerState<PictureBankScreen> createState() => _PictureBankScreenState();
}

class _PictureBankScreenState extends ConsumerState<PictureBankScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedTag = 'Todos';
  List<PictureEntry> _pictures = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPictures();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPictures() async {
    final db = ref.read(repositoryProvider).db;
    final pics = await PictureBankManager.loadPictures(db);
    if (mounted) {
      setState(() {
        _pictures = pics;
        _isLoading = false;
      });
    }
  }

  List<PictureEntry> get _filteredPictures {
    final query = _searchController.text.trim().toLowerCase();
    return _pictures.where((p) {
      final matchesQuery =
          query.isEmpty ||
          p.caption.toLowerCase().contains(query) ||
          p.tags.any((t) => t.toLowerCase().contains(query));
      final matchesTag =
          _selectedTag == 'Todos' ||
          p.tags.any((t) => t.toLowerCase() == _selectedTag.toLowerCase());
      return matchesQuery && matchesTag;
    }).toList();
  }

  Set<String> get _availableTags {
    final tags = <String>{'Todos'};
    for (final p in _pictures) {
      for (final t in p.tags) {
        if (t.trim().isNotEmpty) tags.add(t.trim());
      }
    }
    return tags;
  }

  Future<void> _showAddPictureModal() async {
    String? pickedImageData;
    final captionCtrl = TextEditingController();
    final tagsCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    bool isPicking = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.add_photo_alternate,
                            color: AppTheme.accentTeal,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Adicionar ao Banco de Gravuras',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Área de Seleção de Imagem
                  Center(
                    child: Column(
                      children: [
                        if (pickedImageData != null &&
                            pickedImageData!.isNotEmpty)
                          Container(
                            height: 180,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.accentTeal,
                                width: 2,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _buildPictureWidget(pickedImageData!),
                          )
                        else
                          Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.shade400,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.image_outlined,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Nenhuma imagem selecionada',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              icon: isPicking
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.folder_open, size: 18),
                              label: const Text('Escolher Imagem'),
                              onPressed: isPicking
                                  ? null
                                  : () async {
                                      setSheetState(() => isPicking = true);
                                      try {
                                        final res = await FilePicker.pickFiles(
                                          type: FileType.image,
                                        );
                                        if (res.isNotEmpty) {
                                          final file = res.first;
                                          if (kIsWeb) {
                                            try {
                                              final bytes = await file
                                                  .readAsBytes();
                                              final b64 = base64Encode(bytes);
                                              setSheetState(() {
                                                pickedImageData =
                                                    'data:image/png;base64,$b64';
                                              });
                                            } catch (_) {}
                                          } else if (file.path != null) {
                                            setSheetState(() {
                                              pickedImageData = file.path;
                                            });
                                          }
                                        }
                                      } catch (e) {
                                        debugPrint(
                                          'Erro ao selecionar foto: $e',
                                        );
                                      } finally {
                                        setSheetState(() => isPicking = false);
                                      }
                                    },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),
                  TextField(
                    controller: urlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Ou cole a URL direta da imagem (opcional)',
                      hintText: 'https://exemplo.com/imagem.jpg',
                      prefixIcon: Icon(Icons.link),
                      isDense: true,
                    ),
                    onChanged: (val) {
                      if (val.trim().startsWith('http')) {
                        setSheetState(() => pickedImageData = val.trim());
                      }
                    },
                  ),

                  const SizedBox(height: 12),
                  TextField(
                    controller: captionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Legenda da Foto / Gravura *',
                      hintText: 'Ex: Visita na comunidade Betânia / Ilustração Bíblica',
                      isDense: true,
                    ),
                  ),

                  const SizedBox(height: 12),
                  TextField(
                    controller: tagsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tags (separadas por vírgula)',
                      hintText: 'Ex: campo, estudo, solimoes, jandiatuba',
                      prefixIcon: Icon(Icons.tag),
                      isDense: true,
                    ),
                  ),

                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text('Salvar Gravura'),
                        onPressed: () async {
                          final caption = captionCtrl.text.trim();
                          final image = pickedImageData ?? urlCtrl.text.trim();
                          if (caption.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Informe uma legenda para a gravura.',
                                ),
                                backgroundColor: AppTheme.alertRed,
                              ),
                            );
                            return;
                          }
                          if (image.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Selecione uma imagem ou informe a URL.',
                                ),
                                backgroundColor: AppTheme.alertRed,
                              ),
                            );
                            return;
                          }

                          final rawTags = tagsCtrl.text
                              .split(',')
                              .map((t) => t.trim().replaceAll('#', ''))
                              .where((t) => t.isNotEmpty)
                              .toList();

                          final newEntry = PictureEntry(
                            id: const Uuid().v4(),
                            caption: caption,
                            tags: rawTags,
                            imageData: image,
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                          );

                          final db = ref.read(repositoryProvider).db;
                          await PictureBankManager.savePicture(db, newEntry);
                          if (ctx.mounted) Navigator.pop(ctx);
                          await _loadPictures();

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Gravura salva no banco com sucesso!',
                                ),
                                backgroundColor: AppTheme.successGreen,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openPictureViewer(PictureEntry picture) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PictureDetailViewerScreen(
          picture: picture,
          onDelete: () async {
            final db = ref.read(repositoryProvider).db;
            await PictureBankManager.deletePicture(db, picture.id);
            await _loadPictures();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width < 600 ? 2 : (width < 1000 ? 3 : 4);
    final filtered = _filteredPictures;
    final allTags = _availableTags.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.photo_library, color: AppTheme.accentTeal),
            SizedBox(width: 10),
            Text('Banco de Gravuras'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recarregar Gravuras',
            onPressed: _loadPictures,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.accentTeal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_photo_alternate),
        label: const Text('Adicionar Foto'),
        onPressed: _showAddPictureModal,
      ),
      body: Column(
        children: [
          // Barra de Pesquisa
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por legenda ou tag...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // Chips de Tags Horizontais
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: allTags.length,
              separatorBuilder: (c, i) => const SizedBox(width: 8),
              itemBuilder: (c, i) {
                final tag = allTags[i];
                final isSelected = _selectedTag == tag;
                return ChoiceChip(
                  label: Text(tag == 'Todos' ? 'Todos' : '#$tag'),
                  selected: isSelected,
                  selectedColor: AppTheme.accentTeal.withValues(alpha: 0.2),
                  onSelected: (val) {
                    setState(() => _selectedTag = tag);
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Grade de Fotos
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Nenhuma gravura encontrada',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.only(
                      left: 14,
                      right: 14,
                      top: 8,
                      bottom: 80,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, idx) {
                      final pic = filtered[idx];
                      return Card(
                        elevation: 2,
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: InkWell(
                          onTap: () => _openPictureViewer(pic),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Imagem Miniatura
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  color: isDark
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFFF1F5F9),
                                  child: _buildPictureWidget(pic.imageData),
                                ),
                              ),
                              // Legenda e Tags
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      pic.caption,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (pic.tags.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        pic.tags.map((t) => '#$t').join(' '),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.accentTeal,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
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
        ],
      ),
    );
  }

  static Widget _buildPictureWidget(String data) {
    if (data.startsWith('data:image')) {
      try {
        final commaIdx = data.indexOf(',');
        final bytes = base64Decode(data.substring(commaIdx + 1));
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {}
    } else if (data.startsWith('http')) {
      return Image.network(
        data,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) =>
            const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
      );
    } else if (data.startsWith('assets/')) {
      return Container(
        color: const Color(0xFF0F172A),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.landscape, size: 48, color: AppTheme.accentTeal),
              const SizedBox(height: 6),
              Text(
                data.split('/').last.replaceAll('.png', ''),
                style: const TextStyle(color: Colors.white70, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    } else {
      final file = File(data);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }
    return const Center(child: Icon(Icons.image, size: 40, color: Colors.grey));
  }
}

/// Visualizador em tela cheia com zoom interativo ilimitado (pinch-to-zoom e pan contínuo)
class PictureDetailViewerScreen extends StatefulWidget {
  final PictureEntry picture;
  final VoidCallback onDelete;

  const PictureDetailViewerScreen({
    super.key,
    required this.picture,
    required this.onDelete,
  });

  @override
  State<PictureDetailViewerScreen> createState() =>
      _PictureDetailViewerScreenState();
}

class _PictureDetailViewerScreenState extends State<PictureDetailViewerScreen> {
  final TransformationController _controller = TransformationController();
  bool _showOverlay = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _controller.value = Matrix4.identity();
  }

  void _zoomIn() {
    _controller.value = _controller.value.clone()
      ..scaleByDouble(1.5, 1.5, 1.0, 1.0);
  }

  void _zoomOut() {
    _controller.value = _controller.value.clone()
      ..scaleByDouble(0.67, 0.67, 1.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Canvas Interativo de Imagem com Zoom Livre
          GestureDetector(
            onTap: () => setState(() => _showOverlay = !_showOverlay),
            onDoubleTap: _resetZoom,
            child: SizedBox.expand(
              child: InteractiveViewer(
                transformationController: _controller,
                minScale: 0.2,
                maxScale: 10.0,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                clipBehavior: Clip.none,
                child: Center(
                  child: Hero(
                    tag: widget.picture.id,
                    child: _PictureBankScreenState._buildPictureWidget(
                      widget.picture.imageData,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Barra Superior com Controles
          if (_showOverlay)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black87, Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 8,
                  right: 8,
                  bottom: 20,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        widget.picture.caption,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.zoom_in, color: Colors.white),
                      tooltip: 'Aproximar Zoom',
                      onPressed: _zoomIn,
                    ),
                    IconButton(
                      icon: const Icon(Icons.zoom_out, color: Colors.white),
                      tooltip: 'Afastar Zoom',
                      onPressed: _zoomOut,
                    ),
                    IconButton(
                      icon: const Icon(Icons.restart_alt, color: Colors.white),
                      tooltip: 'Restaurar Tamanho Original',
                      onPressed: _resetZoom,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      tooltip: 'Excluir Gravura',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Excluir gravura?'),
                            content: const Text(
                              'Tem certeza que deseja remover esta gravura do banco?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancelar'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Excluir'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && mounted && context.mounted) {
                          widget.onDelete();
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

          // Barra Inferior com Legenda e Tags
          if (_showOverlay)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black87],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  top: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.picture.caption,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.picture.tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: widget.picture.tags.map((t) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.accentTeal.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '#$t',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
