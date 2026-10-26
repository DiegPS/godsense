import 'dart:developer' as developer;
import 'dart:io';

import 'package:coverage/coverage.dart' as coverage;
import 'package:path/path.dart' as p;

// Flutter's final collection happens after teardown, when native workers have
// already exited. Snapshot the real, still-alive workers before disposing them.
Future<void> snapshotNativeWorkerCoverage(String label) async {
  final directory = Platform.environment['GODSENSE_NATIVE_COVERAGE_DIR'];
  if (directory == null) return;
  final service = await developer.Service.getInfo();
  final uri = service.serverUri;
  if (uri == null) {
    throw StateError(
      'Native worker coverage requires --coverage / a VM service.',
    );
  }
  final root = Directory.current.absolute.path;
  final data = await coverage.collect(uri, false, false, false, {
    'godsense',
  }, timeout: const Duration(seconds: 20));
  final resolver = await coverage.Resolver.create(
    packagesPath: p.join(root, '.dart_tool', 'package_config.json'),
    packagePath: root,
  );
  final hits = coverage.HitMap.parseJsonSync(
    (data['coverage'] as List).cast<Map<String, dynamic>>(),
    checkIgnoredLines: false,
    ignoredLinesInFilesCache: {},
    resolver: resolver,
  );
  final lcov = coverage.FileHitMapsFormatter(hits)
      .formatLcov(resolver, basePath: root, reportOn: [p.join(root, 'lib')]);
  if (!lcov.contains('DA:')) {
    throw StateError('Native coverage snapshot was empty.');
  }
  await Directory(directory).create(recursive: true);
  final name = label.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '-');
  await File(
    p.join(
      directory,
      'native-worker-$name-$pid-${DateTime.now().microsecondsSinceEpoch}.info',
    ),
  ).writeAsString(lcov);
}
