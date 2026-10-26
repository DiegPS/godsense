import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/native_speech_controller.dart';
import 'package:godsense/domain/native_speech_settings.dart';
import 'package:godsense/infrastructure/speech/global_push_to_talk_hotkey.dart';
import 'package:godsense/infrastructure/speech/speech/live_captions_service.dart';
import 'package:godsense/infrastructure/speech/tts_service.dart';

void main() {
  late _Repository repository;
  late _Speech speech;
  late _Tts tts;
  late _Hotkey hotkey;
  late NativeSpeechController controller;
  var disposed = false;
  setUp(() {
    disposed = false;
    repository = _Repository();
    speech = _Speech();
    tts = _Tts();
    hotkey = _Hotkey();
    controller = NativeSpeechController(
      repository: repository,
      speech: speech,
      tts: tts,
      hotkey: hotkey,
    );
  });
  tearDown(() {
    if (!disposed) controller.dispose();
  });
  void close() {
    disposed = true;
    controller.dispose();
  }

  test(
    'a requested queued preference write survives controller disposal',
    () async {
      final gate = Completer<void>();
      repository.modelSaveGates['supertonic-3-hybrid'] = gate.future;
      final older = controller.updateSettings(const NativeSpeechSettings());
      await repository.savingStarted.future;
      final newer = controller.updateSettings(
        const NativeSpeechSettings(ttsModelId: 'kokoro-en-v0-19-int8'),
      );
      close();
      gate.complete();
      await Future.wait([older, newer]);
      expect(repository.saved?.ttsModelId, 'kokoro-en-v0-19-int8');
      expect(hotkey.configurations, 0);
      expect(tts.configuredModels, isEmpty);
    },
  );

  test(
    'failed older save does not block or mark a newer selection as failed',
    () async {
      final gate = Completer<void>();
      repository.modelSaveGates['supertonic-3-hybrid'] = gate.future;
      final older = expectLater(
        controller.updateSettings(const NativeSpeechSettings()),
        throwsStateError,
      );
      await repository.savingStarted.future;
      final newer = controller.updateSettings(
        const NativeSpeechSettings(ttsModelId: 'kokoro-en-v0-19-int8'),
      );
      gate.completeError(StateError('synthetic old save failure'));
      await Future.wait([older, newer]);
      expect(repository.saved?.ttsModelId, 'kokoro-en-v0-19-int8');
      expect(controller.state.error, isNull);
    },
  );

  test(
    'old TTS download cannot mark a different selected model as installed',
    () async {
      final gate = Completer<bool>();
      tts.installed['supertonic-3-hybrid'] = gate.future;
      tts.installed['kokoro-en-v0-19-int8'] = Future.value(false);
      final downloading = controller.downloadTtsModel();
      await tts.checked.future;
      await controller.updateSettings(
        const NativeSpeechSettings(ttsModelId: 'kokoro-en-v0-19-int8'),
      );
      gate.complete(true);
      await downloading;
      expect(controller.state.settings.ttsModelId, 'kokoro-en-v0-19-int8');
      expect(controller.state.ttsModelInstalled, isFalse);
    },
  );

  test(
    'speech download completion preserves settings changed during its check',
    () async {
      final gate = Completer<bool>();
      speech.installed = gate.future;
      final downloading = controller.downloadSpeechModel();
      await speech.checked.future;
      speech.installed = null;
      await controller.updateSettings(
        const NativeSpeechSettings(ttsModelId: 'kokoro-en-v0-19-int8'),
      );
      gate.complete(true);
      await downloading;
      expect(controller.state.settings.ttsModelId, 'kokoro-en-v0-19-int8');
      expect(controller.state.speechModelInstalled, isTrue);
    },
  );

  test(
    'late startup preferences cannot undo a newer voice selection',
    () async {
      final gate = Completer<NativeSpeechSettings>();
      repository.loadGate = gate.future;
      final initializing = controller.initialize();
      await controller.updateSettings(
        const NativeSpeechSettings(ttsModelId: 'kokoro-en-v0-19-int8'),
      );
      gate.complete(const NativeSpeechSettings());
      await initializing;
      expect(controller.state.settings.ttsModelId, 'kokoro-en-v0-19-int8');
      expect(controller.state.loading, isFalse);
      expect(tts.configuredModels.last, 'kokoro-en-v0-19-int8');
    },
  );

  test(
    'overlapping preference writes persist the newest selected model',
    () async {
      final gate = Completer<void>();
      repository.modelSaveGates['supertonic-3-hybrid'] = gate.future;
      final older = controller.updateSettings(const NativeSpeechSettings());
      await repository.savingStarted.future;
      final newer = controller.updateSettings(
        const NativeSpeechSettings(ttsModelId: 'kokoro-en-v0-19-int8'),
      );
      await Future<void>.delayed(Duration.zero);
      gate.complete();
      await Future.wait([older, newer]);
      expect(repository.saved?.ttsModelId, 'kokoro-en-v0-19-int8');
      expect(controller.state.settings.ttsModelId, 'kokoro-en-v0-19-int8');
      expect(tts.configuredModels.last, 'kokoro-en-v0-19-int8');
    },
  );

  test(
    'late failed settings save preserves its original error after disposal',
    () async {
      final gate = Completer<void>();
      repository.saveGate = gate.future;
      final updating = controller.updateSettings(
        const NativeSpeechSettings(ttsEnabled: true),
      );
      await repository.savingStarted.future;
      final error = StateError('synthetic failed preferences write');
      final checked = expectLater(updating, throwsA(same(error)));
      close();
      gate.completeError(error);
      await checked;
    },
  );

  test(
    'late successful save never reconfigures disposed audio or hotkey services',
    () async {
      final gate = Completer<void>();
      repository.saveGate = gate.future;
      final updating = controller.updateSettings(const NativeSpeechSettings());
      await repository.savingStarted.future;
      close();
      gate.complete();
      await expectLater(updating, completes);
      expect(hotkey.configurations, 0);
      expect(tts.configuredModels, isEmpty);
    },
  );

  test(
    'late speech model installed check is harmless after disposal',
    () async {
      final gate = Completer<bool>();
      speech.installed = gate.future;
      final downloading = controller.downloadSpeechModel();
      await speech.checked.future;
      close();
      gate.complete(true);
      await expectLater(downloading, completes);
    },
  );

  test('late TTS model installed check is harmless after disposal', () async {
    final gate = Completer<bool>();
    tts.installed['supertonic-3-hybrid'] = gate.future;
    final downloading = controller.downloadTtsModel();
    await tts.checked.future;
    close();
    gate.complete(true);
    await expectLater(downloading, completes);
  });

  test(
    'newest voice selection owns model status and final TTS configuration',
    () async {
      final oldCheck = Completer<bool>();
      tts.installed['supertonic-3-hybrid'] = oldCheck.future;
      tts.installed['kokoro-en-v0-19-int8'] = Future.value(false);
      final oldUpdate = controller.updateSettings(const NativeSpeechSettings());
      await tts.checked.future;
      await controller.updateSettings(
        const NativeSpeechSettings(ttsModelId: 'kokoro-en-v0-19-int8'),
      );
      expect(controller.state.settings.ttsModelId, 'kokoro-en-v0-19-int8');
      expect(controller.state.ttsModelInstalled, isFalse);
      oldCheck.complete(true);
      await oldUpdate;
      expect(controller.state.ttsModelInstalled, isFalse);
      expect(tts.configuredModels, ['kokoro-en-v0-19-int8']);
    },
  );
}

class _Repository implements NativeSpeechSettingsRepository {
  Future<NativeSpeechSettings>? loadGate;
  Future<void>? saveGate;
  final modelSaveGates = <String, Future<void>>{};
  final savingStarted = Completer<void>();
  NativeSpeechSettings? saved;
  @override
  Future<NativeSpeechSettings> load() async =>
      await (loadGate ?? Future.value(const NativeSpeechSettings()));
  @override
  Future<void> save(NativeSpeechSettings settings) async {
    if (!savingStarted.isCompleted) savingStarted.complete();
    await (modelSaveGates[settings.ttsModelId] ?? saveGate);
    saved = settings;
  }
}

class _Hotkey implements PushToTalkHotkey {
  int configurations = 0;
  bool disposed = false;
  @override
  Stream<bool> get transitions => const Stream.empty();
  @override
  void configure({required bool enabled, required String key}) {
    if (disposed) throw StateError('disposed fixture hotkey was reconfigured');
    configurations++;
  }

  @override
  void dispose() => disposed = true;
}

class _Speech extends LiveCaptionsService {
  Future<bool>? installed;
  final checked = Completer<void>();
  @override
  Future<void> prepareModel() async {}
  @override
  Future<bool> isModelInstalled() {
    if (!checked.isCompleted) checked.complete();
    return installed ?? Future.value(true);
  }

  @override
  Future<void> stop({bool emitIdle = true}) async {}
}

class _Tts extends TtsService {
  final installed = <String, Future<bool>>{};
  final checked = Completer<void>();
  final configuredModels = <String>[];
  @override
  Future<void> prepareModel() async {}
  @override
  Future<bool> isModelInstalled(String id) {
    if (!checked.isCompleted) checked.complete();
    return installed[id] ?? Future.value(true);
  }

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
  }) async {
    configuredModels.add(modelId);
  }

  @override
  Future<void> stop({bool unload = false}) async {}
}
