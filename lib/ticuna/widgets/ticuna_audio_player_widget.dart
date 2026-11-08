import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ticuna_audio_service.dart';
import '../ticuna_providers.dart';
import '../ticuna_unicode_helper.dart';

/// Componente para gravação e reprodução de áudio de pronúncia Ticuna.
/// Suporta reprodução, ajuste de velocidade (0.5x, 0.75x, 1.0x, 1.25x),
/// exclusão de áudio para regravar e gravação leve em formato AAC mono (~32kbps).
class TicunaAudioPlayerWidget extends ConsumerStatefulWidget {
  final String id;
  final String title;
  final String? audioPath;
  final int? audioDurationSeconds;
  final bool isPhrase;
  final bool compact;
  final void Function(String? newPath, int? durationSeconds)? onAudioUpdated;

  const TicunaAudioPlayerWidget({
    super.key,
    required this.id,
    required this.title,
    this.audioPath,
    this.audioDurationSeconds,
    this.isPhrase = false,
    this.compact = false,
    this.onAudioUpdated,
  });

  @override
  ConsumerState<TicunaAudioPlayerWidget> createState() =>
      _TicunaAudioPlayerWidgetState();
}

class _TicunaAudioPlayerWidgetState
    extends ConsumerState<TicunaAudioPlayerWidget> {
  static const List<double> availableSpeeds = [0.5, 0.75, 1.0, 1.25];

  bool _isPlayingThis = false;
  double _currentSpeed = 1.0;
  StreamSubscription<bool>? _playingSub;

  @override
  void initState() {
    super.initState();
    final audioService = ref.read(ticunaAudioServiceProvider);
    _currentSpeed = audioService.currentPlaybackSpeed;
    _playingSub = audioService.playerPlayingStream.listen((playing) {
      if (!mounted) return;
      final currentPath = audioService.currentPlayingPath;
      final isThis = playing && currentPath == widget.audioPath;
      if (_isPlayingThis != isThis) {
        setState(() => _isPlayingThis = isThis);
      }
    });
  }

  @override
  void dispose() {
    _playingSub?.cancel();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    final audioService = ref.read(ticunaAudioServiceProvider);
    final path = widget.audioPath;
    if (path == null || path.isEmpty) return;

    if (_isPlayingThis) {
      await audioService.pause();
      if (mounted) setState(() => _isPlayingThis = false);
    } else {
      await audioService.play(path, speed: _currentSpeed);
      if (mounted) setState(() => _isPlayingThis = true);
    }
  }

  Future<void> _cycleSpeed() async {
    final currentIndex = availableSpeeds.indexOf(_currentSpeed);
    final nextIndex = (currentIndex + 1) % availableSpeeds.length;
    final nextSpeed = availableSpeeds[nextIndex];

    setState(() => _currentSpeed = nextSpeed);
    final audioService = ref.read(ticunaAudioServiceProvider);
    await audioService.setPlaybackSpeed(nextSpeed);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Velocidade de reprodução: ${nextSpeed}x'),
          duration: const Duration(milliseconds: 900),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmDeleteAudio() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Apagar Pronúncia?'),
          ],
        ),
        content: const Text(
          'Deseja remover este áudio de pronúncia? Você poderá gravar um novo áudio a qualquer momento.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final audioService = ref.read(ticunaAudioServiceProvider);
      await audioService.deleteAudioFile(widget.audioPath);

      final repo = ref.read(ticunaRepositoryProvider);
      if (widget.isPhrase) {
        await repo.deletePhraseAudio(widget.id);
      } else {
        await repo.deleteWordAudio(widget.id);
      }

      widget.onAudioUpdated?.call(null, null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Áudio removido com sucesso. Pronto para regravar!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _openRecordingSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TicunaRecordingBottomSheet(
        id: widget.id,
        title: widget.title,
        isPhrase: widget.isPhrase,
        onSaved: (newPath, durationSeconds) {
          widget.onAudioUpdated?.call(newPath, durationSeconds);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasAudio = widget.audioPath != null && widget.audioPath!.isNotEmpty;

    if (!hasAudio) {
      // Estado sem áudio: botão compacto ou expandido de gravação
      return widget.compact
          ? InkWell(
              onTap: _openRecordingSheet,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mic_none, size: 15, color: Color(0xFF0D9488)),
                    SizedBox(width: 4),
                    Text(
                      'Gravar',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0D9488),
                      ),
                    ),
                  ],
                ),
              ) ,
            )
          : OutlinedButton.icon(
              onPressed: _openRecordingSheet,
              icon: const Icon(Icons.mic, size: 18, color: Color(0xFF0D9488)),
              label: const Text(
                'Gravar Pronúncia Ticuna',
                style: TextStyle(color: Color(0xFF0D9488), fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF0D9488)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
    }

    // Estado com áudio disponível: player com Play/Pause, Velocidade e Ações
    final durationSec = widget.audioDurationSeconds ?? 0;
    final durationLabel = durationSec > 0
        ? '${(durationSec ~/ 60).toString().padLeft(2, '0')}:${(durationSec % 60).toString().padLeft(2, '0')}'
        : '00:03';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 8 : 12,
        vertical: widget.compact ? 4 : 8,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF0D9488).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botão Play / Pause
          IconButton(
            icon: Icon(
              _isPlayingThis ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: const Color(0xFF0D9488),
              size: widget.compact ? 24 : 28,
            ),
            tooltip: _isPlayingThis ? 'Pausar pronúncia' : 'Ouvir pronúncia',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _togglePlayPause,
          ),
          const SizedBox(width: 8),

          // Duração e Indicador
          Text(
            durationLabel,
            style: TextStyle(
              fontSize: widget.compact ? 11 : 12.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade300 : const Color(0xFF0F766E),
            ),
          ),
          const SizedBox(width: 8),

          // Seletor de Velocidade (0.5x, 0.75x, 1.0x, 1.25x)
          InkWell(
            onTap: _cycleSpeed,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${_currentSpeed}x',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D9488),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Botão de Regravar / Apagar
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert,
              size: 18,
              color: Color(0xFF0D9488),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Opções do áudio',
            onSelected: (val) {
              if (val == 'rerecord') {
                _openRecordingSheet();
              } else if (val == 'delete') {
                _confirmDeleteAudio();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'rerecord',
                child: Row(
                  children: [
                    Icon(Icons.mic, size: 18, color: Color(0xFF0D9488)),
                    SizedBox(width: 8),
                    Text('Regravar pronúncia'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Apagar áudio', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Modal inferior de gravação com microfone, timer, preview e confirmação
class _TicunaRecordingBottomSheet extends ConsumerStatefulWidget {
  final String id;
  final String title;
  final bool isPhrase;
  final void Function(String newPath, int durationSeconds) onSaved;

  const _TicunaRecordingBottomSheet({
    required this.id,
    required this.title,
    required this.isPhrase,
    required this.onSaved,
  });

  @override
  ConsumerState<_TicunaRecordingBottomSheet> createState() =>
      _TicunaRecordingBottomSheetState();
}

class _TicunaRecordingBottomSheetState
    extends ConsumerState<_TicunaRecordingBottomSheet> {
  bool _recording = false;
  int _seconds = 0;
  Timer? _timer;
  StreamSubscription<int>? _durationSub;
  TicunaRecordingResult? _result;
  bool _isPlayingPreview = false;
  double _previewSpeed = 1.0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final audioService = ref.read(ticunaAudioServiceProvider);
    _durationSub = audioService.recordingDurationStream.listen((sec) {
      if (!mounted) return;
      setState(() {
        _seconds = sec;
        if (sec >= 15 && _recording) {
          _stop();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _durationSub?.cancel();
    if (_recording) {
      ref.read(ticunaAudioServiceProvider).cancelRecording();
    }
    super.dispose();
  }

  Future<void> _start() async {
    final audioService = ref.read(ticunaAudioServiceProvider);
    setState(() {
      _recording = true;
      _seconds = 0;
      _result = null;
    });

    // Inicia imediatamente o timer visual para garantir resposta tátil imediata
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (!_recording) {
        t.cancel();
        return;
      }
      setState(() {
        if (_seconds < 15) {
          _seconds++;
        }
        if (_seconds >= 15) {
          _stop();
        }
      });
    });

    try {
      await audioService.startRecording(
        id: widget.id,
        prefix: widget.isPhrase ? 'phrase' : 'word',
      );
    } catch (e) {
      debugPrint('[TicunaRecording] Falha ao iniciar gravação: $e');
      if (mounted) {
        _timer?.cancel();
        setState(() {
          _recording = false;
          _seconds = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erro ao iniciar microfone: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stop() async {
    _timer?.cancel();
    final audioService = ref.read(ticunaAudioServiceProvider);
    try {
      final res = await audioService.stopRecording();

      if (mounted) {
        setState(() {
          _recording = false;
          _result = res;
        });
      }
    } catch (e) {
      debugPrint('[TicunaRecording] Erro ao finalizar gravação: $e');
      if (mounted) {
        setState(() {
          _recording = false;
        });
      }
    }
  }

  Future<void> _playPreview() async {
    if (_result == null) return;
    final audioService = ref.read(ticunaAudioServiceProvider);

    if (_isPlayingPreview) {
      await audioService.pause();
      if (mounted) setState(() => _isPlayingPreview = false);
    } else {
      await audioService.play(_result!.filePath, speed: _previewSpeed);
      if (mounted) setState(() => _isPlayingPreview = true);
    }
  }

  void _cyclePreviewSpeed() {
    const speeds = [0.5, 0.75, 1.0, 1.25];
    final idx = speeds.indexOf(_previewSpeed);
    final next = speeds[(idx + 1) % speeds.length];
    setState(() => _previewSpeed = next);
    ref.read(ticunaAudioServiceProvider).setPlaybackSpeed(next);
  }

  Future<void> _save() async {
    if (_result == null || _isSaving) return;
    setState(() => _isSaving = true);

    try {
      final repo = ref.read(ticunaRepositoryProvider);
      final audioService = ref.read(ticunaAudioServiceProvider);

      // Salva no banco local Drift apenas se o registro já existir (edição de palavra/frase já salva)
      final isTemporaryDraft = widget.id.startsWith('word_') || widget.id.startsWith('phrase_');
      if (!isTemporaryDraft) {
        if (widget.isPhrase) {
          await repo.updatePhraseAudio(
            widget.id,
            _result!.filePath,
            durationSeconds: _result!.durationSeconds,
          );
        } else {
          await repo.updateWordAudio(
            widget.id,
            _result!.filePath,
            durationSeconds: _result!.durationSeconds,
          );
        }

        // Envia em segundo plano para o Supabase Storage se conectado
        unawaited(
          audioService.uploadToSupabase(
            id: widget.id,
            localFilePath: _result!.filePath,
          ),
        );
      }

      widget.onSaved(_result!.filePath, _result!.durationSeconds);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pronúncia salva! (${(_result!.fileSizeBytes / 1024).toStringAsFixed(1)} KB - ${kIsWeb ? 'WebM' : 'AAC'} otimizado)',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar áudio: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Barra de arraste
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Título e Termo Ticuna
            Text(
              widget.isPhrase ? 'Pronúncia da Frase Ticuna' : 'Pronúncia da Palavra Ticuna',
              style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: TicunaUnicodeHelper.textStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0D9488),
              ),
            ),
            const SizedBox(height: 20),

            // Bloco de Gravação / Preview
            if (_result == null) ...[
              // Gravando ou Pronto para gravar
              Text(
                _recording
                    ? 'Gravando... 00:${_seconds.toString().padLeft(2, '0')} / 00:15'
                    : 'Toque no microfone para iniciar a gravação',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: _recording ? FontWeight.bold : FontWeight.normal,
                  color: _recording ? Colors.red : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: _recording ? _stop : _start,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: _recording ? Colors.red : const Color(0xFF0D9488),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (_recording ? Colors.red : const Color(0xFF0D9488))
                            .withValues(alpha: 0.35),
                        blurRadius: _recording ? 16 : 8,
                        spreadRadius: _recording ? 4 : 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    _recording ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _recording ? 'Toque para finalizar' : 'Limite de 15 segundos',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ] else ...[
              // Preview do Áudio Gravado
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isPlayingPreview ? Icons.pause_circle_filled : Icons.play_circle_filled,
                        color: const Color(0xFF0D9488),
                        size: 32,
                      ),
                      onPressed: _playPreview,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pronúncia Gravada: ${_result!.durationSeconds}s',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${(_result!.fileSizeBytes / 1024).toStringAsFixed(1)} KB (AAC Mono 32 kbps)',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: _cyclePreviewSpeed,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_previewSpeed}x',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D9488),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _result = null;
                          _seconds = 0;
                        });
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Regravar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: Text(_isSaving ? 'Salvando...' : 'Salvar Áudio'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
