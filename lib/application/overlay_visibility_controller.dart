import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../infrastructure/diagnostics/app_logger.dart';

final overlayEnabledProvider =
    StateNotifierProvider<OverlayVisibilityController, bool>((ref) {
      final controller = OverlayVisibilityController();
      controller.load();
      return controller;
    });

class OverlayVisibilityController extends StateNotifier<bool> {
  OverlayVisibilityController({
    Future<SharedPreferences> Function()? preferences,
  }) : _preferences = preferences ?? SharedPreferences.getInstance,
       // Wait for the saved preference before opening an in-game window.
       super(false);

  static const storageKey = 'godsense.overlay.enabled.v1';
  final Future<SharedPreferences> Function() _preferences;
  Future<void> _writes = Future.value();
  int _revision = 0;

  Future<void> load() async {
    final revision = _revision;
    var enabled = true;
    try {
      enabled = (await _preferences()).getBool(storageKey) ?? true;
    } catch (error, stack) {
      AppLogger.warning(
        'Overlay preference could not be loaded.',
        category: 'overlay',
        error: error,
        stackTrace: stack,
      );
    }
    if (mounted && revision == _revision) state = enabled;
  }

  Future<void> setEnabled(bool enabled) {
    if (!mounted) return Future.value();
    _revision++;
    state = enabled;
    final write = _writes.then((_) async {
      final saved = await (await _preferences()).setBool(storageKey, enabled);
      if (!saved) throw StateError('Overlay preference could not be saved.');
    });
    _writes = write.catchError((Object error, StackTrace stack) {
      AppLogger.warning(
        'Overlay preference could not be saved.',
        category: 'overlay',
        error: error,
        stackTrace: stack,
      );
    });
    return write;
  }
}
