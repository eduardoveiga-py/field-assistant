import 'dart:async';

import 'package:flutter/foundation.dart';
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
}

/// Implementação real de reconhecimento e ditado de voz usando speech_to_text (pt-BR, offline-first).
class RealVoiceDictationService implements VoiceDictationService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  ValueChanged<String>? _currentOnError;

  @override
  bool get isListening => _isListening;

  @override
  Future<bool> isAvailable() async {
    try {
      if (!_isInitialized) {
        _isInitialized = await _speech.initialize(
          onError: (error) {
            _isListening = false;
            _currentOnError?.call(
              'Ditado offline indisponível (${error.errorMsg}). Digite o resumo manualmente.',
            );
          },
          onStatus: (status) {
            _isListening = status == 'listening';
          },
        );
      }
      return _isInitialized && _speech.isAvailable;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> startListening({
    required ValueChanged<String> onResult,
    ValueChanged<String>? onError,
  }) async {
    _currentOnError = onError;
    try {
      final available = await isAvailable();
      if (!available) {
        onError?.call(
          'Reconhecimento de fala offline indisponível no iOS. O áudio está sendo gravado e preservado; você pode digitar o resumo manualmente.',
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
    } catch (e) {
      _isListening = false;
      onError?.call(
        'Erro ao iniciar reconhecimento de fala offline: $e. O áudio segue sendo gravado normalmente.',
      );
    }
  }

  @override
  Future<void> stopListening() async {
    _isListening = false;
    _currentOnError = null;
    try {
      await _speech.stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    _isListening = false;
    _currentOnError = null;
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
  ValueChanged<String>? _onError;
  String _currentTranscription = '';
  final List<String> _pendingEmissions = [];
  bool availableOverride = true;
  String? failureReason;

  @override
  bool get isListening => _isListening;

  @override
  Future<bool> isAvailable() async => availableOverride;

  @override
  Future<void> startListening({
    required ValueChanged<String> onResult,
    ValueChanged<String>? onError,
  }) async {
    _isListening = true;
    _onResult = onResult;
    _onError = onError;
    _currentTranscription = '';

    if (!availableOverride || failureReason != null) {
      onError?.call(
        failureReason ?? 'Reconhecimento de fala offline indisponível no dispositivo. Digite o resumo manualmente.',
      );
      return;
    }

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

  /// Método utilitário para simular falha no ditado durante gravação
  void emitError(String error) {
    _onError?.call(error);
  }

  @override
  Future<void> stopListening() async {
    _isListening = false;
    _onError = null;
    _pendingEmissions.clear();
  }

  @override
  void dispose() {
    _isListening = false;
    _onResult = null;
    _onError = null;
    _pendingEmissions.clear();
  }
}

typedef FakeVoiceDictationService = LocalVoiceDictationService;
