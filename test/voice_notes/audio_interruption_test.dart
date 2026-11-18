import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ministerio_pessoal/voice_notes/audio_recording_service.dart';
import 'package:ministerio_pessoal/voice_notes/audio_session_bridge.dart';
import 'package:record/record.dart';

class _FakeAudioSessionBridge implements AudioSessionBridge {
  final StreamController<AudioSessionInterruption> _interruptions =
      StreamController<AudioSessionInterruption>.broadcast();
  final StreamController<void> _noisy = StreamController<void>.broadcast();

  final List<AudioSessionRole> activatedRoles = [];
  int deactivateCount = 0;
  bool disposed = false;

  @override
  Future<bool> activate({required AudioSessionRole role}) async {
    activatedRoles.add(role);
    return true;
  }

  @override
  Future<void> deactivate() async {
    deactivateCount++;
  }

  @override
  Stream<AudioSessionInterruption> get interruptionEvents =>
      _interruptions.stream;

  @override
  Stream<void> get becomingNoisyEvents => _noisy.stream;

  void emitInterruption(AudioSessionInterruption event) {
    _interruptions.add(event);
  }

  void emitBecomingNoisy() {
    _noisy.add(null);
  }

  @override
  void dispose() {
    disposed = true;
    _interruptions.close();
    _noisy.close();
  }
}

class _FakeAudioRecorder implements AudioRecorder {
  final StreamController<RecordState> _stateController =
      StreamController<RecordState>.broadcast();
  bool hasPerm = true;
  String? activePath;
  bool started = false;
  int stopCalls = 0;
  int cancelCalls = 0;
  bool disposed = false;

  @override
  Future<bool> hasPermission({bool request = true}) async => hasPerm;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    started = true;
    activePath = path;
    // Simula captura de bytes reais no arquivo de destino durante a gravação.
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(Uint8List.fromList(List.filled(2048, 0x41)));
    _stateController.add(RecordState.record);
  }

  @override
  Future<String?> stop() async {
    stopCalls++;
    started = false;
    _stateController.add(RecordState.stop);
    return activePath;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    started = false;
    _stateController.add(RecordState.stop);
  }

  @override
  Stream<RecordState> onStateChanged() => _stateController.stream;

  @override
  Future<void> dispose() async {
    disposed = true;
    await _stateController.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'RealAudioRecordingService AVAudioSession Interruption Handling (P1-08)',
    () {
      test('configures playAndRecord session and safely preserves audio file on phone call interruption', () async {
        final tempDir = Directory.systemTemp.createTempSync('audio_int_test_');
        addTearDown(() => tempDir.deleteSync(recursive: true));

        final recorder = _FakeAudioRecorder();
        final sessionBridge = _FakeAudioSessionBridge();
        final service = RealAudioRecordingService(
          audioRecorder: recorder,
          sessionBridge: sessionBridge,
        );
        addTearDown(() {
          service.dispose();
          recorder.dispose();
          sessionBridge.dispose();
        });

        final notices = <AudioInterruptionNotice>[];
        final sub = service.interruptionStream.listen(notices.add);
        addTearDown(sub.cancel);

        final targetPath = '${tempDir.path}/visit_note.m4a';
        await service.startRecording(customPath: targetPath);

        expect(service.isRecording, isTrue);
        expect(
          sessionBridge.activatedRoles,
          equals([AudioSessionRole.recording]),
        );

        // Simula chamada telefônica / alarme iOS (AVAudioSessionInterruptionType.began)
        sessionBridge.emitInterruption(
          const AudioSessionInterruption(
            begin: true,
            shouldPause: true,
            reason: 'phone_call',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Gravação deve ter sido finalizada com segurança, SEM apagar o arquivo gravado.
        expect(service.isRecording, isFalse);
        expect(recorder.stopCalls, equals(1));
        expect(recorder.cancelCalls, equals(0));
        expect(sessionBridge.deactivateCount, greaterThanOrEqualTo(1));

        final savedFile = File(targetPath);
        expect(savedFile.existsSync(), isTrue);
        expect(savedFile.lengthSync(), equals(2048));

        expect(notices, hasLength(1));
        expect(
          notices.first.type,
          equals(AudioInterruptionNoticeType.interruptedAndSaved),
        );
        expect(notices.first.savedResult, isNotNull);
        expect(notices.first.savedResult!.fileIntegrityValid, isTrue);
        expect(notices.first.savedResult!.fileSize, equals(2048));

        // Chamar stopRecording() depois da interrupção deve ser idempotente e retornar o resultado preservado.
        final secondStop = await service.stopRecording();
        expect(secondStop, isNotNull);
        expect(secondStop!.filePath, equals(targetPath));
        expect(recorder.stopCalls, equals(1));
      });

      test('preserves recording safely when audio route becomes noisy (Bluetooth/headphone disconnect)', () async {
        final tempDir = Directory.systemTemp.createTempSync('audio_noisy_');
        addTearDown(() => tempDir.deleteSync(recursive: true));

        final recorder = _FakeAudioRecorder();
        final sessionBridge = _FakeAudioSessionBridge();
        final service = RealAudioRecordingService(
          audioRecorder: recorder,
          sessionBridge: sessionBridge,
        );
        addTearDown(() {
          service.dispose();
          recorder.dispose();
          sessionBridge.dispose();
        });

        final notices = <AudioInterruptionNotice>[];
        final sub = service.interruptionStream.listen(notices.add);
        addTearDown(sub.cancel);

        final targetPath = '${tempDir.path}/noisy_note.m4a';
        await service.startRecording(customPath: targetPath);
        expect(service.isRecording, isTrue);

        sessionBridge.emitBecomingNoisy();
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(service.isRecording, isFalse);
        expect(File(targetPath).existsSync(), isTrue);
        expect(File(targetPath).lengthSync(), equals(2048));
        expect(notices, hasLength(1));
        expect(
          notices.first.type,
          equals(AudioInterruptionNoticeType.becomingNoisy),
        );
        expect(notices.first.savedResult?.fileIntegrityValid, isTrue);
      });

      test(
        'emits interruptionEnded notice cleanly after interruption finishes',
        () async {
          final tempDir = Directory.systemTemp.createTempSync('audio_end_');
          addTearDown(() => tempDir.deleteSync(recursive: true));

          final recorder = _FakeAudioRecorder();
          final sessionBridge = _FakeAudioSessionBridge();
          final service = RealAudioRecordingService(
            audioRecorder: recorder,
            sessionBridge: sessionBridge,
          );
          addTearDown(() {
            service.dispose();
            recorder.dispose();
            sessionBridge.dispose();
          });

          final notices = <AudioInterruptionNotice>[];
          final sub = service.interruptionStream.listen(notices.add);
          addTearDown(sub.cancel);

          final targetPath = '${tempDir.path}/end_note.m4a';
          await service.startRecording(customPath: targetPath);

          sessionBridge.emitInterruption(
            const AudioSessionInterruption(
              begin: false,
              shouldPause: false,
              reason: 'ended',
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 30));

          expect(notices, hasLength(1));
          expect(
            notices.first.type,
            equals(AudioInterruptionNoticeType.interruptionEnded),
          );
          await service.stopRecording();
        },
      );

      test(
        'cancelRecording deactivates audio session and removes temporary file',
        () async {
          final tempDir = Directory.systemTemp.createTempSync('audio_cancel_');
          addTearDown(() => tempDir.deleteSync(recursive: true));

          final recorder = _FakeAudioRecorder();
          final sessionBridge = _FakeAudioSessionBridge();
          final service = RealAudioRecordingService(
            audioRecorder: recorder,
            sessionBridge: sessionBridge,
          );
          addTearDown(() {
            service.dispose();
            recorder.dispose();
            sessionBridge.dispose();
          });

          final targetPath = '${tempDir.path}/cancelled_note.m4a';
          await service.startRecording(customPath: targetPath);
          expect(File(targetPath).existsSync(), isTrue);

          await service.cancelRecording();
          expect(service.isRecording, isFalse);
          expect(recorder.cancelCalls, equals(1));
          expect(sessionBridge.deactivateCount, equals(1));
          expect(File(targetPath).existsSync(), isFalse);
        },
      );
    },
  );
}
