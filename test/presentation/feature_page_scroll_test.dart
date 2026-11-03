import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/app/godsense_theme.dart';
import 'package:godsense/presentation/shared/godsense_ui_components.dart';

void main() {
  for (final width in [360.0, 1000.0, 1920.0]) {
    for (final direction in TextDirection.values) {
      testWidgets('page scroll has no fixed frame at $width / $direction', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1.25;
        tester.view.physicalSize = Size(width * 1.25, 600 * 1.25);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: godsenseTheme().copyWith(platform: TargetPlatform.windows),
            home: Directionality(
              textDirection: direction,
              child: Scaffold(
                body: Column(
                  children: [
                    const SizedBox(height: 52, child: Text('Window chrome')),
                    Expanded(
                      child: GsFeaturePage(
                        key: const Key('page'),
                        children: [
                          Container(
                            key: const Key('long-card'),
                            height: 1200,
                            color: Colors.white,
                          ),
                          GsButton(
                            label: 'Last action',
                            onPressed: () => taps++,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        final page = tester.getRect(find.byKey(const Key('page')));
        final viewportFinder = find.descendant(
          of: find.byKey(const Key('page')),
          matching: find.byType(Viewport),
        );
        final viewport = tester.getRect(viewportFinder);
        expect(viewport, page);
        expect(viewport.top, 52);
        expect(viewport.bottom, 600);
        expect(find.byType(Scrollbar), findsOneWidget);
        final verticalGutter = width < 720 ? 16.0 : 24.0;
        final gutter =
            verticalGutter +
            (width > GsSizes.maxPageWidth
                ? (width - GsSizes.maxPageWidth) / 2
                : 0);
        final card = tester.getRect(find.byKey(const Key('long-card')));
        expect(card.left - viewport.left, gutter);
        expect(viewport.right - card.right, gutter);
        // The configured scrollbar is 8 logical pixels wide. The card has
        // actual reserved space beyond it, not padding outside the viewport.
        final thickness = Theme.of(tester.element(viewportFinder))
            .scrollbarTheme
            .thickness!
            .resolve({})!;
        expect(gutter, greaterThan(thickness));
        final scrollable = tester.state<ScrollableState>(
          find.byType(Scrollable),
        );
        scrollable.position.jumpTo(card.top - viewport.top + 20);
        await tester.pumpAndSettle();
        final moving = tester.getRect(find.byKey(const Key('long-card')));
        expect(moving.top, lessThan(viewport.top));
        final box = tester.renderObject<RenderBox>(
          find.byKey(const Key('long-card')),
        );
        final probe = Offset(card.center.dx, viewport.top + 2);
        final hit = HitTestResult();
        tester.binding.hitTestInView(hit, probe, tester.view.viewId);
        expect(
          hit.path.any((entry) => identical(entry.target, box)),
          isTrue,
          reason: 'Content must be hit-testable immediately below the chrome, not behind a fixed top inset.',
        );
        scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
        await tester.pumpAndSettle();
        final last = tester.getRect(find.byType(GsButton));
        expect(viewport.bottom - last.bottom, closeTo(verticalGutter, .1));
        await tester.tap(find.text('Last action'));
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
