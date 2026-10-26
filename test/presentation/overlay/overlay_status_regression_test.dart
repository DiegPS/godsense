import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/app/godsense_app.dart';
import 'package:godsense/application/native_vision_controller.dart';
import 'package:godsense/domain/companion_models.dart';

void main() {
  testWidgets(
    'gold badge keeps the complete value visible in narrow panels and large text',
    (tester) async {
      for (final width in [130.0, 150.0]) {
        for (final scale in [1.0, 2.0]) {
          for (final value in [-999999, 0, 999999]) {
            await tester.pumpWidget(
              MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: width,
                      child: MiniGoldBadgeHUD(goldDifference: value),
                    ),
                  ),
                ),
              ),
            );
            expect(find.text(value > 0 ? '+$value' : '$value'), findsOneWidget);
            expect(
              tester.takeException(),
              isNull,
              reason: 'width=$width, textScale=$scale, gold=$value',
            );
          }
        }
      }
    },
  );
  final now = DateTime.utc(2026, 10, 25, 12);
  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: SizedBox(width: 400, child: child)),
  );

  final locationCases = <(Map<String, dynamic>, String)>[
    ({'is_dead': true, 'respawn_timer': 65}, 'Muerto · reaparece en 1:05'),
    ({'is_dead': true}, 'Muerto'),
    ({'map_location': 'Río inferior'}, 'Visto en Río inferior'),
    (
      {'is_mia': true, 'mia_duration': 72, 'last_known_location': 'Top'},
      'MIA 1:12 · última vez en Top',
    ),
    ({'is_mia': true, 'mia_duration': 7}, 'MIA 0:07'),
    (
      {'mia_duration': 35, 'last_known_location': 'Bot'},
      'Visto hace 0:35 en Bot',
    ),
    ({}, 'Aún no detectado'),
  ];
  for (final (data, expected) in locationCases) {
    testWidgets('radar explains location status: $expected', (tester) async {
      await tester.pumpWidget(
        wrap(
          ThreatRadarHUD(
            jungler: {'champion_name': 'Lee Sin', ...data},
            threats: const [],
            nativeSighting: null,
            sighting: null,
            nativeVision: const NativeVisionState(),
            now: now,
          ),
        ),
      );
      expect(find.text(expected), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final seconds in [1, 12]) {
    testWidgets(
      'radar distinguishes current and stale native vision at ${seconds}s',
      (tester) async {
        final seen = NativeIdentifiedChampion(
          name: 'Lee Sin',
          region: 'Río',
          x: .4,
          y: .6,
          confidence: .92,
          lastSeen: now.subtract(Duration(seconds: seconds)),
        );
        await tester.pumpWidget(
          wrap(
            ThreatRadarHUD(
              jungler: const {'champion_name': 'Lee Sin'},
              threats: const [],
              nativeSighting: NativeTrackerEvent(
                kind: NativeTrackerEventKind.junglerSighting,
                champion: 'Lee Sin',
                location: 'Río',
                region: 'Río',
                timestamp: seen.lastSeen,
              ),
              sighting: null,
              nativeVision: NativeVisionState(lastKnown: {'LeeSin': seen}),
              now: now,
            ),
          ),
        );
        expect(
          find.text(
            seconds == 1
                ? 'Visto en Río · 92% de confianza'
                : 'Visto hace 0:12 en Río',
          ),
          findsOneWidget,
        );
        expect(find.text(seconds == 1 ? '0:01' : '0:12'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final (state, text) in <(String, String)>[
    ('recording', 'Escuchando…'),
    ('thinking', 'Pensando…'),
    ('answering', 'Consejo sintético'),
    ('answer', 'Consejo sintético'),
    ('error', 'No pude procesar la pregunta. Inténtalo de nuevo.'),
    ('unknown', 'Mensaje de respaldo'),
  ]) {
    testWidgets('voice capsule explains companion state $state', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          VoiceCapsuleHUD(
            isListening: false,
            transcript: '',
            isProcessing: false,
            adviceText: null,
            voiceAlert: CompanionAlert(
              kind: CompanionAlertKind.voice,
              title: 'Voz',
              message: 'Mensaje de respaldo',
              receivedAt: now,
              raw: {'state': state, 'text': 'Consejo sintético'},
            ),
          ),
        ),
      );
      expect(find.text(text), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
