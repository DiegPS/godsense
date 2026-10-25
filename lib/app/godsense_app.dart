import 'dart:async';
import 'dart:io';

import 'package:dart_ai_runtime/dart_ai_runtime.dart' as ai_runtime;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multiview_desktop/multiview_desktop.dart';

import '../application/coach_controller.dart';
import '../application/dependencies.dart';
import '../application/native_calibration_controller.dart';
import '../application/native_league_controller.dart';
import '../application/native_speech_controller.dart';
import '../application/native_vision_controller.dart';
import '../application/vision_session_coordinator.dart';
import '../application/local_scout_controller.dart';
import '../application/overlay_layout_controller.dart';
import '../domain/ai/ai_runtime_models.dart';
import '../domain/companion_models.dart';
import '../domain/identity/league_identity.dart';
import '../domain/league/account_context.dart';
import '../domain/vision/vision_observation.dart';
import '../infrastructure/diagnostics/app_logger.dart';
import '../presentation/native_speech_settings_card.dart';
import '../presentation/shell/retained_page_stack.dart';
import '../presentation/coach/coach_page.dart';
import '../presentation/coach/shared/ai_model_selector.dart';
import '../presentation/coach/shared/ai_provider_connections.dart';
import '../presentation/shared/live_rank_badge.dart';
import '../presentation/shared/getting_started_guide.dart';
import '../presentation/shared/resilient_network_image.dart';
import '../presentation/shared/godsense_ui_components.dart';
import 'godsense_theme.dart';

export '../presentation/shared/godsense_ui_components.dart';
export 'godsense_theme.dart';

part '../presentation/shell/godsense_shell.dart';
part '../presentation/pages/overview_page.dart';
part '../presentation/pages/live_page.dart';
part '../presentation/pages/scout_page.dart';
part '../presentation/pages/vision_page.dart';
part '../presentation/pages/settings_page.dart';
part '../presentation/overlay/godsense_overlay.dart';
part '../presentation/overlay/overlay_components.dart';
part '../presentation/window/overlay_window_manager.dart';
part '../presentation/shared/presentation_shared.dart';

final selectedPageProvider = StateProvider<int>((ref) => 0);
final overlayEnabledProvider = StateProvider<bool>((ref) => true);
final overlayOpenProvider = StateProvider<bool>((ref) => false);

final shellSessionStatusProvider = Provider<({String label, bool online})>((
  ref,
) {
  final connection = ref.watch(
    companionControllerProvider.select((state) => state.connection),
  );
  final companionLobby = ref.watch(
    companionControllerProvider.select((state) => state.lobby),
  );
  final nativeLeague = ref.watch(
    nativeLeagueProvider.select(
      (state) => (
        inGame: state.inGame,
        lcuConnected: state.lcuConnected,
        hasLiveGame: state.liveGame != null,
      ),
    ),
  );
  return (
    label: _sessionLabel(
      connection: connection,
      companionLobby: companionLobby,
      nativeInGame: nativeLeague.inGame,
      nativeLcuConnected: nativeLeague.lcuConnected,
    ),
    online:
        connection == CompanionConnection.online || nativeLeague.hasLiveGame,
  );
});

final appProviderContainer = ProviderContainer();
final overlayWindowManager = OverlayWindowManager(appProviderContainer);
final effectiveGameProvider = Provider<GameSnapshot?>((ref) {
  final liveGame = ref.watch(
    nativeLeagueProvider.select((state) => state.liveGame),
  );
  return liveGame == null ? null : GameSnapshot.fromJson(liveGame);
});

final effectiveLobbyProvider = Provider<LobbyState?>((ref) {
  final nativeLobby = ref.watch(
    nativeLeagueProvider.select((state) => state.lobby),
  );
  if (nativeLobby.isNotEmpty) return LobbyState.fromJson(nativeLobby);
  return ref.watch(companionControllerProvider.select((state) => state.lobby));
});

final overlayWindowVisibleProvider = Provider<bool>((ref) {
  if (!ref.watch(overlayEnabledProvider)) return false;
  if (ref.watch(overlayLayoutProvider).editing) return true;
  final game = ref.watch(effectiveGameProvider);
  return game != null && !game.gameEnded;
});

void runGodSense() {
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/inter/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Inter'], license);
  });
  runMultiApp(
    home: (_, _) => const GodSenseApp(),
    globalScope: (child) => UncontrolledProviderScope(
      container: appProviderContainer,
      child: child,
    ),
    config: MultiAppConfig(
      generalParams: const MultiPlatformParams(
        closeMode: CloseMode.destroy,
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
