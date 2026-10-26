import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:godsense/infrastructure/speech/speech/live_captions_service.dart';
import 'package:godsense/infrastructure/speech/tts_model_cache.dart';

import '../../support/native_worker_coverage.dart';

void main() {
  final nativeDirectory = Platform.environment['GODSENSE_SHERPA_LIBRARY_DIR'];
  final canaryDirectory = Platform.environment['GODSENSE_CANARY_MODEL_DIR'];
  final vadModel = Platform.environment['GODSENSE_SILERO_VAD_MODEL'];
  final denoiserModel = Platform.environment['GODSENSE_GTCRN_MODEL'];
  final canRun =
      nativeDirectory != null && vadModel != null && denoiserModel != null;

  for (final denoise in [false, true]) {
    test(
      'production captions worker transcribes PCM with denoise=$denoise and flushes without blocking the caller',
      () async {
        DynamicLibrary.open('$nativeDirectory\\onnxruntime.dll');
        DynamicLibrary.open('$nativeDirectory\\sherpa-onnx-c-api.dll');
        sherpa.initBindings();
        final wave = sherpa.readWave(
          '$canaryDirectory${Platform.pathSeparator}test_wavs${Platform.pathSeparator}en.wav',
        );
        // The fixture WAV is 24 kHz; production microphone capture is 16 kHz.
        final ratio = wave.sampleRate / 16000;
        final count = (wave.samples.length / ratio).floor();
        final pcm = ByteData(count * 2);
        for (var index = 0; index < count; index++) {
          final position = index * ratio;
          final lower = position.floor();
          final upper = math.min(lower + 1, wave.samples.length - 1);
          final sample =
              wave.samples[lower] +
              (wave.samples[upper] - wave.samples[lower]) * (position - lower);
          pcm.setInt16(
            index * 2,
            (sample * 32767).round().clamp(-32768, 32767),
            Endian.little,
          );
        }
        final capture = _WaveCapture(pcm.buffer.asUint8List());
        final cache = TtsModelCache(
          rootDirectory: Directory(canaryDirectory!).parent,
        );
        final service = LiveCaptionsService(
          modelCache: cache,
          audioCapture: capture,
        );
        final observed = <LiveCaptionsState>[];
        final subscription = service.states.listen(observed.add);
        final clock = Stopwatch()..start();
        var previous = clock.elapsedMilliseconds;
        var largestGap = 0;
        final heartbeat = Timer.periodic(const Duration(milliseconds: 20), (_) {
          final now = clock.elapsedMilliseconds;
          largestGap = math.max(largestGap, now - previous);
          previous = now;
        });
        var stops = 0;
        capture.onStop = () async {
          if (++stops == 2) {
            heartbeat.cancel();
            await snapshotNativeWorkerCoverage('captions-denoise-$denoise');
          }
        };
        try {
          await service.updateConfig(
            enabled: true,
            sourceLanguage: 'en',
            targetLanguage: 'en',
            denoise: denoise,
          );
          expect(service.currentState.phase, LiveCaptionsPhase.listening);
          await capture.sent.future.timeout(const Duration(seconds: 5));
          final transcript = await service.finishUtterance(
            timeout: const Duration(seconds: 60),
          );
          expect(
            transcript.trim(),
            isNotEmpty,
            reason:
                'PCM bytes=${pcm.lengthInBytes}; events=${observed.length}; speech detections=${observed.where((state) => state.speechDetected).length}; errors=${observed.where((state) => state.error != null).map((state) => state.error)}',
          );
          expect(observed.any((state) => state.captionFinal), true);
          expect(observed.where((state) => state.error != null), isEmpty);
          expect(service.currentState.phase, LiveCaptionsPhase.idle);
          expect(
            largestGap,
            lessThan(250),
            reason: 'Native speech must run outside the calling isolate',
          );
        } finally {
          heartbeat.cancel();
          await subscription.cancel();
          await service.dispose();
          cache.dispose();
        }
      },
      skip: !canRun || canaryDirectory == null,
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }

  test(
    'loads native VAD and streaming noise reduction',
    () {
      DynamicLibrary.open('$nativeDirectory\\onnxruntime.dll');
      DynamicLibrary.open('$nativeDirectory\\sherpa-onnx-c-api.dll');
      sherpa.initBindings();
      final vad = sherpa.VoiceActivityDetector(
        config: sherpa.VadModelConfig(
          sileroVad: sherpa.SileroVadModelConfig(model: vadModel!),
          sampleRate: 16000,
          numThreads: 1,
          debug: false,
        ),
        bufferSizeInSeconds: 10,
      );
      final denoiser = sherpa.OnlineSpeechDenoiser(
        sherpa.OnlineSpeechDenoiserConfig(
          model: sherpa.OfflineSpeechDenoiserModelConfig(
            gtcrn: sherpa.OfflineSpeechDenoiserGtcrnModelConfig(
              model: denoiserModel!,
            ),
            numThreads: 1,
            debug: false,
          ),
        ),
      );
      try {
        final samples = Float32List.fromList(
          List<double>.generate(
            16000,
            (index) => 0.1 * math.sin(index * 2 * math.pi * 220 / 16000),
          ),
        );
        final enhanced = denoiser.run(samples: samples, sampleRate: 16000);
        expect(enhanced.sampleRate, 16000);
        expect(enhanced.samples, isNotEmpty);

        vad.acceptWaveform(Float32List(16000));
        expect(vad.isDetected(), isFalse);
      } finally {
        denoiser.free();
        vad.free();
      }
    },
    skip: canRun
        ? false
        : 'Set Sherpa library, Silero VAD, and GTCRN model paths.',
  );

  test(
    'transcribes a real WAV with Canary entirely offline',
    () {
      DynamicLibrary.open('$nativeDirectory\\onnxruntime.dll');
      DynamicLibrary.open('$nativeDirectory\\sherpa-onnx-c-api.dll');
      sherpa.initBindings();
      final separator = Platform.pathSeparator;
      final recognizer = sherpa.OfflineRecognizer(
        sherpa.OfflineRecognizerConfig(
          model: sherpa.OfflineModelConfig(
            canary: sherpa.OfflineCanaryModelConfig(
              encoder: '$canaryDirectory${separator}encoder.int8.onnx',
              decoder: '$canaryDirectory${separator}decoder.int8.onnx',
              srcLang: 'en',
              tgtLang: 'en',
              usePnc: true,
            ),
            tokens: '$canaryDirectory${separator}tokens.txt',
            numThreads: 2,
            provider: 'cpu',
          ),
        ),
      );
      final wave = sherpa.readWave(
        '$canaryDirectory${separator}test_wavs${separator}en.wav',
      );
      final stream = recognizer.createStream();
      try {
        stream.acceptWaveform(
          samples: wave.samples,
          sampleRate: wave.sampleRate,
        );
        recognizer.decode(stream);
        expect(recognizer.getResult(stream).text.trim(), isNotEmpty);
      } finally {
        stream.free();
        recognizer.free();
      }
    },
    skip: nativeDirectory != null && canaryDirectory != null
        ? false
        : 'Set Sherpa library and Canary model directories.',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _WaveCapture implements SpeechAudioCapture {
  _WaveCapture(this.pcm);
  final Uint8List pcm;
  final sent = Completer<void>();
  Future<void> Function()? onStop;
  @override
  Future<Stream<Uint8List>> start() async => _chunks();
  Stream<Uint8List> _chunks() async* {
    for (var offset = 0; offset < pcm.length; offset += 1024) {
      yield Uint8List.sublistView(
        pcm,
        offset,
        math.min(offset + 1024, pcm.length),
      );
    }
    sent.complete();
  }

  @override
  Future<void> stop() async {
    await onStop?.call();
  }

  @override
  Future<void> dispose() async {}
}
