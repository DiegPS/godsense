import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multiview_desktop/multiview_desktop.dart';

import '../application/account_context_coordinator.dart';
import '../application/dependencies.dart';
import '../application/cv_corpus_comparator.dart';
import '../application/native_calibration_controller.dart';
import '../application/native_league_controller.dart';
import '../application/native_speech_controller.dart';
import '../application/native_vision_controller.dart';
import '../application/local_scout_controller.dart';
import '../application/overlay_layout_controller.dart';
import '../application/overlay_parity_logger.dart';
import '../domain/companion_models.dart';
import '../domain/identity/league_identity.dart';
import '../domain/jungle/jungle_recommendation.dart';
import '../domain/league/item_recommendation.dart';
import '../domain/league/rune_recommendation.dart';
import '../domain/vision/vision_observation.dart';
import '../presentation/native_speech_settings_card.dart';
import '../presentation/shared/live_rank_badge.dart';
import '../presentation/shared/getting_started_guide.dart';

part '../presentation/shell/godsense_shell.dart';
part 'godsense_theme.dart';
part '../presentation/pages/overview_page.dart';
part '../presentation/pages/live_page.dart';
part '../presentation/pages/scout_page.dart';
part '../presentation/pages/vision_page.dart';
part '../presentation/pages/coach_page.dart';
part '../presentation/pages/settings_page.dart';
part '../presentation/overlay/godsense_overlay.dart';
part '../presentation/overlay/overlay_components.dart';
part '../presentation/window/overlay_window_manager.dart';
part '../presentation/shared/presentation_shared.dart';
part '../presentation/shared/godsense_ui_components.dart';

final selectedPageProvider = StateProvider<int>((ref) => 0);
final overlayEnabledProvider = StateProvider<bool>((ref) => true);
final overlayOpenProvider = StateProvider<bool>((ref) => false);

final appProviderContainer = ProviderContainer();
final overlayWindowManager = OverlayWindowManager(appProviderContainer);
final overlayParityLogger = OverlayParityLogger();
final forceNativeVision =
    Platform.environment['GODSENSE_NATIVE_VISION_ALWAYS'] == '1';

final effectiveGameProvider = Provider<GameSnapshot?>((ref) {
  final native = ref.watch(nativeLeagueProvider);
  return native.liveGame == null
      ? null
      : GameSnapshot.fromJson(native.liveGame!);
});

final effectiveLobbyProvider = Provider<LobbyState?>((ref) {
  final native = ref.watch(nativeLeagueProvider);
  if (native.lobby.isNotEmpty) return LobbyState.fromJson(native.lobby);
  return ref.watch(companionControllerProvider).lobby;
});

final overlayWindowVisibleProvider = Provider<bool>((ref) {
  if (!ref.watch(overlayEnabledProvider)) return false;
  if (ref.watch(overlayLayoutProvider).editing) return true;
  final game = ref.watch(effectiveGameProvider);
  return game != null && !game.gameEnded;
});

void runGodSense() {
  runMultiApp(
    home: (_, _) => const GodSenseApp(),
    globalScope: (child) => UncontrolledProviderScope(
      container: appProviderContainer,
      child: child,
    ),
    config: MultiAppConfig(
      generalParams: const MultiPlatformParams(
        closeMode: CloseMode.forceSecondary,
        enableDynamicAnchor: false,
      ),
      globalWindowOptions: const WindowOptions(
        size: Size(1200, 760),
        minimumSize: Size(900, 600),
        alignment: Alignment.center,
        title: 'GodSense',
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: false,
      ),
      observers: [overlayWindowManager],
    ),
  );
}
