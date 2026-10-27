import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/coach_controller.dart';
import 'package:godsense/domain/assets/game_asset_catalog.dart';
import 'package:godsense/domain/companion_models.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/league/game_session.dart';
import 'package:godsense/domain/league/item_recommendation.dart';
import 'package:godsense/domain/league/rune_recommendation.dart';

void main() {
  test('Coach projects exact-version asset names and icons with missing metadata fallbacks', () {
    final controller = CoachController(
      importRunes: (_) async {},
      importItems: () async {},
    );
    addTearDown(controller.dispose);
    final provenance = AssetProvenance(
      source: GameAssetSource.dataDragon,
      sourceVersion: '16.18.2',
      locale: LeagueLocale('es_MX'),
      contentHash: 'synthetic',
    );
    final assets = GameAssetCatalogSnapshot(
      resolvedVersion: DataDragonVersion('16.18.2'),
      runes: {
        8005: RuneMetadata(
          id: 8005,
          name: 'Ataque intensificado',
          styleId: 8000,
          slot: 0,
          isKeystone: true,
          iconPath: 'perk-images/fixture.png',
          description: 'Fixture',
          provenance: provenance,
        ),
      },
      summonerSpells: {
        4: SummonerSpellMetadata(
          id: 4,
          name: 'Destello',
          description: 'Fixture',
          iconPath: 'SummonerFlash.png',
          provenance: provenance,
        ),
      },
      items: {
        1001: ItemMetadata(
          id: 1001,
          name: 'Botas',
          description: 'Fixture',
          totalPrice: 300,
          basePrice: 300,
          iconPath: '1001',
          provenance: provenance,
        ),
        2003: ItemMetadata(
          id: 2003,
          name: 'Poción',
          description: 'Fixture',
          totalPrice: 50,
          basePrice: 50,
          iconPath: '2003.png',
          provenance: provenance,
        ),
      },
    );
    controller.synchronize(_inputs(assets: assets));
    final runes = controller.state.runeRecommendations.single;
    expect(runes.runes.first.metadata?.name, 'Ataque intensificado');
    expect(
      runes.runes.first.imageUrl,
      'https://ddragon.leagueoflegends.com/cdn/img/perk-images/fixture.png',
    );
    expect(runes.runes.last.metadata, isNull);
    expect(runes.runes.last.imageUrl, isNull);
    expect(runes.spells.first.metadata?.name, 'Destello');
    expect(
      runes.spells.first.imageUrl,
      'https://ddragon.leagueoflegends.com/cdn/16.18.2/img/spell/SummonerFlash.png',
    );
    expect(runes.spells.last.imageUrl, isNull);
    final groups = controller.state.itemRecommendationGroups;
    expect(groups.map((group) => group.title), [
      'Inicio 1',
      'Compra 1 · hasta 2 completos',
      'Compra 2',
    ]);
    expect(
      groups.first.items.first.imageUrl,
      endsWith('/16.18.2/img/item/1001.png'),
    );
    expect(
      groups.first.items.last.imageUrl,
      endsWith('/16.18.2/img/item/2003.png'),
    );
    expect(
      groups[1].items.first.imageUrl,
      endsWith('/16.18/img/item/3089.png'),
    );
    expect(groups.last.items.single.imageUrl, isNull);
    expect(controller.state.pickAdvice.single.champion, 'Ahri');
    expect(controller.state.pickAdvice.single.reasons, [
      'counter · Zed · Castiga · range · S',
    ]);
    controller.synchronize(_inputs());
    expect(
      controller.state.runeRecommendations.single.spells.first.metadata,
      isNull,
    );
    expect(
      controller.state.itemRecommendationGroups.first.items.first.imageUrl,
      endsWith('/16.18/img/item/1001.png'),
    );
  });

  for (final ahead in [true, false]) {
    test(
      'postgame review retains objectives and bounded meaningful events with gold ${ahead ? 'advantage' : 'deficit'}',
      () {
        final controller = CoachController(
          importRunes: (_) async {},
          importItems: () async {},
        );
        addTearDown(controller.dispose);
        controller.synchronize(
          _inputs(
            ended: {
              '_game_ended': true,
              'game_time': 1800,
              'team_gold_diff': ahead ? 5000 : -5000,
              'team_state': ahead ? 'WINNING' : 'LOSING',
              'active_player': {
                'champion_name': 'Ahri',
                'kda': [12, 7, 12],
                'cs': 100,
              },
              'derived': {
                'objectives': {
                  'dragons': {'ally': 1, 'enemy': 3},
                  'structures': {
                    'ally_turrets_destroyed': 6,
                    'enemy_turrets_destroyed': 2,
                  },
                },
              },
              'events': [
                {
                  'EventName': 'ChampionKill',
                  'game_time': 10,
                  'label': 'Do not project ordinary kills',
                },
                for (var i = 0; i < 15; i++)
                  {
                    'EventName': 'DragonKill',
                    'game_time': i * 60,
                    'label': 'Synthetic objective $i',
                  },
              ],
            },
          ),
        );
        final report = controller.state.postGameReport!;
        expect(report.champion, 'Ahri');
        expect(report.kda, 24 / 7);
        expect(report.allyDragons, 1);
        expect(report.enemyDragons, 3);
        expect(report.allyTurretsLost, 6);
        expect(report.enemyTurretsDestroyed, 2);
        expect(report.keyEvents, hasLength(12));
        expect(report.keyEvents.first.label, 'Synthetic objective 0');
        expect(report.keyEvents.last.timeSeconds, 660);
        expect(report.review, hasLength(5));
        expect(
          report.review.last,
          contains(ahead ? 'ventaja económica' : 'desventaja económica'),
        );
      },
    );
  }
}

CoachInputs _inputs({
  GameAssetCatalogSnapshot? assets,
  Map<String, dynamic>? ended,
}) => CoachInputs(
  gameflowPhase: ended == null ? 'ChampSelect' : 'EndOfGame',
  session: const GameSessionState(),
  liveGame: ended,
  lobby: LobbyState.fromJson({
    'phase': 'IN_SELECT',
    'pick_advice': [
      {
        'champion': 'Ahri',
        'score': 9,
        'reasons': [
          {
            'kind': 'counter',
            'enemy': 'Zed',
            'play': 'Castiga',
            'trait': 'range',
            'tier': 'S',
          },
          {},
        ],
      },
    ],
  }),
  runes: RuneRecommendationBundle(
    championId: 103,
    position: LeaguePosition.middle,
    mapId: 11,
    variants: const [
      RuneRecommendationVariant(
        recommendationId: 'fixture',
        championId: 103,
        position: LeaguePosition.middle,
        perkIds: [8005, 9999],
        primaryStyleId: 8000,
        secondaryStyleId: 8100,
        summonerSpellIds: [4, 999],
        keystoneId: 8005,
        primaryAttribute: '',
        secondaryAttribute: '',
        isDefaultPosition: true,
        isOverride: false,
      ),
    ],
    fetchedAt: DateTime.utc(2026),
  ),
  items: ItemRecommendationBundle(
    championId: 103,
    championAlias: 'Ahri',
    position: LeaguePosition.middle,
    patch: PatchKey('16.18'),
    mapId: 11,
    mode: 'CLASSIC',
    startingBundles: const [
      RecommendedItemBundle(
        items: [
          RecommendedItem(id: 1001, name: 'Boots'),
          RecommendedItem(id: 2003, name: 'Potion'),
        ],
      ),
    ],
    purchaseRanges: const [
      RecommendedItemRange(
        items: [RecommendedItem(id: 3089, name: 'Deathcap')],
        maxCompletedItems: 2,
      ),
      RecommendedItemRange(items: [RecommendedItem(id: 0, name: 'Empty')]),
    ],
    positionSpecific: true,
    fetchedAt: DateTime.utc(2026),
    sourceUri: Uri.parse('https://example.invalid/fixture'),
  ),
  jungle: null,
  directives: const [],
  threats: const [],
  voiceProcessing: false,
  voiceQuestion: '',
  voiceAdvice: null,
  voiceAnsweredAt: null,
  assets: assets,
);
