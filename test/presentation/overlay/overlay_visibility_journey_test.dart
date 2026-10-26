import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/app/godsense_app.dart';
import 'package:godsense/application/coach_controller.dart';
import 'package:godsense/application/companion_controller.dart';
import 'package:godsense/application/dependencies.dart';
import 'package:godsense/application/native_calibration_controller.dart';
import 'package:godsense/application/native_league_controller.dart';
import 'package:godsense/application/native_speech_controller.dart';
import 'package:godsense/application/native_voice_coach_controller.dart';
import 'package:godsense/application/overlay_layout_controller.dart';
import 'package:godsense/domain/calibration_repository.dart';
import 'package:godsense/domain/companion_gateway.dart';
import 'package:godsense/domain/companion_models.dart';
import 'package:godsense/infrastructure/speech/shared_preferences_speech_settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _game = StateProvider<GameSnapshot?>((_) => null);

void main() {
  testWidgets(
    'overlay follows game visibility, alert freshness and hidden panel settings',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final companion = _Companion();
      final speech = NativeSpeechController(
        repository: SharedPreferencesSpeechSettingsRepository(),
      );
      final container = ProviderContainer(
        overrides: [
          companionControllerProvider.overrideWith((_) => companion),
          nativeLeagueProvider.overrideWith((_) => NativeLeagueController()),
          nativeSpeechProvider.overrideWith((_) => speech),
          nativeCalibrationProvider.overrideWith(
            (_) => NativeCalibrationController(_Calibration()),
          ),
          nativeVoiceCoachProvider.overrideWith(
            (_) => NativeVoiceCoachController(
              questions: const Stream.empty(),
              answer: (_) => throw StateError('No voice request expected'),
              speak: (_) {},
            ),
          ),
          coachControllerProvider.overrideWith(
            (_) => CoachController(
              importRunes: (_) async {},
              importItems: () async {},
            ),
          ),
          effectiveGameProvider.overrideWith((ref) => ref.watch(_game)),
        ],
      );
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      try {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: GodSenseOverlay()),
          ),
        );
        await tester.pump();
        expect(find.byType(ThreatRadarHUD), findsNothing);
        container.read(_game.notifier).state = GameSnapshot.fromJson({
          'game_time': 600,
          'team_gold_diff': 1500,
          'enemies': [
            {
              'champion_name': 'Lee Sin',
              'role': 'JUNGLE',
              'map_location': 'Río',
            },
          ],
        });
        await tester.pump();
        expect(find.byType(ThreatRadarHUD), findsOneWidget);
        expect(find.text('Lee Sin'), findsOneWidget);
        expect(find.byType(MiniGoldBadgeHUD), findsOneWidget);
        expect(find.byType(VoiceCapsuleHUD), findsNothing);

        final now = DateTime.now();
        CompanionAlert alert(
          CompanionAlertKind kind,
          int age,
          Map<String, dynamic> raw,
        ) => CompanionAlert(
          kind: kind,
          title: 'Alerta sintética',
          message: 'Río inferior',
          receivedAt: now.subtract(Duration(seconds: age)),
          raw: raw,
        );
        companion.publish(
          CompanionState(
            alerts: [
              alert(CompanionAlertKind.gank, 6, {'threat_level': 'DANGER'}),
              alert(CompanionAlertKind.voice, 9, {
                'state': 'answer',
                'text': 'Respuesta caducada',
              }),
            ],
          ),
        );
        await tester.pump();
        expect(find.byType(GankAlertHUD), findsNothing);
        expect(find.byType(VoiceCapsuleHUD), findsNothing);

        companion.publish(
          CompanionState(
            alerts: [
              alert(CompanionAlertKind.gank, 0, {'threat_level': 'DANGER'}),
              alert(CompanionAlertKind.voice, 0, {
                'state': 'answer',
                'text': 'Respuesta actual',
              }),
              alert(CompanionAlertKind.junglerSighting, 0, {}),
            ],
          ),
        );
        await tester.pump();
        expect(find.byType(GankAlertHUD), findsOneWidget);
        expect(find.text('Respuesta actual'), findsOneWidget);
        expect(tester.takeException(), isNull);

        companion.publish(
          CompanionState(
            settings: CompanionSettings.fromJson({
              'settings': {'overlay_hidden_panels': overlayPanelIds},
            }),
          ),
        );
        await tester.pump();
        expect(find.byType(ThreatRadarHUD), findsNothing);
        expect(find.byType(MiniGoldBadgeHUD), findsNothing);
        expect(find.byType(MatchupInfoHUD), findsNothing);
        expect(find.byType(LinearBuildsHUD), findsNothing);
        expect(find.byType(PriorityDirectivesHUD), findsNothing);
        expect(find.byType(EsportsCompositionHUD), findsNothing);

        companion.publish(
          CompanionState(
            alerts: [
              alert(CompanionAlertKind.overlayVisibility, 0, {
                'visible': false,
              }),
            ],
          ),
        );
        await tester.pump();
        expect(find.byType(ThreatRadarHUD), findsNothing);
        companion.publish(const CompanionState());
        await tester.pump();
        expect(find.byType(ThreatRadarHUD), findsOneWidget);
        container.read(_game.notifier).state = GameSnapshot.fromJson({
          '_game_ended': true,
        });
        await tester.pump();
        expect(find.byType(ThreatRadarHUD), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        speech.disposeServices();
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      }
    },
  );
}

class _Companion extends CompanionController {
  _Companion() : super(_Gateway());
  void publish(CompanionState value) => state = value;
}

class _Gateway implements CompanionGateway {
  @override
  Future<void> closeAlerts() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected transport access: ${invocation.memberName}');
}

class _Calibration implements CalibrationRepository {
  @override
  Future<CalibrationState?> load() async => null;
  @override
  Future<void> save(CalibrationState calibration) async {}
  @override
  Future<void> clear() async {}
}
