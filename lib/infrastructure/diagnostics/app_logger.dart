import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract final class AppLogger {
  static File? _file;
  static int _maxBytes = 512 * 1024;
  static int _backupCount = 3;
  static Future<void> _io = Future<void>.value();
  static int _pendingWrites = 0;

  static Future<void> flush() => _io;

  static Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _io.then((_) => operation());
    _io = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  static String? get logFilePath => _file?.path;

  static Future<bool> initialize({
    Directory? directory,
    int maxBytes = 512 * 1024,
    int backupCount = 3,
  }) async {
    await flush();
    _maxBytes = maxBytes;
    _backupCount = backupCount;
    _file = null;
    try {
      final root = directory ?? await getApplicationSupportDirectory();
      final logDirectory = Directory(p.join(root.path, 'logs'));
      await logDirectory.create(recursive: true);
      _file = File(p.join(logDirectory.path, 'godsense.log'));
      await deleteExpired(const Duration(days: 7));
      info('Local diagnostic logging initialized.', category: 'diagnostics');
      await flush();
      return true;
    } catch (error, stackTrace) {
      _file = null;
      if (kDebugMode) {
        debugPrint(
          'GodSense diagnostic logging is unavailable: ${redact(error)}\n'
          '${redact(stackTrace)}',
        );
      }
      return false;
    }
  }

  static Future<List<Map<String, Object?>>> exportEntries() async {
    return exportEntriesStream().toList();
  }

  static Stream<Map<String, Object?>> exportEntriesStream() async* {
    await flush();
    for (final file in await _existingFiles()) {
      final lines = file
          .openRead()
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          final decoded = jsonDecode(line);
          if (decoded is Map) {
            yield decoded.cast<String, Object?>();
          }
        } catch (_) {
          yield {'message': redact(line), 'malformed': true};
        }
      }
    }
  }

  static Future<int> deleteExpired(Duration maxAge, {DateTime? now}) =>
      _serialize(() async {
        final cutoff = (now ?? DateTime.now()).toUtc().subtract(maxAge);
        var deleted = 0;
        for (final file in await _existingFiles()) {
          final fallbackTimestamp = (await file.lastModified()).toUtc();
          final lines = await file.readAsLines();
          final retained = <String>[];
          for (final line in lines) {
            if (line.trim().isEmpty) continue;
            final timestamp = _entryTimestamp(line) ?? fallbackTimestamp;
            if (!timestamp.isBefore(cutoff)) retained.add(line);
          }
          if (retained.isEmpty) {
            await file.delete();
            deleted++;
          } else if (retained.length !=
              lines.where((line) => line.trim().isNotEmpty).length) {
            await file.writeAsString('${retained.join('\n')}\n', flush: true);
          }
        }
        return deleted;
      });

  static Future<int> deleteAll() => _serialize(() async {
    var deleted = 0;
    for (final file in await _existingFiles()) {
      await file.delete();
      deleted++;
    }
    return deleted;
  });

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
      RegExp(r'(https?://)([^/@\s:]+):([^/@\s]+)@', caseSensitive: false),
      (match) => '${match.group(1)}${match.group(2)}:[REDACTED]@',
    );
    text = text.replaceAllMapped(
      RegExp(
        r'([?&](?:gameName|tagLine|puuid|name)=)[^&\s]+',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}[REDACTED]',
    );
    text = text.replaceAllMapped(
      RegExp(r'(/(?:ranked-stats|summoners?)/)[^/?\s]+', caseSensitive: false),
      (match) => '${match.group(1)}[REDACTED]',
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
    // Bound the queue if a drive is slow; diagnostic traffic must not exhaust
    // memory or synchronously stall the UI waiting for disk.
    if (_pendingWrites >= 256) return;
    _pendingWrites++;
    unawaited(
      _serialize(() async {
        try {
          await _rotateIfNeeded(file, utf8.encode(entry).length + 1);
          await file.writeAsString('$entry\n', mode: FileMode.append);
        } catch (_) {
          // Diagnostics must never take down the application.
        } finally {
          _pendingWrites--;
        }
      }),
    );
  }

  static Future<void> _rotateIfNeeded(File file, int incomingBytes) async {
    if (!await file.exists() ||
        await file.length() + incomingBytes <= _maxBytes) {
      return;
    }
    for (var index = _backupCount; index >= 1; index--) {
      final current = File('${file.path}.$index');
      if (index == _backupCount && await current.exists()) {
        await current.delete();
      }
      final previous = index == 1 ? file : File('${file.path}.${index - 1}');
      if (await previous.exists()) await previous.rename(current.path);
    }
  }

  static Future<List<File>> _existingFiles() async {
    final file = _file;
    if (file == null || !await file.parent.exists()) return const [];
    final baseName = p.basename(file.path);
    return (await file.parent.list().toList())
        .whereType<File>()
        .where((candidate) {
          final name = p.basename(candidate.path);
          return name == baseName || name.startsWith('$baseName.');
        })
        .toList(growable: false);
  }

  static DateTime? _entryTimestamp(String line) {
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map) return null;
      return DateTime.tryParse(decoded['timestamp']?.toString() ?? '')?.toUtc();
    } catch (_) {
      return null;
    }
  }
}
