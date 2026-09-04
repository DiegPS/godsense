// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/assets/game_asset_catalog.dart';
import '../domain/companion_models.dart';
import '../domain/jungle/jungle_recommendation.dart';
import '../domain/league/game_session.dart';
import '../domain/league/item_recommendation.dart';
import '../domain/league/rune_recommendation.dart';
import '../domain/tactical/composition_models.dart';
import '../domain/tactical/tactical_models.dart';
import 'champion_composition_analyzer.dart';

enum CoachPhase { champSelect, inGame, postGame, inactive }

class CoachPhaseResolver {
  const CoachPhaseResolver();

  CoachPhase resolve({
    required GameSessionState session,
    required bool liveGameActive,
    required String gameflowPhase,
  }) {
    if (liveGameActive) return CoachPhase.inGame;
    final current = session.current;
    if (current?.phase == GameSessionPhase.champSelect ||
        _isChampSelect(gameflowPhase)) {
      return CoachPhase.champSelect;
    }
    if (current?.phase == GameSessionPhase.postGame ||
        _isPostGame(gameflowPhase)) {
      return CoachPhase.postGame;
    }
    return CoachPhase.inactive;
  }
}

bool _isChampSelect(String value) {
  final phase = value.trim().toLowerCase().replaceAll('_', '');
  return phase == 'inselect' || phase == 'champselect';
}

bool _isPostGame(String value) {
  final phase = value.trim().toLowerCase().replaceAll('_', '');
  return phase == 'postgame' || phase == 'endofgame';
}

class CoachThreatViewData {
  const CoachThreatViewData({
    required this.isGank,
    required this.champion,
    required this.location,
    required this.region,
    required this.observedAt,
    required this.confidence,
    this.role,
  });

  final bool isGank;
  final String champion;
  final String location;
  final String region;
  final DateTime observedAt;
  final double confidence;
  final String? role;
}

class GoldPointViewData {
  const GoldPointViewData({required this.gameTime, required this.value});

  final double gameTime;
  final int value;
}

class VoiceCoachEntry {
  const VoiceCoachEntry({
    required this.question,
    required this.answer,
    required this.answeredAt,
  });

  final String question;
  final String answer;
  final DateTime answeredAt;
}

class PostGameReport {
  const PostGameReport({
    required this.champion,
    required this.kills,
    required this.deaths,
    required this.assists,
    required this.cs,
    required this.durationSeconds,
    required this.finalGoldDifference,
    required this.teamState,
    required this.allyDragons,
    required this.enemyDragons,
    required this.allyTurretsLost,
    required this.enemyTurretsDestroyed,
    required this.keyEvents,
    required this.review,
    this.sessionId,
    this.matchLabel,
  });

  final String champion;
  final String? sessionId;
  final String? matchLabel;
  final int kills;
  final int deaths;
  final int assists;
  final int cs;
  final double durationSeconds;
  final int finalGoldDifference;
  final String teamState;
  final int allyDragons;
  final int enemyDragons;
  final int allyTurretsLost;
  final int enemyTurretsDestroyed;
  final List<PostGameEvent> keyEvents;
  final List<String> review;

  double get kda => (kills + assists) / (deaths == 0 ? 1 : deaths);
}

class PostGameEvent {
  const PostGameEvent({required this.timeSeconds, required this.label});

  final double timeSeconds;
  final String label;
}

class RuneRecommendationViewData {
  const RuneRecommendationViewData({
    required this.variant,
    required this.runes,
    required this.spells,
  });

  final RuneRecommendationVariant variant;
  final List<RuneAssetViewData> runes;
  final List<SpellAssetViewData> spells;
}

class RuneAssetViewData {
  const RuneAssetViewData({required this.id, this.metadata, this.imageUrl});

  final int id;
  final RuneMetadata? metadata;
  final String? imageUrl;
}

class SpellAssetViewData {
  const SpellAssetViewData({required this.id, this.metadata, this.imageUrl});

  final int id;
  final SummonerSpellMetadata? metadata;
  final String? imageUrl;
}

class RecommendedItemViewData {
  const RecommendedItemViewData({
    required this.item,
    this.metadata,
    this.imageUrl,
  });

  final RecommendedItem item;
  final ItemMetadata? metadata;
  final String? imageUrl;
}

class RecommendedItemGroupViewData {
  const RecommendedItemGroupViewData({
    required this.title,
    required this.items,
  });

  final String title;
  final List<RecommendedItemViewData> items;
}

class PickAdviceViewData {
  const PickAdviceViewData({
    required this.champion,
    required this.scoreLabel,
    required this.reasons,
  });

  final String champion;
  final String? scoreLabel;
  final List<String> reasons;
}

enum CoachImportStatus { idle, importing, succeeded, failed }

class CoachImportFeedback {
  const CoachImportFeedback({
    this.status = CoachImportStatus.idle,
    this.message,
  });

  final CoachImportStatus status;
  final String? message;
}

class CoachInputs {
  const CoachInputs({
    required this.gameflowPhase,
    required this.session,
    required this.liveGame,
    required this.lobby,
    required this.runes,
    required this.items,
    required this.jungle,
    required this.directives,
    required this.threats,
    required this.voiceProcessing,
    required this.voiceQuestion,
    required this.voiceAdvice,
    required this.voiceAnsweredAt,
    this.assets,
    this.accountKey,
  });

  final String gameflowPhase;
  final GameSessionState session;
  final Map<String, dynamic>? liveGame;
  final LobbyState? lobby;
  final RuneRecommendationBundle? runes;
  final ItemRecommendationBundle? items;
  final JungleRecommendationBundle? jungle;
  final List<TacticalAdvice> directives;
  final List<CoachThreatViewData> threats;
  final bool voiceProcessing;
  final String voiceQuestion;
  final TacticalAdvice? voiceAdvice;
  final DateTime? voiceAnsweredAt;
  final GameAssetCatalogSnapshot? assets;
  final String? accountKey;
}

abstract interface class PostGameReportStore {
  Future<Map<String, dynamic>?> load(String accountKey);
  Future<void> save(String accountKey, Map<String, dynamic> snapshot);
}

class CoachState {
  const CoachState({
    this.phase = CoachPhase.inactive,
    this.automaticPhase = CoachPhase.inactive,
    this.lobby,
    this.localChampion = '',
    this.selectedEnemy,
    this.runeRecommendations = const [],
    this.itemRecommendationGroups = const [],
    this.pickAdvice = const [],
    this.jungle,
    this.allyComposition,
    this.enemyComposition,
    this.directives = const [],
    this.threats = const [],
    this.goldDifferential = 0,
    this.goldTimeline = const [],
    this.voiceProcessing = false,
    this.voiceHistory = const [],
    this.importFeedback = const CoachImportFeedback(),
    this.lastCompletedSession,
    this.postGameReport,
  });

  final CoachPhase phase;
  final CoachPhase automaticPhase;
  final LobbyState? lobby;
  final String localChampion;
  final String? selectedEnemy;
  final List<RuneRecommendationViewData> runeRecommendations;
  final List<RecommendedItemGroupViewData> itemRecommendationGroups;
  final List<PickAdviceViewData> pickAdvice;
  final JungleRecommendationBundle? jungle;
  final DeterministicCompositionProfile? allyComposition;
  final DeterministicCompositionProfile? enemyComposition;
  final List<TacticalAdvice> directives;
  final List<CoachThreatViewData> threats;
  final int goldDifferential;
  final List<GoldPointViewData> goldTimeline;
  final bool voiceProcessing;
  final List<VoiceCoachEntry> voiceHistory;
  final CoachImportFeedback importFeedback;
  final GameSession? lastCompletedSession;
  final PostGameReport? postGameReport;

  CoachState copyWith({
    CoachPhase? phase,
    CoachPhase? automaticPhase,
    LobbyState? lobby,
    String? localChampion,
    String? selectedEnemy,
    bool clearSelectedEnemy = false,
    List<RuneRecommendationViewData>? runeRecommendations,
    List<RecommendedItemGroupViewData>? itemRecommendationGroups,
    List<PickAdviceViewData>? pickAdvice,
    JungleRecommendationBundle? jungle,
    DeterministicCompositionProfile? allyComposition,
    DeterministicCompositionProfile? enemyComposition,
    List<TacticalAdvice>? directives,
    List<CoachThreatViewData>? threats,
    int? goldDifferential,
    List<GoldPointViewData>? goldTimeline,
    bool? voiceProcessing,
    List<VoiceCoachEntry>? voiceHistory,
    CoachImportFeedback? importFeedback,
    GameSession? lastCompletedSession,
    PostGameReport? postGameReport,
    bool clearReport = false,
  }) => CoachState(
    phase: phase ?? this.phase,
    automaticPhase: automaticPhase ?? this.automaticPhase,
    lobby: lobby ?? this.lobby,
    localChampion: localChampion ?? this.localChampion,
    selectedEnemy: clearSelectedEnemy
        ? null
        : selectedEnemy ?? this.selectedEnemy,
    runeRecommendations: runeRecommendations ?? this.runeRecommendations,
    itemRecommendationGroups:
        itemRecommendationGroups ?? this.itemRecommendationGroups,
    pickAdvice: pickAdvice ?? this.pickAdvice,
    jungle: jungle ?? this.jungle,
    allyComposition: allyComposition ?? this.allyComposition,
    enemyComposition: enemyComposition ?? this.enemyComposition,
    directives: directives ?? this.directives,
    threats: threats ?? this.threats,
    goldDifferential: goldDifferential ?? this.goldDifferential,
    goldTimeline: goldTimeline ?? this.goldTimeline,
    voiceProcessing: voiceProcessing ?? this.voiceProcessing,
    voiceHistory: voiceHistory ?? this.voiceHistory,
    importFeedback: importFeedback ?? this.importFeedback,
    lastCompletedSession: clearReport
        ? null
        : lastCompletedSession ?? this.lastCompletedSession,
    postGameReport: clearReport ? null : postGameReport ?? this.postGameReport,
  );
}

typedef ImportRuneRecommendation = Future<void> Function(
  RuneRecommendationVariant variant,
);

class CoachController extends StateNotifier<CoachState> {
  CoachController({
    required ImportRuneRecommendation importRunes,
    required Future<void> Function() importItems,
    PostGameReportStore? reportStore,
    CoachPhaseResolver phaseResolver = const CoachPhaseResolver(),
    ChampionCompositionAnalyzer compositionAnalyzer =
        const ChampionCompositionAnalyzer(),
  }) : _importRunes = importRunes,
       _reportStore = reportStore,
       _importItems = importItems,
       _phaseResolver = phaseResolver,
       _compositionAnalyzer = compositionAnalyzer,
       super(const CoachState());

  final ImportRuneRecommendation _importRunes;
  final PostGameReportStore? _reportStore;
  String? _accountKey;
  String? _lastSavedReport;
  int _reportRevision = 0;
  Future<void> _reportWrites = Future<void>.value();
  final Future<void> Function() _importItems;
  final CoachPhaseResolver _phaseResolver;
  final ChampionCompositionAnalyzer _compositionAnalyzer;
  CoachPhase? _manualPhase;
  DateTime? _lastVoiceAnswer;

  void synchronize(CoachInputs inputs) {
    if (inputs.accountKey != _accountKey) {
      _accountKey = inputs.accountKey;
      _lastSavedReport = null;
      final revision = ++_reportRevision;
      state = state.copyWith(clearReport: true, voiceHistory: const []);
      final key = _accountKey;
      if (key != null) unawaited(_restoreReport(key, revision));
    }
    final endedGame = inputs.liveGame;
    final session = inputs.session.current ?? inputs.session.lastCompleted;
    final matchesAccount =
        inputs.accountKey == null ||
        session?.accountPuuid?.value == inputs.accountKey;
    Map<String, dynamic>? completedSnapshot;
    if (endedGame?['_game_ended'] == true && matchesAccount) {
      final active = endedGame!['active_player'] as Map? ?? const {};
      final derived = endedGame['derived'] as Map? ?? const {};
      completedSnapshot = {
        '_game_ended': true,
        'session_id': session?.sessionId ?? endedGame['session_id'],
        'match_label': session?.match?.toString(),
        'game_time': endedGame['game_time'],
        'team_gold_diff': endedGame['team_gold_diff'],
        'team_state': endedGame['team_state'],
        'active_player': {
          for (final key in ['champion_name', 'kda', 'cs']) key: active[key],
        },
        'derived': {'objectives': derived['objectives']},
        'events': _mapList(endedGame['events'])
            .map(
              (event) => {
                for (final key in ['EventName', 'game_time', 'label'])
                  key: event[key],
              },
            )
            .toList(),
      };
      final key = _accountKey;
      final encoded = jsonEncode(completedSnapshot);
      if (key != null && encoded != _lastSavedReport) {
        _reportRevision++;
        _lastSavedReport = encoded;
        final snapshot = completedSnapshot;
        _reportWrites = _reportWrites
            .then((_) async {
              await _reportStore?.save(key, snapshot);
            })
            .catchError((Object _) {
              if (mounted && _accountKey == key) _lastSavedReport = null;
            });
      }
    }
    final automatic = _phaseResolver.resolve(
      session: inputs.session,
      liveGameActive:
          inputs.liveGame != null && inputs.liveGame!['_game_ended'] != true,
      gameflowPhase: inputs.gameflowPhase,
    );
    final enemies =
        inputs.lobby?.draft.enemies
            .where((player) => player.championName.isNotEmpty)
            .map((player) => player.championName)
            .toList(growable: false) ??
        const <String>[];
    final selectedEnemy = enemies.contains(state.selectedEnemy)
        ? state.selectedEnemy
        : enemies.firstOrNull;
    final voiceHistory = [...state.voiceHistory];
    if (inputs.voiceAdvice != null &&
        inputs.voiceAnsweredAt != null &&
        inputs.voiceAnsweredAt != _lastVoiceAnswer) {
      _lastVoiceAnswer = inputs.voiceAnsweredAt;
      voiceHistory.insert(
        0,
        VoiceCoachEntry(
          question: inputs.voiceQuestion,
          answer: inputs.voiceAdvice!.ttsText,
          answeredAt: inputs.voiceAnsweredAt!,
        ),
      );
      if (voiceHistory.length > 20) {
        voiceHistory.removeRange(20, voiceHistory.length);
      }
    }
    final goldPoints = _mapList(inputs.liveGame?['gold_points'])
        .map(
          (point) => GoldPointViewData(
            gameTime: (point['game_time'] as num?)?.toDouble() ?? 0,
            value: (point['value'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList(growable: false);
    final draft = inputs.lobby?.draft;
    final allyMaps = inputs.lobby?.myTeam ?? const <Map<String, dynamic>>[];
    final enemyMaps = inputs.lobby?.enemyTeam ?? const <Map<String, dynamic>>[];
    state = state.copyWith(
      automaticPhase: automatic,
      phase: _manualPhase ?? automatic,
      lobby: inputs.lobby,
      localChampion:
          draft?.allies
              .where((player) => player.isLocal)
              .firstOrNull
              ?.championName ??
          '',
      selectedEnemy: selectedEnemy,
      clearSelectedEnemy: selectedEnemy == null,
      runeRecommendations: _runes(inputs.runes, inputs.assets),
      itemRecommendationGroups: _items(inputs.items, inputs.assets),
      pickAdvice: _pickAdvice(inputs.lobby?.pickAdvice),
      jungle: inputs.jungle,
      allyComposition: _compositionAnalyzer.typedProfile(allyMaps),
      enemyComposition: _compositionAnalyzer.typedProfile(enemyMaps),
      directives: List.unmodifiable(inputs.directives),
      threats: List.unmodifiable(inputs.threats),
      goldDifferential:
          (inputs.liveGame?['team_gold_diff'] as num?)?.toInt() ?? 0,
      goldTimeline: goldPoints,
      voiceProcessing: inputs.voiceProcessing,
      voiceHistory: List.unmodifiable(voiceHistory),
      lastCompletedSession: inputs.session.lastCompleted,
      postGameReport:
          _postGameReport(completedSnapshot) ?? state.postGameReport,
    );
  }

  Future<void> _restoreReport(String key, int revision) async {
    try {
      await _reportWrites;
      final snapshot = await _reportStore?.load(key);
      if (!mounted || revision != _reportRevision || _accountKey != key) return;
      state = state.copyWith(postGameReport: _postGameReport(snapshot));
    } catch (_) {
      // An unreadable saved report must not prevent live coaching.
    }
  }

  void selectEnemy(String enemy) =>
      state = state.copyWith(selectedEnemy: enemy);

  void showPhase(CoachPhase? phase) {
    _manualPhase = phase;
    state = state.copyWith(phase: phase ?? state.automaticPhase);
  }

  Future<void> importRune(RuneRecommendationVariant variant) =>
      _runImport('Runas importadas en League.', () => _importRunes(variant));

  Future<void> importItemSet() =>
      _runImport('Set de objetos importado en League.', _importItems);

  Future<void> importCurrentSetup() async {
    final runes = state.runeRecommendations.firstOrNull;
    if (runes != null) {
      await importRune(runes.variant);
      if (state.importFeedback.status == CoachImportStatus.failed) return;
    }
    if (state.itemRecommendationGroups.isNotEmpty) await importItemSet();
  }

  Future<void> _runImport(
    String successMessage,
    Future<void> Function() operation,
  ) async {
    state = state.copyWith(
      importFeedback: const CoachImportFeedback(
        status: CoachImportStatus.importing,
        message: 'Importando en el cliente de League…',
      ),
    );
    try {
      await operation();
      state = state.copyWith(
        importFeedback: CoachImportFeedback(
          status: CoachImportStatus.succeeded,
          message: successMessage,
        ),
      );
    } catch (error) {
      state = state.copyWith(
        importFeedback: CoachImportFeedback(
          status: CoachImportStatus.failed,
          message: 'No se pudo importar: $error',
        ),
      );
    }
  }
}

List<RuneRecommendationViewData> _runes(
  RuneRecommendationBundle? bundle,
  GameAssetCatalogSnapshot? assets,
) =>
    bundle?.variants
        .map((variant) {
          return RuneRecommendationViewData(
            variant: variant,
            runes: variant.perkIds
                .map((id) {
                  final metadata = assets?.runes[id];
                  return RuneAssetViewData(
                    id: id,
                    metadata: metadata,
                    imageUrl: metadata == null || metadata.iconPath.isEmpty
                        ? null
                        : 'https://ddragon.leagueoflegends.com/cdn/img/'
                              '${metadata.iconPath}',
                  );
                })
                .toList(growable: false),
            spells: variant.summonerSpellIds
                .map((id) {
                  final metadata = assets?.summonerSpells[id];
                  return SpellAssetViewData(
                    id: id,
                    metadata: metadata,
                    imageUrl: metadata == null || metadata.iconPath.isEmpty
                        ? null
                        : 'https://ddragon.leagueoflegends.com/cdn/'
                              '${metadata.provenance.sourceVersion}/img/spell/'
                              '${metadata.iconPath}',
                  );
                })
                .toList(growable: false),
          );
        })
        .toList(growable: false) ??
    const [];

List<RecommendedItemGroupViewData> _items(
  ItemRecommendationBundle? bundle,
  GameAssetCatalogSnapshot? assets,
) {
  if (bundle == null) return const [];
  RecommendedItemViewData project(RecommendedItem item) {
    final metadata = assets?.items[item.id];
    final version = metadata?.provenance.sourceVersion ?? bundle.patch.value;
    final iconFile = metadata != null && metadata.iconPath.isNotEmpty
        ? (metadata.iconPath.endsWith('.png')
              ? metadata.iconPath
              : '${metadata.iconPath}.png')
        : '${item.id}.png';
    final imageUrl = item.id > 0
        ? 'https://ddragon.leagueoflegends.com/cdn/$version/img/item/$iconFile'
        : null;
    return RecommendedItemViewData(
      item: item,
      metadata: metadata,
      imageUrl: imageUrl,
    );
  }

  return [
    for (var index = 0; index < bundle.startingBundles.length; index++)
      RecommendedItemGroupViewData(
        title: 'Inicio ${index + 1}',
        items: bundle.startingBundles[index].items
            .map(project)
            .toList(growable: false),
      ),
    for (var index = 0; index < bundle.purchaseRanges.length; index++)
      RecommendedItemGroupViewData(
        title:
            'Compra ${index + 1}'
            '${bundle.purchaseRanges[index].maxCompletedItems == null ? '' : ' · hasta ${bundle.purchaseRanges[index].maxCompletedItems} completos'}',
        items: bundle.purchaseRanges[index].items
            .map(project)
            .toList(growable: false),
      ),
  ];
}

List<PickAdviceViewData> _pickAdvice(List<Map<String, dynamic>>? raw) =>
    raw
        ?.map((item) {
          final reasons = _mapList(item['reasons'])
              .map(
                (reason) => [
                  reason['kind'],
                  reason['enemy'],
                  reason['play'],
                  reason['trait'],
                  reason['tier'],
                ].where((value) => value != null).join(' · '),
              )
              .where((value) => value.isNotEmpty)
              .toList(growable: false);
          return PickAdviceViewData(
            champion: item['champion']?.toString() ?? 'Campeón',
            scoreLabel: item['score']?.toString(),
            reasons: reasons,
          );
        })
        .toList(growable: false) ??
    const [];

List<Map<String, dynamic>> _mapList(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map(
            (item) => item.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList(growable: false)
    : const [];

PostGameReport? _postGameReport(Map<String, dynamic>? game) {
  if (game == null || game['_game_ended'] != true) return null;
  final active = game['active_player'] is Map
      ? Map<String, dynamic>.from(game['active_player'] as Map)
      : const <String, dynamic>{};
  final kda = active['kda'] is List ? active['kda'] as List : const [];
  int stat(int index) =>
      index < kda.length && kda[index] is num ? (kda[index] as num).toInt() : 0;
  final derived = game['derived'] is Map
      ? Map<String, dynamic>.from(game['derived'] as Map)
      : const <String, dynamic>{};
  final objectives = derived['objectives'] is Map
      ? Map<String, dynamic>.from(derived['objectives'] as Map)
      : const <String, dynamic>{};
  final dragons = objectives['dragons'] is Map
      ? Map<String, dynamic>.from(objectives['dragons'] as Map)
      : const <String, dynamic>{};
  final structures = objectives['structures'] is Map
      ? Map<String, dynamic>.from(objectives['structures'] as Map)
      : const <String, dynamic>{};
  final events = _mapList(game['events'])
      .where(
        (event) => const {
          'DragonKill',
          'BaronKill',
          'HeraldKill',
          'TurretKilled',
          'InhibKilled',
          'GameEnd',
        }.contains(event['EventName']),
      )
      .map(
        (event) => PostGameEvent(
          timeSeconds: (event['game_time'] as num?)?.toDouble() ?? 0,
          label:
              event['label']?.toString() ??
              event['EventName']?.toString() ??
              'Evento',
        ),
      )
      .take(12)
      .toList(growable: false);
  final kills = stat(0);
  final deaths = stat(1);
  final assists = stat(2);
  final cs = (active['cs'] as num?)?.toInt() ?? 0;
  final duration = (game['game_time'] as num?)?.toDouble() ?? 0;
  final goldDifference = (game['team_gold_diff'] as num?)?.toInt() ?? 0;
  final review = <String>[
    if (duration > 0 && cs / (duration / 60) < 5) 'La generación de recursos quedó por debajo de 5 CS/min; prioriza oleadas seguras antes de rotar.',
    if (deaths >= 7)
      'Hubo $deaths muertes: revisa las entradas sin visión y conserva una ruta de salida.',
    if (kills + assists >= deaths * 3) 'La participación individual fue sólida; busca convertir esas ventajas en objetivos.',
    if ((dragons['enemy'] as num?)?.toInt() case final enemy? when enemy >= 3)
      'El rival acumuló $enemy dragones; prepara visión y prioridad con más antelación.',
    if (goldDifference.abs() >= 2000)
      goldDifference > 0
          ? 'La partida terminó con ventaja económica: revisa si podía cerrarse antes.'
          : 'La partida terminó con desventaja económica: identifica el primer punto de ruptura.',
  ];
  if (review.isEmpty) {
    review.add(
      'Revisa los eventos clave y compáralos con la prioridad de objetivos de cada minuto.',
    );
  }
  return PostGameReport(
    sessionId: game['session_id']?.toString(),
    matchLabel: game['match_label']?.toString(),
    champion: active['champion_name']?.toString() ?? 'Campeón',
    kills: kills,
    deaths: deaths,
    assists: assists,
    cs: cs,
    durationSeconds: duration,
    finalGoldDifference: goldDifference,
    teamState: game['team_state']?.toString() ?? 'UNKNOWN',
    allyDragons: (dragons['ally'] as num?)?.toInt() ?? 0,
    enemyDragons: (dragons['enemy'] as num?)?.toInt() ?? 0,
    allyTurretsLost:
        (structures['ally_turrets_destroyed'] as num?)?.toInt() ?? 0,
    enemyTurretsDestroyed:
        (structures['enemy_turrets_destroyed'] as num?)?.toInt() ?? 0,
    keyEvents: events,
    review: List.unmodifiable(review),
  );
}
