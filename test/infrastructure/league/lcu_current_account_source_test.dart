import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/domain/league/account_context.dart';
import 'package:godsense/infrastructure/league/lcu_current_account_source.dart';
import 'package:godsense/infrastructure/league/lcu_probe_transport.dart';

void main() {
  test(
    'maps current summoner, platform, Riot ID, and patch independently',
    () async {
      final transport = _FakeReadTransport(
        detailed: const LcuProbeResponse.success(
          statusCode: 200,
          body: {
            'puuid': 'player-puuid',
            'gameName': 'Diego',
            'tagLine': 'LAN',
            'summonerId': 42,
            'summonerLevel': 123,
            'profileIconId': 7,
          },
        ),
        reads: {
          '/riotclient/region-locale': {'region': 'la1', 'locale': 'es_MX'},
          '/lol-patch/v1/game-version': '16.17.543.1234',
        },
      );
      final source = LcuCurrentAccountSource(
        client: transport,
        now: () => DateTime.utc(2026, 9, 1),
      );

      final result = await source.loadCurrentAccount();

      expect(result.connection, AccountSourceConnection.connected);
      expect(result.account?.puuid.value, 'player-puuid');
      expect(result.account?.platformId.value, 'LA1');
      expect(result.account?.riotId?.displayName, 'Diego#LAN');
      expect(result.account?.patchKey?.value, '16.17');
      expect(result.account?.clientVersion, '16.17.543.1234');
    },
  );

  test('reports connection loss without destroying a prior context', () async {
    final source = LcuCurrentAccountSource(
      client: _FakeReadTransport(
        detailed: const LcuProbeResponse.failure(
          failureKind: LcuProbeFailureKind.disconnected,
          error: 'lockfile missing',
        ),
      ),
    );

    final result = await source.loadCurrentAccount();

    expect(result.connection, AccountSourceConnection.disconnected);
    expect(result.account, isNull);
    expect(result.error, 'lockfile missing');
  });

  test('does not invent identity when platform is missing', () async {
    final source = LcuCurrentAccountSource(
      client: _FakeReadTransport(
        detailed: const LcuProbeResponse.success(
          statusCode: 200,
          body: {'puuid': 'player-puuid'},
        ),
      ),
    );

    final result = await source.loadCurrentAccount();

    expect(result.connection, AccountSourceConnection.connected);
    expect(result.account, isNull);
    expect(result.error, contains('platform'));
  });
}

class _FakeReadTransport implements LcuReadTransport {
  _FakeReadTransport({required this.detailed, this.reads = const {}});

  final LcuProbeResponse detailed;
  final Map<String, Object?> reads;

  @override
  Future<LcuProbeResponse> getDetailed(String path) async => detailed;

  @override
  Future<Object?> get(String path) async => reads[path];
}
