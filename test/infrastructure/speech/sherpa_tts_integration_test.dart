import 'dart:io';
import 'dart:async';

import 'package:godsense/infrastructure/speech/tts/sherpa_tts_engine.dart';
import 'package:godsense/infrastructure/speech/tts_model_cache.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/native_worker_coverage.dart';
import '../../support/voice_model_cases.dart';

void main() {
  final cases = voiceModelCases;

  for (final modelCase in cases) {
    final directory = Platform.environment[modelCase.environmentKey];
    test(
      'synthesizes audio with ${modelCase.model.name} [${modelCase.model.id}]',
      () async {
        final model = modelCase.model;
        final voice = model.voices.first;
        final engine = SherpaTtsEngine();
        final heartbeat = _Heartbeat();
        try {
          await engine.initialize(
            TtsModelInstallation(model, Directory(directory!)),
          );
          final audio = await engine.synthesize(
            text: modelCase.text,
            speakerId: voice.speakerId,
            language: modelCase.language ?? model.languages.first.code,
            speed: 1,
            steps: model.defaultSteps,
            referenceAudio: voice.referenceAudio,
            referenceText: voice.referenceText,
          );
          expect(audio.sampleRate, greaterThan(0));
          expect(audio.samples.length, greaterThan(audio.sampleRate ~/ 4));
          expect(audio.samples.every((sample) => sample.isFinite), isTrue);
          expect(audio.samples.any((sample) => sample.abs() > 0.0001), isTrue);
          heartbeat.stop();
          expect(
            heartbeat.maximumGap,
            lessThan(const Duration(milliseconds: 250)),
            reason: 'Native voice generation must keep the caller isolate responsive',
          );
        } finally {
          heartbeat.stop();
          if (engine.isReady) {
            await snapshotNativeWorkerCoverage('tts-${model.id}');
          }
          await engine.dispose();
        }
      },
      skip: directory == null
          ? 'Set ${modelCase.environmentKey} for this native smoke test.'
          : false,
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }

  for (final modelCase in cases) {
    final directory = Platform.environment[modelCase.environmentKey];
    test(
      'cancels native generation and can initialize again with ${modelCase.model.name} [${modelCase.model.id}]',
      () async {
        final voice = modelCase.model.voices.first;
        final engine = SherpaTtsEngine();
        final heartbeat = _Heartbeat();
        final installation = TtsModelInstallation(
          modelCase.model,
          Directory(directory!),
        );
        try {
          await engine.initialize(installation);
          final generation = engine.synthesize(
            text: List.filled(80, modelCase.text).join(' '),
            speakerId: voice.speakerId,
            language:
                modelCase.language ?? modelCase.model.languages.first.code,
            speed: 1,
            steps: modelCase.model.defaultSteps,
            referenceAudio: voice.referenceAudio,
            referenceText: voice.referenceText,
          );
          await Future<void>.delayed(const Duration(milliseconds: 100));
          final stopwatch = Stopwatch()..start();
          Duration? nativeFinished;
          final observedGeneration = generation.then((_) {
            nativeFinished = stopwatch.elapsed;
          });
          await engine.cancel();
          await observedGeneration;
          stdout.writeln(
            'NATIVE TTS CANCELLATION: model=${modelCase.model.id} '
            'elapsed_ms=${stopwatch.elapsedMilliseconds} '
            'generation_completed_ms=${nativeFinished?.inMilliseconds}',
          );
          expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));

          await engine.initialize(installation);
          final recovered = await engine.synthesize(
            text: modelCase.text,
            speakerId: voice.speakerId,
            language:
                modelCase.language ?? modelCase.model.languages.first.code,
            speed: 1,
            steps: modelCase.model.defaultSteps,
            referenceAudio: voice.referenceAudio,
            referenceText: voice.referenceText,
          );
          expect(recovered.samples, isNotEmpty);
          expect(recovered.samples.every((sample) => sample.isFinite), isTrue);
          expect(
            recovered.samples.any((sample) => sample.abs() > 0.0001),
            isTrue,
          );
          heartbeat.stop();
          expect(
            heartbeat.maximumGap,
            lessThan(const Duration(milliseconds: 250)),
            reason: 'Cancellation and recovery must keep the caller isolate responsive',
          );
        } finally {
          heartbeat.stop();
          if (engine.isReady) {
            await snapshotNativeWorkerCoverage(
              'tts-cancel-${modelCase.model.id}',
            );
          }
          await engine.dispose();
        }
      },
      skip: directory == null
          ? 'Set ${modelCase.environmentKey} for the native cancellation test.'
          : false,
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
}

class _Heartbeat {
  _Heartbeat() {
    _timer = Timer.periodic(const Duration(milliseconds: 10), (_) => _sample());
  }
  final _clock = Stopwatch()..start();
  late final Timer _timer;
  int _previous = 0;
  Duration maximumGap = Duration.zero;
  bool _stopped = false;
  void _sample() {
    final now = _clock.elapsedMicroseconds;
    final gap = Duration(microseconds: now - _previous);
    if (gap > maximumGap) maximumGap = gap;
    _previous = now;
  }

  void stop() {
    if (_stopped) return;
    _sample();
    _stopped = true;
    _timer.cancel();
  }
}
