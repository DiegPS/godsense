import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

const speechWorkerMagic = 0x31545347;
const speechWorkerMaxStringBytes = 1024 * 1024;
const speechWorkerMaxSamples = 16000000;

Uint8List speechWorkerInteger(int value) {
  if (value < 0 || value > 0xffffffff) throw RangeError.value(value);
  return (ByteData(4)..setUint32(0, value, Endian.little)).buffer.asUint8List();
}

Uint8List encodeSpeechWorkerFields(Map<String, String> fields) {
  if (fields.length > 64) {
    throw const FormatException('Too many speech fields.');
  }
  final output = BytesBuilder(copy: false)
    ..add(speechWorkerInteger(fields.length));
  var total = 0;
  for (final entry in fields.entries) {
    for (final value in [entry.key, entry.value]) {
      final bytes = utf8.encode(value);
      total += bytes.length;
      if (value.contains('\u0000') ||
          bytes.length > speechWorkerMaxStringBytes ||
          total > 4 * speechWorkerMaxStringBytes) {
        throw const FormatException(
          'Speech field exceeds the protocol limits.',
        );
      }
      output
        ..add(speechWorkerInteger(bytes.length))
        ..add(bytes);
    }
  }
  return output.takeBytes();
}

class SpeechWorkerReader {
  SpeechWorkerReader(Stream<List<int>> input) : _input = StreamIterator(input);
  final StreamIterator<List<int>> _input;
  List<int> _current = const [];
  int _offset = 0;

  Future<Uint8List> readBytes(int length) async {
    if (length < 0 || length > speechWorkerMaxSamples * 4) {
      throw const FormatException(
        'Speech payload exceeds the protocol limits.',
      );
    }
    final result = Uint8List(length);
    var written = 0;
    while (written < length) {
      if (_offset == _current.length) {
        if (!await _input.moveNext()) {
          throw const FormatException(
            'Speech process closed an incomplete response.',
          );
        }
        _current = _input.current;
        _offset = 0;
        continue;
      }
      final count = (length - written).clamp(0, _current.length - _offset);
      result.setRange(written, written + count, _current, _offset);
      written += count;
      _offset += count;
    }
    return result;
  }

  Future<int> readInteger() async =>
      ByteData.sublistView(await readBytes(4)).getUint32(0, Endian.little);

  Future<String> readString() async {
    final length = await readInteger();
    if (length > speechWorkerMaxStringBytes) {
      throw const FormatException('Speech string exceeds the protocol limits.');
    }
    final value = utf8.decode(await readBytes(length));
    if (value.contains('\u0000')) {
      throw const FormatException('Invalid speech string.');
    }
    return value;
  }

  Future<void> readStatus() async {
    final status = await readInteger();
    if (status == 1) throw StateError(await readString());
    if (status != 0) {
      throw const FormatException('Unknown speech response status.');
    }
  }

  Future<void> close() => _input.cancel();
}
