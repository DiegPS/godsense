import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/infrastructure/speech/native_audio_playback_service.dart';
import 'package:godsense/infrastructure/speech/tts/sherpa_tts_engine.dart';
import 'package:godsense/infrastructure/speech/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('godsense-tts-cancel-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await directory.delete();
  });

  test(
    'stop clears queued speech and ignores a synthesis that completes late',
    () async {
      final engine = _Engine();
      final playback = _Playback();
      final service = TtsService(engine: engine, audioPlayback: playback);
      final errors = <Object>[];
      final subscription = service.playbackErrors.listen(errors.add);
      addTearDown(subscription.cancel);
      addTearDown(service.dispose);
      final first = engine.requests.stream.first;
      service.speak('primera');
      final old = await first;
      service.speak('pendiente');
      await service.stop();
      expect(service.isBusy, isFalse);

      final next = engine.requests.stream.first;
      service.speak('nueva');
      final current = await next;
      expect(current.text, 'nueva');
      // The cancelled native operation may still have a completion in flight.
      old.result.complete(_audio);
      await Future<void>.delayed(Duration.zero);
      expect(service.isBusy, isTrue);
      expect(playback.files, isEmpty);

      final playing = playback.started.future;
      current.result.complete(_audio);
      await playing.timeout(const Duration(seconds: 3));
      expect(playback.files, hasLength(1));
      expect(service.isBusy, isTrue);
      await service.stop();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(service.isBusy, isFalse);
      expect(errors, isEmpty);
      expect(engine.texts, ['primera', 'nueva']);
      expect(await directory.list().isEmpty, isTrue);
    },
  );
}

final _audio = TtsAudio(Float32List.fromList([0, .2, -.2, 0]), 16000);

class _Request {
  _Request(this.text);
  final String text;
  final result = Completer<TtsAudio>();
}

class _Engine extends SherpaTtsEngine {
  final requests = StreamController<_Request>.broadcast(sync: true);
  final pending = <_Request>[];
  final texts = <String>[];
  @override
  bool get isReady => true;
  @override
  Future<TtsAudio> synthesize({
    required String text,
    required int speakerId,
    required String language,
    required double speed,
    required int steps,
    String? referenceAudio,
    String referenceText = '',
  }) {
    final request = _Request(text);
    texts.add(text);
    pending.add(request);
    requests.add(request);
    return request.result.future;
  }

  @override
  Future<void> cancel() async {}
  @override
  Future<void> dispose() async {
    for (final request in pending) {
      if (!request.result.isCompleted) {
        request.result.complete(TtsAudio(Float32List(0), 16000));
      }
    }
    await requests.close();
    await super.dispose();
  }
}

class _Playback extends NativeAudioPlaybackService {
  final started = Completer<void>();
  final files = <String>[];
  Completer<void>? active;
  @override
  Future<void> playFile(
    File file, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final completion = Completer<void>();
    active = completion;
    expect(await file.exists(), isTrue);
    files.add(file.path);
    started.complete();
    await completion.future;
  }

  @override
  Future<void> stop() async {
    if (active case final value? when !value.isCompleted) value.complete();
  }
}
