import 'dart:async';
import 'dart:io';

import 'package:win32/win32.dart';

abstract interface class PushToTalkHotkey {
  Stream<bool> get transitions;
  void configure({required bool enabled, required String key});
  void dispose();
}

class GlobalPushToTalkHotkey implements PushToTalkHotkey {
  final _transitions = StreamController<bool>.broadcast();
  Timer? _timer;
  bool _pressed = false;
  bool _enabled = false;
  int _virtualKey = VK_DELETE;

  @override
  Stream<bool> get transitions => _transitions.stream;

  @override
  void configure({required bool enabled, required String key}) {
    _enabled = enabled && Platform.isWindows;
    _virtualKey = virtualKeyFor(key);
    _timer?.cancel();
    _timer = null;
    if (!_enabled) {
      _emit(false);
      return;
    }
    _timer = Timer.periodic(
      const Duration(milliseconds: 25),
      (_) => _emit((GetAsyncKeyState(_virtualKey) & 0x8000) != 0),
    );
  }

  void _emit(bool pressed) {
    if (_pressed == pressed) return;
    _pressed = pressed;
    if (!_transitions.isClosed) _transitions.add(pressed);
  }

  static int virtualKeyFor(String key) => switch (key.toLowerCase()) {
    'space' => VK_SPACE,
    'f8' => VK_F8,
    'f9' => VK_F9,
    'f10' => VK_F10,
    'f11' => VK_F11,
    'f12' => VK_F12,
    _ => VK_DELETE,
  };

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _transitions.close();
  }
}
