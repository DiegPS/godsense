import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/native_speech_controller.dart';
import 'package:godsense/domain/native_speech_settings.dart';
import 'package:godsense/infrastructure/speech/global_push_to_talk_hotkey.dart';
import 'package:godsense/infrastructure/speech/microphone_test_service.dart';
import 'package:godsense/infrastructure/speech/speech/live_captions_service.dart';
import 'package:godsense/infrastructure/speech/tts_service.dart';

void main() {
  late _Speech speech;
  late _Tts tts;
  late _Capture capture;
  late NativeSpeechController controller;
  setUp(() async {
    speech = _Speech();
    tts = _Tts();
    capture = _Capture();
    controller = NativeSpeechController(
      repository: _Settings(),
      speech: speech,
      tts: tts,
      hotkey: _Hotkey(),
      microphoneTest: MicrophoneTestService(capture: capture),
    );
    await controller.initialize();
  });
  tearDown(() => controller.dispose());

  test('a new response arriving during stop keeps the stop control available', () async {
    controller.speak('First');
    tts.stopGate = Completer<void>();
    final stopping = controller.stopSpeaking();
    controller.speak('New response');
    tts.stopGate!.complete();
    await stopping;
    expect(controller.state.ttsBusy, isTrue);
    expect(controller.state.settings.ttsEnabled, isTrue);
  });

  test(
    'the microphone test excludes PTT and speech, then restores normal input',
    () async {
      final testing = controller.testMicrophone();
      await capture.started.future;
      await controller.pressPushToTalk();
      controller.speak('Do not record this advice.');
      expect(speech.configurations, 0);
      expect(tts.spoken, isEmpty);
      final cancelling = controller.cancelMicrophoneTest();
      capture.release.complete();
      await Future.wait([testing, cancelling]);
      await controller.pressPushToTalk();
      expect(speech.configurations, 1);
      await controller.releasePushToTalk();
    },
  );

  test(
    'stopping a response preserves enabled voice and permits another response',
    () async {
      controller.speak('First response');
      expect(controller.state.ttsBusy, isTrue);
      await controller.stopSpeaking();
      expect(controller.state.ttsBusy, isFalse);
      expect(controller.state.settings.ttsEnabled, isTrue);
      controller.speak('Next response');
      expect(tts.spoken, ['First response', 'Next response']);
      expect(controller.state.ttsBusy, isTrue);
      await controller.pressPushToTalk();
      await controller.testMicrophone();
      expect(capture.started.isCompleted, isFalse);
      await controller.releasePushToTalk();
    },
  );
}

class _Settings implements NativeSpeechSettingsRepository {
  @override
  Future<NativeSpeechSettings> load() async =>
      const NativeSpeechSettings(pushToTalkEnabled: true, ttsEnabled: true);
  @override
  Future<void> save(NativeSpeechSettings settings) async {}
}

class _Hotkey implements PushToTalkHotkey {
  @override
  Stream<bool> get transitions => const Stream.empty();
  @override
  void configure({required bool enabled, required String key}) {}
  @override
  void dispose() {}
}

class _Speech extends LiveCaptionsService {
  int configurations = 0;
  @override
  Future<bool> isModelInstalled() async => true;
  @override
  Future<void> updateConfig({
    required bool enabled,
    required String sourceLanguage,
    required String targetLanguage,
    required bool denoise,
  }) async {
    configurations++;
  }

  @override
  Future<String> finishUtterance({
    Duration timeout = const Duration(seconds: 10),
  }) async => '';
  @override
  Future<void> stop({bool emitIdle = true}) async {}
}

class _Tts extends TtsService {
  bool currentBusy = false;
  Completer<void>? stopGate;
  @override
  bool get isBusy => currentBusy;
  final busy = StreamController<bool>.broadcast(sync: true);
  final spoken = <String>[];
  @override
  Stream<bool> get busyStream => busy.stream;
  @override
  Future<bool> isModelInstalled(String id) async => true;
  @override
  Future<void> updateConfig({
    required bool enabled,
    required String modelId,
    required String voice,
    required String language,
    required double speed,
    required int steps,
    required String referenceAudioPath,
    required String referenceText,
  }) async {}
  @override
  void speak(String text, {bool allowDownload = false}) {
    spoken.add(text);
    currentBusy = true;
    busy.add(true);
  }

  @override
  Future<void> stop({bool unload = false}) async {
    currentBusy = false;
    if (!busy.isClosed) busy.add(false);
    await stopGate?.future;
  }

  @override
  Future<void> dispose() async {
    await super.dispose();
    await busy.close();
  }
}

class _Capture implements SpeechAudioCapture {
  final started = Completer<void>();
  final release = Completer<void>();
  final stream = StreamController<Uint8List>();
  @override
  Future<Stream<Uint8List>> start() async {
    started.complete();
    await release.future;
    return stream.stream;
  }

  @override
  Future<void> stop() async {
    if (!stream.isClosed) unawaited(stream.close());
  }

  @override
  Future<void> dispose() => stop();
}
