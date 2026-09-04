import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/app/godsense_app.dart';
import 'package:godsense/application/native_vision_controller.dart';
import 'package:godsense/domain/companion_models.dart';

void main() {
  Widget wrap(Widget child) {
    return ProviderScope(
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  group('HUD 8 Elements Tests', () {
    testWidgets('1. Gank Alert HUD renders danger and warning states', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          GankAlertHUD(
            nativeGank: NativeTrackerEvent(
              kind: NativeTrackerEventKind.gank,
              champion: 'Jarvan IV',
              location: 'Río Bot',
              region: 'River',
              role: 'JUNGLE',
              timestamp: DateTime.now(),
            ),
          ),
        ),
      );
      expect(find.textContaining('PELIGRO: Jarvan IV'), findsOneWidget);
      expect(find.text('GANK'), findsOneWidget);
      expect(find.text('Río Bot · JUNGLE'), findsOneWidget);
    });

    testWidgets('2. Threat Radar HUD renders enemy jungle & threat statuses', (
      tester,
    ) async {
      final now = DateTime.now();
      await tester.pumpWidget(
        wrap(
          ThreatRadarHUD(
            jungler: const {'champion_name': 'Lee Sin', 'role': 'JUNGLE'},
            threats: const [
              {
                'champion_name': 'Darius',
                'role': 'TOP',
                'is_dead': false,
                'is_mia': false,
              },
              {
                'champion_name': 'Lee Sin',
                'role': 'JUNGLE',
                'is_dead': false,
                'is_mia': false,
              },
              {
                'champion_name': 'Ahri',
                'role': 'MID',
                'is_dead': true,
                'respawn_timer': 14.0,
              },
              {
                'champion_name': 'Jinx',
                'role': 'BOT',
                'is_dead': false,
                'is_mia': true,
                'mia_duration': 22,
              },
              {
                'champion_name': 'Thresh',
                'role': 'SUPPORT',
                'is_dead': false,
                'is_mia': false,
              },
            ],
            nativeSighting: null,
            sighting: null,
            nativeVision: const NativeVisionState(),
            now: now,
          ),
        ),
      );
      expect(find.text('Lee Sin'), findsOneWidget);
      expect(find.text('· JUG'), findsOneWidget);
      expect(find.text('14S'), findsOneWidget);
      expect(find.text('22S'), findsOneWidget);
    });

    testWidgets('3. Voice Capsule HUD displays listening and advice states', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const VoiceCapsuleHUD(
            isListening: true,
            transcript: '',
            isProcessing: false,
            adviceText: null,
            voiceAlert: null,
          ),
        ),
      );
      expect(
        find.text('Escuchando… suelta la tecla para enviar'),
        findsOneWidget,
      );

      await tester.pumpWidget(
        wrap(
          const VoiceCapsuleHUD(
            isListening: false,
            transcript: '',
            isProcessing: false,
            adviceText: 'Congela la oleada antes de Dragón',
            voiceAlert: null,
          ),
        ),
      );
      expect(find.text('Congela la oleada antes de Dragón'), findsOneWidget);
    });

    testWidgets('4. Matchup Info HUD renders win condition & spikes', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const MatchupInfoHUD(
            matchupData: {
              'win_condition': 'Farmea hasta tu pico de poder de nivel 6.',
              'trading_patterns': [
                'Castiga después de que use su habilidad principal.',
              ],
              'power_spikes': ['Cuidado con su combo a nivel 3.'],
            },
          ),
        ),
      );
      expect(find.text('ENFRENTAMIENTO'), findsOneWidget);
      expect(
        find.text('Farmea hasta tu pico de poder de nivel 6.'),
        findsOneWidget,
      );
      expect(find.text('Cuidado con su combo a nivel 3.'), findsOneWidget);
      expect(find.textContaining('Castiga después de que use'), findsOneWidget);
    });

    testWidgets('5. Linear Builds HUD renders items linearly with prices', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const LinearBuildsHUD(
            coachGroups: [],
            rawBuilds: {
              'items': [
                {
                  'category': 'Core',
                  'items': [
                    {'item_id': 3031, 'name': 'Infinity Edge', 'count': 1},
                    {'item_id': 3094, 'name': 'Rapid Firecannon', 'count': 1},
                  ],
                },
              ],
            },
          ),
        ),
      );
      expect(find.text('BUILD RECOMENDADA'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('6. Priority Directives HUD renders P1, P2, P3 cards', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const PriorityDirectivesHUD(
            directives: [
              CoachDirective(
                id: '1',
                title: 'Controlar Río para el Dragón',
                hints: [],
                rationale: '',
                ttsText: '',
              ),
              CoachDirective(
                id: '2',
                title: 'Pushear oleada y comprar',
                hints: [],
                rationale: '',
                ttsText: '',
              ),
            ],
          ),
        ),
      );
      expect(find.text('DIRECTIVAS'), findsOneWidget);
      expect(find.text('P1'), findsOneWidget);
      expect(find.text('Controlar Río para el Dragón'), findsOneWidget);
      expect(find.text('P2'), findsOneWidget);
      expect(find.text('Pushear oleada y comprar'), findsOneWidget);
    });

    testWidgets('7. Esports Composition HUD renders 5v5 lineup', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          EsportsCompositionHUD(
            game: GameSnapshot.fromJson({
              'game_time': 600,
              'phase': 'mid_game',
              'allies': [
                {'champion_name': 'Aatrox', 'role': 'TOP'},
                {'champion_name': 'Sejuani', 'role': 'JUNGLE'},
              ],
              'enemies': [
                {'champion_name': 'Fiora', 'role': 'TOP'},
                {'champion_name': 'Kayn', 'role': 'JUNGLE'},
              ],
            }),
          ),
        ),
      );
      expect(find.text('COMPOSICIÓN'), findsOneWidget);
      expect(find.text('VS'), findsOneWidget);
    });

    testWidgets('8. Mini Gold Badge HUD displays formatted difference', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const MiniGoldBadgeHUD(goldDifference: 2500)),
      );
      expect(find.text('DIF. ORO'), findsOneWidget);
      expect(find.text('+2500'), findsOneWidget);
    });
  });
}
