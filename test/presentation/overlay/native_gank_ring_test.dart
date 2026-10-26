import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/app/godsense_app.dart';
import 'package:godsense/application/coach_controller.dart';
import 'package:godsense/application/companion_controller.dart';
import 'package:godsense/application/dependencies.dart';
import 'package:godsense/application/native_calibration_controller.dart';
import 'package:godsense/application/native_league_controller.dart';
import 'package:godsense/application/native_speech_controller.dart';
import 'package:godsense/application/native_vision_controller.dart';
import 'package:godsense/domain/calibration_repository.dart';
import 'package:godsense/domain/companion_gateway.dart';
import 'package:godsense/domain/companion_models.dart';
import 'package:godsense/infrastructure/speech/shared_preferences_speech_settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final ratio in [1.0, 2.0]) {
    for (final (kind, age, danger) in [
      (NativeTrackerEventKind.gank, 0, true),
      (NativeTrackerEventKind.gank, 6, false),
      (NativeTrackerEventKind.junglerSighting, 0, false),
    ]) {
      testWidgets(
        'native $kind age ${age}s paints danger=$danger at device scale $ratio',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          tester.view.physicalSize = Size(800 * ratio, 600 * ratio);
          tester.view.devicePixelRatio = ratio;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final key = GlobalKey();
          final container = ProviderContainer(
            overrides: [
              companionControllerProvider.overrideWith((_) => _Companion()),
              nativeLeagueProvider.overrideWith(
                (_) => NativeLeagueController(),
              ),
              nativeVisionProvider.overrideWith((_) => _Vision(kind, age)),
              nativeSpeechProvider.overrideWith(
                (_) => NativeSpeechController(
                  repository: SharedPreferencesSpeechSettingsRepository(),
                ),
              ),
              nativeCalibrationProvider.overrideWith((_) => _Calibrated(ratio)),
              coachControllerProvider.overrideWith(
                (_) => CoachController(
                  importRunes: (_) async {},
                  importItems: () async {},
                ),
              ),
              effectiveGameProvider.overrideWithValue(
                GameSnapshot.fromJson({'game_time': 600}),
              ),
            ],
          );
          try {
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  home: RepaintBoundary(
                    key: key,
                    child: const GodSenseOverlay(),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              find.byType(GankAlertHUD),
              danger ? findsOneWidget : findsNothing,
            );
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = (await tester.runAsync(
              () => boundary.toImage(pixelRatio: 1),
            ))!;
            try {
              final pixels = (await tester.runAsync(
                () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
              ))!;
              // The physical calibration is converted to logical coordinates.
              // Sample the middle of its left border, away from rounded corners.
              final offset = (350 * image.width + 302) * 4;
              expect(
                [
                  for (var channel = 0; channel < 4; channel++)
                    pixels.getUint8(offset + channel),
                ],
                danger ? [244, 67, 54, 255] : [0, 0, 0, 0],
                reason: 'Only a fresh native gank highlights the calibrated minimap area.',
              );
            } finally {
              image.dispose();
            }
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox());
            container.dispose();
            await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          }
        },
      );
    }
  }
}

class _Vision extends NativeVisionController {
  _Vision(NativeTrackerEventKind kind, int age) {
    state = NativeVisionState(
      events: [
        NativeTrackerEvent(
          kind: kind,
          champion: 'Vi',
          location: 'Río',
          region: 'Bot',
          role: 'JUNGLE',
          timestamp: DateTime.now().subtract(Duration(seconds: age)),
        ),
      ],
    );
  }
}

class _Companion extends CompanionController {
  _Companion() : super(_Gateway()) {
    state = CompanionState(
      settings: CompanionSettings.fromJson({
        'settings': {
          'overlay_hidden_panels': [
            'jungler',
            'voice_ask',
            'matchup_info',
            'builds',
            'directives',
            'team_comp',
            'gold_chart',
          ],
        },
      }),
    );
  }
}

class _Gateway implements CompanionGateway {
  @override
  Future<void> closeAlerts() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Calibrated extends NativeCalibrationController {
  _Calibrated(double ratio) : super(_Repository()) {
    state = NativeCalibrationState(
      loading: false,
      calibration: CalibrationState(
        calibrated: true,
        recalibrationSuggested: false,
        bounds: {
          'left': 300 * ratio,
          'top': 300 * ratio,
          'width': 100 * ratio,
          'height': 100 * ratio,
        },
      ),
    );
  }
}

class _Repository implements CalibrationRepository {
  @override
  Future<CalibrationState?> load() async => null;
  @override
  Future<void> save(CalibrationState calibration) async {}
  @override
  Future<void> clear() async {}
}
