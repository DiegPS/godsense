import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:record/record.dart';

import 'package:godsense/infrastructure/speech/speech/live_captions_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Windows registers the real audio input backend', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.runAsync(() async {
      final recorder = AudioRecorder();
      try {
        // An empty list is valid on a machine without microphones. A missing
        // plugin is always a failure, including in an otherwise headless suite.
        final devices = await recorder.listInputDevices();
        expect(devices.map((d) => d.id).toSet().length, devices.length);
      } finally {
        await recorder.dispose();
      }
    });
  });

  testWidgets(
    'real microphone PCM reaches Dart through multiview window delegates',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.runAsync(() async {
        final capture = RecordSpeechAudioCapture();
        StreamSubscription<dynamic>? subscription;
        try {
          final firstPacket = Completer<void>();
          final stream = await capture.start();
          subscription = stream.listen(
            (bytes) {
              if (bytes.isNotEmpty && !firstPacket.isCompleted) {
                firstPacket.complete();
              }
            },
            onError: (Object error, StackTrace stack) {
              if (!firstPacket.isCompleted) {
                firstPacket.completeError(error, stack);
              }
            },
          );
          await firstPacket.future.timeout(const Duration(seconds: 5));
        } finally {
          await capture.stop();
          await subscription?.cancel();
          await capture.dispose();
        }
      });
    },
    skip: !const bool.fromEnvironment('GODSENSE_TEST_MICROPHONE'),
  );
}
