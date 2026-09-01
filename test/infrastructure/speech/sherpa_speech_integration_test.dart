import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

void main() {
  final nativeDirectory = Platform.environment['GODSENSE_SHERPA_LIBRARY_DIR'];
  final canaryDirectory = Platform.environment['GODSENSE_CANARY_MODEL_DIR'];
  final vadModel = Platform.environment['GODSENSE_SILERO_VAD_MODEL'];
  final denoiserModel = Platform.environment['GODSENSE_GTCRN_MODEL'];
  final canRun =
      nativeDirectory != null && vadModel != null && denoiserModel != null;

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
