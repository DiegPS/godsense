import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/companion_models.dart';
import 'native_vision_controller.dart';

const overlayParityPanelIds = [
  'matchup_info',
  'builds',
  'directives',
  'team_comp',
  'gold_chart',
  'gank',
  'jungler',
  'voice_ask',
];

class OverlayParityLogger {
  String? _lastState;
  Future<void> _queue = Future.value();

  void record(
    CompanionState legacy,
    NativeVisionState native,
    GameSnapshot? game,
  ) {
    final legacyGank = legacy.alerts
        .where((alert) => alert.kind == CompanionAlertKind.gank)
        .firstOrNull;
    final legacyVoice = legacy.alerts
        .where((alert) => alert.kind == CompanionAlertKind.voice)
        .firstOrNull;
    final nativeGank = native.events
        .where((event) => event.kind == NativeTrackerEventKind.gank)
        .firstOrNull;
    final gameJungler = _jungler(game?.enemies);
    final nativeJunglerName = gameJungler?['champion_name']?.toString();
    final nativeJungler = nativeJunglerName == null
        ? null
        : _findNative(native.lastKnown, nativeJunglerName);

    final python = {
      'matchup_info': legacy.coaching['matchup'],
      'builds': legacy.coaching['builds'],
      'directives': legacy.directives.map(_directive).toList(),
      'team_comp': legacy.coaching['team_comp'],
      'gold_chart': null,
      'gank': legacyGank == null
          ? null
          : {
              'champion': legacyGank.raw['champion_name'],
              'location': legacyGank.raw['zone'],
              'role': legacyGank.raw['role'],
              'threat': legacyGank.raw['threat_level'],
            },
      'jungler': null,
      'voice_ask': legacyVoice?.raw,
    };
    final godsense = {
      'matchup_info': legacy.coaching['matchup'],
      'builds': legacy.coaching['builds'],
      'directives': legacy.directives.map(_directive).toList(),
      'team_comp': legacy.coaching['team_comp'],
      'gold_chart': game?.raw['team_gold_diff'],
      'gank': nativeGank == null
          ? null
          : {
              'champion': nativeGank.champion,
              'location': nativeGank.location,
              'role': nativeGank.role,
              'threat': 'DANGER',
            },
      'jungler': gameJungler == null
          ? null
          : {
              'champion': gameJungler['champion_name'],
              'location':
                  nativeJungler?.region ??
                  gameJungler['map_location'] ??
                  gameJungler['last_known_location'],
              'mia': gameJungler['is_mia'] ?? false,
            },
      'voice_ask': legacyVoice?.raw,
    };
    final equality = {
      for (final id in overlayParityPanelIds)
        id: _canonical(python[id]) == _canonical(godsense[id]),
    };
    final stateOnly = jsonEncode({'python': python, 'godsense': godsense});
    if (stateOnly == _lastState) return;
    _lastState = stateOnly;
    final line = jsonEncode({
      'timestamp': DateTime.now().toIso8601String(),
      'python': python,
      'godsense': godsense,
      'equal': equality,
      'sources': {
        'matchup_info': 'fallback',
        'builds': 'fallback',
        'directives': 'fallback',
        'team_comp': 'fallback',
        'gold_chart': 'native_live_client',
        'gank': 'native_dartcv',
        'jungler': 'native_dartcv',
        'voice_ask': 'fallback',
      },
    });
    _queue = _queue.then((_) => _write('$line\n'));
  }

  Map<String, dynamic>? _jungler(List<Map<String, dynamic>>? enemies) {
    return enemies
        ?.where((enemy) => enemy['role']?.toString().toUpperCase() == 'JUNGLE')
        .firstOrNull;
  }

  NativeIdentifiedChampion? _findNative(
    Map<String, NativeIdentifiedChampion> values,
    String name,
  ) {
    String normalize(String value) =>
        value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final direct = values[name];
    if (direct != null) return direct;
    final normalized = normalize(name);
    return values.entries
        .where((entry) => normalize(entry.key) == normalized)
        .firstOrNull
        ?.value;
  }

  Map<String, dynamic> _directive(CoachDirective value) => {
    'id': value.id,
    'title': value.title,
    'hints': value.hints,
    'rationale': value.rationale,
    'tts_text': value.ttsText,
  };

  String _canonical(Object? value) {
    Object? normalize(Object? item) {
      if (item is Map) {
        final keys = item.keys.map((key) => key.toString()).toList()..sort();
        return {for (final key in keys) key: normalize(item[key])};
      }
      if (item is List) return item.map(normalize).toList();
      if (item is num) return item.toDouble();
      return item;
    }

    return jsonEncode(normalize(value));
  }

  Future<void> _write(String line) async {
    final appData = Platform.environment['APPDATA'];
    if (appData == null) return;
    final directory = Directory('$appData\\GodSense');
    await directory.create(recursive: true);
    await File('${directory.path}\\overlay-comparison-$pid.jsonl')
        .writeAsString(line, mode: FileMode.append, flush: true);
  }
}
