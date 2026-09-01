import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/infrastructure/persistence/journal_payload_codec.dart';

void main() {
  test(
    'semantic hash ignores JSON map key order but raw hash preserves bytes',
    () {
      const codec = JournalPayloadCodec();
      final first = codec.encodeJson({
        'b': 2,
        'a': 1,
      }, originalBytes: Uint8List.fromList(utf8.encode('{"b":2,"a":1}')));
      final second = codec.encodeJson({
        'a': 1,
        'b': 2,
      }, originalBytes: Uint8List.fromList(utf8.encode('{ "a": 1, "b": 2 }')));

      expect(first.semanticHash, second.semanticHash);
      expect(first.rawHash, isNot(second.rawHash));
      expect(utf8.decode(first.bytes), '{"b":2,"a":1}');
    },
  );

  test(
    'canonicalizes non-string JSON-compatible map keys without data loss',
    () {
      const codec = JournalPayloadCodec();
      final encoded = codec.encodeJson({2: 'second', 1: 'first'});

      expect(utf8.decode(encoded.bytes), '{"1":"first","2":"second"}');
    },
  );
}
