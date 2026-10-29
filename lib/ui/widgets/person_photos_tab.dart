import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../database/app_database.dart';
import '../../media/media_picker_helper.dart';
import '../../media/person_photos_manager.dart';

class PersonPhotosTab extends ConsumerStatefulWidget {
  final PersonEntry person;

  const PersonPhotosTab({super.key, required this.person});

  @override
  ConsumerState<PersonPhotosTab> createState() => _PersonPhotosTabState();
}

class _PersonPhotosTabState extends ConsumerState<PersonPhotosTab> {
  Future<void> _addNewPhoto(String photoType, {String? defaultTitle}) async {
    final imageData = await MediaPickerHelper.pickImage(
      context,
      title: defaultTitle ?? 'Adicionar Foto de ${widget.person.name}',
    );

    if (imageData != null && imageData.isNotEmpty && mounted) {
      final mgr = ref.read(personPhotosManagerProvider);
      await mgr.addPhoto(
        personId: widget.person.id,
        photoType: photoType,
        imageData: imageData,
      );

      // Se for foto principal ou residência e ainda não houver definida, atualiza atalho
      if (photoType == 'person') {
        await mgr.savePersonPhoto(widget.person.id, imageData);
      } else if (photoType == 'house') {
        await mgr.saveHousePhoto(widget.person.id, imageData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto adicionada com sucesso à galeria!')),
        );
      }
    }
  }

  void _showAddPhotoModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Nova Foto',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Classifique o tipo de foto que deseja anexar ao cadastro:',
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.person, color: AppTheme.primaryBlue),
                ),
                title: const Text('Foto do Estudante / Morador', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Foto para identificar visualmente a pessoa'),
                onTap: () {
                  Navigator.pop(ctx);
                  _addNewPhoto('person', defaultTitle: 'Foto do Estudante / Morador');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.home, color: AppTheme.accentTeal),
                ),
                title: const Text('Fachada da Casa / Residência', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Ajuda a localizar o endereço no território'),
                onTap: () {
                  Navigator.pop(ctx);
                  _addNewPhoto('house', defaultTitle: 'Foto da Fachada / Residência');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.menu_book, color: Colors.purple),
                ),
                title: const Text('Anotação de Estudo / Publicação', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Registro de parágrafos, dúvidas ou esboços'),
                onTap: () {
                  Navigator.pop(ctx);
                  _addNewPhoto('study', defaultTitle: 'Foto de Anotação ou Lição');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPhotoTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'person':
        return 'Pessoa / Estudante';
      case 'house':
        return 'Residência';
      case 'study':
        return 'Estudo / Anotação';
      default:
        return 'Foto Anexa';
    }
  }

  Color _getBadgeColor(String type) {
    switch (type.toLowerCase()) {
      case 'person':
        return AppTheme.primaryBlue;
      case 'house':
        return AppTheme.accentTeal;
      case 'study':
        return Colors.purple;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final allPhotos = ref.watch(personPhotosStreamProvider).value ?? [];
    final personPhotos = allPhotos.where((p) => p.personId == widget.person.id).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Adicionar Foto'),
        onPressed: _showAddPhotoModal,
      ),
      body: personPhotos.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_library_outlined, size: 72, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'Nenhuma foto anexada ainda',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tire uma foto ou escolha fotos da galeria para identificar ${widget.person.name}, sua residência ou matérias estudadas.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_a_photo),
                      label: const Text('Anexar Primeira Foto'),
                      onPressed: _showAddPhotoModal,
                    ),
                  ],
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Fotos Anexadas (${personPhotos.length})',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.textDark,
                        ),
                      ),
                      Text(
                        'Toque para ampliar com zoom',
                        style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : AppTheme.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount = constraints.maxWidth > 800
                            ? 4
                            : constraints.maxWidth > 500
                                ? 3
                                : 2;

                        return GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: personPhotos.length,
                          itemBuilder: (context, index) {
                            final photo = personPhotos[index];
                            final badgeColor = _getBadgeColor(photo.photoType);
                            final badgeLabel = _formatPhotoTypeLabel(photo.photoType);

                            return Card(
                              clipBehavior: Clip.antiAlias,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                              child: InkWell(
                                onTap: () {
                                  MediaPickerHelper.showFullScreenImage(
                                    context,
                                    imageSource: photo.imageData,
                                    title: '${widget.person.name} • $badgeLabel',
                                    onDelete: () async {
                                      final mgr = ref.read(personPhotosManagerProvider);
                                      await mgr.deletePhotoById(photo.id);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Foto removida com sucesso.')),
                                        );
                                      }
                                    },
                                  );
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          MediaPickerHelper.buildImageWidget(
                                            photo.imageData,
                                            fit: BoxFit.cover,
                                          ),
                                          Positioned(
                                            top: 6,
                                            left: 6,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: badgeColor.withValues(alpha: 0.85),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                badgeLabel,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 6,
                                            right: 6,
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.5),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.zoom_in,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            AppDateUtils.formatDate(photo.createdAt),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            tooltip: 'Excluir foto',
                                            onPressed: () async {
                                              final confirmed = await showDialog<bool>(
                                                context: context,
                                                builder: (dCtx) => AlertDialog(
                                                  title: const Text('Excluir Foto'),
                                                  content: const Text('Tem certeza de que deseja remover esta foto?'),
                                                  actions: [
                                                    TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancelar')),
                                                    ElevatedButton(
                                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                                      onPressed: () => Navigator.pop(dCtx, true),
                                                      child: const Text('Excluir'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (confirmed == true) {
                                                final mgr = ref.read(personPhotosManagerProvider);
                                                await mgr.deletePhotoById(photo.id);
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
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
