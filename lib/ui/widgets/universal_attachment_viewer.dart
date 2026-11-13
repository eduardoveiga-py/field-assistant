import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_logger.dart';
import '../../core/app_theme.dart';

/// Abre o visualizador universal de anexos (PDFs, Imagens, Áudios, Textos e outros formatos).
Future<void> showUniversalAttachmentViewer(
  BuildContext context, {
  required String filePath,
  String? title,
  String? fileType,
  Uint8List? bytes,
}) async {
  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => UniversalAttachmentViewerDialog(
      filePath: filePath,
      title: title,
      fileType: fileType,
      bytes: bytes,
    ),
  );
}

/// Diálogo universal para visualização de qualquer anexo ou documento teocrático.
class UniversalAttachmentViewerDialog extends StatefulWidget {
  final String filePath;
  final String? title;
  final String? fileType;
  final Uint8List? bytes;

  const UniversalAttachmentViewerDialog({
    super.key,
    required this.filePath,
    this.title,
    this.fileType,
    this.bytes,
  });

  @override
  State<UniversalAttachmentViewerDialog> createState() =>
      _UniversalAttachmentViewerDialogState();
}

class _UniversalAttachmentViewerDialogState
    extends State<UniversalAttachmentViewerDialog> {
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _textContent;
  bool _isLoading = true;
  bool _fileNotFound = false;
  String? _errorMessage;
  Uint8List? _pdfBytes;
  Uint8List? _imageBytes;

  String get _effectiveFileType {
    if (widget.fileType != null && widget.fileType!.isNotEmpty) {
      return widget.fileType!.toLowerCase().replaceAll('.', '');
    }
    final path = widget.filePath.toLowerCase();
    final dot = path.lastIndexOf('.');
    if (dot != -1 && dot < path.length - 1) {
      return path.substring(dot + 1);
    }
    return 'unknown';
  }

  bool get _isPdf => _effectiveFileType == 'pdf';

  bool get _isImage =>
      ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(_effectiveFileType);

  bool get _isAudio =>
      ['m4a', 'mp3', 'wav', 'aac', 'ogg', 'opus'].contains(_effectiveFileType);

  bool get _isText => [
        'txt',
        'md',
        'markdown',
        'json',
        'csv',
        'log',
        'xml',
        'html',
        'yaml',
        'yml',
      ].contains(_effectiveFileType);

  @override
  void initState() {
    super.initState();
    _loadFileContent();
  }

  @override
  void dispose() {
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _loadFileContent() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _fileNotFound = false;
    });

    try {
      if (_isPdf) {
        if (widget.bytes != null && widget.bytes!.isNotEmpty) {
          _pdfBytes = widget.bytes;
        } else if (widget.filePath.startsWith('http://') || widget.filePath.startsWith('https://')) {
          final resp = await http.get(Uri.parse(widget.filePath));
          if (resp.statusCode == 200) {
            _pdfBytes = resp.bodyBytes;
          } else {
            _errorMessage = 'Falha ao baixar arquivo remoto (HTTP ${resp.statusCode}).';
          }
        } else if (!kIsWeb) {
          final existing = await _findExistingLocalFile(widget.filePath);
          if (existing != null) {
            _pdfBytes = await existing.readAsBytes();
          } else {
            _fileNotFound = true;
          }
        } else {
          _fileNotFound = true;
        }
      } else if (_isImage) {
        if (widget.bytes != null && widget.bytes!.isNotEmpty) {
          _imageBytes = widget.bytes;
        } else if (!widget.filePath.startsWith('http')) {
          if (!kIsWeb) {
            final existing = await _findExistingLocalFile(widget.filePath);
            if (existing != null) {
              _imageBytes = await existing.readAsBytes();
            } else {
              _fileNotFound = true;
            }
          } else {
            _fileNotFound = true;
          }
        }
      } else if (_isAudio) {
        _audioPlayer = AudioPlayer();
        _audioPlayer!.onPlayerStateChanged.listen((state) {
          if (mounted) {
            setState(() => _isPlaying = state == PlayerState.playing);
          }
        });
        _audioPlayer!.onDurationChanged.listen((d) {
          if (mounted) setState(() => _duration = d);
        });
        _audioPlayer!.onPositionChanged.listen((p) {
          if (mounted) setState(() => _position = p);
        });

        if (!widget.filePath.startsWith('http')) {
          if (!kIsWeb) {
            final existing = await _findExistingLocalFile(widget.filePath);
            if (existing == null) {
              _fileNotFound = true;
            }
          } else {
            _fileNotFound = true;
          }
        }
      } else if (_isText) {
        if (widget.bytes != null) {
          _textContent = String.fromCharCodes(widget.bytes!);
        } else if (widget.filePath.startsWith('http://') || widget.filePath.startsWith('https://')) {
          final resp = await http.get(Uri.parse(widget.filePath));
          if (resp.statusCode == 200) {
            _textContent = resp.body;
          } else {
            _errorMessage = 'Falha ao baixar arquivo de texto (HTTP ${resp.statusCode}).';
          }
        } else if (!kIsWeb) {
          final existingFile = await _findExistingLocalFile(widget.filePath);
          if (existingFile != null) {
            _textContent = await existingFile.readAsString();
          } else {
            _fileNotFound = true;
          }
        } else {
          _fileNotFound = true;
        }
      } else {
        if (widget.bytes == null && !widget.filePath.startsWith('http')) {
          if (!kIsWeb) {
            final existing = await _findExistingLocalFile(widget.filePath);
            if (existing == null) {
              _fileNotFound = true;
            }
          } else {
            _fileNotFound = true;
          }
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<File?> _findExistingLocalFile(String rawPath) async {
    if (kIsWeb || rawPath.trim().isEmpty) return null;

    try {
      final direct = File(rawPath);
      if (await direct.exists()) return direct;
    } catch (e, st) {
      AppLogger.debug('Erro ao verificar caminho direto do anexo ($rawPath): $e', st);
    }

    String decoded = rawPath;
    try {
      decoded = Uri.decodeFull(rawPath);
      final directDecoded = File(decoded);
      if (await directDecoded.exists()) return directDecoded;
    } catch (e, st) {
      AppLogger.debug('Erro ao decodificar/verificar URI do anexo ($rawPath): $e', st);
    }

    final rawName = rawPath.split(RegExp(r'[\\/]')).last;
    final decodedName = decoded.split(RegExp(r'[\\/]')).last;
    final fileNames = {rawName, decodedName}.where((n) => n.trim().isNotEmpty).toList();
    if (fileNames.isEmpty) return null;

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final candidates = <File>[];
      for (final n in fileNames) {
        candidates.add(File('${docDir.path}/documents/$n'));
        candidates.add(File('${docDir.path}/$n'));
      }
      try {
        final supportDir = await getApplicationSupportDirectory();
        for (final n in fileNames) {
          candidates.add(File('${supportDir.path}/documents/$n'));
          candidates.add(File('${supportDir.path}/$n'));
        }
      } catch (e, st) {
        AppLogger.debug('ApplicationSupport indisponível na busca de anexo: $e', st);
      }
      try {
        final tempDir = await getTemporaryDirectory();
        for (final n in fileNames) {
          candidates.add(File('${tempDir.path}/$n'));
          candidates.add(File('${tempDir.path}/file_picker/$n'));
        }
      } catch (e, st) {
        AppLogger.debug('TempDir indisponível na busca de anexo: $e', st);
      }
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          for (final n in fileNames) {
            candidates.add(File('${extDir.path}/$n'));
            candidates.add(File('${extDir.path}/Download/$n'));
            candidates.add(File('${extDir.path}/documents/$n'));
          }
        }
      } catch (e, st) {
        AppLogger.debug('ExternalStorage indisponível na busca de anexo: $e', st);
      }
      try {
        final dlDir = await getDownloadsDirectory();
        if (dlDir != null) {
          for (final n in fileNames) {
            candidates.add(File('${dlDir.path}/$n'));
          }
        }
      } catch (e, st) {
        AppLogger.debug('DownloadsDirectory indisponível na busca de anexo: $e', st);
      }

      for (final f in candidates) {
        if (await f.exists()) {
          return f;
        }
      }
    } catch (e, st) {
      AppLogger.warning('Falha ao varrer diretórios locais para anexo', e, st);
    }

    return null;
  }

  Future<Uint8List> _resolvePdfBytes() async {
    if (_pdfBytes != null && _pdfBytes!.isNotEmpty) {
      return _pdfBytes!;
    }
    if (widget.bytes != null && widget.bytes!.isNotEmpty) {
      return widget.bytes!;
    }
    final existing = await _findExistingLocalFile(widget.filePath);
    if (existing != null) {
      try {
        return await existing.readAsBytes();
      } catch (e, st) {
        AppLogger.warning('Falha ao ler bytes do PDF local (${existing.path})', e, st);
      }
    }

    // Fallback caso caminho comece com http
    if (widget.filePath.startsWith('http://') || widget.filePath.startsWith('https://')) {
      final resp = await http.get(Uri.parse(widget.filePath));
      if (resp.statusCode == 200) {
        return resp.bodyBytes;
      }
    }

    throw FileSystemException(
      'Arquivo físico do anexo não encontrado no armazenamento local. Verifique se o arquivo foi baixado ou sincronize novamente.',
      widget.filePath,
    );
  }

  Future<void> _openExternal() async {
    try {
      if (_fileNotFound) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Arquivo físico do anexo não encontrado no armazenamento local. Verifique se o arquivo foi baixado ou sincronize novamente.',
              ),
            ),
          );
        }
        return;
      }

      if (kIsWeb) {
        if (_isPdf) {
          final pdfBytes = await _resolvePdfBytes();
          await Printing.layoutPdf(
            onLayout: (format) async => pdfBytes,
            name: widget.title != null ? '${widget.title}.pdf' : 'documento.pdf',
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No navegador, utilize o botão de visualização ou impressão para acessar o arquivo.',
            ),
          ),
        );
        return;
      }

      if (widget.filePath.startsWith('http://') || widget.filePath.startsWith('https://')) {
        await launchUrl(Uri.parse(widget.filePath), mode: LaunchMode.externalApplication);
        return;
      }

      String targetPath = widget.filePath;
      final existing = await _findExistingLocalFile(widget.filePath);
      if (existing != null) {
        targetPath = existing.path;
      } else {
        Uint8List? availableBytes = widget.bytes;
        if (availableBytes == null || availableBytes.isEmpty) {
          if (_pdfBytes != null && _pdfBytes!.isNotEmpty) {
            availableBytes = _pdfBytes;
          }
        }

        if (availableBytes != null && availableBytes.isNotEmpty) {
          try {
            final tempDir = await getTemporaryDirectory();
            final rawName = widget.filePath.split(RegExp(r'[\\/]')).last;
            final safeName = rawName.isNotEmpty
                ? rawName
                : '${widget.title ?? "document"}.${_isPdf ? "pdf" : "bin"}';
            final tempFile = File('${tempDir.path}/$safeName');
            await tempFile.writeAsBytes(availableBytes, flush: true);
            targetPath = tempFile.path;
          } catch (e, st) {
            AppLogger.warning('Falha ao gravar arquivo temporário para abrir externamente (${widget.filePath})', e, st);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Arquivo físico do anexo não encontrado no armazenamento local. Verifique se o arquivo foi baixado ou sincronize novamente.',
                ),
              ),
            );
          }
          return;
        }
      }

      final res = await OpenFilex.open(targetPath);
      if (res.type != ResultType.done) {
        final uri = Uri.file(targetPath);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
        if (mounted) {
          final msg = res.message.isNotEmpty
              ? res.message
              : 'Nenhum leitor compatível encontrado para este formato.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Aplicativo externo: $msg')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir externamente: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayName = widget.title ?? widget.filePath.split(RegExp(r'[\\/]')).last;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 800,
          height: 650,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho da Janela de Leitura
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                child: Row(
                  children: [
                    _buildTypeIcon(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Formato: ${_effectiveFileType.toUpperCase()} • ${widget.filePath}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.open_in_new, size: 20),
                      tooltip: 'Abrir no app padrão do sistema',
                      onPressed: _openExternal,
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      tooltip: 'Copiar caminho',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: widget.filePath));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Caminho copiado!')),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Fechar',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Corpo do Visualizador
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildViewerBody(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeIcon() {
    if (_isPdf) {
      return const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 24);
    }
    if (_isImage) {
      return const Icon(Icons.image, color: Colors.blueAccent, size: 24);
    }
    if (_isAudio) {
      return const Icon(Icons.audiotrack, color: Colors.amber, size: 24);
    }
    if (_isText) {
      return const Icon(Icons.article_outlined, color: Colors.teal, size: 24);
    }
    return const Icon(Icons.insert_drive_file_outlined, color: Colors.grey, size: 24);
  }

  Widget _buildViewerBody(bool isDark) {
    if (_fileNotFound) {
      return _buildFileNotFoundView(isDark);
    }

    final displayName = widget.title ?? widget.filePath.split(RegExp(r'[\\/]')).last;

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                'Falha ao carregar arquivo:\n$_errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Recarregar'),
                onPressed: _loadFileContent,
              ),
            ],
          ),
        ),
      );
    }

    if (_isPdf) {
      return PdfPreview(
        build: (format) => _resolvePdfBytes(),
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        actions: [
          PdfPreviewAction(
            icon: const Icon(Icons.open_in_new),
            onPressed: (ctx, fn, format) => _openExternal(),
          ),
        ],
        onError: (context, error) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.broken_image_outlined, size: 48, color: Colors.redAccent),
                  const SizedBox(height: 12),
                  Text(
                    'Não foi possível renderizar a prévia do PDF.\nErro: $error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Recarregar'),
                    onPressed: _loadFileContent,
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    if (_isImage) {
      return Container(
        color: isDark ? Colors.black26 : const Color(0xFFF8FAFC),
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: widget.bytes != null
                ? Image.memory(widget.bytes!, fit: BoxFit.contain)
                : widget.filePath.startsWith('http')
                    ? Image.network(widget.filePath, fit: BoxFit.contain)
                    : _imageBytes != null
                        ? Image.memory(_imageBytes!, fit: BoxFit.contain)
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.broken_image, size: 64, color: Colors.grey),
                              const SizedBox(height: 8),
                              Text('Arquivo de imagem não encontrado: ${widget.filePath}'),
                            ],
                          ),
          ),
        ),
      );
    }

    if (_isAudio) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.music_note_rounded, size: 56, color: Colors.amber),
              ),
              const SizedBox(height: 24),
              Text(
                widget.title ?? widget.filePath.split(RegExp(r'[\\/]')).last,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Slider(
                value: _position.inSeconds.toDouble().clamp(
                      0.0,
                      _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
                    ),
                max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
                onChanged: (val) {
                  _audioPlayer?.seek(Duration(seconds: val.toInt()));
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(_position), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(_formatDuration(_duration), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              IconButton.filled(
                iconSize: 42,
                icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                onPressed: () async {
                  if (_audioPlayer == null) return;
                  if (_isPlaying) {
                    await _audioPlayer!.pause();
                  } else {
                    if (widget.filePath.startsWith('http')) {
                      await _audioPlayer!.play(UrlSource(widget.filePath));
                    } else {
                      await _audioPlayer!.play(DeviceFileSource(widget.filePath));
                    }
                  }
                },
              ),
            ],
          ),
        ),
      );
    }

    if (_isText) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: SelectableText(
            _textContent ?? '',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5),
          ),
        ),
      );
    }

    // Outros formatos (Word, Excel, Zip, etc.)
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.file_present_rounded, size: 64, color: AppTheme.primaryBlue),
            const SizedBox(height: 16),
            Text(
              displayName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Este tipo de arquivo (${_effectiveFileType.toUpperCase()}) pode ser aberto no seu aplicativo favorito.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Abrir com Aplicativo do Sistema'),
              onPressed: _openExternal,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileNotFoundView(bool isDark) {
    final displayName = widget.title ?? widget.filePath.split(RegExp(r'[\\/]')).last;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.file_copy_outlined,
                size: 52,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              displayName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Arquivo físico do anexo não encontrado no armazenamento local. Verifique se o arquivo foi baixado ou sincronize novamente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                    ),
                  ),
                  if (widget.filePath.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Caminho: ${widget.filePath}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Voltar'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Recarregar'),
                  onPressed: _loadFileContent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
