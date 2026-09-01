import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'journal_payload_codec.dart';

class DerivationKeyBuilder {
  const DerivationKeyBuilder({this.payloadCodec = const JournalPayloadCodec()});

  final JournalPayloadCodec payloadCodec;

  String build({
    required String producer,
    required String producerVersion,
    required List<String> orderedParentIds,
    Object? parameters,
  }) {
    final parameterHash = payloadCodec.encodeJson(parameters).semanticHash;
    final identity = jsonEncode({
      'producer': producer,
      'producerVersion': producerVersion,
      'orderedParentIds': orderedParentIds,
      'parameterHash': parameterHash,
    });
    return sha256.convert(utf8.encode(identity)).toString();
  }
}
