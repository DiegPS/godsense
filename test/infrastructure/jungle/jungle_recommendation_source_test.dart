import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/jungle/jungle_recommendation.dart';
import 'package:godsense/infrastructure/jungle/jungle_map_transport.dart';
import 'package:godsense/infrastructure/jungle/jungle_recommendation_source.dart';

void main() {
  group('JungleRecommendationSource', () {
    test(
      'decodes the current patch extraction end to end',
      () async {
        final transport = CommunityDragonJungleMapTransport();
        addTearDown(transport.dispose);

        final result = await JungleRecommendationSource(transport: transport)
            .load(PatchKey('16.17'));

        expect(result.order.camps, hasLength(6));
        expect(result.chaos.camps, hasLength(6));
      },
      skip: Platform.environment['GODSENSE_CDRAGON_SMOKE'] == '1'
          ? false
          : 'Set GODSENSE_CDRAGON_SMOKE=1 for the network smoke test.',
    );

    test('decodes Riot Map11 routes and resolves legacy camp names', () async {
      final source = JungleRecommendationSource(
        transport: _FakeTransport(_map11()),
        now: () => DateTime.utc(2026, 9, 1),
      );

      final result = await source.load(PatchKey('16.17'));

      expect(result.order.camps.map((camp) => camp.name), [
        'Order Red',
        'Order Krugs',
        'Order Raptors',
        'Order Wolves',
        'Order Blue',
        'Order Gromp',
      ]);
      expect(result.chaos.camps.map((camp) => camp.name), [
        'Chaos Blue',
        'Chaos Gromp',
        'Chaos Wolves',
        'Chaos Raptors',
        'Chaos Red',
        'Chaos Krugs',
      ]);
      expect(result.order.camps.first.x, 8000);
      expect(result.patch.value, '16.17');
    });

    test('rejects incomplete routes instead of inventing camps', () async {
      final data = _map11();
      final route = data['route']! as Map<String, dynamic>;
      route['OrderJunglePath'] = [
        {'Camp': 4, '__type': 'TakeCamp'},
      ];

      expect(
        () =>
            JungleRecommendationSource(transport: _FakeTransport(data))
                .load(PatchKey('16.17')),
        throwsA(isA<JungleRecommendationException>()),
      );
    });
  });
}

Map<String, dynamic> _map11() => {
  'map': {
    'JungleLocationInformation': [
      _camp('Order Owlbear', 0, 2200, 8450),
      _camp('Order Blue', 1, 3700, 8000),
      _camp('Order Wolves', 2, 3800, 6500),
      _camp('Order Wraiths', 3, 6950, 5450),
      _camp('Order Red', 4, 8000, 4100),
      _camp('Order Small Golems', 5, 8500, 2820),
      _camp('Chaos OwlBear', 6, 12500, 6500),
      _camp('Chaos Blue', 7, 10900, 7080),
      _camp('Chaos Wolves', 8, 10900, 9400),
      _camp('Chaos Wraiths', 9, 8000, 9500),
      _camp('Chaos Red', 10, 7050, 11000),
      _camp('Chaos Small Golems', 11, 6350, 12100),
    ],
    '__type': 'JungleRecommendationMapInformation',
  },
  'route': {
    'OrderJunglePath': [
      for (final camp in [4, 5, 3, 2, 1]) {'Camp': camp, '__type': 'TakeCamp'},
      {'__type': 'TakeCamp'},
      {'__type': 'TerminatePath'},
    ],
    'ChaosJunglePath': [
      for (final camp in [7, 6, 8, 9, 10, 11])
        {'Camp': camp, '__type': 'TakeCamp'},
      {'__type': 'TerminatePath'},
    ],
    '__type': 'JunglePathRecommendation',
  },
};

Map<String, dynamic> _camp(String name, int id, double x, double z) => {
  'name': name,
  if (id != 0) 'Location': id,
  'Position': [x, 0.0, z],
  '__type': 'JungleLocationMapInformation',
};

class _FakeTransport implements JungleMapTransport {
  const _FakeTransport(this.data);

  final Map<String, dynamic> data;

  @override
  Future<Map<String, dynamic>> loadMap11(PatchKey patch) async => data;

  @override
  Uri sourceUri(PatchKey patch) => Uri.parse('memory://map11/${patch.value}');
}
