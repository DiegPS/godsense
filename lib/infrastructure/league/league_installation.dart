import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart';

String? activeLeagueDirectory() {
  if (!Platform.isWindows) return null;
  final ids = calloc<Uint32>(4096);
  final count = calloc<Uint32>();
  final length = calloc<Uint32>();
  final name = calloc<Uint16>(32768).cast<Utf16>();
  try {
    if (!EnumProcesses(ids, 4096 * 4, count).value) return null;
    for (var i = 0; i < (count.value ~/ 4).clamp(0, 4096); i++) {
      final process = OpenProcess(
        PROCESS_QUERY_LIMITED_INFORMATION,
        false,
        ids[i],
      ).value;
      if (process.isNull) continue;
      try {
        length.value = 32768;
        if (!QueryFullProcessImageName(
          process,
          PROCESS_NAME_WIN32,
          PWSTR(name),
          length,
        ).value) {
          continue;
        }
        final executable = name.toDartString(length: length.value);
        if (p.basename(executable).toLowerCase() == 'leagueclient.exe') {
          return p.dirname(executable);
        }
      } finally {
        CloseHandle(process);
      }
    }
    return null;
  } finally {
    calloc.free(ids);
    calloc.free(count);
    calloc.free(length);
    calloc.free(name);
  }
}

class LeagueConfigSource {
  LeagueConfigSource({
    this.override,
    List<String>? candidates,
    String? Function()? activeDirectory,
  }) : candidates =
           candidates ??
           [
             r'C:\Riot Games\League of Legends',
             r'C:\Program Files\Riot Games\League of Legends',
             if (Platform.environment['PROGRAMDATA'] != null)
               '${Platform.environment['PROGRAMDATA']}\\Riot Games\\League of Legends',
           ],
       activeDirectory = activeDirectory ?? activeLeagueDirectory;
  final String? override;
  final List<String> candidates;
  final String? Function() activeDirectory;

  Map<String, num> read() {
    final explicit = override ?? Platform.environment['GODSENSE_LCU_LOCKFILE'];
    final paths = <String>[
      ?explicit,
      if (activeDirectory() case final String directory) directory,
      ...candidates,
    ];
    for (final candidate in paths) {
      final directory =
          p.extension(candidate).toLowerCase() == '.exe' ||
              p.basename(candidate) == 'lockfile'
          ? p.dirname(candidate)
          : candidate;
      final file = File(
        p.basename(candidate) == 'game.cfg'
            ? candidate
            : p.join(directory, 'Config', 'game.cfg'),
      );
      try {
        if (file.existsSync()) return parse(file.readAsStringSync());
      } on FileSystemException {
        continue;
      }
    }
    return const {};
  }

  static Map<String, num> parse(String text) {
    final result = <String, num>{};
    var section = '';
    for (var line in text.split(RegExp(r'[\r\n]+'))) {
      line = line.split(';').first.trim();
      if (line.startsWith('[') && line.endsWith(']')) {
        section = line.substring(1, line.length - 1).toLowerCase();
        continue;
      }
      if (section != 'general' && section != 'hud') continue;
      final separator = line.indexOf('=');
      if (separator < 1) continue;
      final key = line.substring(0, separator).trim().toLowerCase();
      if (!const [
        'width',
        'height',
        'minimapscale',
        'windowmode',
      ].contains(key)) {
        continue;
      }
      final value = num.tryParse(line.substring(separator + 1).trim());
      if (value != null &&
          value.isFinite &&
          (key == 'windowmode' ? value >= 0 : value > 0)) {
        result[key] = value;
      }
    }
    return result;
  }
}

Future<Map<String, num>> readLeagueCalibrationContext() =>
    Isolate.run(() => LeagueConfigSource().read());

bool calibrationContextChanged(
  Map<String, dynamic>? saved,
  Map<String, num> current,
) {
  if (saved == null) return false;
  return current.entries.any(
    (entry) =>
        saved[entry.key] is num &&
        ((saved[entry.key] as num) - entry.value).abs() > 0.0001,
  );
}
