import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'speech_worker_protocol.dart';
import 'speech_process_host.dart';
import 'tts_text_chunks.dart';

// Only async pipes and byte assembly run in this isolate. All native inference
// and native allocations belong to the helper process, which can be terminated.
void speechProcessWorkerMain(Map<String, Object> startup) async {
  final owner = startup['reply']! as SendPort;
  final model = startup['model']! as Map;
  final commands = ReceivePort();
  SpeechProcessConnection? process;
  SpeechWorkerReader? reader;
  var exited = false;
  var ready = false;
  try {
    process = await SpeechProcessConnection.connect(
      startup['speechProcessHost'] as SendPort,
    );
    final child = process;
    unawaited(child.exitCode.then((_) => exited = true));
    reader = SpeechWorkerReader(child.stdout);
    final files = Map<String, String>.from(model['files'] as Map);
    final fields = {
      'family': model['family'].toString(),
      'threads': model['threads'].toString(),
      'maxSentences': model['maxSentences'].toString(),
      'silenceScale': model['silenceScale'].toString(),
      for (final file in files.entries)
        'file.${file.key}': file.value.isEmpty
            ? ''
            : p.join(model['directory'] as String, file.value),
    };
    child
      ..add(speechWorkerInteger(speechWorkerMagic))
      ..add(speechWorkerInteger(pid))
      ..add(encodeSpeechWorkerFields(fields));
    if (await reader.readInteger() != speechWorkerMagic) {
      throw const FormatException('Unsupported speech worker protocol.');
    }
    await reader.readStatus();
    final sampleRate = await reader.readInteger();
    if (sampleRate == 0 || sampleRate > 384000) {
      throw const FormatException('Invalid speech sample rate.');
    }
    owner.send(commands.sendPort);
    ready = true;
    await for (final dynamic message in commands) {
      if (message is! Map) continue;
      final reply = message['reply'] as SendPort;
      if (message['type'] == 'dispose') {
        if (!exited) {
          child.add(speechWorkerInteger(2));
          await reader.readStatus();
          if (await child.exitCode != 0) {
            throw StateError('Speech process cleanup failed.');
          }
        }
        reply.send(true);
        break;
      }
      if (message['type'] != 'synthesize') continue;
      final cancellation = Pointer<Uint8>.fromAddress(
        message['cancelAddress'] as int,
      );
      final timer = Timer.periodic(const Duration(milliseconds: 10), (_) {
        if (cancellation.value != 0 && !exited) child.kill();
      });
      final audio = BytesBuilder(copy: false);
      Object? failure;
      StackTrace? failureStack;
      try {
        final family = model['family'] as String;
        for (final text in ttsTextChunks(message['text'] as String)) {
          if (cancellation.value != 0) break;
          child
            ..add(speechWorkerInteger(1))
            ..add(
              encodeSpeechWorkerFields({
                'text': text,
                'speakerId': message['speakerId'].toString(),
                'speed': message['speed'].toString(),
                'steps': message['steps'].toString(),
                'referenceAudio': message['referenceAudio'] as String? ?? '',
                'referenceText': message['referenceText'] as String? ?? '',
                'extra': jsonEncode(
                  family == 'supertonic'
                      ? {'lang': message['language'] as String}
                      : family == 'zipvoice'
                      ? const {'min_char_in_sentence': 1}
                      : const <String, Object>{},
                ),
              }),
            );
          await reader.readStatus();
          final rate = await reader.readInteger();
          final count = await reader.readInteger();
          if (rate != sampleRate ||
              count > speechWorkerMaxSamples ||
              audio.length + count * 4 > speechWorkerMaxSamples * 4) {
            throw const FormatException('Invalid speech audio payload.');
          }
          audio.add(await reader.readBytes(count * 4));
        }
      } catch (error, stack) {
        failure = error;
        failureStack = stack;
      } finally {
        timer.cancel();
      }
      if (cancellation.value != 0) {
        if (!exited) child.kill();
        await child.exitCode;
        reply.send({
          'samples': TransferableTypedData.fromList([Uint8List(0)]),
          'sampleRate': sampleRate,
          'workerStopped': true,
        });
      } else if (failure != null) {
        reply.send({'error': 'Speech process failed: $failure'});
        Error.throwWithStackTrace(failure, failureStack!);
      } else {
        reply.send({
          'samples': TransferableTypedData.fromList([audio.takeBytes()]),
          'sampleRate': sampleRate,
        });
      }
    }
  } catch (error, stack) {
    if (ready) Error.throwWithStackTrace(error, stack);
    owner.send('Unable to load speech model: $error');
  } finally {
    commands.close();
    if (process != null) {
      if (!exited) process.kill();
      await process.exitCode;
      process.closeInput();
    }
    await reader?.close();
    await process?.close();
  }
}
