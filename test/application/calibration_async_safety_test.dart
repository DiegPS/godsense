import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/native_calibration_controller.dart';
import 'package:godsense/domain/calibration_repository.dart';
import 'package:godsense/domain/companion_models.dart';
import 'package:godsense/infrastructure/native_vision/desktop_screen_capture.dart';

void main() {
  test('a newer explicit load supersedes an obsolete refresh error', () async {
    final repository = _Repository()..value = _saved;
    final controller = NativeCalibrationController(
      repository,
      screenCapture: _Metadata(),
    );
    addTearDown(controller.dispose);
    await controller.load();
    final gate = Completer<CalibrationState?>();
    repository.nextLoad = gate.future;
    final refreshing = controller.refreshContext();
    await repository.pendingLoadStarted.future;
    await controller.load();
    gate.completeError(StateError('synthetic obsolete refresh'));
    await refreshing;
    expect(controller.state.error, isNull);
  });

  test(
    'a requested save can finish after closing during monitor lookup',
    () async {
      final repository = _Repository();
      final metadata = _Metadata();
      final gate = Completer<Map<String, dynamic>>();
      metadata.pending = gate.future;
      final controller = NativeCalibrationController(
        repository,
        screenCapture: metadata,
      );
      const bounds = {'left': -420, 'top': 700, 'width': 300, 'height': 300};
      final saving = controller.save(bounds);
      await metadata.started.future;
      controller.dispose();
      gate.complete({...bounds, 'display_id': 'user-confirmed-display'});
      await saving;
      expect(repository.value?.bounds?['display_id'], 'user-confirmed-display');
    },
  );

  test('a read waits for a requested clear without cancelling it', () async {
    final repository = _Repository();
    final gate = Completer<void>();
    repository.saveGate = gate.future;
    final controller = NativeCalibrationController(
      repository,
      screenCapture: _Metadata(),
    );
    addTearDown(controller.dispose);
    final saving = controller.save(_saved.bounds!);
    await repository.savingStarted.future;
    final clearing = controller.clear();
    final loading = controller.load();
    gate.complete();
    await Future.wait([saving, clearing, loading]);
    expect(repository.value, isNull);
    expect(controller.state.calibration, isNull);
    expect(controller.state.loading, isFalse);
  });

  test('the newest calibration read wins over an older delayed read', () async {
    final repository = _Repository();
    final gate = Completer<CalibrationState?>();
    repository.nextLoad = gate.future;
    final controller = NativeCalibrationController(
      repository,
      screenCapture: _Metadata(),
    );
    addTearDown(controller.dispose);
    final older = controller.load();
    await repository.pendingLoadStarted.future;
    repository.value = const CalibrationState(
      calibrated: true,
      recalibrationSuggested: false,
      bounds: {
        'left': 500,
        'top': 100,
        'width': 300,
        'height': 300,
        'display_id': 'new-display',
      },
      iconSize: 26,
    );
    await controller.load();
    gate.complete(_saved);
    await older;
    expect(controller.state.calibration?.bounds?['left'], 500);
  });

  test(
    'an explicitly requested clear stays queued when its controller closes',
    () async {
      final repository = _Repository();
      final gate = Completer<void>();
      repository.saveGate = gate.future;
      final controller = NativeCalibrationController(
        repository,
        screenCapture: _Metadata(),
      );
      var closed = false;
      addTearDown(() {
        if (!closed) controller.dispose();
      });
      final saving = controller.save(_saved.bounds!);
      await repository.savingStarted.future;
      final clearing = controller.clear();
      controller.dispose();
      closed = true;
      gate.complete();
      await Future.wait([saving, clearing]);
      expect(repository.value, isNull);
    },
  );

  test('failed older write does not poison a newer clear', () async {
    final repository = _Repository()..value = _saved;
    final gate = Completer<void>();
    repository.saveGate = gate.future;
    final controller = NativeCalibrationController(
      repository,
      screenCapture: _Metadata(),
    );
    addTearDown(controller.dispose);
    final saving = expectLater(
      controller.save(_saved.bounds!),
      throwsStateError,
    );
    await repository.savingStarted.future;
    final clearing = controller.clear();
    gate.completeError(StateError('synthetic old write failure'));
    await Future.wait([saving, clearing]);
    expect(repository.value, isNull);
    expect(controller.state.error, isNull);
    expect(controller.state.saving, isFalse);
  });

  test(
    'clear finishes after an older in-flight write and stays cleared',
    () async {
      final repository = _Repository();
      final gate = Completer<void>();
      repository.saveGate = gate.future;
      final controller = NativeCalibrationController(
        repository,
        screenCapture: _Metadata(),
      );
      addTearDown(controller.dispose);
      final saving = controller.save(_saved.bounds!);
      await repository.savingStarted.future;
      final clearing = controller.clear();
      gate.complete();
      await Future.wait([saving, clearing]);
      expect(repository.value, isNull);
      expect(controller.state.calibration, isNull);
      expect(controller.state.saving, isFalse);
    },
  );

  test(
    'closing during normalization prevents a later preferences write',
    () async {
      final repository = _Repository()..value = _saved;
      final metadata = _Metadata();
      final gate = Completer<Map<String, dynamic>>();
      metadata.pending = gate.future;
      final controller = NativeCalibrationController(
        repository,
        screenCapture: metadata,
      );
      final loading = controller.load();
      await metadata.started.future;
      controller.dispose();
      gate.complete({..._saved.bounds!, 'display_id': 'late-description'});
      await loading;
      expect(repository.saves, 0);
    },
  );

  test(
    'a late initial read cannot restore a user-cleared calibration',
    () async {
      final repository = _Repository()..value = _saved;
      final pending = Completer<CalibrationState?>();
      repository.nextLoad = pending.future;
      final controller = NativeCalibrationController(
        repository,
        screenCapture: _Metadata(),
      );
      addTearDown(controller.dispose);
      final loading = controller.load();
      await repository.pendingLoadStarted.future;
      await controller.clear();
      pending.complete(_saved);
      await loading;
      expect(repository.value, isNull);
      expect(controller.state.calibration, isNull);
      expect(controller.state.loading, isFalse);
      expect(controller.state.saving, isFalse);
    },
  );

  test(
    'a late monitor description cannot persist calibration after clear',
    () async {
      final repository = _Repository()..value = _saved;
      final metadata = _Metadata();
      final pending = Completer<Map<String, dynamic>>();
      metadata.pending = pending.future;
      final controller = NativeCalibrationController(
        repository,
        screenCapture: metadata,
      );
      addTearDown(controller.dispose);
      final loading = controller.load();
      await metadata.started.future;
      await controller.clear();
      pending.complete({
        ..._saved.bounds!,
        'display_id': 'new-display-description',
      });
      await loading;
      expect(repository.value, isNull);
      expect(
        repository.saves,
        0,
        reason: 'Normalization must not resurrect cleared data.',
      );
      expect(controller.state.calibration, isNull);
    },
  );

  test('an obsolete refresh error cannot replace state after clear', () async {
    final repository = _Repository()..value = _saved;
    final controller = NativeCalibrationController(
      repository,
      screenCapture: _Metadata(),
    );
    addTearDown(controller.dispose);
    await controller.load();
    final pending = Completer<CalibrationState?>();
    repository.nextLoad = pending.future;
    final refreshing = controller.refreshContext();
    await controller.clear();
    pending.completeError(StateError('obsolete fixture read'));
    await refreshing;
    expect(controller.state.error, isNull);
    expect(controller.state.calibration, isNull);
  });

  test(
    'a late initial read cannot replace a newly saved calibration',
    () async {
      final repository = _Repository()..value = _saved;
      final pending = Completer<CalibrationState?>();
      repository.nextLoad = pending.future;
      final controller = NativeCalibrationController(
        repository,
        screenCapture: _Metadata(),
      );
      addTearDown(controller.dispose);
      final loading = controller.load();
      await repository.pendingLoadStarted.future;
      await controller.save(const {
        'left': -300,
        'top': 500,
        'width': 300,
        'height': 300,
        'display_id': 'new-calibration-display',
      });
      pending.complete(_saved);
      await loading;
      expect(controller.state.calibration?.bounds?['left'], -300);
      expect(repository.value?.bounds?['left'], -300);
      expect(controller.state.loading, isFalse);
      expect(controller.state.error, isNull);
    },
  );
}

const _saved = CalibrationState(
  calibrated: true,
  recalibrationSuggested: false,
  bounds: {
    'left': 100,
    'top': 100,
    'width': 300,
    'height': 300,
    'display_id': 'saved-display',
  },
  iconSize: 26,
);

class _Repository implements CalibrationRepository {
  CalibrationState? value;
  Future<CalibrationState?>? nextLoad;
  final pendingLoadStarted = Completer<void>();
  Future<void>? saveGate;
  final savingStarted = Completer<void>();
  int saves = 0;
  @override
  Future<CalibrationState?> load() {
    final pending = nextLoad;
    nextLoad = null;
    if (pending != null && !pendingLoadStarted.isCompleted) {
      pendingLoadStarted.complete();
    }
    return pending ?? Future.value(value);
  }

  @override
  Future<void> save(CalibrationState calibration) async {
    saves++;
    if (!savingStarted.isCompleted) savingStarted.complete();
    await saveGate;
    value = calibration;
  }

  @override
  Future<void> clear() async => value = null;
}

class _Metadata implements ScreenCaptureSource {
  final started = Completer<void>();
  Future<Map<String, dynamic>>? pending;
  @override
  Future<Map<String, dynamic>> describeBounds(Map<String, dynamic> bounds) {
    if (!started.isCompleted) started.complete();
    return pending ?? Future.value(bounds);
  }

  @override
  void dispose() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
