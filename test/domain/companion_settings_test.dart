import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/domain/companion_models.dart';

void main() {
  test('equivalent settings snapshots compare equal', () {
    final first = CompanionSettings.fromJson({
      'settings': {
        'ptt_key': 'delete',
        'tts_enabled': true,
        'tts_volume': 0.8,
        'language': 'es',
        'cadence': 'normal',
        'overlay_hidden_panels': ['gank'],
      },
      'meta': {
        'locks': {'language': false},
      },
    });
    final second = CompanionSettings.fromJson({
      'settings': {
        'ptt_key': 'delete',
        'tts_enabled': true,
        'tts_volume': 0.8,
        'language': 'es',
        'cadence': 'normal',
        'overlay_hidden_panels': ['gank'],
      },
      'meta': {
        'locks': {'language': false},
      },
    });

    expect(second, first);
    expect(second.hashCode, first.hashCode);
  });
}
