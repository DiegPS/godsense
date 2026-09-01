import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/companion_gateway.dart';
import '../domain/companion_models.dart';
import '../infrastructure/native_runtime/native_companion_gateway.dart';
import 'companion_controller.dart';
import 'native_league_controller.dart';
import 'native_tactical_engine.dart';

final nativeTacticalEngineProvider = Provider<NativeTacticalEngine>(
  (_) => NativeTacticalEngine(),
);

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
