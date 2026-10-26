import 'dart:convert';
import 'dart:io';

import '../test/support/voice_model_cases.dart';

void main(List<String> arguments) {
  const usage = 'Usage: dart tool/voice_model_manifest.dart [--help]';
  if (arguments.length == 1 && arguments.single == '--help') {
    stdout.writeln(usage);
  } else if (arguments.isNotEmpty) {
    stderr.writeln(usage);
    exitCode = 64;
  } else {
    stdout.writeln(jsonEncode(voiceModelManifest()));
  }
}
