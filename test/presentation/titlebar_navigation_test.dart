import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/app/godsense_app.dart';
import 'package:multiview_desktop/multiview_desktop.dart';

void main() {
  for (final width in [900.0, 1400.0]) {
    testWidgets(
      'title navigation accepts mouse clicks with small vertical motion at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final selections = <int>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: godsenseTheme(),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: GodSenseTitleBar(
                  selectedPage: 0,
                  onSelectPage: selections.add,
                  overlayEditing: false,
                  onToggleEditing: () {},
                  onResetPanels: null,
                  onHelp: () {},
                  sessionLabel: 'Sin partida',
                  isOnline: false,
                ),
              ),
            ),
          ),
        );
        final dragBackground = find.byKey(
          const Key('titlebar-drag-background'),
        );
        final dragListener = find.descendant(
          of: dragBackground,
          matching: find.byType(Listener),
        );
        final dragTarget = tester.renderObject(dragListener);
        bool hitsDragBackground(Offset position) => tester
            .hitTestOnBinding(position)
            .path
            .any((entry) => identical(entry.target, dragTarget));
        final bar = tester.getRect(find.byType(GodSenseTitleBar));
        var freeDragWidth = 0;
        for (var x = 0.0; x < bar.width; x += 4) {
          if (hitsDragBackground(Offset(x, bar.center.dy))) {
            freeDragWidth += 4;
          }
        }
        expect(
          freeDragWidth,
          greaterThanOrEqualTo(48),
          reason: 'Empty titlebar space must let the user move the window',
        );
        expect(
          find.ancestor(
            of: find.byTooltip('Scout'),
            matching: find.byType(DragToMoveArea),
          ),
          findsNothing,
        );
        for (final entry in [
          ('Ajustes', 5),
          ('Coach', 3),
          ('Scout', 4),
          ('Coach', 3),
          ('Ajustes', 5),
        ]) {
          final target = find.descendant(
            of: find.byTooltip(entry.$1),
            matching: find.byType(TextButton),
          );
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          expect(hitsDragBackground(tester.getCenter(target)), isFalse);
          expect(
            hitsDragBackground(
              Offset(tester.getCenter(target).dx, bar.top + 1),
            ),
            isTrue,
            reason: 'The free strip above a tab must remain draggable',
          );
          final gesture = await tester.startGesture(
            tester.getCenter(target),
            kind: PointerDeviceKind.mouse,
          );
          await gesture.moveBy(const Offset(0, 8));
          await tester.pump(const Duration(milliseconds: 70));
          await gesture.up();
          await tester.pump();
          expect(
            selections,
            isNotEmpty,
            reason: '${entry.$1} lost its first click',
          );
          expect(selections.last, entry.$2);
        }
        expect(selections, [5, 3, 4, 3, 5]);
      },
    );
  }
}
