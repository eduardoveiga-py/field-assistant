import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../contacts/doorstep_briefing_helper.dart';
import '../../core/app_theme.dart';
import '../../voice_notes/audio_recording_service.dart';

/// Card de visualização ultrarrápida (30 segundos) para preparação imediata
/// na calçada ou porta do morador/estudante bíblico.
class DoorstepBriefingCard extends StatefulWidget {
  final DoorstepBriefingData data;
  final VoidCallback? onOpenJwLibrary;
  final void Function(Uri)? onLaunchJwLibrary;
  final void Function(String)? onPlayVoiceNote;
  final VoidCallback? onQuickRecord;

  const DoorstepBriefingCard({
    super.key,
    required this.data,
    this.onOpenJwLibrary,
    this.onLaunchJwLibrary,
    this.onPlayVoiceNote,
    this.onQuickRecord,
  });

  @override
  State<DoorstepBriefingCard> createState() => _DoorstepBriefingCardState();
}

class _DoorstepBriefingCardState extends State<DoorstepBriefingCard> {
  final AudioPlayerService _player = LocalAudioPlayerService();
  bool _isPlaying = false;
  StreamSubscription<bool>? _playerSub;

  @override
  void initState() {
    super.initState();
    _playerSub = _player.playingStateStream.listen((playing) {
      if (mounted) {
        setState(() {
          _isPlaying = playing;
        });
      }
    });
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  void _togglePlay(String? audioPath) {
    if (widget.onPlayVoiceNote != null && audioPath != null) {
      widget.onPlayVoiceNote!(audioPath);
    }
    if (_isPlaying) {
      _player.pause();
    } else {
      _player.play(audioPath ?? 'simulated_audio.m4a');
    }
  }

  DoorstepBriefingData get data => widget.data;
  VoidCallback? get onOpenJwLibrary => widget.onOpenJwLibrary;
  void Function(Uri)? get onLaunchJwLibrary => widget.onLaunchJwLibrary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Detecta modo sol intenso (alto contraste)
    final cardShape = theme.cardTheme.shape;
    final BorderSide? borderSide = cardShape is RoundedRectangleBorder
        ? cardShape.side
        : null;
    final isSunMode = (borderSide?.color == const Color(0xFF000000) &&
            (borderSide?.width ?? 0) >= 2.0) ||
        (theme.colorScheme.primary == const Color(0xFF000000) &&
            theme.scaffoldBackgroundColor == Colors.white &&
            theme.brightness == Brightness.light);

    // Se não houver absolutamente nenhum dado registrado, exibe modo compacto inicial
    if (!data.hasAnyData) {
      return _buildEmptyStateCard(context, isDark, isSunMode);
    }

    return Card(
      elevation: isSunMode ? 0 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isSunMode
            ? const BorderSide(color: Color(0xFF000000), width: 2.5)
            : BorderSide(
                color: isDark
                    ? const Color(0xFF334155)
                    : AppTheme.primaryBlue.withValues(alpha: 0.25),
                width: 1.5,
              ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho com ícone e badge "30s"
            _buildHeader(context, isSunMode, isDark),
            const SizedBox(height: 14),

            // SEÇÃO 1: Onde Parou + Botão JW Library
            _buildWhereWeStoppedSection(context, isSunMode, isDark),
            const SizedBox(height: 12),

            // SEÇÃO 2: Pendência da Última Visita
            _buildCalloutSection(
              context: context,
              title: 'PENDÊNCIA DA ÚLTIMA VISITA',
              content: data.pendingDoubt,
              placeholder: 'Sem pendências registradas da última visita',
              icon: Icons.help_outline,
              accentColor: const Color(0xFFD97706), // Amber
              isSunMode: isSunMode,
              isDark: isDark,
            ),
            const SizedBox(height: 10),

            // SEÇÃO 3: Alvo Espiritual Atual
            _buildCalloutSection(
              context: context,
              title: 'ALVO ESPIRITUAL ATUAL',
              content: data.spiritualGoal,
              placeholder: 'Nenhum alvo espiritual ativo cadastrado',
              icon: Icons.track_changes,
              accentColor: const Color(0xFF0D9488), // Teal
              isSunMode: isSunMode,
              isDark: isDark,
            ),
            const SizedBox(height: 10),

            // SEÇÃO 4: Toque de Empatia (Família / Pessoal)
            _buildCalloutSection(
              context: context,
              title: 'TOQUE DE EMPATIA (PESSOAL / FAMÍLIA)',
              content: data.empathyNote,
              placeholder: 'Nenhuma observação pessoal recente',
              icon: Icons.favorite_outline,
              accentColor: const Color(0xFFE11D48), // Rose
              isSunMode: isSunMode,
              isDark: isDark,
            ),

            // SEÇÃO 5: Última Nota de Voz (Ditado Rápido Offline)
            if (data.hasVoiceNote) ...[
              const SizedBox(height: 10),
              _buildVoiceNoteSection(context, isSunMode, isDark),
            ],
          ],
        ),
      ),
    );
  }

  /// Seção dedicada à reprodução e visualização da última nota de áudio/voz gravada
  Widget _buildVoiceNoteSection(BuildContext context, bool isSunMode, bool isDark) {
    const accentColor = Color(0xFF6366F1); // Indigo
    final transcription = data.voiceNoteTranscription;
    final durationSeconds = data.voiceNoteDurationSeconds ?? 15;
    final durationFormatted = '0:${durationSeconds.toString().padLeft(2, '0')}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSunMode
            ? Colors.white
            : (isDark
                ? accentColor.withValues(alpha: 0.12)
                : accentColor.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSunMode ? Colors.black : accentColor.withValues(alpha: 0.6),
          width: isSunMode ? 2.0 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.record_voice_over,
                size: 16,
                color: isSunMode ? Colors.black : accentColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'ÚLTIMA NOTA DE VOZ (DITADO RÁPIDO)',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: isSunMode ? Colors.black : accentColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSunMode
                      ? Colors.black
                      : (isDark ? const Color(0xFF1E293B) : Colors.white),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSunMode ? Colors.black : accentColor,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 11,
                      color: isSunMode ? Colors.white : accentColor,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      durationFormatted,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSunMode ? Colors.white : accentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (transcription != null && transcription.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '"$transcription"',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                fontWeight: isSunMode ? FontWeight.w700 : FontWeight.w500,
                color: isSunMode
                    ? Colors.black
                    : (isDark ? Colors.white : const Color(0xFF1E293B)),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Semantics(
                button: true,
                label: _isPlaying ? 'Pausar nota de voz' : 'Reproduzir nota de voz',
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48), // Tamanho mínimo de alvo de toque (48x48 dp)
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSunMode ? Colors.black : accentColor,
                      foregroundColor: Colors.white,
                      elevation: isSunMode ? 0 : 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: isSunMode
                            ? const BorderSide(color: Colors.black, width: 2)
                            : BorderSide.none,
                      ),
                    ),
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: 20),
                    label: Text(
                      _isPlaying ? 'Pausar Áudio' : 'Ouvir Nota ($durationFormatted)',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _togglePlay(data.audioFilePath),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Cabeçalho do Card com título e identificador de tempo rápido
  Widget _buildHeader(BuildContext context, bool isSunMode, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isSunMode
                ? Colors.black
                : (isDark ? const Color(0xFF334155) : const Color(0xFFEFF6FF)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.doorbell_outlined,
            size: 20,
            color: isSunMode ? Colors.white : AppTheme.primaryBlue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Briefing na Porta',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSunMode ? FontWeight.w900 : FontWeight.bold,
                  color: isSunMode
                      ? Colors.black
                      : (isDark ? Colors.white : AppTheme.textDark),
                ),
              ),
              Text(
                'Preparação rápida para a conversa',
                style: TextStyle(
                  fontSize: 11,
                  color: isSunMode
                      ? Colors.black87
                      : (isDark ? const Color(0xFF94A3B8) : AppTheme.textMuted),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSunMode
                ? Colors.black
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFFEF3C7)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSunMode ? Colors.black : const Color(0xFFF59E0B),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bolt,
                size: 13,
                color: isSunMode ? Colors.white : const Color(0xFFB45309),
              ),
              const SizedBox(width: 2),
              Text(
                '30s',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSunMode ? Colors.white : const Color(0xFFB45309),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Seção "Onde Parou" com destaque para a lição e botão de abertura do JW Library
  Widget _buildWhereWeStoppedSection(BuildContext context, bool isSunMode, bool isDark) {
    final hasContent = data.hasLessonOrTopic;
    final showButton = data.hasJwLibraryLink || onOpenJwLibrary != null || onLaunchJwLibrary != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSunMode
            ? Colors.white
            : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSunMode
              ? Colors.black
              : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          width: isSunMode ? 2.0 : 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 15,
                color: isSunMode ? Colors.black : AppTheme.primaryBlue,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'ONDE PAROU',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: isSunMode ? Colors.black : AppTheme.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (hasContent) ...[
            Text(
              data.lessonAndPoint!,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSunMode ? FontWeight.w900 : FontWeight.bold,
                color: isSunMode ? Colors.black : (isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
            ),
            if (data.publicationTitle != null && data.publicationTitle != data.lessonAndPoint) ...[
              const SizedBox(height: 2),
              Text(
                data.publicationTitle!,
                style: TextStyle(
                  fontSize: 12,
                  color: isSunMode ? Colors.black87 : (isDark ? const Color(0xFF94A3B8) : AppTheme.textMuted),
                ),
              ),
            ],
          ] else ...[
            Text(
              'Nenhuma lição ou assunto anterior registrado',
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: isSunMode ? Colors.black54 : (isDark ? const Color(0xFF64748B) : AppTheme.textMuted),
              ),
            ),
          ],
          if (showButton) ...[
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48), // Tamanho mínimo de alvo de toque (48x48 dp)
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSunMode ? Colors.black : AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: isSunMode ? 0 : 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: isSunMode
                        ? const BorderSide(color: Colors.black, width: 2)
                        : BorderSide.none,
                  ),
                ),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text(
                  'Abrir no JW Library',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  if (onOpenJwLibrary != null) {
                    onOpenJwLibrary!();
                  } else if (onLaunchJwLibrary != null && data.jwLibraryUri != null) {
                    onLaunchJwLibrary!(data.jwLibraryUri!);
                  } else if (data.jwLibraryUri != null) {
                    final uri = data.jwLibraryUri!;
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  }
                },
              ),
            ),
          ),
        ],
        ],
      ),
    );
  }

  /// Constrói caixas destacadas para Pendência, Alvo Espiritual e Toque de Empatia
  Widget _buildCalloutSection({
    required BuildContext context,
    required String title,
    required String? content,
    required String placeholder,
    required IconData icon,
    required Color accentColor,
    required bool isSunMode,
    required bool isDark,
  }) {
    final hasContent = content != null && content.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isSunMode
            ? Colors.white
            : (hasContent
                ? (isDark
                    ? accentColor.withValues(alpha: 0.12)
                    : accentColor.withValues(alpha: 0.08))
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC))),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSunMode
              ? Colors.black
              : (hasContent
                  ? accentColor.withValues(alpha: 0.6)
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          width: isSunMode ? 2.0 : (hasContent ? 1.5 : 1.0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 15,
                color: isSunMode ? Colors.black : accentColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: isSunMode ? Colors.black : accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          if (hasContent)
            Text(
              content.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isSunMode ? FontWeight.w800 : FontWeight.w600,
                color: isSunMode
                    ? Colors.black
                    : (isDark ? Colors.white : const Color(0xFF1E293B)),
              ),
            )
          else
            Text(
              placeholder,
              style: TextStyle(
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
                color: isSunMode
                    ? Colors.black45
                    : (isDark ? const Color(0xFF64748B) : AppTheme.textMuted),
              ),
            ),
        ],
      ),
    );
  }

  /// Card renderizado quando nenhum dado foi coletado ainda (contato novo)
  Widget _buildEmptyStateCard(BuildContext context, bool isDark, bool isSunMode) {
    return Card(
      elevation: isSunMode ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isSunMode
            ? const BorderSide(color: Colors.black, width: 2.0)
            : BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSunMode
                    ? Colors.black
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFEFF6FF)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.doorbell_outlined,
                size: 26,
                color: isSunMode ? Colors.white : AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Briefing na Porta (30s)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSunMode ? FontWeight.w900 : FontWeight.bold,
                      color: isSunMode ? Colors.black : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Primeiro contato sem histórico registrado. Ao registrar sua conversa, as notas, lição e alvos aparecerão aqui em destaque para o seu próximo retorno.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isSunMode ? Colors.black87 : AppTheme.textMuted,
                    ),
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
