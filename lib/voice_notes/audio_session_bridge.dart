import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';

import '../core/app_logger.dart';

/// Papel da sessão de áudio nativa (iOS AVAudioSession / Android AudioManager).
enum AudioSessionRole { recording, playback }

/// Evento normalizado de interrupção do sistema operacional (ex.: chamada telefônica,
/// alarme, Siri, perda de foco de áudio no Android).
class AudioSessionInterruption {
  final bool begin;
  final bool shouldPause;
  final bool shouldDuck;
  final String reason;

  const AudioSessionInterruption({
    required this.begin,
    required this.shouldPause,
    this.shouldDuck = false,
    this.reason = 'system_interruption',
  });
}

/// Abstração testável sobre `package:audio_session` (`AVAudioSession` no iOS e
/// `AudioManager` no Android) para tratar interrupções de áudio e desconexão de
/// fones/microfone (becoming noisy) sem acoplamento direto a canais nativos em testes.
abstract class AudioSessionBridge {
  Future<bool> activate({required AudioSessionRole role});
  Future<void> deactivate();
  Stream<AudioSessionInterruption> get interruptionEvents;
  Stream<void> get becomingNoisyEvents;
  void dispose();
}

/// Implementação real de produção usando `package:audio_session`.
class PlatformAudioSessionBridge implements AudioSessionBridge {
  AudioSession? _session;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;
  StreamSubscription<void>? _becomingNoisySub;
  final StreamController<AudioSessionInterruption> _interruptionController =
      StreamController<AudioSessionInterruption>.broadcast();
  final StreamController<void> _noisyController =
      StreamController<void>.broadcast();
  bool _disposed = false;

  Future<AudioSession?> _ensureSession() async {
    if (_disposed) return null;
    if (_session != null) return _session;
    try {
      final session = await AudioSession.instance;
      if (_disposed) return null;
      _session = session;
      _interruptionSub = session.interruptionEventStream.listen((event) {
        if (_interruptionController.isClosed) return;
        final shouldDuck = event.type == AudioInterruptionType.duck;
        final shouldPause =
            event.type == AudioInterruptionType.pause ||
            event.type == AudioInterruptionType.unknown;
        _interruptionController.add(
          AudioSessionInterruption(
            begin: event.begin,
            shouldPause: shouldPause,
            shouldDuck: shouldDuck,
            reason: event.type.name,
          ),
        );
      });
      _becomingNoisySub = session.becomingNoisyEventStream.listen((_) {
        if (!_noisyController.isClosed) {
          _noisyController.add(null);
        }
      });
      return session;
    } on MissingPluginException {
      return null;
    } on UnimplementedError {
      return null;
    } catch (e, st) {
      AppLogger.warning(
        'PlatformAudioSessionBridge: falha ao inicializar AudioSession',
        e,
        st,
      );
      return null;
    }
  }

  @override
  Future<bool> activate({required AudioSessionRole role}) async {
    final session = await _ensureSession();
    if (session == null) return false;
    try {
      final config = role == AudioSessionRole.recording
          ? AudioSessionConfiguration(
              avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
              avAudioSessionCategoryOptions:
                  AVAudioSessionCategoryOptions.allowBluetooth |
                  AVAudioSessionCategoryOptions.defaultToSpeaker,
              avAudioSessionMode: AVAudioSessionMode.spokenAudio,
              avAudioSessionRouteSharingPolicy:
                  AVAudioSessionRouteSharingPolicy.defaultPolicy,
              avAudioSessionSetActiveOptions:
                  AVAudioSessionSetActiveOptions.none,
              androidAudioAttributes: const AndroidAudioAttributes(
                contentType: AndroidAudioContentType.speech,
                flags: AndroidAudioFlags.none,
                usage: AndroidAudioUsage.voiceCommunication,
              ),
              androidAudioFocusGainType:
                  AndroidAudioFocusGainType.gainTransientExclusive,
              androidWillPauseWhenDucked: true,
            )
          : const AudioSessionConfiguration.speech();
      await session.configure(config);
      return await session.setActive(true);
    } on MissingPluginException {
      return false;
    } on UnimplementedError {
      return false;
    } catch (e, st) {
      AppLogger.warning(
        'PlatformAudioSessionBridge: falha ao ativar sessão ($role)',
        e,
        st,
      );
      return false;
    }
  }

  @override
  Future<void> deactivate() async {
    final session = _session;
    if (session == null) return;
    try {
      await session.setActive(
        false,
        avAudioSessionSetActiveOptions:
            AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
      );
    } on MissingPluginException {
      // Sem canal nativo (ex.: ambiente desktop/teste).
    } on UnimplementedError {
      // Plataforma sem suporte a setActive.
    } catch (e, st) {
      AppLogger.debug(
        'PlatformAudioSessionBridge: falha ao desativar sessão: $e',
        st,
      );
    }
  }

  @override
  Stream<AudioSessionInterruption> get interruptionEvents =>
      _interruptionController.stream;

  @override
  Stream<void> get becomingNoisyEvents => _noisyController.stream;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _interruptionSub?.cancel();
    _interruptionSub = null;
    _becomingNoisySub?.cancel();
    _becomingNoisySub = null;
    _interruptionController.close();
    _noisyController.close();
  }
}
