import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multiview_desktop/multiview_desktop.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/dependencies.dart';
import '../application/cv_corpus_comparator.dart';
import '../application/native_calibration_controller.dart';
import '../application/native_league_controller.dart';
import '../application/native_speech_controller.dart';
import '../application/native_vision_controller.dart';
import '../application/overlay_layout_controller.dart';
import '../application/overlay_parity_logger.dart';
import '../domain/companion_models.dart';
import '../domain/identity/league_identity.dart';
import '../domain/vision/vision_observation.dart';
import '../presentation/native_speech_settings_card.dart';

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
      ),
      observers: [overlayWindowManager],
    ),
  );
}
