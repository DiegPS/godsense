import 'companion_models.dart';

abstract interface class CalibrationRepository {
  Future<CalibrationState?> load();

  Future<void> save(CalibrationState calibration);

  Future<void> clear();
}
