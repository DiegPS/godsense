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
    try {
      final calibration = await _repository.load();
      if (!_disposed &&
          revision == _revision &&
          calibration != null &&
          calibration.recalibrationSuggested !=
              state.calibration?.recalibrationSuggested) {
        state = state.copyWith(calibration: calibration);
      }
    } catch (error) {
      if (!_disposed) {
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
    state = state.copyWith(loading: true, clearError: true);
    try {
      var calibration = await _repository.load();
      if (calibration?.bounds != null) {
        try {
          final described = await _screenCapture.describeBounds(
            calibration!.bounds!,
          );
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
            await _repository.save(calibration);
          }
        } catch (_) {
          // A disconnected monitor may return later. Keep the stable saved
          // identity and let the continuous capture retry without data loss.
        }
      }
      if (_disposed) return;
      state = state.copyWith(
        loading: false,
        calibration: calibration,
        clearCalibration: calibration == null,
        clearError: true,
      );
    } catch (error) {
      if (_disposed) return;
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
    _revision++;
    final validated = _validateBounds(bounds);
    Map<String, dynamic> normalized = validated;
    if ((validated['display_id']?.toString() ?? '').isEmpty) {
      try {
        normalized = await _screenCapture.describeBounds(validated);
      } catch (_) {
        // The calibration remains usable by absolute desktop coordinates. The
        // next native capture resolves its display and can enrich a later save.
      }
    }
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
    state = state.copyWith(saving: true, clearError: true);
    try {
      await _repository.save(calibration);
      final restored = await _repository.load();
      if (_disposed) return;
      state = state.copyWith(
        saving: false,
        calibration: restored ?? calibration,
        clearError: true,
      );
    } catch (error) {
      if (_disposed) return;
      state = state.copyWith(saving: false, error: error.toString());
      rethrow;
    }
  }

  Future<void> clear() async {
    _revision++;
    state = state.copyWith(saving: true, clearError: true);
    try {
      await _repository.clear();
      if (_disposed) return;
      state = state.copyWith(
        saving: false,
        clearCalibration: true,
        clearError: true,
      );
    } catch (error) {
      if (_disposed) return;
      state = state.copyWith(saving: false, error: error.toString());
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
