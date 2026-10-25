import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/presentation/shared/gs_slider.dart';
import 'package:godsense/presentation/shell/retained_page_stack.dart';

void main() {
  testWidgets('keyboard and screen reader adjust speed across tab switches', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final page = ValueNotifier(0);
    final speed = ValueNotifier(1.0);
    addTearDown(page.dispose);
    addTearDown(speed.dispose);
    final slider = ValueListenableBuilder<double>(
      valueListenable: speed,
      builder: (_, value, _) => GsSlider(
        value: value,
        min: .6,
        max: 1.6,
        divisions: 20,
        label: 'Velocidad de voz',
        onChanged: (value) => speed.value = value,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<int>(
            valueListenable: page,
            builder: (_, index, _) => RetainedPageStack(
              index: index,
              children: [
                Center(child: slider),
                const Text('Other tab'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(speed.value, closeTo(1.05, .0001));
    var node = tester.getSemantics(find.bySemanticsLabel('Velocidad de voz'));
    expect(node.getSemanticsData().flagsCollection.isSlider, isTrue);
    node.owner!.performAction(node.id, SemanticsAction.decrease);
    await tester.pump();
    expect(speed.value, closeTo(1, .0001));
    for (var i = 0; i < 4; i++) {
      page.value = 1;
      await tester.pump();
      expect(find.bySemanticsLabel('Velocidad de voz'), findsNothing);
      page.value = 0;
      await tester.pump();
    }
    expect(find.byType(OverlayPortal), findsNothing);
    expect(find.bySemanticsLabel('Velocidad de voz'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    semantics.dispose();
  });
}
