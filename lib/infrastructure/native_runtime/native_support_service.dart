import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class NativeSupportService {
  NativeSupportService({Future<Directory> Function()? rootDirectory})
    : _rootDirectory = rootDirectory ?? _defaultRoot;

  final Future<Directory> Function() _rootDirectory;

  Future<Map<String, dynamic>> createBundle({
    required Map<String, dynamic> settings,
    required Map<String, dynamic> health,
    String? note,
  }) async {
    final now = DateTime.now().toUtc();
    final root = await _rootDirectory();
    await root.create(recursive: true);
    final diagnostics = utf8.encode(
      const JsonEncoder.withIndent('  ').convert({
        'generated_at': now.toIso8601String(),
        'runtime': 'native_flutter',
        'operating_system': Platform.operatingSystem,
        'operating_system_version': Platform.operatingSystemVersion,
        'processor_count': Platform.numberOfProcessors,
        'health': health,
        'settings': _redact(settings),
        if (note?.trim().isNotEmpty == true) 'user_description': note!.trim(),
        'privacy': {
          'contains_lcu_credentials': false,
          'contains_audio': false,
          'contains_screen_capture': false,
        },
      }),
    );
    final archive = Archive()
      ..addFile(
        ArchiveFile('diagnostics.json', diagnostics.length, diagnostics),
      );
    final bytes = ZipEncoder().encodeBytes(archive, modified: now);
    final file = File(p.join(root.path, 'godsense-support-${_stamp(now)}.zip'));
    await file.writeAsBytes(bytes, flush: true);
    return {
      'created': true,
      'path': file.path,
      'bytes': bytes.length,
      'contains_secrets': false,
      'generated_at': now.toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> saveReport(String note) async {
    final normalized = note.trim();
    if (normalized.isEmpty) {
      throw const FormatException('La nota del reporte está vacía.');
    }
    final now = DateTime.now().toUtc();
    final root = await _rootDirectory();
    await root.create(recursive: true);
    final file = File(p.join(root.path, 'report-${_stamp(now)}.json'));
    await file.writeAsString(
      const JsonEncoder.withIndent(' ').convert({
        'created_at': now.toIso8601String(),
        'note': normalized,
        'status': 'saved_locally',
      }),
      flush: true,
    );
    return {
      'saved_locally': true,
      'path': file.path,
      'uploaded': false,
      'created_at': now.toIso8601String(),
    };
  }

  static Future<Directory> _defaultRoot() async => Directory(
    p.join((await getApplicationSupportDirectory()).path, 'support'),
  );
}

Map<String, dynamic> _redact(Map<String, dynamic> source) => {
  for (final entry in source.entries)
    if (!RegExp(
      r'password|token|credential|authorization|lockfile|secret',
      caseSensitive: false,
    ).hasMatch(entry.key))
      entry.key: _redactValue(entry.value),
};

Object? _redactValue(Object? value) => switch (value) {
  Map value => _redact(Map<String, dynamic>.from(value)),
  List value => value.map(_redactValue).toList(growable: false),
  _ => value,
};

String _stamp(DateTime value) =>
    value.toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
