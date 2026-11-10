import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Contrato desacoplado para serviço de reconhecimento e ditado de voz.
abstract class VoiceDictationService {
  bool get isListening;
  Future<bool> isAvailable();
  Future<void> startListening({
    required ValueChanged<String> onResult,
    ValueChanged<String>? onError,
  });
  Future<void> stopListening();
  void dispose();

  /// Retorna true se a plataforma atual suporta nativamente o engine de reconhecimento de fala.
  static bool get isPlatformSupported {
    if (kIsWeb) return true;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
        return true;
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  /// Cria a instância apropriada para a plataforma em execução:
  /// - Em plataformas não suportadas (ex: Linux): retorna UnsupportedVoiceDictationService.
  /// - Em plataformas suportadas: retorna RealVoiceDictationService com proteção a exceções.
  static VoiceDictationService platform({
    VoiceDictationService? overrideService,
  }) {
    if (overrideService != null) return overrideService;
    if (!isPlatformSupported) {
      return UnsupportedVoiceDictationService();
    }
    return RealVoiceDictationService();
  }
}

/// Serviço no-op para plataformas sem suporte nativo a reconhecimento de voz (ex: Linux).
class UnsupportedVoiceDictationService implements VoiceDictationService {
  @override
  bool get isListening => false;

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<void> startListening({
    required ValueChanged<String> onResult,
    ValueChanged<String>? onError,
  }) async {
    onError?.call(
      'Ditado por voz indisponível nesta plataforma. Digite o resumo manualmente.',
    );
  }

  @override
  Future<void> stopListening() async {}

  @override
  void dispose() {}
}

/// Implementação real de reconhecimento e ditado de voz usando speech_to_text (pt-BR, offline-first).
class RealVoiceDictationService implements VoiceDictationService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  @override
  bool get isListening => _isListening;

  @override
  Future<bool> isAvailable() async {
    if (!VoiceDictationService.isPlatformSupported) {
      return false;
    }
    try {
      if (!_isInitialized) {
        _isInitialized = await _speech.initialize(
          onError: (error) {
            _isListening = false;
          },
          onStatus: (status) {
            _isListening = status == 'listening';
          },
        );
      }
      return _isInitialized && _speech.isAvailable;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> startListening({
    required ValueChanged<String> onResult,
    ValueChanged<String>? onError,
  }) async {
    try {
      final available = await isAvailable();
      if (!available) {
        onError?.call(
          'Reconhecimento de fala indisponível no dispositivo. Digite o resumo manualmente.',
        );
        return;
      }

      _isListening = true;
      await _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords);
        },
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          listenMode: stt.ListenMode.dictation,
          localeId: 'pt_BR',
        ),
      );
    } on MissingPluginException catch (e) {
      _isListening = false;
      onError?.call('Plugin de reconhecimento de voz não disponível na plataforma: ${e.message}');
    } on PlatformException catch (e) {
      _isListening = false;
      onError?.call('Erro de plataforma no reconhecimento de voz: ${e.message}');
    } catch (e) {
      _isListening = false;
      onError?.call('Erro ao iniciar reconhecimento de voz: $e');
    }
  }

  @override
  Future<void> stopListening() async {
    _isListening = false;
    try {
      await _speech.stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    _isListening = false;
    try {
      _speech.cancel();
    } catch (_) {}
  }
}

/// Implementação offline do serviço de ditado, permitindo transcrição simulada ou
/// injeção programática para testes de widget e uso sob condições reais.
class LocalVoiceDictationService implements VoiceDictationService {
  bool _isListening = false;
  ValueChanged<String>? _onResult;
  String _currentTranscription = '';
  final List<String> _pendingEmissions = [];

  @override
  bool get isListening => _isListening;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> startListening({
    required ValueChanged<String> onResult,
    ValueChanged<String>? onError,
  }) async {
    _isListening = true;
    _onResult = onResult;
    _currentTranscription = '';
    for (final pending in _pendingEmissions) {
      _currentTranscription = pending;
      _onResult!(pending);
    }
    _pendingEmissions.clear();
  }

  /// Método utilitário para emitir texto transcrito durante o ditado
  void emitTranscription(String text) {
    if (_isListening && _onResult != null) {
      _currentTranscription = text;
      _onResult!(_currentTranscription);
    } else {
      _pendingEmissions.add(text);
    }
  }

  @override
  Future<void> stopListening() async {
    _isListening = false;
    _pendingEmissions.clear();
  }

  @override
  void dispose() {
    _isListening = false;
    _onResult = null;
    _pendingEmissions.clear();
  }
}

typedef FakeVoiceDictationService = LocalVoiceDictationService;
