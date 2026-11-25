import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';

/// Diálogo para desenhar assinatura manuscrita no canvas (dedo, caneta ou mouse)
/// ou importar uma imagem PNG transparente para compor os rodapés oficiais.
class SignaturePadDialog extends StatefulWidget {
  final String elderName;
  final String? initialPngBase64;

  const SignaturePadDialog({
    super.key,
    required this.elderName,
    this.initialPngBase64,
  });

  /// Retorna `""` para limpar a assinatura desenhada, base64 PNG quando confirmada,
  /// ou `null` caso cancelado.
  static Future<String?> show(
    BuildContext context, {
    required String elderName,
    String? initialPngBase64,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => SignaturePadDialog(
        elderName: elderName,
        initialPngBase64: initialPngBase64,
      ),
    );
  }

  @override
  State<SignaturePadDialog> createState() => _SignaturePadDialogState();
}

class _SignaturePadDialogState extends State<SignaturePadDialog> {
  final List<List<Offset>> _strokes = [];
  List<Offset>? _currentStroke;
  double _strokeWidth = 2.6;
  Color _inkColor = const Color(0xFF0F172A);
  String? _importedPngBase64;
  String? _errorText;
  bool _saving = false;

  static const Size _canvasLogicalSize = Size(480, 150);

  @override
  void initState() {
    super.initState();
    final init = widget.initialPngBase64?.trim();
    if (init != null && init.isNotEmpty) {
      _importedPngBase64 = init;
    }
  }

  bool get _hasContent =>
      _strokes.isNotEmpty ||
      (_importedPngBase64 != null && _importedPngBase64!.isNotEmpty);

  void _clear() {
    setState(() {
      _strokes.clear();
      _currentStroke = null;
      _importedPngBase64 = null;
      _errorText = null;
    });
  }

  Future<void> _pickPng() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['png'],
      );
      if (files.isEmpty) return;
      final bytes = await files.first.readAsBytes();
      if (bytes.length < 8 ||
          bytes[0] != 0x89 ||
          bytes[1] != 0x50 ||
          bytes[2] != 0x4E ||
          bytes[3] != 0x47) {
        if (!mounted) return;
        setState(() {
          _errorText = 'Selecione um arquivo PNG válido (preferencialmente com fundo transparente).';
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _strokes.clear();
        _importedPngBase64 = base64Encode(bytes);
        _errorText = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Não foi possível carregar o PNG: $e';
      });
    }
  }

  Future<void> _confirmAndExport() async {
    if (_saving) return;
    if (_strokes.isEmpty) {
      Navigator.pop(context, _importedPngBase64 ?? '');
      return;
    }

    setState(() => _saving = true);
    try {
      const double scale = 2.0;
      final width = (_canvasLogicalSize.width * scale).round();
      final height = (_canvasLogicalSize.height * scale).round();

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(
        recorder,
        ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      );
      canvas.scale(scale, scale);

      final paint = Paint()
        ..color = _inkColor
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      for (final stroke in _strokes) {
        if (stroke.isEmpty) continue;
        if (stroke.length == 1) {
          canvas.drawCircle(
            stroke.first,
            _strokeWidth / 2,
            paint..style = PaintingStyle.fill,
          );
          paint.style = PaintingStyle.stroke;
          continue;
        }
        final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
        for (var i = 1; i < stroke.length; i++) {
          final prev = stroke[i - 1];
          final curr = stroke[i];
          final mid = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
          path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
        }
        path.lineTo(stroke.last.dx, stroke.last.dy);
        canvas.drawPath(path, paint);
      }

      final picture = recorder.endRecording();
      final image = await picture.toImage(width, height);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      if (byteData == null) {
        throw StateError('Falha ao codificar imagem PNG da assinatura.');
      }
      final Uint8List pngBytes = byteData.buffer.asUint8List();
      if (!mounted) return;
      Navigator.pop(context, base64Encode(pngBytes));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorText = 'Erro ao salvar assinatura: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Uint8List? previewBytes;
    if (_importedPngBase64 != null &&
        _importedPngBase64!.isNotEmpty &&
        _strokes.isEmpty) {
      try {
        previewBytes = base64Decode(_importedPngBase64!);
      } catch (_) {}
    }

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.draw_outlined, color: AppTheme.primaryBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Assinatura Manuscrita (PNG)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.elderName,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Desenhe sua assinatura na área branca abaixo ou importe um PNG com fundo transparente. Quando vazia, o app usa a fonte cursiva escolhida.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Tinta:', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 8),
                  for (final col in const [
                    Color(0xFF0F172A),
                    Color(0xFF1E3A8A),
                    Color(0xFF1F2937),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () => setState(() => _inkColor = col),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: col,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _inkColor == col
                                  ? AppTheme.primaryBlue
                                  : Colors.grey.shade400,
                              width: _inkColor == col ? 2.5 : 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  const Spacer(),
                  const Text('Traço:', style: TextStyle(fontSize: 12)),
                  SizedBox(
                    width: 110,
                    child: Slider(
                      value: _strokeWidth,
                      min: 1.5,
                      max: 4.5,
                      onChanged: (v) => setState(() => _strokeWidth = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: _canvasLogicalSize.width,
                  height: _canvasLogicalSize.height,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      // Linha-guia sutil para assinatura
                      Positioned(
                        left: 28,
                        right: 28,
                        bottom: 34,
                        child: Container(
                          height: 1,
                          color: const Color(0xFFE2E8F0),
                        ),
                      ),
                      if (previewBytes != null)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Image.memory(
                              previewBytes,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      if (!_hasContent)
                        const Center(
                          child: Text(
                            'Assine aqui com dedo, mouse ou caneta',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      LayoutBuilder(
                        builder: (ctx, constraints) {
                          Offset clampOffset(Offset local) => Offset(
                            local.dx.clamp(0.0, _canvasLogicalSize.width),
                            local.dy.clamp(0.0, _canvasLogicalSize.height),
                          );
                          return GestureDetector(
                            onPanStart: (details) {
                              setState(() {
                                _importedPngBase64 = null;
                                _errorText = null;
                                final pt = clampOffset(details.localPosition);
                                _currentStroke = [pt];
                                _strokes.add(_currentStroke!);
                              });
                            },
                            onPanUpdate: (details) {
                              if (_currentStroke == null) return;
                              setState(() {
                                _currentStroke!.add(
                                  clampOffset(details.localPosition),
                                );
                              });
                            },
                            onPanEnd: (_) {
                              _currentStroke = null;
                            },
                            child: CustomPaint(
                              size: _canvasLogicalSize,
                              painter: _SignatureStrokePainter(
                                strokes: _strokes,
                                color: _inkColor,
                                strokeWidth: _strokeWidth,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorText!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _pickPng,
                    icon: const Icon(Icons.upload_file, size: 16),
                    label: const Text('Importar PNG'),
                  ),
                  TextButton.icon(
                    onPressed: _saving || !_hasContent ? null : _clear,
                    icon: const Icon(
                      Icons.cleaning_services_outlined,
                      size: 16,
                    ),
                    label: const Text('Limpar / Usar Cursiva'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _confirmAndExport,
          icon: _saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check, size: 16),
          label: Text(_hasContent ? 'Salvar Assinatura' : 'Remover Desenho'),
        ),
      ],
    );
  }
}

class _SignatureStrokePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color color;
  final double strokeWidth;

  const _SignatureStrokePainter({
    required this.strokes,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        canvas.drawCircle(
          stroke.first,
          strokeWidth / 2,
          paint..style = PaintingStyle.fill,
        );
        paint.style = PaintingStyle.stroke;
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length; i++) {
        final prev = stroke[i - 1];
        final curr = stroke[i];
        final mid = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
        path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
      }
      path.lineTo(stroke.last.dx, stroke.last.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignatureStrokePainter oldDelegate) => true;
}
