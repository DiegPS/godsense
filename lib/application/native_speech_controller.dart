// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/native_speech_settings.dart';
import '../infrastructure/speech/global_push_to_talk_hotkey.dart';
import '../infrastructure/speech/shared_preferences_speech_settings_repository.dart';
import '../infrastructure/speech/speech/live_captions_service.dart';
import '../infrastructure/speech/tts/tts_model_catalog.dart';
import '../infrastructure/speech/tts_service.dart';

class NativeSpeechState {
  const NativeSpeechState({
    this.loading = true,
    this.settings = const NativeSpeechSettings(),
    this.speech = const LiveCaptionsState(),
    this.tts = const TtsLoadState(),
    this.ttsBusy = false,
    this.modelsChecked = false,
    this.speechModelInstalled = false,
    this.ttsModelInstalled = false,
    this.pushToTalkPressed = false,
    this.transcript = '',
    this.lastTranscriptAt,
    this.error,
  });

  final bool loading;
  final NativeSpeechSettings settings;
  final LiveCaptionsState speech;
  final TtsLoadState tts;
  final bool ttsBusy;
  final bool modelsChecked;
  final bool speechModelInstalled;
  final bool ttsModelInstalled;
  final bool pushToTalkPressed;
  final String transcript;
  final DateTime? lastTranscriptAt;
  final String? error;

  NativeSpeechState copyWith({
    bool? loading,
    NativeSpeechSettings? settings,
    LiveCaptionsState? speech,
    TtsLoadState? tts,
    bool? ttsBusy,
    bool? modelsChecked,
    bool? speechModelInstalled,
    bool? ttsModelInstalled,
    bool? pushToTalkPressed,
    String? transcript,
    DateTime? lastTranscriptAt,
    String? error,
    bool clearError = false,
  }) => NativeSpeechState(
    loading: loading ?? this.loading,
    settings: settings ?? this.settings,
    speech: speech ?? this.speech,
    tts: tts ?? this.tts,
    ttsBusy: ttsBusy ?? this.ttsBusy,
    modelsChecked: modelsChecked ?? this.modelsChecked,
    speechModelInstalled: speechModelInstalled ?? this.speechModelInstalled,
    ttsModelInstalled: ttsModelInstalled ?? this.ttsModelInstalled,
    pushToTalkPressed: pushToTalkPressed ?? this.pushToTalkPressed,
    transcript: transcript ?? this.transcript,
    lastTranscriptAt: lastTranscriptAt ?? this.lastTranscriptAt,
    error: clearError ? null : error ?? this.error,
  );
}

final nativeSpeechSettingsRepositoryProvider =
    Provider<NativeSpeechSettingsRepository>(
      (_) => SharedPreferencesSpeechSettingsRepository(),
    );

final nativeSpeechProvider =
    StateNotifierProvider<NativeSpeechController, NativeSpeechState>((ref) {
      final controller = NativeSpeechController(
        repository: ref.watch(nativeSpeechSettingsRepositoryProvider),
      );
      unawaited(controller.initialize());
      ref.onDispose(controller.disposeServices);
      return controller;
    });

class NativeSpeechController extends StateNotifier<NativeSpeechState> {
  NativeSpeechController({
    required NativeSpeechSettingsRepository repository,
    LiveCaptionsService? speech,
    TtsService? tts,
    PushToTalkHotkey? hotkey,
  }) : _repository = repository,
       _speech = speech ?? LiveCaptionsService(),
       _tts = tts ?? TtsService(),
       _hotkey = hotkey ?? GlobalPushToTalkHotkey(),
       super(const NativeSpeechState());

  final NativeSpeechSettingsRepository _repository;
  final LiveCaptionsService _speech;
  final TtsService _tts;
  final PushToTalkHotkey _hotkey;
  final _transcripts = StreamController<String>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Future<void>? _pressOperation;
  bool _holding = false;
  bool _disposed = false;

  Stream<String> get transcripts => _transcripts.stream;

  Future<void> initialize() async {
    _subscriptions.add(
      _speech.states.listen((speech) {
        if (!_disposed) state = state.copyWith(speech: speech);
      }),
    );
    _subscriptions.add(
      _tts.loadStateStream.listen((tts) {
        if (!_disposed) state = state.copyWith(tts: tts);
      }),
    );
    _subscriptions.add(
      _tts.busyStream.listen((busy) {
        if (!_disposed) state = state.copyWith(ttsBusy: busy);
      }),
    );
    _subscriptions.add(
      _tts.playbackErrors.listen((error) {
        if (!_disposed) state = state.copyWith(error: error.toString());
      }),
    );
    _subscriptions.add(
      _hotkey.transitions.listen((pressed) {
        if (pressed) {
          unawaited(pressPushToTalk());
        } else {
          unawaited(releasePushToTalk());
        }
      }),
    );
    try {
      final settings = await _repository.load();
      if (_disposed) return;
      state = state.copyWith(
        loading: false,
        settings: settings,
        modelsChecked: false,
        clearError: true,
      );
      _configureHotkey(settings);
      final installed = await Future.wait([
        _speech.isModelInstalled(),
        _tts.isModelInstalled(settings.ttsModelId),
      ]);
      if (_disposed) return;
      state = state.copyWith(
        modelsChecked: true,
        speechModelInstalled: installed[0],
        ttsModelInstalled: installed[1],
      );
      await _configureTts(settings);
    } catch (error) {
      if (!_disposed) {
        state = state.copyWith(loading: false, error: error.toString());
      }
    }
  }

  Future<void> updateSettings(NativeSpeechSettings settings) async {
    final previousState = state;
    final model = TtsModelCatalog.byId(settings.ttsModelId);
    final normalized = settings.copyWith(
      ttsModelId: model.id,
      ttsVoice: model.voice(settings.ttsVoice).id,
      ttsLanguage: model.supportsLanguage(settings.ttsLanguage)
          ? settings.ttsLanguage
          : model.languages.first.code,
      ttsSpeed: settings.ttsSpeed.clamp(0.6, 1.6),
      ttsSteps: settings.ttsSteps.clamp(2, 16),
    );
    final modelChanged =
        normalized.ttsModelId != previousState.settings.ttsModelId;
    final needsInstallCheck = modelChanged || !previousState.modelsChecked;
    state = state.copyWith(
      settings: normalized,
      modelsChecked: needsInstallCheck ? false : previousState.modelsChecked,
      clearError: true,
    );
    try {
      await _repository.save(normalized);
      _configureHotkey(normalized);
      final installed = needsInstallCheck
          ? await Future.wait([
              _speech.isModelInstalled(),
              _tts.isModelInstalled(normalized.ttsModelId),
            ])
          : [
              previousState.speechModelInstalled,
              previousState.ttsModelInstalled,
            ];
      if (_disposed) return;
      state = state.copyWith(
        modelsChecked: true,
        speechModelInstalled: installed[0],
        ttsModelInstalled: installed[1],
      );
      await _configureTts(normalized);
    } catch (error) {
      state = state.copyWith(error: error.toString());
      rethrow;
    }
  }

  Future<void> pressPushToTalk() async {
    if (_disposed || _holding || !state.settings.pushToTalkEnabled) return;
    _holding = true;
    state = state.copyWith(
      pushToTalkPressed: true,
      transcript: '',
      clearError: true,
    );
    final operation = _speech.updateConfig(
      enabled: true,
      sourceLanguage: state.settings.sttLanguage,
      targetLanguage: state.settings.sttLanguage,
      denoise: state.settings.sttDenoise,
    );
    _pressOperation = operation;
    try {
      await operation;
    } catch (error) {
      if (!_disposed) state = state.copyWith(error: error.toString());
    } finally {
      if (identical(_pressOperation, operation)) _pressOperation = null;
    }
  }

  Future<void> releasePushToTalk() async {
    if (_disposed || !_holding) return;
    _holding = false;
    state = state.copyWith(pushToTalkPressed: false);
    try {
      await _pressOperation;
      final transcript = await _speech.finishUtterance();
      if (_disposed) return;
      state = state.copyWith(
        transcript: transcript,
        lastTranscriptAt: transcript.isEmpty ? null : DateTime.now(),
        clearError: true,
      );
      if (transcript.isNotEmpty && !_transcripts.isClosed) {
        _transcripts.add(transcript);
      }
    } catch (error) {
      if (!_disposed) state = state.copyWith(error: error.toString());
    }
  }

  Future<void> downloadSpeechModel() async {
    await _speech.prepareModel();
    if (_disposed) return;
    state = state.copyWith(
      modelsChecked: true,
      speechModelInstalled: await _speech.isModelInstalled(),
    );
  }

  Future<void> downloadTtsModel() async {
    await _tts.prepareModel();
    if (_disposed) return;
    state = state.copyWith(
      modelsChecked: true,
      ttsModelInstalled: await _tts.isModelInstalled(state.settings.ttsModelId),
    );
  }

  Future<void> removeTtsModel(String modelId) async {
    await _tts.removeModel(modelId);
    if (_disposed || modelId != state.settings.ttsModelId) return;
    state = state.copyWith(ttsModelInstalled: false, modelsChecked: true);
  }

  void speak(String text) {
    if (!state.settings.ttsEnabled) return;
    _tts.speak(text);
  }

  Future<void> testTts([
    String text = 'GodSense está listo para ayudarte.',
  ]) async {
    if (!state.ttsModelInstalled) return;
    await _configureTts(state.settings.copyWith(ttsEnabled: true));
    _tts.speak(text);
  }

  void _configureHotkey(NativeSpeechSettings settings) => _hotkey.configure(
    enabled: settings.pushToTalkEnabled,
    key: settings.pushToTalkKey,
  );

  Future<void> _configureTts(NativeSpeechSettings settings) =>
      _tts.updateConfig(
        enabled: settings.ttsEnabled,
        modelId: settings.ttsModelId,
        voice: settings.ttsVoice,
        language: settings.ttsLanguage,
        speed: settings.ttsSpeed,
        steps: settings.ttsSteps,
        referenceAudioPath: settings.referenceAudioPath,
        referenceText: settings.referenceText,
      );

  void disposeServices() {
    if (_disposed) return;
    _disposed = true;
    _hotkey.dispose();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    unawaited(_speech.dispose());
    unawaited(_tts.dispose());
    unawaited(_transcripts.close());
  }

  @override
  void dispose() {
    disposeServices();
    super.dispose();
  }
}
