import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/infrastructure/native_runtime/native_support_service.dart';

void main() {
  late Directory root;
  late NativeSupportService service;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('godsense-support-');
    service = NativeSupportService(rootDirectory: () async => root);
  });

  tearDown(() => root.delete(recursive: true));

  test('creates a real ZIP and removes credential-shaped settings', () async {
    final result = await service.createBundle(
      settings: const {
        'language': 'es',
        'lcu_password': 'must-not-leak',
        'authorization': 'must-not-leak',
      },
      health: const {'status': 'ok'},
    );

    final file = File(result['path'] as String);
    expect(await file.exists(), isTrue);
    final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
    final diagnostics = archive.findFile('diagnostics.json');
    expect(diagnostics, isNotNull);
    final text = utf8.decode(diagnostics!.content as List<int>);
    expect(text, contains('"language": "es"'));
    expect(text, isNot(contains('must-not-leak')));
    expect(result['contains_secrets'], isFalse);
  });

  test('saves a report locally without claiming it was uploaded', () async {
    final result = await service.saveReport('El overlay perdió posición.');

    expect(result['saved_locally'], isTrue);
    expect(result['uploaded'], isFalse);
    final text = await File(result['path'] as String).readAsString();
    expect(text, contains('El overlay perdió posición.'));
  });
}
