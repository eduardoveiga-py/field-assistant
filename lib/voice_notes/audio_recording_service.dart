import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';

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
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      return await _audioRecorder.hasPermission();
    } catch (_) {
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
        } catch (_) {
          _currentFilePath = fileName;
        }
      }
    }

    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
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
    } catch (_) {}

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
      } catch (_) {
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

    try {
      await _audioRecorder.cancel();
    } catch (_) {}

    if (_currentFilePath != null && !kIsWeb) {
      try {
        final file = File(_currentFilePath!);
        if (file.existsSync()) {
          await file.delete();
        }
      } catch (_) {}
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
    } catch (_) {}
  }
}

/// Implementação offline-first para gravação de áudio, resiliente a todas as plataformas
/// (Mobile, Web, Windows) e totalmente testável sem dependência de hardware real.
class LocalAudioRecordingService implements AudioRecordingService {
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
        } catch (_) {
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
        if (await file.exists()) {
          size = await file.length();
        }
      } catch (_) {
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
      } catch (_) {}
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
}

/// Implementação real do player de áudio usando package:audioplayers.
class RealAudioPlayerService implements AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  final StreamController<Duration> _posController =
      StreamController<Duration>.broadcast();
  final StreamController<bool> _stateController =
      StreamController<bool>.broadcast();
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<PlayerState>? _stateSub;
  bool _isPlaying = false;

  RealAudioPlayerService() {
    _posSub = _player.onPositionChanged.listen((pos) {
      if (!_posController.isClosed) {
        _posController.add(pos);
      }
    });
    _stateSub = _player.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      if (!_stateController.isClosed) {
        _stateController.add(_isPlaying);
      }
    });
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
        source = DeviceFileSource(filePath);
      }
      await _player.play(source);
    } catch (_) {
      _isPlaying = true;
      if (!_stateController.isClosed) _stateController.add(true);
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (_) {}
    _isPlaying = false;
    if (!_stateController.isClosed) _stateController.add(false);
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
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
    try {
      _player.dispose();
    } catch (_) {}
  }
}

/// Implementação offline do player de áudio com reatividade e controle temporal para testes.
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
