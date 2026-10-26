// ignore_for_file: prefer_initializing_formals, unnecessary_underscores

import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

import '../tts_model_cache.dart';
import '../sherpa_cpu_thread_policy.dart';
import '../native_worker_guard.dart';
import 'tts_model_catalog.dart';
import 'tts_text_chunks.dart';

class TtsAudio {
  final Float32List samples;
  final int sampleRate;
  const TtsAudio(this.samples, this.sampleRate);
  Duration get duration => sampleRate <= 0
      ? Duration.zero
      : Duration(milliseconds: (samples.length * 1000 / sampleRate).ceil());
}

typedef SherpaTtsWorkerEntrypoint = void Function(Map<String, Object> startup);

class SherpaTtsEngine {
  SherpaTtsEngine({
    SherpaTtsWorkerEntrypoint? workerEntrypoint,
    Duration synthesisTimeout = const Duration(seconds: 90),
  }) : _workerEntrypoint = workerEntrypoint ?? _workerMain,
       _synthesisTimeout = synthesisTimeout;

  final SherpaTtsWorkerEntrypoint _workerEntrypoint;
  final Duration _synthesisTimeout;
  Isolate? _isolate;
  SendPort? _commands;
  TtsModelInstallation? _installation;
  Pointer<Uint8>? _cancelFlag;
  Completer<void>? _activeRequest;
  NativeWorkerGuard? _workerGuard;
  final _workerFailures = StreamController<Object>.broadcast();
  bool _disposed = false;

  bool get isReady =>
      _commands != null && _workerGuard != null && _activeRequest == null;
  Stream<Object> get workerFailures => _workerFailures.stream;

  Future<void> initialize(TtsModelInstallation installation) async {
    if (_disposed) throw StateError('TTS engine has been disposed.');
    if (_commands != null &&
        _activeRequest == null &&
        _installation?.model.storageKey == installation.model.storageKey) {
      return;
    }
    await unload();
    final ready = ReceivePort();
    late final NativeWorkerGuard guard;
    guard = NativeWorkerGuard(
      label: 'Sherpa TTS worker',
      onFailure: (error, failedAfterReady) =>
          _handleWorkerFailure(guard, error, failedAfterReady),
    );
    _workerGuard = guard;
    Isolate? isolate;
    try {
      isolate = await Isolate.spawn(
        _workerEntrypoint,
        <String, Object>{
          'reply': ready.sendPort,
          'model': _modelMessage(installation),
          'nativeLibraryDirectory':
              Platform.environment['GODSENSE_SHERPA_LIBRARY_DIR'] ??
              File(Platform.resolvedExecutable).parent.path,
        },
        errorsAreFatal: true,
        onError: guard.errorPort.sendPort,
        onExit: guard.exitPort.sendPort,
      );
      _isolate = isolate;
      final first = await Future.any<Object?>([
        ready.first,
        guard.failure.then<Object?>((error) => throw error),
      ]).timeout(const Duration(minutes: 2));
      if (first is! SendPort) {
        throw StateError('Sherpa initialization failed: $first');
      }
      if (!identical(_workerGuard, guard)) {
        throw StateError('Sherpa worker stopped during initialization.');
      }
      _commands = first;
      _installation = installation;
      guard.markReady();
    } catch (_) {
      isolate?.kill(priority: Isolate.immediate);
      if (identical(_workerGuard, guard)) {
        _workerGuard = null;
        _isolate = null;
        _commands = null;
        _installation = null;
      }
      await guard.dispose(expectedExit: true);
      rethrow;
    } finally {
      ready.close();
    }
  }

  Future<TtsAudio> synthesize({
    required String text,
    required int speakerId,
    required String language,
    required double speed,
    required int steps,
    String? referenceAudio,
    String referenceText = '',
  }) async {
    final commands = _commands;
    final guard = _workerGuard;
    if (commands == null || guard == null) {
      throw StateError('TTS engine is not ready.');
    }
    if (_activeRequest != null) {
      throw StateError('The previous TTS generation is still stopping.');
    }
    final response = ReceivePort();
    final cancelFlag = calloc<Uint8>()..value = 0;
    final activeRequest = Completer<void>();
    _cancelFlag = cancelFlag;
    _activeRequest = activeRequest;
    commands.send(<String, Object>{
      'type': 'synthesize',
      'reply': response.sendPort,
      'text': text,
      'speakerId': speakerId,
      'language': language,
      'speed': speed,
      'steps': steps,
      if (referenceAudio != null && referenceAudio.isNotEmpty)
        'referenceAudio': p.isAbsolute(referenceAudio)
            ? referenceAudio
            : p.join(_installation!.directory.path, referenceAudio),
      'referenceText': referenceText,
      'cancelAddress': cancelFlag.address,
    });
    final terminal = Future.any<Object?>([
      response.first,
      guard.failure.then<Object?>((error) => throw error),
    ]);
    unawaited(
      _finalizeNativeRequest(
        terminal: terminal,
        response: response,
        cancelFlag: cancelFlag,
        activeRequest: activeRequest,
        guard: guard,
      ),
    );
    final result = await terminal.timeout(
      _synthesisTimeout,
      onTimeout: () {
        final error = TimeoutException(
          'Sherpa did not answer the synthesis request.',
          _synthesisTimeout,
        );
        // Do not kill the isolate or free this flag while Sherpa is inside
        // its synchronous FFI callback. The worker owns the callback until
        // it posts a terminal response; finalization below deliberately
        // keeps both the port and flag alive until that happens.
        cancelFlag.value = 1;
        throw error;
      },
    );
    if (result is Map && result['error'] != null) {
      throw StateError(result['error'] as String);
    }
    if (result is! Map || result['samples'] is! TransferableTypedData) {
      throw StateError('Sherpa returned an invalid audio response.');
    }
    final bytes = (result['samples'] as TransferableTypedData).materialize();
    return TtsAudio(Float32List.view(bytes), result['sampleRate'] as int);
  }

  Future<void> _finalizeNativeRequest({
    required Future<Object?> terminal,
    required ReceivePort response,
    required Pointer<Uint8> cancelFlag,
    required Completer<void> activeRequest,
    required NativeWorkerGuard guard,
  }) async {
    var safeToReleaseNativeMemory = false;
    try {
      await terminal;
      // A terminal worker response is sent only after generateWithConfig has
      // returned and sherpa_onnx has closed its NativeCallable.
      safeToReleaseNativeMemory = true;
    } catch (_) {
      // An isolate error can be delivered just before its exit notification.
      // Only release memory observed by the callback after the isolate has
      // definitely exited. If that notification never comes, leaking one byte
      // is intentionally safer than a native use-after-free.
      try {
        await guard.exited.timeout(const Duration(seconds: 5));
        safeToReleaseNativeMemory = true;
      } catch (_) {}
    } finally {
      response.close();
      if (identical(_cancelFlag, cancelFlag)) _cancelFlag = null;
      if (identical(_activeRequest, activeRequest)) _activeRequest = null;
      if (safeToReleaseNativeMemory) {
        calloc.free(cancelFlag);
      }
      if (!activeRequest.isCompleted) activeRequest.complete();
      if (_disposed && identical(_workerGuard, guard)) {
        unawaited(
          Future<void>.microtask(() async {
            try {
              await unload();
            } catch (_) {}
          }),
        );
      }
    }
  }

  /// Stops native generation immediately. The worker is recreated lazily.
  Future<void> cancel() async {
    _cancelFlag?.value = 1;
    final activeRequest = _activeRequest;
    if (activeRequest != null) {
      try {
        await activeRequest.future.timeout(const Duration(seconds: 5));
      } catch (_) {
        // The synchronous native callback is still alive. Leave the worker
        // quarantined until it acknowledges cancellation; killing it here can
        // delete Dart's NativeCallable while C++ is still invoking it.
        return;
      }
    }
    await unload();
  }

  Future<void> unload() async {
    final activeRequest = _activeRequest;
    if (activeRequest != null) {
      _cancelFlag?.value = 1;
      try {
        await activeRequest.future.timeout(const Duration(seconds: 5));
      } catch (_) {
        throw StateError('Sherpa is still finishing a cancelled generation.');
      }
    }
    final commands = _commands;
    _commands = null;
    _installation = null;
    final isolate = _isolate;
    _isolate = null;
    final guard = _workerGuard;
    _workerGuard = null;
    await guard?.dispose(expectedExit: true);
    if (commands == null) {
      isolate?.kill(priority: Isolate.immediate);
      return;
    }
    final response = ReceivePort();
    commands.send({'type': 'dispose', 'reply': response.sendPort});
    try {
      await response.first.timeout(const Duration(seconds: 3));
    } catch (_) {
      isolate?.kill(priority: Isolate.immediate);
    } finally {
      response.close();
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await unload();
    } on StateError {
      // A native call that ignored cancellation must remain alive until its
      // callback returns. _finalizeNativeRequest will dispose it afterward.
    }
    await _workerFailures.close();
  }

  void _handleWorkerFailure(
    NativeWorkerGuard guard,
    Object error,
    bool failedAfterReady,
  ) {
    if (!identical(_workerGuard, guard)) return;
    _commands = null;
    _installation = null;
    _isolate = null;
    _workerGuard = null;
    _cancelFlag?.value = 1;
    unawaited(guard.dispose(expectedExit: false));
    if (failedAfterReady && !_disposed && !_workerFailures.isClosed) {
      _workerFailures.add(error);
    }
  }

  static Map<String, Object> _modelMessage(TtsModelInstallation installation) {
    final model = installation.model;
    return {
      'family': model.family.name,
      'directory': installation.directory.path,
      'files': model.modelFiles,
      'maxSentences': model.maxSentences,
      'silenceScale': model.silenceScale,
      'threads': SherpaCpuThreadPolicy.recommended(),
    };
  }

  static void _workerMain(Map<String, Object> startup) {
    final owner = startup['reply']! as SendPort;
    final model = startup['model']! as Map;
    if (Platform.isWindows) {
      // Windows searches System32 before the application directory for a DLL's
      // transitive dependencies. Preloading our pinned runtime prevents an old
      // system-wide onnxruntime.dll from being bound to Sherpa.
      final directory = startup['nativeLibraryDirectory']! as String;
      DynamicLibrary.open('$directory\\onnxruntime.dll');
      DynamicLibrary.open('$directory\\sherpa-onnx-c-api.dll');
    }
    sherpa.initBindings();
    sherpa.OfflineTts? tts;
    try {
      final directory = model['directory']! as String;
      final separator = directory.contains('\\') ? '\\' : '/';
      String file(String name) => '$directory$separator$name';
      final files = Map<String, String>.from(model['files']! as Map);
      String modelFile(String key) {
        final relative = files[key];
        return relative == null || relative.isEmpty ? '' : file(relative);
      }

      final family = model['family'] as String;
      final modelConfig = sherpa.OfflineTtsModelConfig(
        supertonic: family == TtsModelFamily.supertonic.name
            ? sherpa.OfflineTtsSupertonicModelConfig(
                durationPredictor: modelFile('durationPredictor'),
                textEncoder: modelFile('textEncoder'),
                vectorEstimator: modelFile('vectorEstimator'),
                vocoder: modelFile('vocoder'),
                ttsJson: modelFile('ttsJson'),
                unicodeIndexer: modelFile('unicodeIndexer'),
                voiceStyle: modelFile('voiceStyle'),
              )
            : const sherpa.OfflineTtsSupertonicModelConfig(),
        vits: family == TtsModelFamily.vits.name
            ? sherpa.OfflineTtsVitsModelConfig(
                model: modelFile('model'),
                lexicon: modelFile('lexicon'),
                tokens: modelFile('tokens'),
                dataDir: modelFile('dataDir'),
              )
            : const sherpa.OfflineTtsVitsModelConfig(),
        matcha: family == TtsModelFamily.matcha.name
            ? sherpa.OfflineTtsMatchaModelConfig(
                acousticModel: modelFile('acousticModel'),
                vocoder: modelFile('vocoder'),
                lexicon: modelFile('lexicon'),
                tokens: modelFile('tokens'),
                dataDir: modelFile('dataDir'),
              )
            : const sherpa.OfflineTtsMatchaModelConfig(),
        kokoro: family == TtsModelFamily.kokoro.name
            ? sherpa.OfflineTtsKokoroModelConfig(
                model: modelFile('model'),
                voices: modelFile('voices'),
                tokens: modelFile('tokens'),
                dataDir: modelFile('dataDir'),
                lexicon: modelFile('lexicon'),
              )
            : const sherpa.OfflineTtsKokoroModelConfig(),
        kitten: family == TtsModelFamily.kitten.name
            ? sherpa.OfflineTtsKittenModelConfig(
                model: modelFile('model'),
                voices: modelFile('voices'),
                tokens: modelFile('tokens'),
                dataDir: modelFile('dataDir'),
              )
            : const sherpa.OfflineTtsKittenModelConfig(),
        zipvoice: family == TtsModelFamily.zipvoice.name
            ? sherpa.OfflineTtsZipVoiceModelConfig(
                tokens: modelFile('tokens'),
                encoder: modelFile('encoder'),
                decoder: modelFile('decoder'),
                vocoder: modelFile('vocoder'),
                dataDir: modelFile('dataDir'),
                lexicon: modelFile('lexicon'),
              )
            : const sherpa.OfflineTtsZipVoiceModelConfig(),
        pocket: family == TtsModelFamily.pocket.name
            ? sherpa.OfflineTtsPocketModelConfig(
                lmFlow: modelFile('lmFlow'),
                lmMain: modelFile('lmMain'),
                encoder: modelFile('encoder'),
                decoder: modelFile('decoder'),
                textConditioner: modelFile('textConditioner'),
                vocabJson: modelFile('vocabJson'),
                tokenScoresJson: modelFile('tokenScoresJson'),
              )
            : const sherpa.OfflineTtsPocketModelConfig(),
        numThreads: model['threads'] as int,
        debug: false,
        provider: 'cpu',
      );
      tts = sherpa.OfflineTts(
        sherpa.OfflineTtsConfig(
          model: modelConfig,
          maxNumSenetences: model['maxSentences'] as int,
          silenceScale: model['silenceScale'] as double,
        ),
      );
      final commands = ReceivePort();
      owner.send(commands.sendPort);
      commands.listen((dynamic message) {
        if (message is! Map) return;
        if (message['type'] == 'dispose') {
          final reply = message['reply'] as SendPort?;
          tts?.free();
          tts = null;
          reply?.send(true);
          commands.close();
          return;
        }
        if (message['type'] != 'synthesize') return;
        final reply = message['reply'] as SendPort;
        try {
          final referencePath = message['referenceAudio'] as String?;
          final reference = referencePath == null
              ? null
              : sherpa.readWave(referencePath);
          if (referencePath != null &&
              (reference == null ||
                  reference.samples.isEmpty ||
                  reference.sampleRate <= 0)) {
            throw StateError('Unable to read reference WAV: $referencePath');
          }
          final samples = BytesBuilder(copy: false);
          final cancellation = Pointer<Uint8>.fromAddress(
            message['cancelAddress'] as int,
          );
          final sampleRate = tts!.sampleRate;
          for (final chunk in ttsTextChunks(message['text'] as String)) {
            if (cancellation.value != 0) break;
            // Some models invoke progress only after a complete text batch.
            // Bound each call so cancellation does not wait for a long reply.
            final audio = tts!.generateWithConfig(
              text: chunk,
              config: sherpa.OfflineTtsGenerationConfig(
                sid: message['speakerId'] as int,
                speed: message['speed'] as double,
                numSteps: message['steps'] as int,
                silenceScale: model['silenceScale'] as double,
                referenceAudio: reference?.samples,
                referenceSampleRate: reference?.sampleRate ?? 0,
                referenceText: message['referenceText'] as String? ?? '',
                extra: family == TtsModelFamily.supertonic.name
                    ? {'lang': message['language'] as String}
                    : family == TtsModelFamily.zipvoice.name
                    ? const {'min_char_in_sentence': 1}
                    : const {},
              ),
              onProgress: (_, __) => cancellation.value == 0 ? 1 : 0,
            );
            samples.add(
              audio.samples.buffer.asUint8List(
                audio.samples.offsetInBytes,
                audio.samples.lengthInBytes,
              ),
            );
          }
          reply.send({
            'samples': TransferableTypedData.fromList([samples.takeBytes()]),
            'sampleRate': sampleRate,
          });
        } catch (error, stack) {
          reply.send({'error': '$error\n$stack'});
        }
      });
    } catch (error, stack) {
      tts?.free();
      owner.send('Unable to load Sherpa model: $error\n$stack');
    }
  }
}
