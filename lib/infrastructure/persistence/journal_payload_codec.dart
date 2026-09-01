import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class EncodedJournalPayload {
  const EncodedJournalPayload({
    required this.bytes,
    required this.rawHash,
    required this.semanticHash,
  });

  final Uint8List bytes;
  final String rawHash;
  final String semanticHash;
}

class JournalPayloadCodec {
  const JournalPayloadCodec();

  EncodedJournalPayload encodeJson(Object? value, {Uint8List? originalBytes}) {
    final canonicalBytes = Uint8List.fromList(
      utf8.encode(jsonEncode(_canonicalize(value))),
    );
    final rawBytes = originalBytes ?? canonicalBytes;
    return EncodedJournalPayload(
      bytes: rawBytes,
      rawHash: sha256.convert(rawBytes).toString(),
      semanticHash: sha256.convert(canonicalBytes).toString(),
    );
  }

  Object? _canonicalize(Object? value) {
    if (value is Map) {
      final entries =
          value.entries
              .map((entry) => MapEntry(entry.key.toString(), entry.value))
              .toList()
            ..sort((left, right) => left.key.compareTo(right.key));
      return <String, Object?>{
        for (final entry in entries) entry.key: _canonicalize(entry.value),
      };
    }
    if (value is Iterable) return value.map(_canonicalize).toList();
    return value;
  }
}
