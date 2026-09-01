import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/domain/companion_models.dart';
import 'package:godsense/infrastructure/native_vision/shared_preferences_calibration_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('round-trips and clears native calibration', () async {
    final repository = SharedPreferencesCalibrationRepository();
    const calibration = CalibrationState(
      calibrated: true,
      recalibrationSuggested: false,
      bounds: {'left': 1500, 'top': 650, 'width': 320, 'height': 318},
      iconSize: 28,
      confidence: 0.92,
      defaultBounds: null,
      defaultIconSize: null,
    );

    await repository.save(calibration);
    final restored = await repository.load();

    expect(restored?.bounds, calibration.bounds);
    expect(restored?.trackingIconSize, 28);
    expect(restored?.confidence, 0.92);

    await repository.clear();
    expect(await repository.load(), isNull);
  });

  test('ignores corrupt persisted data', () async {
    SharedPreferences.setMockInitialValues({
      'native_minimap_calibration_v1': '{not-json',
    });
    final repository = SharedPreferencesCalibrationRepository();

    expect(await repository.load(), isNull);
  });
}
