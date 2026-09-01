import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/live_ranked_profile_loader.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/league/account_context.dart';
import 'package:godsense/domain/league/local_scout.dart';

void main() {
  test('keeps tag lines in identity and falls back to full Riot ID', () {
    expect(
      livePlayerRiotId({'summonerName': 'Same#LAN'})?.displayName,
      'Same#LAN',
    );
    expect(livePlayerRiotId({'riotIdGameName': 'Same'}), isNull);
  });

  test(
    'loads each unique identity and distinguishes unavailable from unranked',
    () async {
      final requests = <String>[];
      final loader = LiveRankedProfileLoader(
        resolve: ({required gameName, required tagLine}) async {
          requests.add('$gameName#$tagLine');
          return LeagueAccountProfile(
            puuid: Puuid(tagLine),
            platformId: PlatformId('LA1'),
            firstSeenAt: DateTime.utc(2026),
            lastSeenAt: DateTime.utc(2026),
          );
        },
        loadRanked: (puuid) async => puuid.value == 'NO'
            ? null
            : LocalRankedSnapshot(
                puuid: puuid,
                payloadJson: puuid.value == 'GOLD'
                    ? '{"queueMap":{"RANKED_SOLO_5x5":{"tier":"GOLD","division":"II","leaguePoints":42}}}'
                    : '{"queueMap":{}}',
                observedAt: DateTime.utc(2026),
                semanticHash: 'test',
              ),
      );
      final result = await loader.load([
        {'summonerName': 'Same#GOLD'},
        {'summonerName': 'Same#GOLD'},
        {'summonerName': 'Same#NONE'},
        {'summonerName': 'Same#NO'},
      ]);
      expect(requests, hasLength(3));
      expect(result['same#gold']?['tier'], 'GOLD');
      expect(result['same#none']?['tier'], 'UNRANKED');
      expect(result['same#no']?['status'], 'unavailable');
    },
  );
}
