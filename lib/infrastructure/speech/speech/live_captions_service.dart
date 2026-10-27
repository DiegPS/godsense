import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../sherpa_cpu_thread_policy.dart';
import '../native_worker_guard.dart';
import '../tts_model_cache.dart';
import 'speech_model_catalog.dart';

enum LiveCaptionsPhase {
  idle,
  missingModel,
  downloading,
  loading,
  listening,
  transcribing,
  error,
}

class LiveCaptionsState {
  const LiveCaptionsState({
    this.phase = LiveCaptionsPhase.idle,
    this.caption = '',
    this.message = '',
    this.error,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.speechDetected = false,
    this.captionFinal = false,
  });

  final LiveCaptionsPhase phase;
  final String caption;
  final String message;
  final String? error;
  final int receivedBytes;
  final int totalBytes;
  final bool speechDetected;
  final bool captionFinal;

  double? get progress =>
      totalBytes == 0 ? null : (receivedBytes / totalBytes).clamp(0.0, 1.0);

  bool get isListening =>
      phase == LiveCaptionsPhase.listening ||
      phase == LiveCaptionsPhase.transcribing;
}

abstract interface class SpeechAudioCapture {
  Future<Stream<Uint8List>> start();
  Future<void> stop();
  Future<void> dispose();
}

typedef CaptionsWorkerEntrypoint = void Function(Map<String, Object> startup);

class RecordSpeechAudioCapture implements SpeechAudioCapture {
  AudioRecorder? _recorder;

  AudioRecorder get _instance => _recorder ??= AudioRecorder();

  @override
  Future<Stream<Uint8List>> start() => _instance.startStream(
    const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
      autoGain: false,
      echoCancel: false,
      noiseSuppress: false,
    ),
  );

  @override
  Future<void> stop() async {
    await _recorder?.stop();
  }

  @override
  Future<void> dispose() async {
    await _recorder?.dispose();
    _recorder = null;
  }
}

class LiveCaptionsService {
  LiveCaptionsService({
    TtsModelCache? modelCache,
    SpeechAudioCapture? audioCapture,
    CaptionsWorkerEntrypoint? workerEntrypoint,
  }) : _modelCache = modelCache ?? TtsModelCache(),
       _audioCapture = audioCapture ?? RecordSpeechAudioCapture(),
       _workerEntrypoint = workerEntrypoint ?? _workerMain;

  final TtsModelCache _modelCache;
  final SpeechAudioCapture _audioCapture;
  final CaptionsWorkerEntrypoint _workerEntrypoint;
  final _states = StreamController<LiveCaptionsState>.broadcast();
  LiveCaptionsState _state = const LiveCaptionsState();
  StreamSubscription<Uint8List>? _audioSubscription;
  TtsDownloadCancellation? _downloadCancellation;
  Isolate? _worker;
  SendPort? _commands;
  ReceivePort? _events;
  NativeWorkerGuard? _workerGuard;
  bool _enabled = false;
  bool _disposed = false;
  String _sourceLanguage = 'es';
  String _targetLanguage = 'es';
  bool _denoise = true;
  int _revision = 0;
  final List<String> _utteranceCaptions = [];
  Completer<void>? _flushCompleter;
  Future<void>? _stopping;

  Stream<LiveCaptionsState> get states async* {
    yield _state;
    yield* _states.stream;
  }

  LiveCaptionsState get currentState => _state;

  Future<bool> isModelInstalled() async =>
      await _modelCache.installed(SpeechModelCatalog.canary.package) != null;

  Future<void> updateConfig({
    required bool enabled,
    required String sourceLanguage,
    required String targetLanguage,
    required bool denoise,
  }) async {
    if (_disposed) return;
    final model = SpeechModelCatalog.canary;
    final nextSource = model.supportsLanguage(sourceLanguage)
        ? sourceLanguage
        : model.languages.first.code;
    final nextTarget = model.supportsDirection(nextSource, targetLanguage)
        ? targetLanguage
        : nextSource;
    final changed =
        nextSource != _sourceLanguage ||
        nextTarget != _targetLanguage ||
        denoise != _denoise;
    _sourceLanguage = nextSource;
    _targetLanguage = nextTarget;
    _denoise = denoise;
    _enabled = enabled;
    final revision = ++_revision;
    if (!enabled) {
      await stop();
      return;
    }
    if (changed || _stopping != null) await _stopCurrent(emitIdle: false);
    if (revision != _revision) return;
    final installation = await _modelCache.installed(model.package);
    if (revision != _revision) return;
    if (installation == null) {
      _emit(
        LiveCaptionsState(
          phase: LiveCaptionsPhase.missingModel,
          message: 'Download the caption model to start.',
          totalBytes: model.package.downloadBytes,
        ),
      );
      return;
    }
    try {
      await _start(installation, revision: revision);
    } catch (error) {
      if (revision != _revision || !_enabled || _disposed) return;
      await stop(emitIdle: false);
      _emit(
        LiveCaptionsState(
          phase: LiveCaptionsPhase.error,
          message: 'Offline captions could not start.',
          error: error.toString(),
        ),
      );
    }
  }

  /// Model downloads are only initiated by this explicit UI action.
  Future<void> prepareModel() async {
    if (_disposed) return;
    final model = SpeechModelCatalog.canary;
    final cancellation = TtsDownloadCancellation();
    _downloadCancellation?.cancel();
    _downloadCancellation = cancellation;
    bool current() =>
        !_disposed &&
        !cancellation.isCancelled &&
        identical(_downloadCancellation, cancellation);
    try {
      final installation = await _modelCache.ensureAvailable(
        model.package,
        cancellation: cancellation,
        onProgress: (progress) {
          if (!current()) return;
          _emit(
            LiveCaptionsState(
              phase: progress.phase == TtsInstallPhase.downloading
                  ? LiveCaptionsPhase.downloading
                  : LiveCaptionsPhase.loading,
              message: progress.message,
              receivedBytes: progress.receivedBytes,
              totalBytes: progress.totalBytes,
            ),
          );
        },
      );
      if (!current()) return;
      if (_enabled) {
        await _start(installation, revision: _revision);
      } else {
        _emit(
          const LiveCaptionsState(message: 'Offline caption model is ready.'),
        );
      }
    } on TtsDownloadCancelledException {
      if (current()) _emit(const LiveCaptionsState());
    } catch (error) {
      if (current()) {
        _emit(
          LiveCaptionsState(
            phase: LiveCaptionsPhase.error,
            message: 'The caption model could not be prepared.',
            error: error.toString(),
          ),
        );
      }
      rethrow;
    } finally {
      if (identical(_downloadCancellation, cancellation)) {
        _downloadCancellation = null;
      }
    }
  }

  Future<void> _start(
    TtsModelInstallation installation, {
    required int revision,
  }) async {
    if (_commands != null || _disposed || !_enabled) return;
    _utteranceCaptions.clear();
    _emit(
      const LiveCaptionsState(
        phase: LiveCaptionsPhase.loading,
        message: 'Loading offline captions…',
      ),
    );
    final ready = ReceivePort();
    late final NativeWorkerGuard guard;
    guard = NativeWorkerGuard(
      label: 'Offline captions worker',
      onFailure: (error, failedAfterReady) =>
          _handleWorkerFailure(guard, error, failedAfterReady),
    );
    _workerGuard = guard;
    Isolate? worker;
    Object? first;
    try {
      worker = await Isolate.spawn(
        _workerEntrypoint,
        <String, Object>{
          'reply': ready.sendPort,
          'directory': installation.directory.path,
          'files': SpeechModelCatalog.canary.modelFiles,
          'sourceLanguage': _sourceLanguage,
          'targetLanguage': _targetLanguage,
          'threads': SherpaCpuThreadPolicy.recommended(),
          'denoise': _denoise,
          'nativeLibraryDirectory':
              Platform.environment['GODSENSE_SHERPA_LIBRARY_DIR'] ??
              File(Platform.resolvedExecutable).parent.path,
        },
        errorsAreFatal: true,
        onError: guard.errorPort.sendPort,
        onExit: guard.exitPort.sendPort,
      );
      _worker = worker;
      first = await Future.any<Object?>([
        ready.first,
        guard.failure.then<Object?>((error) => throw error),
      ]).timeout(const Duration(minutes: 2));
      if (first is! SendPort) {
        throw StateError('Caption worker failed to initialize: $first');
      }
      if (!identical(_workerGuard, guard)) {
        throw StateError('Caption worker stopped during initialization.');
      }
      _commands = first;
      guard.markReady();
    } catch (_) {
      worker?.kill(priority: Isolate.immediate);
      if (identical(_workerGuard, guard)) {
        _workerGuard = null;
        _worker = null;
        _commands = null;
      }
      await guard.dispose(expectedExit: true);
      rethrow;
    } finally {
      ready.close();
    }
    if (revision != _revision || !_enabled || _disposed) {
      first.send({'type': 'dispose'});
      if (identical(_workerGuard, guard)) {
        _workerGuard = null;
        _worker = null;
        _commands = null;
      }
      await guard.dispose(expectedExit: true);
      return;
    }
    final events = ReceivePort();
    _events = events;
    _commands!.send({'type': 'listen', 'reply': events.sendPort});
    events.listen((dynamic event) {
      if (event is! Map) return;
      final text = event['caption'] as String?;
      if (text != null && text.trim().isNotEmpty) {
        _utteranceCaptions.add(text.trim());
      }
      if (event['flushDone'] == true) {
        final completer = _flushCompleter;
        _flushCompleter = null;
        if (completer != null && !completer.isCompleted) completer.complete();
      }
      final detected = event['speechDetected'] == true;
      _emit(
        LiveCaptionsState(
          phase: detected
              ? LiveCaptionsPhase.transcribing
              : LiveCaptionsPhase.listening,
          caption: text ?? _state.caption,
          message: detected ? 'Transcribing locally…' : 'Listening locally…',
          speechDetected: detected,
          captionFinal: text != null && text.trim().isNotEmpty,
        ),
      );
    });

    final stream = await _audioCapture.start();
    if (revision != _revision || !_enabled || _disposed) {
      await _audioCapture.stop();
      return;
    }
    _audioSubscription = stream.listen(
      (bytes) => _commands?.send({
        'type': 'audio',
        'bytes': TransferableTypedData.fromList([bytes]),
      }),
      onError: (Object error) => _emit(
        LiveCaptionsState(
          phase: LiveCaptionsPhase.error,
          message: 'Microphone capture stopped.',
          error: error.toString(),
        ),
      ),
    );
    _emit(
      const LiveCaptionsState(
        phase: LiveCaptionsPhase.listening,
        message: 'Listening locally…',
      ),
    );
  }

  /// Stops capture, flushes Silero VAD, and returns the complete PTT utterance.
  Future<String> finishUtterance({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    try {
      await _audioCapture.stop();
    } catch (_) {}
    final commands = _commands;
    if (commands != null) {
      final completer = Completer<void>();
      _flushCompleter = completer;
      commands.send({'type': 'flush'});
      try {
        await completer.future.timeout(timeout);
      } on TimeoutException {
        if (identical(_flushCompleter, completer)) _flushCompleter = null;
      }
    }
    final transcript = _utteranceCaptions.join(' ').trim();
    await stop();
    return transcript;
  }

  Future<void> stop({bool emitIdle = true}) async {
    _enabled = false;
    ++_revision;
    await _stopCurrent(emitIdle: emitIdle);
  }

  Future<void> _stopCurrent({bool emitIdle = true}) async {
    final operation = _stopping ??= _stopWorker();
    try {
      await operation;
    } finally {
      if (identical(_stopping, operation)) _stopping = null;
    }
    if (emitIdle) _emit(const LiveCaptionsState());
  }

  Future<void> _stopWorker() async {
    _downloadCancellation?.cancel();
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    try {
      await _audioCapture.stop();
    } catch (_) {}
    final commands = _commands;
    _commands = null;
    _events?.close();
    _events = null;
    final flush = _flushCompleter;
    _flushCompleter = null;
    if (flush != null && !flush.isCompleted) flush.complete();
    final guard = _workerGuard;
    _workerGuard = null;
    await guard?.dispose(expectedExit: true);
    final worker = _worker;
    _worker = null;
    if (commands == null) {
      worker?.kill(priority: Isolate.beforeNextEvent);
    } else {
      final released = ReceivePort();
      try {
        commands.send({'type': 'dispose', 'reply': released.sendPort});
        // Let VAD, denoiser and recognizer release their native models before
        // falling back to terminating an unresponsive worker.
        await released.first.timeout(const Duration(seconds: 3));
      } catch (_) {
        worker?.kill(priority: Isolate.beforeNextEvent);
      } finally {
        released.close();
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await stop();
    await _audioCapture.dispose();
    await _states.close();
  }

  void _handleWorkerFailure(
    NativeWorkerGuard guard,
    Object error,
    bool failedAfterReady,
  ) {
    if (!identical(_workerGuard, guard)) return;
    _workerGuard = null;
    _commands = null;
    _worker = null;
    _events?.close();
    _events = null;
    unawaited(guard.dispose(expectedExit: false));
    if (failedAfterReady && !_disposed) {
      ++_revision;
      _emit(
        LiveCaptionsState(
          phase: LiveCaptionsPhase.error,
          message: 'Offline captions stopped unexpectedly.',
          error: error.toString(),
        ),
      );
      unawaited(_stopCaptureAfterWorkerFailure());
    }
  }

  Future<void> _stopCaptureAfterWorkerFailure() async {
    final subscription = _audioSubscription;
    _audioSubscription = null;
    await subscription?.cancel();
    try {
      await _audioCapture.stop();
    } catch (_) {}
  }

  void _emit(LiveCaptionsState state) {
    if (_disposed) return;
    _state = state;
    _states.add(state);
  }

  static void _workerMain(Map<String, Object> startup) {
    final owner = startup['reply']! as SendPort;
    if (Platform.isWindows) {
      final directory = startup['nativeLibraryDirectory']! as String;
      DynamicLibrary.open('$directory\\onnxruntime.dll');
      DynamicLibrary.open('$directory\\sherpa-onnx-c-api.dll');
    }
    sherpa.initBindings();
    final directory = startup['directory']! as String;
    final files = Map<String, String>.from(startup['files']! as Map);
    String file(String key) =>
        '$directory${Platform.pathSeparator}${files[key]}';
    final source = startup['sourceLanguage']! as String;
    final target = startup['targetLanguage']! as String;
    final threads = startup['threads']! as int;
    sherpa.OfflineRecognizer? recognizer;
    sherpa.VoiceActivityDetector? vad;
    sherpa.OnlineSpeechDenoiser? denoiser;
    try {
      recognizer = sherpa.OfflineRecognizer(
        sherpa.OfflineRecognizerConfig(
          model: sherpa.OfflineModelConfig(
            canary: sherpa.OfflineCanaryModelConfig(
              encoder: file('encoder'),
              decoder: file('decoder'),
              srcLang: source,
              tgtLang: target,
              usePnc: true,
            ),
            tokens: file('tokens'),
            numThreads: threads,
            debug: false,
            provider: 'cpu',
          ),
        ),
      );
      vad = sherpa.VoiceActivityDetector(
        config: sherpa.VadModelConfig(
          sileroVad: sherpa.SileroVadModelConfig(
            model: file('vad'),
            threshold: 0.35,
            minSilenceDuration: 0.45,
            minSpeechDuration: 0.2,
            maxSpeechDuration: 12,
            windowSize: 512,
          ),
          sampleRate: 16000,
          numThreads: 1,
          debug: false,
        ),
        bufferSizeInSeconds: 30,
      );
      if (startup['denoise'] == true) {
        denoiser = sherpa.OnlineSpeechDenoiser(
          sherpa.OnlineSpeechDenoiserConfig(
            model: sherpa.OfflineSpeechDenoiserModelConfig(
              gtcrn: sherpa.OfflineSpeechDenoiserGtcrnModelConfig(
                model: file('denoiser'),
              ),
              numThreads: 1,
              debug: false,
              provider: 'cpu',
            ),
          ),
        );
      }
      final commands = ReceivePort();
      SendPort? events;
      owner.send(commands.sendPort);
      commands.listen((dynamic message) {
        if (message is! Map) return;
        switch (message['type']) {
          case 'listen':
            events = message['reply'] as SendPort;
            return;
          case 'audio':
            final data = (message['bytes'] as TransferableTypedData)
                .materialize();
            final bytes = data.asUint8List();
            final samples = Float32List(bytes.length ~/ 2);
            final view = ByteData.sublistView(bytes);
            for (var i = 0; i < samples.length; i++) {
              samples[i] = view.getInt16(i * 2, Endian.little) / 32768.0;
            }
            final enhanced = denoiser?.run(samples: samples, sampleRate: 16000);
            vad!.acceptWaveform(
              enhanced == null || enhanced.samples.isEmpty
                  ? samples
                  : enhanced.samples,
            );
            events?.send({'speechDetected': vad!.isDetected()});
            while (!vad!.isEmpty()) {
              final segment = vad!.front();
              vad!.pop();
              final stream = recognizer!.createStream();
              try {
                stream.acceptWaveform(
                  samples: segment.samples,
                  sampleRate: 16000,
                );
                recognizer!.decode(stream);
                final text = recognizer!.getResult(stream).text.trim();
                if (text.isNotEmpty) {
                  events?.send({'caption': text, 'speechDetected': false});
                }
              } finally {
                stream.free();
              }
            }
            return;
          case 'flush':
            // One second of silence closes a pending Silero segment. The
            // acknowledgement is emitted after Canary finishes decoding.
            vad!.acceptWaveform(Float32List(16000));
            vad!.flush();
            events?.send({'speechDetected': vad!.isDetected()});
            while (!vad!.isEmpty()) {
              final segment = vad!.front();
              vad!.pop();
              final stream = recognizer!.createStream();
              try {
                stream.acceptWaveform(
                  samples: segment.samples,
                  sampleRate: 16000,
                );
                recognizer!.decode(stream);
                final text = recognizer!.getResult(stream).text.trim();
                if (text.isNotEmpty) {
                  events?.send({'caption': text, 'speechDetected': false});
                }
              } finally {
                stream.free();
              }
            }
            events?.send({'flushDone': true, 'speechDetected': false});
            return;
          case 'dispose':
            vad?.free();
            denoiser?.free();
            recognizer?.free();
            vad = null;
            denoiser = null;
            recognizer = null;
            (message['reply'] as SendPort?)?.send(true);
            commands.close();
            return;
        }
      });
    } catch (error, stack) {
      vad?.free();
      denoiser?.free();
      recognizer?.free();
      owner.send('Unable to load captions: $error\n$stack');
    }
  }
}
