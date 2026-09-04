import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/companion_models.dart';
import 'native_calibration_controller.dart';
import 'native_league_controller.dart';
import 'native_vision_controller.dart';

final visionSessionCoordinatorProvider = Provider<VisionSessionCoordinator>((
  ref,
) {
  final coordinator = VisionSessionCoordinator(ref);
  ref.onDispose(coordinator.dispose);
  coordinator.start();
  return coordinator;
});

/// Owns vision lifecycle independently from the mounted page and game phase.
class VisionSessionCoordinator {
  VisionSessionCoordinator(this._ref);

  final Ref _ref;
  bool _started = false;
  bool _scheduled = false;
  bool _disposed = false;

  void dispose() => _disposed = true;

  void start() {
    if (_started) return;
    _started = true;
    _ref.listen<NativeLeagueState>(
      nativeLeagueProvider,
      (_, _) => _scheduleSynchronization(),
      fireImmediately: true,
    );
    _ref.listen<NativeCalibrationState>(
      nativeCalibrationProvider,
      (_, _) => _scheduleSynchronization(),
      fireImmediately: true,
    );
  }

  void _scheduleSynchronization() {
    if (_scheduled || _disposed) return;
    _scheduled = true;
    unawaited(
      Future<void>.microtask(() {
        _scheduled = false;
        if (_disposed) return;
        _synchronize();
      }),
    );
  }

  void _synchronize() {
    final league = _ref.read(nativeLeagueProvider);
    final calibrationState = _ref.read(nativeCalibrationProvider);
    final calibration = calibrationState.calibration;
    final game = league.liveGame == null
        ? null
        : GameSnapshot.fromJson(league.liveGame!);
    final activePlayer = game?.raw['active_player'];
    final vision = _ref.read(nativeVisionProvider.notifier);

    unawaited(
      vision.configureTargets(
        game?.enemies ?? const [],
        localRole: activePlayer is Map
            ? activePlayer['role']?.toString()
            : null,
        iconSize: calibration?.trackingIconSize ?? 28,
      ),
    );
    if (calibrationState.loading) return;
    vision.configure(
      enabled: true,
      calibrationStale: calibration?.recalibrationSuggested ?? false,
      bounds: calibration?.trackingBounds,
      iconSize: calibration?.trackingIconSize ?? 28,
    );
  }
}
