import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/league/rune_recommendation.dart';
import 'package:godsense/infrastructure/league/lcu_probe_transport.dart';
import 'package:godsense/infrastructure/league/lcu_rune_recommendation_source.dart';

void main() {
  group('LcuRuneRecommendationSource', () {
    test('parses every valid variant returned by the League Client', () async {
      final client = _FakeClient([
        _variant('rune-a', secondaryStyle: 8200),
        _variant('rune-b', secondaryStyle: 8300),
      ]);
      final source = LcuRuneRecommendationSource(
        client: client,
        now: () => DateTime.utc(2026, 9, 1, 10),
      );

      final result = await source.load(
        championId: 103,
        position: LeaguePosition.middle,
        clientVersion: ClientVersion('16.17.8104348'),
        patch: PatchKey('16.17'),
      );

      expect(result.variants, hasLength(2));
      expect(result.variants.first.recommendationId, 'rune-a');
      expect(result.variants.first.perkIds, hasLength(9));
      expect(result.variants.first.summonerSpellIds, [4, 12]);
      expect(result.clientVersion?.value, '16.17.8104348');
      expect(result.patch?.value, '16.17');
      expect(
        client.paths.single,
        '/lol-perks/v1/recommended-pages/champion/103/'
        'position/MIDDLE/map/11',
      );
    });

    test('rejects a permissive fallback for another position', () async {
      final fallback = _variant('fallback')..['position'] = 'TOP';
      final source = LcuRuneRecommendationSource(
        client: _FakeClient([fallback]),
      );

      expect(
        () => source.load(championId: 103, position: LeaguePosition.middle),
        throwsA(isA<RuneRecommendationException>()),
      );
    });

    test('rejects malformed and empty successful responses', () async {
      final malformed = _variant('broken')
        ..['perks'] = [
          {'id': 8112},
        ];
      final malformedSource = LcuRuneRecommendationSource(
        client: _FakeClient([malformed]),
      );
      final emptySource = LcuRuneRecommendationSource(
        client: _FakeClient(const []),
      );

      expect(
        () => malformedSource.load(
          championId: 103,
          position: LeaguePosition.middle,
        ),
        throwsA(isA<RuneRecommendationException>()),
      );
      expect(
        () => emptySource.load(
          championId: 999999,
          position: LeaguePosition.middle,
        ),
        throwsA(isA<RuneRecommendationException>()),
      );
    });

    test('normalizes League position aliases without inventing positions', () {
      expect(LeaguePosition.tryParse('mid'), LeaguePosition.middle);
      expect(LeaguePosition.tryParse('support'), LeaguePosition.utility);
      expect(LeaguePosition.tryParse('adc'), LeaguePosition.bottom);
      expect(LeaguePosition.tryParse('none'), isNull);
    });
  });
}

Map<String, dynamic> _variant(String id, {int secondaryStyle = 8200}) => {
  'recommendationId': id,
  'recommendationChampionId': 103,
  'position': 'MIDDLE',
  'perks': [
    for (final id in [8112, 8139, 8140, 8106, 8226, 8210, 5005, 5008, 5001])
      {'id': id},
  ],
  'keystone': {'id': 8112},
  'primaryPerkStyleId': 8100,
  'secondaryPerkStyleId': secondaryStyle,
  'summonerSpellIds': [4, 12],
  'primaryRecommendationAttribute': 'kCooldown',
  'secondaryRecommendationAttribute': 'kMana',
  'isDefaultPosition': true,
  'isRecommendationOverride': false,
};

class _FakeClient implements LcuReadTransport {
  _FakeClient(this.response);

  final Object? response;
  final List<String> paths = [];

  @override
  Future<Object?> get(String path) async {
    paths.add(path);
    return response;
  }

  @override
  Future<LcuProbeResponse> getDetailed(String path) async =>
      LcuProbeResponse.success(body: response, statusCode: 200);
}
