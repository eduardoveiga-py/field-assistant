import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';

import '../core/app_logger.dart';

/// Exceção lançada quando ocorre falha na reprodução de áudio.
class AudioPlaybackException implements Exception {
  final String message;
  const AudioPlaybackException(this.message);

  @override
  String toString() => 'AudioPlaybackException: $message';
}

/// Resultado encapsulado de uma sessão de gravação de áudio.
class RecordingResult {
  final String filePath;
  final Duration duration;
  final int fileSize;
  final DateTime recordedAt;

  const RecordingResult({
    required this.filePath,
    required this.duration,
    this.fileSize = 0,
    required this.recordedAt,
  });

  /// Duração em segundos arredondada
  int get durationSeconds => duration.inSeconds;

  /// Valida se o arquivo possui bytes reais gravados no disco
  bool get fileIntegrityValid => fileSize > 0;
}

/// Contrato desacoplado para gravação de áudio.
abstract class AudioRecordingService {
  bool get isRecording;
  Stream<int> get recordingDurationStream;

  Future<bool> hasPermission();
  Future<bool> requestPermission();
  Future<String> startRecording({String? customPath, int maxDurationSeconds = 30});
  Future<RecordingResult?> stopRecording();
  Future<void> cancelRecording();
  void dispose();

  /// Retorna a implementação recomendada para a plataforma atual.
  static AudioRecordingService platform({AudioRecordingService? overrideService}) {
    if (overrideService != null) return overrideService;
    return RealAudioRecordingService();
  }
}

/// Implementação real de gravação de áudio usando package:record.
class RealAudioRecordingService implements AudioRecordingService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  int _maxDurationSeconds = 30;
  final Uuid _uuid = const Uuid();
  bool _isRecording = false;
  Timer? _timer;
  int _elapsedSeconds = 0;
  DateTime? _startedAt;
  String? _currentFilePath;

  final StreamController<int> _durationController =
      StreamController<int>.broadcast();

  RecordingResult? _lastResult;

  @override
  bool get isRecording => _isRecording;

  @override
  Stream<int> get recordingDurationStream => _durationController.stream;

  @override
  Future<bool> hasPermission() async {
    try {
      return await _audioRecorder.hasPermission();
    } catch (e, st) {
      AppLogger.warning('Falha ao verificar permissão de microfone', e, st);
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      return await _audioRecorder.hasPermission();
    } catch (e, st) {
      AppLogger.warning('Falha ao solicitar permissão de microfone', e, st);
      return false;
    }
  }

  @override
  Future<String> startRecording({String? customPath, int maxDurationSeconds = 30}) async {
    _maxDurationSeconds = maxDurationSeconds;
    if (_isRecording) {
      await cancelRecording();
    }

    var hasPerm = await hasPermission();
    if (!hasPerm) {
      hasPerm = await requestPermission();
    }
    if (!hasPerm) {
      throw Exception('Permissão de gravação de áudio negada');
    }

    _elapsedSeconds = 0;
    _startedAt = DateTime.now();
    _lastResult = null;

    if (customPath != null && customPath.isNotEmpty) {
      _currentFilePath = customPath;
    } else {
      final fileName = 'voice_note_${_uuid.v4()}.m4a';
      if (kIsWeb) {
        _currentFilePath = fileName;
      } else {
        try {
          final dir = await getApplicationDocumentsDirectory();
          final voiceDir = Directory('${dir.path}/voice_notes');
          if (!voiceDir.existsSync()) {
            await voiceDir.create(recursive: true);
          }
          _currentFilePath = '${voiceDir.path}/$fileName';
        } catch (e, st) {
          AppLogger.warning('Falha ao criar diretório voice_notes; usando nome relativo', e, st);
          _currentFilePath = fileName;
        }
      }
    }

    RecordConfig config;
    if (kIsWeb) {
      if (await _audioRecorder.isEncoderSupported(AudioEncoder.opus)) {
        config = const RecordConfig(encoder: AudioEncoder.opus);
        if (customPath == null || customPath.isEmpty) {
          _currentFilePath = 'voice_note_${_uuid.v4()}.webm';
        }
      } else if (await _audioRecorder.isEncoderSupported(AudioEncoder.aacLc)) {
        config = const RecordConfig(encoder: AudioEncoder.aacLc);
        if (customPath == null || customPath.isEmpty) {
          _currentFilePath = 'voice_note_${_uuid.v4()}.m4a';
        }
      } else {
        config = const RecordConfig(encoder: AudioEncoder.wav);
        if (customPath == null || customPath.isEmpty) {
          _currentFilePath = 'voice_note_${_uuid.v4()}.wav';
        }
      }
    } else {
      config = const RecordConfig(encoder: AudioEncoder.aacLc);
    }

    await _audioRecorder.start(
      config,
      path: _currentFilePath!,
    );
    _isRecording = true;

    _durationController.add(0);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!_isRecording) {
        timer.cancel();
        return;
      }
      _elapsedSeconds++;
      if (!_durationController.isClosed) {
        _durationController.add(_elapsedSeconds);
      }
      if (_elapsedSeconds >= _maxDurationSeconds) {
        timer.cancel();
        // Interrompe o gravador de verdade ao atingir 30 segundos
        await stopRecording();
      }
    });

    return _currentFilePath!;
  }

  @override
  Future<RecordingResult?> stopRecording() async {
    if (!_isRecording) return _lastResult;

    _timer?.cancel();
    _timer = null;
    _isRecording = false;

    String? path;
    try {
      path = await _audioRecorder.stop();
    } catch (e, st) {
      AppLogger.warning('Falha ao parar gravação de áudio nativo', e, st);
    }

    path ??= _currentFilePath ?? 'voice_note_${_uuid.v4()}.m4a';

    final duration = Duration(seconds: _elapsedSeconds);
    final recordedAt = _startedAt ?? DateTime.now();

    int size = 0;
    if (!kIsWeb) {
      try {
        final file = File(path);
        if (await file.exists()) {
          size = await file.length();
        }
      } catch (e, st) {
        AppLogger.warning('Falha ao medir tamanho do áudio gravado ($path)', e, st);
        size = 0;
      }
    } else {
      if (path.startsWith('blob:') ||
          path.startsWith('http://') ||
          path.startsWith('https://')) {
        try {
          final response = await http
              .get(Uri.parse(path))
              .timeout(const Duration(seconds: 3));
          if (response.statusCode == 200) {
            size = response.bodyBytes.length;
          }
        } catch (e, st) {
          AppLogger.debug('Falha ao medir tamanho do áudio Web ($path): $e', st);
          size = 0;
        }
      }
    }

    _lastResult = RecordingResult(
      filePath: path,
      duration: duration,
      fileSize: size,
      recordedAt: recordedAt,
    );
    return _lastResult;
  }

  @override
  Future<void> cancelRecording() async {
    _timer?.cancel();
    _timer = null;
    _isRecording = false;
    _elapsedSeconds = 0;

    try {
      await _audioRecorder.cancel();
    } catch (e, st) {
      AppLogger.debug('Falha ao cancelar gravação nativa: $e', st);
    }

    if (_currentFilePath != null && !kIsWeb) {
      try {
        final file = File(_currentFilePath!);
        if (file.existsSync()) {
          await file.delete();
        }
      } catch (e, st) {
        AppLogger.debug('Falha ao remover arquivo temporário cancelado ($_currentFilePath): $e', st);
      }
    }
    _currentFilePath = null;
    _lastResult = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _durationController.close();
    try {
      _audioRecorder.dispose();
    } catch (e, st) {
      AppLogger.debug('Falha ao descartar _audioRecorder: $e', st);
    }
  }
}

/// Test double offline-first para gravação de áudio, utilizado estritamente em
/// testes unitários e de widgets sem dependência de microfone nativo.
class LocalAudioRecordingService implements AudioRecordingService {
  final String? defaultFilePath;

  LocalAudioRecordingService({this.defaultFilePath});

  final Uuid _uuid = const Uuid();
  int _maxDurationSeconds = 30;
  bool _isRecording = false;
  Timer? _timer;
  int _elapsedSeconds = 0;
  DateTime? _startedAt;
  String? _currentFilePath;
  RecordingResult? _lastResult;
  bool _hasPermission = true;
  bool _autoGrantOnRequest = false;
  Future<bool> Function()? onRequestPermission;

  void setPermission(bool granted, {bool autoGrantOnRequest = false}) {
    _hasPermission = granted;
    _autoGrantOnRequest = autoGrantOnRequest;
  }

  final StreamController<int> _durationController =
      StreamController<int>.broadcast();

  @override
  bool get isRecording => _isRecording;

  @override
  Stream<int> get recordingDurationStream => _durationController.stream;

  @override
  Future<bool> hasPermission() async => _hasPermission;

  @override
  Future<bool> requestPermission() async {
    if (onRequestPermission != null) {
      final res = await onRequestPermission!();
      _hasPermission = res;
      return res;
    }
    if (_autoGrantOnRequest) {
      _hasPermission = true;
      return true;
    }
    return _hasPermission;
  }

  @override
  Future<String> startRecording({String? customPath, int maxDurationSeconds = 30}) async {
    _maxDurationSeconds = maxDurationSeconds;
    if (_isRecording) {
      await cancelRecording();
    }

    var hasPerm = await hasPermission();
    if (!hasPerm) {
      hasPerm = await requestPermission();
    }
    if (!hasPerm) {
      throw Exception('Permissão de gravação de áudio negada');
    }

    _isRecording = true;
    _elapsedSeconds = 0;
    _startedAt = DateTime.now();
    _lastResult = null;

    if (customPath != null && customPath.isNotEmpty) {
      _currentFilePath = customPath;
    } else if (defaultFilePath != null && defaultFilePath!.isNotEmpty) {
      _currentFilePath = defaultFilePath;
    } else {
      final fileName = 'voice_note_${_uuid.v4()}.m4a';
      if (kIsWeb) {
        _currentFilePath = 'web_storage://$fileName';
      } else {
        try {
          final dir = await getApplicationDocumentsDirectory();
          final voiceDir = Directory('${dir.path}/voice_notes');
          if (!voiceDir.existsSync()) {
            await voiceDir.create(recursive: true);
          }
          _currentFilePath = '${voiceDir.path}/$fileName';
        } catch (e, st) {
          AppLogger.warning('Falha ao criar diretório voice_notes; usando nome relativo', e, st);
          _currentFilePath = fileName;
        }
      }
    }

    _durationController.add(0);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!_isRecording) {
        timer.cancel();
        return;
      }
      _elapsedSeconds++;
      if (!_durationController.isClosed) {
        _durationController.add(_elapsedSeconds);
      }
      // Limite máximo de segurança para nota rápida: 30 segundos
      if (_elapsedSeconds >= _maxDurationSeconds) {
        timer.cancel();
        await stopRecording();
      }
    });

    return _currentFilePath!;
  }

  @override
  Future<RecordingResult?> stopRecording() async {
    if (!_isRecording) return _lastResult;

    _timer?.cancel();
    _timer = null;
    _isRecording = false;

    final duration = Duration(seconds: _elapsedSeconds);
    final recordedAt = _startedAt ?? DateTime.now();
    final path = _currentFilePath ?? 'voice_note_${_uuid.v4()}.m4a';

    int size = 0;
    if (!kIsWeb && !path.startsWith('web_storage://')) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          size = file.lengthSync();
        }
      } catch (e, st) {
        AppLogger.debug('Falha ao inspecionar tamanho do arquivo local ($path): $e', st);
        size = 0;
      }
    }

    _lastResult = RecordingResult(
      filePath: path,
      duration: duration,
      fileSize: size,
      recordedAt: recordedAt,
    );
    return _lastResult;
  }

  @override
  Future<void> cancelRecording() async {
    _timer?.cancel();
    _timer = null;
    _isRecording = false;
    _elapsedSeconds = 0;

    if (_currentFilePath != null &&
        !kIsWeb &&
        !_currentFilePath!.startsWith('web_storage://')) {
      try {
        final file = File(_currentFilePath!);
        if (file.existsSync()) {
          await file.delete();
        }
      } catch (e, st) {
        AppLogger.debug('Falha ao limpar arquivo temporário local ($_currentFilePath): $e', st);
      }
    }
    _currentFilePath = null;
    _lastResult = null;
  }

  /// Método de teste para avançar o tempo e testar a interrupção automática aos 30 segundos
  Future<void> simulateElapsedSeconds(int seconds) async {
    if (!_isRecording) return;
    _elapsedSeconds = seconds;
    if (!_durationController.isClosed) {
      _durationController.add(_elapsedSeconds);
    }
    if (_elapsedSeconds >= _maxDurationSeconds) {
      _timer?.cancel();
      _timer = null;
      await stopRecording();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _durationController.close();
  }
}

typedef FakeAudioRecordingService = LocalAudioRecordingService;

/// Contrato para reprodução de áudio de notas de voz.
abstract class AudioPlayerService {
  bool get isPlaying;
  Stream<Duration> get positionStream;
  Stream<bool> get playingStateStream;

  Future<void> play(String filePath);
  Future<void> pause();
  Future<void> stop();
  void dispose();

  /// Retorna a implementação recomendada para a plataforma atual.
  static AudioPlayerService platform({AudioPlayerService? overrideService}) {
    if (overrideService != null) return overrideService;
    return RealAudioPlayerService();
  }
}

/// Implementação real do player de áudio usando package:audioplayers.
class RealAudioPlayerService implements AudioPlayerService {
  AudioPlayer? _player;
  final StreamController<Duration> _posController =
      StreamController<Duration>.broadcast();
  final StreamController<bool> _stateController =
      StreamController<bool>.broadcast();
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<PlayerState>? _stateSub;
  bool _isPlaying = false;

  RealAudioPlayerService();

  AudioPlayer _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;
    final created = AudioPlayer();
    _player = created;
    _posSub = created.onPositionChanged.listen((pos) {
      if (!_posController.isClosed) {
        _posController.add(pos);
      }
    });
    _stateSub = created.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      if (!_stateController.isClosed) {
        _stateController.add(_isPlaying);
      }
    });
    return created;
  }

  @override
  bool get isPlaying => _isPlaying;

  @override
  Stream<Duration> get positionStream => _posController.stream;

  @override
  Stream<bool> get playingStateStream => _stateController.stream;

  @override
  Future<void> play(String filePath) async {
    try {
      Source source;
      if (kIsWeb ||
          filePath.startsWith('http://') ||
          filePath.startsWith('https://') ||
          filePath.startsWith('blob:') ||
          filePath.startsWith('data:')) {
        source = UrlSource(filePath);
      } else if (filePath.startsWith('asset://') ||
          filePath.startsWith('assets/')) {
        source = AssetSource(
          filePath.replaceFirst('asset://', '').replaceFirst('assets/', ''),
        );
      } else {
        final file = File(filePath);
        if (!file.existsSync() || file.lengthSync() == 0) {
          throw AudioPlaybackException(
            'Arquivo de áudio não existe ou está vazio: $filePath',
          );
        }
        source = DeviceFileSource(filePath);
      }
      await _ensurePlayer().play(source);
    } catch (e) {
      _isPlaying = false;
      if (!_stateController.isClosed) _stateController.add(false);
      rethrow;
    }
  }

  @override
  Future<void> pause() async {
    final player = _player;
    if (player != null) {
      try {
        await player.pause();
      } catch (e, st) {
        AppLogger.debug('Falha ao pausar player de áudio: $e', st);
      }
    }
    _isPlaying = false;
    if (!_stateController.isClosed) _stateController.add(false);
  }

  @override
  Future<void> stop() async {
    final player = _player;
    if (player != null) {
      try {
        await player.stop();
      } catch (e, st) {
        AppLogger.debug('Falha ao parar player de áudio: $e', st);
      }
    }
    _isPlaying = false;
    if (!_stateController.isClosed) _stateController.add(false);
    if (!_posController.isClosed) _posController.add(Duration.zero);
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _stateSub?.cancel();
    _posController.close();
    _stateController.close();
    final player = _player;
    _player = null;
    if (player != null) {
      try {
        player.dispose();
      } catch (e, st) {
        AppLogger.debug('Falha ao descartar AudioPlayer: $e', st);
      }
    }
  }
}

/// Test double offline-first para reprodução de áudio, utilizado estritamente em
/// testes unitários e de widgets sem dependência de drivers nativos de som.
class LocalAudioPlayerService implements AudioPlayerService {
  bool _isPlaying = false;
  Timer? _ticker;
  int _currentPosSeconds = 0;
  final StreamController<Duration> _posController =
      StreamController<Duration>.broadcast();
  final StreamController<bool> _stateController =
      StreamController<bool>.broadcast();

  @override
  bool get isPlaying => _isPlaying;

  @override
  Stream<Duration> get positionStream => _posController.stream;

  @override
  Stream<bool> get playingStateStream => _stateController.stream;

  @override
  Future<void> play(String filePath) async {
    _isPlaying = true;
    _stateController.add(true);
    _currentPosSeconds = 0;
    _posController.add(Duration.zero);

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPlaying) {
        timer.cancel();
        return;
      }
      _currentPosSeconds++;
      if (!_posController.isClosed) {
        _posController.add(Duration(seconds: _currentPosSeconds));
      }
      if (_currentPosSeconds >= 15) {
        stop();
      }
    });
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
    _ticker?.cancel();
    _ticker = null;
    if (!_stateController.isClosed) {
      _stateController.add(false);
    }
  }

  @override
  Future<void> stop() async {
    _isPlaying = false;
    _ticker?.cancel();
    _ticker = null;
    _currentPosSeconds = 0;
    if (!_posController.isClosed) {
      _posController.add(Duration.zero);
    }
    if (!_stateController.isClosed) {
      _stateController.add(false);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    _posController.close();
    _stateController.close();
  }
}

typedef FakeAudioPlayerService = LocalAudioPlayerService;
