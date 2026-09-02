import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/overlay_layout_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const saved = OverlayPanelLayout(x: 2471, y: 923, width: 403, height: 392);
  test('saved panel stays fully visible on a smaller monitor', () {
    expect(
      saved.fitWithin(const Size(1920, 1080)),
      const Rect.fromLTWH(1517, 688, 403, 392),
    );
  });
  test('tiny and zero viewports never create invalid clamp ranges', () {
    for (final size in [
      Size.zero,
      const Size(100, 40),
      const Size(1920, 1080),
    ]) {
      final fitted = saved.fitWithin(size);
      expect(fitted.left, greaterThanOrEqualTo(0));
      expect(fitted.top, greaterThanOrEqualTo(0));
      expect(fitted.right, lessThanOrEqualTo(size.width));
      expect(fitted.bottom, lessThanOrEqualTo(size.height));
    }
  });
  test(
    'collapsed panels retain a visible header without changing saved height',
    () {
      final collapsed = saved.copyWith(collapsed: true);
      expect(collapsed.fitWithin(const Size(800, 600)).height, 48);
      expect(collapsed.height, 392);
    },
  );
  test(
    'moving and resizing an oversized panel stay within the screen',
    () async {
      SharedPreferences.setMockInitialValues({});
      final controller = OverlayLayoutController();
      addTearDown(controller.dispose);
      await controller.load();
      const viewport = Size(200, 60);
      controller.move('jungler', const Offset(5, 10), viewport);
      controller.resize('jungler', const Offset(100, 100), viewport);
      final layout = controller.state.panels['jungler']!;
      expect(layout.fitWithin(viewport), const Rect.fromLTWH(0, 0, 200, 60));
      expect(layout.width, 200);
      expect(layout.height, 60);
    },
  );
}
