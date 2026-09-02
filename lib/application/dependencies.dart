import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/companion_gateway.dart';
import '../domain/companion_models.dart';
import '../domain/assets/game_asset_catalog.dart';
import '../domain/identity/league_identity.dart';
import '../domain/tactical/tactical_models.dart';
import '../infrastructure/data_dragon/data_dragon_catalog_service.dart';
import '../infrastructure/data_dragon/data_dragon_game_asset_catalog.dart';
import '../infrastructure/native_runtime/native_companion_gateway.dart';
import 'coach_controller.dart';
import 'companion_controller.dart';
import 'local_scout_controller.dart';
import 'native_league_controller.dart';
import 'native_speech_controller.dart';
import 'native_tactical_engine.dart';
import 'native_vision_controller.dart';
import 'native_voice_coach_controller.dart';

final nativeTacticalEngineProvider = Provider<NativeTacticalEngine>(
  (_) => NativeTacticalEngine(),
);

final coachGameAssetsProvider = FutureProvider<GameAssetCatalogSnapshot?>((
  ref,
) async {
  final account = ref.watch(
    nativeLeagueProvider.select(
      (state) => state.accountContext?.context?.account,
    ),
  );
  final patch = account?.patchKey;
  if (account == null || patch == null) return null;
  final service = await DataDragonCatalogService.createDefault();
  return DataDragonGameAssetCatalog(service.resolver).load(
    patch: patch,
    platformId: account.platformId,
    clientVersion: account.clientVersion == null
        ? null
        : ClientVersion(account.clientVersion!),
  );
});

final coachControllerProvider =
    StateNotifierProvider<CoachController, CoachState>((ref) {
      final leagueController = ref.read(nativeLeagueProvider.notifier);
      final controller = CoachController(
        importRunes: leagueController.importRuneRecommendation,
        importItems: leagueController.importItemRecommendations,
      );

      void synchronize() {
        final league = ref.read(nativeLeagueProvider);
        final vision = ref.read(nativeVisionProvider);
        final voice = ref.read(nativeVoiceCoachProvider);
        final lobby = league.lobby.isEmpty
            ? null
            : LobbyState.fromJson(league.lobby);
        final threats = vision.events
            .map(
              (event) => CoachThreatViewData(
                isGank: event.kind == NativeTrackerEventKind.gank,
                champion: event.champion,
                location: event.location,
                region: event.region,
                observedAt: event.timestamp,
                confidence: vision.lastKnown[event.champion]?.confidence ?? 1,
                role: event.role,
              ),
            )
            .toList(growable: false);
        controller.synchronize(
          CoachInputs(
            gameflowPhase: league.gameflowPhase,
            session: league.gameSession,
            liveGame: league.liveGame,
            lobby: lobby,
            runes: league.runeRecommendations,
            items: league.itemRecommendations,
            jungle: league.jungleRecommendations,
            directives: ref
                .read(nativeTacticalEngineProvider)
                .directives(league.liveGame),
            threats: threats,
            voiceProcessing: voice.processing,
            voiceQuestion: voice.question,
            voiceAdvice: voice.advice,
            voiceAnsweredAt: voice.answeredAt,
            assets: ref.read(coachGameAssetsProvider).value,
          ),
        );
      }

      ref.listen(nativeLeagueProvider, (_, _) => synchronize());
      ref.listen(nativeVisionProvider, (_, _) => synchronize());
      ref.listen(nativeVoiceCoachProvider, (_, _) => synchronize());
      ref.listen(coachGameAssetsProvider, (_, _) => synchronize());
      Future<void>.microtask(synchronize);
      return controller;
    });

final nativeVoiceCoachProvider =
    StateNotifierProvider<NativeVoiceCoachController, NativeVoiceCoachState>((
      ref,
    ) {
      final speech = ref.watch(nativeSpeechProvider.notifier);
      final engine = ref.watch(nativeTacticalEngineProvider);
      return NativeVoiceCoachController(
        questions: speech.transcripts,
        answer: (question) {
          final league = ref.read(nativeLeagueProvider);
          final vision = ref.read(nativeVisionProvider);
          final sightings = vision.events
              .where(
                (event) => event.kind == NativeTrackerEventKind.junglerSighting,
              )
              .map(
                (event) => TacticalSighting(
                  champion: event.champion,
                  location: event.location,
                  observedAt: event.timestamp,
                  confidence: vision.lastKnown[event.champion]?.confidence ?? 1,
                  role: event.role,
                ),
              )
              .toList(growable: false);
          return engine.answer(
            question: question,
            game: league.liveGame,
            lobby: league.lobby,
            sightings: sightings,
          );
        },
        speak: speech.speak,
        record: (question, advice) async {
          await ref
              .read(nativeLeagueProvider.notifier)
              .recordTacticalAdvice(question: question, advice: advice);
        },
      );
    });

final localScoutProvider =
    StateNotifierProvider<LocalScoutController, LocalScoutState>((ref) {
      final league = ref.read(nativeLeagueProvider.notifier);
      final controller = LocalScoutController(
        loadMatches: league.loadLocalMatches,
        loadRanked: league.loadLocalRanked,
        loadMatchDetails: league.loadScoutMatchDetails,
        resolveAccount: league.resolveScoutAccount,
        synchronizeAccount: league.synchronizeScoutAccount,
        loadChampionNames: league.loadChampionNames,
      );
      ref.listen(
        nativeLeagueProvider.select(
          (state) => state.accountContext?.context?.account,
        ),
        (_, account) => controller.loadAccount(account),
        fireImmediately: true,
      );
      return controller;
    });

final companionGatewayProvider = Provider<CompanionGateway>((ref) {
  final engine = ref.watch(nativeTacticalEngineProvider);
  return NativeCompanionGateway(
    lobbySnapshot: () {
      final lobby = ref.read(nativeLeagueProvider).lobby;
      return lobby.isEmpty ? null : lobby;
    },
    gameSnapshot: () => ref.read(nativeLeagueProvider).liveGame,
    tacticalAnalysis: engine.analyze,
    tacticalDirectives: engine.directives,
  );
});

final companionRuntimeProvider = Provider<CompanionRuntime>(
  (_) => const InProcessCompanionRuntime(),
);

final coachGatewayProvider = Provider<CoachGateway>(
  (_) => const NativeCoachHealthGateway(),
);

final coachRuntimeProvider = Provider<CoachRuntime>(
  (_) => const InProcessCompanionRuntime(),
);

final companionControllerProvider =
    StateNotifierProvider<CompanionController, CompanionState>((ref) {
      final controller = CompanionController(
        ref.watch(companionGatewayProvider),
        runtime: ref.watch(companionRuntimeProvider),
        coach: ref.watch(coachGatewayProvider),
        coachRuntime: ref.watch(coachRuntimeProvider),
      );
      controller.start();
      return controller;
    });
