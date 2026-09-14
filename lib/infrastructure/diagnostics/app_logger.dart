import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract final class AppLogger {
  static File? _file;
  static int _maxBytes = 512 * 1024;
  static int _backupCount = 3;

  static String? get logFilePath => _file?.path;

  static Future<void> initialize({
    Directory? directory,
    int maxBytes = 512 * 1024,
    int backupCount = 3,
  }) async {
    final root = directory ?? await getApplicationSupportDirectory();
    final logDirectory = Directory(p.join(root.path, 'logs'));
    await logDirectory.create(recursive: true);
    _maxBytes = maxBytes;
    _backupCount = backupCount;
    _file = File(p.join(logDirectory.path, 'godsense.log'));
    await deleteExpired(const Duration(days: 7));
    info('Local diagnostic logging initialized.', category: 'diagnostics');
  }

  static Future<List<Map<String, Object?>>> exportEntries() async {
    final entries = <Map<String, Object?>>[];
    for (final file in _existingFiles()) {
      for (final line in await file.readAsLines()) {
        if (line.trim().isEmpty) continue;
        try {
          final decoded = jsonDecode(line);
          if (decoded is Map) {
            entries.add(decoded.cast<String, Object?>());
          }
        } catch (_) {
          entries.add({'message': redact(line), 'malformed': true});
        }
      }
    }
    return entries;
  }

  static Future<int> deleteExpired(Duration maxAge, {DateTime? now}) async {
    final cutoff = (now ?? DateTime.now()).toUtc().subtract(maxAge);
    var deleted = 0;
    for (final file in _existingFiles()) {
      if ((await file.lastModified()).toUtc().isBefore(cutoff)) {
        await file.delete();
        deleted++;
      }
    }
    return deleted;
  }

  static Future<int> deleteAll() async {
    var deleted = 0;
    for (final file in _existingFiles()) {
      await file.delete();
      deleted++;
    }
    return deleted;
  }

  static String redact(Object? value) {
    var text = value?.toString() ?? '';
    text = text.replaceAll(
      RegExp(r'\b(Basic|Bearer)\s+[A-Za-z0-9._~+/=-]+', caseSensitive: false),
      r'$1 [REDACTED]',
    );
    text = text.replaceAllMapped(
      RegExp(
        r'''("?(?:password|passwd|token|access_token|refresh_token|api[_-]?key|authorization|secret|puuid|gameName|tagLine|question|prompt)"?\s*[:=]\s*")[^"]*"''',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}[REDACTED]"',
    );
    text = text.replaceAllMapped(
      RegExp(
        r'''\b((?:password|passwd|token|access_token|refresh_token|api[_-]?key|authorization|secret|puuid|gameName|tagLine|question|prompt)\s*[:=]\s*)[^\s,}\]]+''',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}[REDACTED]',
    );
    text = text.replaceAllMapped(
      RegExp(r'https?://([^/@\s:]+):([^/@\s]+)@', caseSensitive: false),
      (match) => 'https://${match.group(1)}:[REDACTED]@',
    );
    text = text.replaceAll(
      RegExp(r'\b[A-Z]:\\Users\\[^\\\s]+', caseSensitive: false),
      r'C:\Users\[REDACTED]',
    );
    text = text.replaceAll(
      RegExp(
        r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
        caseSensitive: false,
      ),
      '[REDACTED_EMAIL]',
    );
    return text;
  }

  static void debug(String message, {String category = 'app'}) {
    if (kDebugMode) _write('debug', category, message);
  }

  static void info(String message, {String category = 'app'}) =>
      _write('info', category, message);

  static void warning(
    String message, {
    String category = 'app',
    Object? error,
    StackTrace? stackTrace,
  }) => _write(
    'warning',
    category,
    message,
    error: error,
    stackTrace: stackTrace,
  );

  static void error(
    String message, {
    String category = 'app',
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _write('error', category, message, error: error, stackTrace: stackTrace);

  static void _write(
    String level,
    String category,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final entry = jsonEncode({
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'level': level,
      'category': redact(category),
      'message': redact(message),
      if (error != null) 'error': redact(error),
      if (stackTrace != null) 'stack': redact(stackTrace),
    });
    if (kDebugMode) debugPrint(entry);
    final file = _file;
    if (file == null) return;
    try {
      _rotateIfNeeded(file, utf8.encode(entry).length + 1);
      file.writeAsStringSync('$entry\n', mode: FileMode.append, flush: true);
    } catch (_) {
      // Diagnostics must never take down the application.
    }
  }

  static void _rotateIfNeeded(File file, int incomingBytes) {
    if (!file.existsSync() || file.lengthSync() + incomingBytes <= _maxBytes) {
      return;
    }
    for (var index = _backupCount; index >= 1; index--) {
      final current = File('${file.path}.$index');
      if (index == _backupCount && current.existsSync()) {
        current.deleteSync();
      }
      final previous = index == 1 ? file : File('${file.path}.${index - 1}');
      if (previous.existsSync()) previous.renameSync(current.path);
    }
  }

  static List<File> _existingFiles() {
    final file = _file;
    if (file == null || !file.parent.existsSync()) return const [];
    final baseName = p.basename(file.path);
    return file.parent
        .listSync()
        .whereType<File>()
        .where((candidate) {
          final name = p.basename(candidate.path);
          return name == baseName || name.startsWith('$baseName.');
        })
        .toList(growable: false);
  }
}
