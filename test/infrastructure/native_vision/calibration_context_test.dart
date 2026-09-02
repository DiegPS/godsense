import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/domain/companion_models.dart';
import 'package:godsense/infrastructure/league/league_installation.dart';
import 'package:godsense/infrastructure/native_vision/shared_preferences_calibration_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'discovers config from active custom installation and explicit lockfile',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'godsense-config-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final config = File('${directory.path}/Config/game.cfg');
      await config.parent.create();
      await config.writeAsString(
        '[General]\nWidth=3440\nHeight=1440\n[HUD]\nMinimapScale=1.7',
      );
      final active = LeagueConfigSource(
        candidates: [],
        activeDirectory: () => directory.path,
      ).read();
      final override = LeagueConfigSource(
        override: '${directory.path}/lockfile',
        candidates: [],
        activeDirectory: () => null,
      ).read();
      expect(active['width'], 3440);
      expect(override, active);
    },
  );
  test('configuration parser respects sections and window mode', () {
    expect(
      LeagueConfigSource.parse(
        '[General]\nWidth=1920\nHeight=1080\nWindowMode=1\n[HUD]\nMinimapScale=1.3\n[Other]\nWidth=99',
      ),
      {'width': 1920, 'height': 1080, 'windowmode': 1, 'minimapscale': 1.3},
    );
  });
  test('calibration persists context and detects subsequent changes', () async {
    SharedPreferences.setMockInitialValues({});
    var context = <String, num>{
      'width': 1920,
      'height': 1080,
      'minimapscale': 1.3,
    };
    final repository = SharedPreferencesCalibrationRepository(
      contextReader: () async => context,
    );
    await repository.save(
      const CalibrationState(
        calibrated: true,
        recalibrationSuggested: false,
        bounds: {'left': 1500, 'top': 600, 'width': 300, 'height': 300},
        iconSize: 26,
      ),
    );
    expect((await repository.load())?.recalibrationSuggested, isFalse);
    context = {...context, 'minimapscale': 1.8};
    expect((await repository.load())?.recalibrationSuggested, isTrue);
    context = {};
    expect((await repository.load())?.recalibrationSuggested, isFalse);
  });
  test('legacy calibration without provenance is not discarded', () {
    expect(calibrationContextChanged(null, {'width': 1920}), isFalse);
  });
}
