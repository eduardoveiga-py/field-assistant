import 'dart:async';
import 'package:flutter/foundation.dart';

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
