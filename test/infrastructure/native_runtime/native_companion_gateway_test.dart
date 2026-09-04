import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/infrastructure/native_runtime/native_companion_gateway.dart';
import 'package:godsense/application/native_tactical_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'reports a healthy in-process runtime without external services',
    () async {
      final gateway = NativeCompanionGateway();

      final health = await gateway.health();
      expect(health['runtime'], 'in_process');
      expect(health['status'], 'ok');
      await gateway.closeAlerts();
    },
  );

  test('persists only supported UI settings locally', () async {
    final first = NativeCompanionGateway();
    await first.updateSettings({
      'language': 'es',
      'cadence': 'quiet',
      'overlay_hidden_panels': ['builds', 'gank'],
      'secret': 'must-not-persist',
    });
    await first.closeAlerts();

    final second = NativeCompanionGateway();
    final envelope = await second.settings();
    final settings = envelope['settings'] as Map;

    expect(settings['language'], 'es');
    expect(settings['cadence'], 'quiet');
    expect(settings['overlay_hidden_panels'], ['builds', 'gank']);
    expect(settings.containsKey('secret'), isFalse);
    await second.closeAlerts();
  });

  test('delivers in-memory overlay events without WebSocket IPC', () async {
    final gateway = NativeCompanionGateway();
    final received = gateway.alertEvents().first;

    gateway.publishAlert({'type': 'overlay_edit', 'edit': true});

    expect(await received, {'type': 'overlay_edit', 'edit': true});
    await gateway.closeAlerts();
  });

  test('projects native tactical analysis and directives in process', () async {
    final engine = NativeTacticalEngine(now: () => DateTime.utc(2026));
    Map<String, dynamic>? game;
    final gateway = NativeCompanionGateway(
      lobbySnapshot: () => {
        'snapshot': {
          'my_team': [
            {'champion_name': 'Ahri', 'is_local': true, 'position': 'MIDDLE'},
          ],
          'their_team': [
            {'champion_name': 'Vex', 'position': 'MIDDLE'},
          ],
        },
      },
      gameSnapshot: () => game,
      tacticalAnalysis: engine.analyze,
      tacticalDirectives: engine.directives,
    );

    await gateway.generateLobbyBrief('Vex');

    expect((await gateway.coaching())['matchup'], isNotNull);
    const active = {
      'champion_name': 'Ahri',
      'summoner_name': 'Local',
      'tag_line': 'LAN',
      'role': 'MIDDLE',
      'is_dead': false,
    };
    game = {
      'game_time': 60.0,
      'team_gold_diff': -1200,
      'active_player': active,
      'allies': [active],
      'enemies': [
        {'champion_name': 'Vex', 'role': 'MIDDLE'},
      ],
      'derived': {'objectives': <String, Object?>{}},
    };
    expect((await gateway.coaching())['matchup'], isNotNull);
    expect((await gateway.directives()).single['id'], 'recover_resources');
    await gateway.closeAlerts();
  });
}
