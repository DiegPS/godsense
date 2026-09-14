import 'dart:async';

import 'package:dart_ai_runtime/dart_ai_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'enabled downloads install and start the downloaded installation',
    () async {
      final installer = _FakeInstaller(installedByDefault: false);
      final processes = _FakeProcesses();
      final supervisor = AiRuntimeSupervisor(
        installer: installer,
        processes: processes,
        health: _HealthyClient(),
        allowDownloads: true,
      );
      addTearDown(supervisor.dispose);
      await supervisor.start(AiRuntimeKind.kilo);
      expect(installer.installCount, 1);
      expect(processes.paths, ['downloaded/kilo']);
      expect(supervisor.state.isReady, isTrue);
    },
  );

  test('install stops an active runtime before changing lifecycle', () async {
    final processes = _FakeProcesses();
    final supervisor = AiRuntimeSupervisor(
      installer: _FakeInstaller(),
      processes: processes,
      health: _HealthyClient(),
      allowDownloads: true,
    );
    addTearDown(supervisor.dispose);
    await supervisor.start(AiRuntimeKind.kilo);
    await supervisor.install(AiRuntimeKind.openCode);
    expect(processes.handles.single.stopped, isTrue);
    expect(supervisor.state.endpoint, isNull);
    expect(supervisor.state.lifecycle, AiRuntimeLifecycle.stopped);
    await supervisor.start(AiRuntimeKind.openCode);
    expect(supervisor.state.isReady, isTrue);
  });

  test('cancelling an automatic installation never starts a process', () async {
    final installer = _FakeInstaller(
      installedByDefault: false,
      waitForCancellation: true,
    );
    final processes = _FakeProcesses();
    final supervisor = AiRuntimeSupervisor(
      installer: installer,
      processes: processes,
      health: _HealthyClient(),
      allowDownloads: true,
    );
    addTearDown(supervisor.dispose);
    final operation = supervisor.start(AiRuntimeKind.kilo);
    final assertion = expectLater(
      operation,
      throwsA(isA<ArtifactDownloadCancelledException>()),
    );
    await installer.entered.future;
    supervisor.cancelInstallation();
    await assertion;
    expect(processes.handles, isEmpty);
    expect(supervisor.state.error, isNull);
    expect(supervisor.state.lifecycle, AiRuntimeLifecycle.stopped);
  });

  test('switching runtimes stops the previous process first', () async {
    final installer = _FakeInstaller();
    final processes = _FakeProcesses();
    final supervisor = AiRuntimeSupervisor(
      installer: installer,
      processes: processes,
      health: _HealthyClient(),
      passwordGenerator: () => 'secret',
    );
    addTearDown(supervisor.dispose);

    await supervisor.start(AiRuntimeKind.openCode);
    final first = processes.handles.single;
    await supervisor.start(AiRuntimeKind.kilo);

    expect(first.stopped, isTrue);
    expect(processes.handles, hasLength(2));
    expect(supervisor.state.kind, AiRuntimeKind.kilo);
    expect(supervisor.state.lifecycle, AiRuntimeLifecycle.ready);
    expect(processes.passwords, everyElement('secret'));
  });

  test('an unexpected exit moves the supervisor to crashed', () async {
    final processes = _FakeProcesses();
    final supervisor = AiRuntimeSupervisor(
      installer: _FakeInstaller(),
      processes: processes,
      health: _HealthyClient(),
    );
    addTearDown(supervisor.dispose);

    await supervisor.start(AiRuntimeKind.openCode);
    processes.handles.single.crash(17);
    await Future<void>.delayed(Duration.zero);

    expect(supervisor.state.lifecycle, AiRuntimeLifecycle.crashed);
    expect(supervisor.state.error, contains('17'));
  });

  test('concurrent starts for the same runtime share one process', () async {
    final processes = _FakeProcesses();
    final supervisor = AiRuntimeSupervisor(
      installer: _FakeInstaller(),
      processes: processes,
      health: _HealthyClient(),
    );
    addTearDown(supervisor.dispose);

    final first = supervisor.start(AiRuntimeKind.openCode);
    final second = supervisor.start(AiRuntimeKind.openCode);
    await Future.wait([first, second]);

    expect(processes.handles, hasLength(1));
  });

  test('supervisor with allowDownloads: false blocks install and uninstalled starts', () async {
    final emptyInstaller = _FakeInstaller(installedByDefault: false);
    final supervisor = AiRuntimeSupervisor(
      installer: emptyInstaller,
      processes: _FakeProcesses(),
      health: _HealthyClient(),
      allowDownloads: false,
    );
    addTearDown(supervisor.dispose);

    // Direct install call must throw UnsupportedError
    expect(
      () => supervisor.install(AiRuntimeKind.kilo),
      throwsA(isA<UnsupportedError>()),
    );

    // Starting an uninstalled runtime without downloads must throw StateError
    expect(
      () => supervisor.start(AiRuntimeKind.kilo),
      throwsA(isA<StateError>()),
    );
  });
}

class _FakeInstaller implements AiRuntimeInstallService {
  _FakeInstaller({
    this.installedByDefault = true,
    this.waitForCancellation = false,
  });

  final bool installedByDefault;
  final bool waitForCancellation;
  final entered = Completer<void>();
  int installCount = 0;

  final _catalog = <AiRuntimeKind, AiRuntimeDefinition>{
    for (final kind in AiRuntimeKind.values)
      kind: AiRuntimeDefinition(
        kind: kind,
        version: '1',
        executableName: '${kind.id}.exe',
        artifact: ArtifactSpec(
          id: kind.id,
          version: '1',
          group: 'ai',
          payloads: [
            ArtifactPayloadSpec(
              id: 'fixture',
              uri: Uri.parse('https://example.test/${kind.id}.zip'),
              sha256: List.filled(64, '0').join(),
              bytes: 1,
              fileName: '${kind.id}.zip',
              archiveType: ArtifactArchiveType.zip,
            ),
          ],
          requiredPaths: ['${kind.id}.exe'],
          license: ArtifactLicense(
            name: 'fixture',
            uri: Uri.parse('https://example.test/license'),
            notice: 'Test fixture only.',
          ),
        ),
      ),
  };

  @override
  AiRuntimeDefinition definition(AiRuntimeKind kind) => _catalog[kind]!;

  @override
  Future<AiRuntimeInstallation?> installed(AiRuntimeKind kind) async =>
      installedByDefault
      ? AiRuntimeInstallation(definition: definition(kind), directoryPath: '.')
      : null;

  @override
  Future<AiRuntimeInstallation> install(
    AiRuntimeKind kind, {
    ArtifactDownloadCancellation? cancellation,
    void Function(ArtifactInstallProgress progress)? onProgress,
  }) async {
    installCount++;
    if (!entered.isCompleted) entered.complete();
    if (waitForCancellation) {
      await cancellation!.whenCancelled;
      cancellation.throwIfCancelled();
    }
    return AiRuntimeInstallation(
      definition: definition(kind),
      directoryPath: 'downloaded/${kind.id}',
    );
  }
}

class _FakeProcesses implements AiRuntimeProcessService {
  final handles = <_FakeProcess>[];
  final passwords = <String>[];
  final paths = <String>[];

  @override
  Future<AiRuntimeProcessHandle> start(
    AiRuntimeInstallation installation, {
    required String password,
  }) async {
    passwords.add(password);
    paths.add(installation.directoryPath);
    final handle = _FakeProcess(installation.definition.kind, password);
    handles.add(handle);
    return handle;
  }
}

class _FakeProcess implements AiRuntimeProcessHandle {
  _FakeProcess(AiRuntimeKind kind, String password)
    : endpoint = AiRuntimeEndpoint(
        kind: kind,
        baseUri: Uri.parse('http://127.0.0.1:12345'),
        username: kind == AiRuntimeKind.openCode ? 'opencode' : 'kilo',
        password: password,
        pid: 1,
      );

  final _exit = Completer<int>();
  bool stopped = false;

  @override
  final AiRuntimeEndpoint endpoint;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  Stream<String> get logs => const Stream.empty();

  void crash(int code) => _exit.complete(code);

  @override
  Future<void> stop() async {
    stopped = true;
    if (!_exit.isCompleted) _exit.complete(0);
  }
}

class _HealthyClient implements AiRuntimeHealthService {
  @override
  Future<AiRuntimeHealth> waitUntilReady(
    AiRuntimeEndpoint endpoint, {
    Duration timeout = const Duration(seconds: 25),
  }) async => const AiRuntimeHealth(healthy: true, version: '1');
}
