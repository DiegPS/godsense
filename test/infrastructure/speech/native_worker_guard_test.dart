import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/infrastructure/speech/native_worker_guard.dart';

void main() {
  test('intentional startup cancellation releases waiters without reporting a crash', () async {
    var reported = 0;
    final guard = NativeWorkerGuard(
      label: 'synthetic',
      onFailure: (_, _) => reported++,
    );
    await guard.dispose(expectedExit: true);
    expect(
      await guard.failure.timeout(const Duration(seconds: 1)),
      isA<StateError>(),
    );
    expect(reported, 0);
    await guard.dispose(expectedExit: true);
  });

  test('disposing listeners never pretends the native worker has physically exited', () async {
    final guard = NativeWorkerGuard(label: 'synthetic', onFailure: (_, _) {});
    guard.markReady();
    await guard.dispose(expectedExit: true);
    await expectLater(
      guard.exited.timeout(const Duration(milliseconds: 20)),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('a real exit reports one failure and confirms physical exit', () async {
    final reports = <bool>[];
    final guard = NativeWorkerGuard(
      label: 'synthetic',
      onFailure: (_, ready) => reports.add(ready),
    );
    guard.markReady();
    guard.exitPort.sendPort.send(null);
    await guard.exited.timeout(const Duration(seconds: 1));
    expect(await guard.failure, isA<StateError>());
    await Future<void>.delayed(Duration.zero);
    expect(reports, [true]);
    guard.reportFailure(StateError('duplicate'));
    expect(reports, [true]);
    await guard.dispose(expectedExit: false);
  });
}
