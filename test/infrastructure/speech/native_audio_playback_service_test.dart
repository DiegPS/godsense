import 'dart:io';
import 'dart:typed_data';

import 'package:godsense/infrastructure/speech/native_audio_playback_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Windows WAV playback completes without a Dart native callback',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'godsense-audio-test-',
      );
      final file = File(
        '${directory.path}${Platform.pathSeparator}silence.wav',
      );
      final service = NativeAudioPlaybackService();
      try {
        await file.writeAsBytes(_silentWav(const Duration(milliseconds: 80)));
        await service.playFile(file, timeout: const Duration(seconds: 2));
      } finally {
        await service.dispose();
        await directory.delete(recursive: true);
      }
    },
    skip: !Platform.isWindows,
  );

  test('stopping Windows playback releases the waiting caller', () async {
    final directory = await Directory.systemTemp.createTemp(
      'godsense-audio-stop-test-',
    );
    final file = File('${directory.path}${Platform.pathSeparator}silence.wav');
    final service = NativeAudioPlaybackService();
    try {
      await file.writeAsBytes(_silentWav(const Duration(seconds: 2)));
      final playback = service.playFile(
        file,
        timeout: const Duration(seconds: 4),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await service.stop();
      await playback.timeout(const Duration(seconds: 1));
    } finally {
      await service.dispose();
      await directory.delete(recursive: true);
    }
  }, skip: !Platform.isWindows);
}

Uint8List _silentWav(Duration duration) {
  const sampleRate = 8000;
  const bytesPerSample = 2;
  final sampleCount = duration.inMicroseconds * sampleRate ~/ 1000000;
  final dataSize = sampleCount * bytesPerSample;
  final bytes = Uint8List(44 + dataSize);
  final data = ByteData.sublistView(bytes);

  void ascii(int offset, String value) {
    for (var index = 0; index < value.length; index++) {
      bytes[offset + index] = value.codeUnitAt(index);
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + dataSize, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * bytesPerSample, Endian.little);
  data.setUint16(32, bytesPerSample, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, dataSize, Endian.little);
  return bytes;
}
