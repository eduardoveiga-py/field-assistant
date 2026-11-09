import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/app_theme.dart';
import '../../voice_notes/audio_recording_service.dart';
import '../providers.dart';
import 'adaptive_ministry_sheet.dart';
import 'rich_markdown_toolbar.dart';

/// Modal adaptativo de captura rápida do Módulo A — Inbox Universal.
/// Permite capturar pensamentos, ditados de áudio (até 5 min) e documentos/fotos
/// sem atrito e sem exigir classificação imediata.
class QuickCaptureSheet extends ConsumerStatefulWidget {
  const QuickCaptureSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showAdaptiveMinistrySheet(
      context: context,
      title: 'Captura Rápida • Inbox',
      titleLeading: const Icon(Icons.all_inbox_rounded, color: AppTheme.primaryBlue, size: 22),
      subtitle: 'Guarde ideias, tarefas, áudios ou documentos para organizar depois.',
      builder: (ctx, scrollCtrl) => const QuickCaptureSheet(),
    );
  }

  @override
  ConsumerState<QuickCaptureSheet> createState() => _QuickCaptureSheetState();
}

class _QuickCaptureSheetState extends ConsumerState<QuickCaptureSheet> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String _selectedCategory = 'ministry';
  bool _isSaving = false;

  // Estados de Gravação de Áudio
  late final AudioRecordingService _recordingService;
  late final AudioPlayerService _playerService;
  bool _isRecording = false;
  int _recordDurationSeconds = 0;
  String? _recordedAudioPath;
  StreamSubscription<int>? _durationSub;
  StreamSubscription<bool>? _playerStateSub;
  bool _isPlayingAudio = false;

  // Estados de Anexo
  String? _attachedFilePath;
  String? _attachedFileName;
  int? _attachedFileSize;
  String? _attachedFileType;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _recordingService = kIsWeb ? LocalAudioRecordingService() : RealAudioRecordingService();
    _playerService = kIsWeb ? LocalAudioPlayerService() : RealAudioPlayerService();

    _durationSub = _recordingService.recordingDurationStream.listen((sec) {
      if (mounted) {
        setState(() => _recordDurationSeconds = sec);
      }
    });

    _playerStateSub = _playerService.playingStateStream.listen((isPlaying) {
      if (mounted) {
        setState(() => _isPlayingAudio = isPlaying);
      }
    });
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _playerStateSub?.cancel();
    _tabController.dispose();
    _textController.dispose();
    _noteController.dispose();
    _recordingService.dispose();
    _playerService.dispose();
    super.dispose();
  }

  // ==========================================
  // GRAVAÇÃO DE ÁUDIO (LIMITE: 300s / 5min)
  // ==========================================

  Future<void> _toggleAudioRecording() async {
    if (_isRecording) {
      final res = await _recordingService.stopRecording();
      if (mounted) {
        setState(() {
          _isRecording = false;
          if (res != null) {
            _recordedAudioPath = res.filePath;
            _recordDurationSeconds = res.durationSeconds;
          }
        });
      }
    } else {
      final hasPerm = await _recordingService.hasPermission();
      if (!hasPerm) {
        final granted = await _recordingService.requestPermission();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Permissão de microfone necessária para gravar áudio.')),
            );
          }
          return;
        }
      }

      await _recordingService.startRecording(maxDurationSeconds: 300);
      if (mounted) {
        setState(() {
          _isRecording = true;
          _recordedAudioPath = null;
          _recordDurationSeconds = 0;
        });
      }
    }
  }

  Future<void> _toggleAudioPlayback() async {
    if (_recordedAudioPath == null) return;
    if (_isPlayingAudio) {
      await _playerService.pause();
    } else {
      await _playerService.play(_recordedAudioPath!);
    }
  }

  // ==========================================
  // SELEÇÃO DE ANEXOS
  // ==========================================

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'epub'],
      );
      if (result.isNotEmpty) {
        final f = result.first;
        String finalPath = f.path ?? f.name;
        int fileSize = f.lengthSync() ?? (await f.length()) ?? 0;

        if (!kIsWeb) {
          try {
            final appDir = await getApplicationDocumentsDirectory();
            final docsFolder = Directory('${appDir.path}/documents');
            if (!docsFolder.existsSync()) {
              await docsFolder.create(recursive: true);
            }
            final targetFile = File('${docsFolder.path}/${f.name}');
            Uint8List? bytes;
            try {
              bytes = await f.readAsBytes();
            } catch (_) {}
            if ((bytes == null || bytes.isEmpty) && f.path != null && f.path!.isNotEmpty) {
              final sf = File(f.path!);
              if (await sf.exists()) {
                try {
                  bytes = await sf.readAsBytes();
                } catch (_) {}
              }
            }
            if (bytes != null && bytes.isNotEmpty) {
              await targetFile.writeAsBytes(bytes, flush: true);
              finalPath = targetFile.path;
              fileSize = bytes.length;
            } else if (f.path != null && f.path!.isNotEmpty) {
              final sf = File(f.path!);
              if (await sf.exists()) {
                await sf.copy(targetFile.path);
                finalPath = targetFile.path;
                fileSize = await targetFile.length();
              }
            }
          } catch (e) {
            debugPrint('Erro ao persistir documento no quick capture: $e');
          }
        }

        setState(() {
          _attachedFilePath = finalPath;
          _attachedFileName = f.name;
          _attachedFileSize = fileSize;
          _attachedFileType = 'file';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível anexar o arquivo: $e')),
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 85);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        String finalPath = picked.path;

        if (!kIsWeb) {
          try {
            final appDir = await getApplicationDocumentsDirectory();
            final imgFolder = Directory('${appDir.path}/documents');
            if (!imgFolder.existsSync()) {
              await imgFolder.create(recursive: true);
            }
            final targetFile = File('${imgFolder.path}/${picked.name}');
            await targetFile.writeAsBytes(bytes, flush: true);
            finalPath = targetFile.path;
          } catch (_) {}
        }

        setState(() {
          _attachedFilePath = finalPath;
          _attachedFileName = picked.name;
          _attachedFileSize = bytes.length;
          _attachedFileType = 'image';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível anexar a foto: $e')),
        );
      }
    }
  }

  // ==========================================
  // SALVAR NA INBOX
  // ==========================================

  Future<void> _saveToInbox() async {
    final inboxMgr = ref.read(inboxManagerProvider);
    final tabIndex = _tabController.index;

    setState(() => _isSaving = true);

    try {
      if (tabIndex == 0) {
        // Texto
        final text = _textController.text.trim();
        if (text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Digite algo para salvar na Inbox.')),
          );
          setState(() => _isSaving = false);
          return;
        }
        await inboxMgr.captureText(
          content: text,
          suggestedCategory: _selectedCategory,
        );
      } else if (tabIndex == 1) {
        // Áudio
        if (_recordedAudioPath == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Grave um áudio antes de salvar.')),
          );
          setState(() => _isSaving = false);
          return;
        }
        final note = _noteController.text.trim();
        await inboxMgr.captureAudio(
          content: note.isEmpty ? 'Nota de voz gravada' : note,
          audioPath: _recordedAudioPath!,
          durationSeconds: _recordDurationSeconds,
          suggestedCategory: _selectedCategory,
        );
      } else {
        // Anexo
        if (_attachedFilePath == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selecione um arquivo ou imagem antes de salvar.')),
          );
          setState(() => _isSaving = false);
          return;
        }
        final note = _noteController.text.trim();
        await inboxMgr.captureAttachment(
          content: note.isEmpty ? 'Arquivo: $_attachedFileName' : note,
          filePath: _attachedFilePath!,
          fileName: _attachedFileName ?? 'documento',
          fileType: _attachedFileType ?? 'file',
          suggestedCategory: _selectedCategory,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                SizedBox(width: 8),
                Text('Salvo na Inbox com sucesso!'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar na Inbox: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Seletor de Tipo de Captura
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: AppTheme.primaryBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.edit_note, size: 18), text: 'Ideia / Texto'),
                Tab(icon: Icon(Icons.mic, size: 18), text: 'Voz / Ditado'),
                Tab(icon: Icon(Icons.attach_file, size: 18), text: 'Anexo / Foto'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Categorias Sugeridas
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryChip('ministry', 'Ministério', Icons.menu_book),
                const SizedBox(width: 8),
                _buildCategoryChip('personal', 'Pessoal', Icons.person),
                const SizedBox(width: 8),
                _buildCategoryChip('study', 'Estudo', Icons.school),
                const SizedBox(width: 8),
                _buildCategoryChip('question', 'Dúvida', Icons.help_outline),
                const SizedBox(width: 8),
                _buildCategoryChip('idea', 'Ideia', Icons.lightbulb_outline),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Conteúdo Dinâmico por Aba
          SizedBox(
            height: 210,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTextTab(isDark),
                _buildAudioTab(isDark),
                _buildAttachmentTab(isDark),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Botão Salvar
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveToInbox,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_alt_rounded, size: 20),
            label: Text(
              _isSaving ? 'Salvando...' : 'Salvar na Inbox',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String key, String label, IconData icon) {
    final isSelected = _selectedCategory == key;
    return ChoiceChip(
      avatar: Icon(icon, size: 14, color: isSelected ? Colors.white : AppTheme.primaryBlue),
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _selectedCategory = key);
      },
      selectedColor: AppTheme.primaryBlue,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : null,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildTextTab(bool isDark) {
    return Column(
      children: [
        RichMarkdownToolbar(controller: _textController),
        const SizedBox(height: 6),
        Expanded(
          child: TextField(
            controller: _textController,
            autofocus: true,
            maxLines: null,
            expands: true,
            decoration: InputDecoration(
              hintText: 'O que você está pensando ou precisa registrar sem perder o foco?...',
              hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), fontSize: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAudioTab(bool isDark) {
    final mins = (_recordDurationSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_recordDurationSeconds % 60).toString().padLeft(2, '0');

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_recordedAudioPath == null) ...[
          // Gravando ou pronto para gravar
          Text(
            _isRecording ? 'Gravando: $mins:$secs (máx: 05:00)' : 'Toque no microfone para gravar uma nota rápida',
            style: TextStyle(
              fontSize: 13,
              color: _isRecording ? Colors.redAccent : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              fontWeight: _isRecording ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _toggleAudioRecording,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: _isRecording ? 72 : 64,
              height: _isRecording ? 72 : 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording ? Colors.redAccent : AppTheme.primaryBlue,
                boxShadow: [
                  BoxShadow(
                    color: (_isRecording ? Colors.redAccent : AppTheme.primaryBlue).withValues(alpha: 0.35),
                    blurRadius: 16,
                    spreadRadius: _isRecording ? 4 : 2,
                  ),
                ],
              ),
              child: Icon(
                _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ] else ...[
          // Áudio gravado com sucesso
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _toggleAudioPlayback,
                  icon: Icon(
                    _isPlayingAudio ? Icons.pause_circle_filled : Icons.play_circle_fill,
                    color: AppTheme.primaryBlue,
                    size: 36,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Áudio Gravado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('Duração: $mins:$secs', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _recordedAudioPath = null;
                      _recordDurationSeconds = 0;
                    });
                  },
                  tooltip: 'Regravar',
                  icon: const Icon(Icons.refresh_rounded, color: Colors.redAccent, size: 22),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _noteController,
            decoration: InputDecoration(
              hintText: 'Título ou anotação complementar do áudio...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAttachmentTab(bool isDark) {
    if (_attachedFilePath != null) {
      final sizeKb = ((_attachedFileSize ?? 0) / 1024).toStringAsFixed(1);
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Icon(
                  _attachedFileType == 'image' ? Icons.image_rounded : Icons.description_rounded,
                  color: AppTheme.primaryBlue,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _attachedFileName ?? 'Arquivo',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text('$sizeKb KB', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _attachedFilePath = null;
                      _attachedFileName = null;
                      _attachedFileSize = null;
                    });
                  },
                  tooltip: 'Remover',
                  icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 20),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _noteController,
            decoration: InputDecoration(
              hintText: 'Anotação sobre este anexo...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      );
    }

    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: _pickDocument,
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Documento'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: () => _pickImage(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_rounded),
            label: const Text('Galeria / Foto'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
