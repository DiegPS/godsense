import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/overlay_visibility_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'does not show before loading, defaults on and restores a saved choice',
    () async {
      final first = OverlayVisibilityController();
      addTearDown(first.dispose);
      expect(first.state, isFalse);
      await first.load();
      expect(first.state, isTrue);
      await first.setEnabled(false);
      final restarted = OverlayVisibilityController();
      addTearDown(restarted.dispose);
      await restarted.load();
      expect(restarted.state, isFalse);
      await restarted.setEnabled(true);
      final again = OverlayVisibilityController();
      addTearDown(again.dispose);
      await again.load();
      expect(again.state, isTrue);
    },
  );

  test(
    'a late load cannot undo a user choice and writes remain ordered',
    () async {
      final ready = Completer<SharedPreferences>();
      final controller = OverlayVisibilityController(
        preferences: () => ready.future,
      );
      addTearDown(controller.dispose);
      final loading = controller.load();
      final first = controller.setEnabled(true);
      final second = controller.setEnabled(false);
      ready.complete(await SharedPreferences.getInstance());
      await Future.wait([loading, first, second]);
      expect(controller.state, isFalse);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          OverlayVisibilityController.storageKey,
        ),
        isFalse,
      );
    },
  );

  test(
    'failed persistence keeps the runtime choice and permits retry',
    () async {
      var failing = true;
      final controller = OverlayVisibilityController(
        preferences: () async {
          if (failing) throw StateError('Storage unavailable');
          return SharedPreferences.getInstance();
        },
      );
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.state, isTrue);
      await expectLater(controller.setEnabled(false), throwsStateError);
      expect(controller.state, isFalse);
      failing = false;
      await controller.setEnabled(true);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          OverlayVisibilityController.storageKey,
        ),
        isTrue,
      );
    },
  );

  test('disposing while loading ignores the late result', () async {
    final ready = Completer<SharedPreferences>();
    final controller = OverlayVisibilityController(
      preferences: () => ready.future,
    );
    final loading = controller.load();
    controller.dispose();
    ready.complete(await SharedPreferences.getInstance());
    await loading;
  });
}
