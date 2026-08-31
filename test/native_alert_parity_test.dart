import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/native_vision_controller.dart';

void main() {
  final appData = Platform.environment['APPDATA'];
  final corpus = appData == null
      ? null
      : File('$appData\\GodSense\\alert-corpus.json');

  test('native gank and sighting state matches Python exactly', () async {
    final raw = jsonDecode(await corpus!.readAsString());
    final root = Map<String, dynamic>.from(raw as Map);
    final controller = NativeVisionController();
    addTearDown(controller.dispose);
    controller.configureAlertContext(
      localRole: root['coached_role'].toString(),
      enemyRoles: Map<String, String>.from(root['enemy_roles'] as Map),
    );
    final width = (root['width'] as num).toInt();
    final height = (root['height'] as num).toInt();

    for (final rawFrame in root['frames'] as List) {
      final frame = Map<String, dynamic>.from(rawFrame as Map);
      final timestampSeconds = (frame['timestamp'] as num).toDouble();
      final timestamp = DateTime.fromMillisecondsSinceEpoch(
        (timestampSeconds * 1000).round(),
      );
      final positions = <String, NativeIdentifiedChampion>{};
      final rawPositions = Map<String, dynamic>.from(frame['positions'] as Map);
      for (final entry in rawPositions.entries) {
        final value = Map<String, dynamic>.from(entry.value as Map);
        positions[entry.key] = NativeIdentifiedChampion(
          name: entry.key,
          region: '',
          x: (value['x'] as num).toDouble(),
          y: (value['y'] as num).toDouble(),
          confidence: (value['confidence'] as num).toDouble(),
          lastSeen: DateTime.fromMillisecondsSinceEpoch(
            ((value['timestamp'] as num).toDouble() * 1000).round(),
          ),
        );
      }
      final actual = controller.evaluateAlerts(
        positions,
        timestamp,
        width,
        height,
      );
      final actualGanks = actual
          .where((event) => event.kind == NativeTrackerEventKind.gank)
          .map(
            (event) => {
              'champion_name': event.champion,
              'role': event.role,
              'zone': event.location,
              'threat_level': 'DANGER',
              'timestamp': timestampSeconds,
            },
          )
          .toList();
      final actualSightings = actual
          .where(
            (event) => event.kind == NativeTrackerEventKind.junglerSighting,
          )
          .map(
            (event) => {
              'champion': event.champion,
              'location': event.location,
              'region': event.region,
              'unseen_s': event.unseenSeconds,
              'game_time': timestampSeconds,
              'timestamp': timestampSeconds,
              'type': 'jungler_sighting',
            },
          )
          .toList();
      expect(
        actualGanks,
        frame['ganks'],
        reason: 'Gank mismatch at $timestampSeconds',
      );
      expect(
        actualSightings,
        frame['sightings'],
        reason: 'Sighting mismatch at $timestampSeconds',
      );
    }
  }, skip: corpus?.existsSync() == true ? false : 'Alert corpus unavailable.');
}
