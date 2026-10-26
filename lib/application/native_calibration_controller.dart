import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/calibration_repository.dart';
import '../domain/companion_models.dart';
import '../infrastructure/native_vision/native_minimap_calibrator.dart';
import '../infrastructure/native_vision/desktop_screen_capture.dart';
import '../infrastructure/native_vision/shared_preferences_calibration_repository.dart';

class NativeCalibrationState {
  const NativeCalibrationState({
    this.loading = true,
    this.saving = false,
    this.calibration,
    this.error,
  });

  final bool loading;
  final bool saving;
  final CalibrationState? calibration;
  final String? error;

  NativeCalibrationState copyWith({
    bool? loading,
    bool? saving,
    CalibrationState? calibration,
    bool clearCalibration = false,
    String? error,
    bool clearError = false,
  }) {
    return NativeCalibrationState(
      loading: loading ?? this.loading,
      saving: saving ?? this.saving,
      calibration: clearCalibration ? null : calibration ?? this.calibration,
      error: clearError ? null : error ?? this.error,
    );
  }
}

final calibrationRepositoryProvider = Provider<CalibrationRepository>(
  (_) => SharedPreferencesCalibrationRepository(),
);

final nativeCalibrationProvider =
    StateNotifierProvider<NativeCalibrationController, NativeCalibrationState>((
      ref,
    ) {
      final controller = NativeCalibrationController(
        ref.watch(calibrationRepositoryProvider),
      );
      unawaited(controller.load());
      return controller;
    });

class NativeCalibrationController
    extends StateNotifier<NativeCalibrationState> {
  NativeCalibrationController(
    this._repository, {
    ScreenCaptureSource? screenCapture,
  }) : _screenCapture = screenCapture ?? DesktopScreenCapture(),
       super(const NativeCalibrationState()) {
    _contextTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(refreshContext()),
    );
  }

  final CalibrationRepository _repository;
  final ScreenCaptureSource _screenCapture;
  Timer? _contextTimer;
  bool _refreshing = false;
  bool _disposed = false;
  int _revision = 0;
  int _loadRevision = 0;
  // Keep an in-flight save ahead of any later clear on disk.
  Future<void> _writes = Future<void>.value();

  bool _isCurrent(int revision) => !_disposed && revision == _revision;

  Future<void> _persist(
    int revision,
    Future<void> Function() action, {
    bool userRequested = false,
  }) {
    final writing = _writes.then((_) async {
      if (revision == _revision && (userRequested || !_disposed)) {
        await action();
      }
    });
    _writes = writing.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return writing;
  }

  Future<void> refreshContext() async {
    if (_disposed ||
        _refreshing ||
        state.loading ||
        state.saving ||
        state.calibration == null) {
      return;
    }
    _refreshing = true;
    final revision = _revision;
    final loadRevision = _loadRevision;
    try {
      final calibration = await _repository.load();
      if (_isCurrent(revision) &&
          loadRevision == _loadRevision &&
          calibration != null &&
          calibration.recalibrationSuggested !=
              state.calibration?.recalibrationSuggested) {
        state = state.copyWith(calibration: calibration);
      }
    } catch (error) {
      if (_isCurrent(revision) && loadRevision == _loadRevision) {
        state = state.copyWith(
          error: 'No se pudo comprobar la configuración: $error',
        );
      }
    } finally {
      _refreshing = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _contextTimer?.cancel();
    _screenCapture.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (_disposed) return;
    final revision = _revision;
    final loadRevision = ++_loadRevision;
    bool current() => _isCurrent(revision) && loadRevision == _loadRevision;
    state = state.copyWith(loading: true, saving: false, clearError: true);
    try {
      await _writes;
      if (!current()) return;
      var calibration = await _repository.load();
      if (!current()) return;
      if (calibration?.bounds != null) {
        try {
          final described = await _screenCapture.describeBounds(
            calibration!.bounds!,
          );
          if (!current()) return;
          if (!mapEquals(described, calibration.bounds)) {
            calibration = CalibrationState(
              calibrated: calibration.calibrated,
              recalibrationSuggested: calibration.recalibrationSuggested,
              bounds: described,
              iconSize: calibration.iconSize,
              confidence: calibration.confidence,
              defaultBounds: calibration.defaultBounds,
              defaultIconSize: calibration.defaultIconSize,
              defaultTrustworthy: calibration.defaultTrustworthy,
              provenance: calibration.provenance,
            );
            final normalized = calibration;
            await _persist(revision, () async {
              if (current()) await _repository.save(normalized);
            });
          }
        } catch (_) {
          // A disconnected monitor may return later. Keep the stable saved
          // identity and let the continuous capture retry without data loss.
        }
      }
      if (!current()) return;
      state = state.copyWith(
        loading: false,
        calibration: calibration,
        clearCalibration: calibration == null,
        clearError: true,
      );
    } catch (error) {
      if (!current()) return;
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  Future<void> saveDetected(NativeCalibrationResult result) => save(
    result.bounds,
    iconSize: result.iconSize,
    confidence: result.confidence,
  );

  Future<void> save(
    Map<String, dynamic> bounds, {
    int? iconSize,
    double confidence = 1,
  }) async {
    if (_disposed) return;
    final validated = _validateBounds(bounds);
    final revision = ++_revision;
    state = state.copyWith(saving: true, loading: false, clearError: true);
    Map<String, dynamic> normalized = validated;
    if ((validated['display_id']?.toString() ?? '').isEmpty) {
      try {
        normalized = await _screenCapture.describeBounds(validated);
      } catch (_) {
        // The calibration remains usable by absolute desktop coordinates. The
        // next native capture resolves its display and can enrich a later save.
      }
    }
    if (revision != _revision) return;
    final resolvedIconSize =
        iconSize ??
        ((normalized['width'] as int) * 0.088).round().clamp(16, 64);
    final calibration = CalibrationState(
      calibrated: true,
      recalibrationSuggested: false,
      bounds: normalized,
      iconSize: resolvedIconSize.toDouble(),
      confidence: confidence.clamp(0, 1),
      defaultBounds: null,
      defaultIconSize: null,
      defaultTrustworthy: false,
    );
    try {
      await _persist(
        revision,
        () => _repository.save(calibration),
        userRequested: true,
      );
      if (!_isCurrent(revision)) return;
      final restored = await _repository.load();
      if (!_isCurrent(revision)) return;
      state = state.copyWith(
        saving: false,
        calibration: restored ?? calibration,
        clearError: true,
      );
    } catch (error) {
      if (_isCurrent(revision)) {
        state = state.copyWith(saving: false, error: error.toString());
      }
      rethrow;
    }
  }

  Future<void> clear() async {
    if (_disposed) return;
    final revision = ++_revision;
    state = state.copyWith(saving: true, loading: false, clearError: true);
    try {
      await _persist(revision, _repository.clear, userRequested: true);
      if (!_isCurrent(revision)) return;
      state = state.copyWith(
        saving: false,
        clearCalibration: true,
        clearError: true,
      );
    } catch (error) {
      if (_isCurrent(revision)) {
        state = state.copyWith(saving: false, error: error.toString());
      }
      rethrow;
    }
  }

  Map<String, dynamic> _validateBounds(Map<String, dynamic> bounds) {
    int read(String key) {
      final value = bounds[key];
      if (value is! num) {
        throw ArgumentError.value(value, key, 'Must be numeric.');
      }
      return value.round();
    }

    final left = read('left');
    final top = read('top');
    final width = read('width');
    final height = read('height');
    if (width < 16 || height < 16) {
      throw ArgumentError.value(bounds, 'bounds', 'Out-of-range bounds.');
    }
    final ratio = width / height;
    if (ratio < 0.75 || ratio > 1.33) {
      throw ArgumentError.value(
        bounds,
        'bounds',
        'The minimap must be approximately square.',
      );
    }
    return {
      'left': left,
      'top': top,
      'width': width,
      'height': height,
      for (final key in const [
        'display_id',
        'display_name',
        'display_left',
        'display_top',
        'display_width',
        'display_height',
        'display_dpi_scale',
        'display_rotation',
        'local_left',
        'local_top',
      ])
        if (bounds[key] != null) key: bounds[key],
    };
  }
}
