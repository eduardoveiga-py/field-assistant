import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_theme.dart';
import '../../database/app_database.dart';
import '../../voice_notes/audio_recording_service.dart';
import '../../voice_notes/voice_dictation_service.dart';
import '../../voice_notes/voice_note_parser.dart';
import '../../voice_notes/voice_notes_manager.dart';

/// Diálogo/Modal para Registro Rápido por Áudio / Ditado (15 a 30s) Offline-First.
class QuickVoiceNoteDialog extends ConsumerStatefulWidget {
  final PersonEntry person;
  final BibleStudyEntry? linkedStudy;
  final AudioRecordingService? recordingService;
  final VoiceDictationService? dictationService;
  final AudioPlayerService? playerService;
  final String? initialTranscription;

  const QuickVoiceNoteDialog({
    super.key,
    required this.person,
    this.linkedStudy,
    this.recordingService,
    this.dictationService,
    this.playerService,
    this.initialTranscription,
  });

  /// Exibe o modal na tela do usuário
  static Future<void> show({
    required BuildContext context,
    required PersonEntry person,
    BibleStudyEntry? linkedStudy,
    AudioRecordingService? recordingService,
    VoiceDictationService? dictationService,
    AudioPlayerService? playerService,
    String? initialTranscription,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => QuickVoiceNoteDialog(
        person: person,
        linkedStudy: linkedStudy,
        recordingService: recordingService,
        dictationService: dictationService,
        playerService: playerService,
        initialTranscription: initialTranscription,
      ),
    );
  }

  @override
  ConsumerState<QuickVoiceNoteDialog> createState() => _QuickVoiceNoteDialogState();
}

class _QuickVoiceNoteDialogState extends ConsumerState<QuickVoiceNoteDialog> {
  late final AudioRecordingService _recordingService;
  late final VoiceDictationService _dictationService;
  late final AudioPlayerService _playerService;

  late final TextEditingController _transcriptionController;
  late final TextEditingController _pendingController;
  late final TextEditingController _empathyController;
  late final TextEditingController _lessonController;
  late final TextEditingController _pointController;

  bool _isPendingManuallyEdited = false;
  bool _isEmpathyManuallyEdited = false;
  bool _isLessonManuallyEdited = false;
  bool _isPointManuallyEdited = false;

  StreamSubscription<int>? _durationSub;
  StreamSubscription<bool>? _playerStateSub;

  bool _isRecording = false;
  int _seconds = 0;
  bool _isPlayingAudio = false;
  bool _isSaving = false;
  RecordingResult? _recordingResult;
  ParsedVoiceNote _parsedNote = const ParsedVoiceNote(rawText: '');

  @override
  void initState() {
    super.initState();
    _recordingService = widget.recordingService ?? LocalAudioRecordingService();
    _dictationService = widget.dictationService ?? LocalVoiceDictationService();
    _playerService = widget.playerService ?? LocalAudioPlayerService();

    final initial = widget.initialTranscription ?? '';
    _transcriptionController = TextEditingController(text: initial);
    _pendingController = TextEditingController();
    _empathyController = TextEditingController();
    _lessonController = TextEditingController();
    _pointController = TextEditingController();

    _durationSub = _recordingService.recordingDurationStream.listen((sec) {
      if (mounted) {
        setState(() {
          _seconds = sec;
        });
        if (sec >= 30 && _isRecording) {
          _stopRecording();
        }
      }
    });

    _playerStateSub = _playerService.playingStateStream.listen((playing) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = playing;
        });
      }
    });

    if (initial.isNotEmpty) {
      _processTranscription(initial);
    }
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _playerStateSub?.cancel();
    if (widget.recordingService == null) {
      _recordingService.dispose();
    }
    if (widget.dictationService == null) {
      _dictationService.dispose();
    }
    if (widget.playerService == null) {
      _playerService.dispose();
    }
    _transcriptionController.dispose();
    _pendingController.dispose();
    _empathyController.dispose();
    _lessonController.dispose();
    _pointController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    setState(() {
      _isRecording = true;
      _seconds = 0;
    });

    final dictationFuture = _dictationService.startListening(
      onResult: (text) {
        if (mounted) {
          _transcriptionController.text = text;
          _processTranscription(text);
        }
      },
    );
    final recordingFuture = _recordingService.startRecording();
    await Future.wait([dictationFuture, recordingFuture]);
  }

  Future<void> _stopRecording() async {
    final result = await _recordingService.stopRecording();
    await _dictationService.stopListening();

    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordingResult = result;
      });
      _processTranscription(_transcriptionController.text);
    }
  }

  void _processTranscription(String text) {
    final parsed = VoiceNoteParser.parse(text);
    setState(() {
      _parsedNote = parsed;
      if (!_isPendingManuallyEdited) {
        _pendingController.text = parsed.pendingDoubt ?? '';
      }
      if (!_isEmpathyManuallyEdited) {
        _empathyController.text = parsed.empathyNote ?? '';
      }
      if (!_isLessonManuallyEdited) {
        _lessonController.text = parsed.lesson?.toString() ?? '';
      }
      if (!_isPointManuallyEdited) {
        _pointController.text = parsed.point?.toString() ?? '';
      }
    });
  }

  void _toggleAudioPreview() {
    if (_isPlayingAudio) {
      _playerService.pause();
    } else {
      _playerService.play(_recordingResult?.filePath ?? 'simulated_voice_note.m4a');
    }
  }

  Future<void> _saveAndApplyBriefing() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    final currentText = _transcriptionController.text.trim();
    final customLesson = int.tryParse(_lessonController.text.trim());
    final customPoint = int.tryParse(_pointController.text.trim());
    final customPending = _pendingController.text.trim().isEmpty ? null : _pendingController.text.trim();
    final customEmpathy = _empathyController.text.trim().isEmpty ? null : _empathyController.text.trim();

    final finalParsed = _parsedNote.copyWith(
      lesson: customLesson ?? _parsedNote.lesson,
      point: customPoint ?? _parsedNote.point,
      pendingDoubt: customPending,
      empathyNote: customEmpathy,
      rawText: currentText.isEmpty ? (_parsedNote.rawText.isNotEmpty ? _parsedNote.rawText : 'Nota de voz rápida') : currentText,
    );

    try {
      final manager = ref.read(voiceNotesManagerProvider);
      await manager.saveQuickVisitFromVoiceNote(
        personId: widget.person.id,
        parsedNote: finalParsed,
        audioFilePath: _recordingResult?.filePath,
        audioDurationSeconds: _recordingResult?.durationSeconds ?? (_seconds > 0 ? _seconds : 15),
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Visita salva e Briefing na Porta atualizado com sucesso!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Erro ao salvar nota: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Detecção de SunMode (alto contraste)
    final cardShape = theme.cardTheme.shape;
    final BorderSide? borderSide = cardShape is RoundedRectangleBorder ? cardShape.side : null;
    final isSunMode = (borderSide?.color == const Color(0xFF000000) && (borderSide?.width ?? 0) >= 2.0) ||
        (theme.colorScheme.primary == const Color(0xFF000000) &&
            theme.scaffoldBackgroundColor == Colors.white &&
            theme.brightness == Brightness.light);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSunMode ? const BorderSide(color: Colors.black, width: 2.5) : BorderSide.none,
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabeçalho com título e indicador de 15s
                _buildHeader(isSunMode, isDark),
                const SizedBox(height: 16),

                // Painel de Gravação / Cronômetro
                _buildRecordingPanel(isSunMode, isDark),
                const SizedBox(height: 16),

                // Pré-visualização Estruturada Teocrática
                _buildStructuredPreview(isSunMode, isDark),
                const SizedBox(height: 16),

                // Campo de Ajuste Manual da Transcrição
                _buildTranscriptionField(isSunMode, isDark),
                const SizedBox(height: 20),

                // Botão de 1 Toque: Salvar Visita & Atualizar Briefing
                _buildActionButtons(isSunMode, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isSunMode, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSunMode ? Colors.black : const Color(0xFF4F46E5).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.mic_outlined,
            size: 22,
            color: isSunMode ? Colors.white : const Color(0xFF4F46E5),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Registro Rápido (15s)',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: isSunMode ? FontWeight.w900 : FontWeight.bold,
                    color: isSunMode ? Colors.black : (isDark ? Colors.white : AppTheme.textDark),
                  ),
                ),
              ),
              Text(
                widget.person.name,
                style: TextStyle(
                  fontSize: 13,
                  color: isSunMode ? Colors.black87 : (isDark ? const Color(0xFF94A3B8) : AppTheme.textMuted),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Fechar',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildRecordingPanel(bool isSunMode, bool isDark) {
    final progress = (_seconds / 30).clamp(0.0, 1.0);
    final durationFormatted = '0:${_seconds.toString().padLeft(2, '0')} / 0:30';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSunMode ? Colors.white : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSunMode
              ? Colors.black
              : (_isRecording ? Colors.red : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
          width: isSunMode ? 2.0 : (_isRecording ? 2.0 : 1.2),
        ),
      ),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording ? Colors.red : (_seconds > 0 ? Colors.green : Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isRecording
                          ? 'Gravando áudio...'
                          : (_seconds > 0 ? 'Gravação finalizada' : 'Pronto para gravar'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isSunMode ? Colors.black : (_isRecording ? Colors.red : null),
                      ),
                    ),
                  ],
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  durationFormatted,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isSunMode ? Colors.black : AppTheme.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                isSunMode ? Colors.black : (_seconds >= 15 ? Colors.green : AppTheme.primaryBlue),
              ),
            ),
          ),
          if (_seconds >= 15) ...[
            const SizedBox(height: 6),
            const Text(
              '✓ Duração ideal para notas de campo alcançada',
              style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (!_isRecording)
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSunMode ? Colors.black : const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: isSunMode ? const BorderSide(color: Colors.black, width: 2) : BorderSide.none,
                      ),
                    ),
                    onPressed: _startRecording,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.mic, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(_seconds == 0 ? 'Iniciar Gravação' : 'Gravar Novamente'),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: isSunMode ? const BorderSide(color: Colors.black, width: 2) : BorderSide.none,
                      ),
                    ),
                    onPressed: _stopRecording,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.stop, size: 20),
                        SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Concluir Gravação'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_seconds > 0 && !_isRecording)
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isSunMode ? Colors.black : AppTheme.primaryBlue,
                      side: BorderSide(color: isSunMode ? Colors.black : AppTheme.primaryBlue, width: isSunMode ? 2.0 : 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _toggleAudioPreview,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_isPlayingAudio ? Icons.pause : Icons.play_arrow, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(_isPlayingAudio ? 'Pausar' : 'Ouvir Áudio'),
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
    );
  }

  Widget _buildStructuredPreview(bool isSunMode, bool isDark) {
    final hasLesson = _parsedNote.lesson != null || _parsedNote.point != null;
    final progressText = _parsedNote.formattedProgress ?? 'Nenhuma lição detectada';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSunMode ? Colors.white : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSunMode ? Colors.black : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: isSunMode ? 2.0 : 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 16,
                color: isSunMode ? Colors.black : const Color(0xFF7C3AED),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'EXTRAÇÃO DETERMINÍSTICA AUTOMÁTICA',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: isSunMode ? Colors.black : const Color(0xFF7C3AED),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Chip 1: Progresso (Lição e Ponto)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSunMode ? Colors.white : (isDark ? const Color(0xFF0F172A) : Colors.white),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSunMode
                    ? Colors.black
                    : (hasLesson ? const Color(0xFF7C3AED) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                width: isSunMode ? 2.0 : (hasLesson ? 1.5 : 1.0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.menu_book,
                      size: 16,
                      color: isSunMode ? Colors.black : (hasLesson ? const Color(0xFF7C3AED) : Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '📖 Progresso: $progressText',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: hasLesson ? FontWeight.bold : FontWeight.normal,
                          color: isSunMode ? Colors.black : null,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _lessonController,
                        keyboardType: TextInputType.number,
                        onChanged: (val) {
                          _isLessonManuallyEdited = true;
                          setState(() {
                            final parsedL = int.tryParse(val.trim());
                            _parsedNote = _parsedNote.copyWith(lesson: parsedL);
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Lição',
                          hintText: 'Ex: 18',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _pointController,
                        keyboardType: TextInputType.number,
                        onChanged: (val) {
                          _isPointManuallyEdited = true;
                          setState(() {
                            final parsedP = int.tryParse(val.trim());
                            _parsedNote = _parsedNote.copyWith(point: parsedP);
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Ponto / Parágrafo',
                          hintText: 'Ex: 3',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Chip 2: Pendência para Próxima Visita
          TextFormField(
            controller: _pendingController,
            onChanged: (val) {
              _isPendingManuallyEdited = true;
            },
            decoration: InputDecoration(
              labelText: '📌 Pendência / Próximo Passo',
              hintText: 'Ex: Mostrar vídeo sobre batismo',
              isDense: true,
              prefixIcon: const Icon(Icons.help_outline, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),

          // Chip 3: Gatilho de Empatia
          TextFormField(
            controller: _empathyController,
            onChanged: (val) {
              _isEmpathyManuallyEdited = true;
            },
            decoration: InputDecoration(
              labelText: '💡 Gatilho de Empatia / Contexto de Vida',
              hintText: 'Ex: Turno de trabalho vai mudar na próxima semana',
              isDense: true,
              prefixIcon: const Icon(Icons.favorite_outline, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptionField(bool isSunMode, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Texto Transcrito / Ditado (pode ser ajustado manualmente):',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _transcriptionController,
          maxLines: 3,
          onChanged: _processTranscription,
          decoration: InputDecoration(
            hintText: 'Fale ou digite o resumo da visita...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isSunMode ? Colors.black : const Color(0xFFCBD5E1),
                width: isSunMode ? 2.0 : 1.0,
              ),
            ),
          ),
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool isSunMode, bool isDark) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48), // Alvo de toque mínimo 48dp
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isSunMode ? Colors.black : const Color(0xFF10B981),
            foregroundColor: Colors.white,
            elevation: isSunMode ? 0 : 2,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: isSunMode ? const BorderSide(color: Colors.black, width: 2) : BorderSide.none,
            ),
          ),
          onPressed: _isSaving ? null : _saveAndApplyBriefing,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isSaving)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              else
                const Icon(Icons.flash_on, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _isSaving ? 'Salvando...' : 'Salvar Visita & Atualizar Briefing',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
