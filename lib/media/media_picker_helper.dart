import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/app_theme.dart';

// Helper Web para seleção de arquivos diretamente via HTML se estiver no navegador
import 'media_web_stub.dart'
    if (dart.library.js_interop) 'media_web_impl.dart';

class MediaPickerHelper {
  /// Abre seletor com opções: Tirar Foto (Câmera), Escolher do Dispositivo ou Colar URL/Base64
  static Future<String?> pickImage(BuildContext context, {String title = 'Selecionar Imagem'}) async {
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final urlController = TextEditingController();

        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.add_a_photo, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 18)),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Escolha como deseja adicionar a foto:',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 16),

                // OPÇÃO 1: CÂMERA (Tirar Foto)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentTeal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.photo_camera, color: AppTheme.accentTeal),
                  ),
                  title: const Text('Tirar Foto com a Câmera', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Abre a câmera do dispositivo móvel ou tablet', style: TextStyle(fontSize: 12)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onTap: () async {
                    final result = await pickImageFromBrowser(useCamera: true);
                    if (result != null && result.isNotEmpty) {
                      if (ctx.mounted) Navigator.pop(ctx, result);
                    } else if (result == null && ctx.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Câmera física disponível no navegador/dispositivo móvel. No desktop, você pode colar o link ou base64 abaixo.')),
                      );
                    }
                  },
                ),
                const Divider(height: 16),

                // OPÇÃO 2: DISPOSITIVO (Galeria / Arquivos)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.photo_library, color: AppTheme.primaryBlue),
                  ),
                  title: const Text('Escolher do Dispositivo / Galeria', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Selecione uma imagem salva no aparelho', style: TextStyle(fontSize: 12)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onTap: () async {
                    final result = await pickImageFromBrowser(useCamera: false);
                    if (result != null && result.isNotEmpty) {
                      if (ctx.mounted) Navigator.pop(ctx, result);
                    } else if (result == null && ctx.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Seletor nativo disponível no navegador/dispositivo móvel. No desktop, você pode colar o link ou base64 abaixo.')),
                      );
                    }
                  },
                ),
                const Divider(height: 16),

                // OPÇÃO 3: COLAR URL OU BASE64 (Funciona em qualquer ambiente / Desktop)
                ExpansionTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.link, color: Colors.purple),
                  ),
                  title: const Text('Colar Link ou Imagem Base64', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Inserir URL da web ou código Base64', style: TextStyle(fontSize: 12)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          TextField(
                            controller: urlController,
                            decoration: const InputDecoration(
                              labelText: 'URL da imagem ou data:image/...',
                              hintText: 'https://exemplo.com/foto.jpg',
                              isDense: true,
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Usar esta Imagem'),
                            onPressed: () {
                              final text = urlController.text.trim();
                              if (text.isNotEmpty) {
                                Navigator.pop(ctx, text);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ],
        );
      },
    );
  }

  /// Visualizador em tela cheia com zoom interativo de alta resolução
  static void showFullScreenImage(
    BuildContext context, {
    required String imageSource,
    String? title,
    VoidCallback? onDelete,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  panEnabled: true,
                  scaleEnabled: true,
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: buildImageWidget(imageSource, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onDelete != null)
                      IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: Colors.red.withValues(alpha: 0.8)),
                        icon: const Icon(Icons.delete, color: Colors.white, size: 20),
                        tooltip: 'Remover Foto',
                        onPressed: () {
                          Navigator.pop(ctx);
                          onDelete();
                        },
                      ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: Colors.black54),
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      tooltip: 'Fechar',
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              if (title != null)
                Positioned(
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Constrói Widget de imagem que suporta base64 data URI, HTTP URL ou asset
  static Widget buildImageWidget(
    String imageSource, {
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
  }) {
    final clean = imageSource.trim();
    if (clean.isEmpty) return _buildPlaceholderIcon();

    if (clean.startsWith('assets/')) {
      return Image.asset(
        clean,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholderIcon(),
      );
    }

    if (clean.startsWith('data:video')) {
      return Container(
        color: Colors.black87,
        width: width,
        height: height,
        child: const Center(
          child: Icon(Icons.videocam, color: Colors.white, size: 28),
        ),
      );
    }

    if (clean.startsWith('data:image')) {
      final commaIndex = clean.indexOf(',');
      final base64String = commaIndex != -1 ? clean.substring(commaIndex + 1) : clean;
      try {
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholderIcon(),
        );
      } catch (_) {
        return _buildPlaceholderIcon();
      }
    } else if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return Image.network(
        clean,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholderIcon(),
      );
    } else {
      // Tenta decodificar como base64 puro somente se não for um caminho com barras/pontos
      if (!clean.contains('/') && !clean.contains('\\') && !clean.contains(':')) {
        try {
          final bytes = base64Decode(clean);
          return Image.memory(
            bytes,
            fit: fit,
            width: width,
            height: height,
            errorBuilder: (context, error, stackTrace) => _buildPlaceholderIcon(),
          );
        } catch (_) {}
      }
      return _buildPlaceholderIcon();
    }
  }

  static Widget buildThumbnail(
    String imageSource, {
    double width = 48,
    double height = 48,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
  }) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(8),
      child: SizedBox(
        width: width,
        height: height,
        child: buildImageWidget(imageSource, fit: fit, width: width, height: height),
      ),
    );
  }

  static Future<String?> pickImageOrCapture(BuildContext context, {String title = 'Selecionar Imagem'}) {
    return pickImage(context, title: title);
  }

  static Widget _buildPlaceholderIcon() {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.broken_image, color: Colors.grey, size: 32),
      ),
    );
  }
}
