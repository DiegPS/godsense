import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/companion_gateway.dart';
import '../domain/companion_models.dart';
import '../infrastructure/legacy/legacy_companion_gateway.dart';
import '../infrastructure/local_coach/local_coach_gateway.dart';
import 'companion_controller.dart';

final companionGatewayProvider = Provider<CompanionGateway>(
  (_) => LegacyCompanionGateway(),
);

final companionRuntimeProvider = Provider<CompanionRuntime>(
  (_) => LegacyCompanionRuntime(),
);

final coachGatewayProvider = Provider<CoachGateway>((_) => LocalCoachGateway());

final coachRuntimeProvider = Provider<CoachRuntime>((_) => LocalCoachRuntime());

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
