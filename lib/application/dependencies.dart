import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/companion_gateway.dart';
import '../domain/companion_models.dart';
import '../domain/tactical/tactical_models.dart';
import '../infrastructure/native_runtime/native_companion_gateway.dart';
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
        resolveAccount: league.scoutByRiotId,
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
