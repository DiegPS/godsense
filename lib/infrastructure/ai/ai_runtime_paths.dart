import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/ai/ai_runtime_models.dart';

class AiRuntimePaths {
  AiRuntimePaths(this.root);

  final Directory root;

  static Future<AiRuntimePaths> createDefault() async {
    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData != null && localAppData.isNotEmpty) {
        return AiRuntimePaths(Directory(p.join(localAppData, 'GodSense')));
      }
    }
    final support = await getApplicationSupportDirectory();
    return AiRuntimePaths(Directory(p.join(support.path, 'GodSense')));
  }

  Directory family(AiRuntimeKind kind) =>
      Directory(p.join(root.path, 'ai', kind.id));

  Directory data(AiRuntimeKind kind) =>
      Directory(p.join(family(kind).path, 'data'));
  Directory cache(AiRuntimeKind kind) =>
      Directory(p.join(family(kind).path, 'cache'));
  Directory config(AiRuntimeKind kind) =>
      Directory(p.join(family(kind).path, 'config'));
  Directory state(AiRuntimeKind kind) =>
      Directory(p.join(family(kind).path, 'state'));
  Directory temp(AiRuntimeKind kind) =>
      Directory(p.join(family(kind).path, 'temp'));
  Directory workspace(AiRuntimeKind kind) =>
      Directory(p.join(family(kind).path, 'workspace'));

  Future<void> createRuntimeDirectories(AiRuntimeKind kind) async {
    for (final directory in [
      data(kind),
      cache(kind),
      config(kind),
      state(kind),
      temp(kind),
      workspace(kind),
    ]) {
      await directory.create(recursive: true);
    }
  }
}
