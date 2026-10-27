import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/infrastructure/speech/tts/speech_worker_protocol.dart';
import 'package:godsense/infrastructure/speech/tts/speech_process_host.dart';
import 'package:godsense/infrastructure/speech/native_worker_guard.dart';
import 'package:godsense/infrastructure/speech/tts/sherpa_tts_engine.dart';
import 'package:godsense/infrastructure/speech/tts/tts_model_catalog.dart';
import 'package:godsense/infrastructure/speech/tts_model_cache.dart';
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart';

void main() {
  final libraryDirectory = Platform.environment['GODSENSE_SHERPA_LIBRARY_DIR'];
  final skip = !Platform.isWindows || libraryDirectory == null
      ? 'Set GODSENSE_SHERPA_LIBRARY_DIR to test the installed native helper.'
      : false;
  final executable = p.join(
    libraryDirectory ?? '',
    'godsense_speech_worker.exe',
  );

  Future<void> malformed(List<int> bytes) async {
    final process = await Process.start(
      executable,
      const [],
      runInShell: false,
    );
    final reader = SpeechWorkerReader(process.stdout);
    final stderr = process.stderr.drain<void>();
    try {
      process.stdin.add(bytes);
      await process.stdin.flush();
      expect(await reader.readInteger(), speechWorkerMagic);
      await expectLater(reader.readStatus(), throwsStateError);
      expect(
        await process.exitCode.timeout(const Duration(seconds: 5)),
        isNot(0),
      );
    } finally {
      process.kill();
      await process.exitCode;
      await reader.close();
      await stderr;
      try {
        await process.stdin.close();
      } catch (_) {}
    }
  }

  test(
    'native helper rejects unsupported protocol before loading a model',
    () async {
      await malformed(speechWorkerInteger(0));
    },
    skip: skip,
  );
  test(
    'native helper rejects oversized fields before allocating them',
    () async {
      await malformed([
        ...speechWorkerInteger(speechWorkerMagic),
        ...speechWorkerInteger(pid),
        ...speechWorkerInteger(1),
        ...speechWorkerInteger(speechWorkerMaxStringBytes + 1),
      ]);
    },
    skip: skip,
  );
  test('native helper rejects malformed UTF-8 from its pipe', () async {
    await malformed([
      ...speechWorkerInteger(speechWorkerMagic),
      ...speechWorkerInteger(pid),
      ...speechWorkerInteger(1),
      ...speechWorkerInteger(1),
      0xff,
    ]);
  }, skip: skip);

  test('native helper exits when configuration is truncated', () async {
    final process = await Process.start(
      executable,
      const [],
      runInShell: false,
    );
    final output = process.stdout.drain<void>();
    final stderr = process.stderr.drain<void>();
    try {
      process.stdin.add(speechWorkerInteger(speechWorkerMagic));
      await process.stdin.close();
      expect(
        await process.exitCode.timeout(const Duration(seconds: 5)),
        isNot(0),
      );
    } finally {
      process.kill();
      await process.exitCode;
      await output;
      await stderr;
    }
  }, skip: skip);

  test('losing the proxy isolate leaves no native helper waiting for configuration', () async {
    final child = ReceivePort();
    Isolate? proxy;
    HANDLE? handle;
    final code = calloc<Uint32>();
    final host = SpeechProcessHost(executable);
    final guard = NativeWorkerGuard(
      label: 'Test speech proxy',
      onFailure: (_, _) => host.close(),
    );
    guard.markReady();
    try {
      proxy = await Isolate.spawn(
        _startAbandonedHelper,
        [child.sendPort, host.requests],
        onExit: guard.exitPort.sendPort,
        onError: guard.errorPort.sendPort,
      );
      final processId =
          await child.first.timeout(const Duration(seconds: 5)) as int;
      handle = OpenProcess(
        PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_TERMINATE,
        false,
        processId,
      ).value;
      expect(handle.isNull, isFalse);
      proxy.kill(priority: Isolate.immediate);
      final watch = Stopwatch()..start();
      do {
        expect(GetExitCodeProcess(handle, code).value, isTrue);
        if (code.value != 259) break; // STILL_ACTIVE
        await Future<void>.delayed(const Duration(milliseconds: 20));
      } while (watch.elapsed < const Duration(seconds: 3));
      expect(
        code.value,
        isNot(259),
        reason: 'The helper must exit when its proxy disappears.',
      );
    } finally {
      proxy?.kill(priority: Isolate.immediate);
      await host.close();
      await guard.dispose(expectedExit: true);
      if (handle != null && !handle.isNull) {
        if (GetExitCodeProcess(handle, code).value && code.value == 259) {
          // Terminate through the actual process handle, never a reused PID.
          TerminateProcess(handle, 1);
        }
        CloseHandle(handle);
      }
      calloc.free(code);
      child.close();
    }
  }, skip: skip);

  final supertonicDirectory =
      Platform.environment['GODSENSE_SUPERTONIC_MODEL_DIR'];
  test(
    'native synthesis timeout retires the process before a new initialization',
    () async {
      final engine = SherpaTtsEngine(
        synthesisTimeout: const Duration(milliseconds: 1),
      );
      final installation = TtsModelInstallation(
        TtsModelCatalog.supertonic,
        Directory(supertonicDirectory!),
      );
      try {
        await engine.initialize(installation);
        await expectLater(
          engine.synthesize(
            text: 'Hola, GodSense está listo.',
            speakerId: 0,
            language: 'es',
            speed: 1,
            steps: 5,
          ),
          throwsA(isA<TimeoutException>()),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(
          engine.isReady,
          isFalse,
          reason: 'A killed native process cannot remain ready.',
        );
        await engine.initialize(installation);
        expect(engine.isReady, isTrue);
      } finally {
        await engine.dispose();
      }
    },
    skip: skip != false || supertonicDirectory == null
        ? 'Requires the native helper and Supertonic model.'
        : false,
  );
}

void _startAbandonedHelper(List<Object> arguments) async {
  final owner = arguments[0] as SendPort;
  final process = await SpeechProcessConnection.connect(
    arguments[1] as SendPort,
  );
  unawaited(process.stdout.drain<void>());
  process
    ..add(speechWorkerInteger(speechWorkerMagic))
    ..add(speechWorkerInteger(pid));
  owner.send(process.processId);
  // Keep the proxy alive without completing initialization. Killing this
  // isolate must notify its app-owned host even though Flutter stays alive.
  await ReceivePort().first;
}
