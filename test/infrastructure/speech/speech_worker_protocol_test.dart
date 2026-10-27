import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/infrastructure/speech/tts/speech_worker_protocol.dart';

void main() {
  test('fields preserve Unicode across single-byte pipe fragments', () async {
    final fields = {'voz': 'búho 🦉', 'ruta': r'C:\modelos\voz', 'vacío': ''};
    final bytes = encodeSpeechWorkerFields(fields);
    final reader = SpeechWorkerReader(
      Stream.fromIterable([
        <int>[],
        for (final byte in bytes) [byte],
      ]),
    );
    try {
      expect(await reader.readInteger(), fields.length);
      final actual = <String, String>{};
      for (var i = 0; i < fields.length; i++) {
        actual[await reader.readString()] = await reader.readString();
      }
      expect(actual, fields);
    } finally {
      await reader.close();
    }
  });

  test('integers use little endian and reject out-of-range values', () {
    expect(speechWorkerInteger(0x12345678), [0x78, 0x56, 0x34, 0x12]);
    expect(() => speechWorkerInteger(-1), throwsRangeError);
    expect(() => speechWorkerInteger(0x100000000), throwsRangeError);
  });

  test(
    'incomplete pipe responses fail instead of returning partial audio',
    () async {
      final reader = SpeechWorkerReader(Stream.value([1, 2]));
      try {
        await expectLater(reader.readInteger(), throwsFormatException);
      } finally {
        await reader.close();
      }
    },
  );

  test(
    'reader bounds allocations before consuming oversized payloads',
    () async {
      final reader = SpeechWorkerReader(
        Stream.value(speechWorkerInteger(speechWorkerMaxStringBytes + 1)),
      );
      try {
        await expectLater(reader.readString(), throwsFormatException);
        await expectLater(
          reader.readBytes(speechWorkerMaxSamples * 4 + 1),
          throwsFormatException,
        );
        await expectLater(reader.readBytes(-1), throwsFormatException);
      } finally {
        await reader.close();
      }
    },
  );

  for (final bad in <List<int>>[
    [0xff],
    [0],
  ]) {
    test('reader rejects malformed UTF-8 or embedded NUL: $bad', () async {
      final reader = SpeechWorkerReader(
        Stream.value([...speechWorkerInteger(bad.length), ...bad]),
      );
      try {
        await expectLater(reader.readString(), throwsFormatException);
      } finally {
        await reader.close();
      }
    });
  }

  test('writer bounds field count, individual fields and aggregate size', () {
    expect(
      () => encodeSpeechWorkerFields({for (var i = 0; i < 65; i++) '$i': ''}),
      throwsFormatException,
    );
    expect(
      () => encodeSpeechWorkerFields({'bad': '\u0000'}),
      throwsFormatException,
    );
    final large = 'x' * speechWorkerMaxStringBytes;
    expect(
      () => encodeSpeechWorkerFields({'bad': '${large}x'}),
      throwsFormatException,
    );
    expect(
      () => encodeSpeechWorkerFields({for (var i = 0; i < 5; i++) '$i': large}),
      throwsFormatException,
    );
  });

  test(
    'response status distinguishes success, native error and unknown status',
    () async {
      final message = utf8.encode('Fixture model failed');
      final reader = SpeechWorkerReader(
        Stream.value([
          ...speechWorkerInteger(0),
          ...speechWorkerInteger(1),
          ...speechWorkerInteger(message.length),
          ...message,
          ...speechWorkerInteger(2),
        ]),
      );
      try {
        await reader.readStatus();
        await expectLater(reader.readStatus(), throwsStateError);
        await expectLater(reader.readStatus(), throwsFormatException);
      } finally {
        await reader.close();
      }
    },
  );

  test('closing a reader releases a pending read', () async {
    final source = StreamController<List<int>>();
    final reader = SpeechWorkerReader(source.stream);
    final failed = expectLater(reader.readInteger(), throwsFormatException);
    await Future<void>.delayed(Duration.zero);
    await reader.close();
    await failed;
    await source.close();
  });
}
