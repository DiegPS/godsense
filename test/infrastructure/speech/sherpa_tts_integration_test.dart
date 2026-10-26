import 'dart:io';

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
        } finally {
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
          await engine.cancel();
          await generation;
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
        } finally {
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
