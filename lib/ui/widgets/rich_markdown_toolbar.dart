import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_theme.dart';

/// Barra de ferramentas de formatação rica e Markdown ágil.
/// Permite aplicar Negrito, Itálico, Títulos, Listas, Citações,
/// Textos Bíblicos e Cores em qualquer [TextEditingController].
class RichMarkdownToolbar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onChanged;

  const RichMarkdownToolbar({
    super.key,
    required this.controller,
    this.onChanged,
  });

  void _wrapSelection({
    required String prefix,
    required String suffix,
    String defaultText = '',
  }) {
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
      final newCursorPos = start + prefix.length + selectedText.length + suffix.length;
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursorPos),
      );
    }
    onChanged?.call();
  }

  void _insertAtLineStart(String linePrefix) {
    final text = controller.text;
    final selection = controller.selection;
    final rawCursor = selection.isValid ? selection.baseOffset : text.length;
    final cursor = rawCursor.clamp(0, text.length);

    // Acha o início da linha atual
    final lastNewline = text.lastIndexOf('\n', cursor > 0 ? cursor - 1 : 0);
    final lineStart = lastNewline == -1 ? 0 : (lastNewline + 1).clamp(0, text.length);

    final newText = text.replaceRange(lineStart, lineStart, linePrefix);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor + linePrefix.length),
    );
    onChanged?.call();
  }

  void _showColorPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cor do Destaque',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  _colorOption(
                    label: 'Amarelo',
                    color: Colors.amber,
                    onTap: () {
                      Navigator.pop(ctx);
                      _wrapSelection(prefix: '<mark style="background:#fef08a">', suffix: '</mark>', defaultText: 'destaque');
                    },
                  ),
                  _colorOption(
                    label: 'Azul',
                    color: Colors.lightBlue,
                    onTap: () {
                      Navigator.pop(ctx);
                      _wrapSelection(prefix: '<mark style="background:#bae6fd">', suffix: '</mark>', defaultText: 'destaque');
                    },
                  ),
                  _colorOption(
                    label: 'Verde',
                    color: Colors.lightGreen,
                    onTap: () {
                      Navigator.pop(ctx);
                      _wrapSelection(prefix: '<mark style="background:#bbf7d0">', suffix: '</mark>', defaultText: 'destaque');
                    },
                  ),
                  _colorOption(
                    label: 'Rosa / Roxo',
                    color: Colors.purpleAccent,
                    onTap: () {
                      Navigator.pop(ctx);
                      _wrapSelection(prefix: '<mark style="background:#fbcfe8">', suffix: '</mark>', defaultText: 'destaque');
                    },
                  ),
                  _colorOption(
                    label: 'Laranja',
                    color: Colors.orangeAccent,
                    onTap: () {
                      Navigator.pop(ctx);
                      _wrapSelection(prefix: '<mark style="background:#fed7aa">', suffix: '</mark>', defaultText: 'destaque');
                    },
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
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _toolbarButton(
              icon: Icons.format_bold,
              tooltip: 'Negrito (**texto**)',
              onTap: () => _wrapSelection(prefix: '**', suffix: '**', defaultText: 'texto'),
            ),
            _toolbarButton(
              icon: Icons.format_italic,
              tooltip: 'Itálico (*texto*)',
              onTap: () => _wrapSelection(prefix: '*', suffix: '*', defaultText: 'texto'),
            ),
            _toolbarButton(
              icon: Icons.title,
              tooltip: 'Título Grande (### Título)',
              onTap: () => _insertAtLineStart('### '),
            ),
            _toolbarButton(
              icon: Icons.text_fields,
              tooltip: 'Subtítulo (#### Subtítulo)',
              onTap: () => _insertAtLineStart('#### '),
            ),
            const VerticalDivider(width: 16, indent: 8, endIndent: 8),
            _toolbarButton(
              icon: Icons.format_list_bulleted,
              tooltip: 'Lista de Marcadores (- Item)',
              onTap: () => _insertAtLineStart('- '),
            ),
            _toolbarButton(
              icon: Icons.check_box_outlined,
              tooltip: 'Checklist / Tarefa (- [ ] Tarefa)',
              onTap: () => _insertAtLineStart('- [ ] '),
            ),
            _toolbarButton(
              icon: Icons.format_quote,
              tooltip: 'Citação (> citação)',
              onTap: () => _insertAtLineStart('> '),
            ),
            const VerticalDivider(width: 16, indent: 8, endIndent: 8),
            _toolbarButton(
              icon: Icons.menu_book_outlined,
              tooltip: 'Texto Bíblico (📖 Romanos 12:12)',
              onTap: () => _wrapSelection(prefix: '📖 ', suffix: '', defaultText: 'Texto bíblico'),
            ),
            _toolbarButton(
              icon: Icons.palette_outlined,
              tooltip: 'Cor de Destaque',
              onTap: () => _showColorPicker(context),
            ),
            const VerticalDivider(width: 16, indent: 8, endIndent: 8),
            _toolbarButton(
              icon: Icons.add_photo_alternate_outlined,
              tooltip: 'Inserir Imagem (![legenda](caminho))',
              onTap: () => _showImagePickerDialog(context),
            ),
            _toolbarButton(
              icon: Icons.link_rounded,
              tooltip: 'Inserir Link de Publicação / Vídeo ([📖 Título](url))',
              onTap: () => _showLinkPickerDialog(context),
            ),
            _toolbarButton(
              icon: Icons.code,
              tooltip: 'Código / Bloco (`texto`)',
              onTap: () => _wrapSelection(prefix: '`', suffix: '`', defaultText: 'código'),
            ),
          ],
        ),
      ),
    );
  }

  void _showImagePickerDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.add_photo_alternate, color: AppTheme.primaryBlue),
                    SizedBox(width: 8),
                    Text(
                      'Inserir Imagem no Texto',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppTheme.primaryBlue),
                title: const Text('Escolher da Galeria'),
                subtitle: const Text('Selecionar foto salva no dispositivo'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final picker = ImagePicker();
                    final photo = await picker.pickImage(source: ImageSource.gallery);
                    if (photo != null) {
                      _wrapSelection(
                        prefix: '![foto](${photo.path})',
                        suffix: '',
                      );
                    }
                  } catch (e) {
                    debugPrint('Erro ao selecionar foto: $e');
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.accentTeal),
                title: const Text('Tirar com a Câmera'),
                subtitle: const Text('Fotografar anotação, publicação ou lugar'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final picker = ImagePicker();
                    final photo = await picker.pickImage(source: ImageSource.camera);
                    if (photo != null) {
                      _wrapSelection(
                        prefix: '![foto](${photo.path})',
                        suffix: '',
                      );
                    }
                  } catch (e) {
                    debugPrint('Erro ao capturar foto: $e');
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.link, color: Colors.purple),
                title: const Text('Inserir Link / URL de Imagem'),
                subtitle: const Text('Usar endereço web (https://...) ou caminho local'),
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
    final captionCtrl = TextEditingController();
    final urlCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
                final caption = captionCtrl.text.trim().isEmpty ? 'imagem' : captionCtrl.text.trim();
                _wrapSelection(prefix: '![$caption]($path)', suffix: '');
              }
              Navigator.pop(ctx);
            },
            child: const Text('Inserir'),
          ),
        ],
      ),
    );
  }

  void _showLinkPickerDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.bookmark_added_outlined, color: AppTheme.primaryBlue),
                    SizedBox(width: 8),
                    Text(
                      'Inserir Link ou Publicação',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF4338CA),
                  child: Icon(Icons.menu_book, color: Colors.white, size: 20),
                ),
                title: const Text('Publicação do JW.org'),
                subtitle: const Text('Livro, brochura, revista ou artigo teocrático'),
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
                  child: Icon(Icons.play_circle_fill, color: Colors.white, size: 20),
                ),
                title: const Text('Vídeo do JW.org / Broadcasting'),
                subtitle: const Text('Vídeo de lição, animação bíblica ou música'),
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
    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${defaultPrefix.isNotEmpty ? defaultPrefix : "🔗 "}Inserir Link'),
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
                final title = titleCtrl.text.trim().isEmpty ? 'Link' : titleCtrl.text.trim();
                _wrapSelection(prefix: '[$defaultPrefix$title]($url)', suffix: '');
              }
              Navigator.pop(ctx);
            },
            child: const Text('Inserir Link'),
          ),
        ],
      ),
    );
  }

  Widget _toolbarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
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
