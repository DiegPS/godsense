import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../domain/companion_gateway.dart';
import '../domain/companion_models.dart';
import '../domain/assets/game_asset_catalog.dart';
import '../domain/identity/league_identity.dart';
import '../domain/tactical/tactical_models.dart';
import '../domain/ai/ai_runtime_models.dart';
import '../infrastructure/data_dragon/data_dragon_catalog_service.dart';
import '../infrastructure/data_dragon/data_dragon_game_asset_catalog.dart';
import '../infrastructure/native_runtime/native_companion_gateway.dart';
import '../infrastructure/ai/ai_runtime_health_client.dart';
import '../infrastructure/ai/ai_runtime_paths.dart';
import '../infrastructure/ai/local_ai_runtime_process_service.dart';
import '../infrastructure/ai/open_code_compatible_runtime_client.dart';
import '../infrastructure/ai/pinned_ai_runtime_installer.dart';
import '../infrastructure/ai/shared_preferences_ai_models.dart';
import '../infrastructure/ai/shared_preferences_ai_conversation_history.dart';
import '../infrastructure/ai/shared_preferences_ai_runtime_settings.dart';
import 'ai/ai_model_selection_controller.dart';
import 'ai/ai_provider_connection_controller.dart';
import 'ai/ai_conversation_controller.dart';
import 'ai/ai_runtime_supervisor.dart';
import 'ai/game_context_prompt_builder.dart';
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
        answer: (question) async {
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
          final deterministic = engine.answer(
            question: question,
            game: league.liveGame,
            lobby: league.lobby,
            sightings: sightings,
          );
          final supervisor = ref.read(aiRuntimeSupervisorProvider);
          final selection = ref.read(aiModelSelectionProvider).selected;
          final conversation = ref.read(aiConversationProvider);
          if (!supervisor.state.isReady ||
              selection == null ||
              conversation.isBusy) {
            return deterministic;
          }
          try {
            final response = await ref
                .read(aiConversationProvider.notifier)
                .sendAndWait(
                  question,
                  systemPrompt: _voiceGameContextPrompt(
                    league.liveGame,
                    league.lobby,
                    sightings,
                  ),
                );
            return TacticalAdvice(
              id: 'voice_ai_${DateTime.now().microsecondsSinceEpoch}',
              title: 'Coach con IA',
              hints: [response],
              rationale:
                  'Respuesta del modelo ${selection.name} con telemetría actual de GodSense.',
              ttsText: _plainTextForSpeech(response),
              priority: 70,
              evidence: [
                TacticalEvidence(
                  factType: 'voice_question',
                  source: FactSource.user,
                  observedAt: DateTime.now().toUtc(),
                  confidence: 1,
                ),
                TacticalEvidence(
                  factType: 'model_assisted_tactical_answer',
                  source: FactSource.derived,
                  observedAt: DateTime.now().toUtc(),
                  confidence: 0.8,
                ),
              ],
            );
          } catch (_) {
            return deterministic;
          }
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

final aiRuntimePathsProvider = Provider<AiRuntimePaths>((ref) {
  final baseDir = Directory(
    Platform.environment['GODSENSE_AI_RUNTIME_DIR'] ??
        p.join(
          Platform.environment['APPDATA'] ??
              Platform.environment['USERPROFILE'] ??
              '.',
          'GodSense',
          'ai_runtimes',
        ),
  );
  return AiRuntimePaths(baseDir);
});

final aiRuntimeSupervisorProvider = Provider<AiRuntimeSupervisor>((ref) {
  final paths = ref.watch(aiRuntimePathsProvider);
  final installer = PinnedAiRuntimeInstaller(paths: paths);
  final processService = LocalAiRuntimeProcessService(paths);
  final health = AiRuntimeHealthClient();
  final supervisor = AiRuntimeSupervisor(
    installer: installer,
    processes: processService,
    health: health,
    allowDownloads: true,
  );
  ref.onDispose(() {
    supervisor.dispose();
    health.dispose();
  });
  return supervisor;
});

final aiRuntimeSupervisorStateProvider =
    StreamProvider<AiRuntimeSupervisorState>((ref) {
      final supervisor = ref.watch(aiRuntimeSupervisorProvider);
      return supervisor.states;
    });

final aiRuntimeSettingsProvider = Provider(
  (_) => const SharedPreferencesAiRuntimeSettings(),
);

final aiRuntimeBootstrapProvider = FutureProvider<void>((ref) async {
  final settings = await ref.watch(aiRuntimeSettingsProvider).load();
  final kind = settings.preferredKind;
  if (!settings.autoStart || kind == null) return;
  final supervisor = ref.watch(aiRuntimeSupervisorProvider);
  if (!await supervisor.isInstalled(kind)) return;
  try {
    await supervisor.start(kind);
  } catch (_) {
    // The settings page exposes the actionable runtime error.
  }
});

final aiConversationProvider =
    StateNotifierProvider<AiConversationController, AiConversationState>((ref) {
      final supervisor = ref.watch(aiRuntimeSupervisorProvider);
      final paths = ref.watch(aiRuntimePathsProvider);
      final controller = AiConversationController(
        supervisor: supervisor,
        modelSelection: () {
          final displayedEndpoint = ref
              .read(aiRuntimeSupervisorStateProvider)
              .value
              ?.endpoint;
          final activeEndpoint = supervisor.state.endpoint;
          if (displayedEndpoint == null ||
              activeEndpoint == null ||
              displayedEndpoint.kind != activeEndpoint.kind ||
              displayedEndpoint.pid != activeEndpoint.pid ||
              displayedEndpoint.password != activeEndpoint.password) {
            return null;
          }
          final models = ref.read(aiModelSelectionProvider);
          return models.loading ? null : models.selected;
        },
        clientFactory: () {
          final endpoint = supervisor.state.endpoint;
          if (endpoint == null) {
            throw StateError('El motor de IA local no está encendido.');
          }
          return OpenCodeCompatibleRuntimeClient(
            endpoint: endpoint,
            directory: paths.root.path,
          );
        },
        historyStore: const SharedPreferencesAiConversationHistory(),
      );
      return controller;
    });

final aiModelPreferencesProvider = Provider<AiModelPreferences>(
  (ref) => SharedPreferencesAiModels(),
);

final aiModelSelectionProvider =
    StateNotifierProvider<AiModelSelectionController, AiModelSelectionState>((
      ref,
    ) {
      final supervisor = ref.watch(aiRuntimeSupervisorProvider);
      final snapshot =
          ref.watch(aiRuntimeSupervisorStateProvider).value ?? supervisor.state;
      final endpoint = snapshot.isReady ? snapshot.endpoint : null;
      final paths = ref.watch(aiRuntimePathsProvider);
      final client = endpoint == null
          ? null
          : OpenCodeCompatibleRuntimeClient(
              endpoint: endpoint,
              directory: paths.root.path,
            );
      if (client != null) ref.onDispose(client.dispose);
      final controller = AiModelSelectionController(
        runtimeId: endpoint?.kind.id ?? 'inactive',
        loadProviders: () => client?.providers() ?? Future.value([]),
        preferences: ref.watch(aiModelPreferencesProvider),
      );
      if (endpoint != null) {
        scheduleMicrotask(() {
          if (controller.mounted) unawaited(controller.refresh());
        });
      }
      return controller;
    });

final aiProviderConnectionProvider =
    StateNotifierProvider.autoDispose<
      AiProviderConnectionController,
      AiProviderConnectionState
    >((ref) {
      final supervisor = ref.watch(aiRuntimeSupervisorProvider);
      final snapshot =
          ref.watch(aiRuntimeSupervisorStateProvider).value ?? supervisor.state;
      final endpoint = snapshot.isReady ? snapshot.endpoint : null;
      final controller = AiProviderConnectionController(
        client: endpoint == null
            ? null
            : OpenCodeCompatibleRuntimeClient(
                endpoint: endpoint,
                directory: ref.watch(aiRuntimePathsProvider).root.path,
              ),
      );
      if (endpoint != null) scheduleMicrotask(controller.refresh);
      return controller;
    });

final gameContextPromptProvider = Provider<String>((ref) {
  final coachState = ref.watch(coachControllerProvider);
  final liveGame = ref.watch(nativeLeagueProvider.select((s) => s.liveGame));
  return const GameContextPromptBuilder().buildSystemPrompt(
    coachState: coachState,
    liveGame: liveGame,
  );
});

String _plainTextForSpeech(String markdown) => markdown
    .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
    .replaceAll(RegExp(r'[`*_>#-]'), ' ')
    .replaceAll(RegExp(r'\[(.*?)\]\(.*?\)'), r'$1')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String _voiceGameContextPrompt(
  Map<String, dynamic>? game,
  Map<String, dynamic> lobby,
  List<TacticalSighting> sightings,
) {
  final active = game?['active_player'] is Map
      ? Map<String, dynamic>.from(game!['active_player'] as Map)
      : const <String, dynamic>{};
  final enemies = game?['enemies'] is List
      ? (game!['enemies'] as List)
            .whereType<Map>()
            .map((item) => item['champion_name']?.toString() ?? '')
            .where((name) => name.isNotEmpty)
            .join(', ')
      : '';
  return [
    'Eres el coach táctico de League of Legends de GodSense.',
    'Responde en español, de forma breve, accionable y sin usar herramientas.',
    if (game != null) 'Minuto: ${game['game_time'] ?? 0}.',
    if (active.isNotEmpty)
      'Jugador: ${active['champion_name'] ?? 'desconocido'}, KDA ${active['kda'] ?? const []}, CS ${active['cs'] ?? 0}.',
    if (game != null) 'Diferencia de oro: ${game['team_gold_diff'] ?? 0}.',
    if (enemies.isNotEmpty) 'Enemigos: $enemies.',
    if (sightings.isNotEmpty)
      'Último avistamiento: ${sightings.first.champion} en ${sightings.first.location}.',
    if (game == null && lobby.isNotEmpty)
      'Contexto de selección de campeón disponible: ${lobby['phase'] ?? 'ChampSelect'}.',
  ].join('\n');
}
